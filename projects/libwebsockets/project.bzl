load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# libwebsockets — lightweight C WebSocket/HTTP library (warmcat/libwebsockets).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic reached for only when needed.)
LIBWEBSOCKETS_PROJECT = project_spec(
    name = "libwebsockets",
    source = bcr_module_source(
        module = "libwebsockets",
        version = "4.5.2",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@libwebsockets//..."], flags = ["-c", "opt"]),
)
