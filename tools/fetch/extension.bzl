"""Module extensions that fetch hermetic, pinned build inputs.

Two extensions:

* `inner_bazel` — the Bazel binary used to run the *inner* project builds. We
  pin a specific release (version + sha256) and download the official binary,
  rather than depending on a host-installed bazel/bazelisk. linux + darwin,
  amd64 + arm64.

* `project_sources` — source tarballs of the museum's projects, pinned by
  sha256. This is the kickoff's "project source code as a dep in MODULE.bazel":
  each project's source is an immutable, content-addressed input. We fetch the
  tarball as an opaque file (http_file) so the *outer* Bazel never parses the
  project's own BUILD files — the inner Bazel does that, against an extracted
  copy.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

# --- Inner Bazel binaries --------------------------------------------------

# The default inner Bazel. Most projects build with this; a project that targets
# an older Bazel (see its .bazelversion / bazel_compatibility) can ask for a
# different version via museum_project(bazel_version = ...).
DEFAULT_INNER_BAZEL_VERSION = "9.1.1"

# version -> {repo suffix: (release arch tag, sha256 of the binary)}. The repos
# are named inner_bazel_<version-with-underscores>_<suffix> (e.g.
# inner_bazel_9_1_1_linux_amd64). Add a version block to support a new inner.
_INNER_BAZELS = {
    "9.1.1": {
        "linux_amd64": ("linux-x86_64", "857bed5d2756b4d998d3caebf2d941d13d434c4eda4b1d6d7dda205736c25a93"),
        "linux_arm64": ("linux-arm64", "82d1163884e45a6a7ff764cc01197b1b1ed497000726b84dc4b47c1dfc8a2bb4"),
        "darwin_amd64": ("darwin-x86_64", "6fd490084bdccf044d7a6d8360a26f8770fa09f4e624328efea292f493204930"),
        "darwin_arm64": ("darwin-arm64", "2db883718453f0437a7bcb408e889dbf8539cdc4d61c8ebc3807a1a88d02ff08"),
    },
    # gRPC 1.81.1 (and other mature projects) target Bazel 8; building them with
    # the Bazel 9 inner fights their pre-Bazel-9 transitive dep graph.
    "8.0.1": {
        "linux_amd64": ("linux-x86_64", "40f243b118f46d1c88842315e78ec5f9f6390980d67a90f7b64098613e60d65b"),
        "linux_arm64": ("linux-arm64", "ebc269a83c64d52017681874d13fce399cc624ab42e8e83bf4dedfe29589eaa6"),
        "darwin_amd64": ("darwin-x86_64", "32ca8bbf866cb14190bfb019ce1ac4a7d61b8cbb3f0771137974e8d0e5cdf1eb"),
        "darwin_arm64": ("darwin-arm64", "d10ac6488550c5211aed20084f40dfb77f6367e229b15a1cf287057941d9332b"),
    },
}


def _version_tag(version):
    return version.replace(".", "_")


def _inner_bazel_impl(_ctx):
    for version, plats in _INNER_BAZELS.items():
        vtag = _version_tag(version)
        for suffix, (arch, sha256) in plats.items():
            http_file(
                name = "inner_bazel_{}_{}".format(vtag, suffix),
                urls = ["https://github.com/bazelbuild/bazel/releases/download/{v}/bazel-{v}-{a}".format(
                    v = version,
                    a = arch,
                )],
                sha256 = sha256,
                executable = True,
                downloaded_file_path = "bazel",
            )


inner_bazel = module_extension(implementation = _inner_bazel_impl)

# --- Project source archives ----------------------------------------------

# repo name -> dict(url, sha256, filename). Add a line here to vendor a new
# project's source. The repo's file is reachable as `@<name>//file`.
_PROJECT_SOURCES = {
    "absl_archive": {
        "url": "https://github.com/abseil/abseil-cpp/releases/download/20260526.0/abseil-cpp-20260526.0.tar.gz",
        "sha256": "6e1aee535473414164bf83e4ebc40240dec71a4701f8a642d906e95bea1aea0c",
        "filename": "abseil-cpp-20260526.0.tar.gz",
    },
    "copybara_archive": {
        "url": "https://github.com/google/copybara/archive/refs/tags/v20260622.tar.gz",
        "sha256": "62fd6f98f6414c0ed846f839f391e3c88bbbc7d2440cb353b4009a711b4d5ea0",
        "filename": "copybara-v20260622.tar.gz",
    },
    "cxx_archive": {
        "url": "https://github.com/dtolnay/cxx/archive/refs/tags/1.0.194.tar.gz",
        "sha256": "2edf94915ab43778b02a13e522d050a76dea607d1a05f769911775676d27cb3c",
        "filename": "cxx-1.0.194.tar.gz",
    },
    # Protocol Buffers — the canonical first-party Bazel C++ project. We pin the
    # release's Bazel-specific source dist (the variant the BCR consumes), which
    # ships the bzlmod MODULE.bazel and depends on abseil-cpp/rules_cc/zlib.
    "protobuf_archive": {
        "url": "https://github.com/protocolbuffers/protobuf/releases/download/v35.1/protobuf-35.1.bazel.tar.gz",
        "sha256": "75b7b0b36b630c7b6e3aeb07b2e58993fb9494fbb2b08bba0891aaa231d4e4d1",
        "filename": "protobuf-35.1.bazel.tar.gz",
    },
    # gRPC — first-party Bazel; pairs naturally with protobuf. Fully bzlmod
    # (its legacy WORKSPACE is ignored under Bazel 9); pulls boringssl, abseil,
    # c-ares, protobuf, re2, zlib from the BCR.
    "grpc_archive": {
        "url": "https://github.com/grpc/grpc/archive/refs/tags/v1.81.1.tar.gz",
        "sha256": "48ae0d05f87206112d9e9144a923191ee1e482141a70686ec58dc86d0b40fddc",
        "filename": "grpc-1.81.1.tar.gz",
    },
    # GoogleTest — the C++ test framework. First-party Bazel, builds + tests
    # itself with the hermetic LLVM toolchain.
    "googletest_archive": {
        "url": "https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz",
        "sha256": "65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c",
        "filename": "googletest-1.17.0.tar.gz",
    },
    # nlohmann/json — JSON for Modern C++. Header-only; first-party Bazel.
    "json_archive": {
        "url": "https://github.com/nlohmann/json/archive/refs/tags/v3.12.0.tar.gz",
        "sha256": "4b92eb0c06d10683f7447ce9406cb97cd4b453be18d7279320f7b2f025c10187",
        "filename": "json-3.12.0.tar.gz",
    },
    # FlatBuffers — serialization library + flatc compiler. First-party Bazel.
    "flatbuffers_archive": {
        "url": "https://github.com/google/flatbuffers/archive/refs/tags/v25.12.19-2026-02-06-03fffb2.tar.gz",
        "sha256": "ccbce58684691de1e7d51f5e87786266b37d06ab66e9dfe2d0ec106fe50aace0",
        "filename": "flatbuffers-25.12.19-2026-02-06-03fffb2.tar.gz",
    },
    # Catch2 — C++ test framework. First-party Bazel.
    "catch2_archive": {
        "url": "https://github.com/catchorg/Catch2/archive/refs/tags/v3.15.1.tar.gz",
        "sha256": "be23a52b85cf04cd9587612147a10b023d59ed9757fa1843cc99e615d6c0893c",
        "filename": "Catch2-3.15.1.tar.gz",
    },
}


def _project_sources_impl(_ctx):
    for name, info in _PROJECT_SOURCES.items():
        http_file(
            name = name,
            urls = [info["url"]],
            sha256 = info["sha256"],
            downloaded_file_path = info["filename"],
        )


project_sources = module_extension(implementation = _project_sources_impl)
