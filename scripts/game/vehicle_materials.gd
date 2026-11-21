class_name VehicleMaterials
extends RefCounted
## Shared vehicle finishes. Keep the builders' colours; choose the coating by
## vehicle family and the physical surface by the part's existing material.
## Packed linear maps: R height, G roughness variation, B corrosion, A luminance variation.

const PROFILES := {
	"signal_lens": {"surface_normal_strength": 0.0, "surface_finish": 8, "surface_weather": 0.0, "surface_grain": 0.0, "surface_roughness": 0.0, "rough": 0.16, "metal": 0.0, "bump": 0.0, "grime": 0.0, "surface_detail": false, "surface_specular": 0.5},
	"headlamp": {"surface_normal_strength": 0.0, "surface_finish": 8, "surface_weather": 0.0, "surface_grain": 0.0, "surface_roughness": 0.0, "rough": 0.20, "metal": 0.35, "bump": 0.0, "grime": 0.0, "surface_detail": false, "surface_specular": 0.5},
	"mirror": {"surface_normal_strength": 0.0, "surface_finish": 8, "surface_weather": 0.0, "surface_grain": 0.0, "surface_roughness": 0.0, "rough": 0.035, "metal": 1.0, "bump": 0.0, "grime": 0.0, "surface_detail": false, "surface_specular": 0.5},
	"rotor": {"surface_normal_strength": 0.12, "surface_finish": 7, "surface_weather": 0.04, "surface_grain": 0.12, "surface_roughness": 0.24, "map": "coating", "rough": 0.78, "metal": 0.0, "bump": 0.004, "grime": 0.0, "surface_scale": 3.0, "surface_tone": 0.035, "surface_specular": 0.25},
	"armor": {"surface_paint_wear": 0.85,"surface_normal_strength": 0.08, "surface_finish": 0, "surface_weather": 0.32, "surface_grain": 0.12, "surface_wear": 0.10, "surface_roughness": 0.48, "map": "coating", "rough": 0.73, "metal": 0.0, "bump": 0.018, "grime": 0.32, "surface_scale": 1.5, "surface_tone": 0.08},
	"aircraft": {"surface_paint_wear": 0.40,"surface_normal_strength": 0.04, "surface_finish": 0, "surface_weather": 0.24, "surface_grain": 0.05, "surface_coat": 0.03, "surface_coat_roughness": 0.30, "surface_roughness": 0.30, "map": "coating", "rough": 0.68, "metal": 0.0, "bump": 0.006, "grime": 0.025, "surface_scale": 2.0, "surface_tone": 0.025},
	"automotive": {"surface_normal_strength": 0.03, "surface_finish": 0, "surface_weather": 0.08, "surface_grain": 0.03, "surface_coat_roughness": 0.18, "surface_roughness": 0.24, "map": "coating", "rough": 0.28, "metal": 0.0, "bump": 0.006, "grime": 0.23, "surface_scale": 2.0, "surface_tone": 0.025, "surface_coat": 0.65},
	"marine": {"surface_paint_wear": 0.60,"surface_normal_strength": 0.06, "surface_finish": 0, "surface_weather": 0.23, "surface_grain": 0.08, "surface_coat_roughness": 0.24, "surface_roughness": 0.42, "map": "coating", "rough": 0.42, "metal": 0.0, "bump": 0.012, "grime": 0.25, "surface_scale": 1.5, "surface_tone": 0.05, "surface_coat": 0.2},
	# (a tyre sheds the dust its paint keeps: it flexes and turns, so it takes
	# about a quarter of the hull's, and that a dark road film, see preset)
	"rubber": {"surface_normal_strength": 0.65, "surface_finish": 1, "surface_weather": 0.22, "surface_grain": 0.65, "surface_roughness": 0.38, "surface_specular": 0.22, "map": "rubber", "rough": 0.88, "metal": 0.0, "bump": 0.09, "grime": 0.06, "surface_scale": 2.0, "surface_tone": 0.18},
	"plastic": {"surface_normal_strength": 0.28, "surface_finish": 7, "surface_weather": 0.10, "surface_grain": 0.35, "surface_roughness": 0.30, "surface_specular": 0.30, "map": "rubber", "rough": 0.63, "metal": 0.0, "bump": 0.025, "grime": 0.2, "surface_scale": 5.0},
	# Cotton duck (tilts, tarps, the old kit): a coarse open weave, dead matte,
	# mottled where it has been rained on, sun-faded and dried out again.
	"canvas": {"surface_normal_strength": 0.75, "surface_finish": 2, "surface_weather": 0.30, "surface_grain": 0.70, "surface_roughness": 0.25, "surface_specular": 0.16, "map": "canvas", "rough": 0.96, "metal": 0.0, "bump": 0.10, "grime": 0.18, "surface_scale": 3.0, "surface_tone": 0.28},
	# Woven webbing (straps, slings, the bands round a roll): a tight nylon or
	# polyester twill, its ribs a third the size of canvas's, one even colour
	# that hardly fades, with a dull satin sheen running along it where the
	# fibres lie straight. It reads as a strap, not a strip cut from the tilt.
	"webbing": {"surface_normal_strength": 0.55, "surface_finish": 2, "surface_weather": 0.10, "surface_grain": 0.95, "surface_roughness": 0.12, "surface_specular": 0.36, "map": "canvas", "rough": 0.66, "metal": 0.0, "bump": 0.06, "grime": 0.12, "surface_scale": 9.0, "surface_tone": 0.07},
	# Nylon kit cloth and upholstery (Cordura bags, seat covers, flight suits):
	# finer and smoother than cotton, a faint sheen, its dye holding its colour
	# better than canvas does.
	"nylon": {"surface_normal_strength": 0.42, "surface_finish": 2, "surface_weather": 0.16, "surface_grain": 0.45, "surface_roughness": 0.20, "surface_specular": 0.28, "map": "canvas", "rough": 0.81, "metal": 0.0, "bump": 0.05, "grime": 0.15, "surface_scale": 6.0, "surface_tone": 0.12},
	# Rubberised and PVC-coated cloth (mantlet and NBC covers, marine canvas,
	# a soft top, fuel bladders): the coating fills the weave, which only
	# shows faintly through it; smooth, a little glossy, even in tone, and
	# shedding the rain that stains cotton.
	"coated": {"surface_normal_strength": 0.22, "surface_finish": 1, "surface_weather": 0.18, "surface_grain": 0.22, "surface_roughness": 0.22, "surface_specular": 0.36, "map": "canvas", "rough": 0.6, "metal": 0.0, "bump": 0.03, "grime": 0.14, "surface_scale": 4.0, "surface_tone": 0.06},
	# Laid rope (lashings, grab lines): hairy twisted fibre, coarser than any
	# cloth and matte all over, its strands shading light and dark.
	# Marine canvas (a bimini, a boot, a hatch tarp, sacks aboard): woven
	# solution-dyed acrylic, the yarn dyed before it is spun, so it keeps its
	# colour in the sun and salt where cotton blotches; a tighter, finer weave
	# than cotton duck that still shows, dead matte but for a faint sheen of
	# its water-repellent finish. It reads as cloth, not as the vinyl beside it.
	"acrylic": {"surface_normal_strength": 0.62, "surface_finish": 2, "surface_weather": 0.16, "surface_grain": 0.62, "surface_roughness": 0.18, "surface_specular": 0.2, "map": "canvas", "rough": 0.9, "metal": 0.0, "bump": 0.07, "grime": 0.14, "surface_scale": 4.5, "surface_tone": 0.1},
	"rope": {"surface_normal_strength": 0.9, "surface_finish": 2, "surface_weather": 0.2, "surface_grain": 1.0, "surface_roughness": 0.18, "surface_specular": 0.14, "map": "canvas", "rough": 0.95, "metal": 0.0, "bump": 0.12, "grime": 0.15, "surface_scale": 11.0, "surface_tone": 0.3},
	"steel": {"surface_normal_strength": 0.4, "surface_finish": 3, "surface_weather": 0.10, "surface_grain": 0.70, "surface_roughness": 0.62, "map": "metal", "rough": 0.36, "metal": 0.9, "bump": 0.012, "grime": 0.2, "surface_scale": 1.0, "surface_tone": 0.1},
	"weapon": {"surface_normal_strength": 0.25, "surface_finish": 7, "surface_weather": 0.05, "surface_grain": 0.3, "surface_wear": 0.35, "surface_roughness": 0.7, "map": "metal", "rough": 0.5, "metal": 0.5, "bump": 0.02, "grime": 0.05, "surface_scale": 4.0, "surface_tone": 0.16},
	# (dark steel and its black paint: half metallic and a little rough, so a
	# big flat face, a weapon station's housing, reflects the sky as a dull
	# sheen instead of mirroring it pale, while the metal map still scuffs it
	# bright up close)
	"gunmetal": {"surface_normal_strength": 0.35, "surface_finish": 3, "surface_weather": 0.15, "surface_grain": 0.42, "surface_roughness": 0.55, "map": "metal", "rough": 0.54, "metal": 0.5, "bump": 0.025, "grime": 0.15, "surface_scale": 2.0, "surface_tone": 0.18},
	# Military kit bolted onto a civilian truck (a technical's gun mount, its
	# shields and boxes): service paint, matte and worn at its edges, with no
	# showroom clear coat over it like the truck's own body.
	"service": {"surface_paint_wear": 0.6, "surface_normal_strength": 0.06, "surface_finish": 0, "surface_weather": 0.26, "surface_grain": 0.1, "surface_wear": 0.08, "surface_roughness": 0.45, "map": "coating", "rough": 0.72, "metal": 0.0, "bump": 0.014, "grime": 0.3, "surface_scale": 1.5, "surface_tone": 0.06},
	"track": {"surface_normal_strength": 0.5, "surface_finish": 3, "surface_weather": 0.40, "surface_grain": 0.26, "surface_wear": 0.35, "surface_roughness": 0.65, "map": "metal", "rough": 0.69, "metal": 0.65, "bump": 0.16, "grime": 0.4, "surface_scale": 3.0},
	"glass": {"surface_normal_strength": 0.0, "surface_finish": 8, "surface_weather": 0.0, "surface_grain": 0.0, "surface_roughness": 0.0, "rough": 0.045, "metal": 0.0, "bump": 0.0, "grime": 0.0, "surface_detail": false, "surface_specular": 0.8, "surface_glaze": 0.6},
	# Armoured glass and vision blocks: laminated glass and polycarbonate
	# several centimetres thick, tinted green-black through its layers and set
	# deep in a steel frame. No cab shows through it, only its own dark depth,
	# and each laminate face adds a faint image of its own, so it gives back a
	# slightly softer sheen of the sky than a car's thin screen, over a darker
	# glass. Its reflection leans up toward the sky as the plain glass's does:
	# from above, a tank's blocks read as deep green-grey glass in the cupola
	# and a protected cab's windows as dark panes with the sky's sheen across
	# them, still glass, never a hole (with next to no sky in it, the
	# reflection leaning only a little up, they went the near-black of an
	# open slot).
	"armor_glass": {"surface_normal_strength": 0.0, "surface_finish": 8, "surface_weather": 0.0, "surface_grain": 0.0, "surface_roughness": 0.0, "rough": 0.08, "metal": 0.0, "bump": 0.0, "grime": 0.0, "surface_detail": false, "surface_specular": 0.7, "surface_glaze": 0.6},
	"nonslip": {"surface_normal_strength": 0.65, "surface_finish": 4, "surface_weather": 0.23, "surface_grain": 0.75, "surface_roughness": 0.22, "map": "nonslip", "rough": 0.92, "metal": 0.0, "bump": 0.18, "grime": 0.13, "surface_scale": 2.0},
	"tread": {"surface_normal_strength": 0.7, "surface_finish": 4, "surface_weather": 0.20, "surface_grain": 0.25, "surface_roughness": 0.42, "map": "tread", "rough": 0.76, "metal": 0.0, "bump": 0.65, "grime": 0.13, "surface_scale": 0.65, "surface_tone": 0.18},
	"oxidized": {"surface_normal_strength": 0.55, "surface_finish": 3, "surface_weather": 0.25, "surface_grain": 0.35, "surface_roughness": 0.62, "map": "oxidized", "rough": 0.43, "metal": 0.85, "bump": 0.08, "grime": 0.15, "surface_scale": 1.0, "surface_corrosion": 1.0, "surface_tone": 0.12},
	"wood": {"surface_normal_strength": 0.25, "surface_finish": 5, "surface_weather": 0.24, "surface_grain": 0.55, "surface_roughness": 0.22, "map": "coating", "rough": 0.81, "metal": 0.0, "bump": 0.12, "grime": 0.12, "surface_scale": 2.0},
	"burnt": {"surface_normal_strength": 0.8, "surface_finish": 6, "surface_weather": 0.0, "surface_grain": 0.65, "surface_specular": 0.12, "surface_roughness": 0.22, "map": "char", "rough": 0.95, "metal": 0.05, "bump": 0.14, "grime": 0.0, "surface_scale": 2.0},
}

