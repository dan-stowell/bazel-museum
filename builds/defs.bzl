"""`museum_project` / `goal`: declare isolated, daemonless inner Bazel builds.

A *project* pins a source tarball and a set of base overlays; each *goal* is a
`bazel run`-nable target running one inner command (build/test) over some
targets, composing the project's base overlays with its own. See
//builds/overlays.bzl for what an overlay is.

Example:

    load("//builds:defs.bzl", "goal", "museum_project")
    load("//builds:overlays.bzl", "HERMETIC_LLVM")

    museum_project(
        name = "cxx",
        source_archive = "@cxx_archive//file",
        strip_prefix = "cxx-1.0.194",
        overlays = [HERMETIC_LLVM],                       # every goal gets these
        goals = [
            goal("build", targets = ["//:cxx", "//:core"]),
            goal("test", command = "test", targets = ["//..."]),
        ],
    )

    # then: bazel run //builds/cxx:build
    #       bazel run //builds/cxx:test
    #       bazel run //builds/cxx:build -- //:cxx          (override targets)
    #       bazel run //builds/cxx:test  -- --runs_per_test=3
"""

load("@rules_python//python:defs.bzl", "py_binary")

# Per-OS+CPU selection of the pinned inner Bazel binary (data dep + runfiles
# path). We key on os *and* cpu because the official release binaries differ per
# platform: a cpu-only select would, e.g., match the linux arm64 binary on a
# macOS arm64 host. The config settings are defined in //builds:BUILD.bazel.
_INNER_BAZEL_DATA = select({
    "//builds:linux_amd64": ["@inner_bazel_linux_amd64//file"],
    "//builds:linux_arm64": ["@inner_bazel_linux_arm64//file"],
    "//builds:darwin_amd64": ["@inner_bazel_darwin_amd64//file"],
    "//builds:darwin_arm64": ["@inner_bazel_darwin_arm64//file"],
})
_INNER_BAZEL_ARG = select({
    "//builds:linux_amd64": ["--bazel=$(rlocationpath @inner_bazel_linux_amd64//file)"],
    "//builds:linux_arm64": ["--bazel=$(rlocationpath @inner_bazel_linux_arm64//file)"],
    "//builds:darwin_amd64": ["--bazel=$(rlocationpath @inner_bazel_darwin_amd64//file)"],
    "//builds:darwin_arm64": ["--bazel=$(rlocationpath @inner_bazel_darwin_arm64//file)"],
})

# Sensible defaults per command so `bazel test` shows failures and keeps going
# (so we see how many targets pass). Goals/overlays can override via later flags.
_COMMAND_DEFAULT_FLAGS = {
    "test": [
        "--test_output=errors",
        "--keep_going",
        # Pin a UTF-8 locale for test actions: hermetic and reproducible, and it
        # fixes JVM sun.jnu.encoding so tests touching Unicode file paths pass
        # regardless of the host's locale.
        "--test_env=LC_ALL=C.UTF-8",
        "--test_env=LANG=C.UTF-8",
    ],
}

def goal(name, targets, command = "build", overlays = [], build_flags = []):
    """A single runnable goal: one inner command over some targets + overlays."""
    return struct(
        name = name,
        command = command,
        targets = targets,
        overlays = overlays,
        build_flags = build_flags,
    )

def _dedupe(items):
    seen = {}
    out = []
    for it in items:
        if it not in seen:
            seen[it] = True
            out.append(it)
    return out

def _emit_goal(project_id, source_archive, strip_prefix, base_overlays, g, visibility):
    overlays = base_overlays + g.overlays

    appends = []        # (label, dest)
    patch_labels = []
    overlay_flags = []
    header_envs = []
    for ov in overlays:
        appends += ov.appends
        patch_labels += ov.patches
        overlay_flags += ov.build_flags
        header_envs += ov.remote_header_envs

    args = [
        "--name={}__{}".format(project_id, g.name),
        "--command=" + g.command,
        "--source-archive=$(rlocationpath {})".format(source_archive),
    ]
    if strip_prefix:
        args.append("--strip-prefix=" + strip_prefix)
    for label, dest in appends:
        args.append("--append=$(rlocationpath {})={}".format(label, dest))
    for label in patch_labels:
        args.append("--patch=$(rlocationpath {})".format(label))
    for spec in header_envs:
        args.append("--remote-header-env=" + spec)
    for flag in _COMMAND_DEFAULT_FLAGS.get(g.command, []) + overlay_flags + g.build_flags:
        args.append("--build-flag=" + flag)
    for target in g.targets:
        args.append("--target=" + target)

    overlay_files = _dedupe([label for label, _ in appends] + patch_labels)
    data = [source_archive] + overlay_files + _INNER_BAZEL_DATA

    py_binary(
        name = g.name,
        srcs = ["//tools/buildrunner:runner.py"],
        main = "runner.py",
        deps = ["@rules_python//python/runfiles"],
        data = data,
        args = args + _INNER_BAZEL_ARG,
        visibility = visibility,
    )

def museum_project(
        name,
        source_archive,
        goals,
        strip_prefix = "",
        overlays = [],
        visibility = ["//visibility:public"]):
    """Declare a museum project and its goals.

    Args:
      name: project name (informational; the package path also identifies it).
      source_archive: label of the pinned source tarball (e.g. "@cxx_archive//file").
      goals: list of goal(...) structs; each becomes a `bazel run`-nable target.
      strip_prefix: top-level directory inside the tarball = workspace root.
      overlays: base overlays applied to every goal (e.g. [HERMETIC_LLVM]).
      visibility: visibility for the generated goal targets.
    """

    # Unique per-project id, derived from the package path so two projects'
    # goals (e.g. both named "build") don't collide on the build root.
    project_id = (native.package_name().replace("/", "_") or name)
    for g in goals:
        _emit_goal(project_id, source_archive, strip_prefix, overlays, g, visibility)
