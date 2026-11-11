# Building vehicles from shared components

See the [construction inventory](../tools/vehicles/README.md) to find existing shared methods before adding a helper. The [30-technique implementation review](vehicle-construction-review.md) lists adopters, supported shapes and deliberately specialized construction. The [roadmap](vehicle-construction-roadmap.md) records the original priorities.

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

Use `--surface-accessories` in the vehicle showcase for separate antenna, mirror-face, mirror-back and barrel inspection views. Fixed fittings fold into their existing parent/material bake. Each live antenna keeps one whip pivot and one material batch; wreck antennas remain static.

`VehicleModels.update_antennas(travel, dt, active)` takes world-space travel velocity. One exact damped spring per vehicle combines drag and clamped acceleration, then transforms the resulting lean into each antenna parent’s coordinates, including traversing turrets. The view callback derives travel from displayed movement on both host and client. Motion resets outside 100 m, when hidden, after long frame gaps or after implausible position corrections. There are no rigid bodies, bones, mesh rebuilds or per-whip spring solvers. The base remains fixed while the spring/rod assembly tilts up to about 16 degrees.

`--surface-antenna-motion` captures a combined rigid/animated comparison driven by controlled forward, lateral and reverse velocity inputs, followed by settling. This is an inspection rig, not recorded driving footage.

### Round headlights: Hunter construction pass

Start each construction pass with one vehicle and one visible feature. Extract a
shared builder only after identifying that feature on at least two other vehicles;
then migrate every matching construction, retaining family-specific mounts and
silhouettes. Capture broadly for inspection, but commit a compact comparison sheet
or short video under the presentation skill's media budget.

The Hunter's round headlight insert now uses
`VehicleFittings.headlamp(k, parent, center, radius, direction)`. `center` is the
old lens face and `direction` points outward (default -Z). The helper supplies a
rubber seating ring, metal rim, shallow reflector, bulb shield and moulded lens
ribs. A cached unit reflector scales to each lamp; opaque geometry approximates
sealed-beam optics without transparent sorting or a light/shadow pass. It is an
unlit appearance detail, not functional headlight illumination. All pieces fold
into the existing hull bake; wrecks omit the intact reflector and lens ribs.

Coverage: Hunter, Prowler, Marshall, Rhino, Slammer, Scorcher, Sandstorm, Panther,
Bobcat, Cheetah, Stomper, Abrams, T-55, Humvee, BTR-80, Bradley, M35, Zamak and Qilin,
including variants sharing those builders. Rectangular lamps and infrared/search
lights retain their own construction; the T-55's missing IR lens stays missing.
Family builders retain lamp placement, housing dimensions, guards and indicators.

### Ten-feature construction pass

The headlights above count as feature 1. Each subsequent row started with one
vehicle, verified at least two other users, and then migrated matching geometry.
These are static appearance changes: no new gameplay state, lights, physics or
per-frame updates. Construction mounts fold into their supplied hull/turret parent.

| # | Feature / starting vehicle | Two other confirmed users | Shared construction and rollout |
| --- | --- | --- | --- |
| 1 | Round headlights / Hunter | Zamak, Qilin | `headlamp`; coverage above, plus MB4WD round lamps and matching civilian fog lamps found during the final roster audit |
| 2 | Jerrycans / Hunter | Prowler, Marshall | `jerrycan`: pressed ribs, seam, three open handles, filler cap. All five ground-family jerrycan helpers delegate here, including civilian repair pickups. |
| 3 | Sealed ammo cans / Prowler | Abrams, Humvee | `ammo_can`: gasket, lid, latches, open handle and wall ribs. NATO/core helpers and loose cans in offroad/MB4WD gun vehicles; wooden crates and gun-specific feed boxes keep their construction. |
| 4 | Tow shackles / Hunter | Prowler, Marshall | `tow_shackle`: open forged bow, pin and attached mounting lug. Core/NATO/CSAT helpers plus the independent Strider, Mora, Kuma, Gorgon and Zamak fittings. |
| 5 | Smoke tubes / Marshall | Rhino, Slammer | `smoke_tube`: reuses the hollow barrel mesh and adds a mounting collar. All four ground-family smoke banks retain their counts, spacing, pitch and yaw. |
| 6 | Periscope heads / Abrams | T-55, Bradley | `periscope`: fitted glass, seal, protective lip and fasteners. Core/CSAT helpers plus the matching NATO and independent driver/crew heads. Panoramic sight towers and flush vision ports retain their shapes. |
| 7 | Closed round hatches / Ifrit | Marid, Varsuk | `hatch`: lid seal, seat, hinge knuckles/pin and open handle. Core/CSAT helpers and matching NATO/independent closed lids. Cupola pedestals, open lids and rectangular hatches remain authored by their families. |
| 8 | Tail-light clusters / Hunter | Prowler, Marshall | `tail_cluster` / `signal_lens`: sealed red/amber lenses with moulded ribs across core/NATO/CSAT/independent clusters. Civilian lights share the optical finish while retaining their distinct silhouettes. |
| 9 | Lifting eyes / Abrams | T-55, Bradley | `lifting_eye`: actual open ring and welded foot. All core lifting eyes, Mora's deck eyes and the SDV's flat corner rings. |
| 10 | Rectangular headlights / Ifrit | Marid, Tempest | `rectangular_headlamp`: rubber seat, fluted optics and bulb shield. CSAT/independent clusters, HEMTT, Hilux and matching forward-facing civilian rectangular lamps. Family housings, guards, indicators and nonrectangular lamps remain distinct. |

