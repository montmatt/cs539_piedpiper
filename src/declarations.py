import ctypes, sys, os

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

if sys.platform == "win32":
    lib = ctypes.CDLL(os.path.join(base, "zig-out", "bin", "piedpiper.dll"))
elif sys.platform == "darwin":
    lib = ctypes.CDLL(os.path.join(base, "zig-out", "lib", "libpiedpiper.dylib"))
else:
    lib = ctypes.CDLL(os.path.join(base, "zig-out", "lib", "libpiedpiper.so"))

# Declare all functions here


lib.init.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
lib.init.restype  = ctypes.c_bool
def init(aVecPath: str, wVecPath: str, numThreads: int) -> bool:
    b_aVecPath = aVecPath.encode('utf-8')
    b_wVecPath = wVecPath.encode('utf-8')
    return lib.init(b_aVecPath, b_wVecPath, numThreads)

lib.deinit.argtypes = []
def deinit():
    lib.deinit()

# get dimensions of the data

lib.numDataPoints.argtypes = []
lib.numDataPoints.restype  = ctypes.c_uint64
def numDataPoints():
    return lib.numDataPoints()

lib.numAffectVecCols.argtypes = []
lib.numAffectVecCols.restype  = ctypes.c_uint64
def numAffectVecCols():
    return lib.numAffectVecCols()

lib.numWordVecCols.argtypes = []
lib.numWordVecCols.restype  = ctypes.c_uint64
def numWordVecCols():
    return lib.numWordVecCols()

# set values in data (Inefficient, but just for testing)

lib.setWordVecValue.argtypes = [ctypes.c_uint64, ctypes.c_uint64, ctypes.c_float]
def setWordVecValue(row: int, col: int, value: float):
    lib.setWordVecValue(row, col, value)

lib.setAffectVecValue.argtypes = [ctypes.c_uint64, ctypes.c_uint64, ctypes.c_float]
def setAffectVecValue(row: int, col: int, value: float):
    lib.setAffectVecValue(row, col, value)

lib.setResponsibilityValue.argtypes = [ctypes.c_uint64, ctypes.c_uint64, ctypes.c_float]
def setResponsibilityValue(row: int, clusterIdx: int, value: float):
    lib.setResponsibilityValue(row, clusterIdx, value)

# Get values from the data (Inefficient, but just for testing)

lib.getWordVecvalue.argtypes = [ctypes.c_uint64, ctypes.c_uint64]
lib.getWordVecvalue.restype  = ctypes.c_float
def getWordVecvalue(row: int, col: int) -> float:
    return lib.getWordVecvalue(row, col)

lib.getAffectVecValue.argtypes = [ctypes.c_uint64, ctypes.c_uint64]
lib.getAffectVecValue.restype  = ctypes.c_float
def getAffectVecValue(row: int, col: int) -> float:
    return lib.getAffectVecvalue(row, col)

lib.getResponsibilityValue.argtypes = [ctypes.c_uint64, ctypes.c_uint64]
lib.getResponsibilityValue.restype  = ctypes.c_float
def getResponsibilityValue(row: int, clusterIdx: int) -> float:
    return lib.getResponsibilityValue(row, clusterIdx)


# Get rows from the data (also inefficient, just for testing)

lib.getWordVecPos.argtypes = [ctypes.c_uint64]
lib.getWordVecPos.restype  = ctypes.POINTER(ctypes.c_float)
def getWordVecPos(row: int) -> list[float]:
    ret = lib.getWordVecPos(row)
    if not ret:
        raise ValueError(f"Failed to get word vector position for row {row}")
    return [ret[i] for i in range(lib.numWordVecCols())]

lib.getAffectVecPos.argtypes = [ctypes.c_uint64]
lib.getAffectVecPos.restype  = ctypes.POINTER(ctypes.c_float)
def getAffectVecPos(row: int) -> list[float]:
    ret = lib.getAffectVecPos(row)
    if not ret:
        raise ValueError(f"Failed to get affect vector position for row {row}")
    return [ret[i] for i in range(lib.numAffectVecCols())]

lib.getResponsibilityVec.argtypes = [ctypes.c_uint64]
lib.getResponsibilityVec.restype  = ctypes.POINTER(ctypes.c_float)
def getResponsibilityVec(row: int) -> list[float]:
    ret = lib.getResponsibilityVec(row)
    if not ret:
        raise ValueError(f"Failed to get responsibility vector for row {row}")
    return [ret[i] for i in range(lib.numDataPoints())]


# Sumations of data values

# Sum the responsibility values for a given cluster
lib.sumResponsibility.argtypes = [ctypes.c_uint64]
lib.sumResponsibility.restype  = ctypes.c_float
def sumResponsibility(clusterIdx: int) -> float:
    return lib.sumResponsibility(clusterIdx)


# Sumations over data vectors

# Sum the word vector values for a given cluster, 
# weighted by the responsibility of each data point 
# to that cluster
lib.sumWordVecWeightResponsibility.argtypes = [ctypes.c_uint64, ctypes.POINTER(ctypes.c_float), ctypes.c_uint64]
lib.sumWordVecWeightResponsibility.restype  = ctypes.c_bool
def sumWordVecWeightResponsibility(clusterIdx: int) -> list[float]:
    sum = [0.0] * lib.numWordVecCols()
    arr_type = ctypes.c_float * len(sum)
    c_wordVec = arr_type(*sum)
    if not lib.sumWordVecWeightResponsibility(clusterIdx, c_wordVec, len(sum)):
        raise ValueError(f"Failed to sum word vector weight responsibility for cluster {clusterIdx}")
    return list(c_wordVec)

# Sum the affect vector values for a given cluster,
# weighted by the responsibility of each data point
# to that cluster
lib.sumAffectVecWeightResponsibility.argtypes = [ctypes.c_uint64, ctypes.POINTER(ctypes.c_float), ctypes.c_uint64]
lib.sumAffectVecWeightResponsibility.restype  = ctypes.c_bool
def sumAffectVecWeightResponsibility(clusterIdx: int) -> list[float]:
    sum = [0.0] * lib.numAffectVecCols()
    print(len(sum))
    arr_type = ctypes.c_float * len(sum)
    c_affectVec = arr_type(*sum)
    if not lib.sumAffectVecWeightResponsibility(clusterIdx, c_affectVec, len(sum)):
        raise ValueError(f"Failed to sum affect vector weight responsibility for cluster {clusterIdx}")
    return list(c_affectVec)


lib.updateResponsibility.argtypes = [ctypes.c_uint64, ctypes.POINTER(ctypes.c_float), ctypes.c_uint64]
def updateResponsibility(clusterIdx: int, emotionVec: list[float]):
    size = len(emotionVec)
    arr = (ctypes.c_int * len(emotionVec))(*emotionVec)
    if not lib.sumAffectVecWeightResponsibility(clusterIdx, arr, size):
        raise ValueError(f"Failed to sum affect vector weight responsibility for cluster {clusterIdx}")