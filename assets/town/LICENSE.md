# Town surface scans

CC0 1.0 assets from [Poly Haven](https://polyhaven.com/license):

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
