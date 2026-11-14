# Building vehicles from shared components

See the [construction inventory](../tools/vehicles/README.md) to find existing shared methods before adding a helper. The [30-technique implementation review](vehicle-construction-review.md) lists adopters, supported shapes and deliberately specialized construction. The [roadmap](vehicle-construction-roadmap.md) records the original priorities.

Family builders own the silhouette, dimensions, wheel positions, payload and weapon sockets. Reuse the parts below for ordinary wheels, belts, structural members and windows. Existing family helpers delegate to them, so variants inherit improvements together.

| Component | Use | Keep specific to the vehicle |
| --- | --- | --- |
| `VehicleWheels.pneumatic` | Rounded tyre, recessed rim, hub bolts; `road`, `offroad`, `aircraft` profiles | Radius, width, rim paint and axle position |
| `VehicleWheels.spare` | Same assembly folded into the chassis, never registered for wheel animation | Mount and orientation |
| `VehicleWheels.road` | Twin tracked road wheels, recessed discs, bolts; optional ribs and steel idler mode | Radius, width, spoke count; drive sprockets use `VehicleWheels.sprocket` |
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

### Equipment assembly extraction

The [assembly implementation review](vehicle-assembly-review.md) documents the 22 new construction groups, adopters and shape boundaries. Use `VehicleMounts` for equipment mounts/cages, and the extended wheel, aircraft, cab, marine, cargo, door and fitting classes for their domain-specific geometry. Keep sockets and animation ownership in the caller. The registry in `tools/vehicles/assembly-extractions.json` enforces three independent builder groups per API.

### Twenty shared components

The third extraction pass started from three source surveys (armour, trucks and civilians, aircraft and
boats) that looked for parts each family still assembled itself from primitives. Each part below now has one builder, and
every matching site across the roster calls it, so a later improvement to the builder reaches every
vehicle at once. `tools/vehicles/assembly-extractions.json` registers them; the index test requires at
least three independent builder groups for each (the counts below are from the construction index, not
variants).

| Part | API | Builder groups / models | What the builder adds over the old copies |
| --- | --- | ---: | --- |
| Turret race ring | `VehicleMounts.turret_ring` | 30 / 50 | Splash-guard lip, bolt circle on the race's outer face |
| Sight head | `VehicleMounts.sight` | 29 / 45 | Bevelled head, bezelled windows on rubber, armoured visor, cover seam, panoramic stem with flange and rotary joint; one wreck rule for the glass |
| Commander's cupola | `VehicleMounts.cupola` | 10 / 12 | Bolted roof flange, armoured vision-block housings with rain hoods |
| Reactive armour brick | `VehicleMounts.era_brick` | 8 / 11 | Bevelled brick, cover plate, two bolts |
| Rectangular hatch lid | `VehicleFittings.panel_hatch` | 16 / 26 | Coaming, rubber seal, pressed stiffeners, two hinges, grab handle |
| Bore evacuator | `VehicleFittings.evacuator` | 9 / 12 | Tapered end cones, joint band, filler plug |
| Dome light | `VehicleFittings.dome_light` | 19 / 25 | Metal base reaching the old sphere's foot, rubber seat, glossy lens |
| Navigation sidelight | `VehicleFittings.nav_light` | 30 / 36 | Red to port and green to starboard by rule, marker housing, visor |
| Coaxial gun port | `VehicleWeapons.coax` | 13 / 17 | Port sleeve, slotted flash hider, dark bore |
| Automatic cannon | `VehicleWeapons.autocannon` | 16 / 24 | Recoil-sleeve collar, clamp bands, ported muzzle brake, bore |
| Heavy machine gun | `VehicleWeapons.hmg` | 22 / 40 | Shared receiver, feed cover, rear sight, perforated jacket, carrying handle, spade grips, sealed ammo can and belt |
| Medium machine gun | `VehicleWeapons.mmg` | 8 / 16 | Shared receiver, butt and pistol grip, gas tube, carrying handle, ammo can |
| Grenade machine gun | `VehicleWeapons.gmg` | 14 / 23 | Shared receiver, spade grips, perforated jacket, drum or box feed with chute |
| Rotary barrel cluster | `VehicleWeapons.rotary` | 11 / 19 | Spindle, barrel carrier, clamps and bores along any axis |
| Missile launch tube | `VehicleWeapons.launch_tube` | 4 / 11 | End collars, frangible front cover, rear blast seal, clamp bands, umbilical box |
| Rotor mast | `VehicleRotors.mast` | 12 / 16 | Bearing housing, drive splines, bolted collars |
| Turbine exhaust | `VehicleAircraft.turbine_exhaust` | 10 / 14 | Open shell, soot liner, tail cone, heat-tinted lip, outlet aimed along the pipe |
| Fender sheet | `VehicleBody.fender` | 9 / 30 | Rolled edge bead, bolts, inboard stays, optional valance |
| Saddle fuel tank | `VehicleRunningGear.fuel_tank` | 6 / 23 | Dished ends and straps (round) or bevelled box, filler cap, hangers, drain |
| Rolled tarp | `VehicleCloth.roll` | 7 / 18 | Softened ends with wound layers, webbing straps and buckles |

Contracts, so a call drops in where the old primitives were:

- Every builder takes the old geometry's centre, size, radii or endpoints. Position conventions follow the
  primitives they replace: `turret_ring`, `cupola` and `mast` take the old cylinder's centre and radii;
  `sight` and `panel_hatch` the old box; `era_brick` the old brick with local +Z outward; `dome_light`
  the old sphere, with `up` for lamps under a belly or on a staff.
