"""Compatibility overlay values for KISS-only project declarations.

The KISS macros ignore overlays, but many project BUILD files still load and
pass these names. Keep them as inert structs so those declarations stay small.
"""

def overlay(name, appends = [], writes = [], patches = [], build_flags = [], remote_header_envs = [], tools = []):
    return struct(
        name = name,
        appends = appends,
        writes = writes,
        patches = patches,
        build_flags = build_flags,
        remote_header_envs = remote_header_envs,
        tools = tools,
    )

HERMETIC_LLVM = overlay(name = "hermetic_llvm")
CC_NODETECT = overlay(name = "cc_nodetect")
HERMETIC_ZIP = overlay(name = "hermetic_zip")
RULES_RUST_SYSROOT_FIX = overlay(name = "rules_rust_sysroot_fix")
RULES_CC_DEP = overlay(name = "rules_cc_dep")
PLATFORMS_DEP = overlay(name = "platforms_dep")
BUILDBUDDY_RBE = overlay(name = "buildbuddy_rbe")
ACTIOND_WORKER = overlay(name = "actiond_worker")
