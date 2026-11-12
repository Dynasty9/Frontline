# Building buildings from shared components

Buildings are put together the way the vehicles are (see [vehicle-components.md](vehicle-components.md)): each
builder owns its footprint, silhouette, collision parts and layout, and takes its walls, roofs, openings,
fittings and wire from shared components, so an improvement to one window frame reaches every window in town.
The collision and cover a structure gives (`Structure._define_parts`) never depends on these: they are looks only.

| File | Class | What it builds |
| --- | --- | --- |
| `scripts/game/building_kit.gd` | `BuildingKit` | Where parts go and in whose frame; primitives; cached shapes |
| `scripts/game/building_materials.gd` | `BuildingMaterials` | Construction materials: surface, colour, dressings, finish |
| `scripts/game/building_walls.gd` | `BuildingWalls` | Faces (plinths, bands, boards, sheeting, joints, quoins), copings, piers |
| `scripts/game/building_openings.gd` | `BuildingOpenings` | Windows, sills, heads, shutters, doorways, door leaves, roller shutters, louvres, ribbon glazing |
| `scripts/game/building_roofs.gd` | `BuildingRoofs` | Gables, hipped roofs (and pyramids), flat roofs with parapets (and their wear), single-pitch roofs, canopies, north lights; `underside` for seating things on a slope |
| `scripts/game/building_fittings.gd` | `BuildingFittings` | Gutters, hoppers, downpipes, chimneys, flues, stacks, pipe runs, plant, masts, aerials, flagpoles, lamps, drums, crates, pallets |
| `scripts/game/building_wire.gd` | `BuildingWire` | Catenary spans, cables, guys with anchors, insulators, barbed strands, wall-top wire |
| `scripts/game/building_weathering.gd` | `BuildingWeathering` | Ivy, weeds at the foot of walls, the fallen-in roof on a ruin's floor, roof tarps and holes; stains that fade into a wall (soot, rain streaks, scorch), shell scars, bullet strikes, boarded and sandbagged windows |
| `scripts/game/building_furnishings.gd` | `BuildingFurnishings` | Curtains, blinds, nets, window boxes, door lanterns, TV aerials; inside: linings and skirting, radiators, pictures, mirrors, clocks, shelves, rugs |
| `scripts/game/building_shops.gd` | `BuildingShops` | Shop fronts: fascia boards with lettering, blade signs, striped awnings, and the wares a shop puts out (produce stands, cafe tables, sandwich boards, a hardware shop's stock, paper racks) |
| `scripts/game/building_yards.gd` | `BuildingYards` | What people keep round a house: wheelie bins, a woodpile and chopping block, a garden table and chairs (a parasol over some), a kennel, a bicycle, pots of flowers |

## The kit

A `BuildingKit` writes either **nodes** (`BuildingKit.nodes(parent, rng)`: a `MeshInstance3D` per part, merged
with the rest of the model by `Mats.merge_static`, or kept apart when it must move, like a door leaf on its
hinge) or straight into a **bake** (`BuildingKit.baked(bake, rng, at)`: the scenery a town has thousands of,
whose parts never become nodes). `Structure._kit(rng)` picks the right one for the model being built (the kinds
in `Structure.BAKED` bake), and Decor's chunks pass their own bake and holder transform.

Every component works in the kit's frame. For anything on a face (`kit.on_face(point, outward)` or
`kit.at_point(p, rot)`): x runs along the face and is centred on it, y is up from its foot, z points out of it
and the face is at z = 0. Roofs work in a frame whose origin is the building's middle at the ground, the ridge
along x. `kit.moved(xf)` gives the same output in a sub-frame, so components compose.

Parts always carry one of our procedural surfaces (a `Mats` preset) and a colour tint, so `Structure._skin`
leaves them alone and the merged meshes stay one per surface. Keep the number of surfaces a model uses small:
a model merged on its own makes one mesh (one draw call) per surface and shadow setting. Roofs set
`kit.sink.cast_all` so their few tiny shadowless parts don't cost a draw call each.

