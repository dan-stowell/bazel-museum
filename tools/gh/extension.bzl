"""Module extension that fetches a hermetic, pinned `gh` (GitHub CLI).

We download official release tarballs from github.com/cli/cli and expose the
`gh` binary as a filegroup. Pinning the version + sha256 keeps builds
reproducible and removes any dependency on a host-installed `gh`.

linux and darwin, amd64 + arm64, are wired up. To bump the version, update
GH_VERSION and the sha256 values (from the release's
`gh_<version>_checksums.txt`).

Note the per-OS asset naming: linux assets are `..._linux_<arch>.tar.gz`,
while darwin assets are `..._macOS_<arch>.zip`. We key the map by our own
repo suffix (`darwin_*`, matching the rest of the museum) and carry the
asset's platform fragment + archive extension explicitly.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

GH_VERSION = "2.95.0"

# repo suffix -> (asset platform fragment, archive extension, sha256).
GH_PLATFORMS = {
    "linux_amd64": ("linux_amd64", "tar.gz", "25d1e4729e8808c9ed3d613e96ebd3f3e44446f2d368c89d878a71a36ddb3d8c"),
    "linux_arm64": ("linux_arm64", "tar.gz", "d41e0b3b6218e5741c8bb4db39b16e53a59e0e06299a8489bd38f623ef7ebaae"),
    "darwin_amd64": ("macOS_amd64", "zip", "985707e9ac60c95ed51cddd808c338b481abe69fffa77e9d6547c3750045f77e"),
    "darwin_arm64": ("macOS_arm64", "zip", "3677f9c27965825f9c7d50395473c134edaea4b484373ef6b25de653570a0489"),
}

_BUILD_FILE = """\
# Exposes the hermetic gh binary unpacked from the release tarball.
filegroup(
    name = "gh",
    srcs = ["bin/gh"],
    visibility = ["//visibility:public"],
)
"""

def _gh_extension_impl(_ctx):
    for suffix, (asset_platform, ext, sha256) in GH_PLATFORMS.items():
        name = "gh_{v}_{p}".format(v = GH_VERSION, p = asset_platform)
        http_archive(
            name = "gh_cli_" + suffix,
            urls = ["https://github.com/cli/cli/releases/download/v{v}/{n}.{e}".format(
                v = GH_VERSION,
                n = name,
                e = ext,
            )],
            sha256 = sha256,
            strip_prefix = name,
            build_file_content = _BUILD_FILE,
        )

gh_extension = module_extension(implementation = _gh_extension_impl)
