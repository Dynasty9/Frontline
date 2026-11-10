# Vehicle surface library

The roster shares sixteen physical finishes in
[`VehicleMaterials.PROFILES`](../../../scripts/game/vehicle_materials.gd), backed
by eight 512 × 512 tileable data textures (six baked from CC0 sources). Every procedural vehicle part goes
through this library, including parked civilian cars and wrecks. Building and
terrain materials keep their existing presets.

| Finish | Use | Roughness | Metalness | Data map |
| --- | --- | ---: | ---: | --- |
| Armor | Military vehicle paint, camouflage | 0.73 | 0 | coating |
| Aircraft | Painted airframes, rotor coatings | 0.48 | 0 | coating |
| Automotive | Civilian paint, technical bodywork | 0.28 | 0 | coating |
| Marine | Painted hulls and superstructure | 0.42 | 0 | coating |
| Rubber | Tyres, inflatable tubes, hoses | 0.88 | 0 | rubber |
| Plastic | Dark trim, instrument housings | 0.63 | 0 | rubber |
| Canvas | Truck covers, seats, stowage | 0.96 | 0 | canvas |
| Steel | Exposed fittings and hubs | 0.36 | 0.90 | metal |
| Gunmetal | Weapons, dark metal hardware | 0.43 | 0.80 | metal |
| Track | Track shoes, with the existing link pattern | 0.69 | 0.65 | metal |
| Glass | Opaque reflective glazing | 0.075 | 0 | none |
| Nonslip | Boat and ship walking decks | 0.92 | 0 | nonslip |
| Tread | RHIB painted walking deck | 0.76 | 0 | tread |
| Oxidized | Trawler anchors and localized corrosion | 0.43–0.94 | 0–0.85 | oxidized |
| Wood | Crates and timber, with the existing grain | 0.81 | 0 | coating |
| Burnt | Charred wrecks | 0.95 | 0.05 | char |

These are base values; the shader adds small roughness variation and dust.
Paint stays nonmetallic. Rust coverage reduces exposed metal’s reflectivity. Automotive and marine
finishes have a clearcoat. Fighter canopy coatings retain their explicit tinted
metal response; ordinary glass is dielectric. Glazing over solid bodies stays opaque. `VehicleCab` supplies separate transparent panes and
100 m opaque fallbacks for the hollow HEMTT, Zamak and Tempest cabs and the Offroad,
hatchback and SUV glasshouses. These bypass the shared opaque-material bake; wrecks
omit the intact panes. `VehicleCloth` shares draped cargo shells and fitted restraints.
The shared wheel builder uses cached rounded tyre/rim meshes, road or offroad tread,
and smooth aircraft tyres. All rubber and rim detail remains on the wheel pivot.

## Using a surface

Model builders continue to pass a surface name and color to `k._add`, `_box`
or `_cyl`. `VehicleModels` resolves its family once and wraps the name with
`VehicleMaterials.key`. Explicit part types such as rubber, steel and canvas
take precedence over the family's default paint. Use `"nonslip"` explicitly
on a walking deck; do not infer a deck from its orientation.

Colors and camouflage palettes come from the existing `Mats` presets. Adjust
the shared physical finish in `PROFILES`; do not duplicate a material for each
model. A special coating can duplicate the resolved shared material, as the
fighter canopy does. All per-object values still go through `Mats.set_inst`.

The maps contain **linear data**, not albedo photographs:

- **R:** normalized height, converted to surface-gradient relief in the shader.
- **G:** roughness variation, centered around 0.5.
- **B:** corrosion coverage from the oxidized source’s inverse metalness.
- **A:** centered linear luminance variation, modulated by each finish’s tone strength.

The original nonslip/char maps remain RGB; their blue/implicit alpha channels
are unused. Paint uses source grain only, not the metalness of its donor material.

They are sampled with triplanar projection in model coordinates. `surface_scale`
is repeats per model metre, independent of the camouflage pattern scale. This
works on the generated lofts, which have no conventional UV unwrap, and softens
projection transitions on curved surfaces. Texture, camouflage seed, broad
variation and lower-body dust remain attached when a vehicle moves or changes
altitude. Moving assemblies retain their own local coordinates.

Keep the `.png.import` files: lossless compression preserves the packed data,
mipmaps and anisotropic filtering keep distant detail stable, and automatic 3D
compression is disabled. The eight maps occupy about 4.6 MiB on disk and are loaded
once; there are no per-vehicle texture copies or runtime downloads. Existing
merged meshes and the one-surface distance LOD remain in use.

## Regeneration and review

Run [`tools/generate_vehicle_surfaces.py`](../../../tools/generate_vehicle_surfaces.py)
to regenerate all eight maps. It retains original procedural nonslip and char
data, then calls [`tools/bake_vehicle_sources.py`](../../../tools/bake_vehicle_sources.py)
to bake six CC0 sources. The baker verifies pinned source hashes, downsamples
height/roughness, converts color from sRGB to linear luminance, and records output
hashes in `baked-sources.json`. Source normals are retained for authoring but not
sampled at runtime: height drives the triplanar surface gradient. See [LICENSE.md](LICENSE.md).

```sh
python3 tools/generate_vehicle_surfaces.py # numpy, scipy, Pillow
godot --headless --path . --import
node --test tests/vehicle-materials.test.mjs tests/vehicle-lod.test.mjs tests/vehicle-motion.test.mjs

# Run with a display (or Xvfb), not --headless:
godot --path . --rendering-method gl_compatibility tools/showcase/vehicle-surfaces.tscn -- --surface-out=/tmp/roster
godot --path . --rendering-method gl_compatibility tools/showcase/vehicle-surfaces.tscn -- --surface-out=/tmp/swatches --surface-swatches
```

The studio captures every definition and builder key, five parked-car variants
and three representative wrecks at seed 3. `--surface-team=1` checks the second
palette; `--surface-single --surface-kinds=tank,hatchback,rhib` captures close-ups.
Add `--surface-offset` to move the studio 117 m east, 35 m up and 81 m north:
the images should match apart from rasterization rounding. Also check
`--rendering-method forward_plus` and verify the log actually says Forward+.
The headless material fixture audits all model surfaces, mipmaps, wreck finishes,
and both palettes. Screenshots remain the check for visual quality.

## CC0 sources in use

The [third-party source library](../sources/README.md) contains six ambientCG
CC0 sets. Coating, rubber, canvas and brushed-metal detail is shared across the
roster. Diamond plate is assigned to the RHIB walking deck, and oxidized steel
to the gun trawler's anchors and existing localized rust patches. Other boat decks
keep abrasive nonslip paint. The original 1K files remain authoring inputs;
only the compact baked maps are loaded by the game.
