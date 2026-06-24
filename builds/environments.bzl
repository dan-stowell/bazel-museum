"""Environments: where a goal's inner build actually runs.

An *environment* provisions execution capacity and declares which (os, arch)
platforms it can serve. museum_project crosses environments x platforms x
commands to emit the concrete `<command>_<env>_<os>_<arch>` goal targets (see
//builds:defs.bzl).

Fields:
  * name        — token used in target names (`local`, `rbe`).
  * platforms   — list of PLATFORMS keys this environment can serve.
  * overlays    — overlays applied to every goal in this environment (e.g. the
                  BuildBuddy connection for `rbe`).
  * pin_platform — if True, the goal injects museum_rbe/ and pins --platforms /
                  --extra_execution_platforms / --host_platform to its platform.
                  Used by remote environments so the build is fully explicit
                  about os/arch instead of inheriting the orchestrating host's.
  * host_only   — if True, each goal only runs when the *host* matches its
                  platform (via target_compatible_with). This is how `local`
                  models "one OS/arch at a time": on this laptop only the
                  darwin_arm64 goals are live; on the linux VM only linux_amd64.

To add an environment (e.g. a future `actiond`), define it here with the
platforms it supports and add it to a project's `environments = [...]`.
"""

load(":overlays.bzl", "BUILDBUDDY_RBE")

def environment(name, platforms, overlays = [], pin_platform = False, host_only = False):
    return struct(
        name = name,
        platforms = platforms,
        overlays = overlays,
        pin_platform = pin_platform,
        host_only = host_only,
    )

# The host machine itself. Supports exactly one platform at a time — whichever
# the host is — so each per-platform goal is gated on the host matching it.
LOCAL = environment(
    name = "local",
    platforms = ["linux_amd64", "darwin_arm64"],
    host_only = True,
)

# BuildBuddy cloud RBE. Today it serves linux/amd64 (linux/arm64 and darwin would
# need the corresponding executor pools). Host-independent: runs the same from a
# linux or macOS orchestrator.
RBE = environment(
    name = "rbe",
    platforms = ["linux_amd64"],
    overlays = [BUILDBUDDY_RBE],
    pin_platform = True,
)
