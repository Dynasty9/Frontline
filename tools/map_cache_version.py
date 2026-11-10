"""Stamp source scripts before exporting bytecode; native/content hashes remain runtime checks."""
import hashlib
from pathlib import Path


def stamp(root: Path) -> str:
    records = []
    sources = [root / "project.godot"]
    for folder in ("scripts", "assets"):
        sources.extend(path for path in (root / folder).rglob("*")
                       if path.suffix in (".gd", ".tres", ".tscn"))
    for path in sorted(sources):
        digest = hashlib.sha256(path.read_text(encoding="utf-8").encode()).hexdigest()
        records.append(f"{path.relative_to(root).as_posix()}\n{digest}\n")
    digest = hashlib.sha256("".join(sorted(records)).encode()).hexdigest()
    destination = root / "bin/map-cache-code.sha256"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(digest + "\n", encoding="utf-8")
    return digest


if __name__ == "__main__":
    print(stamp(Path(__file__).resolve().parents[1]))
