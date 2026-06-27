# Minimal build/test image — what each project actually needs

_Goal: the smallest container image that still builds & tests the front-door
suite (`//projects/<project>:build` / `:test`), learned project by project by
**starting minimal and pulling tools in only when a build demands them**._

The front-door targets run each project's **upstream** build (its own
MODULE/BUILD, no overlays, no injected toolchain — see `projects/defs.bzl`)
inside `//runner/image`. So the image *is* the toolchain: whatever the upstream
build shells out to has to be on `PATH` in the image.

Method: build deliberately-stripped Debian-slim images, then run projects in them
via the `docker` runtime (`RUNNER_RUNTIME=docker RUNNER_IMAGE=<img>
projects/run.sh <key> <ver> build <targets>`) and read the failure. Every missing
tool announces itself precisely (`command not found`, `Cannot find gcc or CC`,
`local_runtime_repo` …), so each tier adds exactly one demand.

## The tiers we climbed

| Image | Adds | What it unlocked |
|-------|------|------------------|
| `bazelisk + jre + ca-certs` | — | **Nothing.** Bazel's `cc_configure` (rules_cc) probes for a host `cc` *unconditionally*, at fetch time, for **every** project — Go and Python included. No compiler ⇒ `Cannot find gcc or CC` before any build starts. |
| **M1** `+ build-essential` (drop jre) | gcc/g++/make | The large majority: compiled & header-only **C++**, **Go** (rules_go fetches its SDK), **Rust** (rules_rust fetches its toolchain), **Java** (remotejdk — see below), **Python** (rules_python is hermetic). |
| **M2** `+ python3` | python3 | **protobuf** (and other `rules_python` codegen that probes the host interpreter via `local_runtime_repo`). |
| **M3** `+ git + curl + zip` | git, curl, zip | **ortools** (`git_repository` → `git`), **grpc** (its `tools/bazel` wrapper → `curl`), **bazel** (install-base genrule → `zip`). |

## Headline findings

- **A C/C++ toolchain is effectively mandatory suite-wide** — not because every
  project compiles C++, but because Bazel's `cc_configure` repo rule runs for
  almost every module and hard-errors without a host `cc`. (Escape hatch:
  `--repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1`, but then any module that
  *does* reach a cc toolchain fails at analysis — not worth it for this suite.)
- **The JDK is droppable.** `default-jdk-headless` is in the current image but
  **nothing in the front-door suite needs it.** copybara (a pure-Java app) builds
  its `copybara.jar`, and even building **bazel itself** succeeds, with **no host
  Java** — Java compilation uses the hermetic `remotejdk` (rules_java downloads
  it) and Bazel's launcher uses its own embedded JDK.
- **No host `cmake` needed.** `rules_foreign_cc` downloads its own hermetic
  cmake (z3's build uses `cmake-3.23` from the repo cache, not the host's).
- The only "more than a compiler" front-door projects are the four heavyweights:
  **protobuf** (python3), **ortools** (git), **grpc** (curl), **bazel** (zip).
  Everything else builds on the compiler-only floor.

## Proposed minimal image (`toolchain.yaml`)

Drop `default-jdk-headless`. Keep:

- `build-essential` — universal (cc_configure + the C/C++ projects)
- `python3` + `python-is-python3` — protobuf & rules_python codegen
- `git` — ortools `git_repository`
- `curl` — grpc `tools/bazel` wrapper
- `zip` + `unzip` — bazel install-base genrule
- `ca-certificates` — TLS for BCR / bazelisk

A **two-tier** split is also viable: a *slim* image (`build-essential` +
`ca-certificates`) builds ~90% of the suite; a *full* image adds
`python3/git/curl/zip` for the four heavyweights above.

## Per-project minimal tier

Two sweeps over all front-door `:build` targets: M3 (full, no JDK) and M1
(compiler-only). M1 ran on a repocache warmed by M3, so it cleanly exposes
*compile/probe-time* needs (cc, python3, zip — re-run every build) but **masks
fetch-time downloads** (git/curl) whose artifacts were already cached; those were
pinned by the cold M2 batch instead. Combined partition:

| Minimal tier | Projects |
|--------------|----------|
| **compiler only** (`build-essential` + `ca-certs`) | abseil_cpp, abseil_py, benchmark, boringssl, buildtools, catch2, cctz, cli11, copybara, cpu_features, crow, cxx, double_conversion, fast_float, flatbuffers, ftxui, gflags, glog, go_jsonnet, googletest, gperftools, grpc_gateway, highs, highway, iceoryx2, json, jsoncpp, jsonnet, lcm, magic_enum, nsync, onetbb, opencc, openexr, opentelemetry_cpp, pcre2, prometheus_cpp, quill, re2, snappy, zlib |
| **+ python3** | protobuf |
| **+ git** | ortools (`git_repository`) |
| **+ curl** | grpc (`tools/bazel` wrapper) |
| **+ zip** | bazel (install-base genrule) |

That's **44/49 building** with no JDK. The compiler-only tier spans every
language in the suite — C++ (compiled & header-only), Go, Rust, Java (copybara),
Python (abseil_py) — confirming the JDK and host python/git/curl/zip are needed
only by the four named heavyweights.

### The five that don't build front-door (image-independent or LOCAL-only)

| Project | Why | Image-related? |
|---------|-----|----------------|
| brotli | WORKSPACE-only (no `MODULE.bazel`) — bzlmod sees no workspace | no |
| doctest | root `//:doctest` self-rejects (`includes=["."]`) for the main module | no |
| grpc | its `tools/bazel` wrapper downloads its own Bazel which then can't find the compiler | no (wrapper) |
| cpptrace | self-registers `toolchains_llvm`, whose clang wants **`libtinfo.so.5`** (absent on bookworm) | yes — but a LOCAL museum project |
| z3 | foreign_cc build globs `bazel-bin/**` / `find_package(Python3)` edge | LOCAL museum project |

_Source data: `runner/image-needs.tsv` (M3, no-JDK) and `runner/image-needs-m1.tsv`
(compiler-only). Note: the sweep keys by the project's `runner_project` name, not
its directory — abseil_cpp's archive is `absl`._

## Caveat on method

These probe images were built with plain `docker build` (apt postinst runs, so
`cc`/`make` alternatives are wired up normally). The real `//runner/image`
extracts `.deb` data via rules_distroless (no postinst) and recreates those
symlinks in its `fixups` tar. Dropping `default-jdk-headless` from
`toolchain.yaml` is independent of that and the conclusion carries; the lock must
be regenerated (`bazel run @toolchain_apt//:lock`) after the edit.
