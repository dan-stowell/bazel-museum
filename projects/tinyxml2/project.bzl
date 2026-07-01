load("//kiss:defs.bzl", "LOCAL", "RBE", "bcr_module_source", "build_spec", "project_spec", "test_spec")
# TinyXML-2 — small, efficient C++ XML parser (leethomason/tinyxml2). A "BCR
# module" project running its own @tinyxml2 targets (incl. the xmltest suite).
# LOCAL uses the ambient host gcc; RBE uses hermetic LLVM. BCR 11.0.0.
TINYXML2_PROJECT = project_spec(
    name = "tinyxml2",
    source = bcr_module_source(
        module = "tinyxml2",
        version = "11.0.0",
    ),
    environments = [LOCAL, RBE],
    build = build_spec(targets = ["@tinyxml2"], flags = ["-c", "opt"]),
    test = test_spec(targets = ["@tinyxml2//:xmltest"], flags = ["-c", "opt"]),
)
