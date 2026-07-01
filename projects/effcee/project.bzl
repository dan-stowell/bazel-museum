load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# Effcee — C++ stateful pattern matching for test output (google/effcee).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier on LOCAL +
# LOCAL with the ambient toolchain — no hermetic LLVM.
EFFCEE_PROJECT = project_spec(
    name = "effcee",
    source = bcr_module_source(
        module = "effcee",
        version = "0.0.0-20250222",
    ),
    bazel_version = "8.7.0",
    environments = [LOCAL],
    test = test_spec(targets = ["@effcee//..."], flags = ["-c", "opt"]),
)
