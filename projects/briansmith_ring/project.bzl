load("//kiss:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# ring — Rust crypto primitives (briansmith/ring).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic reached for only when needed.)
BRIANSMITH_RING_PROJECT = project_spec(
    name = "briansmith_ring",
    source = bcr_module_source(
        module = "briansmith_ring",
        version = "0.17.14.bcr.1",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@briansmith_ring//..."], flags = ["-c", "opt"]),
)
