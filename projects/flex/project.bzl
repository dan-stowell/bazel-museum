load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# flex — the fast lexical-analyzer generator in C (westes/flex).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic not wired: reach for it only when needed.)
FLEX_PROJECT = project_spec(
    name = "flex",
    source = bcr_module_source(
        module = "flex",
        version = "2.6.4.bcr.5",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@flex//..."], flags = ["-c", "opt"]),
)
