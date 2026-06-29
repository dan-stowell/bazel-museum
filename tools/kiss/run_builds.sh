#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: tools/kiss/run_builds.sh [--list] [--] [TARGET...]

Runs KISS build targets sequentially. With no TARGET arguments, discovers all
//projects/...:kiss_build targets. Extra Bazel flags can be supplied through
BAZEL_BUILD_FLAGS, for example:

  BAZEL_BUILD_FLAGS="--verbose_failures" tools/kiss/run_builds.sh 2>&1 | tee kiss-builds.log

Set BAZEL=/path/to/bazel to use a different Bazel client.
EOF
}

main() {
  local bazel_bin="${BAZEL:-bazel}"
  local list_only=0
  local -a targets=()

  while (($#)); do
    case "$1" in
      -h|--help)
        usage
        return 0
        ;;
      --list)
        list_only=1
        shift
        ;;
      --)
        shift
        targets+=("$@")
        break
        ;;
      -*)
        echo "run_builds.sh: unknown option: $1" >&2
        usage >&2
        return 2
        ;;
      *)
        targets+=("$1")
        shift
        ;;
    esac
  done

  if ((${#targets[@]} == 0)); then
    mapfile -t targets < <("$bazel_bin" query 'attr(name, "kiss_build", //projects/...)' | sort)
  fi

  if ((list_only)); then
    printf '%s\n' "${targets[@]}"
    return 0
  fi

  local -a bazel_flags=()
  if [[ -n "${BAZEL_BUILD_FLAGS:-}" ]]; then
    # Intentionally shell-split: this is a command-line convenience variable.
    # shellcheck disable=SC2206
    bazel_flags=(${BAZEL_BUILD_FLAGS})
  fi

  local -a passed=()
  local -a failed=()
  local target status

  for target in "${targets[@]}"; do
    printf '\n===== KISS BUILD %s =====\n' "$target" >&2
    "$bazel_bin" build "${bazel_flags[@]}" "$target"
    status=$?
    if ((status == 0)); then
      passed+=("$target")
      printf '===== PASS %s =====\n' "$target" >&2
    else
      failed+=("$target:$status")
      printf '===== FAIL %s status=%s =====\n' "$target" "$status" >&2
    fi
  done

  printf '\n===== KISS BUILD SUMMARY =====\n' >&2
  printf 'passed: %d\n' "${#passed[@]}" >&2
  printf 'failed: %d\n' "${#failed[@]}" >&2
  if ((${#failed[@]})); then
    printf '%s\n' "${failed[@]}" >&2
    return 1
  fi
}

main "$@"
