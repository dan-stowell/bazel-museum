load("//kiss:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# libcreate — C++ driver for iRobot Create/Roomba (AutonomyLab/libcreate).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier on LOCAL +
# LOCAL with the ambient toolchain — no hermetic LLVM.
LIBCREATE_PROJECT = project_spec(
    name = "libcreate",
    source = bcr_module_source(
        module = "libcreate",
        version = "3.1.0",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@libcreate//:create_test"], flags = ["-c", "opt"]),
)
