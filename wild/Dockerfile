# "In the wild" image: nothing but bazelisk.
#
# The museum proper makes projects hermetic *by injection* — a pinned inner
# Bazel, a hermetic LLVM toolchain, and per-project overlays. This image takes
# the opposite bet: the container is the only reproducibility boundary, and we
# run each project's build exactly as upstream ships it ("as found in nature").
#
# The final image carries the irreducible minimum to *run bazelisk*: a libc
# (debian-slim), CA certificates (bazelisk downloads Bazel, and the build fetches
# the BCR + toolchains over https), and the bazelisk binary itself. No compiler,
# no language SDK, no build tools. Whatever a build needs beyond that, it must
# bring itself — which is exactly what we're measuring.
#
# Build:  docker build -t bazel-wild --build-arg BAZELISK_VERSION=v1.25.0 wild/
#
# A two-stage build keeps even curl out of the final image.

FROM debian:bookworm-slim AS fetch
ARG BAZELISK_VERSION=v1.25.0
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL -o /bazelisk \
        "https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-linux-amd64" \
    && chmod +x /bazelisk

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /bazelisk /usr/local/bin/bazelisk
# bazelisk caches its downloaded Bazel here; the build's output base lives under
# HOME too. Both are mountable as a volume so reruns are warm.
ENV HOME=/home/wild
RUN mkdir -p /home/wild /work
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/bazelisk"]
