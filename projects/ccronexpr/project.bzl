load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# ccronexpr — cron expression parser in C (exander77/supertinycron).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier on LOCAL +
# LOCAL with the ambient toolchain — no hermetic LLVM.
CCRONEXPR_PROJECT = project_spec(
    name = "ccronexpr",
    source = bcr_module_source(
        module = "ccronexpr",
        version = "2.1.0",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@ccronexpr//:ccronexpr_test"], flags = ["-c", "opt"]),
)
