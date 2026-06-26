#!/usr/bin/env bash
# Runner behind the //projects/<project>:build and :test targets.
#
#   run.sh <key> <bazel-version|-> <build|test> [targets/flags...]
#
# Builds/tests a project "as upstream ships it": its pinned source (no museum
# overlays, no injected toolchain) run by bazelisk inside the //wild/image
# container (a pinned, ordinary CI machine). The project's source url+sha256 is
# read straight from //tools/fetch:extension.bzl, so the target needs no
# separate table. Source is fetched + verified on the host, mounted into a
# container rootfs, and bazelisk runs the upstream MODULE/BUILD as found.
#
# Runtime (WILD_RUNTIME):
#   crun   (default) daemonless + rootless via the pinned //tools/crun plus the
#          //wild/image:image OCI layout in runfiles. The rootfs is extracted
#          into WILD_CACHE on demand, keyed by manifest digest. No dockerd, no
#          host runtime, no manual pre-staging step.
#   docker the image loaded by `bazel run //wild/image:load` (needs a daemon).
# Env: WILD_CACHE (default ~/.cache/wild), WILD_IMAGE (docker tag),
#      WILD_OCI_LAYOUT/WILD_ROOTFS/WILD_CRUN (debug overrides for crun mode).
set -euo pipefail

# Under `bazel run`, the repo root is $BUILD_WORKSPACE_DIRECTORY; fall back to
# deriving it from this script's location for direct CLI use.
ROOT="${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EXT="$ROOT/tools/fetch/extension.bzl"
RUNTIME="${WILD_RUNTIME:-crun}"
IMAGE="${WILD_IMAGE:-bazel-wild-baseline:latest}"
CACHE="${WILD_CACHE:-$HOME/.cache/wild}"
SRC_CACHE="$CACHE/src"
mkdir -p "$SRC_CACHE" "$CACHE/home"

runfile() {
  local path="$1"
  if [[ -n "${RUNFILES_DIR:-}" ]]; then
    for prefix in "_main" "${TEST_WORKSPACE:-}"; do
      [[ -n "$prefix" && -e "$RUNFILES_DIR/$prefix/$path" ]] && { printf '%s\n' "$RUNFILES_DIR/$prefix/$path"; return 0; }
    done
    [[ -e "$RUNFILES_DIR/$path" ]] && { printf '%s\n' "$RUNFILES_DIR/$path"; return 0; }
  fi
  if [[ -n "${RUNFILES_MANIFEST_FILE:-}" && -f "$RUNFILES_MANIFEST_FILE" ]]; then
    awk -v p="_main/$path" '$1 == p {print substr($0, index($0, $2)); found=1; exit} END {exit !found}' "$RUNFILES_MANIFEST_FILE" && return 0
    awk -v p="$path" '$1 == p {print substr($0, index($0, $2)); found=1; exit} END {exit !found}' "$RUNFILES_MANIFEST_FILE" && return 0
  fi
  local from_root="$ROOT/bazel-bin/$path"
  [[ -e "$from_root" ]] && { printf '%s\n' "$from_root"; return 0; }
  return 1
}

rootfs_from_oci_layout() {
  local layout="$1"
  local mani rootfs digest_file
  mani="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1] + '/index.json'))['manifests'][0]['digest'].split(':')[1])" "$layout")"
  rootfs="$CACHE/rootfs/$mani"
  digest_file="$rootfs/.manifest-digest"
  if [[ -f "$digest_file" && "$(cat "$digest_file")" == "$mani" ]]; then
    printf '%s\n' "$rootfs"
    return 0
  fi

  echo ">> extracting image rootfs -> $rootfs" >&2
  rm -rf "$rootfs"
  mkdir -p "$rootfs"

  mapfile -t layers < <(python3 - "$layout" "$mani" <<'PY'
import json, sys
layout, mani = sys.argv[1], sys.argv[2]
m = json.load(open(f"{layout}/blobs/sha256/{mani}"))
for l in m["layers"]:
    print(l["digest"].split(":")[1], "gz" if l["mediaType"].endswith("gzip") else "raw")
PY
)

  local first=1 entry hex gz z
  for entry in "${layers[@]}"; do
    read -r hex gz <<<"$entry"
    z=""; [[ "$gz" == gz ]] && z="z"
    tar --overwrite -p${z}xf "$layout/blobs/sha256/$hex" -C "$rootfs" \
      --warning=no-unknown-keyword --no-same-owner 2>/dev/null || true
    if [[ "$first" == 1 ]]; then
      for d in bin lib lib64 sbin; do
        [[ -L "$rootfs/$d" ]] && rm -f "$rootfs/$d"
      done
      first=0
    fi
  done

  echo "$mani" > "$digest_file"
  printf '%s\n' "$rootfs"
}

key="${1:?usage: run.sh <key> <version|-> <build|test> [targets...]}"
ver="${2:-}"; cmd="${3:-build}"; shift 3 || true
targets=("$@")

# Runtime present?
if [[ "$RUNTIME" == crun ]]; then
  OCI_LAYOUT="${WILD_OCI_LAYOUT:-$(runfile wild/image/image_oci_layout || runfile wild/image/oci_layout || true)}"
  CRUN="${WILD_CRUN:-$(runfile wild/image/crun.bin || true)}"
  if [[ -n "${WILD_ROOTFS:-}" ]]; then
    ROOTFS="$WILD_ROOTFS"
  elif [[ -n "$OCI_LAYOUT" && -d "$OCI_LAYOUT" ]]; then
    ROOTFS="$(rootfs_from_oci_layout "$OCI_LAYOUT")"
  else
    ROOTFS=""
  fi
  if [[ ! -x "$CRUN" || ! -d "$ROOTFS" ]]; then
    echo "error: daemonless runtime runfiles are missing." >&2
    echo "expected executable: wild/image/crun.bin" >&2
    echo "expected directory:  wild/image/image_oci_layout" >&2
    exit 1
  fi