## Mud and dust from the ground, by family (the surface shader's surface_mud):
## grime is how thick it lies at the bottom (scaled by how much each finish
## takes: a profile's own grime, 0.25 and up taking all of it), mud the height
## in metres its wandering edge reaches, splash how ragged that edge is, and the
## colours of the wet mud low down and the paler dust above it. Tracks churn
## the most up an armoured hull and its running gear; cars pick up road dust
## along the sills; a boat carries a waterline stain, level, instead of mud;
## aircraft none.
const DIRT := {
	"armor": {"grime": 0.95, "mud": 0.85, "splash": 1.0, "mud_col": Color(0.36, 0.30, 0.22), "dust_col": Color(0.58, 0.52, 0.42)},
	"automotive": {"grime": 0.45, "mud": 0.5, "splash": 1.0, "mud_col": Color(0.40, 0.35, 0.28), "dust_col": Color(0.60, 0.55, 0.47)},
	"marine": {"grime": 0.55, "mud": 0.42, "splash": 0.0, "mud_col": Color(0.22, 0.24, 0.18), "dust_col": Color(0.58, 0.59, 0.55)},
	"aircraft": {"grime": 0.0, "mud": 0.0, "splash": 0.0, "mud_col": Color(0.3, 0.25, 0.19), "dust_col": Color(0.55, 0.49, 0.39)},
}

