"""KISS-only project macros.

The project BUILD files still describe build/test target patterns with
`museum_project(...)`, but this trimmed repo only emits `:kiss_source`,
`:kiss_build`, and `:kiss_test` for source-archive projects.
"""

load("//kiss:defs.bzl", "extract_source", "inner_bazel", "inner_bazel_arg", "inner_bazel_data", "kiss_build", "kiss_test")
load("//kiss:extension.bzl", "DEFAULT_INNER_BAZEL_VERSION")

def build_spec(targets, flags = [], exclude_on = {}, emit_artifacts = True):
    return struct(
        command = "build",
        targets = targets,
        flags = flags,
        exclude_on = exclude_on,
        emit_artifacts = emit_artifacts,
    )

def test_spec(targets, flags = [], exclude_on = {}):
    return struct(
        command = "test",
        targets = targets,
        flags = flags,
        exclude_on = exclude_on,
    )

def _emit_kiss_targets(source_archive, strip_prefix, build, test, bazel_version, visibility):
    extract_source(
        name = "kiss_source",
        archive = source_archive,
        strip_prefix = strip_prefix,
    )

    bazel = inner_bazel(bazel_version)
    if build:
        kiss_build(
            name = "kiss_build",
            source = ":kiss_source",
            bazel = bazel,
            targets = build.targets,
            visibility = visibility,
        )
    if test:
        kiss_test(
            name = "kiss_test",
            source = ":kiss_source",
            targets = test.targets,
            bazel_data = inner_bazel_data(bazel_version),
            bazel_arg = inner_bazel_arg(bazel_version),
            visibility = visibility,
        )

def museum_project(
        name,
        source_archive,
        environments,
        build = None,
        test = None,
        strip_prefix = "",
        toolchains = [],
        bazel_version = DEFAULT_INNER_BAZEL_VERSION,
        clients = None,
        visibility = ["//visibility:public"]):
    """Declare a source-backed project's KISS targets."""
    if clients:
        fail("KISS-only museum_project does not support clients=; use bazel_version=")
    _emit_kiss_targets(source_archive, strip_prefix, build, test, bazel_version, visibility)

def project_test(
        name,
        source_archive,
        test,
        strip_prefix = "",
        toolchains = [],
        bazel_version = DEFAULT_INNER_BAZEL_VERSION,
        clients = None,
        visibility = ["//visibility:public"]):
    """Deprecated compatibility helper; emits only a KISS test target."""
    _emit_kiss_targets(source_archive, strip_prefix, None, test, bazel_version, visibility)

def bcr_project(
        name,
        module,
        version,
        environments,
        build = None,
        test = None,
        toolchains = None,
        rbe_toolchains = None,
        bazel_version = DEFAULT_INNER_BAZEL_VERSION,
        clients = None,
        visibility = ["//visibility:public"]):
    """Compatibility no-op.

    BCR projects do not have pinned source archives in this repo, so there is no
    `kiss_source`/`kiss_build`/`kiss_test` target to emit for them.
    """
    pass
