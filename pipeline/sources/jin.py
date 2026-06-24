"""Source: jin/awesome-bazel "Projects" section (under Resources).

The README mixes HTML (for the rules tables) and Markdown. The "### Projects"
section is a plain Markdown bullet list of real projects built with Bazel:

    - [owner/repo](https://github.com/owner/repo): description
    - [owner/repo](https://github.com/owner/repo) - description
"""

import re

from .. import model

SOURCE_ID = "jin"
SOURCE_URL = "https://raw.githubusercontent.com/jin/awesome-bazel/master/README.md"

_SECTION = "projects"
_ITEM_RE = re.compile(
    r"^\s*[\*\-]\s+\[(?P<name>[^\]]+)\]\((?P<url>[^)]+)\)(?P<rest>.*)$"
)


def _clean_desc(rest):
    return rest.strip().lstrip(":-—– ").strip()


def parse(markdown):
    projects = []
    in_section = False
    for line in markdown.splitlines():
        stripped = line.strip()
        if stripped.startswith("### "):
            in_section = stripped[4:].strip().lower() == _SECTION
            continue
        if stripped.startswith("## "):
            in_section = False
            continue
        if not in_section:
            continue
        m = _ITEM_RE.match(line)
        if not m:
            continue
        # Skip indented sub-bullets (e.g. annotations under a project).
        if line[: len(line) - len(line.lstrip())]:
            continue
        gh = model.parse_github(m.group("url"))
        if not gh:
            continue
        owner, repo = gh
        projects.append(
            model.Project(
                owner=owner,
                repo_name=repo,
                name=m.group("name").strip(),
                description=_clean_desc(m.group("rest")),
                category=model.CATEGORY_PROJECT,
                classification_reason="listed under jin 'Projects'",
                sources=[SOURCE_ID],
            )
        )
    return projects


def fetch():
    from .. import netfetch

    return parse(netfetch.get_text(SOURCE_URL))
