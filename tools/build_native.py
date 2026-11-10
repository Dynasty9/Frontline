"""Build the map-generation extension and authoritative server for native exports."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
from map_cache_version import stamp

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--target", help="Optional Rust target triple for cross compilation")
args = parser.parse_args()
destination = ROOT / "bin/native"
destination.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / "native/content.json", ROOT / "bin/content.json")


def build(target):
    cmd = ["cargo", "+1.94.0", "build", "--locked", "--release", "--manifest-path", str(ROOT / "native/Cargo.toml"), "-p", "frontline_sim", "-p", "frontline_server"]
    output = ROOT / "native/target"
    if target:
        cmd += ["--target", target]
        output /= target
    subprocess.run(cmd, cwd=ROOT, check=True)
    return output / "release"


if sys.platform == "darwin" and not args.target:
    targets = ["aarch64-apple-darwin", "x86_64-apple-darwin"]
    subprocess.run(["rustup", "target", "add", "--toolchain", "1.94.0", *targets], check=True)
    outputs = [build(target) for target in targets]
    (destination / "macos").mkdir(exist_ok=True)
    for name, staged in [("libfrontline_sim.dylib", destination / "libfrontline_sim.dylib"), ("frontline-server", destination / "macos/frontline-server")]:
        subprocess.run(["lipo", "-create", *(str(folder / name) for folder in outputs), "-output", str(staged)], check=True)
else:
    output = build(args.target)
    windows = "windows" in args.target if args.target else sys.platform == "win32"
    macos = "apple-darwin" in (args.target or "")
    library = "frontline_sim.dll" if windows else "libfrontline_sim.dylib" if macos else "libfrontline_sim.so"
    server = "frontline-server.exe" if windows else "frontline-server"
    if windows:
        subprocess.run([sys.executable, str(ROOT / "tools/check_windows_imports.py"),
                        str(output / library), str(output / server)], check=True)
    shutil.copy2(output / library, destination / library)
    server_dir = destination / "macos" if macos else destination
    server_dir.mkdir(exist_ok=True)
    shutil.copy2(output / server, server_dir / server)
(ROOT / "frontline_sim.gdextension").write_text('''[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = "4.6"
reloadable = false

[libraries]
windows.x86_64 = "res://bin/native/frontline_sim.dll"
linux.x86_64 = "res://bin/native/libfrontline_sim.so"
macos = "res://bin/native/libfrontline_sim.dylib"
web.wasm32 = "res://bin/web/frontline_sim.wasm"
''', encoding="utf-8")
stamp(ROOT)
print(f"Staged simulation binaries in {destination}")
