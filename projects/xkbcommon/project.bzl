load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# libxkbcommon — keyboard keymap handling in C (xkbcommon/libxkbcommon).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic reached for only when needed.)
XKBCOMMON_PROJECT = project_spec(
    name = "xkbcommon",
    source = bcr_module_source(
        module = "xkbcommon",
        version = "1.9.2.bcr.beta.1",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@xkbcommon//:xkbcommon_headers_consumer_compile_test"], flags = ["-c", "opt"]),
)
