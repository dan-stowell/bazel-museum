load("//kiss:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# CxxUrl — a small C++ URL parser (chmike/CxxUrl).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier on LOCAL +
# LOCAL with the ambient toolchain — no hermetic LLVM.
CXXURL_PROJECT = project_spec(
    name = "cxxurl",
    source = bcr_module_source(
        module = "cxxurl",
        version = "0.3",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@cxxurl//:test"], flags = ["-c", "opt"]),
)
