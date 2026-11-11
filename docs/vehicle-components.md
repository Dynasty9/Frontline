# Building vehicles from shared components

Family builders own the silhouette, dimensions, wheel positions, payload and weapon sockets. Reuse the parts below for ordinary wheels, belts, structural members and windows. Existing family helpers delegate to them, so variants inherit improvements together.

| Component | Use | Keep specific to the vehicle |
| --- | --- | --- |
| `VehicleWheels.pneumatic` | Rounded tyre, recessed rim, hub bolts; `road`, `offroad`, `aircraft` profiles | Radius, width, rim paint and axle position |
| `VehicleWheels.spare` | Same assembly folded into the chassis, never registered for wheel animation | Mount and orientation |
| `VehicleWheels.road` | Twin tracked road wheels, recessed discs, bolts; optional ribs and steel idler mode | Radius, width, spoke count; drive sprockets remain family parts |
| `VehicleTracks.shoes` | Evenly spaced shoes, hinge pins, optional rubber pads and guide teeth | Outline, width, pitch and steel/padded construction |
| `VehicleFrames.tube`, `.beam`, `.path` | Struts, frame rails, roll cages, bars and rounded tube joints | Endpoint layout, section dimensions and taper |
| `VehicleGlazing.rectangle`, `.quad` | Rectangular or fitted quadrilateral pane with rubber seals | Actual opening outline and whether an interior exists |
| `VehicleRotors.main`, `.tail`, `.blade` | Airfoil sections, shaped tips, matte blade coating and hub hardware | Radius, chord, blade count, phase, sweep/paddle style and aircraft-specific caps |
| `VehicleCab` / `VehicleCloth` | Open cabs, furniture, near/far glass and draped cargo covers | Family proportions and load |

All positions are local to the supplied parent. Forward is -Z; wheel axles are X. Track outlines are **(Z, Y)**, and `wheel_envelope` takes circles as **(Z, Y, radius)**. A shoe outline normally describes its centre line; use `inset=thickness/2` when an existing outline describes the outside edge. Pitch controls link length in metres. ED-1 uses a 0.035 m pitch; full-size armour uses 0.20 m. Pads and hinge pins scale down with thickness. Tracks remain static geometry, as before this change.

```gdscript
# Animated wheel: pivot is registered in k.wheels.
VehicleWheels.pneumatic(k, k.root, Vector3(1.1, 0.5, -1.8), 0.5, 0.3,
	"paint", rim_color, "offroad")
# Upright rear spare: rotation uses CylinderMesh's Y-axis convention.
VehicleWheels.spare(k, k.root, Vector3(0, 1.2, 2.8), 0.5, 0.3,
	Vector3(PI / 2, 0, 0), "paint", rim_color)
VehicleFrames.tube(k, k.root, lower_corner, upper_corner, 0.04, "steel")
```

Use `register=false` for static aircraft wheels attached to an existing gear parent. Ordinary wheels and tracked road wheels each create one pivot; static spares fold their geometry into their parent. Opaque detail enters the existing material bake and distance LOD. Do not add separate MeshInstance nodes for each bolt or track link.

Glazing defaults to opaque. Set `clear=true` only after modelling a real opening and interior; otherwise transparency exposes the solid hull behind it. Clear panes use `VehicleCab.mesh_glass`, with a matching opaque fallback at 100 m and no intact pane on wrecks. `.quad` accepts four ordered face corners, a point inside the hull (for the outward normal), and a normalized `Rect2` selecting the pane region. Its mesh-cache key must identify the shape, including variant and side when they differ.

Surface finishes still come from `VehicleMaterials`: the existing eight maps and CC0 credits are unchanged. These improvements are geometry and reuse, not another texture download. Unique aircraft canopies, inflatable tubes, agricultural tread and optimised open ship rail meshes remain specialised.

Validate with `node --test tests/vehicle-components.test.mjs tests/vehicle-materials.test.mjs tests/vehicle-lod.test.mjs tests/vehicle-motion.test.mjs`, then render `tools/showcase/vehicle-surfaces.tscn`. Add `--surface-rear` for rear-quarter views; use `--surface-single --surface-kinds=... --surface-ground` for closer inspection.

Helicopter builders call `VehicleRotors.main` through the existing `VmHeli._rotor` adapter. `tip=0` is tapered square, `tip=1` swept and `tip=2` a broad paddle tip. The assembly shares cached airfoil meshes by dimensions and tip type. Blade roots and tips follow the same section geometry; erosion protection follows its leading edge. `.tail` reorients the same airfoil along an X-axis rotor. `VehicleMaterials` supplies the matte `rotor` finish without adding texture downloads.

Hub fittings stay on the rotor parent, while explicit blades stay under the existing blade visibility node. Additional rotors retain `Blades` and `Blur` children. This preserves current speed-driven blur behaviour; detailed blade shapes are principally visible at rest or low speed. Enclosed fans and drone propellers are deliberately separate. Use `--surface-rotor --surface-size=3 --surface-single` to inspect a main hub with the shared capture stage.

### Body skins and service panels

`VehicleBody.skin(mesh, key, crease)` caches smoothed normals for curved skins without changing
positions. Use unique mesh keys; sharp creases retain face normals. `seam` follows supplied points,
`fastener` takes an outward normal, and `panel` builds a gasket, pressed sheet and flush screws,
optionally with louvres. Panels occupy local XY with +Z outward and fold into the parent's bake.
The helicopter hull wrapper uses skins on sections with at least ten points; low-sided stealth
sections stay faceted. HEMTT, Zamak and Tempest builders place shared panels against their own cabs.

