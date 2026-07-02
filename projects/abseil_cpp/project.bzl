load("//bazel_runner:defs.bzl", "LOCAL", "RBE", "build_spec", "project_spec", "tarball_source", "test_spec")

# Abseil's C++ common libraries — the matrix's first build.
# Source pinned in //bazel_runner:extension.bzl (@absl_archive, release
# 20260526.0), built from the upstream source/module as-is. The hermetic
# LLVM modification lives in //projects/abseil_cpp/hermetic_llvm.
#
ABSEIL_CPP_PROJECT = project_spec(
    name = "abseil_cpp",
    source = tarball_source(
        archive = "@absl_archive//file",
        strip_prefix = "abseil-cpp-20260526.0",
    ),
    environments = [LOCAL, RBE],
    build = build_spec(targets = ["//absl/..."], flags = ["-c", "opt"]),
    test = test_spec(
        targets = ["//absl/..."],
        # The cctz tests bundle testdata/zoneinfo as runfiles data; TZDIR makes
        # them read that (resolved relative to the test cwd in runfiles)
        # instead of the host /usr/share/zoneinfo, which RBE executor images
        # do not ship.
        flags = ["--test_env=TZDIR=absl/time/internal/cctz/testdata/zoneinfo"],
        # time_test has no zoneinfo data dep of its own, so off-host it still
        # has no timezone database to read. A hermetic tzdata input upstream
        # would re-include it.
        exclude_on = {
            "rbe": ["//absl/time:time_test"],
        },
    ),
)
