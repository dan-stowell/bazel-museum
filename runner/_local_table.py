#!/usr/bin/env python3
# Render the README's host-local sweep table from runner/local-results.tsv
# (produced by runner/local_sweep.sh). One row per museum project, two result
# columns — `:local_build` and `:local_test` — each marked:
#
#   ✅ success   ❌ failure   ⏱️ timeout   — missing (no such target)
#
#   python3 runner/_local_table.py
#
# Reuses the project display names/links from runner/_readme_table.py.
import csv
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _readme_table import META  # noqa: E402

SYMBOL = {"success": "✅", "failure": "❌", "timeout": "⏱️", "missing": "—"}


def test_cell(state, summary):
    """Symbol for a test result, annotating partial failures with N/M pass."""
    sym = SYMBOL.get(state, state)
    if state == "failure":
        m = re.search(r"Executed \d+ out of (\d+) tests?: (\d+) tests? pass", summary or "")
        if m:
            total, passed = int(m.group(1)), int(m.group(2))
            if passed:  # mostly-green, one or two env-sensitive failures
                sym += " (%d/%d)" % (passed, total)
    return sym


def main():
    rows = list(csv.DictReader(open("runner/local-results.tsv"), delimiter="\t"))
    rows.sort(key=lambda r: META.get(r["proj"], (r["proj"],))[0].lower())

    print("| Project | Bazel | `:local_build` | `:local_test` |")
    print("|---------|:-----:|:--------------:|:-------------:|")
    for r in rows:
        name, repo, _ = META.get(r["proj"], (r["proj"], "", ""))
        link = "[%s](%s)" % (name, repo) if repo else name
        b = SYMBOL.get(r["build"], r["build"])
        t = test_cell(r["test"], r.get("test_summary", ""))
        print("| %s | %s | %s | %s |" % (link, r["version"], b, t))

    n = len(rows)
    nb = sum(1 for r in rows if r["build"] == "success")
    nt = sum(1 for r in rows if r["test"] == "success")
    print()
    print("_Host-local sweep of %d projects: %d build and %d run their test suite "
          "directly on the host toolchain (✅ success · ❌ failure · ⏱️ timeout · "
          "— no such target)._" % (n, nb, nt))


if __name__ == "__main__":
    main()
