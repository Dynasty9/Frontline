"""Capture a controlled stage with fixed simulation timing and provenance."""
import argparse
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    stages = json.loads((ROOT / 'tools/showcase/stages.json').read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=stages)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', default='CURRENT BUILD')
    parser.add_argument('--renderer', choices=['gl_compatibility', 'forward_plus'], default=None,
                        help="Defaults to the stage's own renderer, else gl_compatibility")
    parser.add_argument('--legacy-effects', action='store_true', help='Use the historical two-argument explosion API')
    args = parser.parse_args()
    stage = stages[args.stage]
    renderer = args.renderer or stage.get('renderer', 'gl_compatibility')
    out = args.output.resolve()
    if out.exists() and any(out.iterdir()):
        parser.error('Use a new or empty output directory to avoid mixing captures.')
    godot = os.environ.get('GODOT') or shutil.which('godot')
    ffmpeg = os.environ.get('FFMPEG') or shutil.which('ffmpeg')
    if not godot or not ffmpeg:
        parser.error('Set GODOT and FFMPEG, or put both on PATH.')
    out.mkdir(parents=True, exist_ok=True)
    frames = out / 'frames'
    resolution = '1280x720'
    env = os.environ.copy()
    display = ['--position', '-10000,-10000']
    if os.environ.get('FL_SHOW_WINDOW') == '1':
        display = []
    elif sys.platform == 'darwin':
        display = ['--embedded', '--debug', '--ignore-error-breaks']
        env['FL_CAPTURE_SIZE'] = resolution
    command = [godot, *display, '--path', str(ROOT), '--rendering-method', renderer,
               '--audio-driver', 'Dummy', '--resolution', resolution,
               'res://' + stage['scene'], '--', '--clip=' + args.stage,
               '--label=' + args.label, '--frames=' + str(frames)]
    if args.legacy_effects:
        command.append('--legacy-effects')
    if stage.get('engine_fixed_fps'):
        command[1:1] = ['--fixed-fps', str(stage['engine_fixed_fps'])]
    with (out / 'capture.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=log, check=True, env=env, timeout=stage.get("timeout", 300))
    log = (out / 'capture.log').read_text()
    if any(error in log for error in ['SCRIPT ERROR', 'SHADER ERROR', 'Shader compilation failed', 'TESTRUN failed']):
        raise SystemExit('Capture has script or shader errors; inspect capture.log.')
    expected = stage['seconds'] * stage['fps']
    if len(list(frames.glob('*.png'))) != expected:
        raise SystemExit('Incomplete capture.')
    with (frames / '0000.png').open('rb') as first:
        width, height = struct.unpack('>II', first.read(24)[16:24])
    if f'{width}x{height}' != resolution:
        raise SystemExit(f'Expected {resolution} frames, captured {width}x{height}.')
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-framerate', str(stage['fps']),
                    '-i', str(frames / '%04d.png'), '-c:v', 'libvpx-vp9', '-crf', str(stage.get('crf', 30)),
                    '-b:v', str(stage.get('bitrate', '0')), '-pix_fmt', 'yuv420p', '-an', str(out / 'clip.webm')], check=True)
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-ss', '3', '-i', str(out / 'clip.webm'),
                    '-frames:v', '1', '-q:v', '2', str(out / 'poster.jpg')], check=True)
    changes = subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).splitlines()
    provenance = {
        'stage': args.stage,
        'source_ref': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'working_tree_dirty': bool(changes),
        'working_tree_changes': changes,
        'engine': subprocess.check_output([godot, '--version'], text=True).strip(),
        'command': command, 'parameters': stage,
        'legacy_pool_clock': 'Hold shown rig timestamps so wall-clock cleanup cannot truncate fixed-step particle lifetimes during offline readback.' if args.legacy_effects else None,
        'attribution': 'Current-build controlled demonstration; not original release footage.',
    }
    (out / 'capture.json').write_text(json.dumps(provenance, indent=2) + '\n')
    print(out / 'clip.webm')


if __name__ == '__main__':
    main()
