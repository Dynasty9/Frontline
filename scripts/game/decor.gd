class_name Decor
extends Node3D
## Street furniture and set dressing (world.decor), built on each client from
## the list the server generated: sidewalks and curbs, street lights, utility
## poles and their sagging wires, benches, bins, hydrants, signs, a bus stop,
## the square's fountain or statue and market stalls, playground kit, fences,
## vegetable patches, washing lines, hay bales, a water tower.
##
## Parts are baked into merged meshes per 64 m chunk (so they still cull), the
## wires are drawn as lines and the lamp lenses glow; at dusk and at night the
## street lights cast real light.

const CHUNK := 32.0
const PAINT := [Color(0.78, 0.2, 0.14), Color(0.2, 0.42, 0.75), Color(0.92, 0.72, 0.18), Color(0.25, 0.6, 0.3), Color(0.85, 0.42, 0.12)]
const CANVAS := [Color(0.62, 0.2, 0.16), Color(0.2, 0.36, 0.55), Color(0.28, 0.46, 0.3), Color(0.8, 0.7, 0.42), Color(0.36, 0.34, 0.3)]
## What a blast or a vehicle can knock down, with the box it falls as
## (size, and how heavy it is).
const BREAKABLE := {
	"lamp": [Vector3(0.35, 6.3, 0.35), 160.0], "lamp_deco": [Vector3(0.4, 4.8, 0.4), 120.0],
	"pole": [Vector3(0.35, 8.4, 0.35), 400.0], "sign_stop": [Vector3(0.8, 2.4, 0.15), 25.0],
	"sign_town": [Vector3(2.0, 2.3, 0.15), 40.0], "bench": [Vector3(1.9, 0.9, 0.6), 60.0],
	"bin": [Vector3(0.5, 0.9, 0.5), 20.0], "hydrant": [Vector3(0.35, 0.7, 0.35), 90.0],
	"mailbox": [Vector3(0.3, 1.25, 0.45), 15.0], "bus_stop": [Vector3(3.3, 2.4, 1.6), 300.0],
	"planter": [Vector3(1.2, 1.1, 1.2), 400.0], "bollard": [Vector3(0.2, 0.85, 0.2), 60.0],
	"stall": [Vector3(2.6, 2.3, 1.5), 80.0], "fence": [Vector3(2.0, 1.1, 0.15), 40.0],
	"clothesline": [Vector3(4.0, 1.9, 0.9), 20.0], "flagpole": [Vector3(0.2, 8.0, 0.2), 60.0],
	"transformer": [Vector3(1.2, 1.45, 0.7), 400.0], "hay": [Vector3(2.7, 1.3, 1.3), 200.0],
	"swing": [Vector3(3.5, 2.5, 1.6), 150.0], "slide": [Vector3(3.2, 1.9, 0.8), 120.0],
	"climber": [Vector3(2.0, 1.9, 2.0), 120.0], "seesaw": [Vector3(3.4, 0.7, 0.4), 60.0],
	"roundabout": [Vector3(2.2, 1.0, 2.2), 150.0], "statue": [Vector3(1.8, 4.5, 1.8), 2000.0],
}

var world
var _entries: Array = []  # [kind, pos, yaw, extra, chunk key, broken]
var _chunks := {}  # key -> Node3D
var _chunk_items := {}  # key -> [entry index]
var _hash := {}  # 8 m cell -> [entry index] of breakable pieces
var _dirty := {}  # chunks to rebuild
var _wire_items: Array = []  # [a pole pos, b pole pos (or a house), kind, args]
var _wire_mi: MeshInstance3D
var _wires := PackedVector3Array()  # line pairs
var _glow: SurfaceTool  # the chunk being built
var _glow_n := 0
var _lights: Array = []
var _chunk_lights := {}  # key -> [positions]
var _veh_t := 0.0
var _vpos := {}  # vehicle -> where it was at the last check
var rng := RandomNumberGenerator.new()


func build(w, entries: Array) -> void:
	world = w
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(1.0, 0.92, 0.75)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.82, 0.55)
	for i in entries.size():
		var e: Array = entries[i]
		var kind: String = e[0]
		var pos: Vector3 = e[1]
		var key := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
		_entries.append([kind, pos, float(e[2]), e[3], key, false])
		match kind:
			"wire":
				_wire_items.append([pos, (e[3] as Array)[0], "wire", [pos, float(e[2]), e[3]]])
				continue
			"drop":
				_wire_items.append([pos - Vector3(0, 7.0, 0), e[3], "drop", [pos, e[3]]])
				continue
		if not _chunk_items.has(key):
			_chunk_items[key] = []
		_chunk_items[key].append(i)
		if BREAKABLE.has(kind):
			var hk := Vector2i(floori(pos.x / 8.0), floori(pos.z / 8.0))
			if not _hash.has(hk):
				_hash[hk] = []
			_hash[hk].append(i)
	for key in _chunk_items:
		_build_chunk(key)
	_build_wires()
	_apply_mood()
	if OS.has_environment("FL_DEBUG_DECOR"):
		var mis := 0
		var surfs := 0
		var counts := {}
		for e in _entries:
			counts[e[0]] = counts.get(e[0], 0) + 1
		for c in _chunks.values():
			for m in (c as Node).get_children():
				if m is MeshInstance3D and (m as MeshInstance3D).mesh:
					mis += 1
					surfs += (m as MeshInstance3D).mesh.get_surface_count()
		print("DECOR chunks=%d mis=%d surfaces=%d entries=%d %s" % [_chunks.size(), mis, surfs, _entries.size(), counts])


