#!/usr/bin/env bash
# Build a museum project "in the wild": its pinned source, its own build files,
# inside the bazelisk-only container — no museum overlays, no injected toolchain.
#
#   wild/build.sh <project> [bazel-args...]
#
# We reuse the museum's pinned source tarballs (same url+sha256 as
# //tools/fetch:extension.bzl) for an apples-to-apples comparison: the only thing
# that changes vs. the hermetic museum is that nothing is injected. Source is
# downloaded + verified on the host, then mounted read-only into the container,
# which runs `bazelisk <args>` against the upstream WORKSPACE/MODULE as-is.
set -euo pipefail

IMAGE="bazel-wild"
CACHE="${WILD_CACHE:-$HOME/.cache/wild}"          # warm bazelisk + repo cache across runs
SRC_CACHE="$CACHE/src"
mkdir -p "$SRC_CACHE" "$CACHE/home"

proj="${1:-}"; shift || true

# project -> "url|sha256|strip_prefix|default_target"
# default_target is what a developer would naturally run; override via args.
case "$proj" in
  buildtools)
    spec="https://github.com/bazelbuild/buildtools/archive/refs/tags/v7.3.1.tar.gz|051951c10ff8addeb4f10be3b0cf474b304b2ccd675f2cc7683cdd9010320ca9|buildtools-7.3.1|//buildifier:buildifier" ;;
  fast_float)
    spec="https://github.com/fastfloat/fast_float/archive/refs/tags/v8.2.10.tar.gz|76f958dd97b1cf4d8862d1f0986a47d4bdfa8845252bae15ef0f40de3b95961f|fast_float-8.2.10|//..." ;;
  cpu_features)
    spec="https://github.com/google/cpu_features/archive/refs/tags/v0.11.0.tar.gz|ab2463f2d38fcaff1ce806be8e4c91333449931f5e02009d543b2569a3fa471a|cpu_features-0.11.0|//:cpu_features" ;;
  *)
    echo "unknown project '$proj' (known: buildtools, fast_float, cpu_features)" >&2; exit 2 ;;
esac

IFS='|' read -r url sha strip target <<<"$spec"
tarball="$SRC_CACHE/$(basename "$url")"
workdir="$SRC_CACHE/$strip"

if [[ ! -f "$tarball" ]]; then
  echo ">> fetching $url"
  curl -fsSL -o "$tarball" "$url"
fi
echo "$sha  $tarball" | sha256sum -c - >/dev/null
if [[ ! -d "$workdir" ]]; then
  echo ">> extracting $strip"
  tar -xzf "$tarball" -C "$SRC_CACHE"
fi

# Default to the project's natural target if none given.
args=("$@"); [[ ${#args[@]} -eq 0 ]] && args=(build "$target")

# Bazel writes convenience symlinks + a lockfile into the workspace, so it must
# be writable; the output base lives under the mounted HOME and stays warm.
# By default bazelisk honors the project's own .bazelversion (the "in nature"
# behavior); if the project pins nothing it falls back to the latest Bazel. Set
# USE_BAZEL_VERSION on the host to force a specific Bazel (e.g. to isolate a
# version-drift failure from a real toolchain one) — it's forwarded into the
# container.
echo ">> bazelisk ${args[*]}   (project=$proj, in the wild${USE_BAZEL_VERSION:+, bazel=$USE_BAZEL_VERSION})"
exec docker run --rm \
  -v "$workdir":/work \
  -v "$CACHE/home":/home/wild \
  ${USE_BAZEL_VERSION:+-e USE_BAZEL_VERSION="$USE_BAZEL_VERSION"} \
  "$IMAGE" "${args[@]}"
