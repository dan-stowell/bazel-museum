"""Module extension that fetches a hermetic, pinned `actiond` worker binary.

actiond (github.com/hermeticbuild/actiond) is a local Remote Execution API
worker + cache: it boots a small Linux VM and runs Bazel actions inside it, so
the host acts as a local Linux remote-execution worker. The museum uses it as an
execution *environment* (`ACTIOND`, see //builds:environments.bzl): inner builds
point `--remote_executor`/`--remote_cache` at a locally-run actiond and pin the
target platform to linux/arm64, so we can build+test the museum's projects for
linux without leaving this macOS host.

We pin the release binary (version + sha256) and download the official asset,
exactly like the hermetic `gh` and inner Bazel binaries. The VM kernel,
initramfs, and runtime image are embedded in the release binary, so nothing else
is needed to serve the worker.

Each release asset is a single executable, so we expose it via http_file. The
host that runs the worker selects its own binary (darwin arm64 here; the linux
binaries are pinned too so a linux host can serve the same way).
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

ACTIOND_VERSION = "0.0.6"

# repo suffix -> (release asset name, sha256). From the release's SHA256.txt.
_ACTIOND = {
    "darwin_arm64": ("darwin-actiond_macos_arm64", "4e929779d2eb119a011809c0bc0b2349f16167dadd917078bb9be2b68c615157"),
    "linux_arm64": ("linux-actiond_linux_arm64", "13282b589d03a474fc2f6074f36f1f7beac26850d84db716b409b8e4b95e99b5"),
    "linux_amd64": ("linux-actiond_linux_x86_64", "006dc798d4363596fe8ab997606fc93766a0cc427c2d005cf4fc1765fa4c2052"),
}

def _actiond_impl(_ctx):
    for suffix, (asset, sha256) in _ACTIOND.items():
        http_file(
            name = "actiond_" + suffix,
            urls = ["https://github.com/hermeticbuild/actiond/releases/download/v{v}/{a}".format(
                v = ACTIOND_VERSION,
                a = asset,
            )],
            sha256 = sha256,
            executable = True,
            downloaded_file_path = "actiond",
        )

actiond = module_extension(implementation = _actiond_impl)