- Guns run from a point at the back (receiver centre, breech, barrel carrier) to `muzzle`, along any
  axis, and return `muzzle`. `muzzle` is where the gun's geometry ends; muzzle markers (`k._tip`),
  turret pivots and recoil parents stay with the family, so weapon sockets do not move (the socket
  fixture checks all 104 armed models). `size` scales cross-sections, never the length.
- `sight` windows are `Rect2`s on the head's -Z face: the position is the window's centre relative to
  the head's centre (in the head's own axes when it is tilted). `stem = (top radius, bottom radius,
  drop below the head's centre)` makes a panoramic head.
- `cupola` blocks sit at `first_angle + i * step` radians from forward (positive toward +X).
- `hmg` and `mmg` take `can` (-1 left, +1 right, 0 none); a remote station whose own ammunition box
  sits outside the yoke passes 0. `gmg` takes the feed side, drum or box, and `feed_offset`.
- `fender` builds one flat sheet; a raked lip is a second call with the old rotation.
- Wrecks: builders that carry glass or lenses omit the intact glass and take the burnt material.

Deliberately left authored: lofted or cylindrical sight heads (Abrams CITV and doghouse, Kuma PERI),
aircraft sensor drums, DShK-pattern guns with cooling fins, box launchers with tube mouths, packed or
sideways launch tubes, lofted exhaust suppressors, faceted armoured wheel arches, fender-mounted fuel
drums and aircraft drop tanks, and civilian beacons and light bars (cylinders and boxes, not domes).
Inspect the parts with `--surface-shared-parts` in the vehicle showcase. Validate with
`tests/vehicle-shared-parts.test.mjs` (fold, muzzle, envelope and wreck checks for each builder) and
the socket fixture, alongside the vehicle tests listed above.

Across 135 models (`tools/vehicles/construction-metrics.tscn`, before and after on the same engine),
nodes, meshes and wheel/rotor registrations are unchanged; mesh surfaces rise 2.8% and vertices 5.6%
(27.1 M to 28.6 M), mostly from guns with sealed ammunition cans and reactive armour on the heaviest
tanks. Reactive bricks keep a plain cover plate because they repeat by the hundred. These are geometry
measurements of near and far meshes together, not frame-rate claims.

### Second pass: twenty improvements by impact

The second pass ranked parts by how much a player sees them (top-down decks and track sides from the RTS
camera, truck beds, aircraft stores) times how many vehicles carry them, then built or extended a shared
builder for each and moved every compatible site onto it. Counts are builder groups and model keys from the
construction index, before and after the pass.

| # | Improvement | API | Groups | Models |
| ---: | --- | --- | ---: | ---: |
| 1 | Engine-deck, radiator and exhaust grilles | `VehicleFittings.grille` / `vent` (migration) | 8 → 39 | 25 → 77 |
| 2 | Track skirts and raked bow panels | `VehicleEquipment.skirt`, new `skirt_bow` | 10 → 16, 11 | 11 → 18, 12 |
| 3 | Track return rollers | `VehicleWheels.roller` | 11 | 15 |
| 4 | Truck cargo beds | `VehicleCargo.flatbed` | 5 | 21 |
| 5 | Box missile launchers | `VehicleWeapons.missile_box` / `missile_face` | 6 / 8 | 9 / 17 |
| 6 | Air-launched missiles | `VehicleAircraft.missile` | 11 | 11 |
| 7 | Smoke discharger banks | `VehicleFittings.smoke_bank` | 24 | 35 |
| 8 | Rotor hub caps | `VehicleRotors.hub_cap` | 9 | 11 |
| 9 | Helicopter stub-wing pylons | `VehicleAircraft.hardpoint` (material, rise, braces) | 10 → 17 | 10 → 19 |
| 10 | Closed bins and toolboxes | `VehicleEquipment.storage` (migration) | 15 → 26 | 23 → 50 |
| 11 | Door and ramp leaves | `VehicleDoors.leaf` (migration) | 19 → 28 | 38 → 55 |
| 12 | Truck box bodies, doors, shutters, ladders | `VehicleCargo.shelter` / `body_door` / `roller_shutter` / `rung_ladder` | 4 | 20 |
| 13 | Lamp units | `VehicleFittings.lamp_unit` | 37 | 73 |
| 14 | Aircraft engine intake faces | `VehicleAircraft.intake_face` | 9 | 9 |
| 15 | Pedestal gun mounts | `VehicleMounts.pedestal` (+ `gun_shield`, `ring_mount`) | 5 | 15 |
| 16 | Roll cages and bull bars | `VehicleFrames.roll_bar` / `bull_bar` | 4 / 5 | 11 / 10 |
| 17 | Wheel-well tubs | `VehicleWheelArches.tub` | 8 | 18 |
| 18 | Aircraft store pods | `VehicleAircraft.pod` | 4 | 4 |
| 19 | Aircraft and boat whips | `VehicleFittings.antenna` ("whip" style) | 35 → 50 | 68 → 88 |
| 20 | Sensor balls on necks | `VehicleEquipment.sensor` (neck, windows) | 7 → 12 | 14 → 20 |

Contracts follow the first pass: each builder takes the old geometry's own centre, size, bounds or
endpoints, folds into its parent and registers nothing; muzzle markers, turret, rotor and wheel pivots stay
with the families (the socket fixture checks every armed model). Extended APIs keep their old output for old
arguments, and the hull fixture compares them part by part with copies of the previous functions.
Notes for callers:

- **Grilles on a deck** sit their centre 3 cm above the deck: the recessed core is 2.5 cm deep, and a flush
  core flickers against the deck. Sloped faces need the face's outward normal (two families gained small
  helpers, `_zy_grille` and `_glacis_grille`, that lay a grille along a slope).