## (Re)builds one chunk: every piece still standing, merged per material.
func _build_chunk(key: Vector2i) -> void:
	if _chunks.has(key):
		(_chunks[key] as Node3D).queue_free()
	var n := Node3D.new()
	add_child(n)
	_chunks[key] = n
	_glow = SurfaceTool.new()
	_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	_glow_n = 0
	_lights = []
	var keep := _wires
	_wires = PackedVector3Array()  # clotheslines belong to the chunk
	for i in _chunk_items[key]:
		var e: Array = _entries[i]
		if e[5]:
			continue
		var h := Node3D.new()
		h.position = e[1]
		h.rotation.y = e[2]
		n.add_child(h)
		rng.seed = 90210 + i * 7919  # the same look every rebuild
		_make(h, e[0], e[3])
	Mats.merge_static(n)
	if not _wires.is_empty():
		n.add_child(_lines_mi(_wires))
	_wires = keep
	if _glow_n > 0:
		var gm := MeshInstance3D.new()
		gm.mesh = _glow.commit()
		gm.material_override = _glow_mat
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(gm)
	_chunk_lights[key] = _lights


func _lens(h: Node3D, size: Vector3, p: Vector3) -> void:
	var xf: Transform3D = h.transform * Transform3D(Basis.IDENTITY, p)
	_glow.append_from(Res.box(size), 0, xf)
	_glow_n += 1
	_lights.append(xf.origin + Vector3(0, -0.25, 0))


# --- knocking things down ---------------------------------------------------------------

## A blast throws down whatever stands close: lamps and poles topple away from
## it (taking their wires down), benches and bins tumble.
func blast(p: Vector3, size: float) -> void:
	var r := 1.5 + size * 2.6
	for i in _near(p, r):
		var e: Array = _entries[i]
		var d := Defs.flat((e[1] as Vector3) - p)
		var dist := d.length()
		if dist > r:
			continue
		var away := d.normalized() if dist > 0.1 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var pw := (1.0 - dist / r) * size
		_knock(i, away * (2.0 + pw * 6.0) + Vector3.UP * (1.5 + pw * 5.0), away)


func _near(p: Vector3, r: float) -> Array:
	var out := []
	for cx in range(floori((p.x - r) / 8.0), floori((p.x + r) / 8.0) + 1):
		for cz in range(floori((p.z - r) / 8.0), floori((p.z + r) / 8.0) + 1):
			var a = _hash.get(Vector2i(cx, cz))
			if a == null:
				continue
			for i in a:
				if not _entries[i][5]:
					out.append(i)
	return out


func _knock(i: int, vel: Vector3, dir: Vector3) -> void:
	var e: Array = _entries[i]
	if e[5]:
		return
	e[5] = true
	_dirty[e[4]] = true
	var kind: String = e[0]
	world.stat("decor_down")
	# the piece itself falls under physics
	if world.phys:
		var h := Node3D.new()
		add_child(h)
		rng.seed = 90210 + i * 7919
		_glow = SurfaceTool.new()  # a fallen lamp is dark
		_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lights = []
		var keep := _wires
		_wires = PackedVector3Array()
		_make(h, kind, e[3])
		Mats.merge_static(h, [], true, false, true)
		if not _wires.is_empty():
			h.add_child(_lines_mi(_wires))  # built at the origin, like the piece
		_wires = keep
		var xf := Transform3D(Basis(Vector3.UP, float(e[2])), e[1])
		var spec: Array = BREAKABLE[kind]
		var sz: Vector3 = spec[0]
		if kind == "fence" and e[3] is Vector3:
			sz = Vector3((e[3] as Vector3).x, (e[3] as Vector3).y, 0.15)
		# tall things topple over from the base rather than fly
		var tall := sz.y > 3.0
		var spin := dir.cross(Vector3.UP) * (-1.6 if tall else randf_range(-6.0, 6.0))
		if tall:
			vel = dir * 1.5 + Vector3.UP * 0.5
		world.phys.prop(h, xf, vel, spin, sz, float(spec[1]))
	# poles take their wires with them
	if kind == "pole":
		var pp: Vector3 = e[1]
		var changed := false
		for wi in _wire_items:
			if wi.size() > 4:
				continue
			if Defs.flat((wi[0] as Vector3) - pp).length() < 0.6 or Defs.flat((wi[1] as Vector3) - pp).length() < 0.6:
				wi.append(true)
				changed = true
		if changed:
			_build_wires()


func _process(dt: float) -> void:
	_mood_t -= dt
	if _mood_t <= 0.0:
		_mood_t = 1.0
		if world and world.atmo and world.atmo.mood != _mood:
			_apply_mood()
	# rebuild a couple of damaged chunks a frame
	var n := 0
	for key in _dirty.keys():
		if n >= 2:
			break
		_dirty.erase(key)
		_build_chunk(key)
		_apply_mood_chunk(key)
		n += 1
	# vehicles flatten what they drive over
	_veh_t -= dt
	if _veh_t <= 0.0 and world:
		_veh_t = 0.1
		if _vpos.size() > 64:
			_vpos.clear()
		for v in world.vehicles:
			if v.gone or v.is_air() or not v.model:
				continue
			var was: Vector3 = _vpos.get(v, v.position)
			_vpos[v] = v.position
			if Defs.flat(v.position - was).length() < 0.05:
				continue
			var hs: Vector3 = v._hull_size()
			var fwd := Defs.dir_of(v.rotation.y)
			for i in _near(v.position, maxf(hs.x, hs.z) * 0.6):
				var e: Array = _entries[i]
				var rel := Defs.flat((e[1] as Vector3) - v.position)
				if absf(rel.dot(fwd)) < hs.z * 0.55 and absf(rel.dot(fwd.cross(Vector3.UP))) < hs.x * 0.55 + 0.2:
					_knock(i, fwd * 2.0 + Vector3.UP * 0.6, fwd)
					world.stat("decor_crushed")