## How high (metres) a family's hull is wet above the water it floats on (the
## surface shader's surface_wet): a boat's topsides are dark and glossy for a
## hand or two above the slop alongside. Land vehicles and aircraft never are.
const WET := {"marine": 0.32}

## Burnt-out wrecks by family (the surface shader's char finish): the colour
## the bare metal goes once the paint has burned off it, the pale ash and heat
## scale where it burned hottest, and how high (metres) the fire only scorched
## the paint before it burned it off. Armour plate rusts to orange-brown, and
## its lower hull, skirts and running gear, below the fighting compartment,
## keep their scorched paint; a car's thin sheet goes more orange, and burns
## to the sills; a boat's steel rusts a little darker; an aircraft's aluminium
## doesn't rust, it burns to dull grey and black under white ash.
const CHAR := {
	"armor": {"rust": Color(0.36, 0.25, 0.19), "ash": Color(0.44, 0.43, 0.41), "low": 0.55},
	"automotive": {"rust": Color(0.42, 0.27, 0.18), "ash": Color(0.5, 0.48, 0.45), "low": 0.28},
	"marine": {"rust": Color(0.33, 0.24, 0.18), "ash": Color(0.42, 0.41, 0.39), "low": 0.3},
	"aircraft": {"rust": Color(0.22, 0.215, 0.21), "ash": Color(0.48, 0.47, 0.45), "low": 0.15},
}

