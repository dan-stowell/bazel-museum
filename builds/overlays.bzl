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
# This overlay carries only the *connection* to BuildBuddy (endpoints, auth,
# fan-out). The execution+target *platform* is pinned separately, per goal, by
# museum_project (it injects museum_rbe/ and sets --platforms /
# --extra_execution_platforms / --host_platform to the goal's os/arch). That
# separation is what lets one environment serve multiple platforms. The API key
# is injected as a --remote_header by the runner, so it never hits disk.
_BB = "grpcs://buildbuddy.buildbuddy.io"
_BB_RESULTS = "https://buildbuddy.buildbuddy.io/invocation/"

BUILDBUDDY_RBE = overlay(
    name = "buildbuddy_rbe",
    build_flags = [
        "--remote_executor=" + _BB,
        "--remote_cache=" + _BB,
        "--bes_backend=" + _BB,
        "--bes_results_url=" + _BB_RESULTS,
        "--remote_timeout=10m",
        # Run spawns remotely, falling back to a local sandbox (then bare local)
        # only for actions that can't go remote. Crucially this drops the default
        # `worker` strategy: persistent workers run *locally*, so with a pinned
        # remote platform a local worker would try to exec the executor's toolchain
        # (e.g. the linux remote JDK) on the orchestrating host and fail with
        # "cannot execute binary file". Keeping workers off makes RBE host-neutral.
        "--spawn_strategy=remote,sandboxed,local",
        # RBE best practices: fan out, and don't pull every intermediate output.
        "--jobs=50",
        "--remote_download_toplevel",
    ],
    remote_header_envs = ["BUILDBUDDY_API_KEY:x-buildbuddy-api-key"],
)
