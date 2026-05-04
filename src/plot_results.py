# src/plot_results.py
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"

base = pd.read_csv(RESULTS / "baseline_bic_k2to512.csv")
mod = pd.read_csv(RESULTS / "modified_bic_k2to512.csv")

fig, ax = plt.subplots(figsize=(9, 5))
ax.plot(base["k"], base["bic"], "s-", label="Baseline GMM", color="C0")
ax.plot(mod["k"], mod["bic"], "o-", label="Modified GMM (with S(m,h))", color="C1")
ax.set_xscale("log", base=2)

# Use the union of K values for tick marks
all_k = sorted(set(base["k"]) | set(mod["k"]))
ax.set_xticks(all_k)
ax.set_xticklabels(all_k)

ax.set_xlabel("K (number of components)")
ax.set_ylabel("BIC (lower is better)")
ax.set_title("Baseline vs Modified GMM - BIC across K")
ax.legend()
ax.grid(alpha=0.3)
fig.savefig(RESULTS / "comparison_k2to512.png", dpi=120, bbox_inches="tight")