**Cost.** Things a town has hundreds of are cached as one mesh per shape with `BuildingKit.shape(key, build)`
(window frames, shutters, door leaves and their ironmongery, louvres, gutters, pallets, north-light bars), so a
window frame is one part, not six boxes. Use `kit.plate()` (a plain box) for trims too thin for a chamfer to show
and `kit.box()` (a bevelled `Res.box`) where an edge catches the light; `BuildingKit.ring()` rather than
`Res.torus` for small rings. Square bars (`kit.bar`) are a quarter of a round rod's vertices: downpipes are
square-section. Matched against the models before this kit (best of several runs, a town's worth of preview
models): house walls build in about the same time with 15% fewer vertices and a quarter fewer meshes; a roof costs
about 0.8 ms and 2,000 vertices more (gutters, downpipes, fascia, barge boards, a proper chimney).

**Batching.** House walls, garden walls, floors and crates are merged into 64 m blocks by `StructureView`, which
refuses surfaces in local space. Everything a wall or opening uses is a world-space surface; the test fixture
checks it. Don't dress batched scenery in `roof_tile`, `roof_concrete`, `fabric`, `canvas_l` or the other
`local_space` presets.

## Materials

`BuildingMaterials.PROFILES` names, for each construction material, its surface, its colour, what its dressings
are made of (`trim`, `sill`, `head`, `base`, `cap`) and its `finish`, which decides how a face is built:

| Material | Surface | Finish on a face | Sills / heads | Coping |
| --- | --- | --- | --- | --- |
| plaster | `plaster` | Darker rendered plinth, band under the eaves | Render bands in the wall's paint | Cast cap with drips |
| brick | `brick` | Engineering-brick base | Concrete sills and lintels | Brick-on-edge over a creasing |
| stone | `stone` | Stone base course, dressed quoins | Stone sills, lintel with a keystone | Saddleback |
| concrete | `concrete` | Cast base | Cast | Cast cap with drips |
| precast | `precast` | Sealed panel joints | Cast | Cast cap |
| timber | `wood_painted` | Lapped weatherboards, corner boards | Painted timber | Timber |
| corrugated | `corrugated` | Sheet laps, base angle, top flashing over a concrete upstand | Steel | Steel |

Roof coverings: `roof_tile` (round ridge, fascia, barge boards), `roof_sheet` (lapped sheets, ridge capping,
drip edges), `roof_concrete` (flat slabs) and `canvas`.

A house's material follows its colour index (`BuildingMaterials.house`, `HOUSE`): most are rendered and painted,
the red-brown ones bare brick, the grey-brown ones rough stone. Brick and stone houses take the material's own
colour (`house_color`), their roofs' gables follow, and their debris is their colour.

## Lived-in houses and lamplight

`BuildingFurnishings` dresses a house as somebody's home. At the windows: drapes, a roller blind or nets
(`BuildingOpenings.window` opts `curtains` and `curtain`). The glass is opaque, so they hang just in front of it,
behind the glazing bars, which is how they show through it. Outside: flowers in a box on some sills, a lantern
by about half the front doors, a TV aerial on half the pitched roofs. Inside each wall section, facing into the
room: its paint and skirting (`lining`, cut round the openings), a radiator under each window, and on plain
walls a picture or two, a mirror, a clock or a shelf of books. A rug lies on most floors.

**Nothing in a room may stand where a man does.** `Cover` puts fighting positions half a metre off both faces
of every house wall, and men cross the room's middle. So room things hang flat on the walls (within a hand's
breadth below head height; shelves stand out only above 1.85 m) or lie flat on the floor. The fixture samples
the space a standing man takes along a wall over sixteen seeds of `wall_things`.

**Lamplight.** The `window_lit` surface is glass with `lit` set: it glows warm by `window_glow`, a global
shader value (registered in `project.godot`) that `Atmosphere.lamplight(mood)` sets as the time of day changes:
1 at night, about half at dusk, a little on a dark day, none in sunshine. Each window's brightness varies with
where it is, so a batch keeps every room's own. About a third of house windows have a lamp on (and keep their
glass), most barracks windows and the research post's glazing do, and so do the factory's north lights and the
door lanterns. It is an emissive surface, not a light: it costs nothing per window and casts no light round it.
Render a building at night with `--building-night` in the studio stage.

## Weathering and ruins

