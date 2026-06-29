load("@rules_python//python:defs.bzl", "py_test")

def _extract_source_impl(ctx):
    out = ctx.actions.declare_directory(ctx.attr.name)
    args = ctx.actions.args()
    args.add(ctx.file.archive)
    args.add(out.path)
    args.add(ctx.attr.strip_prefix)
    ctx.actions.run_shell(
        inputs = [ctx.file.archive],
        outputs = [out],
        arguments = [args],
        command = """
set -euo pipefail
archive="$1"
out="$2"
strip_prefix="$3"
mkdir -p "$out"
if [[ -n "$strip_prefix" ]]; then
  tar -xzf "$archive" -C "$out" --strip-components=1 "$strip_prefix"
else
  tar -xzf "$archive" -C "$out"
fi
""",
    )
    return [DefaultInfo(files = depset([out]))]

extract_source = rule(
    implementation = _extract_source_impl,
    attrs = {
        "archive": attr.label(allow_single_file = True, mandatory = True),
        "strip_prefix": attr.string(),
    },
)

def kiss_build(name, source, bazel, targets, flags = [], visibility = None):
    out = name + ".tar"
    native.genrule(
        name = name,
        srcs = [
            source,
            bazel,
            "//tools/kiss:kiss_runner.py",
        ],
        outs = [out],
        cmd = "python3 $(location //tools/kiss:kiss_runner.py) " +
              "--mode=build " +
              "--source=$(location %s) " % source +
              "--bazel=$(location %s) " % bazel +
              "--bundle=$@ " +
              " ".join(["--flag='%s'" % flag for flag in flags]) + " " +
              " ".join(["--target='%s'" % target for target in targets]),
        executable = False,
        visibility = visibility,
    )

def kiss_test(name, source, bazel, targets, flags = [], visibility = None):
    py_test(
        name = name,
        srcs = ["//tools/kiss:kiss_runner.py"],
        main = "kiss_runner.py",
        args = [
            "--mode=test",
            "--source=$(rlocationpath %s)" % source,
            "--bazel=$(rlocationpath %s)" % bazel,
        ] + [
            "--flag=%s" % flag
            for flag in flags
        ] + [
            "--target=%s" % target
            for target in targets
        ],
        data = [
            source,
            bazel,
        ],
        deps = ["@rules_python//python/runfiles"],
        size = "large",
        timeout = "eternal",
        visibility = visibility,
    )
