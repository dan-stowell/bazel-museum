"""Module extension that fetches Info-ZIP's `zip` source, pinned by sha256.

We build the `zip` CLI from this source (see infozip.BUILD) with the museum's
hermetic LLVM toolchain, so projects whose builds shell out to `zip` (e.g. Bazel
itself) get a hermetic, pinned tool instead of depending on a host `zip`. The
built binary is injected on the inner build's PATH via the HERMETIC_ZIP overlay
(//builds:overlays.bzl) and `--tool` in //tools/buildrunner.

Source is Info-ZIP zip 3.0 (the last release), via Debian's immutable orig
tarball; sha256-pinned so the bytes are content-addressed like every other
museum input.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _infozip_impl(_ctx):
    http_archive(
        name = "infozip",
        urls = [
            "https://deb.debian.org/debian/pool/main/z/zip/zip_3.0.orig.tar.gz",
            "http://deb.debian.org/debian/pool/main/z/zip/zip_3.0.orig.tar.gz",
        ],
        sha256 = "f0e8bb1f9b7eb0b01285495a2699df3a4b766784c1765a8f1aeedf63c0806369",
        strip_prefix = "zip30",
        build_file = "//tools/zip:infozip.BUILD",
    )

infozip = module_extension(implementation = _infozip_impl)
