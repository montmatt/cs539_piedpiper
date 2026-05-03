from declarations import *

aVecStr = "datafiles/compressed_AffectVec"
wVecStr = "datafiles/compressed_WordVec"
res = init(aVecStr, wVecStr, 32)

ACols = numAffectVecCols()
print(f"From python, we know there are {ACols} columns in the AffectVec database")

print(f"There are {numDataPoints()} data points in the database")

# set some values in the responsibility vec,
# and check if the sum of the responsibility values is correct
for i in range(2):
    setResponsibilityValue(0, i, 0.5)
    setResponsibilityValue(1, i, 0.5)
    # setResponsibilityValue(2, i, 0.3)
    # setResponsibilityValue(3, i, 0.4)

for i in range(4):
    print(f"Sum of responsibility values for cluster {i}: {sumResponsibility(i)}")

setResponsibilityValue(2, 3, 0.2)
print(f"Responsibility value for data point 2, cluster 3: {getResponsibilityValue(2, 3)}")

print(f"Average affect vector weighted by responsibility: {sumAffectVecWeightResponsibility(0)}")

deinit()