elif [[ "$RUNTIME" == docker ]]; then
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "error: image '$IMAGE' not loaded. Build it first with:" >&2
    echo "    bazel run //wild/image:load" >&2
    exit 1
  fi
else
  echo "error: unknown WILD_RUNTIME='$RUNTIME' (use crun or docker)" >&2; exit 2
fi

# Pull url/sha256/filename for "<key>_archive" out of extension.bzl.
read -r url sha filename < <(awk -v key="\"${key}_archive\":" '
  $0 ~ key {f=1}
  f && /"url":/      {u=$0}
  f && /"sha256":/   {s=$0}
  f && /"filename":/ {n=$0}
  f && /},/ {
    gsub(/.*"url": *"|".*/,"",u); gsub(/.*"sha256": *"|".*/,"",s); gsub(/.*"filename": *"|".*/,"",n)
    print u, s, n; exit
  }' "$EXT")
[[ -z "${url:-}" ]] && { echo "no '${key}_archive' in $EXT" >&2; exit 2; }

tarball="$SRC_CACHE/$filename"
if [[ ! -f "$tarball" ]]; then echo ">> fetching $url"; curl -fsSL -o "$tarball" "$url"; fi
echo "$sha  $tarball" | sha256sum -c - >/dev/null

# `|| true` so tar's SIGPIPE (head closes the pipe early) doesn't trip pipefail.
strip="$( { tar -tzf "$tarball" || true; } | head -1)"; strip="${strip%%/*}"
workdir="$SRC_CACHE/$strip"
[[ -d "$workdir" ]] || { echo ">> extracting $strip"; tar -xzf "$tarball" -C "$SRC_CACHE"; }

# Pin the project's known-good Bazel (the version column). "-" leaves bazelisk
# to honor the repo's .bazelversion (or its default).
env_args=()
[[ -n "$ver" && "$ver" != "-" ]] && env_args+=(-e "USE_BAZEL_VERSION=$ver")

# Every project mounts its source at /work, so give each its own Bazel output
# base (keyed by project) — otherwise they'd collide in one shared base and
# re-fetch each other's deps. Lives under the mounted $HOME so reruns stay warm.
startup=("--output_user_root=/home/wild/ob/$key")

# Extra bazel flags (e.g. --verbose_failures) go before the `--` marker; the
# targets go after it so negative patterns like `-//:exhaustive_test` parse as
# target patterns rather than options. A shared, content-addressed repository
# cache (under the mounted $HOME) means the BCR + toolchains download once
# across all projects rather than once per project's output base.
flags=("--repository_cache=/home/wild/repocache")
if [[ -n "${WILD_BAZEL_FLAGS:-}" ]]; then
  read -ra _extra <<<"$WILD_BAZEL_FLAGS"; flags+=("${_extra[@]}")
fi

echo ">> [$RUNTIME] bazelisk $cmd ${targets[*]}   (project=$key, bazel=${ver:--})"

# The full bazelisk argv, identical for both runtimes.
bazelisk=(/usr/local/bin/bazelisk "${startup[@]}" "$cmd" "${flags[@]}" -- "${targets[@]}")

if [[ "$RUNTIME" == docker ]]; then
  exec docker run --rm \
    -v "$workdir":/work \
    -v "$CACHE/home":/home/wild \
    "${env_args[@]}" \
    "$IMAGE" "${startup[@]}" "$cmd" "${flags[@]}" -- "${targets[@]}"
fi

# --- crun: a rootless OCI bundle over the staged rootfs, no daemon -------------
bundle="$(mktemp -d "$CACHE/bundle.XXXXXX")"
trap 'rm -rf "$bundle"' EXIT
"$CRUN" spec --rootless --bundle "$bundle" >/dev/null

ENV_JSON="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/home/wild
JAVA_HOME=/usr/lib/jvm/default-java
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
[[ -n "$ver" && "$ver" != "-" ]] && ENV_JSON+=$'\n'"USE_BAZEL_VERSION=$ver"

ROOTFS="$ROOTFS" WORKDIR="$workdir" HOMEDIR="$CACHE/home" ENVS="$ENV_JSON" \
python3 - "$bundle/config.json" "${bazelisk[@]}" <<'PY'
import json, os, sys
cfg, args = sys.argv[1], sys.argv[2:]
c = json.load(open(cfg))
c["root"] = {"path": os.environ["ROOTFS"], "readonly": True}
c["process"]["args"] = args
c["process"]["cwd"] = "/work"
c["process"]["terminal"] = False
c["process"]["env"] = [l for l in os.environ["ENVS"].splitlines() if l]
# Share the host network (so downloads resolve) — drop the network namespace.
c["linux"]["namespaces"] = [n for n in c["linux"]["namespaces"] if n["type"] != "network"]
c["linux"]["resources"] = {}  # rootless, no cgroup limits
c["mounts"] += [
    {"destination": "/work", "type": "bind", "source": os.environ["WORKDIR"], "options": ["rbind", "rw"]},
    {"destination": "/home/wild", "type": "bind", "source": os.environ["HOMEDIR"], "options": ["rbind", "rw"]},
    {"destination": "/etc/resolv.conf", "type": "bind", "source": "/etc/resolv.conf", "options": ["rbind", "ro"]},
]
json.dump(c, open(cfg, "w"), indent=2)
PY

exec "$CRUN" --cgroup-manager=disabled run -b "$bundle" "wild-$key-$$"
