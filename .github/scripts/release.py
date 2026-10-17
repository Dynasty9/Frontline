"""A release's GitHub side: its draft, its pull request, and publishing it.

Releasing is one press and one merge. Actions > Release builds the game and
bakes the release on its own branch, release/vX.Y.Z (bake-release.sh), then:

    release.py hold VERSION               makes the release's open pull request a draft while
                                          it's rebuilt, so it can't be merged half-way
    release.py draft VERSION BAKED BUILD  uploads the build as a draft release at the baked
                                          commit: nothing anyone else can see yet
    release.py pr VERSION BAKED BUMP      opens the pull request that says what the release
                                          is (or brings the open one up to date), and closes
                                          any older release's

Merging that pull request runs Publish release (publish.yml):

    release.py publish [--version V] [--head SHA] [--pr N] [--dry-run]
        checks that the draft's downloads are the ones the merged release.json
        names, tags the baked commit and publishes the release. With no
        --version it publishes the newest release filed here that isn't out.

Run from a checkout of the repository with gh signed in (GH_TOKEN in a
workflow). Python 3.11+, standard library only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import changelog  # noqa: E402

ROOT = changelog.ROOT
REPO = changelog.REPO
GITHUB = f"https://github.com/{REPO}"
ACTIONS = bool(os.environ.get("GITHUB_ACTIONS"))
# a pull request's description holds at most 65,536 characters
MAX_BODY = 60_000


# --- plumbing -----------------------------------------------------------------------------

def run(*cmd: str, check: bool = True) -> str | None:
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    if r.returncode == 0:
        return r.stdout
    if check:
        fail(f"{' '.join(cmd[:3])} failed: {r.stderr.strip() or r.stdout.strip()}")
    return None


def gh(*args: str, check: bool = True) -> str | None:
    return run("gh", *args, check=check)


def api(path: str, *args: str, method: str = "GET", check: bool = True):
    out = gh("api", "-X", method, path, *args, check=check)
    return json.loads(out) if out and out.strip() else None


def git(*args: str) -> str:
    return (run("git", *args) or "").strip()


def warn(msg: str) -> None:
    print(f"::warning::{msg}" if ACTIONS else f"warning: {msg}", file=sys.stderr)


def fail(msg: str):
    raise SystemExit(f"::error::{msg}" if ACTIONS else msg)


def summary(markdown: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(markdown + "\n")


def temp_file(text: str, suffix: str = ".md") -> str:
    f = tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False, encoding="utf-8", dir=os.environ.get("RUNNER_TEMP"))
    f.write(text)
    f.close()
    return f.name


# --- what's there -------------------------------------------------------------------------

def releases_tagged(tag: str) -> list[dict]:
    """Every release, drafts too, that is tagged `tag` or will be once published.
    The newest hundred is plenty: a draft is always among the newest."""
    return [r for r in api(f"repos/{REPO}/releases?per_page=100") or [] if r["tag_name"] == tag]


def release_prs() -> list[dict]:
    """The open pull requests from release branches in this repository."""
    prs = json.loads(gh("pr", "list", "--state", "open", "--base", "main", "--limit", "100",
                        "--json", "number,headRefName,url,isDraft,isCrossRepository") or "[]")
    return [p for p in prs if p["headRefName"].startswith("release/v") and not p["isCrossRepository"]]


def filed(version: str) -> dict:
    r = next((x for x in changelog.releases() if x["version"] == version), None)
    if not r:
        fail(f"there's no changelog/v{version}/ here: run this on the release's own commit")
    return r


def notes(version: str, image_ref: str) -> str:
    """The release's notes, with its screenshots served from `image_ref`."""
    os.environ["CHANGELOG_IMAGE_REF"] = image_ref
    return changelog.notes(version)


def last_tag() -> str:
    tags = git("tag", "--list", "v[0-9]*.[0-9]*.[0-9]*", "--sort=-v:refname").splitlines()
    return tags[0] if tags else ""


def delete_drafts(tag: str) -> None:
    for r in releases_tagged(tag):
        if r["draft"]:
            api(f"repos/{REPO}/releases/{r['id']}", method="DELETE")
            print(f"deleted the old draft of {tag} (built at {r['target_commitish'][:10]})")


# --- preparing: hold, draft, pr ------------------------------------------------------------

