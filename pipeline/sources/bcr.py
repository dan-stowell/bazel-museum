"""Source: the Bazel Central Registry (BCR).

Every module in the registry has a modules/<name>/metadata.json describing its
upstream repository. We download a single tarball of the registry (one request,
no auth required) and read every metadata.json from it, then classify each
module as project / ruleset / tooling (see classify.py).

The registry is mostly rulesets and tooling, but it also contains many real
open-source projects/libraries that build with Bazel (abseil-cpp, grpc,
protobuf, re2, ...) -- exactly what this museum wants.
"""

import io
import json
import tarfile

from .. import classify, model

SOURCE_ID = "bcr"
SOURCE_URL = "https://github.com/bazelbuild/bazel-central-registry"
_TARBALL = "https://codeload.github.com/bazelbuild/bazel-central-registry/tar.gz/refs/heads/main"


def _repo_from_metadata(meta):
    """Extract (owner, repo) from a BCR metadata.json, or None."""
    for entry in meta.get("repository", []) or []:
        # Entries look like "github:owner/repo".
        if entry.startswith("github:"):
            spec = entry[len("github:"):]
            if "/" in spec:
                owner, _, repo = spec.partition("/")
                if owner and repo:
                    return owner, repo
    # Fall back to homepage if it points at github.
    gh = model.parse_github(meta.get("homepage", ""))
    return gh


def parse(tar_bytes):
    projects = []
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:gz") as tar:
        for member in tar:
            if not member.isfile():
                continue
            parts = member.name.split("/")
            # <prefix>/modules/<module_name>/metadata.json
            if len(parts) < 4 or parts[-3] != "modules" or parts[-1] != "metadata.json":
                continue
            module_name = parts[-2]
            f = tar.extractfile(member)
            if f is None:
                continue
            try:
                meta = json.loads(f.read().decode("utf-8"))
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
            gh = _repo_from_metadata(meta)
            if not gh:
                continue
            owner, repo = gh
            category, reason = classify.classify_bcr(module_name, owner)
            projects.append(
                model.Project(
                    owner=owner,
                    repo_name=repo,
                    name=module_name,
                    description="",
                    category=category,
                    classification_reason=f"BCR: {reason}",
                    sources=[SOURCE_ID],
                )
            )
    return projects


def fetch():
    from .. import netfetch

    return parse(netfetch.get_bytes(_TARBALL))
