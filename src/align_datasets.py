from pathlib import Path
import shutil
import sys
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
AFFECT_PATH = ROOT / "datafiles" / "AffectVec-data.tsv"
WORD_PATH = ROOT / "datafiles" / "reduced_WordVec.tsv"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".bak")
    if bak.exists():
        print(f"Backup already exists (not overwriting): {bak.name}")
    else:
        shutil.copy2(path, bak)
        print(f"Backup: {path.name} -> {bak.name}")

def main() -> None:
    if not AFFECT_PATH.exists():
        sys.exit(f"Missing: {AFFECT_PATH}")
    if not WORD_PATH.exists():
        sys.exit(f"Missing: {WORD_PATH}")

    print("Backing up originals ...")
    backup(AFFECT_PATH)
    backup(WORD_PATH)

    print(f"\nLoading {AFFECT_PATH.name} ...")
    affect_df = pd.read_csv(AFFECT_PATH, sep="\t")
    print(f"{len(affect_df)} rows, {len(affect_df.columns) - 1} affect dimensions")

    print(f"Loading {WORD_PATH.name} ...")
    word_df = pd.read_csv(WORD_PATH, sep="\t")
    print(f"{len(word_df)} rows, {len(word_df.columns) - 1} word2vec dimensions")
    
    # De-duplicate any words.
    n_aff = len(affect_df)
    n_word = len(word_df)
    affect_df = affect_df.dropna(subset=["word"]).drop_duplicates(subset="word", keep="first")
    word_df = word_df.dropna(subset=["word"]).drop_duplicates(subset="word", keep="first")
    if len(affect_df) != n_aff:
        print(f"Dropped {n_aff - len(affect_df)} duplicate words from AffectVec")
    if len(word_df) != n_word:
        print(f"Dropped {n_word - len(word_df)} duplicate words from WordVec")

    affect_words = set(affect_df["word"])
    word_words = set(word_df["word"])
    intersection = affect_words & word_words

    # Filter both to the intersection.
    affect_aligned = (
        affect_df[affect_df["word"].isin(intersection)]
        .sort_values("word")
        .reset_index(drop=True)
    )
    word_aligned = (
        word_df[word_df["word"].isin(intersection)]
        .sort_values("word")
        .reset_index(drop=True)
    )

    # Checking
    assert len(affect_aligned) == len(word_aligned), "Row counts differ after alignment"
    assert (affect_aligned["word"].values == word_aligned["word"].values).all(), \
        "Words differ at the same index after alignment"

    affect_aligned.to_csv(AFFECT_PATH, sep="\t", index=False)
    word_aligned.to_csv(WORD_PATH, sep="\t", index=False)

if __name__ == "__main__":
    main()