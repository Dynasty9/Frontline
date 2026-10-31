"""Check presentation coverage and provenance without rendering or network access."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('changelog', ROOT / '.github/scripts/changelog.py')
changelog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(changelog)


def audit():
    catalog = json.loads((ROOT / 'tools/showcase/catalog.json').read_text())
    paths = {p.relative_to(ROOT).as_posix(): p for p in (ROOT / 'changelog').glob('*/*.md')}
    seen, errors = set(), []
    for item in catalog['entries']:
        key = item['entry']
        if key not in paths and key.startswith('changelog/unreleased/'):
            matches = [k for k in paths if Path(k).name == Path(key).name]
            if len(matches) == 1:
                key = matches[0]  # release filing preserves the presentation review
        if key in seen:
            errors.append(f'Duplicate entry: {key}')
        seen.add(key)
        if key not in paths:
            errors.append(f'Missing entry: {key}')
            continue
        entry = changelog.read_entry(paths[key])
        if item['medium'] not in {'text', 'still', 'motion', 'audio', 'measurement'}:
            errors.append(f'Unknown medium: {key}')
        if not item.get('rationale') or not item.get('stage') or not item.get('source_ref'):
            errors.append(f'Missing editorial decision or provenance: {key}')
        if item['medium'] == 'motion' and not entry['videos']:
            errors.append(f'Motion entry has no clip: {key}')
        if item['medium'] == 'still' and not entry['screenshots']:
            errors.append(f'Still entry has no image: {key}')
        def asset_path(value):
            # Filing a release moves the entry and its adjacent asset directory.
            old_folder = str(Path(item['entry']).with_suffix('')) + '/'
            new_folder = str(Path(key).with_suffix('')) + '/'
            if value.startswith(old_folder):
                value = new_folder + value[len(old_folder):]
            return (ROOT / value).resolve()

        for source in item.get('sources', []):
            file = asset_path(source['file'])
            if not file.is_relative_to(ROOT) or not file.is_file():
                errors.append(f'Missing source: {source["file"]}')
            elif hashlib.sha256(file.read_bytes()).hexdigest() != source['sha256']:
                errors.append(f'Source changed; review presentation: {source["file"]}')
        if item.get('output'):
            output = asset_path(item['output'])
            if not output.is_relative_to(ROOT) or not output.is_file() or output.stat().st_size > changelog.MAX_IMAGE:
                errors.append(f'Missing or oversized overview: {output}')
    errors += [f'Presentation decision needed: {key}' for key in sorted(paths.keys() - seen)]
    return catalog, errors


if __name__ == '__main__':
    catalog, errors = audit()
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        sys.exit(1)
    counts = {kind: sum(e['medium'] == kind for e in catalog['entries']) for kind in ['text', 'still', 'motion', 'audio', 'measurement']}
    print(f'Presentation audit: {len(catalog["entries"])} entries, {counts}; sources and outputs verified')
