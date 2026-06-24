"""Core data model: the normalized representation of a discovered project."""

import re
from dataclasses import dataclass, field, asdict

# Category of an entry. Awesome-list "projects" sections yield PROJECT; BCR
# entries are classified heuristically (see classify.py).
CATEGORY_PROJECT = "project"
CATEGORY_RULESET = "ruleset"
CATEGORY_TOOLING = "tooling"
CATEGORY_UNKNOWN = "unknown"

# When the same repo shows up under different categories across sources, the
# more specific / more "buildable project" category wins.
_CATEGORY_PRIORITY = {
    CATEGORY_PROJECT: 3,
    CATEGORY_UNKNOWN: 2,
    CATEGORY_RULESET: 1,
    CATEGORY_TOOLING: 0,
}

_GITHUB_RE = re.compile(
    r"github\.com[:/]+(?P<owner>[^/\s]+)/(?P<repo>[^/\s#?)]+)",
    re.IGNORECASE,
)

# Owners/paths on github.com that are never real repositories.
_NON_REPO_OWNERS = {"sponsors", "about", "features", "topics", "orgs", "settings"}


def parse_github(url):
    """Return (owner, repo) for a github.com URL, or None if not parseable."""
    m = _GITHUB_RE.search(url or "")
    if not m:
        return None
    owner = m.group("owner")
    repo = m.group("repo")
    if owner.lower() in _NON_REPO_OWNERS:
        return None
    repo = repo.removesuffix(".git").rstrip("/")
    if not owner or not repo:
        return None
    return owner, repo


@dataclass
class Project:
    """A single discovered project, normalized across sources."""

    owner: str
    repo_name: str
    name: str = ""
    description: str = ""
    category: str = CATEGORY_UNKNOWN
    classification_reason: str = ""
    sources: list = field(default_factory=list)

    # Enrichment from the GitHub API (filled in optionally via gh).
    enriched: bool = False
    stars: int = 0
    archived: bool = False
    language: str = ""
    pushed_at: str = ""

    @property
    def key(self):
        """Dedup key: case-insensitive owner/repo."""
        return f"{self.owner.lower()}/{self.repo_name.lower()}"

    @property
    def repo_url(self):
        return f"https://github.com/{self.owner}/{self.repo_name}"

    def merge(self, other):
        """Fold another record for the same repo into this one."""
        for s in other.sources:
            if s not in self.sources:
                self.sources.append(s)
        if not self.name:
            self.name = other.name
        if not self.description:
            self.description = other.description
        if _CATEGORY_PRIORITY[other.category] > _CATEGORY_PRIORITY[self.category]:
            self.category = other.category
            self.classification_reason = other.classification_reason

    def to_dict(self):
        d = asdict(self)
        d.pop("owner")
        d.pop("repo_name")
        # Present a stable, readable ordering.
        return {
            "name": self.name or self.repo_name,
            "repo": self.repo_url,
            "category": self.category,
            "description": self.description,
            "sources": sorted(self.sources),
            "classification_reason": self.classification_reason,
            "stars": self.stars,
            "archived": self.archived,
            "language": self.language,
            "pushed_at": self.pushed_at,
            "enriched": self.enriched,
        }
