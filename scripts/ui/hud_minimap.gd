class_name HudMinimap
extends Control

var hud: Hud
var _drag := false
var _bg: ImageTexture
var _static: ImageTexture  # backdrop + roads + neutral scenery, rebuilt when they change
var _static_sig := -1
var _sig_t := 0.0

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				hud.world.cam.focus(_to_world(mb.position))
				if hud.world.director:
					hud.world.director.active = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			hud.world.input.order_at(_to_world(mb.position))
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		hud.world.cam.focus(_to_world((ev as InputEventMouseMotion).position))

func _to_world(p: Vector2) -> Vector3:
	return Vector3(p.x / size.x * MapDims.SIZE - MapDims.HALF, 0, p.y / size.y * MapDims.SIZE - MapDims.HALF)

func _to_map(p: Vector3) -> Vector2:
	return Vector2((p.x + MapDims.HALF) / MapDims.SIZE * size.x, (p.z + MapDims.HALF) / MapDims.SIZE * size.y)

## Terrain backdrop from the same noise the ground shader uses.
func _make_bg() -> void:
	var at: Atmosphere = hud.world.atmo
	if at == null or at.biome_img == null:
		return
	var n := 128
	var mpp := MapDims.SIZE / n  # metres per pixel
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var wp := Vector3((x + 0.5) * mpp - MapDims.HALF, 0, (y + 0.5) * mpp - MapDims.HALF)
			var g := at.grass_amount(wp)
			var b := at.biome_at(wp)
			var c := Color(0.36, 0.31, 0.22).lerp(Color(0.24, 0.32, 0.15), g)
			c = c.lerp(Color(0.33, 0.33, 0.2), clampf((b - 0.45) * 2.0, 0.0, 0.35) * g)
			img.set_pixel(x, y, c.darkened(0.15))
	_bg = ImageTexture.create_from_image(img)

## Bakes the parts of the map that rarely change into one texture.
func _bake_static() -> void:
	var w := hud.world
	if _bg == null:
		_make_bg()
	if _bg == null:
		return
	var n := 512
	var img: Image = _bg.get_image()
	img.resize(n, n, Image.INTERPOLATE_BILINEAR)
	var k := n / MapDims.SIZE  # pixels per metre
	if w.water and w.water.mask:
		# the sea, the river and the ponds; sand and mud along their shores
		var wm: Image = w.water.mask.duplicate()
		wm.resize(n, n, Image.INTERPOLATE_BILINEAR)
		for y in n:
			for x in n:
				var c := wm.get_pixel(x, y)
				if c.a > 0.5:
					img.set_pixel(x, y, Color(0.12, 0.2, 0.22).lerp(Color(0.05, 0.11, 0.16), c.r).lerp(Color(0.1, 0.22, 0.27), c.b * 0.5))
				elif c.g > 0.3:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.5, 0.45, 0.32) if c.b > 0.5 else Color(0.3, 0.26, 0.18), 0.6))
	for t in 3:
		for poly in w.roads[t]:
			var pts: PackedVector3Array = poly
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var steps := int(a.distance_to(b) * k * 1.5) + 1
				for j in steps + 1:
					var p := a.lerp(b, float(j) / steps)
					var px := int((p.x + MapDims.HALF) * k)
					var pz := int((p.z + MapDims.HALF) * k)
					for dx in 2:
						for dz in 2:
							if px + dx >= 0 and pz + dz >= 0 and px + dx < n and pz + dz < n:
								img.set_pixel(px + dx, pz + dz, Color(0.55, 0.47, 0.33))
	for st in w.structures:
		if st.gone or st.team >= 0:
			continue
		var col := Color(-1, 0, 0)
		if st.skind in ["house_wall", "tall_wall", "wreck", "rubble", "roof", "floor"]:
			col = Color(0.62, 0.6, 0.54) if st.skind != "floor" else Color(0.5, 0.48, 0.44)
		elif st.skind == "tree":
			col = Color(0.1, 0.17, 0.08)
		if col.r < 0.0:
			continue
		var px2 := int((st.position.x + MapDims.HALF) * k)
		var pz2 := int((st.position.z + MapDims.HALF) * k)
		if px2 >= 0 and pz2 >= 0 and px2 < n - 1 and pz2 < n - 1:
			img.set_pixel(px2, pz2, col)
			img.set_pixel(px2 + 1, pz2, col)
			img.set_pixel(px2, pz2 + 1, col)
			img.set_pixel(px2 + 1, pz2 + 1, col)
	_static = ImageTexture.create_from_image(img)