Helpers are in `scripts/game/vehicle_fittings.gd`. Position contracts matter:
`jerrycan` and `ammo_can` take body centres; independent/civilian jerrycan adapters
convert their old bottom origin by 0.23 m. `hatch` takes the **lid centre**;
core/CSAT adapters convert their old deck origin. `lifting_eye` takes the contact
surface and supports upright or flat rings. Periscope and rectangular-headlamp
local -Z faces out; signal lenses use +Z and accept a facing sign. Smoke tubes
keep the original cylinder centre, local-Y axis and length. All rotations turn
whole assemblies, including lids, handles and caps.

The opaque optical surfaces approximate lamps and periscopes without transparency
sorting. Wreck builds substitute burnt material and omit intact optical inserts.
The component fixture checks can attachments under compound rotation, batching,
finite bounds, construction budgets and wreck materials; existing vehicle tests
cover animation pivots, sockets, model bounds and all-family material consistency.

Use `--surface-construction --surface-single --surface-kinds=KIND` with the existing
vehicle showcase for component inspection. Kinds: `jerrycan`, `ammo_can`,
`tow_shackle`, `smoke_tubes`, `periscope`, `hatch`, `tail_lights`, `lifting_eye`,
`rectangular_lights`. The [combined comparison sheets](../changelog/unreleased/vehicle-shared-equipment/)
show genuine before/after component rigs, not gameplay footage. The presentation
catalog records revisions, cameras and commands. Full-roster and individual raw
captures are local review artifacts, not checked-in media.

### Fitted construction and equipment

`VehicleSurface` maps a two-dimensional domain to a vehicle's authored surface.
Use `plane(origin, across, up)` for metre-scaled sheets, `quad(corners, inside)`
for normalized cabin faces, or supply a sampler and outward direction for curved
skins. Domain coordinates belong to that adapter: never assume normalized UVs
are metres. Offsets and thickness are in model metres. Polygon outlines must be
simple, ordered and nondegenerate; curved surfaces need explicit subdivisions.

`VehicleBody.fitted` shares the outline with `boundary` seams and corner screws.
Boundary seals form one low-section mesh, with no cylinder caps or hidden rings.
`VehicleCab.framed_face` omits rectangular opening cells from the shell and adds
reveals. It is not arbitrary CSG. `VehicleGlazing.polygon` accepts an optional
authored mesh for faceted helicopter panes, preserving creases while sharing the
seal. Never turn on clear glazing without a real opening and an interior.

`VehicleDoors.closed` takes an outline, hinge anchors and handle anchor on the
same surface. `rectangle` is the convenience adapter. `light`, `utility` and
`armored` styles control sheet and hardware dimensions; exposed face screws are
reserved for armored leaves. Hinges and pull handles also work independently
on storage lids. Opening doors, sliders and vehicle-specific pivots stay local.

`VehicleEquipment` builds closed storage bins, skirt segments, winches, optical
housings and dished vessels. Dimensions are independent, rather than separate
small/large/XL implementations. Storage hardware is clamped to the available lid;
vessels accept independent width, height, length and strap stations; sensors
support box and ball styles. Use the existing `VehicleFittings.jerrycan`,
`VehicleCloth` and material library instead of adding duplicate container or
fabric builders. Top-lid storage is not an ammunition-can or basket replacement.

`VehicleRunningGear` owns ladder frames and solid axles, without registering
wheels. `VehicleWheelArches` owns the civilian cut-body and flare kernel; its
liners remain outside the supplied tyre radius. `VehicleCargo` supplies pallets
and load-bound straps. `VehicleFrames` adds boarding treads, ladders, explicit
stanchion runs and static sagging cables. These are construction, not suspension
or rope simulation. Existing independent suspension and optimized ship rails
remain distinct implementations.

`VehicleProfiles` caches lofts/revolutions by their actual shape parameters.
`VehicleAirfoils` shares section interpolation and metre-scaled control gaps.
`VehicleAircraft` supplies ducts, landing struts, pylons and seven/nineteen-tube
rocket pods. Families keep station data, planforms, nozzle petals and payload
positions. `VehiclePropellers` shares blades, spinners and blur materials, while
callers retain existing `k.wheels`/rotor registration and visibility parents.
`VehicleMarkings` projects authored polygons onto surfaces and omits intact
markings on wrecks by default. `VehicleMarine.mooring` supports cleats and bitts.

All opaque assemblies use the existing bake and LOD path. Helpers that create a
temporary construction pivot fold it back into the supplied parent. They must
not register wheels, weapons or rotors unless that is the explicit API contract.
Use the surface, index, material, component, LOD and motion tests together when
changing these foundations; the index test requires three independent builder
roots for each of the 30 registered techniques (conditional variants still need
source inspection).

### Equipment detail pass

The [40-improvement review](vehicle-detail-40-review.md) lists refinements to 20
existing assemblies. `VehicleFittings.jerrycan` adds an optional body `size`
argument after the legacy `width`: `Vector3(0.1, 0.25, 0.18)` builds a smaller
container using the same cap, carrying bars, shoulders and ribs. Omit `size` to
keep existing call sites unchanged. The size describes the body; cap and handle
project above it. The complete assembly follows the supplied rotation.

Chassis frames now use open C sections within the existing rail bounds. Pallets
have lower runners and gaps for fork entry. When adding a pallet to a load,
raise both the load and its restraint origin by the pallet height. Preserve
separate equipment such as loading cranes and vehicle-specific silencers.
