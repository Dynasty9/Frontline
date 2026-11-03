"""Build the Rust browser worker and Godot extension, then stage a complete web export.

Requires Rust 1.94.0, nightly-2026-01-15 with rust-src, and Emscripten 3.1.74 on PATH.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", required=True)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
args.godot = shutil.which(args.godot) or str(Path(args.godot).resolve())
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)

manifest = str(ROOT / "native/Cargo.toml")
subprocess.run(["cargo", "+1.94.0", "build", "--locked", "--release", "--target", "wasm32-unknown-unknown",
                "--manifest-path", manifest, "-p", "frontline_browser"], cwd=ROOT, check=True)
environment = os.environ.copy()
environment["GDRUST_GODOT_BIN"] = str(Path(args.godot).resolve())
environment["RUSTFLAGS"] = ("-C link-args=-sSIDE_MODULE=2 -C llvm-args=-enable-emscripten-cxx-exceptions=0 "
                            "-Z default-visibility=hidden -Z link-native-libraries=no -Z emscripten-wasm-eh=false")
subprocess.run(["cargo", "+nightly-2026-01-15", "build", "--locked", "--release", "-Zbuild-std",
                "--target", "wasm32-unknown-emscripten", "--manifest-path", manifest, "-p", "frontline_sim",
                "--features", "godot/experimental-wasm,godot/experimental-wasm-nothreads,godot/api-custom,godot/lazy-function-tables"],
               cwd=ROOT, env=environment, check=True)
staged = ROOT / "bin/web"
staged.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / "native/content.json", ROOT / "bin/content.json")
shutil.copy2(ROOT / "native/target/wasm32-unknown-emscripten/release/frontline_sim.wasm", staged)
extension = ROOT / "frontline_sim.gdextension"
if not extension.exists():
    extension.write_text('[configuration]\nentry_symbol = "gdext_rust_init"\ncompatibility_minimum = "4.6"\nreloadable = false\n\n[libraries]\n')
definition = extension.read_text()
if "web.wasm32" not in definition:
    extension.write_text(definition + 'web.wasm32 = "res://bin/web/frontline_sim.wasm"\n')
for options in [["--import"], ["--export-release", "Web", str(output / "index.html")]]:
    result = subprocess.run([args.godot, "--headless", "--path", str(ROOT), *options],
                            cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=True)
    print(result.stdout)
    if "SCRIPT ERROR" in result.stdout or "Parse Error" in result.stdout or "ERROR:" in result.stdout:
        raise SystemExit("Godot web export reported an error")
shutil.copy2(ROOT / "native/target/wasm32-unknown-unknown/release/frontline_browser.wasm", output)
shutil.copy2(ROOT / "tools/web/simulation-worker.js", output)
for name in ["index.wasm", "index.side.wasm", "index.pck", "frontline_sim.wasm", "frontline_browser.wasm"]:
    if not (output / name).is_file():
        raise SystemExit(f"Missing browser runtime: {name}")
print(f"Staged browser simulation in {output}")
