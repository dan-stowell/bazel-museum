load("//bazel_runner:defs.bzl", "LOCAL", "bcr_module_source", "project_spec", "test_spec")
# OpenSSL — the C TLS/crypto library (openssl/openssl); a foreign_cc heavyweight that builds against the ambient sysroot.
# A "BCR module" project: the runner bazel_dep()s the module from the Bazel
# Central Registry and runs its own presubmit test target. Host tier: builds and
# tests with the ambient toolchain on LOCAL — no
# hermetic LLVM. (RBE/hermetic not wired: reach for it only when needed.)
OPENSSL_PROJECT = project_spec(
    name = "openssl",
    source = bcr_module_source(
        module = "openssl",
        version = "3.5.5.bcr.4",
    ),
    environments = [LOCAL],
    test = test_spec(targets = ["@openssl//..."], flags = ["-c", "opt"]),
)
