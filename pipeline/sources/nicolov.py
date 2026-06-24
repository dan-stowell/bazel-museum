"""Source: nicolov/awesome-bazel "Projects built with Bazel" section.

The README is Markdown. We grab the "## Projects built with Bazel" section and
parse its bullet list (it has "non-Google" / "Google" subsections, both of
which we keep). Each bullet looks like:

    * [Name](https://github.com/owner/repo) optional description
"""

import re

from .. import model

SOURCE_ID = "nicolov"
SOURCE_URL = "https://raw.githubusercontent.com/nicolov/awesome-bazel/master/README.md"

_SECTION_HEADING = "projects built with bazel"
_ITEM_RE = re.compile(
    r"^\s*[\*\-]\s*\[(?P<name>[^\]]+)\]\((?P<url>[^)]+)\)(?P<rest>.*)$"
)


def _clean_desc(rest):
    return rest.strip().lstrip(":-—– ").strip()


def parse(markdown):
    projects = []
    in_section = False
    for line in markdown.splitlines():
        if line.startswith("## "):
            in_section = line[3:].strip().lower().startswith(_SECTION_HEADING)
            continue
        if not in_section:
            continue
        m = _ITEM_RE.match(line)
        if not m:
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
                classification_reason="listed under nicolov 'Projects built with Bazel'",
                sources=[SOURCE_ID],
            )
        )
    return projects


def fetch():
    from .. import netfetch

    return parse(netfetch.get_text(SOURCE_URL))