All 18 `VehicleMaterials` profiles define their finish, weathering and grain. Eight shared linear
normal maps are reproduced with `python tools/bake_vehicle_normals.py` from checksum-pinned bundled
sources. Keep their mipmaps enabled. Paint relief is intentionally weaker than fabric or grip;
adding noisy normal relief cannot replace an appropriate panel outline or a curved body normal.
See [matched body and material comparisons](vehicle-surface-review/README.md).

### Material-aware construction

`VehicleBody.panel(k, parent, center, size, rotation, material, color, louvres)` now selects
construction from `VehicleMaterials.profile`:

| Material | Automatic construction |
|---|---|
| Paint / metal | Gasket, folded edges, pressed centre, fasteners; optional louvres |
| Canvas / fabric / webbing | Draped cloth, sewn hems and filtered stitches |
| Rubber / plastic | Chamfered moulded sheet, without metal screws |
| Wood | Solid sheet with the wood finish, without sheet-metal details |
| Glass | Fitted opaque pane and rubber seals; use VehicleGlazing directly for open clear cabs |

`VehicleCloth.canopy(k, parent, profile, bows, color)` fits cloth between a left-to-right
cross-section and longitudinal support stations. Its front is closed; the family builder owns
the rear opening, rolled flap and boarding fittings. HEMTT, Zamak and Tempest troop bodies use it.
`VehicleCloth.load_cover` also provides sewn perimeter hems on tied cargo covers.

`VehicleBody.paint_mesh` caches per-piece face coordinates without changing positions or normals.
Military paint uses these coordinates for edge rubs; curved triangles receive neutral coordinates,
so they do not acquire an artificial box outline. `Mats` preserves these UVs through merging.
This is an approximation of part-boundary wear, not a curvature or ambient-occlusion bake.
UVs are reserved for this purpose on vehicle paint; photographic relief remains triplanar.
Use `--surface-panels` in the vehicle showcase to inspect all construction types together.

### Service fittings and padded stowage

`VehicleFittings` adds opaque parts to the existing material bake:

- `grille(k, parent, center, size, rotation, material, color, count, vertical)` uses local XY, with +Z outward. Allow at least 5 cm behind its centre for the recessed core; mounting it inside a solid body hides the recess. Slat count and direction preserve each vehicle's design.
- `exhaust(k, parent, base, direction, length, radius)` aims along any authored axis. It has an uncapped outlet, inward-facing soot sleeve, rolled rim and lower shield/clamps. Pipe meshes are cached by size.
- `mudflap(k, parent, center, size, rotation)` adds curved rubber, reinforcing ribs and a clamped upper edge. +Z faces outward.
- `VehicleCloth.bag` (or `k._bag`) keeps the box builder's size/position/material arguments, adding a softened shell, sewn welt, fitted strap and buckle. Use it explicitly for padded stowage; seats, tarps and canvas panels have their own builders.

These helpers fold temporary construction mounts into the parent's bake and retain turret/wheel animation ownership. HEMTT, Tempest, Zamak and Hunter use the grille helper; HEMTT and Tempest use the exhaust helper. HEMTT, Tempest, Hunter, Ifrit and Strider use mudflaps. Existing bags across the NATO, CSAT and independent builders share the padded construction. Inspect the four parts with `--surface-fittings` in the showcase.

### Antennas, mirrors and gun tubes

- `VehicleFittings.antenna(k, parent, base, height)` builds a bolted foot, rubber boot, cached helical spring and tapered whip. Height is the rod height above the original 12 cm base; the tip retains that overall height, with a slight rearward bend. Use this for upright radio whips, not aircraft blades or ship radar arrays.
- `VehicleFittings.mirror(k, parent, center, size, yaw, anchors)` builds a moulded shell, rear rib, rubber perimeter and reflective face. Local +Z faces the rearward view. Parent-local anchors connect to swivel joints on the back of the rotated housing. The dedicated `mirror` finish uses smooth metallic reflection; ordinary window glass stays dielectric. Reflections come from the renderer's environment, without an extra planar camera.
- `VehicleFittings.barrel(k, parent, breech, muzzle, radius, material, color, sleeved)` aims a hollow tapered tube between authored endpoints. The inward-facing bore, annular crown and optional three sleeve sections share cached geometry. Family builders retain their extractors, muzzle sensors, brakes, recoil/elevation pivots and gameplay `gun_tip` markers. Pass `false` for an older unsleeved gun such as the T-55.

The core, NATO, CSAT and independent whip helpers delegate to the same antenna builder. Mirrors cover HEMTT, Tempest, Zamak, Hunter, Ifrit, Strider, Qilin, Humvee, technicals and the core truck. Gun tubes cover Abrams, T-55, Slammer, Rhino, Kuma, Varsuk, Angara, Scorcher and Sochor, including variants that share those builders. Unique autocannons, machine guns, aircraft aerials and radar structures retain their authored construction.

Use `--surface-accessories` in the vehicle showcase for separate antenna, mirror-face, mirror-back and barrel inspection views. All opaque fittings fold into their existing parent/material bake.
