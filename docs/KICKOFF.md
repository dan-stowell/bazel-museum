# Kickoff

This repo is the source of truth for the project. This file records the
original kickoff prompt (verbatim) and the clarifying notes that followed, so
the intent behind the design is never lost.

## Original kickoff prompt

> Good morning!
> I would like this repo to hold a collection of Bazel builds of public (open source) projects.
> There are three pieces to this:
>
> 1. A data pipeline to gather public projects that build with Bazel.
> Some potential sources:
> - https://github.com/nicolov/awesome-bazel
> - https://github.com/jin/awesome-bazel
> - the bazel central registry (would need to use heuristics to find open source projects that buid with bazel as opposed to bazel tooling or rulesets)
>
> 2. A way to run Bazel builds in isolation
> An idea:
> - define minimal container image that can run bazel (using rules_img)
> - provide targets so you can `bazel run //:project_xyz_bazel_build -- ...` inside that container
> - open to other ideas!
> - let's start with linux amd64, but linux arm64 would be the next natural step
> - do not assume daemons
>
> 3. The collection of Bazel builds itself:
> - project source code (probably as a dep in MODULE.bazel)
> - any necessary overlays or patches
>
> That's a lot! Let's start with the data pipeline. From there we'll pick a first project to exercise the other bits.
> Please use Bazel for everything. It should be possible to clone this repo to a host with only Bazel and build and run everything inside.
> Please document everything (including this kickoff prompt) in this repo. This repo is the source of truth for the project.
> Please commit and push often.
> Fine to commit to main -- you're the only person working on this project currently.

## Follow-up notes

> One note for the data pipeline: `gh` is auth'ed as me. You can assume the
> presence of an auth'ed gh for now.

> Actually: if you use gh, can you pull it in as a bazel dep, and find a way to
> pass a token to it?

This led to the hermetic `gh` setup described in [DESIGN.md](DESIGN.md): we
download a pinned `gh` release as a Bazel dependency rather than relying on the
host's `gh`, and pass it a token resolved from the environment (or, failing
that, the host's stored credentials).
