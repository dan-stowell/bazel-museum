load("//bazel_runner:defs.bzl", "HERMETIC_LLVM", "LOCAL", "PLATFORMS_DEP", "RBE", "build_spec", "project_spec", "tarball_source", "test_spec")
# abseil-py — Google's Python common libraries (application/flags/logging/testing),
# the Python sibling of the C++ //projects/abseil_cpp. Source pinned in
# //bazel_runner:extension.bzl (@abseil_py_archive, release v2.4.0). First-party
# Bazel: built and tested with rules_python on a hermetic interpreter. It's pure
# Python (no C code), so HERMETIC_LLVM is only a no-op registration; PLATFORMS_DEP
# supplies @platforms visibility for the injected RBE platform (abseil-py's MODULE
# declares no direct platforms dep).
#
#   bazel run //projects/abseil_py:build_local_linux_amd64
#   bazel run //projects/abseil_py:test_local_linux_amd64
ABSEIL_PY_PROJECT = project_spec(
    name = "abseil_py",
    source = tarball_source(
        archive = "@abseil_py_archive//file",
        strip_prefix = "abseil-py-2.4.0",
    ),
    toolchains = [HERMETIC_LLVM, PLATFORMS_DEP],
    bazel_version = "8.7.0",
    environments = [LOCAL, RBE],
    # The whole absl Python package tree (app, flags, logging, testing helpers).
    build = build_spec(targets = ["//absl/..."]),
    # abseil-py's py_test suite across flags, logging, testing and the top-level
    # app/command-name/version tests.
    test = test_spec(
        targets = ["//absl/..."],
        # flags_test's test_method_flagfiles_no_permissions chmods a flagfile
        # unreadable and expects the open to fail; RBE executors run actions
        # as root, which ignores file permissions, so the test only fails
        # off-host.
        exclude_on = {
            "rbe": ["//absl/flags:tests/flags_test"],
        },
    ),
)
