# Town surface scans

CC0 1.0 assets from [Poly Haven](https://polyhaven.com/license):

- [Aerial Asphalt 01](https://polyhaven.com/a/aerial_asphalt_01), Rob Tuytel; 30 m scan.
- [Concrete Pavement](https://polyhaven.com/a/concrete_pavement), Charlotte Baglioni; 1.8 m scan.
- [Leafy Grass](https://polyhaven.com/a/leafy_grass), Charlotte Baglioni; 2 m scan.

`tools/bake_town_assets.py` verifies original 2K JPEG source checksums from
`sources.json`, caches downloads under `build/terrain/town-source`, and packs
bundled runtime textures. Asphalt retains 2K; paving and grass use 1K.
`*_color.jpg` is sRGB colour. `*_surface.png` stores linear OpenGL normals in RGB
and roughness in alpha. Alpha is data; imports preserve it and generate mipmaps.
The game never downloads these assets. Shader tinting varies grass moisture and
slab weathering; source photographs contain no new generated painted detail.
