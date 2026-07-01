load("//kiss:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# BehaviorTree.CPP — C++ behavior-tree library (BehaviorTree/BehaviorTree.CPP).
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic not wired: reach for it only when needed.)
BEHAVIORTREE_CPP_PROJECT = project_spec(
    name = "behaviortree_cpp",
    source = bcr_module_source(
        module = "behaviortree_cpp",
        version = "4.7.0.bcr.3",
    ),
    bazel_version = "8.7.0",
    environments = [LOCAL],
    test = test_spec(targets = ["@behaviortree_cpp//:behaviortree_cpp_test"], flags = ["-c", "opt"]),
)