- **`smoke_bank`** takes the family's own tube transforms, so the four discharger layouts are unchanged.
- **`antenna`** with `style = "whip"` builds a boss or white insulator foot, ferrule, tapered rod and ball tip
  with no sway registration; ground whips keep the boot, spring and motion.
- **`roller_shutter`** without a colour keeps its material's own finish: pass the body's camouflage material
  for a painted shutter. **`shelter`**'s bottom rail stands 2.8 cm proud, past a door leaf's 2 cm, so doors
  hung to the floor sit behind it like a sill.
- **`VehicleDoors.hinge`** straps reach about two radii either side of the hinge line; hinge a ramp on a face
  it lies against, not across a free edge.
- **`lamp_unit`** steps each extra insert slightly further out for overlapping clusters, so light bars of
  side-by-side lenses stay authored.

Fixes found along the way:
- The A-10's intakes were closed by a solid cowling disc ahead of the fan; it is now a ring, so the fan shows.
- Old missile "nose cones" were mounted wide end forward.
- The T-55, Bradley and BTR-80 laid glacis parts (the T-55 splash board, the BTR windows) along an inward
  normal, inside the hull.
- The Stalker's glacis grille sat 4 cm inside the plate.

Validate with `tests/vehicle-parts-hull.test.mjs`, `vehicle-parts-trucks.test.mjs` and
`vehicle-parts-aircraft.test.mjs` (fold, envelope, wreck-glass and compatibility checks for every builder;
`FL_DEBUG_PART_BOUNDS=1` prints bounds and vertex counts) with the socket fixture and the vehicle tests above.

Across 135 models, nodes, meshes and wheel/rotor registrations are unchanged; mesh surfaces rise 0.6% and
vertices 7.6% (28.6 M to 30.8 M), most on the Tigris and Kamysh launchers and the small Fenghuang UAV (about
+30% each). Beyond 100 m the model draws one merged, welded mesh whose detail levels the engine generates
(`Mats.add_distance_lod`), so the added parts cost far less there than these unwelded near-mesh counts. These
are geometry measurements, not frame-rate claims.

### Third pass: running gear, crew fittings, cranes and aircraft details

The third pass took the parts that three or more families still assemble from primitives, ranked as before by how
much the RTS camera sees them and how many vehicles carry them. Counts are builder groups and model keys
from the construction index after the pass (an arrow marks an existing builder's growth).

| # | Improvement | API | Groups | Models |
| ---: | --- | --- | ---: | ---: |
| 1 | Track guards and mudguards | `VehicleBody.track_guard` | 6 | 7 |
| 2 | Wishbone suspension | `VehicleRunningGear.wishbone` | 6 | 11 |
| 3 | Tow cables with eyes and clips | `VehicleFittings.tow_cable` | 8 | 10 |
| 4 | Exhaust runs and silencers | `VehicleFittings.exhaust_run` / `silencer` | 10 / 12 | 22 / 30 |
| 5 | Air cleaners | `VehicleFittings.air_cleaner` | 3 | 14 |
| 6 | Searchlights | `VehicleFittings.searchlight` | 10 | 14 |
| 7 | Emergency and work light bars | `VehicleFittings.light_bar` | 4 | 11 |
| 8 | Crew benches | `VehicleCab.bench` | 8 | 23 |
| 9 | Mirrors (shell material and colour) | `VehicleFittings.mirror` (migration) | 10 → 17 | 34 → 49 |
| 10 | Seats | `VehicleCab.seat` (migration) | 10 → 13 | 35 → 39 |
| 11 | Number plates | `VehicleMarkings.plate` | 10 | 27 |
| 12 | Red crosses | `VehicleMarkings.cross` | 4 | 21 |
| 13 | Stencil lettering | `VehicleMarkings.digit_strokes` / `stroke_rects` | 17 / 12 | 34 / 29 |
| 14 | Door levers | `VehicleDoors.lever` | 14 | 22 |
| 15 | Sliding-door rails | `VehicleDoors.slide_rail` | 5 | 7 |
| 16 | Bow eyes and boat fenders | `VehicleMarine.bow_eye` / `fender` | 4 / 3 | 5 / 3 |
| 17 | Muzzle brakes | `VehicleWeapons.muzzle_brake` | 4 | 5 |
| 18 | Muzzle reference sensors | `VehicleWeapons.muzzle_sensor` | 6 | 9 |
| 19 | Cranes | `VehicleMounts.crane` | 5 | 23 |
| 20 | Gun travel locks | `VehicleMounts.travel_lock` | 3 | 3 |
| 21 | Machine-gun pintles | `VehicleMounts.pintle` | 5 | 8 |
| 22 | Trim vanes | `VehicleMounts.trim_vane` | 3 | 4 |
| 23 | Hydraulic rams | `VehicleFrames.ram` | 8 | 26 |
| 24 | Sensor masts | `VehicleMounts.mast_segment` (migration) | 5 → 7 | 11 → 14 |
| 25 | Roof racks | `VehicleCargo.roof_rack` | 3 | 9 |
| 26 | Crate stacks | `VehicleCargo.crate_stack` | 5 | 23 |
| 27 | Tanker walkways, manholes and rails | `VehicleEquipment.tanker_top` | 3 | 18 |
| 28 | Pump cabinets | `VehicleEquipment.pump_cabinet` | 3 | 18 |
| 29 | Gas bottles in racks | `VehicleEquipment.gas_bottle` | 3 | 16 |
| 30 | Helicopter main gear | `VehicleAircraft.trailing_gear` | 5 | 6 |
| 31 | Tailwheels | `VehicleAircraft.tailwheel` | 5 | 6 |
| 32 | Countermeasure dispensers | `VehicleAircraft.dispenser` | 4 | 5 |
| 33 | Formation lights | `VehicleAircraft.formation_light` | 6 | 7 |
| 34 | Refuelling receptacles | `VehicleAircraft.refuel_receptacle` | 4 | 4 |
| 35 | Bombs | `VehicleAircraft.bomb` | 8 | 8 |
| 36 | Chin turrets | `VehicleAircraft.chin_turret` | 4 | 4 |
| 37 | Pitot probes | `VehicleAircraft.pitot` (migration) | 12 → 15 | 15 → 19 |
| 38 | Spare track links, piano hinges | `VehicleTracks.spare_links`, `VehicleDoors.piano_hinge` | 1, 1 | 1, 2 |

The last row's builders have one family each so far and stay out of the assembly registry until two more
use them. Contracts are the first pass's: each builder takes the old geometry's centre, size or endpoints,
folds into its parent and registers nothing, wheels, rotors, turrets and muzzle markers stay with the
families, and wrecks lose their glass and lenses. Notes for callers:

- **`muzzle_brake`** runs from the sleeve's back to the old brake's front along any axis and returns the
  front; stop the family's `VehicleFittings.barrel` inside the sleeve. Its front face carries the barrel's
  crown ring round the bore, so a closed brake still reads as an open muzzle.
- **`trailing_gear`** and **`tailwheel`** draw the legs and beams to the caller's own `k._wheel` pivot (call
  the wheel first and pass its pivot as `hub` where there is a hub cover).