`BuildingWeathering` adds what time and the war leave. Weeds tuft along the foot of about half the house walls
(stopping at doorsteps) and of half the garden walls; ivy climbs about one plain house wall in eight, nearer one
in three on stone houses. A ruined house's floor (mapgen marks it, variant 1, without drawing any random
numbers) carries its fallen roof: soot where it burned, charred rafters lying across the room, broken tiles,
lumps of plaster and brick, glass. Like furnishings these keep out of a man's way: ivy and weeds within a hand's
breadth of the wall and below the eaves, a ruin's debris inside the room and no higher than an ankle; the
fixture checks both over ten seeds. Lived-in and weathering choices each draw from a stream of their own
(seeded from the structure's), so adding either never changes a house's chimney, shutters, panes or doors.

Rain and the war mark the house walls too, each wall drawing from a stream of its own. Under about half the
window sills rain has run down the wall in two streaks; above one window or door in fourteen a fire inside has
licked soot up the face; one wall in five has taken a burst of bullet strikes (flakes of the face knocked off
round dark holes, missing the openings); about one plain wall in fourteen has a shell hit: the render blown off
to the brick behind it, scorched round, spattered with strikes. At the windows, the glass of some lived-in houses
is taped in crosses against the blast, some windows are boarded across (with gaps: a window a man can still see
and shoot through) and some have sandbags laid along the sill. Soot, streaks and scorch are
`BuildingWeathering.stain`: a patch of the wall's own surface 3 mm proud, its vertex colours running from the
stain to exactly the tint the wall's body was drawn in (`Structure._tone`), so it fades into the wall with no
edge; the fixture checks the rim comes back to the wall's colour. Everything stays within a hand's breadth of the
face, so cover is unchanged.

## Shop fronts

The town's shops (near the square) each have a front from `BuildingShops`, decided by the kind of shop the town
already drew for it: a greengrocer, a cafe, a baker, a hardware shop or a newsagent. A painted fascia board over
the windows carries the shop's name in raised letters (letter shapes from a small set, so a name reads as a name
from the street, though not in any language), and about half have a sign standing out from the wall on a bracket.
Under the fascia a striped canvas awning on its arms, its scalloped edge no lower than 1.88 m. On the pavement,
clear of the door, one or two lots of what the shop puts out: crates of fruit and vegetables on a stand, a table
and chairs, a sandwich board and tubs of flowers, sacks on a pallet with gas bottles and buckets, a paper rack.
The wares are breakable set dressing, placed from a stream of their own after every other piece of decor, so the
town is otherwise the same. Render a parade of three with `--building-kinds=shops` in the studio stage; the town
views include a shop front.

## Roofscapes

A town's pitched roofs differ the way real ones do. Each is pitched anywhere from 24 to 36 degrees, and about a
third are hipped (`BuildingRoofs.hip`: four slopes at one pitch, hip and ridge tiles, a fascia and gutters all
round), which over a square house makes a pyramid. A chimney stands on the lowest point of the slope under it
(`BuildingRoofs.underside` gives the underside's height anywhere over the walls, gable or hip). About one roof in
eight has been mended with a tarpaulin weighted down with tyres and sandbags, one in sixteen has a hole with the
battens showing (both `BuildingWeathering`), and one in seven a skylight (`BuildingFurnishings.skylight`), two in
five of them lit after dark. The form and the patches each draw from a stream of their own, so tints, chimneys
and aerials are what they were. Roofs are looks only (no collision), so none of this changes cover or movement.
Render four roofs together with `--building-kinds=roofscape` in the studio stage.

Roofs weather too, each from a stream of its own. Every pitched roof grows two to four patches of moss and
lichen, most on the back slope: dark green where it holds the damp, pale yellow-grey where it's dry, mottled,
each kept inside its own slope (clear of the hips and verges). Every flat roof (`BuildingRoofs.flat_wear`) has
one to three dark rings where rain stood in a hollow, sometimes green with algae, up to two patches of newer
membrane over old leaks, moss along the foot of a parapet on most, and a vent pipe or two. The stains are
`BuildingWeathering.stain` on the covering (its own surface, so they fade into it); the fixture keeps a flat
roof's wear on its deck inside the parapets, and the forty-roof check covers the pitched ones.

## Yards

`BuildingYards` builds what the people in a house keep round it, and the town places them round each house
(not the shops) from a stream of its own seeded from where the lot is: two in three houses have a wheelie bin or
two at the front corner away from the door, a third pots of flowers by the door, a quarter a bicycle leaning on
a side wall, and out the back two in five a woodpile against the back wall with its chopping block and axe, two
in five a table and chairs on the grass (a parasol over some), one in seven a kennel in a corner of the garden.
They're set dressing (Decor, appended after the rest so the town's other dressing keeps its looks): no cover,
and a blast or a truck knocks them over. Render them with `--building-kinds=house_yard` in the studio stage.

