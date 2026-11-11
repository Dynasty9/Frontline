"""Reject model branding and unreviewed authorship claims in tracked text."""

import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
# Agent instructions and historical capture/branch metadata are not product copy.
EXCLUDED = {
    "AGENTS.md", ".gitignore", ".dockerignore",
    ".github/scripts/check_model_names.py",
    ".github/scripts/test_model_names.py",
    ".github/attribution-allowlist.json",
    "tools/showcase/catalog.json",
    "docs/SCALING_PROGRESS.md",
    "changelog/v1.0.13/realistic-armament-effects/presentation-review.json",
}
AGENT_DIRS = (".agents/", ".claude/", ".codex/")
# shortcut: this is a maintained name list, extend it when new model families appear.
NAMES = re.compile(
    r"(?<![a-z0-9])(?:chat[\s_-]*gpt|gpt(?:[\s_-]*\d+(?:\.\d+)*)?|"
    r"claude|open[\s_-]*ai|anthropic|codex|co[\s_-]*pilot|gemini|"
    r"deep[\s_-]*seek|llama|mistral|grok|qwen|gemma)(?![a-z])",
    re.IGNORECASE,
)
ATTRIBUTION = re.compile(
    r"(?<![a-z0-9])(?:(?:co[\s_-]*)?authored|made|created|generated|written|built|"
    r"developed|designed|powered|assisted|produced|coded)[\s_-]+(?:by|with)(?![a-z0-9])|"
    r"\b(?:thanks|credits?)[\s_-]+to\b|\b(?:author|coauthor)[\s_-]*:|"
    r"\bai[\s_-]+(?:generated|assisted|authored|powered)\b|"
    r"\bwith[\s_-]+(?:the[\s_-]+)?(?:help|assistance)[\s_-]+(?:of|from)\b",
    re.IGNORECASE,
)
# Only reviewed, exact lines are exempt; adding another credit still fails.
ATTRIBUTION_ALLOWLIST = json.loads(
    (ROOT / ".github/attribution-allowlist.json").read_text(encoding="utf-8")
)


def included(path):
    return path not in EXCLUDED and not path.lower().startswith(AGENT_DIRS)


def findings(path, data):
    if not included(path) or b"\0" in data:
        return
    for number, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
        for match in NAMES.finditer(line):
            yield f"{path}:{number}: prohibited model/assistant name: {match.group()}"
        if ATTRIBUTION.search(line) and line not in ATTRIBUTION_ALLOWLIST.get(path, []):
            yield f"{path}:{number}: unreviewed attribution: {line.strip()}"


def main(root=ROOT):
    paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=root)
    failed = False
    for raw in paths.split(b"\0"):
        if not raw:
            continue
        path = raw.decode("utf-8")
        if not included(path):
            continue
        for finding in findings(path, (root / path).read_bytes()):
            print(finding)
            failed = True
    if not failed:
        print("Model name and attribution check passed.")
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
