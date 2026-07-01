load("//kiss:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# libheif — HEIF/AVIF image codec in C++ (strukturag/libheif).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic reached for only when needed.)
LIBHEIF_PROJECT = project_spec(
    name = "libheif",
    source = bcr_module_source(
        module = "libheif",
        version = "1.21.2",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@libheif//..."], flags = ["-c", "opt"]),
)
