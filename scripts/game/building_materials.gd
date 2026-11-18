class_name BuildingMaterials
extends RefCounted
## What buildings are built of. A construction material names the surface it
## shows (a Mats preset), the colour it has when the builder gives none, and
## how the shared components build in it: what its sills, lintels and copings
## are made of, how its face is finished (rendered with a plinth, brick with a
## blue-brick base, stone with dressed quoins, boards lapped, sheet lapped and
## flashed, precast in jointed panels) and what its roof covering does at the
## ridge and the eaves. Components ask here, so a material learned once is
## learned by every building that uses it.
##
## Batched scenery (house walls, garden walls) must keep to surfaces that are
## not in local space (see StructureView._build_draw_batch): every surface
## named below for walls, openings and trims is a world-space one.

const PROFILES := {
	# walls
	"plaster": {"surface": "plaster", "color": Color(0.72, 0.66, 0.55), "finish": "render",
		"trim": "plaster", "sill": "plaster", "head": "plaster", "base": "plaster", "base_tone": -0.3, "cap": "plaster"},
	"brick": {"surface": "brick", "color": Color(0.42, 0.27, 0.22), "finish": "brick",
		"trim": "concrete", "sill": "concrete", "head": "concrete", "base": "brick", "base_tone": -0.35, "cap": "concrete",
		"trim_color": Color(0.62, 0.6, 0.56)},
	"stone": {"surface": "stone", "color": Color(0.56, 0.53, 0.48), "finish": "stone",
		"trim": "stone", "sill": "stone", "head": "stone", "base": "stone", "base_tone": -0.18, "cap": "stone"},
	"concrete": {"surface": "concrete", "color": Color(0.5, 0.49, 0.46), "finish": "cast",
		"trim": "concrete", "sill": "concrete", "head": "concrete", "base": "concrete", "base_tone": -0.12, "cap": "concrete"},
	"precast": {"surface": "precast", "color": Color(0.56, 0.55, 0.52), "finish": "panels", "joints": 2.0,
		"trim": "precast", "sill": "precast", "head": "precast", "base": "precast", "base_tone": -0.1, "cap": "precast"},
	"timber": {"surface": "wood_painted", "color": Color(0.3, 0.34, 0.22), "finish": "boards", "boards": 0.24,
		"trim": "wood_dark", "sill": "wood_dark", "head": "wood_dark", "base": "concrete", "base_tone": 0.0, "cap": "wood_dark"},
	"corrugated": {"surface": "corrugated", "color": Color(0.45, 0.46, 0.44), "finish": "sheet", "sheets": 1.05,
		"trim": "steel", "sill": "steel", "head": "steel", "base": "concrete", "base_tone": 0.0, "cap": "steel",
		"trim_color": Color(0.4, 0.41, 0.39)},
	# roof coverings
	"roof_tile": {"surface": "roof_tile", "color": Color(0.5, 0.22, 0.14), "ridge": "round", "eaves": "fascia",
		"trim": "paint", "thickness": 0.09},
	"roof_sheet": {"surface": "corrugated", "color": Color(0.45, 0.47, 0.45), "ridge": "capping", "eaves": "drip",
		"trim": "steel", "thickness": 0.04, "laps": 0.95},
	"roof_concrete": {"surface": "roof_concrete", "color": Color(0.52, 0.5, 0.47), "ridge": "", "eaves": "",
		"trim": "concrete", "thickness": 0.2},
	"canvas": {"surface": "canvas", "color": Color(0.4, 0.41, 0.31), "ridge": "sleeve", "eaves": "",
		"trim": "wood_dark", "thickness": 0.03},
}

## The materials a house can be built of, by its colour index (see
## Structure.HOUSE_COLORS): most are rendered and painted, the red-brown ones
## are bare brick, the grey-brown ones rough stone.
## A house's material by its colour index (the town draws 0 to 4); a barn's
## is the last, weatherboarding (see MapGen._house).
const HOUSE := ["plaster", "plaster", "brick", "plaster", "stone", "timber"]


## What a town's pitched roofs are covered in. Clay tiles fired in different
## kilns and aged differently: a newer orange clay, the usual terracotta gone
## brown with the years, a dark red-brown, and the concrete tiles of later
## houses in brown and in a sooty red; the rest slate or grey concrete tile.
## None as bright as a new tile: a roof is out in all weathers, its surface
## dulled by dirt and lichen (and the tile photograph carries its own
## variation tile by tile on top of this).
const ROOF_CLAY := [Color(0.45, 0.26, 0.19), Color(0.4, 0.25, 0.2), Color(0.35, 0.21, 0.17), Color(0.32, 0.24, 0.2), Color(0.34, 0.18, 0.15)]
const ROOF_SLATE := [Color(0.25, 0.25, 0.26), Color(0.32, 0.31, 0.29), Color(0.21, 0.21, 0.21)]
## A barn's sheet roof: rusted, galvanised gone dull grey, or painted red.
const BARN_SHEET := [Color(0.34, 0.25, 0.21), Color(0.3, 0.31, 0.31), Color(0.32, 0.16, 0.13)]


