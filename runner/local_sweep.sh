#!/usr/bin/env bash
# Sweep every museum project's HOST-LOCAL build/test — the //projects/<p>:local_build
# and :local_test variants (bazelisk on the host with the host toolchain, not the
# //runner/image container). Records one of four states per goal:
#
#   success  bazel reported the build/test green (exit 0)
#   failure  bazel ran but the build/test did not pass
#   timeout  killed by the per-goal timeout
#   missing  the project declares no such target
#
# Source of truth for the README's "host-local sweep" table (runner/_local_table.py).
# Resumable: skips projects already in the results TSV. Per-project output bases
# (run.sh, keyed by project) keep reruns warm.
#
#   bash runner/local_sweep.sh                          # the whole matrix
#   RUNNER_ONLY="re2 snappy" bash runner/local_sweep.sh # just these
set -uo pipefail   # not -e: builds/tests are expected to fail and must continue

cd "$(dirname "${BASH_SOURCE[0]}")/.."
TSV="runner/local-results.tsv"
CACHE="${RUNNER_CACHE:-${WILD_CACHE:-$HOME/.cache/runner}}"
LOGS="$CACHE/localsweeplogs"; mkdir -p "$LOGS"
BUILD_TIMEOUT="${RUNNER_BUILD_TIMEOUT:-1800}"
TEST_TIMEOUT="${RUNNER_TEST_TIMEOUT:-1800}"
ONLY="${RUNNER_ONLY:-${WILD_ONLY:-}}"
[[ -f "$TSV" ]] || printf 'proj\tversion\tbuild\ttest\ttest_summary\n' > "$TSV"

classify_build() {  # <logfile> <rc>
  local f="$1" rc="$2"
  [[ "$rc" == 124 ]] && { echo timeout; return; }
  grep -q "Build completed successfully" "$f" && { echo success; return; }
  echo failure
}

# Pull "Executed N out of M tests: ..." from a test log for the record.
test_summary() {  # <logfile>
  grep -m1 -E "Executed [0-9]+ out of [0-9]+ tests" "$1" \
    | sed -E 's/\t/ /g; s/INFO: //' | cut -c1-80 || echo ""
}

classify_test() {  # <logfile> <rc>
  local f="$1" rc="$2"
  [[ "$rc" == 124 ]] && { echo timeout; return; }
  [[ "$rc" == 0 ]] && { echo success; return; }
  echo failure
}

while IFS= read -r row; do
  # Tab-split preserving empty fields (IFS=$'\t' read collapses them because tab
  # is IFS-whitespace — that would shift a project's empty build into its test).
  proj=$(cut -f1 <<<"$row"); key=$(cut -f2 <<<"$row"); version=$(cut -f3 <<<"$row")
  build=$(cut -f4 <<<"$row"); test=$(cut -f5 <<<"$row")
  [[ -n "$ONLY" && " $ONLY " != *" $proj "* ]] && continue
  grep -q "^${proj}	" "$TSV" && { echo "skip $proj (done)"; continue; }
  # Each project gets its own (unshared) Bazel output base, so disk grows fast.
  # Bail out cleanly when space runs low rather than recording bogus ENOSPC
  # failures — the sweep is resumable, so it continues after space is freed.
  avail=$(df -P "$CACHE" | awk 'NR==2 {print $4}')
  if (( avail < ${RUNNER_MIN_FREE_KB:-3000000} )); then
    echo "ABORT: only ${avail}KB free under $CACHE; free space and rerun." >&2
    break
  fi
  echo "==== $proj (key=$key bazel=$version) ===="

  bstat="missing"
  if [[ -n "$build" ]]; then
    read -ra BT <<<"$build"
    timeout "$BUILD_TIMEOUT" projects/run.sh "$key" "$version" local_build "${BT[@]}" \
      >"$LOGS/$proj.build.log" 2>&1
    bstat=$(classify_build "$LOGS/$proj.build.log" $?)
  fi
  echo "  local_build: $bstat"

  tstat="missing"; tsum=""
  if [[ -n "$test" ]]; then
    read -ra TT <<<"$test"
    timeout "$TEST_TIMEOUT" projects/run.sh "$key" "$version" local_test "${TT[@]}" \
      >"$LOGS/$proj.test.log" 2>&1
    rc=$?
    tstat=$(classify_test "$LOGS/$proj.test.log" $rc)
    tsum=$(test_summary "$LOGS/$proj.test.log")
  fi
  echo "  local_test:  $tstat   $tsum"

  printf '%s\t%s\t%s\t%s\t%s\n' "$proj" "$version" "$bstat" "$tstat" "$tsum" >> "$TSV"

  # Per-project output bases aren't shared, so a 33-project sweep would balloon
  # disk. Drop this project's base now that its result is recorded (build+test
  # already shared it). Set RUNNER_KEEP=1 to keep them warm for reruns.
  [[ -z "${RUNNER_KEEP:-}" ]] && rm -rf "$CACHE/local_ob/$key" 2>/dev/null
done < <(python3 runner/_sweep_projects.py)

echo "== local sweep complete =="
column -t -s$'\t' "$TSV"
