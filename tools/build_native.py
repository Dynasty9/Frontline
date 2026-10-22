"""Build the numeric simulation extension and stage Godot's export inputs."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--target", help="Optional Rust target triple for cross compilation")
args = parser.parse_args()
cmd = ["cargo", "+1.94.0", "build", "--locked", "--release", "--manifest-path", str(ROOT / "native/Cargo.toml")]
target_dir = ROOT / "native/target"
if args.target:
    cmd += ["--target", args.target]
    target_dir /= args.target
subprocess.run(cmd, cwd=ROOT, check=True)
windows = "windows" in args.target if args.target else sys.platform == "win32"
library = "frontline_sim.dll" if windows else "libfrontline_sim.so"
destination = ROOT / "bin/native"
destination.mkdir(parents=True, exist_ok=True)
shutil.copy2(target_dir / "release" / library, destination / library)
(ROOT / "frontline_sim.gdextension").write_text('''[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = "4.6"
reloadable = false

[libraries]
windows.x86_64 = "res://bin/native/frontline_sim.dll"
linux.x86_64 = "res://bin/native/libfrontline_sim.so"
''', encoding="utf-8")
print(f"Staged {destination / library}")
