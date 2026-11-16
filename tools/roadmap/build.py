#!/usr/bin/env python3
"""Build the roadmap page from GitHub Issues.

Role: reads every issue (open and closed) and every release through `gh api graphql`,
groups the issues into epics and writes one self-contained HTML page: `template.html`
with the data embedded as JSON. `.github/workflows/roadmap.yml` runs it and publishes
the page on GitHub Pages; nothing is committed.

How issues become the roadmap (the conventions are in docs/agents/issue-tracker.md):
- An epic is a top-level issue with sub-issues: a spec (its implementation tickets)
  or a wayfinder map (its decision tickets). An older parent without the `spec`
  label counts as a spec.
- A spec's map is the first issue linked under its `## Origin` heading.
- Phases: a closed spec is shipped; an open spec is now; an open map with open
  decisions and no spec yet is next; issues labelled `roadmap:later` are later.
- Inbox: open issues outside every epic and not labelled `roadmap:later`, plus
  open tickets left under a closed spec. Pinned issues (the Roadmap issue) are skipped.
- A shipped epic belongs to the first release published after its last ticket closed.

Usage: python3 tools/roadmap/build.py [owner/repo] [out.html]
Needs `gh` signed in (or GH_TOKEN set) with read access to issues. Only the standard
library is used, so CI needs no install step.
"""
import datetime as dt
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LATER_LABEL = "roadmap:later"

QUERY = """
query($owner:String!, $name:String!, $cursor:String) {
  repository(owner:$owner, name:$name) {
    releases(first:100, orderBy:{field:CREATED_AT, direction:ASC}) { nodes { tagName publishedAt url isDraft } }
    issues(first:100, after:$cursor, orderBy:{field:CREATED_AT, direction:ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number title state url createdAt closedAt body isPinned
        labels(first:20) { nodes { name color } }
        parent { number }
        blockedBy(first:30) { nodes { number state } }
        assignees(first:5) { nodes { login } }
      }
    }
  }
}"""


def fetch(repo):
    owner, name = repo.split("/")
    issues, cursor = [], None
    while True:
        args = ["gh", "api", "graphql", "-f", f"query={QUERY}", "-F", f"owner={owner}", "-F", f"name={name}"]
        if cursor:
            args += ["-f", f"cursor={cursor}"]
        data = json.loads(subprocess.check_output(args))["data"]["repository"]
        issues += data["issues"]["nodes"]
        page = data["issues"]["pageInfo"]
        if not page["hasNextPage"]:
            releases = [r for r in data["releases"]["nodes"] if not r["isDraft"] and r["publishedAt"]]
            return issues, releases
        cursor = page["endCursor"]


def labels(issue):
    return [l["name"] for l in issue["labels"]["nodes"]]


def kind(issue):
    ls = labels(issue)
    if "wayfinder:map" in ls:
        return "map"
    if any(l.startswith("wayfinder:") for l in ls):
        return "decision"
    return "spec" if "spec" in ls else "ticket"


def origin_map(issue):
    section = re.search(r"## Origin\s+(.*?)(?:\n## |\Z)", issue["body"] or "", re.S)
    link = section and re.search(r"/issues/(\d+)", section.group(1))
    return int(link.group(1)) if link else None


def areas(issues):
    return sorted({l for i in issues for l in labels(i) if l.startswith("area:")})


def ticket(c):
    return {
        "number": c["number"], "title": c["title"], "url": c["url"], "state": c["state"],
        "closed": c["closedAt"],
        "blockedBy": [b["number"] for b in c["blockedBy"]["nodes"]],
        "openBlockers": [b["number"] for b in c["blockedBy"]["nodes"] if b["state"] == "OPEN"],
        "areas": areas([c]),
        "human": "ready-for-human" in labels(c),
        "assignees": [a["login"] for a in c["assignees"]["nodes"]],
    }


def model(repo, issues, releases):
    children = {}
    for i in issues:
        if i["parent"]:
            children.setdefault(i["parent"]["number"], []).append(i)

    epics = []
    for i in issues:
        kids = sorted(children.get(i["number"], []), key=lambda c: c["number"])
        if i["parent"] or not kids:
            continue
        k = "map" if kind(i) == "map" else "spec"
        done = sum(c["state"] == "CLOSED" for c in kids)
        finished = i["state"] == "CLOSED" or (k == "map" and done == len(kids))
        closed = [c["closedAt"] for c in kids if c["closedAt"]] + ([i["closedAt"]] if i["closedAt"] else [])
        end = max(closed, default=i["createdAt"]) if finished else None
        epics.append({
            "number": i["number"], "title": i["title"], "url": i["url"], "kind": k,
            "start": min([i["createdAt"]] + [c["createdAt"] for c in kids]), "end": end,
            "done": done, "total": len(kids), "areas": areas([i] + kids),
            "map": origin_map(i) if k == "spec" else None,
            "release": next((r["tagName"] for r in releases if end and r["publishedAt"] >= end), None),
            "kids": [ticket(c) for c in kids],
        })

    specced_maps = {e["map"] for e in epics if e["map"]}
    for e in epics:
        if e["end"]:
            e["phase"] = "shipped"
        elif e["kind"] == "spec" or e["number"] in specced_maps:
            e["phase"] = "now"
        else:
            e["phase"] = "next"

    in_epic = {e["number"] for e in epics} | {c["number"] for e in epics for c in e["kids"]}
    open_ = [i for i in issues if i["state"] == "OPEN" and not i["isPinned"]]
    later = [i for i in open_ if LATER_LABEL in labels(i) and i["number"] not in in_epic]
    inbox = [i for i in open_ if i["number"] not in in_epic and LATER_LABEL not in labels(i)]
    leftovers = [c for e in epics if e["phase"] == "shipped" and e["kind"] == "spec"
                 for c in e["kids"] if c["state"] == "OPEN"]
    brief = lambda i: {"number": i["number"], "title": i["title"], "url": i["url"], "labels": labels(i)}

    return {
        "repo": repo,
        "generated": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "today": dt.date.today().isoformat(),
        "epics": epics,
        "later": [brief(i) for i in later],
        "inbox": [brief(i) for i in inbox] + [dict(c, labels=c["areas"]) for c in leftovers],
        "releases": [{"tag": r["tagName"], "date": r["publishedAt"], "url": r["url"]} for r in releases],
        "colors": {l["name"]: "#" + l["color"] for i in issues for l in i["labels"]["nodes"]},
    }


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("GITHUB_REPOSITORY", "pkopczynski/lunar-lander")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "_site", "index.html")
    issues, releases = fetch(repo)
    data = json.dumps(model(repo, issues, releases)).replace("</", "<\\/")
    with open(os.path.join(HERE, "template.html")) as f:
        page = f.read().replace("/*DATA*/null", data)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w") as f:
        f.write(page)
    print(f"Wrote {out} from {len(issues)} issues and {len(releases)} releases.")


if __name__ == "__main__":
    main()