def hold(version: str) -> None:
    for p in release_prs():
        if p["headRefName"] == f"release/v{version}" and not p["isDraft"]:
            if gh("pr", "ready", "--undo", str(p["number"]), check=False) is None:
                warn(f"couldn't make #{p['number']} a draft: don't merge it until this run has finished")
            else:
                print(f"#{p['number']} is a draft while it's rebuilt, so it can't be merged half-way")


def release_files(build_dir: str) -> list[Path]:
    """What a release offers: the zips (Frontline-<platform>.zip) and the
    installers (Frontline-windows-setup.exe, Frontline-macos.dmg)."""
    return sorted(p for pattern in ("Frontline-*.zip", "Frontline-*-setup.exe", "Frontline-*.dmg")
                  for p in Path(build_dir).glob(pattern))


def draft(version: str, baked: str, build_dir: str) -> None:
    tag = f"v{version}"
    if any(not r["draft"] for r in releases_tagged(tag)):
        fail(f"{tag} is already published")
    delete_drafts(tag)
    files = [str(p) for p in release_files(build_dir)]
    if not any(f.endswith(".zip") for f in files):
        fail(f"no Frontline-*.zip in {build_dir}")
    # the screenshots from the baked commit, so the draft shows them; publishing
    # rewrites the notes to take them from the tag
    gh("release", "create", tag, *files, "--draft", "--target", baked,
       "--title", f"Frontline {tag}: {filed(version)['name']}",
       "--notes-file", temp_file(notes(version, baked)))
    print(f"drafted {tag} at {baked[:10]}: {', '.join(Path(f).name for f in files)}")


def build_downloads(build_dir: str) -> list[dict]:
    """The downloads in `build_dir`, as the draft will hold them."""
    return [{"name": f.name, "size": f.stat().st_size, "sha256": hashlib.sha256(f.read_bytes()).hexdigest()}
            for f in release_files(build_dir)]


def draft_downloads(rel: dict) -> list[dict]:
    """The downloads in a draft release, with GitHub's SHA-256 of each."""
    return [{"name": a["name"], "size": a["size"], "sha256": (a.get("digest") or "").removeprefix("sha256:")}
            for a in sorted(rel.get("assets", []), key=lambda a: a["name"])]


def pr_body(version: str, baked: str, bump: str, draft_url: str, downloads: list[dict]) -> str:
    r = filed(version)
    tag = r["tag"]
    built = git("rev-parse", f"{baked}^")
    last = last_tag()
    run_id = os.environ.get("GITHUB_RUN_ID")
    if last:
        count = int(git("rev-list", "--count", f"{last}..{built}"))
        since = f", [{count} commit{'s' if count != 1 else ''} since {last}]({GITHUB}/compare/{last}...{built})"
        step = f"a {bump} step after `{last}`"
    else:
        since, step = "", "the first release"
    prs = ", ".join(f"#{n}" for n in r["pull_requests"])
    entries = len(r["entries"])
    sizes = ", ".join(f"`{a['name']}` ({a['size'] / 1e6:.1f} MB)" for a in downloads)
    sums = "\n".join(f"{a['sha256']}  {a['name']}" for a in downloads if a["sha256"])
    lines = [
        f"**Merging this releases Frontline {tag}: {r['name']}.** It publishes [the release]({draft_url}) on GitHub,"
        f" tagged `{tag}`, with the downloads below; puts it on [the website]({changelog.WEBSITE}) (the downloads and"
        f" the changelog page); and tells the matchmaker, and through it every copy of the game, that there's an"
        f" update. Railway redeploys the website and the matchmaker as it merges.",
        "",
        "| | |",
        "| --- | --- |",
        f"| **Version** | `{tag}`, {step} |",
        f"| **Built from** | `main` at {built[:10]}{since} |",
        f"| **Changes** | {entries} entr{'ies' if entries != 1 else 'y'}" + (f", from {prs}" if prs else "") + " |",
        f"| **Downloads** | {sizes}, waiting in [the draft release]({draft_url}) |",
        f"| **Dated** | {changelog.nice_date(r['date'])} |",
        "",
        f"To change the version or the name, or to take in what has merged since, run"
        f" [Release]({GITHUB}/actions/workflows/release.yml) again: it rebuilds the release and updates this pull"
        f" request. Don't push to this branch: the downloads are already built, so nothing added here would be in"
        f" them.",
        "",
        "<details><summary>SHA-256 checksums</summary>",
        "",
        "```text",
        sums,
        "```",
        "",
        "</details>",
        "",
    ]
    if run_id:
        lines += [f"Built by [Release run {run_id}]({GITHUB}/actions/runs/{run_id}).", ""]
    head = "\n".join(lines + ["---", "", "*The release notes, as they'll be published:*", "", ""])
    body = notes(version, baked)
    if len(head) + len(body) > MAX_BODY:
        body = body[: MAX_BODY - len(head)].rsplit("\n", 1)[0] + f"\n\n*...and more: the rest is in [the draft release]({draft_url}).*\n"
    return head + body


