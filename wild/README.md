# wild — builds "as found in nature"

The museum proper makes projects hermetic *by injection*: a pinned inner Bazel, a
fully-hermetic LLVM toolchain, and per-project overlays. This directory takes the
opposite bet:

> Put the reproducibility boundary at the **container**, not the build graph. Ship
> an image with **nothing but bazelisk**, drop a project's source in *exactly as
> upstream wrote it* (no overlays, no injected toolchain), and run its build. The
> question we're measuring: **which projects are already hermetic enough to build
> with nothing but bazelisk + the network?**

## Pieces

- [`Dockerfile`](Dockerfile) — a two-stage build whose final image is just
  `debian-slim` + `ca-certificates` + the `bazelisk` binary (~136 MB). No
  compiler, no language SDK, no build tools. (CA certs are irreducible: bazelisk
  downloads Bazel, and builds fetch the BCR + toolchains over https.)
- [`build.sh`](build.sh) — `wild/build.sh <project> [bazel-args…]`. Reuses the
  museum's pinned source tarball (same url+sha256 as
  `//tools/fetch:extension.bzl`), verifies it on the host, mounts it into the
  container, and runs `bazelisk` against the upstream `MODULE.bazel`/`BUILD` as
  found. `USE_BAZEL_VERSION=<v>` forces a specific Bazel (otherwise bazelisk
  honors the project's `.bazelversion`, or the latest if it pins none).

```sh
docker build -t bazel-wild wild/
wild/build.sh buildtools build //buildifier:buildifier
USE_BAZEL_VERSION=7.4.1 wild/build.sh fast_float build //...
```

## First findings

Two failure layers surface immediately, and they are the whole story so far.

**1. Version drift.** A project that pins no `.bazelversion` gets whatever
bazelisk thinks is latest (today, Bazel **9.1.1**). Bazel 9 removed the
autoloaded `cc_*` / `sh_test` built-ins, so older releases break at *load* time:

```
buildtools v7.3.1  (no .bazelversion)
  → bazelisk picks 9.1.1
  → ERROR: buildifier/BUILD.bazel:60: name 'sh_test' is not defined
```

In nature, "reproducible" and "buildable" are not the same thing: the source is
pinned, but the *toolchain selector* is a moving target the project never nailed
down.

**2. The host C/C++ toolchain is the universal wall.** Pin past the version drift
(`USE_BAZEL_VERSION=7.4.1`) and every project that compiles anything fails at the
*same* place — Bazel's C/C++ toolchain **auto-configuration**, which probes the
host for `gcc`/`CC` and finds none in a bazelisk-only image:

```
fast_float  (pure C++)   → @rules_cc//…/local_config_cc:cc-compiler-k8
buildtools  (pure Go!)   → @rules_go//:cgo_context_data → …/local_config_cc
  both → "Auto-Configuration Error: Cannot find gcc or CC"
```

Note buildtools is a *pure-Go* binary, yet rules_go still eagerly configures a
cgo C toolchain at analysis time. So even "no native code" projects lean on a
host compiler in nature — exactly the dependency the museum's `HERMETIC_LLVM`
overlay removes by injection.

### Takeaway

Almost nothing builds with *literally* nothing but bazelisk, because "in nature"
a Bazel project assumes the host is a developer machine with a C compiler on
`$PATH`. That points at two honest framings for this track, which is the open
question:

- **(a) Strictly bazelisk-only** → the interesting set is the small minority of
  projects that bring their *own* hermetic toolchain (e.g. declare
  `toolchains_llvm` / `hermetic_cc_toolchain` and `register_toolchains` in their
  own `MODULE.bazel`). Cataloging those = "who is hermetic in nature."
- **(b) bazelisk + a baseline** → bake a system compiler (gcc, a JDK, …) into the
  image to model a *normal* CI machine, and let the container be the
  reproducibility boundary. More projects build; the image is the pinned "nature."

| project | lang | result (in the wild) |
|---------|------|----------------------|
| buildtools | Go | ❌ no `.bazelversion` → Bazel 9 `sh_test` removed; @7.4.1 → no host gcc (rules_go cgo) |
| fast_float | C++ | ❌ @7.4.1 → no host gcc (rules_cc autoconfig) |
