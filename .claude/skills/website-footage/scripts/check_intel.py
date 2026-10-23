"""Check that what the website says about the game is still true.

    check_intel.py           report (exit 1 if anything is out of date)
    check_intel.py --fix     also rewrite the counts in web/src/lib/intel.ts

The site's copy lives in web/src/lib/intel.ts. This compares it with the game:

  counts     COUNTS.vehicles (Defs.VEHICLES plus the vehicle roster's keys),
             COUNTS.support (Defs.SUPPORT less its recon flights),
             COUNTS.missions (the missions the menu lists). --fix updates
             them; the stats, ticker and feature copy all read COUNTS.
  missions   MISSIONS against scripts/game/missions.gd: the same missions in
             the same order, titles and operation names exact, blurbs exact,
             the time of day against the mission's mood. The force line may be
             shortened on the site, so a difference there is only a note.
  radio      every RADIO line must come from a string in the game's scripts
             (grid references and %s placeholders count as wildcards; a line
             may be shortened).
  hardware   every name in the HARDWARE ticker must be a vehicle, support or
             mission name in the game.
  media      every clip and still the site uses must be in web/public/media.

Standard library only.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent
REPO = SKILL.parents[2]
INTEL = REPO / "web" / "src" / "lib" / "intel.ts"
MEDIA = REPO / "web" / "public" / "media"
STR = r'"((?:[^"\\]|\\.)*)"'

# how the site names a mission's mood (Missions.LIST "mood")
TIMES = {"dawn": "Dawn", "golden": "Golden hour", "overcast": "Overcast", "dusk": "Dusk", "night": "Night",
         "day": "Midday", "hazy": "Haze", "rain": "Rain"}


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def block(text: str, start: str, end_line: str) -> str:
    """From the line starting with `start` to the next line that is exactly `end_line`."""
    i = text.index(start)
    j = text.index("\n" + end_line + "\n", i)
    return text[i:j]


def game_counts() -> dict[str, int]:
    defs = read(REPO / "scripts" / "autoload" / "defs.gd")
    roster = read(REPO / "scripts" / "game" / "vehicle_roster.gd")
    vehicles = set(re.findall(r'^\t"(\w+)": \{', block(defs, "var VEHICLES := {", "}"), re.M))
    vehicles |= set(re.findall(r't\["(\w+)"\] = _v\(', roster))
    # fire support only: recon flights ("recon": true) spot for you but don't shoot
    entries = re.split(r'^\t(?="\w+": \{)', block(defs, "var SUPPORT := {", "}"), flags=re.M)[1:]
    support = [e for e in entries if '"recon": true' not in e]
    return {"vehicles": len(vehicles), "support": len(support), "missions": len(game_missions())}


def game_missions() -> list[dict[str, str]]:
    text = block(read(REPO / "scripts" / "game" / "missions.gd"), "const LIST := [", "]")
    out = []
    for entry in re.split(r'\n\t\{(?="key")', text)[1:]:
        if '"hidden": true' in entry:
            continue
        out.append(dict(re.findall(r'"(\w+)": ' + STR, entry)))
    return out


def site() -> dict:
    ts = read(INTEL)
    m = re.search(r"export const COUNTS = \{ vehicles: (\d+), support: (\d+), missions: (\d+) \}", ts)
    if not m:
        sys.exit("Can't find `export const COUNTS = { vehicles: N, support: N, missions: N }` in intel.ts.")
    radio = re.findall(r"\[\s*" + STR + r",\s*" + STR + r",?\s*\]", block(ts, "export const RADIO", "]"), re.S)
    hardware = re.findall(STR, block(ts, "export const HARDWARE", "]"))
    missions = [dict(re.findall(r"(\w+):\s*" + STR, e)) for e in block(ts, "export const MISSIONS", "]").split("{")[1:]]
    return {"counts": dict(zip(("vehicles", "support", "missions"), map(int, m.groups()))), "radio": radio,
            "hardware": hardware, "missions": missions, "ts": ts}


def words(s: str) -> list[str]:
    s = s.lower()
    s = re.sub(r"%[-+0-9.]*[sdfi]", " x ", s)  # a placeholder in the game's string
    s = re.sub(r"\b[a-l]\d{1,2}\b", " x ", s)  # a grid reference on the site ("C6")
    return re.findall(r"[a-z0-9]+", s)


def pairs(ws: list[str]) -> set[tuple[str, str]]:
    return set(zip(ws, ws[1:]))


def game_strings() -> list[set[tuple[str, str]]]:
    out = []
    for p in (REPO / "scripts").rglob("*.gd"):
        for s in re.findall(STR, read(p)):
            ws = words(s)
            if len(ws) >= 3:
                out.append(pairs(ws))
    return out


def from_game(text: str, corpus: list[set[tuple[str, str]]]) -> float:
    """How much of the line's wording (word pairs) one of the game's strings has."""
    mine = pairs(words(text))
    if not mine:
        return 0.0
    return max((len(mine & s) / len(mine) for s in corpus), default=0.0)


def names() -> list[str]:
    out = []
    for p in ("scripts/autoload/defs.gd", "scripts/game/vehicle_roster.gd", "scripts/game/missions.gd"):
        out += re.findall(STR, read(REPO / p))
    return [n for n in out if 2 <= len(n) <= 80]


def media_needed(s: dict) -> list[str]:
    feats = read(REPO / "web" / "src" / "components" / "features.tsx")
    need = ["hero.mp4", "hero.jpg", "reel.mp4", "reel.jpg", "reel.vtt"]
    for clip in re.findall(r'clip: "([\w-]+)"', feats):
        need += [f"{clip}.mp4", f"{clip}.jpg"]
    need += [f"m-{m['key']}.jpg" for m in s["missions"] if "key" in m]
    return need


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--fix", action="store_true", help="rewrite COUNTS in intel.ts to match the game")
    a = ap.parse_args()

    s = site()
    problems: list[str] = []
    notes: list[str] = []

    # counts
    counts = game_counts()
    for k, v in counts.items():
        if s["counts"][k] != v:
            problems.append(f"counts: the site says {s['counts'][k]} {k}, the game has {v}")
    if a.fix and counts != s["counts"]:
        line = f"export const COUNTS = {{ vehicles: {counts['vehicles']}, support: {counts['support']}, missions: {counts['missions']} }}"
        INTEL.write_text(re.sub(r"export const COUNTS = \{[^}]*\}", line, s["ts"], count=1), encoding="utf-8", newline="\n")
        print(f"fixed: {line}")
        problems = [p for p in problems if not p.startswith("counts:")]

    # missions
    gm, sm = game_missions(), s["missions"]
    if [m.get("key") for m in gm] != [m.get("key") for m in sm]:
        problems.append(f"missions: the game lists {[m.get('key') for m in gm]}, the site {[m.get('key') for m in sm]}")
    site_by_key = {m.get("key"): m for m in sm}
    for g in gm:
        m = site_by_key.get(g["key"])
        if not m:
            continue
        for field in ("title", "op", "blurb"):
            if m.get(field) != g.get(field):
                problems.append(f"missions/{g['key']}: {field} is {m.get(field)!r} on the site, {g.get(field)!r} in the game")
        want = TIMES.get(g.get("mood", ""), g.get("mood", "").capitalize())
        if m.get("time") != want:
            problems.append(f"missions/{g['key']}: time is {m.get('time')!r}, the game's mood is {g.get('mood')!r} ({want!r})")
        if m.get("force") != g.get("force"):
            notes.append(f"missions/{g['key']}: force on the site {m.get('force')!r}\n    in the game {g.get('force')!r}")

    # radio
    corpus = game_strings()
    for who, text in s["radio"]:
        score = from_game(text, corpus)
        if score < 0.6:
            problems.append(f"radio: no line in the game says {who}: {text!r} ({score:.0%} of its wording found)")

    # hardware
    known = names()
    low = [n.lower() for n in known]
    for item in s["hardware"]:
        i = item.lower()
        if not any(i in n or (len(n) >= 4 and n in i) for n in low):
            problems.append(f"hardware: {item!r} isn't a name in the game's tables")

    # media
    missing = [f for f in media_needed(s) if not (MEDIA / f).exists()]
    shots = json.loads(read(SKILL / "shots.json"))
    missing += [f"{o}.mp4" for o in shots["outputs"] if not (MEDIA / f"{o}.mp4").exists() and f"{o}.mp4" not in missing]
    for f in missing:
        problems.append(f"media: web/public/media/{f} is missing")

    for n in notes:
        print("note  " + n)
    for p in problems:
        print("STALE " + p)
    print(f"\ngame: {counts['vehicles']} vehicles, {counts['support']} fire-support assets, {counts['missions']} missions; "
          f"{len(s['radio'])} radio lines, {len(s['hardware'])} names checked")
    if problems:
        print(f"{len(problems)} thing(s) on the site are out of date with the game.")
        sys.exit(1)
    print("The site's copy matches the game.")


if __name__ == "__main__":
    main()