## One part with a procedural surface, optionally tinted to a colour.
## cut: paving, holed where the ground under it is cratered or dug out.
func _m(h: Node3D, mesh: Mesh, kind: String, p: Vector3, col = null, rot := Vector3.ZERO, shadow := true, cut := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)
	var tn: Color = Mats.tint_for(kind, col) if col is Color else Color(1, 1, 1)
	if cut:
		mi.material_override = Mats.paving(kind)
		if tn != Color(1, 1, 1):
			mi.set_instance_shader_parameter("tint", tn)
	else:
		Mats.apply(mi, kind, tn)
	return mi


func _leaf(h: Node3D, r: float, p: Vector3, col: Color, shadow := true) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Res.sphere(r, 8)
	mi.position = p
	mi.material_override = Mats.foliage()
	mi.set_instance_shader_parameter("tint", col)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)


## A straight member between two local points (legs, braces, chains, rails).
func _beam(h: Node3D, a: Vector3, b: Vector3, t: float, kind: String, col = null, shadow := true) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.001:
		return
	var y := d / L
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var mi := _m(h, Res.box(Vector3(t, L, t)), kind, Vector3.ZERO, col, Vector3.ZERO, shadow)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)


func _make(h: Node3D, kind: String, ex) -> void:
	match kind:
		"walk":
			var s: Vector3 = ex
			_m(h, Res.box(s), "concrete", Vector3(0, s.y * 0.5, 0), Color(0.6, 0.58, 0.54), Vector3.ZERO, false, true)
		"curb":
			var s: Vector3 = ex
			_m(h, Res.box(s), "concrete", Vector3(0, s.y * 0.5, 0), Color(0.72, 0.71, 0.67), Vector3.ZERO, false, true)
		"junction":
			var s: Vector3 = ex
			_m(h, Res.box(Vector3(s.x, 0.02, s.z)), "concrete_floor", Vector3(0, 0.032, 0), Color(0.31, 0.31, 0.3), Vector3.ZERO, false, true)
		"zebra":
			var wd := float(ex)
			var n := 6
			for i in n:
				var z := -wd * 0.5 + (i + 0.5) * wd / n
				_m(h, Res.box(Vector3(2.6, 0.01, wd / n * 0.5)), "paint", Vector3(0, 0.044, z), Color(0.86, 0.86, 0.82), Vector3.ZERO, false, true)
		"lamp":
			if ex == 1:
				_m(h, Res.cyl(0.08, 0.12, 6.0, 8), "wood_dark", Vector3(0, 3.0, 0))
				_m(h, Res.box(Vector3(1.0, 0.07, 0.07)), "wood_dark", Vector3(0.5, 5.6, 0))
				_m(h, Res.cyl(0.07, 0.3, 0.22, 10), "metal_dark", Vector3(1.0, 5.45, 0), Color(0.22, 0.25, 0.22))
				_lens(h, Vector3(0.36, 0.04, 0.36), Vector3(1.0, 5.33, 0))
			else:
				_m(h, Res.cyl(0.17, 0.21, 0.45, 10), "metal_dark", Vector3(0, 0.22, 0))
				_m(h, Res.cyl(0.055, 0.095, 6.2, 8), "metal_dark", Vector3(0, 3.1, 0), Color(0.3, 0.32, 0.32))
				_m(h, Res.box(Vector3(1.5, 0.07, 0.07)), "metal_dark", Vector3(0.72, 6.16, 0), Color(0.3, 0.32, 0.32), Vector3(0, 0, 0.08))
				_m(h, Res.box(Vector3(0.64, 0.14, 0.3)), "metal_dark", Vector3(1.44, 6.14, 0), Color(0.3, 0.32, 0.32))
				_lens(h, Vector3(0.52, 0.04, 0.24), Vector3(1.44, 6.05, 0))
		"lamp_deco":
			_m(h, Res.cyl(0.12, 0.16, 0.5, 10), "metal_dark", Vector3(0, 0.25, 0), Color(0.12, 0.16, 0.13))
			_m(h, Res.cyl(0.05, 0.07, 3.4, 8), "metal_dark", Vector3(0, 1.95, 0), Color(0.12, 0.16, 0.13))
			_m(h, Res.cyl(0.22, 0.12, 0.12, 8), "metal_dark", Vector3(0, 4.12, 0), Color(0.12, 0.16, 0.13))
			_m(h, Res.cyl(0.04, 0.24, 0.16, 8), "metal_dark", Vector3(0, 4.7, 0), Color(0.12, 0.16, 0.13))
			_lens(h, Vector3(0.3, 0.42, 0.3), Vector3(0, 4.4, 0))
		"pole":
			_m(h, Res.cyl(0.11, 0.16, 8.4, 8), "wood_dark", Vector3(0, 4.2, 0), Color(0.3, 0.24, 0.17))
			_m(h, Res.box(Vector3(0.12, 0.11, 2.0)), "wood_dark", Vector3(0, 7.45, 0), Color(0.3, 0.24, 0.17))
			for z in [-0.8, 0.0, 0.8]:
				_m(h, Res.cyl(0.035, 0.055, 0.16, 6), "paint", Vector3(0, 7.58, z), Color(0.82, 0.82, 0.78), Vector3.ZERO, false)
			_beam(h, Vector3(0, 6.9, 0), Vector3(0, 7.42, 0.6), 0.05, "wood_dark", Color(0.3, 0.24, 0.17), false)
			if ex == 1:
				_m(h, Res.cyl(0.27, 0.27, 0.85, 12), "paint", Vector3(0.38, 6.3, 0), Color(0.5, 0.52, 0.48))
		"hydrant":
			_m(h, Res.cyl(0.12, 0.14, 0.62, 10), "paint", Vector3(0, 0.31, 0), Color(0.7, 0.12, 0.08), Vector3.ZERO, false)
			_m(h, Res.sphere(0.13, 8), "paint", Vector3(0, 0.62, 0), Color(0.7, 0.12, 0.08), Vector3.ZERO, false)
			_m(h, Res.cyl(0.05, 0.05, 0.36, 6), "paint", Vector3(0, 0.42, 0), Color(0.75, 0.7, 0.6), Vector3(0, 0, PI * 0.5), false)
		"bin":
			_m(h, Res.cyl(0.24, 0.21, 0.85, 10), "metal_dark", Vector3(0, 0.43, 0), Color(0.12, 0.2, 0.13), Vector3.ZERO, false)
			_m(h, Res.cyl(0.26, 0.26, 0.05, 10), "metal_dark", Vector3(0, 0.88, 0), Color(0.1, 0.15, 0.1), Vector3.ZERO, false)
		"bench":
			_bench(h, Vector3.ZERO)
		"sign_stop":
			_m(h, Res.cyl(0.035, 0.035, 2.3, 6), "metal_dark", Vector3(0, 1.15, 0), Color(0.5, 0.5, 0.5))
			_m(h, Res.cyl(0.39, 0.39, 0.02, 8), "paint", Vector3(0, 2.15, -0.03), Color(0.9, 0.9, 0.88), Vector3(PI * 0.5, 0, 0))
			_m(h, Res.cyl(0.35, 0.35, 0.02, 8), "paint", Vector3(0, 2.15, -0.05), Color(0.72, 0.08, 0.06), Vector3(PI * 0.5, 0, 0))
		"sign_town":
			for x in [-0.8, 0.8]:
				_m(h, Res.cyl(0.04, 0.04, 2.2, 6), "metal_dark", Vector3(x, 1.1, 0), Color(0.5, 0.5, 0.5))
			_m(h, Res.box(Vector3(2.0, 0.7, 0.05)), "paint", Vector3(0, 1.9, 0), Color(0.88, 0.8, 0.22))
			_m(h, Res.box(Vector3(1.86, 0.56, 0.01)), "paint", Vector3(0, 1.9, -0.03), Color(0.95, 0.88, 0.3), Vector3.ZERO, false)
			for y in [2.0, 1.8]:
				_m(h, Res.box(Vector3(1.3 if y > 1.9 else 0.9, 0.09, 0.01)), "paint", Vector3(0, y, -0.04), Color(0.08, 0.08, 0.08), Vector3.ZERO, false)
		"bus_stop":
			for x in [-1.5, 1.5]:
				for z in [-0.6, 0.6]:
					_m(h, Res.box(Vector3(0.07, 2.3, 0.07)), "metal_dark", Vector3(x, 1.15, z), Color(0.28, 0.33, 0.36))
			_m(h, Res.box(Vector3(3.0, 1.9, 0.04)), "glass", Vector3(0, 1.25, 0.6))
			_m(h, Res.box(Vector3(0.04, 1.9, 1.15)), "glass", Vector3(1.5, 1.25, 0.0))
			_m(h, Res.box(Vector3(3.3, 0.08, 1.55)), "metal_dark", Vector3(0, 2.34, 0.0), Color(0.28, 0.33, 0.36))
			_m(h, Res.box(Vector3(2.4, 0.05, 0.38)), "wood", Vector3(0, 0.46, 0.35))
			_m(h, Res.cyl(0.035, 0.035, 2.6, 6), "metal_dark", Vector3(-2.1, 1.3, -0.4), Color(0.5, 0.5, 0.5))
			_m(h, Res.cyl(0.26, 0.26, 0.03, 12), "paint", Vector3(-2.1, 2.5, -0.4), Color(0.15, 0.35, 0.62), Vector3(PI * 0.5, 0, 0))
		"planter":
			_m(h, Res.box(Vector3(1.2, 0.5, 1.2)), "concrete", Vector3(0, 0.25, 0), Color(0.6, 0.58, 0.54))
			_leaf(h, 0.55, Vector3(0, 0.85, 0), Color(0.3, 0.42, 0.2))
			for i in 3:
				var a := TAU * i / 3.0 + 0.4
				_leaf(h, 0.2, Vector3(cos(a) * 0.32, 0.72, sin(a) * 0.32), [Color(0.75, 0.2, 0.28), Color(0.85, 0.7, 0.2), Color(0.6, 0.35, 0.7)][i], false)
		"bollard":
			_m(h, Res.cyl(0.08, 0.1, 0.85, 8), "metal_dark", Vector3(0, 0.42, 0), Color(0.2, 0.2, 0.2), Vector3.ZERO, false)
		"fountain":
			_m(h, Res.cyl(2.35, 2.35, 0.1, 20), "stone", Vector3(0, 0.05, 0))
			for i in 16:
				var a := TAU * i / 16.0
				_m(h, Res.box(Vector3(0.98, 0.55, 0.32)), "stone", Vector3(cos(a) * 2.4, 0.28, sin(a) * 2.4), null, Vector3(0, -a + PI * 0.5, 0))
			_m(h, Res.cyl(0.25, 0.35, 1.4, 10), "stone", Vector3(0, 0.7, 0))
			_m(h, Res.cyl(0.85, 0.35, 0.25, 14), "stone", Vector3(0, 1.45, 0))
			var water := StandardMaterial3D.new()
			water.albedo_color = Color(0.12, 0.22, 0.24)
			water.roughness = 0.05
			water.metallic_specular = 0.9
			Res.mi(h, Res.cyl(2.25, 2.25, 0.04, 20), water, Vector3(0, 0.44, 0), Vector3.ZERO, false)
			Res.mi(h, Res.cyl(0.74, 0.74, 0.03, 14), water, Vector3(0, 1.56, 0), Vector3.ZERO, false)
		"statue":
			_m(h, Res.box(Vector3(1.8, 1.0, 1.8)), "stone", Vector3(0, 0.5, 0))
			if ex == 1:
				_m(h, Res.cyl(0.18, 0.45, 4.2, 4), "stone", Vector3(0, 3.1, 0), Color(0.62, 0.6, 0.56), Vector3(0, PI * 0.25, 0))
			else:
				var bronze := Color(0.22, 0.32, 0.27)
				_m(h, Res.box(Vector3(1.2, 1.4, 1.2)), "stone", Vector3(0, 1.7, 0))
				_m(h, Res.box(Vector3(0.36, 0.9, 0.24)), "metal_dark", Vector3(0, 2.85, 0), bronze)
				_m(h, Res.box(Vector3(0.52, 0.72, 0.32)), "metal_dark", Vector3(0, 3.66, 0), bronze)
				_m(h, Res.sphere(0.17, 10), "metal_dark", Vector3(0, 4.18, 0), bronze)
				_m(h, Res.box(Vector3(0.12, 0.72, 0.12)), "metal_dark", Vector3(0.36, 4.1, 0), bronze, Vector3(0, 0, -0.45))
				_m(h, Res.box(Vector3(0.12, 0.6, 0.12)), "metal_dark", Vector3(-0.33, 3.5, 0), bronze, Vector3(0, 0, 0.2))
				_m(h, Res.box(Vector3(0.6, 0.35, 0.02)), "metal_dark", Vector3(0, 1.6, -0.61), Color(0.45, 0.35, 0.18), Vector3.ZERO, false)
		"flagpole":
			_m(h, Res.cyl(0.045, 0.07, 8.0, 8), "steel", Vector3(0, 4.0, 0))
			# the town's own colours
			_m(h, Res.box(Vector3(1.6, 1.0, 0.02)), "fabric", Vector3(0.84, 7.25, 0), Color(0.86, 0.85, 0.8))
			_m(h, Res.box(Vector3(0.5, 1.0, 0.03)), "fabric", Vector3(0.29, 7.25, 0), Color(0.2, 0.42, 0.3))
			_m(h, Res.box(Vector3(1.1, 0.16, 0.03)), "fabric", Vector3(1.09, 7.25, 0), Color(0.62, 0.16, 0.12))
		"stall":
			var ci := int(ex) if ex != null else 0
			_m(h, Res.box(Vector3(2.2, 0.06, 1.0)), "wood", Vector3(0, 0.9, 0))
			for x in [-1.0, 1.0]:
				for z in [-0.42, 0.42]:
					_m(h, Res.box(Vector3(0.06, 0.9, 0.06)), "wood_dark", Vector3(x, 0.45, z))
				_m(h, Res.cyl(0.03, 0.03, 2.35, 6), "wood_dark", Vector3(x * 1.15, 1.17, 0.5))
				_m(h, Res.cyl(0.03, 0.03, 2.0, 6), "wood_dark", Vector3(x * 1.15, 1.0, -0.55))
			_m(h, Res.box(Vector3(2.6, 0.05, 1.5)), "fabric", Vector3(0, 2.2, 0.0), CANVAS[ci % CANVAS.size()], Vector3(-0.15, 0, 0))
			_m(h, Res.box(Vector3(2.6, 0.25, 0.02)), "fabric", Vector3(0, 2.0, -0.75), CANVAS[ci % CANVAS.size()])
			for i in 4:
				var gx := -0.8 + i * 0.53
				_m(h, Res.box(Vector3(0.42, 0.14, 0.32)), "wood", Vector3(gx, 1.0, 0.0), null, Vector3.ZERO, false)
				_m(h, Res.box(Vector3(0.36, 0.06, 0.26)), "paint", Vector3(gx, 1.09, 0.0), [Color(0.75, 0.15, 0.1), Color(0.9, 0.55, 0.12), Color(0.35, 0.6, 0.2), Color(0.85, 0.75, 0.25)][(i + ci) % 4], Vector3.ZERO, false)
		"transformer":
			_m(h, Res.box(Vector3(1.1, 1.4, 0.6)), "paint", Vector3(0, 0.7, 0), Color(0.3, 0.4, 0.3))
			_m(h, Res.box(Vector3(1.2, 0.06, 0.7)), "paint", Vector3(0, 1.43, 0), Color(0.26, 0.34, 0.26))
			_m(h, Res.box(Vector3(0.22, 0.2, 0.01)), "paint", Vector3(0, 1.0, -0.31), Color(0.95, 0.8, 0.1), Vector3.ZERO, false)
		"awning":
			var a3: Vector3 = ex
			var col: Color = CANVAS[int(a3.z) % CANVAS.size()]
			_m(h, Res.box(Vector3(a3.x, 0.05, 1.3)), "fabric", Vector3(0, 2.45, -0.78), col, Vector3(-0.3, 0, 0))
			_m(h, Res.box(Vector3(a3.x, 0.24, 0.02)), "fabric", Vector3(0, 2.15, -1.4), col)
			_m(h, Res.box(Vector3(a3.x * 0.6, 0.4, 0.05)), "paint", Vector3(0, 2.78, -0.25), Color(0.15, 0.17, 0.2))
		"fence":
			_fence(h, ex)
		"garden":
			var g: Vector3 = ex
			_m(h, Res.box(Vector3(g.x, 0.05, g.z)), "earth", Vector3(0, 0.025, 0), null, Vector3.ZERO, false)
			var rows := maxi(1, int(g.z / 0.75))
			var per := maxi(1, int(g.x / 0.55))
			var leaf: Color = [Color(0.3, 0.5, 0.2), Color(0.42, 0.55, 0.22), Color(0.25, 0.42, 0.25)][rng.randi() % 3]
			for r in rows:
				for k in per:
					if rng.randf() < 0.85:
						_leaf(h, rng.randf_range(0.15, 0.24), Vector3(-g.x * 0.5 + (k + 0.5) * g.x / per, 0.13, -g.z * 0.5 + (r + 0.5) * g.z / rows), leaf, false)
		"clothesline":
			for x in [-2.0, 2.0]:
				_m(h, Res.box(Vector3(0.07, 1.9, 0.07)), "wood", Vector3(x, 0.95, 0))
				_m(h, Res.box(Vector3(0.06, 0.06, 0.9)), "wood", Vector3(x, 1.85, 0))
			for z in [-0.35, 0.35]:
				_sag(h.transform * Vector3(-2.0, 1.85, z), h.transform * Vector3(2.0, 1.85, z), 0.15)
				for i in rng.randi_range(2, 3):
					_m(h, Res.box(Vector3(rng.randf_range(0.4, 0.7), rng.randf_range(0.5, 0.75), 0.02)), "fabric", Vector3(-1.4 + i * 1.1 + rng.randf_range(-0.2, 0.2), 1.45, z), CANVAS[rng.randi() % CANVAS.size()].lightened(0.25), Vector3.ZERO, false)
		"mailbox":
			_m(h, Res.box(Vector3(0.07, 1.0, 0.07)), "wood_dark", Vector3(0, 0.5, 0), null, Vector3.ZERO, false)
			_m(h, Res.box(Vector3(0.26, 0.24, 0.42)), "paint", Vector3(0, 1.1, 0), [Color(0.2, 0.35, 0.25), Color(0.6, 0.15, 0.12), Color(0.15, 0.25, 0.45), Color(0.12, 0.12, 0.12)][rng.randi() % 4], Vector3.ZERO, false)
		"soft":
			var s2: Vector3 = ex
			_m(h, Res.box(Vector3(s2.x, 0.04, s2.z)), "rubber", Vector3(0, 0.02, 0), Color(0.42, 0.2, 0.16), Vector3.ZERO, false)
		"swing":
			var c1: Color = PAINT[rng.randi() % PAINT.size()]
			for x in [-1.7, 1.7]:
				for z in [-0.75, 0.75]:
					_beam(h, Vector3(x, 0, z), Vector3(x, 2.5, 0), 0.08, "paint", c1)
			_beam(h, Vector3(-1.75, 2.5, 0), Vector3(1.75, 2.5, 0), 0.09, "paint", c1)
			for x in [-0.75, 0.75]:
				for dx in [-0.22, 0.22]:
					_beam(h, Vector3(x + dx, 2.48, 0), Vector3(x + dx, 0.58, 0), 0.02, "metal_dark", null, false)
				_m(h, Res.box(Vector3(0.5, 0.05, 0.22)), "rubber", Vector3(x, 0.56, 0))
		"slide":
			var c2: Color = PAINT[rng.randi() % PAINT.size()]
			for z in [-0.28, 0.28]:
				_beam(h, Vector3(-1.6, 0, z), Vector3(-1.3, 1.9, z), 0.06, "metal_dark", Color(0.6, 0.6, 0.6))
			for i in 5:
				var y := 0.3 + i * 0.32
				_m(h, Res.box(Vector3(0.05, 0.04, 0.56)), "metal_dark", Vector3(-1.6 + y * 0.16, y, 0), Color(0.6, 0.6, 0.6), Vector3.ZERO, false)
			_m(h, Res.box(Vector3(0.8, 0.07, 0.8)), "paint", Vector3(-1.0, 1.55, 0), c2)
			for z in [-0.4, 0.4]:
				_m(h, Res.box(Vector3(0.8, 0.4, 0.04)), "paint", Vector3(-1.0, 1.8, z), c2)
			_m(h, Res.box(Vector3(2.85, 0.05, 0.62)), "paint", Vector3(0.65, 0.9, 0), Color(0.85, 0.25, 0.15), Vector3(0, 0, -0.48))
			for z in [-0.31, 0.31]:
				_m(h, Res.box(Vector3(2.85, 0.14, 0.04)), "paint", Vector3(0.65, 0.97, z), Color(0.85, 0.25, 0.15), Vector3(0, 0, -0.48))
			for z in [-0.3, 0.3]:
				_beam(h, Vector3(-0.6, 0, z), Vector3(-0.6, 1.55, z), 0.06, "metal_dark", Color(0.6, 0.6, 0.6))
		"climber":
			var c3: Color = PAINT[rng.randi() % PAINT.size()]
			for i in 3:
				for j in 3:
					_beam(h, Vector3(-1.0 + i, 0, -1.0 + j), Vector3(-1.0 + i, 1.9, -1.0 + j), 0.05, "paint", c3)
			for y in [0.65, 1.3, 1.9]:
				for j in 3:
					_beam(h, Vector3(-1.0, y, -1.0 + j), Vector3(1.0, y, -1.0 + j), 0.05, "paint", c3)
					_beam(h, Vector3(-1.0 + j, y, -1.0), Vector3(-1.0 + j, y, 1.0), 0.05, "paint", c3)
		"seesaw":
			_m(h, Res.box(Vector3(0.25, 0.45, 0.35)), "metal_dark", Vector3(0, 0.22, 0))
			_m(h, Res.box(Vector3(3.4, 0.07, 0.32)), "paint", Vector3(0, 0.52, 0), PAINT[2], Vector3(0, 0, 0.14))
			for x in [-1.3, 1.3]:
				_beam(h, Vector3(x, 0.52 + x * 0.14, -0.14), Vector3(x, 0.82 + x * 0.14, -0.14), 0.04, "metal_dark", null, false)
		"sandbox":
			for z in [-1.32, 1.32]:
				_m(h, Res.box(Vector3(2.8, 0.28, 0.16)), "wood", Vector3(0, 0.14, z))
				_m(h, Res.box(Vector3(0.16, 0.28, 2.5)), "wood", Vector3(z, 0.14, 0))
			_m(h, Res.box(Vector3(2.5, 0.06, 2.5)), "earth", Vector3(0, 0.05, 0), Color(0.82, 0.74, 0.55), Vector3.ZERO, false)
			_m(h, Res.cyl(0.12, 0.09, 0.16, 8), "paint", Vector3(0.6, 0.16, 0.4), PAINT[1], Vector3.ZERO, false)
		"roundabout":
			_m(h, Res.cyl(0.15, 0.2, 0.3, 8), "metal_dark", Vector3(0, 0.15, 0))
			_m(h, Res.cyl(1.1, 1.1, 0.08, 18), "paint", Vector3(0, 0.34, 0), PAINT[0])
			_m(h, Res.cyl(0.05, 0.05, 0.9, 6), "metal_dark", Vector3(0, 0.8, 0))
			for i in 4:
				var a2 := TAU * i / 4.0
				_beam(h, Vector3(cos(a2) * 0.9, 0.38, sin(a2) * 0.9), Vector3(cos(a2) * 0.2, 1.0, sin(a2) * 0.2), 0.04, "metal_dark", Color(0.6, 0.6, 0.6), false)
		"water_tower":
			var steel := Color(0.58, 0.6, 0.58)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_beam(h, Vector3(sx * 2.7, 0, sz * 2.7), Vector3(sx * 1.7, 9.2, sz * 1.7), 0.24, "paint", steel)
					_m(h, Res.box(Vector3(0.7, 0.4, 0.7)), "concrete", Vector3(sx * 2.7, 0.2, sz * 2.7))
			for y in [3.0, 6.2]:
				var k: float = 2.7 - float(y) / 9.2
				for e in [[Vector3(-k, y, -k), Vector3(k, y, -k)], [Vector3(k, y, -k), Vector3(k, y, k)], [Vector3(k, y, k), Vector3(-k, y, k)], [Vector3(-k, y, k), Vector3(-k, y, -k)]]:
					_beam(h, e[0], e[1], 0.1, "paint", steel)
			_m(h, Res.cyl(2.6, 2.6, 0.1, 18), "metal_dark", Vector3(0, 9.15, 0))
			_m(h, Res.cyl(2.3, 2.3, 3.2, 18), "paint", Vector3(0, 10.8, 0), Color(0.62, 0.64, 0.6))
			_m(h, Res.cyl(0.15, 2.45, 1.1, 18), "paint", Vector3(0, 12.95, 0), Color(0.5, 0.52, 0.5))
			_beam(h, Vector3(2.75, 0, 0.25), Vector3(2.4, 12.4, 0.25), 0.05, "metal_dark")
			_beam(h, Vector3(2.75, 0, -0.25), Vector3(2.4, 12.4, -0.25), 0.05, "metal_dark")
		"hay":
			var n2 := int(ex) if ex != null else 1
			for i in n2:
				_m(h, Res.cyl(0.65, 0.65, 1.2, 14), "fabric", Vector3((i - (n2 - 1) * 0.5) * 1.35, 0.65, 0), Color(0.75, 0.64, 0.32), Vector3(0, 0, PI * 0.5))
			if n2 >= 3:
				_m(h, Res.cyl(0.65, 0.65, 1.2, 14), "fabric", Vector3(0, 1.85, 0), Color(0.72, 0.62, 0.3), Vector3(0, 0, PI * 0.5))
		"drive":
			var d2: Vector3 = ex
			_m(h, Res.box(Vector3(d2.x, 0.03, d2.z)), "concrete_floor", Vector3(0, 0.015, 0), Color(0.36, 0.33, 0.29), Vector3.ZERO, false, true)
		"path":
			var p2: Vector3 = ex
			_m(h, Res.box(Vector3(p2.x, 0.03, p2.z)), "earth", Vector3(0, 0.02, 0), Color(0.58, 0.52, 0.42), Vector3.ZERO, false, true)
		"pave":
			var pv: Vector3 = ex
			_m(h, Res.box(Vector3(pv.x, 0.1, pv.z)), "floor_tiles", Vector3(0, 0.05, 0), Color(0.62, 0.58, 0.52), Vector3.ZERO, false, true)
		"lot_pave":
			var lp: Vector3 = ex
			_m(h, Res.box(Vector3(lp.x, 0.04, lp.z)), "concrete_floor", Vector3(0, 0.025, 0), Color(0.13, 0.13, 0.13), Vector3.ZERO, false, true)
			var slots := int(lp.x / 2.6)
			for i in slots + 1:
				var x := -lp.x * 0.5 + i * 2.6 + (lp.x - slots * 2.6) * 0.5
				_m(h, Res.box(Vector3(0.08, 0.005, 4.6)), "paint", Vector3(x, 0.05, lp.y * 2.6), Color(0.85, 0.85, 0.8), Vector3.ZERO, false, true)


