class_name Battlefields
extends RefCounted
## The menu's catalogue is data only; opening it never compiles the battle.

const MAPS := [
	{"key": "alder-valley", "title": "Alder Valley", "seed": 3, "size": 1024, "water": "coast", "description": "A coastal valley: a western river, central town and harbour on the eastern flank."},
	{"key": "stonebridge", "title": "Stonebridge", "seed": 17, "size": 1024, "water": "river", "description": "An inland river crossing: bridges and fords link wooded villages to the town."},
	{"key": "highland-junction", "title": "Highland Junction", "seed": 41, "size": 1024, "water": "dry", "description": "Dry highland roads: farmland and foothills with no river crossings to hold."},
]


static func find(key: String) -> Dictionary:
	for entry: Dictionary in MAPS:
		if entry.key == key:
			return entry
	return {}


static func options(key: String) -> Dictionary:
	var entry := find(key)
	if entry.is_empty():
		return {}
	return {"battlefield": key, "fixed_seed": entry.seed, "map_size": entry.size}
