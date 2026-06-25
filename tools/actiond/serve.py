"""Launch the hermetic actiond worker (a local Linux RE worker + cache).

`bazel run //tools/actiond:serve` boots actiond's Linux VM and serves the Remote
Execution API on a local endpoint. Leave it running, then run a museum project's
`*_actiond_linux_arm64` goal in another terminal; the inner build points its
`--remote_executor`/`--remote_cache` at this endpoint (see the ACTIOND_WORKER
overlay in //builds:overlays.bzl).

The worker is a persistent local *service* (like BuildBuddy, but on this host),
so it lives outside the museum's daemonless inner builds. Its `--root` holds the
guest-owned CAS/ActionCache; reusing it keeps the cache warm across restarts.

Env overrides:
  MUSEUM_ACTIOND_LISTEN  endpoint to listen on   (default 127.0.0.1:8980)
  MUSEUM_ACTIOND_ROOT    VM state / cache dir     (default ~/.cache/actiond/vm)
Any extra args are forwarded verbatim to `actiond serve-vm`.
"""

import os
import sys


def _resolve(rloc):
    from python.runfiles import runfiles
    rf = runfiles.Create()
    path = rf.Rlocation(rloc)
    if not path or not os.path.exists(path):
        sys.exit(f"actiond serve: could not resolve runfile: {rloc!r} -> {path!r}")
    return path


def main(argv):
    if len(argv) < 2:
        sys.exit("actiond serve: missing --actiond=<runfiles path> (set by the macro)")
    actiond_rloc = argv[1].removeprefix("--actiond=")
    extra = argv[2:]

    actiond = _resolve(actiond_rloc)
    listen = os.environ.get("MUSEUM_ACTIOND_LISTEN", "127.0.0.1:8980")
    root = os.environ.get("MUSEUM_ACTIOND_ROOT") or os.path.join(
        os.path.expanduser("~"), ".cache", "actiond", "vm")
    os.makedirs(root, exist_ok=True)

    cmd = [actiond, "serve-vm", "--listen=" + listen, "--root=" + root] + extra
    print(f"actiond serve: {' '.join(cmd)}", file=sys.stderr)
    os.execv(actiond, cmd)


if __name__ == "__main__":
    main(sys.argv)