func _draw() -> void:
	var w := hud.world
	_sig_t -= 1.0 / 15.0
	if _static == null or _sig_t <= 0.0:
		_sig_t = 2.0
		var sig := w.structures.size() * 31
		for t in 3:
			sig = sig * 7 + (w.roads[t] as Array).size()
		if sig != _static_sig or _static == null:
			_static_sig = sig
			_bake_static()
	if _static:
		draw_texture_rect(_static, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.25, 0.15))
	# the same grid the radio calls use (A-H across, 1-8 down)
	var gn := float(MapDims.GRID)
	for i in range(1, MapDims.GRID):
		var gx := size.x * i / gn
		var gy := size.y * i / gn
		draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(1, 1, 1, 0.08), 1.0)
		draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(1, 1, 1, 0.08), 1.0)
	for i in MapDims.GRID:
		UiKit.text(self, Vector2(size.x * (i + 0.5) / gn - 3.0, 10), "ABCDEFGHIJKLMNOP"[i], 9, Color(1, 1, 1, 0.45), 600)
		UiKit.text(self, Vector2(2, size.y * (i + 0.5) / gn + 4.0), str(i + 1), 9, Color(1, 1, 1, 0.45), 600)
	for st in w.structures:
		if not st.visible or st.team < 0:
			continue
		var p := _to_map(st.position)
		var c: Color = Defs.TEAM_COLORS[st.team]
		if st.skind == "fob" or st.skind == "depot":
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), c)
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(0, 0, 0, 0.8), false, 1.0)
		else:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), c.darkened(0.15))
	for s in w.soldiers:
		if not s.visible or s.life == Soldier.Life.HIDDEN or s.life == Soldier.Life.DEAD:
			continue
		var c2: Color = Defs.TEAM_COLORS[s.team].lightened(0.25) if s.team >= 0 else Color.WHITE
		if s.selected:
			c2 = Color(1, 1, 1)
		draw_rect(Rect2(_to_map(s.position) - Vector2(1.2, 1.2), Vector2(2.6, 2.6)), c2)
	for v in w.vehicles:
		if not v.visible or v.team < 0:
			continue
		var vs2: Array = MapSymbols.vehicle_symbol(v.vkind)
		MapSymbols.nato(self, _to_map(v.position), 11.0, v.team == w.local_team or w.local_team < 0, v.team, vs2[0])
	for d in w.drones:
		if d.visible:
			draw_circle(_to_map(d.position), 2.0, Color(1, 1, 0.3))
	var now := w.time
	for pg in w.pings:
		if pg[1] < now:
			continue
		var pp := _to_map(pg[0])
		var r := 4.0 + fmod(now * 2.0, 1.0) * 6.0
		draw_arc(pp, r, 0, TAU, 16, Color(0.5, 0.9, 1.0) if pg[2] == "intel" else Color(1, 0.5, 0.3), 1.5)
	var cam := w.cam
	var vs := get_viewport().get_visible_rect().size
	var corners := [cam.ground_point(Vector2(0, 0)), cam.ground_point(Vector2(vs.x, 0)), cam.ground_point(vs), cam.ground_point(Vector2(0, vs.y))]
	for i in 4:
		draw_line(_to_map(corners[i]), _to_map(corners[(i + 1) % 4]), Color(1, 1, 1, 0.7), 1.0)