static var _presets := {}
static var _maps := {}

static func family(model: String) -> String:
	if model in VmBoat.KEYS or model in VmShips.KEYS:
		return "marine"
	if model in VmHeli.KEYS or model in VmPlane.KEYS or model in VmGunship.KEYS or model in VmAttack.KEYS or model in VmFighter.KEYS or model in ["heli", "gunship"]:
		return "aircraft"
	if model in VmCiv.KEYS or model in ["technical", "aa_tech"]:
		return "automotive"
	return "armor"

static func key(kind: String, vehicle_family: String) -> String:
	return "vehicle/%s/%s" % [vehicle_family, kind]

static func profile(kind: String, vehicle_family: String) -> String:
	match kind:
		"rubber", "glass", "armor_glass", "mirror", "headlamp", "signal_lens", "track", "burnt", "steel", "gunmetal", "nonslip", "tread", "rotor", "weapon":
			return kind
		"abrams_scorched":
			return "burnt"
		"rust_steel":
			return "oxidized"
		"metal_dark", "gunmetal_w", "wire":
			return "gunmetal"
		"webbing", "rope":
			return kind
		"fabric", "nylon", "cloth":
			# ("cloth": a pilot's flight suit and the kit on it, Nomex and
			# nylon, not the airframe's painted skin)
			return "nylon"
		"coated", "boot":
			return "coated"
		"canvas", "canvas_white", "canvas_l", "bag":
			# A boat's cushions, covers and dry bags are vinyl and PVC, coated
			# against the spray; its plain canvas (a bimini and its boot, a
			# hold's tarp, the sacks of a sandbag wall) is woven acrylic, which
			# stays cloth. Ashore cloth is plain cotton duck unless its builder
			# asks for "coated" or "nylon".
			if vehicle_family == "marine":
				return "acrylic" if kind == "canvas" else "coated"
			return "canvas"
		"wood", "wood_dark", "wood_l", "wood_painted":
			return "wood"
		"plain_dark":
			return "plastic"
		"aircraft":
			return "aircraft"
		"car_paint":
			return "automotive"
		"paint":
			# (a car's own body is car_paint: plain paint on one is fitted kit)
			if vehicle_family == "automotive":
				return "service"
	return vehicle_family

