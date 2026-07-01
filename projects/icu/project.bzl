load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# ICU — International Components for Unicode, C/C++ (unicode-org/icu).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic reached for only when needed.)
ICU_PROJECT = project_spec(
    name = "icu",
    source = bcr_module_source(
        module = "icu",
        version = "78.2.bcr.1",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@icu//bcr/..."], flags = ["-c", "opt"]),
)