- **`crane`** draws ring, post, boom, lift ram, sheave and hook; families keep their own extra booms,
  outriggers and rests. **`pintle`** takes the receiver centre passed to `hmg` or `mmg`.
- **`searchlight`** turns its yoke with the lamp; a lead runs from the lamp's gland into the pedestal or
  post. Small boat and nose lamps pass no mount.
- **`bench`** lays wood as slats on bearers and anything else as a piped cushion; `wall` hinges it on the
  body behind it, as troop seats on a dropside or bulwark.
- **`plate`** embosses registration text derived from the plate's position unless given one, so two
  vehicles of a kind carry the same registration.
- Civilian car aerials use the static `"whip"` antenna; the sprung, swaying whip with its boot and spring is
  military radio fit and adds a node of its own.

Fixes found along the way:
- The Merkava loader's machine gun floated above the roof; it stands on a pintle.
- Every shared seat's back leaned toward its sitter; it leans away, headrest and all.
- Lamp lenses no longer survive on wrecked dome lights, and sealed-beam headlamps cost half the ribs.

Validate with `tests/vehicle-parts-gear.test.mjs`, `vehicle-parts-cabin.test.mjs`, `vehicle-parts-trim.test.mjs`,
`vehicle-parts-arms.test.mjs` and `vehicle-parts-airframe.test.mjs` (fold, envelope and wreck checks for
every builder; `FL_DEBUG_PART_BOUNDS=1` prints bounds and vertex counts) with the socket fixture and the
vehicle tests above.

Across 135 models, nodes, meshes and wheel/rotor registrations are unchanged; mesh surfaces rise 1.2% and
near-mesh vertices 5.3% (30.7 M to 32.3 M). Small boats rise most (the SDV about 55%, the SURC speedboats
about a third) because a pair of searchlights or eight cushioned benches weighs a lot against a small hull.
These are geometry measurements, not frame-rate claims.

### Fourth pass: sweeping the rest onto shared builders

The fourth pass made two builders and then swept every family file for parts still assembled from primitives
although a shared builder already makes them, reading each catalog candidate (most are comment matches, lofted
hulls or authored designs) and moving the sites whose old geometry fits a builder's contract. Counts are builder
groups and model keys from the construction index, before and after.

| Builder | Groups | Models |
| --- | ---: | ---: |
| `VehicleEquipment.drum` (new: 200-litre drums, standing or lying, hoops, bungs, straps) | 3 | 14 |
| `VehicleWheels.carrier` (new: hub, swing-out, cradle and strap carriers for `spare`) | 11 | 40 |
| `VehicleGlazing.rectangle` (sealed vision blocks and door windows) | 11 → 27 | 29 → 53 |
| `VehicleDoors.leaf` / `closed` / `slide_rail` | 30 → 37 / 9 → 10 / 5 → 6 | 58 → 70 / 29 → 30 / 7 → 10 |
| `VehicleMounts.sight`, `radar_array`, `pintle`, `pedestal`, `radome`, `bumper` | 29 → 33, 5 → 7, 5 → 7, 5 → 6, 4 → 5, 11 → 13 | 45 → 55, 9 → 12, 8 → 10, 15 → 17, 5 → 6, 35 → 45 |
| `VehicleRunningGear.fuel_tank`, `VehicleEquipment.vessel`, `VehicleFittings.filler` | 6 → 10, 6 → 10, 12 → 18 | 23 → 27, 23 → 27, 32 → 40 |
| `VehicleWeapons.autocannon`, `launch_tube`, `gmg` | 16 → 20, 4 → 5, 14 → 15 | 24 → 28, 11 → 12, 23 → 25 |
| `VehicleFittings.panel_hatch`, `VehicleEquipment.storage` | 16 → 19, 26 → 29 | 26 → 29, 50 → 53 |
| `VehicleAircraft.pitot`, `gear_leg`, `turbine_exhaust` | 15 → 18, 7 → 10, 10 → 11 | 19 → 22, 9 → 12, 14 → 15 |
| `VehicleFittings.mirror`, `light_bar`, `parked_wiper`, `VehicleMarkings.plate` | 17 → 18, 4 → 5, 5 → 6, 10 → 11 | 49 → 54, 11 → 16, 12 → 15, 27 → 32 |