## Turns a pane VehicleGlazing laid in plain glass (the part k._add handed
## back for it) to another glass, `kind`, tinted `col`; its shape and rubber
## seal stay as they were. A protected cab's windows are armoured glass
## ("armor_glass"), which the shared glazing doesn't choose itself. A wreck's
## panes are left as they were.
static func glaze(k: VehicleModels, pane: Variant, kind: String, col = null) -> void:
	if k.wreck or pane == null:
		return
	var mk := key(kind, k.surface_family)
	var mat := Mats.get_mat(mk)
	var t := Mats.tint_for(mk, col) if col is Color else Color(1, 1, 1)
	if pane is Array:
		# (a part noted for the bake: its material and tint, as _add notes them)
		var note := pane as Array
		note[1] = mat
		note[2] = t
	elif pane is MeshInstance3D:
		var mi := pane as MeshInstance3D
		Mats.set_material(mi, mat)
		Mats.set_inst(mi, &"tint", t)


static func preset(material_key: String) -> Dictionary:
	if _presets.has(material_key):
		return _presets[material_key]
	var vehicle_family := material_key.get_slice("/", 1)
	var kind := material_key.get_slice("/", 2)
	var finish := profile(kind, vehicle_family)
	var p := Mats._preset(kind.trim_prefix("cast_")).duplicate()
	# Nonslip is explicitly assigned to walking surfaces, with the same tint
	# basis as the plain painted parts it replaces.
	if kind in ["nonslip", "tread", "rotor", "mirror", "headlamp", "signal_lens"]:
		p = Mats._preset("plain").duplicate()
	if kind == "armor_glass":
		p = Mats._preset("glass").duplicate()
	if finish == "wood":
		p["pattern"] = Mats.WOOD
	if int(p.get("pattern", 0)) not in [Mats.CAMO, Mats.WOOD, Mats.TRACK]:
		p["pattern"] = Mats.PLAIN
	p.merge({"vehicle_surface": true, "local_space": true, "surface_detail": true, "surface_wear": 0.0, "surface_tone": 0.0, "surface_roughness": 0.8, "surface_corrosion": 0.0, "surface_coat": 0.0, "surface_specular": 0.4, "surface_finish": 0, "surface_weather": 0.0, "surface_grain": 0.0, "surface_coat_roughness": 0.22, "rust": 0.0}, true)
	var settings: Dictionary = PROFILES[finish]
	for setting: String in settings:
		if setting != "map":
			p[setting] = settings[setting]
	if finish == "glass":
		# Laminated vehicle glass: a dark cab seen through a faintly blue-grey
		# tint, its coating reflecting a little more than plain window glass.
		p["col_a"] = Color(0.10, 0.13, 0.15)
	elif finish == "armor_glass":
		# (its layers' green-black; the builders' tints, a block's green or a
		# sight's amber coating, stay within reach of it)
		p["col_a"] = Color(0.06, 0.08, 0.075)
	if finish == "gunmetal":
		# (less metallic, the steel shows more of its own colour: a shade
		# darker keeps it the near-black it was where the sky isn't on it)
		p["col_a"] = (p.get("col_a", Color(0.14, 0.14, 0.135)) as Color).darkened(0.22)
		p["col_b"] = (p.get("col_b", Color(0.34, 0.33, 0.31)) as Color).darkened(0.3)
	if kind.begins_with("cast_"):
		# The paint follows the shallow pits in the cast turret shell.
		p["rough"] = 0.84
		p["surface_normal_strength"] = 0.49
		p["surface_grain"] = 0.38
		p["surface_scale"] = 2.1
	var map_name: String = settings.get("map", "coating")
	if not _maps.has(map_name):
		_maps[map_name] = load("res://assets/vehicles/surfaces/%s.png" % map_name)
	p["surface_map"] = _maps[map_name]
	var normal_name := map_name + "_normal"
	if not _maps.has(normal_name):
		_maps[normal_name] = load("res://assets/vehicles/surfaces/%s.png" % normal_name)
	p["surface_normal_map"] = _maps[normal_name]
	# Vehicle camouflage needs broad, legible paint colours rather than the
	# close-value mottling used by small equipment and uniforms.
	if kind == "camo_tank":
		p["col_b"] = Color(0.17, 0.205, 0.135)
		p["col_c"] = Color(0.34, 0.29, 0.20)
		p["col_d"] = Color(0.105, 0.12, 0.095)
	elif kind == "camo_tank_rebel":
		p["col_b"] = Color(0.32, 0.285, 0.20)
		p["col_c"] = Color(0.51, 0.46, 0.34)
		p["col_d"] = Color(0.23, 0.225, 0.16)
	var dirt: Dictionary = DIRT.get(vehicle_family, DIRT.armor)
	p["grime"] = float(dirt.grime) * clampf(float(p.grime) / 0.25, 0.0, 1.0)
	p["surface_mud"] = dirt.mud
	p["surface_splash"] = dirt.splash
	p["surface_mud_col"] = dirt.mud_col
	p["surface_dust_col"] = dirt.dust_col
	if finish == "rubber":
		# Dust on a tyre is the dark film of road grit and brake dust a
		# turning, oily rubber holds, not the pale powder that settles on a
		# painted hull: from the battle camera a dusty tyre still reads as
		# rubber, not as the hull's tan moulded round the wheel.
		p["surface_dust_col"] = (dirt.mud_col as Color).lerp(dirt.dust_col, 0.3).darkened(0.12)
	if WET.has(vehicle_family) and finish != "burnt":
		p["surface_wet"] = WET[vehicle_family]
		p["surface_sea"] = WaterMap.LEVEL
	if finish == "burnt":
		var burnt: Dictionary = CHAR.get(vehicle_family, CHAR.armor)
		p["surface_char_rust"] = burnt.rust
		p["surface_char_ash"] = burnt.ash
		p["surface_char_low"] = burnt.low
	_presets[material_key] = p
	return p
