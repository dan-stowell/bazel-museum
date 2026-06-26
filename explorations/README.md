# Explorations

The repo's headline goal is narrow and in the top-level [README](../README.md):
*build & test real projects with **bazelisk alone** (plus the host tools they
assume), and enumerate what those tools are.* Getting there, we went down
several deeper roads that are worth keeping but aren't the main story. They live
here.

Each of these is real and green; they're "explorations" only in the sense that
they go past the headline goal (hermeticity by injection, remote execution, a
local RE worker, a discovery pipeline) rather than measuring the host the way
the [`wild/`](../wild) track does.

---

## 1. The hermetic museum (`builds/`)

The opposite bet from `wild/`: instead of putting the reproducibility boundary
at a container and letting projects use the host, make each project **hermetic
by injection**. Every [`builds/<project>`](../builds) wires its pinned source to
a fully-hermetic LLVM toolchain, a pinned + daemonless *inner* Bazel, and
per-project overlays, run in an isolated build root — no host compiler, no host
Python, no host `zip`, nothing of the host Bazel's state touched.

```sh
bazel run //builds/abseil_cpp:build   # pinned inner Bazel + hermetic LLVM, isolated
bazel run //builds/abseil_cpp:test    # 251/251, no host toolchain
```

33 projects are wired this way — including **Bazel itself** (`//src:bazel-bin`,
6768 actions, hermetic LLVM + bundled JDK). A late-Bazel-8 inner (8.7.0) is used
for projects still on the Bazel-8 dependency shape; everything else runs the
9.1.1 inner. See **[docs/DESIGN.md](../docs/DESIGN.md)** for the architecture
(how the isolation, the toolchain injection, and the overlays work) and
**[docs/KICKOFF.md](../docs/KICKOFF.md)** for the original intent.

## 2. Remote execution on BuildBuddy (RBE)

The same hermetic builds, run on BuildBuddy's cloud executors (linux amd64/arm64
+ darwin arm64) — *without* `toolchains_buildbuddy`: the hermetic LLVM toolchain
runs on the executors directly. Goals are `<command>_rbe_<os>_<arch>`, or the
`.remote` convenience:

```sh
bazel run //builds/abseil_cpp:test.remote   # 248/248 pass remotely
```

Backends/OSes/arches are declared in
[`builds/environments.bzl`](../builds/environments.bzl) and
[`builds/platforms.bzl`](../builds/platforms.bzl).

## 3. actiond — a local Linux RE worker (`tools/actiond`)

[hermeticbuild/actiond](https://github.com/hermeticbuild/actiond) runs the
museum's actions for linux/arm64 (or amd64) inside a VM on this host — remote
execution semantics with no cloud. Goals are `<command>_actiond_<os>_<arch>`:

```sh
bazel run //tools/actiond:serve                       # boot the worker
bazel run //builds/abseil_cpp:build_actiond_linux_arm64
```

## 4. The discovery pipeline (`pipeline/`)

How the museum's projects were chosen in the first place: a data pipeline that
gathers public projects building with Bazel (awesome-bazel lists + the Bazel
Central Registry), enriches them with GitHub metadata via a hermetic, pinned
`gh`, and ranks candidates by recognition × maintained × buildability.

```sh
bazel run //pipeline:gather                  # write data/projects.json
bazel run //pipeline:rank                    # order the next candidates
bazel run //pipeline:rank -- --by-language   # best-per-toolchain coverage
```

The snapshot lands in [`data/projects.json`](../data/projects.json); each
project carries a `candidate_score`, so the next project to add is a ranking,
not a guess.

---

These tracks share infrastructure with `wild/`: the pinned project sources
([`tools/fetch`](../tools/fetch)) and the project list ([`builds/`](../builds))
are reused by the `wild/` targets, which build those same projects *as upstream
ships them* instead of hermetically.
