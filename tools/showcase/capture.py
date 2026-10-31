"""Capture a controlled stage with fixed simulation timing and provenance."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    stages = json.loads((ROOT / 'tools/showcase/stages.json').read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=stages)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', default='CURRENT BUILD')
    args = parser.parse_args()
    stage = stages[args.stage]
    out = args.output.resolve()
    if out.exists() and any(out.iterdir()):
        parser.error('Use a new or empty output directory to avoid mixing captures.')
    godot = os.environ.get('GODOT') or shutil.which('godot')
    ffmpeg = os.environ.get('FFMPEG') or shutil.which('ffmpeg')
    if not godot or not ffmpeg:
        parser.error('Set GODOT and FFMPEG, or put both on PATH.')
    out.mkdir(parents=True, exist_ok=True)
    frames = out / 'frames'
    command = [godot, '--path', str(ROOT), '--rendering-method', 'gl_compatibility',
               '--position', '-10000,-10000', '--resolution', '1280x720',
               'res://' + stage['scene'], '--', '--clip=' + args.stage,
               '--label=' + args.label, '--frames=' + str(frames)]
    with (out / 'capture.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=log, check=True, timeout=300)
    log = (out / 'capture.log').read_text()
    if 'SCRIPT ERROR' in log or 'TESTRUN failed' in log:
        raise SystemExit('Capture has script errors; inspect capture.log.')
    expected = stage['seconds'] * stage['fps']
    if len(list(frames.glob('*.png'))) != expected:
        raise SystemExit('Incomplete capture.')
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-framerate', str(stage['fps']),
                    '-i', str(frames / '%04d.png'), '-c:v', 'libvpx-vp9', '-crf', '30',
                    '-b:v', '0', '-pix_fmt', 'yuv420p', '-an', str(out / 'clip.webm')], check=True)
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-ss', '3', '-i', str(out / 'clip.webm'),
                    '-frames:v', '1', str(out / 'poster.jpg')], check=True)
    provenance = {
        'stage': args.stage,
        'source_ref': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'working_tree_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)),
        'command': command, 'parameters': stage,
        'attribution': 'Current-build controlled demonstration; not original release footage.',
    }
    (out / 'capture.json').write_text(json.dumps(provenance, indent=2) + '\n')
    print(out / 'clip.webm')


if __name__ == '__main__':
    main()
