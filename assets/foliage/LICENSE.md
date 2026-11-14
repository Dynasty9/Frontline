# Foliage sources

CC0 1.0 assets from [Poly Haven](https://polyhaven.com/license):

- [Fir Tree 01](https://polyhaven.com/a/fir_tree_01), Rico Cilliers (modeling) and Rob Tuytel (photography).
- [Tree Small 02](https://polyhaven.com/a/tree_small_02), Rico Cilliers.
- [Fern 02](https://polyhaven.com/a/fern_02), Rico Cilliers (modeling) and Rob Tuytel (scanning).
- [Dead Tree Trunk 02](https://polyhaven.com/a/dead_tree_trunk_02), Jenelle van Heerden (photography) and Rico Cilliers (processing).
- [Tree Stump 01](https://polyhaven.com/a/tree_stump_01), Rob Tuytel.
- [Nettle Plant](https://polyhaven.com/a/nettle_plant), Rob Tuytel (photography) and Rico Cilliers (modeling).
- [Rock Moss Set 01](https://polyhaven.com/a/rock_moss_set_01), Kless Gyzen.
- [Grass Medium 01](https://polyhaven.com/a/grass_medium_01), Rob Tuytel (photography) and Rico Cilliers (modeling).
- [Pine Sapling Small](https://polyhaven.com/a/pine_sapling_small), Rob Tuytel (photography) and Rico Cilliers (modeling).
- [Shrub 02](https://polyhaven.com/a/shrub_02), Rico Cilliers.

The branch cards are cropped colour/opacity scans. The distant fir atlas is
four variants of source trees A, B and C, normalized to the same height and
baked at five elevations from the horizon to directly overhead. Neutral lighting
and self-shadowing preserve the shape of each crown. Runtime blends the two
nearest elevations from isolated mipmapped array layers. MSAA edge colours are unpremultiplied
in linear space before import so alpha-tested canopies have no baked black fringe.
`tools/bake_foliage_assets.py --godot <Godot 4.7 console executable>` reproduces
both from SHA-256-checked sources in `sources.json`. The high-detail source
model (about 480 MB) is cached only under ignored `build/terrain/foliage-source`;
it is not shipped. The original distant-tree system uses three small mipmapped
PNGs and no downloads.

The `woodland/` folder contains reduced scan meshes, 2K colour/opacity maps and
1K surface maps (normal X/Y, occlusion, roughness in RGBA). Trees retain scanned
wood and use branch cards sampled within the scanned canopy. Sources, including
their SHA-256 hashes, are recorded in `woodland/sources.json`;
`tools/woodland/bake.py` reproduces these assets with Blender and Godot.
The high-resolution originals stay in ignored `build/woodland/source` and are
not distributed with the game.

The butterfly wing uses [Nymphalidae aglais urticae](https://commons.wikimedia.org/wiki/File:Nymphalidae_aglais_urticae.jpg),
photographed by QuodScripsiScripsi and released under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). The photograph is
unmodified; the small tortoiseshell's wing geometry samples its markings.
