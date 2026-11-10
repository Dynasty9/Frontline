# Foliage sources

CC0 1.0 assets from [Poly Haven](https://polyhaven.com/license):

- [Fir Tree 01](https://polyhaven.com/a/fir_tree_01), Rico Cilliers (modeling) and Rob Tuytel (photography).
- [Tree Small 02](https://polyhaven.com/a/tree_small_02), Rico Cilliers.

The branch cards are cropped colour/opacity scans. The distant fir atlas is
four variants of source trees A, B and C, normalized to the same height and
baked at five elevations from the horizon to directly overhead. Neutral lighting
and self-shadowing preserve the shape of each crown. Runtime blends the two
nearest elevations from isolated mipmapped array layers. MSAA edge colours are unpremultiplied
in linear space before import so alpha-tested canopies have no baked black fringe.
`tools/bake_foliage_assets.py --godot <Godot 4.7 console executable>` reproduces
both from SHA-256-checked sources in `sources.json`. The high-detail source
model (about 480 MB) is cached only under ignored `build/terrain/foliage-source`;
it is not shipped. Runtime uses three small mipmapped PNGs and no downloads.