## Openings stay open

The holes in a wall are the builder's: its collision parts leave them. Dressings must not fill them. Pass the
openings as `gaps` (Rect2s in face x and y) to `BuildingWalls.face` so plinths, bands, boards and joints stop at
them, as a real wall's do. Frames sit back in the reveal (`inset`); on a solid block with no real hole, pass a
negative inset so the frame stands proud of the face and glaze it fully (`glazing = 1.0`), since a missing pane
would show the block behind. Door leaves that swing are built in their own hinge kit (`BuildingKit.nodes(pivot)`);
`BuildingOpenings.leaf` runs the leaf out along `toward` from the hinge line.

## Who uses what

| Component | Users |
| --- | --- |
| `BuildingWalls.face` | House walls (rendered, brick, stone), barracks (weatherboard), factory (sheet), research post (precast) |
| `BuildingWalls.coping`, `plinth`, `joints` | Garden walls (saddleback stone, brick-on-edge over a blue-brick base), compound walls, flat-roof parapets, bridge parapets |
| `BuildingOpenings.window` | House windows (louvred or boarded shutters, cracked panes), barracks windows |
| `BuildingOpenings.doorway`, `leaf` | House doors (panelled, now and then a hood), barracks (ledged double doors), research post and bunker (steel) |
| `BuildingOpenings.roller_door`, `ribbon` | Factory shutter; research post glazing |
| `BuildingRoofs.gable`, `hip` | House roofs (tile: about a third hipped), barracks (sheet) |
| `BuildingRoofs.flat`, `mono`, `canopy`, `sawtooth` | Flat house roofs; watchtower roof; barracks porch and house door hoods; factory north lights |
| `BuildingFittings` rainwater goods | Every pitched and flat house roof, the barracks, the boat shed |
| `BuildingFittings.chimney`, `flue`, `stack`, `pipe` | House chimneys; barracks stove, bunker vent, factory cowls, generator exhaust; factory chimney and pipe runs |
| `BuildingFittings` plant | Flat roofs, barracks and research post (air conditioners, water tanks, dishes) |
| `BuildingFittings.mast`, `whip`, `flagpole`, `lamp` | FOB and research post masts; FOB and bunker aerials; town dump, barracks, Coalition dock flagpoles; bridge and quay lamps |
| `BuildingFittings.drum`, `crate`, `pallet` | FOB, town dumps, barracks, barricades, ammunition caches, the dock |
| `BuildingWire` | Mast guys, tent, tarp, camouflage-net and FOB net guy ropes, utility-pole insulators, power-line sag (Decor), barbed strands (also the concertina), compound-wall wire |

Specialised construction stays with its builder: the dock's boat shed frame and jetty, trench kit, the
concertina's coils, sandbags, HESCO cells, the camouflage net itself, trees, cars and wrecks.

## Checking

`node --test tests/building-components.test.mjs` (from `tests/`, with `GODOT` set) runs
`tests/fixtures/building-components.tscn`: every component builds finite geometry as nodes and into a bake, a
doorway's passage and a window's openings are clear of their dressing, shared shapes are shared, house walls and
garden walls stay batchable, and every building kind and scenery kind still builds its model.

To look at them, render the studio stage off-screen:

```
godot --path . tools/showcase/building-surfaces.tscn -- --building-out=/tmp/buildings --offscreen
godot --path . tools/showcase/building-surfaces.tscn -- --building-out=/tmp/parts --building-components --offscreen
```

`--building-single` gives one 1600×900 close-up per subject, `--building-rear` the back quarter, `--building-night`
the lamps lit with the sun down (`house_open` shows a house without its roof, as when men are inside, and
`house_ruin` a ruin with walls down), and
`--building-kinds=` a selection: the named subjects (`house_pitched`, `house_flat`, `house_window`, `barracks`,
...), any structure as `kind:side[:variant]`, or with `--building-components` the parts (`wall_brick`,
`roof_sheet`, `window_shutters`, `door_steel`, `gutter_downpipe`, `wire_topping`, ...). The stage builds the
same preview models as the Field Manual, so it renders the same subject on two revisions. For buildings in
place, `tests/fixtures/environment-views.gd` with `--capture-set=town` (see `tools/showcase/README.md`).
