#!/usr/bin/env python3
"""Inventory authored construction sections and rank remaining extraction candidates.

This is source evidence, not a runtime bill of materials. Variants share a
conditional union; comments identify candidates, never prove geometry equivalence.
"""
import argparse
import importlib.util
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('construction_index', Path(__file__).with_name('construction-index.py'))
indexer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(indexer)
PRIMITIVE = re.compile(r'(?<!\w)(?:k\.)?_(?:box|bx|cyl|add|plane|sphere|zy|plate|patch|panel|rod|tube|slab|strut)\s*\(')

def sections(function, item):
    """Keep every executable section, including unlabelled code; ignore doc headers."""
    result, comments, code, start = [], [], [], item['line'] + 1
    def flush():
        if any(indexer.mask(line).strip() for line in code):
            result.append({'id': f'{function}:{start}', 'function': function,
                           'file': item['file'], 'line': start,
                           'label': ' '.join(comments) or 'Unlabelled construction / setup',
                           'code': '\n'.join(code)})
    for offset, line in enumerate(item['body'].splitlines()[1:], 1):
        if line and not line[0].isspace():
            continue  # next function's top-level documentation is not this body
        if re.match(r'^\s+#', line):
            if any(line.strip() for line in code):
                flush(); comments, code = [], []
            if not comments:
                start = item['line'] + offset
            comments.append(line.strip().lstrip('#').strip())
        else:
            if not comments and not code:
                start = item['line'] + offset
            code.append(line)
    flush()
    return result

def matches_category(category, section):
    function = section['function']
    if category.get('owners') and function.split('.')[0] not in category['owners']:
        return False
    if function in category.get('exclude_functions', []):
        return False
    # A named local helper can identify otherwise unlabelled construction.
    label = section['label']
    if label == 'Unlabelled construction / setup':
        label = function.split('.')[-1].replace('_', ' ')
    if category.get('exclude_pattern') and re.search(category['exclude_pattern'], label, re.I):
        return False
    return bool(re.search(category['pattern'], label, re.I))

def build(root=ROOT):
    functions, _ = indexer.load_sources(root)
    graph = {k: indexer.calls(f['body'], f['class'], functions) for k, f in functions.items()}
    def reachable(starts):
        seen, pending = set(), list(starts)
        while pending:
            key = pending.pop()
            if key in seen or (key.startswith('Vm') and key.endswith('.build')):
                continue
            seen.add(key); pending.extend(graph.get(key, set()) - seen)
        return seen
    index = indexer.make_index(root)
    categories = json.loads(Path(__file__).with_name('part-categories.json').read_text())
    all_sections, by_function = {}, {}
    for key, f in functions.items():
        if not key.startswith('Vm') and key != 'VehicleModels._car':
            continue
        by_function[key] = []
        for section in sections(key, f):
            # calls() expects a declaration before the body.
            direct = indexer.calls('\n' + section['code'], f['class'], functions)
            called = reachable(direct)
            section['shared'] = sorted(c for c in called if c.startswith('Vehicle') and not c.startswith('VehicleModels.') and '._' not in c)
            section['local_geometry'] = bool(PRIMITIVE.search(indexer.mask(section['code'])))
            section['candidates'] = []
            if section['local_geometry']:
                for category in categories:
                    if matches_category(category, section):
                        # Conservative: do not rank a section that already delegates
                        # this feature, even if some other local geometry remains.
                        if not any(c.startswith(prefix) for c in called for prefix in category.get('shared', [])):
                            section['candidates'].append(category['name'])
            section['calls'] = sorted(direct)
            all_sections[section['id']] = section
            by_function[key].append(section['id'])
    designs, models = {}, {}
    for model, info in index['models'].items():
        design = ' / '.join(info['roots'])
        if design not in designs:
            family = sorted(k for k in reachable(info['roots']) if k in by_function)
            refs = sorted({s for f in family for s in by_function[f]},
                          key=lambda s: (all_sections[s]['file'], all_sections[s]['line']))
            designs[design] = {'models': [], 'roots': info['roots'], 'functions': family,
                               'sections': refs, 'shared': sorted(c for c in info['shared_calls'] if '._' not in c),
                               'counted': model != 'truck'}
        designs[design]['models'].append(model)
        models[model] = {'design': design, 'owner': info['owner'], 'shadowed': info['shadowed']}
    ranking = []
    for category in categories:
        evidence = {}
        for design, data in designs.items():
            hits = [s for s in data['sections'] if category['name'] in all_sections[s]['candidates']]
            if hits and data['counted']:
                evidence[design] = hits
        ranking.append({**category, 'status': 'Extend existing assembly' if category.get('shared') else 'No dedicated cross-family assembly identified',
                        'design_count': len(evidence), 'site_count': len({s for hits in evidence.values() for s in hits}),
                        'evidence': evidence})
    ranking.sort(key=lambda c: (-c['design_count'], -c['site_count'], c['name']))
    return {'revision': subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
            'models': models, 'designs': designs, 'sections': all_sections, 'ranking': ranking,
            'limitations': ['Conditional branches are a union per builder root, not per-variant runtime presence.',
                            'Comment/helper-name categories plus local construction are candidates, not verified identical meshes.',
                            'Unlabelled construction is retained; only descriptive helper names can classify it automatically.',
                            'Dynamic calls and inner-class construction require linked source inspection.',
                            'Convoy team union and shadowed dispatchers do not add to design counts.',
                            'Family-local helpers may already share a part within one family; ranking concerns cross-family extraction.']}

