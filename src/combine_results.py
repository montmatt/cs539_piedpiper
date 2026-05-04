from pathlib import Path
import sys
import pandas as pd
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"

def merge_csvs(paths: list[Path], out_path: Path, label: str) -> pd.DataFrame | None:
    frames = []
    for p in paths:
        if p.exists():
            frames.append(pd.read_csv(p))
            print(f"Found: {p.name}")
        else:
            print(f"Skipping (not found): {p.name}")
    if not frames:
        print(f"No {label} CSVs found - skipping merge.")
        return None
    df = pd.concat(frames, ignore_index=True)
    df = df.drop_duplicates(subset="k", keep="first").sort_values("k").reset_index(drop=True)
    df.to_csv(out_path, index=False)
    print(f"Wrote: {out_path.name}  ({len(df)} rows)")
    return df


def plot_bic(base: pd.DataFrame, mod: pd.DataFrame, out_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(9, 5))
    if base is not None:
        ax.plot(base["k"], base["bic"], "s-", label="Baseline GMM", color="C0")
    ax.plot(mod["k"], mod["bic"], "o-", label="Modified GMM (with S(m,h))", color="C1")

    all_k = sorted(set(mod["k"]) | (set(base["k"]) if base is not None else set()))
    ax.set_xscale("log", base=2)
    ax.set_xticks(all_k)
    ax.set_xticklabels(all_k)
    ax.set_xlabel("K (number of components)")
    ax.set_ylabel("BIC (lower is better)")
    ax.set_title("Baseline vs Modified GMM - BIC across K")
    ax.legend()
    ax.grid(alpha=0.3)
    fig.savefig(out_path, dpi=120, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote: {out_path.name}")


def plot_loglik(base: pd.DataFrame, mod: pd.DataFrame, out_path: Path) -> None:
    if "log_likelihood" not in mod.columns:
        print(f"Skipping {out_path.name}: log_likelihood column missing")
        return
    fig, ax = plt.subplots(figsize=(9, 5))
    if base is not None and "log_likelihood" in base.columns:
        ax.plot(base["k"], base["log_likelihood"], "s-", label="Baseline GMM", color="C0")
    ax.plot(mod["k"], mod["log_likelihood"], "o-", label="Modified GMM", color="C1")

    all_k = sorted(set(mod["k"]) | (set(base["k"]) if base is not None else set()))
    ax.set_xscale("log", base=2)
    ax.set_xticks(all_k)
    ax.set_xticklabels(all_k)
    ax.set_xlabel("K (number of components)")
    ax.set_ylabel("Log-likelihood (higher is better)")
    ax.set_title("Baseline vs Modified GMM - log-likelihood across K")
    ax.legend()
    ax.grid(alpha=0.3)
    fig.savefig(out_path, dpi=120, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote: {out_path.name}")


def plot_bic_delta(base: pd.DataFrame, mod: pd.DataFrame, out_path: Path) -> None:
    if base is None:
        print(f"Skipping {out_path.name}: no baseline data")
        return
    merged = pd.merge(
        base[["k", "bic"]].rename(columns={"bic": "bic_base"}),
        mod[["k", "bic"]].rename(columns={"bic": "bic_mod"}),
        on="k",
    )
    if merged.empty:
        print(f"Skipping {out_path.name}: no overlapping K values")
        return
    merged["delta"] = merged["bic_mod"] - merged["bic_base"]

    fig, ax = plt.subplots(figsize=(9, 4))
    colors = ["C3" if d > 0 else "C2" for d in merged["delta"]]
    ax.bar(range(len(merged)), merged["delta"], tick_label=merged["k"], color=colors)
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_xlabel("K")
    ax.set_ylabel("BIC(modified) - BIC(baseline)")
    ax.set_title("BIC gap")
    ax.grid(alpha=0.3, axis="y")
    fig.savefig(out_path, dpi=120, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote: {out_path.name}")


def main() -> None:
    if not RESULTS.exists():
        sys.exit(f"Results directory not found: {RESULTS}")

    print("=" * 60)
    print("Merging modified GMM CSVs ...")
    mod_inputs = [
        RESULTS / "modified_bic_k2to128.csv",
        RESULTS / "modified_bic_k256to512.csv",
    ]
    mod_full = merge_csvs(mod_inputs, RESULTS / "modified_bic_k2to512.csv", "modified")

    print("\nMerging baseline GMM CSVs ...")
    base_inputs = [
        RESULTS / "baseline_bic.csv",
    ]
    base_full = merge_csvs(base_inputs, RESULTS / "baseline_bic_k2to512.csv", "baseline")

    if mod_full is None:
        sys.exit("No modified data; cannot generate plots.")

    print("\nGenerating plots ...")
    plot_bic(base_full, mod_full, RESULTS / "comparison_bic.png")
    plot_loglik(base_full, mod_full, RESULTS / "comparison_loglik.png")
    plot_bic_delta(base_full, mod_full, RESULTS / "bic_delta.png")

    print("\nFinal merged tables:")
    if base_full is not None:
        print("\nBaseline:")
        print(base_full[["k", "bic", "log_likelihood", "n_iter", "elapsed_sec"]].to_string(index=False))
    print("\nModified:")
    cols = ["k", "bic", "log_likelihood", "n_iter", "elapsed_sec"]
    cols = [c for c in cols if c in mod_full.columns]
    print(mod_full[cols].to_string(index=False))


if __name__ == "__main__":
    main()