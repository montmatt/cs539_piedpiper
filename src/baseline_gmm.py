from pathlib import Path
import time

import numpy as np
import pandas as pd
import joblib
import matplotlib.pyplot as plt
from sklearn.mixture import GaussianMixture

# -------------------------------- Configurations --------------------------------
ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "datafiles/reduced_WordVec.tsv"
RESULTS_DIR = ROOT / "results"

K_VALUES = [2, 4, 8, 16, 32, 64, 128, 256, 512]
COVARIANCE_TYPE = "diag" # "diag", "full", "tied", "spherical"

RANDOM_STATE = 42

MAX_ITER = 200
N_INIT = 1
# --------------------------------------------------------------------------------

def load_word_vectors(path: Path) -> tuple[np.ndarray, list[str]]:
    """
    Load reduced_WordVec.tsv. Format is: word \\t d0 \\t d1 \\t ... \\t d299.
    Returns (X, words) where X has shape (n_rows, 300) as float32.
    """
    if not path.exists():
        raise FileNotFoundError(
            f"Could not find {path}. "
            f"Run preprocess-wordbin.py first if it isn't there."
        )
    print(f"Loading {path} ...")
    df = pd.read_csv(path, sep="\t")
    words = df["word"].astype(str).tolist()
    X = df.drop(columns=["word"]).to_numpy(dtype=np.float32)
    print(f"  -> {X.shape[0]} words, {X.shape[1]} dimensions")
    return X, words

def fit_one(X: np.ndarray, k: int) -> dict:
    """Fit a GMM with K components and return its diagnostics."""
    t0 = time.time()
    gmm = GaussianMixture(
        n_components=k,
        covariance_type=COVARIANCE_TYPE,
        random_state=RANDOM_STATE,
        max_iter=MAX_ITER,
        n_init=N_INIT,
    )
    gmm.fit(X)
    elapsed = time.time() - t0
    return {
        "k": k,
        "bic": gmm.bic(X), # lower is better
        "log_likelihood": gmm.score(X) * X.shape[0], # total, not per-sample
        "n_iter": gmm.n_iter_,
        "converged": gmm.converged_,
        "elapsed_sec": elapsed,
        "model": gmm,
    }

def print_header() -> None:
    print(
        f"\n{'K':>5} {'BIC':>15} {'logL':>15} "
        f"{'iters':>6} {'conv':>6} {'time(s)':>8}"
    )
    print("-" * 75)

def print_row(r: dict) -> None:
    print(
        f"{r['k']:>5} {r['bic']:>15.2f} "
        f"{r['log_likelihood']:>15.2f} {r['n_iter']:>6} "
        f"{str(r['converged']):>6} {r['elapsed_sec']:>8.1f}"
    )

def save_summary_csv(results: list[dict], path: Path) -> pd.DataFrame:
    cols = ["k", "bic", "log_likelihood", "n_iter", "converged", "elapsed_sec"]
    df = pd.DataFrame([{c: r[c] for c in cols} for r in results])
    df.to_csv(path, index=False)
    return df

def plot_bic(df: pd.DataFrame, best_k: int, path: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(df["k"], df["bic"], marker="o", label="BIC")
    ax.axvline(best_k, linestyle="--", color="gray", alpha=0.6,
               label=f"Best K = {best_k} (by Bayesian Information Criterion)")
    ax.set_xlabel("K (number of components)")
    ax.set_ylabel("Information criterion")
    ax.set_title(f"Baseline GMM ({COVARIANCE_TYPE} covariance) — K sweep")
    ax.set_xscale("log", base=2)
    ax.set_xticks(df["k"])
    ax.set_xticklabels(df["k"])
    ax.legend()
    ax.grid(alpha=0.3)
    fig.savefig(path, dpi=120, bbox_inches="tight")
    plt.close(fig)

def main() -> None:
    RESULTS_DIR.mkdir(exist_ok=True)

    X, _words = load_word_vectors(DATA_PATH)

    print(f"\nFitting GMMs for K = {K_VALUES} (covariance={COVARIANCE_TYPE})")
    print_header()

    results: list[dict] = []
    for k in K_VALUES:
        try:
            r = fit_one(X, k)
            results.append(r)
            print_row(r)
        except Exception as e:
            print(f"{k:>5}   FAILED: {e}")
    
    if not results:
        print("\nAll fits failed; nothing to save.")
        return
    
    summary_csv = RESULTS_DIR / "baseline_bic.csv"
    summary_df = save_summary_csv(results, summary_csv)
    print(f"\nResults table -> {summary_csv}")

    best = min(results, key=lambda r: r["bic"])
    best_path = RESULTS_DIR / f"baseline_gmm_k{best['k']}.joblib"
    joblib.dump(best["model"], best_path)
    print(f"Best model    -> {best_path}  (K={best['k']}, BIC={best['bic']:.2f})")

    plot_path = RESULTS_DIR / "baseline_bic.png"
    plot_bic(summary_df, best["k"], plot_path)
    print(f"Elbow plot    -> {plot_path}")


if __name__ == "__main__":
    main()