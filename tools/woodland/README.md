# Woodland asset bake

Run from the repository root with Python 3.11+, Pillow, NumPy, Blender 4.5 and
Godot 4.7:

```
python tools/woodland/bake.py --blender <blender.exe> --godot <godot_console.exe>
```

The baker downloads the CC0 sources listed in
`assets/foliage/woodland/sources.json`, verifies their SHA-256 hashes, and keeps
the originals under ignored `build/woodland/source/`. Credits and source pages
are in `assets/foliage/LICENSE.md`. `--textures-only` skips mesh conversion.

Runtime color/alpha maps are at most 2048 square. The 1024-square surface maps
pack normal X/Y in R/G, ambient occlusion in B and roughness in A. Keep their
Godot normal-map import mode disabled: normal-map compression would discard
the other channels. Both texture types use mipmaps.

Blender preserves separate wood and foliage surfaces. Broadleaf and mature fir
crowns sample the scan's branch distribution into 700 and 1600 textured cards,
respectively. Small props use bounded decimation; `meshes.py` holds the budgets
and selected variants. The Godot converter aligns tree components to the trunk
base and generates mesh LODs before saving compressed resources. Its small
project avoids loading game autoloads during an offline asset conversion.

The scan geometry is cosmetic. Woodland scattering uses its own seeded random
generator, follows the ground shader, and does not change cover, collision or
replicated map data. Review placement with `tests/grass_stream_test.tscn` and
the `woodland` stage in `tests/fixtures/environment-views.gd` in both Forward+
and Compatibility after changing a bake.

## Review the woods

The `woodland` capture set uses a fixed attack-scenario stand by default.
`--woodland-generated` finds a tree stand in the generated battlefield. Both
write camera transforms and draw counters to a JSON sidecar. Keep the same
fixture, seed, renderer and settings on the parent revision for comparisons.

```
godot --path . --audio-driver Dummy --fixed-fps 30 --resolution 1600x900 --script tests/fixtures/environment-views.gd -- --scenario=attack --seed=3 --offscreen --nohud --perf=0 --preset=high --mood=day --capture-set=woodland --capture-views=floor,stand,eye --capture-prefix=build/woodland/review
```

Omit `--capture-views` to include specimen close-ups. Add
`--capture-clip=detail-4` to record 180 butterfly frames at 30 fps. For a
generated stand, replace `--scenario=attack` with `--aivai` and add
`--woodland-generated`. Repeat with `--rendering-method gl_compatibility`
before the engine argument separator, and with Low quality and rain.

Imported LODs survive on instanced ground props. Mature trees use the existing
spatial batching path, which currently rebuilds their mesh surfaces without
those LODs. Do not infer a frame-rate improvement from the asset budgets or
from the capture sidecar: benchmark matched scenes on an otherwise idle GPU.
