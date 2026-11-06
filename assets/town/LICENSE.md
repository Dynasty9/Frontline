# Town surface scans

CC0 1.0 assets from [Poly Haven](https://polyhaven.com/license):

- [Road Damaged Clean](https://polyhaven.com/a/road_damaged_clean), Dimitrios Savva; 2.2 m scan.
- [Aerial Asphalt 01](https://polyhaven.com/a/aerial_asphalt_01), Rob Tuytel; 30 m scan.
- [Concrete Pavement](https://polyhaven.com/a/concrete_pavement), Charlotte Baglioni; 1.8 m scan.
- [Leafy Grass](https://polyhaven.com/a/leafy_grass), Charlotte Baglioni; 2 m scan.

- [Roof Tiles](https://polyhaven.com/a/roof_tiles), Stephan Seeliger; 2 m scan.
- [Weathered Planks](https://polyhaven.com/a/weathered_planks); 2 m scan.
- [Concrete Floor 01](https://polyhaven.com/a/concrete_floor_01), Rob Tuytel; 2 m scan.
- [Asphalt 02](https://polyhaven.com/a/asphalt_02), Rob Tuytel; 3 m repair surface.

- [Brick Wall 001](https://polyhaven.com/a/brick_wall_001), Rob Tuytel and Dimitrios Savva.
- [Plastered Wall](https://polyhaven.com/a/plastered_wall), Amal Kumar.
- [Tree Bark 03](https://polyhaven.com/a/tree_bark_03), Rob Tuytel.
- [Gravelly Sand](https://polyhaven.com/a/gravelly_sand), Dario Barresi.

`tools/bake_town_assets.py` verifies original 2K JPEG source checksums from
`sources.json`, caches downloads under `build/terrain/town-source`, and packs
bundled runtime textures. Asphalt retains 2K; other surfaces use 1K. Repair asphalt uses colour only.
`*_color.jpg` is sRGB colour. `*_surface.png` stores linear OpenGL normals in RGB
and roughness in alpha. Alpha is data; imports preserve it and generate mipmaps.
The game never downloads these assets. Shader tinting varies grass moisture and
slab weathering; source photographs contain no new generated painted detail.

Street surfaces combine the aerial scan at 30 m for broad cracks and weathering
with Road Damaged Clean at 2.2 m for fine aggregate and normal/roughness detail.
The fine scan is desaturated toward charcoal in the shader; repaired patches
retain the same aggregate scale. The normal maps follow the actual road slope.

The baker also measures each packed photograph's average linear albedo in
`material_means.tres`. Building materials use those values to preserve their
preset and per-object colours while retaining photographed variation.
