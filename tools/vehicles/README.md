# Construction inventory

Run from the repository root:

```sh
python3 tools/vehicles/construction-index.py --output /tmp/vehicle-construction.json
python3 tools/vehicles/construction-index.py --model hunter --output /tmp/hunter.json
```

The index maps every family model key to its first active dispatcher, root
construction methods, reachable shared methods, source locations and candidate
feature evidence. It includes the five ambient civilian bodies and the convoy's
three team-dependent body choices. Follow `Defs.VEHICLES[kind].model` when starting
from a gameplay roster alias instead of a model key.

This is conservative source analysis: conditional features are a union, dynamic
calls and inner-class methods need inspection, and keyword hits are candidates.
It does not claim that every variant visibly has every reachable feature. Inspect
the linked construction before migrating it. Shadowed plane builders are listed
but never used as additional adopters. Regenerate the output after changes; keep
large generated JSON files and captures outside Git.

Use the [roadmap](../../docs/vehicle-construction-roadmap.md) for priorities and
[component contracts](../../docs/vehicle-components.md) before introducing a new
helper. Prefer extending a matching existing helper; expose dimensions and style
options where construction is genuinely shared. Different silhouettes are not
necessarily different techniques, and similarly named equipment is not always
the same construction.

`features.json` records the 30 construction techniques and their compatibility
boundaries. To include the actual gameplay roster aliases:

```sh
godot --headless --path . tools/vehicles/roster-index.tscn -- --vehicle-index-out=/tmp/vehicle-roster.json
python3 tools/vehicles/construction-index.py --roster /tmp/vehicle-roster.json --output /tmp/vehicle-construction.json
```

For comparable construction cost and geometry counts, run the same engine on
both revisions, without simultaneous rendering or tests:

```sh
godot --headless --path . tools/vehicles/construction-metrics.tscn -- --vehicle-metrics-out=/tmp/vehicle-metrics.json
```

The report includes all mesh surfaces, including near/far LOD alternatives; it is
not a claim that all reported surfaces draw simultaneously. Build time includes
cache warm-up in the sorted model order. Inspect gameplay frame cost separately.
