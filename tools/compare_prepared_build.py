#!/usr/bin/env python3
"""Compare identical Highland Junction builds, without drawing or screenshots."""
import argparse
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)  # Never accept an earlier report.
    report = output / 'result.json'
    env = dict(os.environ, FL_PAIR_OUTPUT=str(report))
    root = Path(__file__).resolve().parent.parent
    with (output / 'engine.log').open('w') as log:
        result = subprocess.run([args.godot, '--headless', '--fixed-fps', '30',
                                 '--path', str(root),
                                 'tests/fixtures/prepared_pair.tscn'],
                                env=env, stdout=log, stderr=subprocess.STDOUT)
    log = (output / 'engine.log').read_text()
    if result.returncode or 'ERROR:' in log or not report.is_file():
        raise SystemExit('Invalid attempt: inspect engine.log; no timing conclusion.')
    data = json.loads(report.read_text())
    runs = data['runs']
    if data['failures'] or len(runs) != 6 or 'PREPARED_PAIR failures=0' not in log:
        raise SystemExit('Pair did not pass all state/path checks.')
    for row, requested in zip(runs, ['generated', 'prepared', 'prepared', 'generated', 'generated', 'prepared']):
        if row['requested'] != requested or row['observed_cached_structures_restored'] != (requested == 'prepared'):
            raise SystemExit('Unexpected build path.')
    print(json.dumps(data, indent=2))


if __name__ == '__main__':
    main()
