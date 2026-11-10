# Texture provenance

`coating.png`, `rubber.png`, `canvas.png`, `metal.png`, `tread.png` and
`oxidized.png` are modified derivatives of ambientCG assets by Lennart Demes,
distributed under **CC0 1.0 Universal**. See [source licenses](../sources/LICENSE.md).

| Runtime map | CC0 source |
| --- | --- |
| coating | Metal027 (grain only; paint remains dielectric) |
| rubber | Rubber004 |
| canvas | Fabric036 |
| metal | Metal009 |
| tread | DiamondPlate009 |
| oxidized | Metal053B |

`tools/bake_vehicle_sources.py` resizes and repacks the channels into linear
512 × 512 RGBA data. `baked-sources.json` records output checksums; the
[source manifest](../sources/sources.json) records input checksums and URLs.
Source normals are not copied into these packed maps.

`nonslip.png` and `char.png` are original algorithmically generated material
data, created by `tools/generate_vehicle_surfaces.py` with seed 7319. These two
outputs and the tooling are distributed under the repository's [MIT license](../../../LICENSE).

`*_normal.png` are 512px linear OpenGL tangent normal maps. The six photographic
normals use the corresponding ambientCG CC0 NormalGL source listed above;
`nonslip_normal.png` and `char_normal.png` are periodic derivatives of the original
MIT height maps. `tools/bake_vehicle_normals.py` verifies source checksums and
records output hashes in `baked-normals.json`. Runtime imports retain mipmaps.
