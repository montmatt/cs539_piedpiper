#!/usr/bin/env python3
import sys
from gensim.models import KeyedVectors
import numpy as np

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--help":
        print("usage:\ninteractive: preprocess-wordbin.py <model.bin> <words>\nautomatic: preprocess-wordbin.py to automatically", file=sys.stderr)
    elif len(sys.argv) < 3:
        affect_vec = np.genfromtxt( "./datafiles/AffectVec-data.tsv", delimiter="\t", dtype=str)
        words = affect_vec[1:,0]
        print(words)

        with open("./datafiles/reduced_WordVec.tsv", 'w') as f:
            bintotsv("./datafiles/GoogleNews-vectors-negative300.bin", words, f)
    else:
        model_path = sys.argv[1]
        words = sys.argv[2:]
        bintotsv(model_path, words, sys.stdout)

def bintotsv(model_path, words, out):
        model = KeyedVectors.load_word2vec_format(model_path, binary=True)

        dim = model.vector_size

        print("word\t" + "\t".join(f"d{i}" for i in range(dim)), file=out)

        for w in words:
            if w in model:
                vec = model[w]
                row = "\t".join(f"{x:.6f}" for x in vec)
                print(f"{w}\t{row}", file=out)
            else:
                print(f"Could not find word: {w}")

if __name__ == "__main__":
    main()
