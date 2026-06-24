"""Canonical (os, arch) platforms the museum can target.

Each entry carries the bits the different layers need:

  * `os` / `arch`            — the tokens used in target names (e.g. `linux_amd64`).
  * `os_constraint` / `cpu_constraint` — Bazel platform constraint_values, used
    both to gate host-only (`local`) goals via target_compatible_with and to
    define the injected RBE platforms.
  * `config_setting`         — the //builds os+cpu config_setting (see
    //builds:BUILD.bazel), used to pick the matching inner Bazel binary.
  * `rbe_exec_properties`    — the BuildBuddy executor properties for this
    platform (executor image / pool). Carried on the injected RBE platform so an
    action lands on the right executor.

To support a new (os, arch), add an entry here, a matching config_setting in
//builds:BUILD.bazel, a `platform(...)` in
//tools/buildrunner/overlays:rbe_platforms.BUILD.bazel, and (for RBE) make sure
the environment lists it (see //builds:environments.bzl).
"""

_LINUX = "@platforms//os:linux"
_OSX = "@platforms//os:osx"
_X86_64 = "@platforms//cpu:x86_64"
_ARM64 = "@platforms//cpu:arm64"

# Default BuildBuddy linux executor image. Only needs a modern-enough glibc to
# run the prebuilt hermetic clang (their default Ubuntu 16.04 image is too old).
_RBE_LINUX_IMAGE = "docker://gcr.io/flame-public/rbe-ubuntu20-04:latest"

def _platform(os, arch, os_constraint, cpu_constraint, rbe_exec_properties):
    name = "{}_{}".format(os, arch)
    return struct(
        name = name,
        os = os,
        arch = arch,
        os_constraint = os_constraint,
        cpu_constraint = cpu_constraint,
        config_setting = "//builds:" + name,
        rbe_exec_properties = rbe_exec_properties,
    )

PLATFORMS = {p.name: p for p in [
    _platform("linux", "amd64", _LINUX, _X86_64, {
        "OSFamily": "Linux",
        "container-image": _RBE_LINUX_IMAGE,
    }),
    _platform("linux", "arm64", _LINUX, _ARM64, {
        "OSFamily": "Linux",
        "container-image": _RBE_LINUX_IMAGE,
    }),
    # macOS executors are a separate BuildBuddy capability (mac executor pool);
    # the properties below are a starting point for when that is enabled.
    _platform("darwin", "arm64", _OSX, _ARM64, {
        "OSFamily": "Darwin",
        "Arch": "arm64",
    }),
    _platform("darwin", "amd64", _OSX, _X86_64, {
        "OSFamily": "Darwin",
        "Arch": "amd64",
    }),
]}