def source(section):
    return f"[{section['function']}:{section['line']}](../{section['file']}#L{section['line']})"

def write_markdown(result, directory):
    directory.mkdir(parents=True, exist_ok=True)
    designs = result['designs']; sections_by_id = result['sections']
    header = f"Source revision: `{result['revision'][:8]}`. {len(result['models'])} model keys, {len(designs)} construction-root groups.\n\n"
    limits = '\n'.join('- '+s for s in result['limitations'])+'\n\n'
    ranking = '# Most common remaining vehicle construction\n\n'+header
    ranking += 'Counts are **distinct builder groups with candidate evidence**, not instances or variant counts. Sites are distinct source sections. A high count means broad potential reuse; it does not prove that all shapes fit the same API.\n\n'+limits
    for status, title in [(False,'Candidates for dedicated assemblies'),(True,'Existing assemblies with remaining local construction')]:
        ranking += f'## {title}\n\n| Rank | Part | Builder groups | Source sites | Suggested reuse |\n|---|---|---:|---:|---|\n'
        rows = [r for r in result['ranking'] if bool(r.get('shared')) == status and r['design_count']]
        for i,r in enumerate(rows,1):
            ranking += f"| {i} | {r['name']} | {r['design_count']} | {r['site_count']} | {r['reuse']} |\n"
        ranking += '\n'
    ranking += '## Using the remaining candidates\n\nThe [assembly implementation review](vehicle-assembly-review.md) records migrations and supported shapes. Remaining matches are source leads: inspect the linked geometry before extending an API. Keep candidates below three compatible builder groups as inventory until another adopter is found. Mixed sections can still appear here after some of their parts migrate.\n\n'
    ranking += '## Evidence by candidate\n\n'
    for r in result['ranking']:
        if not r['design_count']: continue
        ranking += f"### {r['name']}\n\n"
        for design,hits in r['evidence'].items():
            names=', '.join(designs[design]['models'])
            ranking += f"- **{names}**: "+'; '.join(source(sections_by_id[h]) for h in hits)+'\n'
        ranking+='\n'
    (directory/'vehicle-parts-ranking.md').write_text(ranking)
    catalog = '# Vehicle construction part catalog\n\n'+header
    catalog += 'Every model key is mapped below. Designs sharing a builder are grouped to avoid counting weapon/cargo variants as new designs. Each entry lists shared assemblies, authored sections in its root builder, and local helper construction. This is a source inventory, not a certified runtime bill of materials.\n\n'+limits
    if result.get('roster'):
        catalog += '## Gameplay aliases\n\n| Gameplay key | Model key |\n|---|---|\n'
        for key,value in sorted(result['roster'].items()): catalog += f"| `{key}` | `{value['model']}` |\n"
        catalog += '\n'
    catalog += '## Models\n\n'
    for design,data in sorted(designs.items(),key=lambda kv:kv[1]['models'][0]):
        catalog += '### '+', '.join(data['models'])+'\n\n'
        catalog += '**Shared:** '+', '.join('`'+s+'`' for s in data['shared'])+'.\n\n'
        catalog += '**Authored sections:**\n\n'
        for ref in data['sections']:
            section=sections_by_id[ref]
            if section['function'] not in data['roots']:continue
            catalog += f"- {section['label']} — {source(section)}\n"
        helpers = [f for f in data['functions'] if f not in data['roots']]
        if helpers: catalog += '\n**Local helper construction:** '+', '.join('`'+f+'`' for f in helpers)+'.\n'
        catalog += '\n'
    catalog += '## Local helper section index\n\n'
    root_set = {f for d in designs.values() for f in d['roots']}
    helper_set = {f for d in designs.values() for f in d['functions']} - root_set
    for function in sorted(helper_set):
        catalog += f'### {function}\n\n'
        for section in sections_by_id.values():
            if section['function']==function: catalog += f"- {section['label']} — {source(section)}\n"
        catalog+='\n'
    (directory/'vehicle-parts-catalog.md').write_text(catalog)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--markdown',type=Path)
    parser.add_argument('--roster',type=Path)
    args=parser.parse_args();result=build()
    if args.roster:result['roster']=json.loads(args.roster.read_text())
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    if args.markdown:write_markdown(result,args.markdown)
    print(f"Cataloged {len(result['models'])} models, {len(result['designs'])} builder groups, {len(result['sections'])} source sections")
    for row in result['ranking'][:20]:print(row['design_count'],row['site_count'],row['name'])

if __name__=='__main__':main()
