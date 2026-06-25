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
  MUSEUM_ACTIOND_LISTEN      endpoint to listen on   (default 127.0.0.1:8980)
  MUSEUM_ACTIOND_ROOT        VM state / cache dir     (default ~/.cache/actiond/vm)
  MUSEUM_ACTIOND_MEMORY_MIB  guest RAM in MiB         (default 14336 = 14 GiB)
Any extra args are forwarded verbatim to `actiond serve-vm`.

The default guest RAM is deliberately generous: the museum's first build
compiles the whole hermetic LLVM toolchain (compiler-rt/libcxx/libunwind) from
source, and several concurrent clang/llvm-ar actions OOM-kill in a small VM.
14 GiB lets the build run at useful concurrency without OOM on a 16 GiB+ host.

Linux host prerequisites (macOS uses Hypervisor.framework and needs none):
actiond boots an embedded qemu-system with `-accel kvm` and a vhost-vsock
channel, so the worker process needs read/write on /dev/kvm and
/dev/vhost-vsock. Both are group `kvm`; add yourself once with
`sudo usermod -aG kvm $USER` (re-login to apply), or run this target with the
group active in the current shell: `sg kvm -c 'bazel run //tools/actiond:serve'`.
The serve target itself needs no privileges beyond that device access — the
inner build connects to the worker over TCP and runs unprivileged.
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
    memory_mib = os.environ.get("MUSEUM_ACTIOND_MEMORY_MIB", "14336")
    os.makedirs(root, exist_ok=True)

    cmd = [actiond, "serve-vm", "--listen=" + listen, "--root=" + root,
           "--memory-mib=" + memory_mib] + extra
    print(f"actiond serve: {' '.join(cmd)}", file=sys.stderr)
    os.execv(actiond, cmd)


if __name__ == "__main__":
    main(sys.argv)