func _bench(h: Node3D, o: Vector3) -> void:
	for x in [-0.8, 0.8]:
		_m(h, Res.box(Vector3(0.06, 0.45, 0.42)), "metal_dark", o + Vector3(x, 0.225, 0), null, Vector3.ZERO, false)
		_m(h, Res.box(Vector3(0.05, 0.45, 0.05)), "metal_dark", o + Vector3(x, 0.66, 0.21), null, Vector3.ZERO, false)
	for k in 3:
		_m(h, Res.box(Vector3(1.9, 0.04, 0.11)), "wood", o + Vector3(0, 0.46, -0.15 + k * 0.14), null, Vector3.ZERO, false)
	for k in 2:
		_m(h, Res.box(Vector3(1.9, 0.1, 0.035)), "wood", o + Vector3(0, 0.62 + k * 0.17, 0.22), null, Vector3(-0.15, 0, 0), false)


## Fence styles: 0 white pickets, 1 plank fence, 2 painted railings.
func _fence(h: Node3D, ex) -> void:
	var f: Vector3 = ex
	var L := f.x
	var ht := f.y
	var style := int(f.z)
	var posts := maxi(1, int(ceil(L / 2.2)))
	match style:
		0:
			var white := Color(0.86, 0.85, 0.8)
			for i in posts + 1:
				_m(h, Res.box(Vector3(0.08, ht, 0.08)), "paint", Vector3(-L * 0.5 + i * L / posts, ht * 0.5, 0), white)
			for y in [ht * 0.3, ht * 0.75]:
				_m(h, Res.box(Vector3(L, 0.05, 0.03)), "paint", Vector3(0, y, 0.02), white, Vector3.ZERO, false)
			var n := int(L / 0.24)
			for i in n:
				_m(h, Res.box(Vector3(0.07, ht * 0.92, 0.02)), "paint", Vector3(-L * 0.5 + (i + 0.5) * L / n, ht * 0.46, -0.03), white, Vector3.ZERO, false)
		1:
			for i in posts + 1:
				_m(h, Res.box(Vector3(0.1, ht + 0.05, 0.1)), "wood_dark", Vector3(-L * 0.5 + i * L / posts, (ht + 0.05) * 0.5, 0))
			for y in [0.25, 0.55, 0.85]:
				_m(h, Res.box(Vector3(L, 0.12, 0.025)), "wood", Vector3(0, ht * y, -0.06))
		_:
			var green := Color(0.2, 0.42, 0.26)
			for i in posts + 1:
				_m(h, Res.box(Vector3(0.06, ht, 0.06)), "paint", Vector3(-L * 0.5 + i * L / posts, ht * 0.5, 0), green)
			for y in [0.12, ht - 0.03]:
				_m(h, Res.box(Vector3(L, 0.045, 0.045)), "paint", Vector3(0, y, 0), green, Vector3.ZERO, false)
			var n2 := int(L / 0.3)
			for i in n2:
				_m(h, Res.box(Vector3(0.022, ht - 0.15, 0.022)), "paint", Vector3(-L * 0.5 + (i + 0.5) * L / n2, ht * 0.5, 0), green, Vector3.ZERO, false)


