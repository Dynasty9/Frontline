extends Node

class Mood extends RefCounted:
	var mood := "night"

class Physics extends RefCounted:
	var pieces := []
	func prop(model: Node3D, xf: Transform3D, velocity: Vector3, spin: Vector3, size: Vector3, mass: float) -> void:
		pieces.append([model, xf, velocity, spin, size, mass])

class Battlefield extends RefCounted:
	var atmo := Mood.new()
	var phys := Physics.new()
	var vehicles := []
	var counts := {}
	func stat(key: String) -> void:
		counts[key] = int(counts.get(key, 0)) + 1
	func vp(_key: String, _started: int) -> void:
		pass

func vertices(span: Array) -> PackedVector3Array:
	var all: PackedVector3Array = (span[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return all.slice(span[1], span[1] + span[2])

func removed(spans: Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for span: Array in spans:
		for p: Vector3 in vertices(span):
			assert(p == Mats.HIDDEN_VERTEX, "Fallen geometry and its shadows must disappear")

func _ready() -> void:
	var w := Battlefield.new()
	var decor := Decor.new()
	add_child(decor)
	decor.set_process(false)
	var entries := [
		["lamp", Vector3(2, 0, 4), 0.0, 0], ["lamp", Vector3(4, 0, 4), 0.3, 1],
		["pole", Vector3(6, 0, 4), 0.0, 0], ["pole", Vector3(10, 0, 4), 0.0, 1],
		["pole", Vector3(14, 0, 4), 0.0, 0],
		["wire", Vector3(6, 0, 4), 0.0, [Vector3(10, 0, 4), 0.0]],
		["drop", Vector3(6, 7, 4), 0.0, Vector3(6, 3, 8)],
		["wire", Vector3(10, 0, 4), 0.0, [Vector3(14, 0, 4), 0.0]],
	]
	for kind: String in Decor.BREAKABLE:
		if kind in ["lamp", "pole"]:
			continue
		var i := entries.size()
		entries.append([kind, Vector3(2 + i % 6 * 4, 0, 10 + i / 6 * 4), 0.4,
			Vector3(2, 1.2, 0) if kind == "fence" else 1])
	entries.append(["walk", Vector3(80, 0, 4), 0.0, Vector3(12, 0.12, 3)])
	decor.build(w, entries)
	var original_chunks := decor._chunks.duplicate()
	var original_wire := decor._wire_mi
	var lamp: Dictionary = decor._entry_draw[0]
	var neighbour: Dictionary = decor._entry_draw[1]
	var before := []
	if DisplayServer.get_name() != "headless":
		for span: Array in neighbour.spans:
			before.append(vertices(span))
	var key: Vector2i = decor._entries[0][4]
	var lights_before: int = decor._light_nodes[key].size()
	var retained_lights := []
	for light: OmniLight3D in decor._light_nodes[key]:
		if not light.position in lamp.lights:
			retained_lights.append(light)
	decor._knock(0, Vector3.ONE, Vector3.RIGHT)
	removed(lamp.spans)
	assert(decor._light_nodes[key].size() == lights_before - lamp.lights.size())
	assert(decor._chunk_lights[key].size() == decor._light_nodes[key].size())
	assert(decor._light_nodes[key] == retained_lights, "Neighboring lamps must retain their lights")
	if not before.is_empty():
		for i in before.size():
			assert(vertices(neighbour.spans[i]) == before[i], "Adjacent geometry and glow must remain byte-for-byte unchanged")
	decor._knock(0, Vector3.ONE, Vector3.RIGHT)
	assert(w.phys.pieces.size() == 1 and w.counts.decor_down == 1, "Repeated explosions must not spawn the same fallen prop twice")
	assert(w.phys.pieces[0][1].origin == entries[0][1] and w.phys.pieces[0][5] == Decor.BREAKABLE.lamp[1])
	decor._knock(2, Vector3.ONE, Vector3.RIGHT)
	assert(decor._wire_items[0].size() == 5 and decor._wire_items[1].size() == 5 and decor._wire_items[2].size() == 4)
	removed([decor._wire_spans[0], decor._wire_spans[1]])
	if DisplayServer.get_name() != "headless":
		assert(vertices(decor._wire_spans[2])[0] != Mats.HIDDEN_VERTEX, "Other poles keep their wires")
	for id: int in decor._entry_draw.keys():
		var spans: Array = decor._entry_draw[id].spans
		assert(not spans.is_empty())
		decor._knock(id, Vector3.ONE, Vector3.RIGHT)
		removed(spans)
	decor._process(1.1)
	assert(decor._chunks == original_chunks and decor._wire_mi == original_wire, "Damage must preserve the original shared meshes")
	assert(decor._entry_draw.is_empty() and w.phys.pieces.size() == Decor.BREAKABLE.size() + 3)
	for lights: Array in decor._chunk_lights.values():
		assert(lights.is_empty())
	w.atmo.mood = "day"
	decor._apply_mood()
	w.atmo.mood = "night"
	decor._apply_mood()
	for lights: Array in decor._light_nodes.values():
		assert(lights.is_empty(), "Changing time of day must not revive fallen lamps")
	w.phys.pieces.clear()
	decor.free()
	print("DECOR_DAMAGE passed")
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
