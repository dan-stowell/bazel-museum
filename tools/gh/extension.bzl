"""Module extension that fetches a hermetic, pinned `gh` (GitHub CLI).

We download official release tarballs from github.com/cli/cli and expose the
`gh` binary as a filegroup. Pinning the version + sha256 keeps builds
reproducible and removes any dependency on a host-installed `gh`.

Currently linux/amd64 and linux/arm64 are wired up. To bump the version,
update GH_VERSION and the sha256 values (from the release's
`gh_<version>_checksums.txt`).
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

GH_VERSION = "2.95.0"

# platform key (as it appears in the release asset name) -> sha256 of the tarball.
GH_SHA256 = {
    "linux_amd64": "25d1e4729e8808c9ed3d613e96ebd3f3e44446f2d368c89d878a71a36ddb3d8c",
    "linux_arm64": "d41e0b3b6218e5741c8bb4db39b16e53a59e0e06299a8489bd38f623ef7ebaae",
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
    for platform, sha256 in GH_SHA256.items():
        name = "gh_{v}_{p}".format(v = GH_VERSION, p = platform)
        http_archive(
            name = "gh_cli_" + platform,
            urls = ["https://github.com/cli/cli/releases/download/v{v}/{n}.tar.gz".format(
                v = GH_VERSION,
                n = name,
            )],
            sha256 = sha256,
            strip_prefix = name,
            build_file_content = _BUILD_FILE,
        )

gh_extension = module_extension(implementation = _gh_extension_impl)
