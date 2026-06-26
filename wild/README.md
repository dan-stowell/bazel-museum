# wild — builds "as found in nature"

The museum proper makes projects hermetic *by injection*: a pinned inner Bazel, a
fully-hermetic LLVM toolchain, and per-project overlays. This directory takes the
opposite bet:

> Put the reproducibility boundary at the **container**, not the build graph. Drop
> a project's source in *exactly as upstream wrote it* (no overlays, no injected
> toolchain) and run its build. Then measure **hermeticity as a dimension**: which
> projects build with nothing but bazelisk, which need an ordinary host, and which
> just need a nudge.

## Pieces

- [`Dockerfile`](Dockerfile) — **strict** image: `debian-slim` + `ca-certificates`
  + `bazelisk` only (~136 MB). No compiler, no SDK. The "is it hermetic in nature?"
  probe.
- [`Dockerfile.baseline`](Dockerfile.baseline) — **baseline** image: the above plus
  a normal CI machine (gcc/g++, JDK, python, git, zip; ~1.1 GB). The workhorse for
  "build it as it is."
- [`build.sh`](build.sh) — `wild/build.sh <project> [bazel-args…]`. Reads the
  project's pinned `url+sha256` straight from `//tools/fetch:extension.bzl`, fetches
  + verifies it on the host, mounts it into the container, and runs `bazelisk`
  against the upstream `MODULE`/`BUILD`. `WILD_IMAGE` picks the image (default
  baseline); `USE_BAZEL_VERSION=<v>` forces a Bazel (else bazelisk honors the repo's
  `.bazelversion`, or the latest if it pins none).
- [`sweep.sh`](sweep.sh) — runs every museum project's curated target through three
  configs and writes the matrix. Self-committing and resumable.
- [`CATALOG.md`](CATALOG.md) — the generated result matrix (all 33 projects).

```sh
docker build -t bazel-wild            wild/                                # strict
docker build -t bazel-wild-baseline -f wild/Dockerfile.baseline wild/      # baseline
wild/build.sh cpu_features                       # build it as it is (baseline)
USE_BAZEL_VERSION=8.7.0 wild/build.sh nsync build //:nsync
WILD_IMAGE=bazel-wild   wild/build.sh fast_float  # the strict (hermeticity) probe
bash wild/sweep.sh                                # the whole matrix
```

## Results

All 33 museum projects, each built **as upstream ships it** (curated target, no
overlays) under three configs — see [`CATALOG.md`](CATALOG.md) for the full table:

- **as-is** — baseline image, whatever Bazel bazelisk picks.
- **+right-bazel** — baseline image, pinned to the project's known-good Bazel.
- **hermetic** — *strict* image, known-good Bazel (✅ ⇒ builds with no host toolchain).

|                | builds | of 33 |
|----------------|:------:|:-----:|
| as-is          | **20** | 61% |
| +right-bazel   | **29** | 88% |
| hermetic in nature | **0** | 0% |

The shape of the result is the finding: **as-is ≈ ⅔, right-Bazel ≈ ⅞, hermetic = 0.**

## The two walls

**1. Version drift (the as-is → right-bazel gap).** A repo that pins no
`.bazelversion` gets whatever bazelisk thinks is latest (Bazel 9), which removed the
autoloaded `cc_*` / `sh_test` built-ins — so any package still using them fails at
*load* time. Nine of the thirteen as-is failures are this: buildtools, cli11, glog,
googletest, nsync, snappy (`sh_test`/`cc_*` not defined) and cctz, flatbuffers
(dep-shape on Bazel 9). Give each the Bazel it expects and it builds. doctest *does*
pin (8.5.0) and bazelisk honors it — version-pinning works in nature when the repo
bothers; pinned source and a moving toolchain selector are not the same thing.

**2. The host toolchain (why hermetic = 0).** Pin past the drift and *everything*
that compiles fails the same way in the strict image — Bazel's C/C++ toolchain
**auto-configuration**, which probes the host for `gcc`/`CC` and finds none:

```
fast_float (pure C++)  → @rules_cc//…/local_config_cc:cc-compiler-k8
buildtools (pure Go!)  → @rules_go//:cgo_context_data → …/local_config_cc
  → "Auto-Configuration Error: Cannot find gcc or CC"
```

Even pure-Go buildifier and Rust `cxx` hit it — rules_go/rules_rust eagerly
configure a host C toolchain for cgo/linking. Of the 29 projects that build with the
right Bazel, **27 need a C/C++ compiler**, ortools additionally needs **`git`** (a
`git_repository` fetch), and protobuf trips a repo-visibility issue — so **none** are
hermetic for free. That host-toolchain dependency is exactly what the museum's
`HERMETIC_LLVM` overlay removes by injection: the museum isn't gilding the lily, it's
supplying something every one of these projects silently assumes.

## Hermeticity as a dimension

That makes the spectrum the real product, not a pass/fail:

- **hermetic from the start** — builds in the strict image. *Currently none*, but
  this is the column to grow.
- **hermetic with a nudge** — would, with a small *declared* change: register a
  `toolchains_llvm` / `hermetic_cc_toolchain` in its own `MODULE.bazel`. Most C/C++
  projects here are one `register_toolchains` away.
- **leans on the host** — builds only with the baseline image's toolchain (today:
  all 29 that build).

## Still failing even with the right Bazel (4)

Each is a distinct "as found in nature" story, not a toolchain problem:

- **bazel** — `//src:bazel-bin` is 6768 actions; hit the 900 s sweep timeout. Builds
  given time (it's the museum's flagship), just too big for an unscoped sweep slot.
- **grpc** — ships a `tools/bazel` wrapper that bazelisk respects, which shells out
  to **`curl`** to download its own pinned Bazel. The image has no `curl` →
  `curl: command not found`. A host-tool assumption beyond the compiler.
- **brotli** — ships **no `MODULE.bazel`** (WORKSPACE-only in nature; the museum
  synthesizes one). bzlmod in the wild sees no workspace marker → *"the 'build'
  command is only supported from within a workspace."*
- **doctest** — root `//:doctest` uses `includes = ["."]`, which modern Bazel rejects
  for the main module ("resolves to the workspace root"). Legal — and fine — only
  when doctest is consumed as a *dependency*, which is how it's meant to be used.

## Takeaway

"Build it as it is" holds for ~⅔ of real Bazel projects out of the box and ~⅞ once
you hand them the Bazel they were written for. Hermeticity, though, is cleanly its
own axis that **nobody satisfies for free** — in nature a Bazel project assumes a
developer machine (a compiler, sometimes a JDK, `curl`, `git`). The museum's
injected toolchain is what converts "leans on the host" into "hermetic"; the open,
interesting work is the **nudge** column — how few declared lines move a project from
host-dependent to hermetic-from-the-start.
