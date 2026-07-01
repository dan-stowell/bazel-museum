load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# HFSM2 — header-only C++ hierarchical finite-state-machine library (andrew-gresyk/HFSM2).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic reached for only when needed.)
HFSM2_PROJECT = project_spec(
    name = "hfsm2",
    source = bcr_module_source(
        module = "hfsm2",
        version = "2.10.0",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@hfsm2//:hfsm2_test"], flags = ["-c", "opt"]),
)
