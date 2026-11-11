# Construction inventory

The [per-vehicle catalog](../../docs/vehicle-parts-catalog.md) lists authored
construction sections, shared APIs, local helpers and gameplay aliases. The
[ranked extraction list](../../docs/vehicle-parts-ranking.md) separates new
assembly candidates from remaining migrations to existing shared builders.

Regenerate both from the current source (export the roster using the command
below first):

```sh
python3 tools/vehicles/parts-catalog.py --roster /tmp/vehicle-roster.json --output /tmp/vehicle-parts.json --markdown docs
python3 tests/vehicle-parts-catalog.test.py
```

`part-categories.json` defines semantic candidate patterns, exclusions and existing
shared APIs. Ranking counts construction-root groups, not variants or individual
meshes. A matching comment/helper name must have local geometry in its source
section; existing matching shared calls exclude that section conservatively.
Unlabelled code remains in the catalog. Mixed sections and conditional branches
still require source review before extracting a feature. This is a reproducible
source audit, not an exact runtime bill of materials or an exhaustive semantic
classification of every mesh.

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
the linked construction before migrating it. A model that a later family also
dispatches is listed as shadowed, never counted as another adopter; the index
test expects none. Regenerate the output after changes; keep
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

`detail-improvements.json` records the next 40 improvements to 20 existing
assemblies, separately from the original 30-technique registry. See the
[detail review](../../docs/vehicle-detail-40-review.md) for the changes, adopters,
exceptions and validation. Extend the matching shared method instead of creating
a parallel builder for a different size.
