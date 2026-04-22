#!/usr/bin/env python3
import sys
from gensim.models import KeyedVectors

def main():
    if len(sys.argv) < 3:
        print("usage: script.py <model.bin> <word1> [word2 ...]", file=sys.stderr)
        sys.exit(1)

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
            print(f"# OOV: {w}", file=sys.stderr)

if __name__ == "__main__":
    main()
