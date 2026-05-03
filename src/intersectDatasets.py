import numpy as np
affect_vec = np.genfromtxt( "./datafiles/AffectVec-data.tsv", delimiter="\t", dtype=str)
word_vec = np.genfromtxt( "./datafiles/reduced_WordVec.tsv", delimiter="\t", dtype=str)
affect_vec_words = affect_vec[1:,0]
word_vec_words = word_vec[1:,0]
print(affect_vec_words)
print(word_vec_words)
intersection = np.intersect1d(affect_vec_words, word_vec_words)
print(intersection)
is_in = np.isin(affect_vec_words, intersection)
print(is_in)
reduced_affect_vecs = affect_vec[np.insert(is_in, 0, True)]

np.savetxt("./datafiles/AffectVec-data.tsv", reduced_affect_vecs, fmt='%s', delimiter="\t")
