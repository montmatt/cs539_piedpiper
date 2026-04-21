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

lib.deinit.argtypes = []

lib.numAffectVecCols.argtypes = []
lib.numAffectVecCols.restype  = ctypes.c_uint64
