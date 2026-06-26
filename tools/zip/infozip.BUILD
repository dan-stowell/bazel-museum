# Build the Info-ZIP `zip` CLI from source as a hermetic, pinned tool.
#
# Some museum projects' builds shell out to `zip` (notably Bazel itself: its
# genrules call `zip` ~72x to assemble the embedded install base). Rather than
# require a host `zip`, we build one from Info-ZIP's pinned source with the
# museum's hermetic LLVM toolchain and inject it on the inner build's PATH (see
# HERMETIC_ZIP in //builds:overlays.bzl + --tool in //tools/buildrunner).
#
# Object set mirrors Info-ZIP's unix `generic` target (unix/Makefile): OBJZ +
# OBJI, compiling unix/unix.c for the platform layer. No ASM (pure C), and no
# BZIP2_SUPPORT, so zbz2err.c compiles to stubs and we need no libbz2.

load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "zip",
    srcs = [
        "zip.c",
        "zipfile.c",
        "zipup.c",
        "fileio.c",
        "util.c",
        "globals.c",
        "crypt.c",
        "ttyio.c",
        "crc32.c",
        "zbz2err.c",
        "deflate.c",
        "trees.c",
        "unix/unix.c",
    ] + glob(["*.h", "unix/*.h"]),
    copts = [
        "-DUNIX",
        # Info-ZIP is pre-C99 K&R-ish C; a modern clang otherwise errors on
        # implicit declarations/ints. Build it in gnu89 and downgrade those.
        "-std=gnu89",
        "-w",
    ],
    # Dynamic (hermetic glibc ships no libc.a, so -static can't link). The binary
    # NEEDs libc/libm/libpthread by soname with no rpath, so it resolves against
    # whatever glibc the run host has (built against 2.28; glibc is backward-
    # compatible). It runs standalone and inside the inner build's Tier-1 sandbox,
    # which mounts host / read-only — so the interpreter + libs are present there.
    linkopts = [],
    visibility = ["//visibility:public"],
)
