"""Heuristics to tell real *projects* apart from Bazel rulesets / tooling.

The awesome-bazel lists already curate a "projects" section, so entries from
there are trusted as projects. The Bazel Central Registry, however, is full of
rulesets and tooling (rules_go, bazel_skylib, ...) mixed with real OSS projects
(abseil-cpp, grpc, protobuf, ...). These heuristics filter the registry.

They are intentionally conservative and explainable: every decision returns a
human-readable reason so the output can be audited and the rules tuned.
"""

from . import model

# Owners that almost exclusively publish Bazel rules/tooling, not end projects.
_TOOLING_OWNERS = {
    "bazelbuild",
    "bazel-contrib",
    "aspect-build",
}

# Substrings that strongly indicate a ruleset or Bazel-tooling module.
_RULESET_HINTS = ("rules_", "_rules", "-rules", "rules-")
_TOOLING_HINTS = (
    "bazel_",
    "_bazel",
    "bazel-",
    "-bazel",
    "toolchain",
    "gazelle",
    "stardoc",
    "buildtools",
    "buildifier",
    "skylib",
)

# Specific module names that are tooling/infra despite not matching above.
_KNOWN_TOOLING = {
    "platforms",
    "apple_support",
    "bazel_features",
    "bazel_skylib",
    "stardoc",
}


def classify_bcr(module_name, owner):
    """Return (category, reason) for a Bazel Central Registry module."""
    name = module_name.lower()
    own = (owner or "").lower()

    if name in _KNOWN_TOOLING:
        return model.CATEGORY_TOOLING, f"known Bazel tooling module '{module_name}'"

    for hint in _RULESET_HINTS:
        if hint in name:
            return model.CATEGORY_RULESET, f"module name contains '{hint}'"

    for hint in _TOOLING_HINTS:
        if hint in name:
            return model.CATEGORY_TOOLING, f"module name contains '{hint}'"

    if own in _TOOLING_OWNERS:
        return (
            model.CATEGORY_TOOLING,
            f"published by Bazel tooling org '{owner}'",
        )

    return model.CATEGORY_PROJECT, "BCR module not matching ruleset/tooling heuristics"