def pr(version: str, baked: str, bump: str) -> None:
    tag = f"v{version}"
    branch = f"release/{tag}"
    mine = next((r for r in releases_tagged(tag) if r["draft"] and r["target_commitish"] == baked), None)
    if not mine:
        fail(f"there's no draft of {tag} at {baked[:10]}: run `release.py draft` first")
    title = f"Release {tag}: {filed(version)['name']}"
    downloads = draft_downloads(api(f"repos/{REPO}/releases/{mine['id']}"))
    body = temp_file(pr_body(version, baked, bump, mine["html_url"], downloads))
    prs = release_prs()
    own = next((p for p in prs if p["headRefName"] == branch), None)
    if own:
        api(f"repos/{REPO}/pulls/{own['number']}", "-f", f"title={title}", "-F", f"body=@{body}", method="PATCH")
        gh("pr", "ready", str(own["number"]), check=False)
        url = own["url"]
        print(f"updated {url}")
    else:
        url = (gh("pr", "create", "--base", "main", "--head", branch, "--title", title, "--body-file", body, check=False) or "").strip()
        if not url:
            compare = f"{GITHUB}/compare/main...{branch}?expand=1"
            warn("GitHub Actions may not open pull requests here (Settings > Actions > General > Allow GitHub Actions"
                 f" to create and approve pull requests). Open it yourself, then merge it to publish {tag}: {compare}")
            summary(f"**Open [{tag}'s pull request]({compare}) and merge it** to publish the release.")
            url = compare
        else:
            print(f"opened {url}")
    # an older release that was never merged: this one ships its entries too
    for p in prs:
        if p["headRefName"] == branch:
            continue
        old = p["headRefName"].removeprefix("release/")
        if any(not r["draft"] for r in releases_tagged(old)):
            continue  # published already, the old way round: it still has to merge
        gh("pr", "close", str(p["number"]), "--delete-branch", "--comment",
           f"Replaced by {tag} ({url}), which ships everything this would have and anything merged since.")
        delete_drafts(old)
        print(f"closed #{p['number']} ({old}): {tag} replaces it")
    if url.startswith(f"{GITHUB}/pull/"):
        summary(f"## {title}\n\nNothing is public yet. **Merge [its pull request]({url}) to publish it.**")


# --- publishing ---------------------------------------------------------------------------

def check_downloads(version: str, rel: dict) -> list[str]:
    """What's wrong, if anything, with publishing `rel`: its downloads must be
    the ones the merged release.json names, since that's what the website
    links to and what the game's updater checks a download against."""
    web = json.loads((ROOT / "web" / "src" / "release.json").read_text(encoding="utf-8"))
    mm = json.loads((ROOT / "matchmaker" / "release.json").read_text(encoding="utf-8"))
    problems = []
    if web != mm:
        problems.append("web/src/release.json and matchmaker/release.json differ")
    if web.get("version") != version:
        problems.append(f"release.json is for {web.get('version')}, not {version}")
    assets = {a["name"]: a for a in rel.get("assets", [])}
    for want in [*web.get("assets", {}).values(), *web.get("installers", {}).values()]:
        got = assets.get(want["name"])
        if not got:
            problems.append(f"the draft has no {want['name']}")
        elif got["size"] != want["size"]:
            problems.append(f"{want['name']} is {got['size']} bytes in the draft, {want['size']} in release.json")
        elif got.get("digest") and got["digest"] != f"sha256:{want['sha256']}":
            problems.append(f"{want['name']}'s SHA-256 in the draft isn't the one in release.json")
        elif not got.get("digest"):
            warn(f"GitHub gave no checksum for {want['name']}, so only its size was checked")
    return problems


def tag_commit(tag: str, sha: str) -> None:
    ref = api(f"repos/{REPO}/git/ref/tags/{tag}", check=False)
    if ref:
        if ref["object"]["sha"] != sha:
            fail(f"{tag} already exists, at {ref['object']['sha'][:10]} rather than the build's {sha[:10]}")
        return
    api(f"repos/{REPO}/git/refs", "-f", f"ref=refs/tags/{tag}", "-f", f"sha={sha}", method="POST")
    print(f"tagged {sha[:10]} {tag}")