# --- wires ----------------------------------------------------------------------------

func _build_wires() -> void:
	_wires = PackedVector3Array()
	for wi in _wire_items:
		if wi.size() > 4:
			continue  # its pole is down
		var args: Array = wi[3]
		if wi[2] == "wire":
			_wire(args[0], args[1], args[2])
		else:
			_sag(args[0], args[1], 0.35)
	if _wire_mi:
		_wire_mi.queue_free()
		_wire_mi = null
	if _wires.is_empty():
		return
	_wire_mi = _lines_mi(_wires)
	add_child(_wire_mi)


var _line_mat: StandardMaterial3D


func _lines_mi(v: PackedVector3Array) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	if not _line_mat:
		_line_mat = StandardMaterial3D.new()
		_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mat.albedo_color = Color(0.03, 0.03, 0.03)
	mi.material_override = _line_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _wire(a: Vector3, yaw_a: float, ex) -> void:
	var b: Vector3 = ex[0]
	var yaw_b := float(ex[1])
	var ba := Basis(Vector3.UP, yaw_a)
	var bb := Basis(Vector3.UP, yaw_b)
	var flip := -1.0 if (ba * Vector3.BACK).dot(bb * Vector3.BACK) < 0.0 else 1.0
	for z in [-0.8, 0.0, 0.8]:
		_sag(a + ba * Vector3(0, 7.66, z), b + bb * Vector3(0, 7.66, z * flip), 0.15 + a.distance_to(b) * 0.018)


