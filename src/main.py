from declarations import lib

aVecStr = "datafiles/compressed_AffectVec"
wVecStr = "my string 2"

# create byte objects from the strings
b_aVecStr = aVecStr.encode('utf-8')
b_wVecStr = wVecStr.encode('utf-8')

# send strings to c function
lib.init(b_aVecStr, b_wVecStr, 32)

ACols = lib.numAffectVecCols()
print(f"From python, we know there are {ACols} columns in the AffectVec database")

lib.deinit()