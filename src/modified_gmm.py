from pathlib import Path
import sys
import time

import numpy as np
import joblib
import matplotlib.pyplot as plt
import pandas as pd
from scipy.special import logsumexp
from sklearn.cluster import KMeans


sys.path.insert(0, str(Path(__file__).resolve().parent))
import declarations as zig  # noqa: E402


# ------------------------------- Configuration -------------------------------
ROOT = Path(__file__).resolve().parents[1]
A_VEC_PATH = ROOT / "datafiles" / "compressed_AffectVec"
W_VEC_PATH = ROOT / "datafiles" / "compressed_WordVec"
RESULTS_DIR = ROOT / "results"

K_VALUES = [256, 512]

NUM_THREADS = 32

RANDOM_STATE = 42
MAX_ITER = 200
TOL = 1e-3 # convergence: |delta(modified_objective_per_sample)| < TOL
REG_COVAR = 1e-6 # added to Sigma diagonals to prevent collapse
S_EPS = 1e-12 # floor for S(m,h) so log(S) is finite
# -----------------------------------------------------------------------------

def load_through_zig() -> tuple[np.ndarray, np.ndarray]:
    print("Initializing Zig backend ...")
    if not zig.init(str(A_VEC_PATH), str(W_VEC_PATH), NUM_THREADS):
        raise RuntimeError(
            f"zig.init failed. Check that {A_VEC_PATH} and {W_VEC_PATH} exist "
            f"(run zig-out\\bin\\preprocess.exe to regenerate them)."
        )

    n = int(zig.numDataPoints())
    d = int(zig.numWordVecCols())
    a = int(zig.numAffectVecCols())
    print(f"N={n}, D={d} (word2vec), A={a} (affect)")

    X = np.empty((n, d), dtype=np.float64)
    M = np.empty((n, a), dtype=np.float64)

    print(f"Pulling {n} rows through Zig API ...", flush=True)
    t0 = time.time()
    for i in range(n):
        # zig.lib.getWordVecPos returns a POINTER(c_float). np.ctypeslib.as_array
        # gives a zero-copy numpy view; we copy into our destination matrix.
        x_ptr = zig.lib.getWordVecPos(i)
        if not x_ptr:
            zig.deinit()
            raise RuntimeError(f"getWordVecPos({i}) returned NULL")
        X[i] = np.ctypeslib.as_array(x_ptr, shape=(d,))

        m_ptr = zig.lib.getAffectVecPos(i)
        if not m_ptr:
            zig.deinit()
            raise RuntimeError(f"getAffectVecPos({i}) returned NULL")
        M[i] = np.ctypeslib.as_array(m_ptr, shape=(a,))

        if n >= 10 and (i + 1) % max(1, n // 10) == 0:
            pct = (i + 1) * 100 // n
            print(f"{pct:>3}%  ({i + 1}/{n})", flush=True)

    print(f"Loaded in {time.time() - t0:.1f}s")
    return X, M

def similarity_matrix(M: np.ndarray, H: np.ndarray, eps: float = S_EPS) -> np.ndarray:
    """S(m_i, h_k) = 1 - mean_a (m_i_a - h_k_a)^2 -> shape (N, K)."""
    A = M.shape[1]
    m_sq = (M ** 2).sum(axis=1)
    h_sq = (H ** 2).sum(axis=1)
    cross = M @ H.T
    sse = m_sq[:, None] + h_sq[None, :] - 2.0 * cross
    return np.maximum(1.0 - sse / A, eps)

def log_gaussian_diag(X: np.ndarray, mu: np.ndarray, sigma_sq: np.ndarray) -> np.ndarray:
    """log N(x_i | mu_k, diag(sigma_sq_k)) -> shape (N, K)."""
    N, D = X.shape
    K = mu.shape[0]
    log_det = np.sum(np.log(2.0 * np.pi * sigma_sq), axis=1)
    out = np.empty((N, K), dtype=np.float64)
    for k in range(K):
        diff = X - mu[k]
        out[:, k] = np.sum(diff * diff / sigma_sq[k], axis=1)
    return -0.5 * (log_det[None, :] + out)

def standard_log_likelihood(X: np.ndarray, pi: np.ndarray,
                            mu: np.ndarray, sigma_sq: np.ndarray) -> float:
    log_pi = np.log(np.maximum(pi, 1e-300))
    log_N = log_gaussian_diag(X, mu, sigma_sq)
    return float(logsumexp(log_pi[None, :] + log_N, axis=1).sum())

def initialize_from_kmeans(X: np.ndarray, M: np.ndarray, k: int,
                           random_state: int) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    print(f"Initializing with K-means (K={k}) ...", flush=True)
    km = KMeans(n_clusters=k, random_state=random_state, n_init=3).fit(X)
    labels = km.labels_

    D = X.shape[1]
    A = M.shape[1]
    mu = km.cluster_centers_.astype(np.float64)
    sigma_sq = np.empty((k, D), dtype=np.float64)
    h = np.empty((k, A), dtype=np.float64)
    pi = np.empty(k, dtype=np.float64)

    global_var = X.var(axis=0)
    global_h = M.mean(axis=0)
    for j in range(k):
        mask = labels == j
        n_j = int(mask.sum())
        if n_j < 2:
            sigma_sq[j] = global_var
            h[j] = global_h
        else:
            sigma_sq[j] = X[mask].var(axis=0)
            h[j] = M[mask].mean(axis=0)
        pi[j] = max(n_j / X.shape[0], 1e-10)
    pi = pi / pi.sum()
    sigma_sq = np.maximum(sigma_sq, REG_COVAR)
    return pi, mu, sigma_sq, h

def fit_modified_gmm(X: np.ndarray, M: np.ndarray, k: int,
                     max_iter: int = MAX_ITER, tol: float = TOL,
                     random_state: int = RANDOM_STATE) -> dict:
    N, D = X.shape
    A = M.shape[1]

    pi, mu, sigma_sq, h = initialize_from_kmeans(X, M, k, random_state)

    fit_start = time.time() # Used for seeing elapsed time after N iterations
    prev_obj_per = -np.inf
    converged = False
    n_iter = 0

    for it in range(1, max_iter + 1):
        # E-step.
        log_S = np.log(similarity_matrix(M, h))
        log_pi = np.log(np.maximum(pi, 1e-300))
        log_N = log_gaussian_diag(X, mu, sigma_sq)
        log_unnorm = log_S + log_pi[None, :] + log_N
        log_norm = logsumexp(log_unnorm, axis=1, keepdims=True)
        log_resp = log_unnorm - log_norm
        resp = np.exp(log_resp)

        modified_obj_per = float(log_norm.sum() / N)
        if abs(modified_obj_per - prev_obj_per) < tol:
            converged = True
            n_iter = it
            break
        prev_obj_per = modified_obj_per

        # M-step.
        Nk = resp.sum(axis=0)
        Nk_safe = np.maximum(Nk, 1e-10)

        pi = Nk / N
        mu = (resp.T @ X) / Nk_safe[:, None]
        h = (resp.T @ M) / Nk_safe[:, None]

        for j in range(k):
            diff = X - mu[j]
            sigma_sq[j] = (resp[:, j:j + 1] * (diff * diff)).sum(axis=0) / Nk_safe[j]
        sigma_sq = np.maximum(sigma_sq, REG_COVAR)

        n_iter = it

        # Progress: print every 10 iterations
        if it % 10 == 0 or it == 1:
            elapsed = time.time() - fit_start
            print(f"Iteration {it:>3}:  obj/N = {modified_obj_per:>9.4f}  elapsed-time = {elapsed:>6.1f}s",
                  flush=True)

    log_lik = standard_log_likelihood(X, pi, mu, sigma_sq)
    n_params = k * D + k * D + (k - 1) + k * A
    bic = -2.0 * log_lik + n_params * np.log(N)

    return {
        "k": k,
        "pi": pi,
        "mu": mu,
        "sigma_sq": sigma_sq,
        "h": h,
        "n_iter": n_iter,
        "converged": converged,
        "modified_objective": prev_obj_per * N,
        "log_likelihood": log_lik,
        "bic": bic,
        "n_params": n_params,
    }

def print_header() -> None:
    print(
        f"\n{'K':>5} {'BIC':>15} {'logL':>15} "
        f"{'iters':>6} {'conv':>6} {'time(s)':>8}"
    )
    print("-" * 70)

def print_row(r: dict) -> None:
    print(
        f"{r['k']:>5} {r['bic']:>15.2f} {r['log_likelihood']:>15.2f} "
        f"{r['n_iter']:>6} {str(r['converged']):>6} {r['elapsed_sec']:>8.1f}"
    )

def save_summary_csv(results: list[dict], path: Path) -> pd.DataFrame:
    cols = ["k", "bic", "log_likelihood", "modified_objective",
            "n_iter", "converged", "n_params", "elapsed_sec"]
    df = pd.DataFrame([{c: r[c] for c in cols} for r in results])
    df.to_csv(path, index=False)
    return df

def plot_bic_vs_baseline(modified_df: pd.DataFrame, baseline_csv: Path,
                         best_k: int, path: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(modified_df["k"], modified_df["bic"],
            marker="o", label="Modified GMM (with S(m,h))", color="C1")
    if baseline_csv.exists():
        base_df = pd.read_csv(baseline_csv)
        ax.plot(base_df["k"], base_df["bic"],
                marker="s", label="Baseline GMM", color="C0", alpha=0.7)
    ax.axvline(best_k, linestyle="--", color="gray", alpha=0.6,
               label=f"Modified best K = {best_k}")
    ax.set_xlabel("K (number of components)")
    ax.set_ylabel("Bayesian Information Criterion (lower is better)")
    ax.set_title("Modified vs Baseline GMM - BIC across K")
    ax.set_xscale("log", base=2)
    ax.set_xticks(modified_df["k"])
    ax.set_xticklabels(modified_df["k"])
    ax.legend()
    ax.grid(alpha=0.3)
    fig.savefig(path, dpi=120, bbox_inches="tight")
    plt.close(fig)

def main() -> None:
    RESULTS_DIR.mkdir(exist_ok=True)
    results: list[dict] = []

    try:
        X, M = load_through_zig()
        print(f"X: {X.shape}, M: {M.shape}")

        print(f"\nFitting modified GMM for K = {K_VALUES}")
        print_header()

        for k in K_VALUES:
            t0 = time.time()
            try:
                r = fit_modified_gmm(X, M, k)
                r["elapsed_sec"] = time.time() - t0
                results.append(r)
                print_row(r)

                # Save after each K so a crash or Ctrl+C doesn't lose completed work
                save_summary_csv(results, RESULTS_DIR / "modified_bic.csv")
                joblib.dump(r, RESULTS_DIR / f"modified_gmm_k{k}.joblib")
                print(f"Saved partial results")
            except KeyboardInterrupt:
                elapsed = time.time() - t0
                print(f"\n{k:>5}   INTERRUPTED after {elapsed:.1f}s — partial results saved up to K={results[-1]['k'] if results else 'none'}")
                break
            except Exception as e:
                elapsed = time.time() - t0
                print(f"{k:>5}   FAILED after {elapsed:.1f}s: {e}")
    finally:
        zig.deinit()
    
    if not results:
        print("\nNo K values completed; nothing to save.")
        return

    summary_csv = RESULTS_DIR / "modified_bic.csv"
    summary_df = save_summary_csv(results, summary_csv)
    print(f"\nResults table -> {summary_csv}")

    best = min(results, key=lambda r: r["bic"])
    best_path = RESULTS_DIR / f"modified_gmm_k{best['k']}.joblib"
    joblib.dump(best, best_path)
    print(f"Best model -> {best_path} (K={best['k']}, BIC={best['bic']:.2f})")

    plot_path = RESULTS_DIR / "modified_vs_baseline_bic.png"
    plot_bic_vs_baseline(summary_df, RESULTS_DIR / "baseline_bic.csv",
                         best["k"], plot_path)
    print(f"Comparison plot -> {plot_path}")

if __name__ == "__main__":
    main()