func _sag(a: Vector3, b: Vector3, sag: float) -> void:
	var n := 10
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		_wires.append(prev)
		_wires.append(p)
		prev = p


## Lamp lenses glow (each chunk has its own glow mesh); at dusk, dawn and
## night the street lights cast real light (shadowless, so cheap). Follows
## changes of mood.
var _glow_mat: StandardMaterial3D
var _light_nodes := {}  # chunk key -> [OmniLight3D]
var _mood := ""
var _mood_t := 0.0


func _apply_mood() -> void:
	_mood = world.atmo.mood if world.atmo else "day"
	_glow_mat.emission_energy_multiplier = 6.0 if _mood == "night" else (3.0 if _mood in ["dusk", "dawn"] else 0.25)
	for key in _chunk_lights:
		_apply_mood_chunk(key)


func _apply_mood_chunk(key: Vector2i) -> void:
	for l in _light_nodes.get(key, []):
		(l as Node).queue_free()
	_light_nodes[key] = []
	if not _mood in ["night", "dusk", "dawn"]:
		return
	for p in _chunk_lights.get(key, []):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.8, 0.55)
		l.light_energy = 5.0 if _mood == "night" else 2.2
		l.omni_range = 15.0
		l.omni_attenuation = 1.1
		l.shadow_enabled = false
		l.position = p
		add_child(l)
		_light_nodes[key].append(l)