def publish(version: str | None, head: str | None, pr_number: str | None, dry_run: bool) -> None:
    if not version:
        # releases go out one at a time, so only the newest can be waiting
        filed_here = changelog.releases()
        if not filed_here:
            fail("no release is filed here")
        version = filed_here[0]["version"]
    tag = f"v{version}"
    r = filed(version)
    tagged = releases_tagged(tag)
    if any(not x["draft"] for x in tagged):
        print(f"{tag} is already published: nothing to do")
        return
    drafts = [x for x in tagged if x["draft"]]
    if not drafts:
        fail(f"there's no draft of {tag}, so nothing was built for it. Its release merged without one (was the"
             f" draft deleted?): build {tag} from release/{tag} and publish it by hand.")
    rel = next((x for x in drafts if x["target_commitish"] == head), None)
    if not rel:
        if len(drafts) > 1:
            fail(f"there are {len(drafts)} drafts of {tag}" + (f", none of them built at {head[:10]}" if head else "")
                 + ": delete all but the one to publish")
        rel = drafts[0]
        if head:
            warn(f"release/{tag} moved on after it was built (built at {rel['target_commitish'][:10]}, merged at"
                 f" {head[:10]}). The downloads are the build of {rel['target_commitish'][:10]}, which is what's"
                 f" tagged; anything added to the branch since ships with the next release.")
    baked = rel["target_commitish"]
    problems = check_downloads(version, api(f"repos/{REPO}/releases/{rel['id']}"))
    if problems:
        fail(f"{tag}'s draft doesn't match what the website and the matchmaker now offer, so it wasn't published: "
             + "; ".join(problems) + ". Run Release again to build it afresh.")
    title = f"Frontline {tag}: {r['name']}"
    if dry_run:
        print(f"would tag {baked[:10]} {tag} and publish {rel['html_url']} as {title!r}: its downloads check out")
        return
    tag_commit(tag, baked)
    payload = {"draft": False, "make_latest": "true", "tag_name": tag, "target_commitish": baked, "name": title,
               "body": notes(version, tag)}
    published = api(f"repos/{REPO}/releases/{rel['id']}", "--input", temp_file(json.dumps(payload), ".json"), method="PATCH")
    url = published["html_url"]
    print(f"published {url}")
    if not pr_number:
        merged = json.loads(gh("pr", "list", "--state", "merged", "--head", f"release/{tag}", "--json", "number", "--limit", "1") or "[]")
        pr_number = str(merged[0]["number"]) if merged else None
    if pr_number:
        gh("pr", "comment", pr_number, "--body", f"Published [{title}]({url}). The website and the matchmaker are"
           " redeploying from this merge; once they're up, every copy of the game hears there's an update.", check=False)
    # the tag holds the release's commit now
    api(f"repos/{REPO}/git/refs/heads/release/{tag}", method="DELETE", check=False)
    summary(f"## Published [{title}]({url})")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    h = sub.add_parser("hold")
    h.add_argument("version")
    d = sub.add_parser("draft")
    d.add_argument("version")
    d.add_argument("baked")
    d.add_argument("build", help="the folder the downloads are in")
    p = sub.add_parser("pr")
    p.add_argument("version")
    p.add_argument("baked")
    p.add_argument("bump")
    p.add_argument("--print", action="store_true", help="print the description instead of opening the pull request")
    p.add_argument("--build", default="build", help="with --print: where the downloads are (default build)")
    u = sub.add_parser("publish")
    u.add_argument("--version")
    u.add_argument("--head", help="the merged pull request's head commit")
    u.add_argument("--pr", help="the merged pull request's number")
    u.add_argument("--dry-run", action="store_true", help="check everything, change nothing")
    a = ap.parse_args()
    if a.cmd == "hold":
        hold(a.version)
    elif a.cmd == "draft":
        draft(a.version, a.baked, a.build)
    elif a.cmd == "pr" and a.print:
        sys.stdout.write(pr_body(a.version, a.baked, a.bump, f"{GITHUB}/releases", build_downloads(a.build)))
    elif a.cmd == "pr":
        pr(a.version, a.baked, a.bump)
    elif a.cmd == "publish":
        publish(a.version, a.head, a.pr, a.dry_run)


if __name__ == "__main__":
    try:
        main()
    except changelog.EntryError as e:
        fail(str(e))
