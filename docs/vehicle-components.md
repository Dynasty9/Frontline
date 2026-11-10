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

All 17 `VehicleMaterials` profiles define their finish, weathering and grain. Eight shared linear
normal maps are reproduced with `python tools/bake_vehicle_normals.py` from checksum-pinned bundled
sources. Keep their mipmaps enabled. Paint relief is intentionally weaker than fabric or grip;
adding noisy normal relief cannot replace an appropriate panel outline or a curved body normal.
See [matched body and material comparisons](vehicle-surface-review/README.md).
