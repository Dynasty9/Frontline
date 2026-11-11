#!/usr/bin/env python3
"""Source-level construction index, not a runtime feature-presence oracle.

Walks direct calls from dispatch arms. Conditional branches are a union; dynamic
calls and inner-class methods are explicitly outside the analysis. JSON output
belongs outside Git; regenerate after changing builders.
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORDER = ['VmCore', 'VmGunship', 'VmAttack', 'VmFighter', 'VmNato', 'VmCsat',
         'VmIndep', 'VmCiv', 'VmHeli', 'VmPlane', 'VmBoat', 'VmShips']
FUNCTION = re.compile(r'^(?:static )?func (\w+)\(', re.M)
CALL = re.compile(r'(?<![\w.])(?:(\w+)\.)?(\w+)\s*\(')
# Strip comments and strings without changing line numbers or character offsets.
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*')
CANDIDATES = {
    'doors': r'\bdoor|\bhinge|\blatch', 'glazing': r'\bwindow|\bwindshield|\bwindscreen|\bglaz',
    'access': r'\bladder|\bstep|\brung', 'rails': r'\bhandrail|\bstanchion|\bgrab rail',
    'storage': r'\btoolbox|\bstowage|\bstorage|\bbin\b', 'hoses_cables': r'\bhose|\bcable|\brope',
    'vessels': r'\bfuel tank|\bsaddle|\bdrum', 'suspension': r'\baxle|\bsuspension|\bdifferential',
    'wipers': r'\bwiper', 'vents': r'\blouvre|\bgrille|\bintake',
}

def mask(text):
    return TOKEN.sub(lambda m: ''.join('\n' if c == '\n' else ' ' for c in m[0]), text)

def load_sources(root):
    functions, classes = {}, {}
    for path in sorted((root / 'scripts/game').rglob('*.gd')):
        source = path.read_text()
        cls = re.search(r'^class_name (\w+)', source, re.M)
        if not cls or not (cls[1].startswith('Vm') or cls[1].startswith('Vehicle')):
            continue
        cls = cls[1]
        classes[cls] = str(path.relative_to(root))
        matches = list(FUNCTION.finditer(source))
        for i, match in enumerate(matches):
            end = matches[i + 1].start() if i + 1 < len(matches) else len(source)
            body = source[match.start():end]
            functions[f'{cls}.{match[1]}'] = {
                'file': classes[cls], 'line': source[:match.start()].count('\n') + 1,
                'body': body, 'class': cls,
            }
    return functions, classes

def calls(body, cls, functions):
    result = set()
    # Omit the declaration itself; include only known direct function references.
    code = mask(body.split('\n', 1)[-1])
    for match in CALL.finditer(code):
        owner, name = match.groups()
        owner = cls if owner is None else ('VehicleModels' if owner == 'k' else owner)
        key = f'{owner}.{name}'
        if key in functions:
            result.add(key)
    return result

def dispatch(body):
    arms = {}
    current = []
    for line in body.splitlines():
        if re.match(r'^\t\t[^\t].*:\s*$', line):
            current = re.findall(r'"([^"\\]+)"', line)
            for key in current:
                arms[key] = []
        elif line.startswith('\t\t\t'):
            for key in current:
                arms[key].append(line)
    return {k: '\n' + '\n'.join(v) for k, v in arms.items()}

def make_index(root):
    functions, classes = load_sources(root)
    graph = {key: calls(item['body'], item['class'], functions) for key, item in functions.items()}
    owners, shadows, roots = {}, {}, {}
    for cls in ORDER:
        for model, body in dispatch(functions[f'{cls}.build']['body']).items():
            if model in owners:
                shadows.setdefault(model, []).append(cls)
            else:
                owners[model] = cls
                roots[model] = calls(body, cls, functions)
    # Convoy routing depends on team; avoid expanding whole family dispatchers.
    roots['truck'] = {'VmNato._hemtt', 'VmIndep._zamak', 'VmCore._truck'} & functions.keys()
    for i in range(5):
        owners[f'civilian_{i}'] = 'VehicleModels.build_car'
        roots[f'civilian_{i}'] = {'VehicleModels._car'}
    models = {}
    for model in sorted(owners):
        seen, pending = set(), list(roots[model])
        while pending:
            key = pending.pop()
            if key in seen or (key.endswith('.build') and key.split('.')[0].startswith('Vm')):
                continue
            seen.add(key)
            pending.extend(graph.get(key, set()) - seen)
        evidence = {}
        for feature, pattern in CANDIDATES.items():
            hits = []
            for key in sorted(seen):
                # Search authored family construction only, not generic helpers.
                if not key.startswith('Vm') and key != 'VehicleModels._car':
                    continue
                f = functions[key]
                for offset, line in enumerate(f['body'].splitlines()):
                    if re.search(pattern, line, re.I):
                        hits.append({'function': key, 'file': f['file'], 'line': f['line'] + offset})
            if hits:
                evidence[feature] = hits
        models[model] = {'owner': owners[model], 'roots': sorted(roots[model]),
            'shadowed': shadows.get(model, []),
            'shared_calls': {key: {'file': functions[key]['file'], 'line': functions[key]['line']}
                             for key in sorted(seen) if key.startswith('Vehicle') and not key.startswith('VehicleModels.')},
            'candidate_evidence': evidence}
    return {'schema': 1, 'limitations': [
        'Model keys, not roster aliases; resolve Defs.VEHICLES[kind].model first.',
        'Direct-call reachability only. Conditional branches are a union, not proof of runtime presence.',
        'Candidate evidence is a search aid, never an automatic migration instruction.',
        'Dynamic calls and inner-class methods need manual review.',
        'Convoy is a union of team-specific HEMTT, Zamak and fallback M35 construction.',
    ], 'models': models}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--roster', type=Path, help='Runtime alias export from roster-index.tscn')
    parser.add_argument('--model', help='Show one model and its reachable construction')
    args = parser.parse_args()
    result = make_index(ROOT)
    if args.roster:
        aliases = json.loads(args.roster.read_text())
        result['roster'] = {key: {**value, 'owner': result['models'].get(value['model'], {}).get('owner', 'VehicleModels fallback')} for key, value in sorted(aliases.items())}
    if args.model:
        if args.model not in result['models']:
            parser.error(f'Unknown model key: {args.model}')
        result['models'] = {args.model: result['models'][args.model]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Indexed {len(result["models"])} model keys in {args.output}')

if __name__ == '__main__':
    main()
