import ctypes, sys, os

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

if sys.platform == "win32":
    lib = ctypes.CDLL(os.path.join(base, "zig-out", "bin", "piedpiper.dll"))
elif sys.platform == "darwin":
    lib = ctypes.CDLL(os.path.join(base, "zig-out", "lib", "libpiedpiper.dylib"))
else:
    lib = ctypes.CDLL(os.path.join(base, "zig-out", "lib", "libpiedpiper.so"))

# Declare all functions here
lib.add.argtypes = [ctypes.c_int32, ctypes.c_int32]
lib.add.restype  = ctypes.c_int32