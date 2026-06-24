# Design

Bazel Museum is a collection of reproducible Bazel builds of public open-source
projects. There are three pieces. **Piece 1 (the data pipeline) is built; pieces
2 and 3 are planned.**

Everything is driven by Bazel: clone the repo onto a host that has only Bazel
(via `bazelisk`) and you can build and run everything. No host Python, no host
`gh`, no daemons assumed.

---

## Piece 1 — Data pipeline (built)

Discovers public projects that build with Bazel and writes a normalized
snapshot to [`data/projects.json`](../data/projects.json).

```
bazel run //pipeline:gather                 # fetch + enrich + write snapshot
bazel run //pipeline:gather -- --enrich=none # offline: skip GitHub enrichment
bazel run //pipeline:gather -- --enrich=all  # enrich rulesets/tooling too
```

### Sources

| id        | what                                                              | how |
|-----------|-------------------------------------------------------------------|-----|
| `nicolov` | [nicolov/awesome-bazel] "Projects built with Bazel" section       | parse Markdown bullet list |
| `jin`     | [jin/awesome-bazel] "Projects" section                            | parse Markdown bullet list |
| `bcr`     | [Bazel Central Registry] — every module's `metadata.json`         | download one repo tarball, read all metadata, **classify** |

[nicolov/awesome-bazel]: https://github.com/nicolov/awesome-bazel
[jin/awesome-bazel]: https://github.com/jin/awesome-bazel
[Bazel Central Registry]: https://github.com/bazelbuild/bazel-central-registry

The awesome-list "projects" sections are curated, so their entries are trusted
as projects. The registry is mostly rulesets/tooling mixed with real projects,
so each module is classified heuristically.

### Classification heuristics (BCR)

Implemented in [`pipeline/classify.py`](../pipeline/classify.py). Every decision
carries a human-readable `classification_reason` so the output is auditable:

- module name contains `rules_` / `-rules` / `_rules` → **ruleset**
- module name contains `bazel`, `gazelle`, `toolchain`, `stardoc`, `skylib`,
  `buildtools`/`buildifier` → **tooling**
- published by a known Bazel-tooling org (`bazelbuild`, `bazel-contrib`,
  `aspect-build`) → **tooling**
- otherwise → **project** (e.g. abseil-cpp, grpc, openexr, antlr4, libavif)

These are intentionally conservative and easy to tune.

### Normalization, dedup, enrichment

- Every entry is keyed by `owner/repo` (case-insensitive) and deduped; an entry
  found in multiple sources keeps the union of `sources` and the most specific
  category.
- Enrichment uses the GitHub API (via hermetic `gh`) to add `stars`, `archived`,
  `language`, `pushed_at`, and `description`. Because `gh` follows renames, the
  canonical `owner/repo` is adopted and a second dedup pass collapses aliases
  (e.g. `google/protobuf` → `protocolbuffers/protobuf`).
- Output is deterministic (sorted by category, then stars, then key; no
  timestamps) so committed diffs are meaningful.

### Hermetic `gh` (GitHub CLI as a Bazel dependency)

We do **not** rely on a host-installed `gh`. [`tools/gh/extension.bzl`](../tools/gh/extension.bzl)
is a module extension that downloads a pinned `gh` release tarball
(version + sha256) and exposes the binary. `//pipeline:gather` bundles it via
`data`/`args` (selected per CPU; linux **amd64** and **arm64** are both wired
up) and locates it at runtime through runfiles.

**Token handling** (see [`pipeline/github.py`](../pipeline/github.py)):

1. `GH_TOKEN` or `GITHUB_TOKEN` from the environment, else
2. the host's stored credential via `gh auth token` (reads `~/.config/gh`).

The resolved token is passed explicitly to every `gh api` call via `GH_TOKEN`,
so authentication works without the binary depending on host `gh` state. To use
a specific token: `GH_TOKEN=… bazel run //pipeline:gather`.

### Layout

```
pipeline/
  gather.py        entrypoint: fetch → merge/dedup → enrich → write JSON
  model.py         Project dataclass, GitHub URL parsing, dedup/merge
  classify.py      BCR project/ruleset/tooling heuristics
  github.py        hermetic-gh wrapper + token resolution
  netfetch.py      stdlib-only HTTP helpers (no third-party deps)
  sources/         one module per source (nicolov, jin, bcr)
tools/gh/          hermetic gh CLI module extension
data/projects.json generated snapshot (committed)
```

The pipeline uses only the Python standard library plus `rules_python`'s
runfiles helper — no pip lockfile — which keeps it simple and hermetic.

---

## Piece 2 — Running Bazel builds in isolation (planned)

Goal: `bazel run //builds/<project>:build` builds a chosen project inside a
minimal, hermetic Linux container, with **no daemon assumed** (`bazel
--batch`-style, or a non-daemon runner).

Direction (open to change):

- Define a minimal container image that can run Bazel, using
  [`rules_img`](https://github.com/bazel-contrib/rules_img).
- Provide per-project run targets:
  `bazel run //:project_xyz_bazel_build -- <args>`.
- Start with linux/amd64; linux/arm64 next (the hermetic `gh` setup already
  pins both arches as a template for multi-arch).

## Piece 3 — The build collection (planned)

For each museum project:

- Pull the project source as a dependency in `MODULE.bazel` (e.g.
  `bazel_dep` / `git_override` / `archive_override`), not vendored.
- Keep any necessary overlays/patches alongside it.

The data pipeline (piece 1) feeds the choice of first project: pick a
well-known, self-contained project that already builds with Bazel from
`data/projects.json`, then exercise pieces 2 and 3 against it.
