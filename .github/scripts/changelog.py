"""Frontline's changelog: one entry per change, gathered into releases.

Every pull request that changes the game adds an entry for players to
changelog/unreleased/ (changelog/README.md says how). Merging it releases
nothing: entries wait there until someone runs the release workflow (Actions >
Release > Run workflow). That files every waiting entry under changelog/vX.Y.Z/,
names the release after its headline change, and this script writes everything
that shows the changelog:

    web/src/changelog.json    the website's Changelog page and What's new
    CHANGELOG.md              the whole history, readable on GitHub
    (stdout of `notes`)       the GitHub release's notes

    changelog.py check [--base REF] [--require]   validate entries; with --require,
                                                  fail if the game changed but no entry was added
    changelog.py pending                          the entries waiting for the next release
    changelog.py release VERSION                  file every waiting entry under VERSION, then build
    changelog.py build                            regenerate the outputs from changelog/v*/
    changelog.py name VERSION                     the release's name
    changelog.py notes VERSION                    the release's notes (markdown)

Python 3.11+ (tomllib), standard library only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tomllib
from datetime import date, datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "changelog"
UNRELEASED = LOG / "unreleased"
WEB_JSON = ROOT / "web" / "src" / "changelog.json"
CHANGELOG_MD = ROOT / "CHANGELOG.md"
REPO = os.environ.get("GITHUB_REPOSITORY", "Dynasty9/Frontline")
WEBSITE = "https://web-production-5a4c1.up.railway.app"

KINDS = {"new": "New", "improved": "Improved", "fixed": "Fixed"}
KIND_ORDER = list(KINDS)
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}
MAX_IMAGE = 1_500_000
# what the game is made of: the same list as the release workflow's
GAME = re.compile(r"^(scripts/|assets/|project\.godot$|main\.tscn$|export_presets\.cfg$|icon\.svg$)")
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
VERSION_DIR = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")


class EntryError(Exception):
    pass


# --- reading -----------------------------------------------------------------------------

def read_entry(path: Path) -> dict:
    """An entry: TOML between +++ lines, then markdown details."""
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    m = re.match(r"\+\+\+\n(.*?)\n\+\+\+\n?(.*)", text, re.S)
    if not m:
        raise EntryError(f"{rel(path)}: must start with a +++ block (see changelog/README.md)")
    try:
        meta = tomllib.loads(m.group(1))
    except tomllib.TOMLDecodeError as e:
        raise EntryError(f"{rel(path)}: the +++ block isn't valid TOML: {e}") from e
    slug = path.stem
    entry = {
        "slug": slug,
        "title": str(meta.get("title", "")).strip(),
        "summary": " ".join(str(meta.get("summary", "")).split()),
        "kind": str(meta.get("kind", "")).strip(),
        "headline": bool(meta.get("headline", False)),
        "release_name": str(meta.get("release_name", "")).strip(),
        "screenshots": [],
        "body": m.group(2).strip(),
        "path": path,
    }
    problems = []
    if not SLUG.match(slug):
        problems.append("the file name must be lower-case words joined by hyphens, like fire-and-smoke.md")
    if not entry["title"] or len(entry["title"]) > 80:
        problems.append("title is required, at most 80 characters")
    if not entry["summary"] or len(entry["summary"]) > 320:
        problems.append("summary is required, at most 320 characters")
    if entry["kind"] not in KINDS:
        problems.append(f"kind must be one of {', '.join(KINDS)}")
    for s in meta.get("screenshots", []):
        f = path.parent / slug / str(s.get("file", ""))
        if not s.get("file") or not f.is_file():
            problems.append(f"screenshot {s.get('file')!r} isn't in {rel(path.parent / slug)}/")
            continue
        if f.suffix.lower() not in IMAGE_EXT:
            problems.append(f"{f.name}: screenshots are .jpg, .png or .webp")
        if f.stat().st_size > MAX_IMAGE:
            problems.append(f"{f.name} is {f.stat().st_size // 1000} KB: keep screenshots under {MAX_IMAGE // 1000} KB (a JPEG at quality 80)")
        entry["screenshots"].append({"file": f.name, "caption": str(s.get("caption", "")).strip()})
    if problems:
        raise EntryError(f"{rel(path)}:\n  - " + "\n  - ".join(problems))
    return entry


def read_dir(d: Path) -> list[dict]:
    return sort_entries([read_entry(p) for p in sorted(d.glob("*.md")) if p.name.lower() != "readme.md"])


def sort_entries(entries: list[dict]) -> list[dict]:
    return sorted(entries, key=lambda e: (not e["headline"], KIND_ORDER.index(e["kind"]) if e["kind"] in KINDS else 9, e["slug"]))


def release_name(entries: list[dict]) -> str:
    for e in entries:
        if e["release_name"]:
            return e["release_name"]
    return entries[0]["title"] if entries else "Maintenance"


def releases() -> list[dict]:
    """Every published release, newest first."""
    out = []
    for d in LOG.iterdir() if LOG.is_dir() else []:
        m = VERSION_DIR.match(d.name)
        if not (m and d.is_dir()):
            continue
        meta = tomllib.loads((d / "release.toml").read_text(encoding="utf-8")) if (d / "release.toml").is_file() else {}
        entries = read_dir(d)
        version = d.name[1:]
        out.append({
            "key": tuple(int(x) for x in m.groups()),
            "version": version,
            "tag": d.name,
            "name": str(meta.get("name") or release_name(entries)),
            "date": str(meta.get("date", "")),
            "summary": str(meta.get("summary") or (entries[0]["summary"] if entries else "")),
            "pull_requests": list(meta.get("pull_requests", [])),
            "entries": entries,
            "dir": d,
        })
    return sorted(out, key=lambda r: r["key"], reverse=True)


def rel(p: Path) -> str:
    try:
        return p.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(p)


def own_summary(r: dict) -> str:
    """The release's summary, unless it only repeats one of its entries'."""
    return "" if r["summary"] in {e["summary"] for e in r["entries"]} else r["summary"]


def image_url(r: dict, e: dict, s: dict) -> str:
    # served by GitHub from main, where release filed it: no copies of the
    # screenshots in the website's own files
    ref = os.environ.get("CHANGELOG_IMAGE_REF", "main")  # another branch, to preview the site before merging
    return f"https://raw.githubusercontent.com/{REPO}/{ref}/changelog/{r['tag']}/{e['slug']}/{s['file']}"


def release_url(r: dict) -> str:
    return f"https://github.com/{REPO}/releases/tag/{r['tag']}"


def nice_date(iso: str) -> str:
    try:
        d = date.fromisoformat(iso)
    except ValueError:
        return iso
    return f"{d.day} {d.strftime('%B %Y')}"


# --- writing ------------------------------------------------------------------------------

def build() -> None:
    rs = releases()
    data = {
        "releases": [
            {
                "version": r["version"],
                "tag": r["tag"],
                "name": r["name"],
                "date": r["date"],
                "summary": r["summary"],
                "url": release_url(r),
                "pull_requests": r["pull_requests"],
                "entries": [
                    {
                        "slug": e["slug"],
                        "title": e["title"],
                        "kind": e["kind"],
                        "summary": e["summary"],
                        "body": e["body"],
                        "screenshots": [{"url": image_url(r, e, s), "caption": s["caption"]} for s in e["screenshots"]],
                    }
                    for e in r["entries"]
                ],
            }
            for r in rs
        ]
    }
    WEB_JSON.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")

    md = [
        "# Changelog",
        "",
        "Every release of Frontline, newest first. The game updates itself; downloads, and this changelog with pictures,",
        f"are on [the website]({WEBSITE}/changelog/). Each change is written up in [`changelog/`](changelog/) as part of",
        "the pull request that makes it.",
        "",
    ]
    for r in rs:
        md += [f"## {r['tag']}: {r['name']}", "", f"*{nice_date(r['date'])}* · [Release on GitHub]({release_url(r)})", ""]
        if own_summary(r):
            md += [own_summary(r), ""]
        for kind, label in KINDS.items():
            group = [e for e in r["entries"] if e["kind"] == kind]
            if not group:
                continue
            md += [f"### {label}", ""]
            for e in group:
                md += [f"#### {e['title']}", "", e["summary"], ""]
                for s in e["screenshots"]:
                    md += [f"![{s['caption']}](changelog/{r['tag']}/{e['slug']}/{s['file']})", ""]
                if e["body"]:
                    md += [e["body"], ""]
    CHANGELOG_MD.write_text("\n".join(md).rstrip() + "\n", encoding="utf-8", newline="\n")


def notes(version: str) -> str:
    r = next((x for x in releases() if x["version"] == version), None)
    if not r:
        raise SystemExit(f"no changelog for v{version}")
    out = []
    if own_summary(r):
        out += [own_summary(r), ""]
    for kind, label in KINDS.items():
        group = [e for e in r["entries"] if e["kind"] == kind]
        if not group:
            continue
        out += [f"## {label}", ""]
        for e in group:
            out += [f"### {e['title']}", "", e["summary"], ""]
            for s in e["screenshots"]:
                out += [f"![{s['caption']}]({image_url(r, e, s)})", ""]
            if e["body"]:
                out += [e["body"], ""]
    out += [
        "## Get it",
        "",
        f"The game updates itself. To install it, download **Frontline-windows.zip** or **Frontline-linux.zip** below,"
        f" or from [the website]({WEBSITE}/#download), unzip it anywhere and run it.",
        "",
        f"The whole history, with pictures: [Changelog]({WEBSITE}/changelog/#{r['tag']}).",
    ]
    return "\n".join(out).rstrip() + "\n"


def pending() -> list[dict]:
    """The entries waiting in changelog/unreleased/ for the next release."""
    return read_dir(UNRELEASED) if UNRELEASED.is_dir() else []


def pr_of(path: Path) -> int | None:
    """The pull request that added an entry: a squash merge's subject ends
    with "(#123)"."""
    subjects = subprocess.run(["git", "log", "--diff-filter=A", "--format=%s", "--", rel(path)], cwd=ROOT,
                              capture_output=True, text=True).stdout.splitlines()
    m = re.search(r"\(#(\d+)\)\s*$", subjects[-1]) if subjects else None
    return int(m.group(1)) if m else None


def release(version: str, name: str = "") -> None:
    """File every waiting entry under changelog/vVERSION/: everything merged
    since the last release, which is what the workflow has just built. The
    release is called `name`, or else after its headline entry."""
    waiting = pending()
    if not waiting:
        raise SystemExit("nothing to release: there are no entries in changelog/unreleased/")
    dest = LOG / f"v{version}"
    if dest.exists():
        raise SystemExit(f"{rel(dest)} already exists")
    dest.mkdir(parents=True)
    prs = sorted({n for e in waiting if (n := pr_of(e["path"]))})
    for e in waiting:
        md = e["path"]
        shutil.move(str(md), dest / md.name)
        pics = UNRELEASED / md.stem
        if pics.is_dir():
            shutil.move(str(pics), dest / md.stem)
    entries = read_dir(dest)
    name = name.strip() or release_name(entries)
    toml_lines = [
        f'version = "{version}"',
        f"name = {json.dumps(name)}",
        f'date = "{datetime.now(timezone.utc).date().isoformat()}"',
    ]
    if prs:
        toml_lines.append(f"pull_requests = [{', '.join(str(n) for n in prs)}]")
    (dest / "release.toml").write_text("\n".join(toml_lines) + "\n", encoding="utf-8", newline="\n")
    print(f"v{version}: {name} ({len(entries)} entries: {', '.join(e['slug'] for e in entries)})", file=sys.stderr)
    build()


def check(base: str | None, require: bool) -> int:
    problems = []
    for d in [UNRELEASED] + [r["dir"] for r in releases_safe(problems)]:
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.md")):
            if p.name.lower() == "readme.md":
                continue
            try:
                read_entry(p)
            except EntryError as e:
                problems.append(str(e))
    if require and base:
        changed = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.split()
        game = [f for f in changed if GAME.match(f)]
        entries = [f for f in changed if f.startswith("changelog/unreleased/") and f.endswith(".md") and not f.lower().endswith("readme.md")]
        if game and not entries:
            problems.append(
                "This pull request changes the game but adds no changelog entry.\n"
                "  Add changelog/unreleased/<what-changed>.md (changelog/README.md shows how), or label the pull\n"
                "  request 'no changelog' if players needn't hear about it."
            )
    for p in problems:
        print(f"::error::{p}" if os.environ.get("GITHUB_ACTIONS") else p, file=sys.stderr)
    if not problems:
        print("changelog entries are fine")
    return 1 if problems else 0


def releases_safe(problems: list) -> list:
    try:
        return releases()
    except EntryError as e:
        problems.append(str(e))
        return []


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--base")
    c.add_argument("--require", action="store_true")
    sub.add_parser("pending")
    r = sub.add_parser("release")
    r.add_argument("version")
    r.add_argument("--name", default="", help="what to call the release (default: after its headline entry)")
    sub.add_parser("build")
    n = sub.add_parser("notes")
    n.add_argument("version")
    nm = sub.add_parser("name")
    nm.add_argument("version")
    a = ap.parse_args()
    if a.cmd == "check":
        sys.exit(check(a.base, a.require))
    if a.cmd == "pending":
        for e in pending():
            print(f"{e['kind']:<9}{e['slug']}: {e['title']}")
    elif a.cmd == "release":
        release(a.version, a.name)
    elif a.cmd == "build":
        build()
    elif a.cmd == "notes":
        sys.stdout.write(notes(a.version))
    elif a.cmd == "name":
        r = next((x for x in releases() if x["version"] == a.version), None)
        print(r["name"] if r else "")


if __name__ == "__main__":
    try:
        main()
    except EntryError as e:
        print(e, file=sys.stderr)
        sys.exit(1)
