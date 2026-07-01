load("//kiss:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# Reflexxes RMLTypeII — online trajectory generation in C++ (Reflexxes).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier on LOCAL +
# LOCAL with the ambient toolchain — no hermetic LLVM.
REFLEXXES_RMLTYPE2_PROJECT = project_spec(
    name = "reflexxes-rmltype2",
    source = bcr_module_source(
        module = "reflexxes-rmltype2",
        version = "1.2.7",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@reflexxes-rmltype2//:01_RMLPositionSampleApplication"], flags = ["-c", "opt"]),
)
