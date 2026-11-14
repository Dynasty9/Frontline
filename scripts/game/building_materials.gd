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
	"brick": {"surface": "brick", "color": Color(0.56, 0.3, 0.21), "finish": "brick",
		"trim": "concrete", "sill": "concrete", "head": "concrete", "base": "brick", "base_tone": -0.35, "cap": "concrete",
		"trim_color": Color(0.62, 0.6, 0.56)},
	"stone": {"surface": "stone", "color": Color(0.56, 0.53, 0.48), "finish": "stone",
		"trim": "stone", "sill": "stone", "head": "stone", "base": "stone", "base_tone": -0.18, "cap": "stone"},
	"concrete": {"surface": "concrete", "color": Color(0.5, 0.49, 0.46), "finish": "cast",
		"trim": "concrete", "sill": "concrete", "head": "concrete", "base": "concrete", "base_tone": -0.12, "cap": "concrete"},
	"precast": {"surface": "precast", "color": Color(0.56, 0.55, 0.52), "finish": "panels", "joints": 2.0,
		"trim": "precast", "sill": "precast", "head": "precast", "base": "precast", "base_tone": -0.1, "cap": "precast"},
	"church": {"surface": "plaster", "color": Color(0.78, 0.73, 0.62), "finish": "render",
		"trim": "stone", "sill": "stone", "head": "stone", "base": "stone", "base_tone": -0.2, "cap": "stone",
		"trim_color": Color(0.74, 0.7, 0.62)},
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
## A house's material by its colour index (the town draws 0 to 4); then the
## parish church's limewashed render (see MapGen._church), and last a barn's
## weatherboarding (see MapGen._house).
const HOUSE := ["plaster", "plaster", "brick", "plaster", "stone", "church", "timber"]


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


## The colour its walls show: rendered walls take the house's paint, bare
## brick and stone their own (a little different from house to house).
static func house_color(ci: int, paint: Color) -> Color:
	match house(ci):
		"brick":
			return [Color(0.56, 0.3, 0.21), Color(0.5, 0.29, 0.22), Color(0.6, 0.36, 0.25)][posmod(ci / HOUSE.size(), 3)]
		"stone":
			return [Color(0.6, 0.57, 0.51), Color(0.55, 0.53, 0.49), Color(0.62, 0.58, 0.5)][posmod(ci / HOUSE.size(), 3)]
		"church":
			# limewash over the render: warm cream, ochre, or pale grey
			return [Color(0.8, 0.75, 0.63), Color(0.76, 0.68, 0.53), Color(0.72, 0.7, 0.65)][posmod(ci / HOUSE.size(), 3)]
		"timber":
			# a barn's boards: barn red, weathered grey, or dark green
			return [Color(0.46, 0.15, 0.11), Color(0.45, 0.43, 0.39), Color(0.22, 0.29, 0.21)][posmod(ci / HOUSE.size(), 3)]
	return paint


## The colour of a material's dressings next to a wall of colour `wall`:
## render bands, stone and painted boards are the wall's own colour a shade
## lighter or darker; brick is dressed in concrete and sheet in steel, their
## own greys whatever the wall.
static func trim_color(material: String, wall: Color, tone := 0.0) -> Color:
	var base: Color = profile(material).get("trim_color", wall)
	return base.lightened(tone) if tone >= 0.0 else base.darkened(-tone)
