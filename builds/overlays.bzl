"""Reusable, named *overlays* — bundles of source edits + flags for a goal.

An overlay captures everything needed to make some project build/test under some
condition (a toolchain, an environment like remote cache / RBE, a project fix):

  * appends   — list of (file_label, dest): append file onto dest in the source
                (e.g. inject a toolchain into MODULE.bazel, flags into .bazelrc)
  * patches   — list of unified-diff file labels applied with `patch -p1`
  * build_flags        — flags added to the inner `bazel <command>`
  * remote_header_envs — "ENVVAR:HEADER" pairs; the runner reads ENVVAR and adds
                         --remote_header=HEADER=<value> (keeps secrets off disk)

Overlays compose: a project sets base overlays for all its goals, and each goal
can add more (e.g. a remote-execution overlay). This is how we capture
overlays/patches per (project x goal x environment).
"""

def overlay(name, appends = [], patches = [], build_flags = [], remote_header_envs = []):
    return struct(
        name = name,
        appends = appends,
        patches = patches,
        build_flags = build_flags,
        remote_header_envs = remote_header_envs,
    )

# Fully-hermetic LLVM C/C++ toolchain (hermeticbuild/hermetic-llvm). Zero-sysroot:
# no host compiler/headers/libc. See //tools/buildrunner/overlays/.
HERMETIC_LLVM = overlay(
    name = "hermetic_llvm",
    appends = [("//tools/buildrunner/overlays:hermetic_cc.MODULE.bazel", "MODULE.bazel")],
    build_flags = ["--extra_toolchains=@llvm//toolchain:all"],
)

# BuildBuddy cloud remote build execution (RBE). We deliberately do NOT use
# toolchains_buildbuddy: hermetic-llvm is zero-sysroot, so the compiler and all
# inputs are uploaded to the CAS and run image-agnostically on the executor.
#
# The executor image only needs a modern-enough glibc to run the prebuilt clang
# (BuildBuddy's default image is Ubuntu 16.04 / glibc 2.23, too old), so we pin
# one explicitly via --remote_default_exec_properties (which applies because no
# target sets its own exec_properties). The API key is injected as a
# --remote_header by the runner, never committed.
#
# This works as-is when the *host* is linux/amd64 (the auto exec platform is
# already linux x86_64). Cross-host (e.g. macOS) RBE will force a linux exec
# platform; that is the next step.
_BB = "grpcs://buildbuddy.buildbuddy.io"
_BB_RESULTS = "https://buildbuddy.buildbuddy.io/invocation/"
_RBE_IMAGE = "docker://gcr.io/flame-public/rbe-ubuntu20-04:latest"

BUILDBUDDY_RBE = overlay(
    name = "buildbuddy_rbe",
    build_flags = [
        "--remote_executor=" + _BB,
        "--remote_cache=" + _BB,
        "--bes_backend=" + _BB,
        "--bes_results_url=" + _BB_RESULTS,
        "--remote_timeout=10m",
        "--remote_default_exec_properties=OSFamily=Linux",
        "--remote_default_exec_properties=container-image=" + _RBE_IMAGE,
        # RBE best practices: fan out, and don't pull every intermediate output.
        "--jobs=50",
        "--remote_download_toplevel",
    ],
    remote_header_envs = ["BUILDBUDDY_API_KEY:x-buildbuddy-api-key"],
)
