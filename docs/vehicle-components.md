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