Smaller moves: hatches, turret rings, crate stacks, bags, axles, canvas tilts, roll bars, mooring bitts, grilles,
lamp units and markers. Notes for callers, from the sites that didn't fit:

- **`grille`** and **`vent`** recess their core 2.5 cm behind the centre, which assumes an opening in the face.
  On a solid face stand the centre 3 cm proud, as the deck grilles do, or the core vanishes into the plate.
- **`marker`** turns its lens in quarter turns from +Z: 2 faces forward, as on cab roofs.
- **`exhaust`** registers its mouth for the engine's heat haze and smoke; pipes that never breathed stay authored.
- **`panel_hatch`** and **`fuel_tank`** take no rotation: build them in a pivot tilted to the face and fold it.
- **`VehicleDoors.leaf`** puts its sealed face toward local +X; a mirrored pair needs a mirrored frame
  (`VmFighter._gear_door` fits a leaf through a gear door's four corners).
- **`hitch`** builds jaws and a pin only; tow balls stay authored. **`tow_shackle`** is always gunmetal.
- **`storage`** and **`panel_hatch`** cost about 6k vertices each once merged, mostly hinges and fasteners;
  small lockers on ships and hull vents on the SDV stayed authored for that reason.

Fixes found along the way:
- The HEMTT repair truck's tool lockers sat inside its tandem wheels; they hang between the axles now.
- Spare wheels floated: the HEMTT's 25 cm over its rails, the Qilin's half above its deck, and the Prowler's
  cross bar ran through the tyre. Each now hangs on a carrier.
- The Xian's troop-door seams and windows stood 3 to 24 cm off its flank, and the Caesar's gull-wing door seams
  about 20 cm at their tops; they lie on the skin.
- The Mohawk's rescue-hoist cable was drawn as a pitot boom; it hangs a cable and hook block.
- The Sochor's turret vents stood 6 cm off the leaning side, and the SURC's roof grab rail overhung its posts.

Validate with `tests/vehicle-parts-stowage.test.mjs` (drums and carriers at every site, live and wrecked), the
socket fixture and the vehicle tests above.

Across 135 models, nodes, meshes and wheel/rotor registrations are unchanged; near-mesh vertices rise 2.3%
(32.3 M to 33.1 M). The Xian (fitted doors, +21%), the patrol ship and gun trawler (lockers, hatches and
pintles, +15%) and the SURC and RHIB (+12%) rise most.

### Fifth pass: lighter shared hardware

The passes above made the parts more detailed; the fifth made the shared builders cheaper without changing what
they draw. `tools/vehicles/builder-profile.tscn` charges every part's vertices to the outermost shared builder
that made it, across all 135 models, so the heaviest builders could be found and trimmed once for every vehicle.
Near-mesh vertices fell from 23.8 M to 12.9 M (-46%); counting the distance meshes, construction-metrics' total
fell from 33.1 M to 18.5 M. Nodes, meshes, surfaces and wheel/rotor registrations are unchanged, and matched wide
shots of every family differ on at most 0.03% of pixels.

| Builder | Before | After |
| --- | ---: | ---: |
| `VehicleWheels.pneumatic` (every tyre) | 7.23 M | 3.34 M |
| `VehicleWheels.road` | 1.35 M | 0.70 M |
| `VehicleFittings.tow_shackle` | 1.03 M | 0.23 M |
| `VehicleFittings.smoke_bank` | 0.72 M | 0.24 M |
| `VehicleWheels.spare` | 0.66 M | 0.29 M |
| `VehicleEquipment.storage` | 0.59 M | 0.23 M |
| `VehicleFittings.lamp_unit` | 0.58 M | 0.34 M |
| `VehicleFittings.antenna` | 0.46 M | 0.21 M |
| `VehicleFittings.jerrycan`, `grille`, `exhaust`, `hatch` | 1.08 M | 0.43 M |
| `VehicleBody.fastener` (charged to every builder that bolts) | ≈ 1.97 M | ≈ 0.63 M |

What changed, in every builder at once:

- **One band of sides.** `Res.cyl`'s middle ring splits a straight side in two and adds triangles, not shape.
  `VehicleBody.drum` is the shared ringless cylinder, cached by size with only the caps that show; `k._cyl`,
  `VehicleFrames.tube`/`rod_mesh`, `VehicleWheels.drum` and `VehicleEquipment._cylinder` all draw through it, at
  `Res.cyl`'s exact sizes.
- **Joints only where a bend opens.** `VehicleFrames.path` put a ball at every joint, even on a smooth 13-point
  arc. Gentle bends now run the pieces into each other; balls stay only at sharp corners (`VehicleBody.bead` does
  the same for seams and hoses).
- **Nothing that can't be seen.** Caps inside bosses and collars, tread faces under the shoulder, the inner 60°
  of a tyre's carcass inside the rim, screws hidden in a pull's standoff, bore discs behind a rocket pod's face.
- **Segments to size.** A 2 cm rod has 6 sides, a bolt head 6, a tyre lip 6 round a 32-sided rim; rings
  (`VehicleFittings._ring`) pick 12, 16 or 20 by size.
- **Tread as one mesh.** A tyre's 72 or 96 bevelled lug boxes are one cached mesh per tyre size, plain blocks at
  the old positions.

New parameters (old output by default): `panel_hatch(rotation)`, `tow_shackle(mat, col)`,
`VehicleFrames.railing(lean)`, `tube`/`path(caps)`, `VehicleRunningGear.fuel_tank(rotation)`,
`VehicleMounts.hitch(style = "ball")`, `VehicleEquipment.sensor(lens)`, `VehicleCloth.canopy(closed_back)`,
`VehicleCloth.panel(hems)`, `VehicleMounts.mast_segment(rake)`, `VehicleWeapons.launch_tube(forward, up)`,
`VehicleDoors.leaf(facing)` and `VehicleDoors.hinge(mirror)`.

One visible fix: the searchlight's solid collar hid its lens, so only rib tips showed; it is an open band now.

Profile a change with
`godot --headless --path . tools/vehicles/builder-profile.tscn -- --builder-profile-out=<file>` before and after.

### Sixth pass: the sites the new parameters unlock

The fifth pass's new parameters let three agents replace workarounds and move the sites that had stayed authored
for want of them. Nodes, meshes and wheel/rotor registrations are unchanged; vertices rise 0.4%.

- **Sloped hatches** (`panel_hatch(rotation)`): the Abrams driver's hatch (its tilted pivot is gone), the
  Merkava and Namer glacis access panels (`VmNato._zy_hatch`), and the RHIB's and patrol ship's deck hatches,
  pitched to their decks instead of burying one edge.
- **Tilted tanks** (`fuel_tank(rotation)`): the T-55's dented fender tanks lose their folded pivots.
- **Tow balls** (`hitch(style = "ball")`) on the Offroad and the technical; **painted tow hooks**
  (`tow_shackle(mat, col)`) on the MB 4WD and the civilian truck.
- **Closed tilt** (`canopy(closed_back)`): the M35's back flap is part of its canopy.
- **Raked mast** (`mast_segment(rake)`) on the Stomper; **sensor lens** (`sensor(lens)`) on the Vorona sight;
  **angled launch tubes** (`launch_tube(forward)`) for the Angara's Afghanit dischargers.
- **Door leaves facing out** (`leaf(facing)`): the left-hand doors of the BTR, the Sochor's crew doors and the
  A-10, Wipeout, AC-130 and Blackfish gear doors showed their inner face outboard; the Scorcher, trawler and
  `VmFighter._gear_door` workarounds became the parameter with the same output.
- **Mirrored hinges** (`hinge(mirror)`): the MB 4WD's and the van's left-hand hinges were the right-hand ones
  turned round, straps on the cowl. `VehicleDoors.closed` (and `rectangle`) now mirror each hinge so its outer
  straps reach toward the handle, onto the leaf, for every fitted door at once.

Fixes found in review: `VehicleAircraft.trailing_gear(hull)` runs the pivot and strut fittings in to the
fuselage skin (`|x|` at each, probed on the built model), so the Ghost Hawk's, Black Hawk's, Apache's and
Kajman's gear no longer ends in mid-air; `VehicleWeapons._bore` is the barrel builder's near-black, not a
dark paint the sun lights grey, so every muzzle reads as a hole; VmCsat's `_arch(inner)` folds the three
arch plates into one mitred band from inside the hull, with a dark well face; the Zamak repair crane's
column stands 22 cm taller so the folded boom clears the roof; the Xian's rack tubes are four
`launch_tube`s packed under the rack plate on strap cradles.

Left for later: `railing` always lays a foot plate (the motorboat helm and RHIB seat rails end inside cushions)
and puts a post under every point (the motorboat bow rail has posts at only four of seven); round hatches
(`VehicleFittings.hatch`) take no rotation.

### Seventh pass: detail against AAA references

Four agents, one per family, rendered their vehicles against what Company of Heroes 3, WARNO, Steel Division 2
and Arma 3 show, ranked the gaps by visible impact times the number of vehicles sharing the fix, and closed
the biggest. Nodes, meshes and wheel/rotor registrations are unchanged; vertices rise 1.8% across the roster
(no model more than 15%).

- **Edges that catch light.** VmCsat's `_bevelled` (section hulls), `_chamfer_loft` and `_inset` (lofts) and
  VmIndep's `_capped` (ring solids) chamfer roof edges by 3-8 cm on about thirty hulls and turrets. VmNato
  lays weld beads (`_weld`, `_loop`, on `VehicleBody.bead`) round the Abrams, Merkava, Namer, Marshall, Rhino,
  Scorcher, BTR and Bradley; `_on_loft` / `_loft_seam` put seams exactly on a loft face folded across its
  diagonal (the Merkava wedge flank folds 13.6°).
- **Bolt-on armour** (`VehicleMounts.applique`): a chamfered slab with a bolt grid and optional lifting lugs,
  folded into its parent. Two rows of five per side on the Namer family, the Merkava and Marshall flank
  modules, the Bradley's tiles.
- **Tactical numbers.** CSAT and Indep turrets and hull sides carry three-figure numbers drawn from the
  vehicle's seed (its entity id in play, so peers agree and neighbours differ) in the hull bars;
  NATO and core vehicles carry fixed numbers in the stroke font. Wrecks drop them.
- **Aircraft paint** (`VehicleAircraft.insignia`, `lettering`, `lines`, `soot`, `paint`, `face`): stars,
  roundels and low-visibility stars and bars on wings, fins and booms; serials, bort numbers and civil
  registrations; panel joints; exhaust soot that darkens the skin's own camouflage. Layers stack 5 mm apart
  so none fights another on a curved skin. CSAT's jets wear `camo_tank_rebel`.
- **Glass and car bodies.** `VehicleCab._materials` tints clear glass darker and glossier, `VmCiv._glasshouse`
  floors the cabin, `VehicleCab.interior(seat_col, seat_mat)` gives cars cloth seats; `VehicleGlazing._crowned`
  leans every opaque pane's normals outward so the sky slides across it. `VehicleWheelArches._xprism` /
  `_xbody(roll)` smooth car bodies' normals across chamfers and gentle bends (flat faces stay flat);
  `VmBoat._faired` does the same for planing hulls and ship bands.
- **Crew kit and breakup**: tow cables along T-100 and T-14 guards, rolled tarps and nets on decks, Kuma roof
  seams and lifting eyes, exhaust soot on the Namer, Merkava and Bradley, bonnet shut lines and black trim on
  cars.

The shared builders the family agents didn't own went to the next passes: the eighth took most, the
ninth the chamfered end ring in `VehicleModels.loft` / `solid`.

### Eighth pass: mud, stencils, wheels, tracks and rotors

Four more agents, this time by shared system rather than by family (markings, materials, running gear,
aircraft), against the same references. Nodes and meshes are unchanged except the Black Wasp's (+1 each:
the distance mesh it was missing); vertices fall 0.3% across the roster, the CSAT tracked vehicles rising
up to 14% for their new links and the cars falling 16-24% for lighter wheels.