## What a flat roof is covered in: bitumen felt gone dull black-grey, green-
## grey mineral felt, the bare concrete deck or pale chippings, old asphalt.
## Drawn by `deck_color`, felt the most often (it's what goes on a house).
const FLAT_DECKS := [Color(0.27, 0.27, 0.27), Color(0.34, 0.36, 0.32), Color(0.5, 0.49, 0.46), Color(0.41, 0.39, 0.36)]


static func deck_color(rng: RandomNumberGenerator) -> Color:
	var r := rng.randf()
	var c: Color = FLAT_DECKS[0 if r < 0.35 else (1 if r < 0.6 else (2 if r < 0.85 else 3))]
	return c.lightened(rng.randf_range(-0.02, 0.04))


## A pitched roof's tint: clay (shade its few per cent lighter or darker) or
## slate, which one drawn from `rng`.
static func roof_color(clay: bool, shade: float, rng: RandomNumberGenerator) -> Color:
	var pick: Array = ROOF_CLAY if clay else ROOF_SLATE
	var c: Color = pick[rng.randi() % pick.size()]
	var k := 1.0 + shade
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1))


static func profile(material: String) -> Dictionary:
	return PROFILES.get(material, PROFILES["plaster"])


## The surface (a Mats preset) the material shows.
static func surface(material: String) -> String:
	return profile(material).surface


static func color(material: String) -> Color:
	return profile(material).color


## The surface its dressings (sills, heads, copings) are made in.
static func trim(material: String, part := "trim") -> String:
	var p := profile(material)
	return p.get(part, p.get("trim", "concrete"))


static func value(material: String, key: String, fallback: Variant = null) -> Variant:
	return profile(material).get(key, fallback)


## What a house of colour index `ci` is built of.
static func house(ci: int) -> String:
	return HOUSE[posmod(ci, HOUSE.size())]


## The colours a rendered house is painted, three to each of the rendered
## colour indices (0, 1 and 3; which of the three is ci / HOUSE.size(), as
## for brick and stone): limewash and cream, a pale ochre, warm white; beige,
## a faded pink, grey render; off-white, a dull sage, a pale yellow. All of
## them old paint, a little dirty, none of them bright.
const RENDERS := [Color(0.72, 0.66, 0.55), Color(0.73, 0.66, 0.54), Color(0.78, 0.76, 0.7),
	Color(0.66, 0.6, 0.52), Color(0.72, 0.61, 0.55), Color(0.62, 0.61, 0.58),
	Color(0.75, 0.72, 0.66), Color(0.62, 0.63, 0.57), Color(0.76, 0.72, 0.62)]


## The colour its walls show: rendered walls take the house's paint, bare
## brick and stone their own (a little different from house to house).
static func house_color(ci: int, paint: Color) -> Color:
	match house(ci):
		"plaster":
			var slot: int = [0, 1, 0, 2, 0, 0][posmod(ci, HOUSE.size())]
			if posmod(ci, HOUSE.size()) in [0, 1, 3]:
				return RENDERS[slot * 3 + posmod(ci / HOUSE.size(), 3)]
			return paint
		"brick":
			# (old brick: red-brown, a darker purple-brown, a sandier red;
			# never a new brick's orange)
			return [Color(0.42, 0.27, 0.22), Color(0.38, 0.25, 0.22), Color(0.46, 0.32, 0.26)][posmod(ci / HOUSE.size(), 3)]
		"stone":
			# (a local stone, a little warm: buff, grey, honey)
			return [Color(0.6, 0.55, 0.46), Color(0.55, 0.53, 0.48), Color(0.63, 0.56, 0.45)][posmod(ci / HOUSE.size(), 3)]
		"timber":
			# a barn's boards: barn red, weathered grey, or dark green
			return [Color(0.37, 0.14, 0.1), Color(0.42, 0.4, 0.37), Color(0.2, 0.26, 0.19)][posmod(ci / HOUSE.size(), 3)]
	return paint


## The colour of a material's dressings next to a wall of colour `wall`:
## render bands, stone and painted boards are the wall's own colour a shade
## lighter or darker; brick is dressed in concrete and sheet in steel, their
## own greys whatever the wall.
static func trim_color(material: String, wall: Color, tone := 0.0) -> Color:
	var base: Color = profile(material).get("trim_color", wall)
	return base.lightened(tone) if tone >= 0.0 else base.darkened(-tone)
