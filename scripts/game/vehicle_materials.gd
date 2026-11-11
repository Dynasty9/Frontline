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
	"automotive": {"surface_normal_strength": 0.03, "surface_finish": 0, "surface_weather": 0.08, "surface_grain": 0.03, "surface_coat_roughness": 0.12, "surface_roughness": 0.24, "map": "coating", "rough": 0.28, "metal": 0.0, "bump": 0.006, "grime": 0.23, "surface_scale": 2.0, "surface_tone": 0.025, "surface_coat": 0.65},
	"marine": {"surface_paint_wear": 0.60,"surface_normal_strength": 0.06, "surface_finish": 0, "surface_weather": 0.23, "surface_grain": 0.08, "surface_coat_roughness": 0.24, "surface_roughness": 0.42, "map": "coating", "rough": 0.42, "metal": 0.0, "bump": 0.012, "grime": 0.07, "surface_scale": 1.5, "surface_tone": 0.05, "surface_coat": 0.2},
	"rubber": {"surface_normal_strength": 0.65, "surface_finish": 1, "surface_weather": 0.22, "surface_grain": 0.65, "surface_roughness": 0.38, "surface_specular": 0.22, "map": "rubber", "rough": 0.88, "metal": 0.0, "bump": 0.09, "grime": 0.27, "surface_scale": 2.0, "surface_tone": 0.18},
	"plastic": {"surface_normal_strength": 0.28, "surface_finish": 7, "surface_weather": 0.10, "surface_grain": 0.35, "surface_roughness": 0.30, "surface_specular": 0.30, "map": "rubber", "rough": 0.63, "metal": 0.0, "bump": 0.025, "grime": 0.12, "surface_scale": 5.0},
	"canvas": {"surface_normal_strength": 0.75, "surface_finish": 2, "surface_weather": 0.30, "surface_grain": 0.70, "surface_roughness": 0.25, "surface_specular": 0.16, "map": "canvas", "rough": 0.96, "metal": 0.0, "bump": 0.10, "grime": 0.18, "surface_scale": 3.0, "surface_tone": 0.28},
	"steel": {"surface_normal_strength": 0.4, "surface_finish": 3, "surface_weather": 0.10, "surface_grain": 0.70, "surface_roughness": 0.62, "map": "metal", "rough": 0.36, "metal": 0.9, "bump": 0.012, "grime": 0.1, "surface_scale": 1.0, "surface_tone": 0.1},
	"gunmetal": {"surface_normal_strength": 0.35, "surface_finish": 3, "surface_weather": 0.15, "surface_grain": 0.42, "surface_roughness": 0.55, "map": "metal", "rough": 0.43, "metal": 0.8, "bump": 0.025, "grime": 0.08, "surface_scale": 2.0, "surface_tone": 0.18},
	"track": {"surface_normal_strength": 0.5, "surface_finish": 3, "surface_weather": 0.40, "surface_grain": 0.26, "surface_wear": 0.35, "surface_roughness": 0.65, "map": "metal", "rough": 0.69, "metal": 0.65, "bump": 0.16, "grime": 0.4, "surface_scale": 3.0},
	"glass": {"surface_normal_strength": 0.0, "surface_finish": 8, "surface_weather": 0.0, "surface_grain": 0.0, "surface_roughness": 0.0, "rough": 0.045, "metal": 0.0, "bump": 0.0, "grime": 0.0, "surface_detail": false, "surface_specular": 0.5},
	"nonslip": {"surface_normal_strength": 0.65, "surface_finish": 4, "surface_weather": 0.23, "surface_grain": 0.75, "surface_roughness": 0.22, "map": "nonslip", "rough": 0.92, "metal": 0.0, "bump": 0.18, "grime": 0.13, "surface_scale": 2.0},
	"tread": {"surface_normal_strength": 0.7, "surface_finish": 4, "surface_weather": 0.20, "surface_grain": 0.25, "surface_roughness": 0.42, "map": "tread", "rough": 0.76, "metal": 0.0, "bump": 0.65, "grime": 0.13, "surface_scale": 0.65, "surface_tone": 0.18},
	"oxidized": {"surface_normal_strength": 0.55, "surface_finish": 3, "surface_weather": 0.25, "surface_grain": 0.35, "surface_roughness": 0.62, "map": "oxidized", "rough": 0.43, "metal": 0.85, "bump": 0.08, "grime": 0.15, "surface_scale": 1.0, "surface_corrosion": 1.0, "surface_tone": 0.12},
	"wood": {"surface_normal_strength": 0.25, "surface_finish": 5, "surface_weather": 0.24, "surface_grain": 0.55, "surface_roughness": 0.22, "map": "coating", "rough": 0.81, "metal": 0.0, "bump": 0.12, "grime": 0.12, "surface_scale": 2.0},
	"burnt": {"surface_normal_strength": 0.8, "surface_finish": 6, "surface_weather": 0.0, "surface_grain": 0.65, "surface_specular": 0.12, "surface_roughness": 0.22, "map": "char", "rough": 0.95, "metal": 0.05, "bump": 0.14, "grime": 0.0, "surface_scale": 2.0},
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
		"rubber", "glass", "mirror", "headlamp", "signal_lens", "track", "burnt", "steel", "gunmetal", "nonslip", "tread", "rotor":
			return kind
		"rust_steel":
			return "oxidized"
		"metal_dark", "gunmetal_w", "wire":
			return "gunmetal"
		"canvas", "canvas_white", "canvas_l", "fabric", "bag", "webbing", "boot":
			return "canvas"
		"wood", "wood_dark", "wood_l", "wood_painted":
			return "wood"
		"plain_dark":
			return "plastic"
		"aircraft":
			return "aircraft"
		"car_paint":
			return "automotive"
	return vehicle_family

static func preset(material_key: String) -> Dictionary:
	if _presets.has(material_key):
		return _presets[material_key]
	var vehicle_family := material_key.get_slice("/", 1)
	var kind := material_key.get_slice("/", 2)
	var finish := profile(kind, vehicle_family)
	var p := Mats._preset(kind).duplicate()
	# Nonslip is explicitly assigned to walking surfaces, with the same tint
	# basis as the plain painted parts it replaces.
	if kind in ["nonslip", "tread", "rotor", "mirror", "headlamp", "signal_lens"]:
		p = Mats._preset("plain").duplicate()
	if finish == "wood":
		p["pattern"] = Mats.WOOD
	if int(p.get("pattern", 0)) not in [Mats.CAMO, Mats.WOOD, Mats.TRACK]:
		p["pattern"] = Mats.PLAIN
	p.merge({"vehicle_surface": true, "local_space": true, "surface_detail": true, "surface_wear": 0.0, "surface_tone": 0.0, "surface_roughness": 0.8, "surface_corrosion": 0.0, "surface_coat": 0.0, "surface_specular": 0.4, "surface_finish": 0, "surface_weather": 0.0, "surface_grain": 0.0, "surface_coat_roughness": 0.22, "rust": 0.0}, true)
	var settings: Dictionary = PROFILES[finish]
	for setting: String in settings:
		if setting != "map":
			p[setting] = settings[setting]
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
	# Aircraft tyres and metalwork don't acquire a land vehicle's mud skirt.
	if vehicle_family == "aircraft":
		p["grime"] = minf(float(p.grime), 0.04)
	_presets[material_key] = p
	return p