- **Mud and dust** (the surface shader's vehicle branch, `VehicleMaterials.DIRT`): wet mud low on the hull
  with a splash-broken edge that fills recesses first, paler dust above it settling on upward faces, both
  turning the surface matte. Strength and height by family: armour 0.95 to 0.85 m, cars road dust to 0.5 m,
  boats a level waterline stain, aircraft none. It is measured in the model's own frame from each baked
  part's pivot height, which `Mats.Bake.commit` writes into the vertex colours' alpha (`_lift`): instance
  uniforms for it cost the browser renderer a material copy per part. On wheels it is measured outward from
  the axle, so it doesn't turn with the wheel. Distant meshes carry each part's average dirt colour.
- **Glass**: vehicle glass is a blue-grey tint with a stronger coating (`surface_specular` 0.8) and
  `surface_glaze`, which leans its reflection toward the sky, so it reads as glass from above.
- **`Mats.tint_for`** lifts only vehicle colours darker than its floor in every channel, as a whole, so
  very dark tints keep their hue; every other call returns what it did. **`Mats._collect`** builds a
  surface with a foreign shader into the distance mesh as dark glass instead of rejecting its whole mesh.
- **Stencils** (`VehicleMarkings`): a "tactical" lettering style of heavy bars with stencil bridges, the
  letters to spell unit codes, `tactical_number(seed, places)`, `bumper_code(seed, units)` (US battalion and
  company codes), `side_number` (the face-corner builder both CSAT and Indep used), `face_text` (fitted to a
  width) and `bumper`. Paints are army stencil colours (`STENCIL_WHITE`, `STENCIL_AAF`, `STENCIL_SAND`), each
  bar a shade off the next like a hand-painted stencil. Every NATO, core, CSAT and Indep number comes from
  the seed; the Abrams, Bradley, Humvee, Hunter and HEMTT carry bumper codes.
- **Car wheels** (`VehicleWheels._car_wheel`, chosen by `pneumatic` for road tyres on steel or gunmetal rims
  0.30-0.42 m): a low-profile tyre on a lathed rim, five-spoke alloys on dark rims, six-spoke on bright
  large ones, domed plastic trims with vent slots on small ones. Parked cars' wheels sit under black arch
  trims (`VehicleWheelArches._flare`) instead of behind a slab.
- **Track links** (`VehicleTracks.shoes`, `_link`; the T-55's live belt in `track_belt.gd` shares them):
  without `pads`, a cast single-pin link with a grouser, interleaving hinge lugs and a guide horn on every
  link (CSAT, the T-55, its wreck), running between twin sprockets; with `pads`, a double-pin shoe with two
  rubber pads and end connectors, `guides` putting the centre guide on the connector (Abrams, Bradley,
  Leopard 2, Warrior, Wiesel). Short unsupported return runs sag between supports. `VehicleFittings.tow_cable`
  costs 40% less.
- **Rotor blur** (`VehicleModels._blur_mat`, `VehicleRotors.main(blade_tint)`): a lit translucent disc in the
  blades' colour, denser inboard, a soft ring on the tip path, ghost blades laid out against the world (so
  they drift instead of strobing at the hub's speed), alpha corrected for the browser renderer's blending.
- **Aircraft**: gun-gas soot on the A-10, Wipeout, F-16, Black Wasp, AC-130 and armed Blackfish; tailplane
  soot behind the A-10's engines; VmFighter's wing insignia point at the nose; the NATO Blackfish carries its
  stars and fin serials.

Left for later: soot with a soft alpha edge (layered paint steps in close-ups). The ninth pass took the
tail-rotor and propeller discs and the loft chamfer ring.

### Ninth pass: rotor discs, wrecks, edges and kit

Four agents judged from the battle camera (30-60 m, from above, noon) first and close-ups second. Nodes and
meshes change only on helicopters (+2 to +4 nodes, +1 to +3 meshes: the tail rotor's "Blades" and "Blur",
and the ducted fans' on the Blackfoot and Orca); vertices rise 0.23% across the roster, at most 2.3% (the
Merkava and Scorcher, for their split rolls and bags).

- **Rotor and propeller discs** (`VehicleRotors.BLUR_SHADER`, the material of `VehicleModels._blur_mat` and
  `VehiclePropellers.disc_material`): one lit shader for every rotor and propeller, a nearly black disc
  tinted by the blades' paint at about a quarter opacity, a little thinner over the cabin, with a soft
  darker band near the tips instead of the pale ring that read as a selection circle from above. The ghost
  blades keep a sharp leading edge and a short smear and stay laid out against the world. One shader for
  all propellers (its blade count and hub material values); `VehicleRotors.tail` and `VmHeli._fan` put
  their blades in "Blades" beside a "Blur" disc facing along x, which `Vehicle` swaps at the main rotor's
  speed threshold. A drone's rotors (no main rotor) show their discs from the start, and an aircraft's
  propellers in flight (`Projectile._blur_props`) show only theirs. The studio stage's `--surface-flight`
  shows a model's rotors as they look turning, from above.
- **Burnt hulks** (the surface shader's char branch, `surface_finish == 6`, with `VehicleMaterials.CHAR`'s
  per-family heights; a battle wreck is built in its own paint instead, `k.wreck` without `k.burnt`, and
  burns out under `vehicle_soot.gdshader`): a burnt model's parts read as rust that runs from dark brown to orange with grey
  scale and pitting, a grainy ash film on upward faces, paint only scorched below a family height (armour
  0.55 m, cars 0.28 m), soot along that line and streaked up the sides, and grey-black with white ash on
  aircraft. Parts tinted darker than 0.6 in a channel (exhaust and muzzle mouths, and a burnt vehicle's
  glass and lamps, which `_add` tints 0.3) keep the old sooty black. A gutted car's tyres (`VehicleWheels._belt`)
  are a ragged steel-wire band hung on the rim; every other wreck's burn away to the rims it settles on
  (`Structure._ruin`). Markings, stencils and the tail-rotor and fan discs are left off anything built for a
  wreck (`k.wreck`). A hulk or a gutted car that burns again chars to 30% at most (`Structure._fire_view`), so its rust shows between the
  blackened patches. Buildings' "burnt" preset is unchanged.
- **Chamfered lofts** (`VehicleModels.loft` / `solid` `bevel` and `bevel_bottom`, `extrude_x` `bevel`):
  the end ring moved in by the width within its own plane and a new ring that far back, so the cap keeps its
  plane and the mesh its bounds; capped at 40% of the end segment and 30% of the ring's half-width, halved
  where an edge would turn over, cached under its own key. On 39 sites: bonnets (Hunter, Prowler, M35), the
  HEMTT's nose, sight boxes, the Abrams' hull roof (kept narrow under its welds), consoles, the ships'
  deckhouses and wheelhouse roofs, the civilian tractor's roof. Welded roof edges keep their beads; section
  hulls (`_sec`, `_extrude_z`) are outside its reach.
- **Each crew's own kit** (`VehicleModels.kit_seed`, set in `start` from the seed for team vehicles that
  aren't burnt; scenery and wrecks keep one load so `look`/`stock` still share them): `VehicleCargo.kit`
  draws a generator from the kit seed, a salt and the item's model-space place rounded to 2 cm, and
  `kit_colour` picks the issue colour or another depot's from a palette (`KIT_CLOTH`, `KIT_PAINT`,
  `KIT_TARP`, `KIT_STRAP`), a shade newer or faded. `crate_stack` may have issued its top layer (straps
  cinched down) and lots differ box to box; `bag` holds one, two or three bags, a bedroll, or a gap, each
  full or slumped, some with pockets; `roll` may split in two; `load_cover` varies its tarp, folds and
  lashings; jerrycans and ammo cans vary their paint; `VehicleCargo.tilt_colour` gives each truck's canvas
  tilt one shade for its cloth, bows' lashing and rolled flap; `VmCore._bedroll` draws its colour too.

### Gun mounts: laying, recoil and the guns themselves

The gun builders (`coax`, `autocannon`, `hmg`, `mmg`, `gmg`, `rotary`) end with `k._gun(m, muzzle)` instead of
folding their pivot: the assembly is noted (its parent, origin, muzzle and parts) and then folded as before.
A hand-built gun on a pivot of its own at its receiver notes itself with `k.gun_assembly(pivot, muzzle)`
(VmCore's DShK). When the model is assembled, `_mount_guns()` finds the assembly whose muzzle is `k.mg_tip`
(on the same parent, laid along its -Z) and lifts its parts and nodes onto a new pivot at its origin, square
to the parent; the marker goes with it, and a twin beside it at the same height and depth (the other barrel of
a twin AA gun) gets a pivot of its own. A cradle the family made itself, already laid a little under the
turret (the ZU-23s' `el`), is the mount as it stands, receivers, boxes and all. Each mount lands in
`k.mg_mounts` with its rest pose in `k.mg_rests`; `k.mg_free` is set when it rides on no turret (door guns,
hull pintles). At rest nothing moves, so the sockets fixture and every part's place are unchanged. Wrecks and
fixed-wing aircraft get no mounts.

`Vehicle._lay_guns` (view) lays each mount on `aim_point()`: the target on the host, the replicated aim on a
client. Elevation runs -0.3 to 0.85 rad (to 1.3 for AA weapons, from -1.1 for a helicopter in the air; a coax
keeps to the main gun's -0.16 to 0.31); a free mount also traverses within `mg_arc` (1.2 rad), out of its own
side only. `mg_kick` runs the gun back along its axis by `Fx.MOUNT_KICK` per round with a little muzzle jump,
and `breech_world()` is where its brass and links leave. Each mount is a holder of its own in the merge: a
handful of draw calls per armed vehicle.

The autocannon tube now steps down from a thick chamber end, carries one barrel clamp with a pinch bolt (when
the family asks for no bands) and ends in a brake with dark side ports in two rows and a lip; `_belt` lays a
linked belt with brass rounds from an ammo can's mouth to the feed tray (`hmg`, `mmg`); the `hmg` has its
feed-cover latch and retracting handle, the `mmg` its cover hinge and rear sight. The armed motorboat carries
its PKM on a pintle in the foredeck (it had a gun only in its definition).
