# bazel-museum

`bazel-museum` checks whether pinned real-world Bazel projects still build and
test with pinned Bazel clients.

The current approach is intentionally small:

1. Declare a project source archive as a Bazel dependency.
2. Extract that archive with the outer Bazel build.
3. Invoke the pinned inner Bazel inside the extracted source tree.
4. For `kiss_build`, package the useful inner build outputs into one tarball.

Older container, RBE, and runner experiments are not documented here. Use git
history if you need to resurrect them.

## Quick Start

Install Bazel or Bazelisk, then run the RE2 build:

```sh
bazel build //projects/re2:kiss_build
```

The output is:

```text
bazel-bin/projects/re2/kiss_build.tar
```

That tarball contains the inner Bazel build event stream, a manifest, and RE2's
top-level build outputs.

Run RE2's upstream tests:

```sh
bazel test //projects/re2:kiss_test
```

List all KISS build targets:

```sh
tools/kiss/run_builds.sh --list
```

Run all KISS builds sequentially, with a clean outer Bazel output tree before
each project:

```sh
tools/kiss/run_builds.sh 2>&1 | tee kiss-builds.log
```

Useful variants:

```sh
BAZEL_BUILD_FLAGS="--verbose_failures" tools/kiss/run_builds.sh 2>&1 | tee kiss-builds.log
tools/kiss/run_builds.sh --no-clean //projects/re2:kiss_build //projects/snappy:kiss_build
```

## Target Convention

Archive-backed projects under `//projects/<name>` may expose:

```text
//projects/<name>:kiss_build
//projects/<name>:kiss_test
```

`kiss_build` runs `bazel build` inside the pinned source tree and emits a tarball.
`kiss_test` runs `bazel test` inside the pinned source tree.

BCR-only project packages still exist under `//projects`, but they do not fit the
"invoke Bazel inside the upstream source archive" model yet, so they do not emit
KISS targets today.

## Current KISS Build Sweep

The local `kiss-builds.log` from this workspace reports 46 passing builds out
of 52 generated `kiss_build` targets.

Passing `kiss_build` targets:

```text
//projects/abseil_cpp:kiss_build
//projects/abseil_py:kiss_build
//projects/benchmark:kiss_build
//projects/boringssl:kiss_build
//projects/buildtools:kiss_build
//projects/catch2:kiss_build
//projects/cctz:kiss_build
//projects/cli11:kiss_build
//projects/copybara:kiss_build
//projects/cpptrace:kiss_build
//projects/cpu_features:kiss_build
//projects/crow:kiss_build
//projects/cxx:kiss_build
//projects/double_conversion:kiss_build
//projects/fast_float:kiss_build
//projects/flatbuffers:kiss_build
//projects/ftxui:kiss_build
//projects/fuzztest:kiss_build
//projects/gflags:kiss_build
//projects/glog:kiss_build
//projects/go_jsonnet:kiss_build
//projects/googletest:kiss_build
//projects/gperftools:kiss_build
//projects/grpc:kiss_build
//projects/grpc_gateway:kiss_build
//projects/highs:kiss_build
//projects/highway:kiss_build
//projects/json:kiss_build
//projects/jsoncpp:kiss_build
//projects/jsonnet:kiss_build
//projects/lcm:kiss_build
//projects/nsync:kiss_build
//projects/onetbb:kiss_build
//projects/opencc:kiss_build
//projects/openexr:kiss_build
//projects/opentelemetry_cpp:kiss_build
//projects/ortools:kiss_build
//projects/pcre2:kiss_build
//projects/prometheus_cpp:kiss_build
//projects/protobuf:kiss_build
//projects/quill:kiss_build
//projects/re2:kiss_build
//projects/snappy:kiss_build
//projects/verible:kiss_build
//projects/z3:kiss_build
//projects/zlib:kiss_build
```

Failing `kiss_build` targets from that sweep:

```text
//projects/bazel:kiss_build
//projects/brotli:kiss_build
//projects/doctest:kiss_build
//projects/iceoryx2:kiss_build
//projects/magic_enum:kiss_build
//projects/s2geometry:kiss_build
```

Projects with `kiss_test` targets:

```text
//projects/abseil_cpp:kiss_test
//projects/abseil_py:kiss_test
//projects/bazel:kiss_test
//projects/benchmark:kiss_test
//projects/boringssl:kiss_test
//projects/brotli_go:kiss_test
//projects/buildtools:kiss_test
//projects/catch2:kiss_test
//projects/cctz:kiss_test
//projects/cli11:kiss_test
//projects/copybara:kiss_test
//projects/cpptrace:kiss_test
//projects/cpu_features:kiss_test
//projects/cxx:kiss_test
//projects/double_conversion:kiss_test
//projects/fast_float:kiss_test
//projects/flatbuffers:kiss_test
//projects/ftxui:kiss_test
//projects/fuzztest:kiss_test
//projects/go_jsonnet:kiss_test
//projects/googletest:kiss_test
//projects/gperftools:kiss_test
//projects/grpc:kiss_test
//projects/grpc_gateway:kiss_test
//projects/highs:kiss_test
//projects/highway:kiss_test
//projects/iceoryx2:kiss_test
//projects/jsoncpp:kiss_test
//projects/jsonnet:kiss_test
//projects/lcm:kiss_test
//projects/magic_enum:kiss_test
//projects/nsync:kiss_test
//projects/onetbb:kiss_test
//projects/opencc:kiss_test
//projects/openexr:kiss_test
//projects/opentelemetry_cpp:kiss_test
//projects/ortools:kiss_test
//projects/prometheus_cpp:kiss_test
//projects/protobuf:kiss_test
//projects/re2:kiss_test
//projects/s2geometry:kiss_test
//projects/snappy:kiss_test
//projects/verible:kiss_test
```

## Implementation Notes

The shared KISS helpers live in `//tools/kiss`.

`kiss_build` uses an action-local inner Bazel `--output_user_root` so nested
Bazel has writable scratch space without using the host user's Bazel output
tree. The output root is not part of the final artifact; the declared output is
the `kiss_build.tar` bundle.

`tools/kiss/run_builds.sh` runs `bazel clean` before each project by default.
Disable that with `--no-clean` when you deliberately want outer Bazel caching
between projects.
