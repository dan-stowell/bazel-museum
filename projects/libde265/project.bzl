load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# libde265 — H.265/HEVC video decoder in C++ (strukturag/libde265).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic reached for only when needed.)
LIBDE265_PROJECT = project_spec(
    name = "libde265",
    source = bcr_module_source(
        module = "libde265",
        version = "1.0.18",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@libde265//..."], flags = ["-c", "opt"]),
)
