class_name HudMinimap
extends Control
## The minimap. The ground, water, roads, woods and buildings are baked into a
## texture; over it go the fog of war (darker where your side can't see), every
## unit you can see, where the enemy was last seen, where men are fighting, the
## objectives and alerts, aircraft overhead, and the camera's view as a lit
## wedge from where it stands. North is up, or (a setting) the map turns so
## that the way the camera faces is up, as in the view.
## Left-click or drag: look there. Right-click: send the selection there.
## Alt+click: ping the spot for your side; Alt+right-drag: draw on the map for
## them (a route, a line to hold). Wheel: zoom the camera. The other
## commanders on your side show in their colours: their views, cursors and
## selections. The needle in the corner points north as the camera
## sees it; click it to turn back to the starting heading (Backspace).

const N := 512  # the baked map's pixels across (2 m each)
const COMPASS_R := 11.0
## Baked colours (sRGB: this is the interface, not the ground shader).
const C_ROAD_EDGE := Color(0.2, 0.17, 0.12)
const C_ROAD := Color(0.78, 0.7, 0.52)
const C_TRACK := Color(0.6, 0.53, 0.4)
const C_TREE := Color(0.1, 0.17, 0.08)
const C_ROOF := Color(0.8, 0.76, 0.68)
const C_RUIN := Color(0.45, 0.42, 0.37)
const C_WALL := Color(0.64, 0.62, 0.56)
const C_RUBBLE := Color(0.4, 0.38, 0.34)
const C_WRECK := Color(0.28, 0.26, 0.24)
const C_FIGHT := Color(1.0, 0.6, 0.24)
const C_INTEL := Color(1.0, 0.42, 0.36)
const C_RECON := Color(0.5, 0.88, 1.0)

var hud: Hud
var _drag := false
var _base: Image  # the ground and the water: baked once (again when the water arrives)
var _ground: Image  # + the roads (FOBs lay new ones as the battle goes)
var _static: ImageTexture  # + woods and buildings (they burn and fall)
var _road_sig := -1
var _static_sig := -1
var _sig_t := 0.0
var _hover := Vector2(-1, -1)
var _xf := Transform2D.IDENTITY  # map pixels -> the control (turning with the camera when set to)
var _fight := {}  # grid cell -> where men are firing in it, rebuilt each redraw
var sketch := PackedVector3Array()  # a line being drawn on the minimap (Alt+right-drag)
var _sk_last := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP


## Bakes the map again: the buildings and roads, or (all) the ground and water too.
func rebake(all := false) -> void:
	if all:
		_base = null
		_ground = null
	_static = null


# --- input --------------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	var w := hud.world
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.alt_pressed and _on_map(mb.position) and w.coop:
			# Alt+click pings the spot for your side (an enemy in sight there: "enemy spotted")
			var gp := _to_world(mb.position)
			var e := _enemy_near(gp, 7.0 * MapDims.SIZE / maxf(1.0, size.x))
			w.coop.ping("enemy" if e else "look", Defs.flat(e.position) if e else gp, e.eid if e else 0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _on_compass(mb.position):
				if w.cam:
					w.cam.reset_view()
				Sfx.ui("click")
			else:
				_drag = mb.pressed
				if mb.pressed:
					_look(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and mb.alt_pressed and _on_map(mb.position):
			# Alt+right-drag draws on the map for your side
			sketch = PackedVector3Array([_to_world(mb.position)])
			_sk_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and not sketch.is_empty():
			if sketch.size() >= 2 and w.coop:
				w.coop.sketch(PlayerInput.thin_line(sketch, CoCommand.SKETCH_PTS))
			sketch = PackedVector3Array()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _on_map(mb.position):
				w.input.order_at(_to_world(mb.position))
		elif mb.pressed and w.cam and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			w.cam.zoom_step(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		_hover = mm.position
		if not sketch.is_empty() and mm.position.distance_to(_sk_last) > 3.0 and sketch.size() < 256:
			sketch.append(_to_world(mm.position))
			_sk_last = mm.position
		var rk := Keys.label("cam_reset")
		tooltip_text = ("Compass: north as the camera sees it.\nClick%s to turn back to the starting heading." % ((" (or %s)" % rk) if rk != "" else "")) if _on_compass(mm.position) else ""
		if _drag:
			_look(mm.position)
	elif ev is InputEventMagnifyGesture and w.cam:
		# on a trackpad, a pinch over the map zooms the view, and so do two fingers, as the wheel does
		w.cam.pinch((ev as InputEventMagnifyGesture).factor)
		accept_event()
	elif ev is InputEventPanGesture and w.cam:
		w.cam.scroll_zoom((ev as InputEventPanGesture).delta.y)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2(-1, -1)


## The enemy in sight nearest a spot, within r metres (null if none).
func _enemy_near(p: Vector3, r: float) -> Entity:
	var w := hud.world
	var best: Entity = null
	var bd := r
	for arr in [w.soldiers, w.vehicles]:
		for e in arr:
			if e.gone or not e.visible or not e.is_hostile_to(w.local_team) or not e.seen_by_local():
				continue
			if e is Soldier and (e.life == Soldier.Life.DEAD or e.life == Soldier.Life.HIDDEN):
				continue
			var d := Defs.flat(e.position - p).length()
			if d < bd:
				bd = d
				best = e
	return best


func _look(p: Vector2) -> void:
	var w := hud.world
	if w.cam == null:
		return
	w.cam.stop_follow()
	w.cam.stop_shadow()
	w.cam.focus(_to_world(p))
	if w.director:
		w.director.active = false


func _compass_c() -> Vector2:
	return size - Vector2(COMPASS_R + 5.0, COMPASS_R + 5.0)


func _on_compass(p: Vector2) -> bool:
	return p.distance_to(_compass_c()) <= COMPASS_R + 2.0


func _on_map(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_xf.affine_inverse() * p)


# --- coordinates --------------------------------------------------------------------------

## A point on the control -> the ground.
func _to_world(p: Vector2) -> Vector3:
	var m := _xf.affine_inverse() * p
	return Vector3(clampf(m.x / size.x, 0.0, 1.0) * MapDims.SIZE - MapDims.HALF, 0, clampf(m.y / size.y, 0.0, 1.0) * MapDims.SIZE - MapDims.HALF)


## The ground -> the unturned map.
func _to_map(p: Vector3) -> Vector2:
	return Vector2((p.x + MapDims.HALF) / MapDims.SIZE * size.x, (p.z + MapDims.HALF) / MapDims.SIZE * size.y)


## The ground -> the control.
func _pt(p: Vector3) -> Vector2:
	return _xf * _to_map(p)


func _update_xf() -> void:
	var cam: RtsCamera = hud.world.cam
	if cam and bool(Settings.get_v("minimap_rotate")):
		# turn about the middle so the camera's heading points up the map
		var c := size * 0.5
		_xf = Transform2D(cam.yaw, c) * Transform2D(0.0, -c)
	else:
		_xf = Transform2D.IDENTITY


# --- baking -------------------------------------------------------------------------------

## The ground (from the same noise the ground shader uses) and the water.
func _make_base() -> void:
	var w := hud.world
	var at: Atmosphere = w.atmo
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
			var c := Color(0.37, 0.32, 0.23).lerp(Color(0.25, 0.34, 0.16), g)
			c = c.lerp(Color(0.34, 0.34, 0.21), clampf((b - 0.45) * 2.0, 0.0, 0.35) * g)
			img.set_pixel(x, y, c.darkened(0.1))
	img.resize(N, N, Image.INTERPOLATE_BILINEAR)
	if w.water and w.water.mask:
		# the sea, the river and the ponds; sand and mud along their shores
		var wm: Image = w.water.mask.duplicate()
		wm.resize(N, N, Image.INTERPOLATE_BILINEAR)
		for y in N:
			for x in N:
				var c := wm.get_pixel(x, y)
				if c.a > 0.5:
					img.set_pixel(x, y, Color(0.12, 0.2, 0.22).lerp(Color(0.05, 0.11, 0.16), c.r).lerp(Color(0.1, 0.22, 0.27), c.b * 0.5))
				elif c.g > 0.3:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.5, 0.45, 0.32) if c.b > 0.5 else Color(0.3, 0.26, 0.18), 0.6))
	_base = img


## The roads over the ground: the main roads light with a dark edge so they
## read against fields and woods, the supply tracks thinner.
func _make_ground() -> void:
	var w := hud.world
	if _base == null:
		_make_base()
	if _base == null:
		return
	var img: Image = _base.duplicate()
	var k := N / MapDims.SIZE  # pixels per metre
	for pass_i in 2:
		for t in 3:
			var main := t == 2
			if pass_i == 0 and not main:
				continue
			# a main road: a 5 px dark edge, then a 3 px light middle; a supply track 2 px
			var half := (2 if pass_i == 0 else 1) if main else 0
			var wd := half * 2 + 1 if main else 2
			var col := C_ROAD_EDGE if pass_i == 0 else (C_ROAD if main else C_TRACK)
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
						img.fill_rect(Rect2i(px - half, pz - half, wd, wd), col)
	_ground = img


## Woods, then houses: each house's floor as its footprint, light where the
## roof still stands and dark where it is a ruin; walls round yards and
## compounds as lines.
func _bake_static() -> void:
	var w := hud.world
	if _ground == null:
		_make_ground()
	if _ground == null:
		return
	var t0 := Time.get_ticks_usec()
	var img: Image = _ground.duplicate()
	var k := N / MapDims.SIZE
	var roofs := {}
	for st in w.structures:
		if not st.gone and st.team < 0 and st.skind == "roof":
			roofs[Vector2i(roundi(st.position.x), roundi(st.position.z))] = true
	for pass_i in 2:
		for st in w.structures:
			if st.gone or st.team >= 0:
				continue
			var px := int((st.position.x + MapDims.HALF) * k)
			var pz := int((st.position.z + MapDims.HALF) * k)
			# woods and debris first, the buildings over them
			if pass_i == 0:
				match st.skind:
					"tree":
						img.fill_rect(Rect2i(px, pz, 2, 2), C_TREE)
					"rubble":
						img.fill_rect(Rect2i(px, pz, 2, 2), C_RUBBLE)
					"wreck":
						img.fill_rect(Rect2i(px, pz, 2, 2), C_WRECK)
					"bridge":
						_stamp(img, st.position, st.foot, st.yaw, C_ROAD, k)
				continue
			match st.skind:
				"floor":
					var standing := roofs.has(Vector2i(roundi(st.position.x), roundi(st.position.z)))
					_stamp(img, st.position, st.foot, st.yaw, C_ROOF if standing else C_RUIN, k)
				"tall_wall":
					# at least a pixel thick, so a wall shows as a line rather than vanishing
					_stamp(img, st.position, Vector2(maxf(st.foot.x, 0.6 / k), maxf(st.foot.y, 0.6 / k)), st.yaw, C_WALL, k)
	img.generate_mipmaps()
	_static = ImageTexture.create_from_image(img)
	if OS.has_environment("FL_DEBUG_MINIMAP"):
		print("minimap: baked %d structures (%d roofs) in %.1f ms" % [w.structures.size(), roofs.size(), (Time.get_ticks_usec() - t0) / 1000.0])


## Fills a turned rectangle (centre, half extents in metres, heading) on the
## baked map, a row at a time: on each row the inside is one span, where the
## row crosses both pairs of the rectangle's sides.
func _stamp(img: Image, c: Vector3, h: Vector2, yaw: float, col: Color, k: float) -> void:
	var ax := Vector2(cos(yaw), -sin(yaw))  # the structure's own x along the ground
	var az := Vector2(sin(yaw), cos(yaw))  # and its z
	var r := h.length() * k + 1.0
	var cx := (c.x + MapDims.HALF) * k
	var cz := (c.z + MapDims.HALF) * k
	for y in range(maxi(0, int(cz - r)), mini(N - 1, int(cz + r)) + 1):
		var dz := (y + 0.5 - cz) / k
		var lo := -INF
		var hi := INF
		for q in 2:
			var a := ax.x if q == 0 else az.x
			var b := dz * (ax.y if q == 0 else az.y)
			var hh := h.x if q == 0 else h.y
			if absf(a) < 0.0001:
				if absf(b) > hh:
					hi = -INF
				continue
			var e0 := (-hh - b) / a
			var e1 := (hh - b) / a
			lo = maxf(lo, minf(e0, e1))
			hi = minf(hi, maxf(e0, e1))
		if lo > hi:
			continue
		var x0 := maxi(0, ceili(cx + lo * k - 0.5))
		var x1 := mini(N - 1, floori(cx + hi * k - 0.5))
		if x1 >= x0:
			img.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), col)


## Rebakes what has changed: the roads, or the buildings. Trees knocked down,
## rubble and wrecks don't trigger it on their own (they catch up with the
## next one), so a tank in a wood doesn't keep the map rebaking.
func _check_bake() -> void:
	var w := hud.world
	_sig_t -= 1.0 / 15.0
	if _static != null and _sig_t > 0.0:
		return
	_sig_t = 2.0
	var rs := 0
	for t in 3:
		rs = rs * 7919 + (w.roads[t] as Array).size()
	if rs != _road_sig:
		_road_sig = rs
		_ground = null
		_static = null
	var drawn := 0
	var roofs := 0
	for st in w.structures:
		if st.gone or st.team >= 0:
			continue
		match st.skind:
			"roof":
				roofs += 1
			"floor", "bridge", "tall_wall":
				drawn += 1
	var sig := drawn * 7919 + roofs
	if sig != _static_sig:
		_static_sig = sig
		_static = null
	if _static == null:
		_bake_static()


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	var w := hud.world
	_check_bake()
	_update_xf()
	# the backdrop shows round the edges when the map turns
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.075, 0.08))
	if _static:
		draw_set_transform_matrix(_xf)
		draw_texture_rect(_static, Rect2(Vector2.ZERO, size), false)
		if w.fog and w.fog.active:
			# the fog of war: darker wherever your side can't see right now
			draw_texture_rect_region(w.fog.dark_tex, Rect2(Vector2.ZERO, size), w.fog.map_region(), Color(1, 1, 1, 0.55))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_grid()
	var sc := clampf(size.x / 240.0, 0.85, 1.35)
	_draw_objectives(w)
	_draw_structures(w, sc)
	if hud.map_layer("intel"):
		_draw_intel(w, sc)
	_draw_fighting(w, sc)
	_draw_units(w, sc)
	_draw_aircraft(w, sc)
	_draw_pings(w)
	_draw_coop(w, sc)
	_draw_view(w)
	_draw_compass(w)
	_draw_hover()


## The same grid the radio calls use (A-H across, 1-8 down), labelled along
## the map's own top and left edges so the labels go round with it.
func _draw_grid() -> void:
	var gn := MapDims.GRID
	var gc := Color(1, 1, 1, 0.08)
	for i in range(1, gn):
		var f := float(i) / gn
		draw_line(_xf * Vector2(size.x * f, 0), _xf * Vector2(size.x * f, size.y), gc, 1.0)
		draw_line(_xf * Vector2(0, size.y * f), _xf * Vector2(size.x, size.y * f), gc, 1.0)
	var fs := 10 if size.x >= 240.0 else 9
	var lc := Color(1, 1, 1, 0.55)
	for i in gn:
		var f := (i + 0.5) / gn
		_label(_xf * Vector2(size.x * f, 7.0), "ABCDEFGHIJKLMNOP"[i], fs, lc)
		_label(_xf * Vector2(7.0, size.y * f), str(i + 1), fs, lc)


## A grid letter or number centred on a point, in mono (docs/UI.md, Two voices).
func _label(c: Vector2, s: String, fs: int, col: Color) -> void:
	UiKit.mono_at(self, c + Vector2(-UiKit.mono_w(s, fs) * 0.5, fs * 0.36), s, fs, col)


## A mission's objectives, by their letters.
func _draw_objectives(w: World) -> void:
	if w.mission_info.is_empty():
		return
	for o in w.mission_info.get("objs", []):
		if int(o[2]) != MissionDirector.ACTIVE or o[4] == null:
			continue
		var op := _pt(o[4])
		var orad := float(o[5]) * size.x / MapDims.SIZE
		if orad > 3.0:
			draw_circle(op, orad, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.08))
			draw_arc(op, orad, 0, TAU, 32, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.6), 1.0, true)
		HudObjectives.diamond(self, op, 7.0, String(o[0]), UiKit.ACCENT, 1.0)


## What the sides have built: FOBs and depots as squares, the rest as small
## marks; and the towns, whoever holds them.
func _draw_structures(w: World, sc: float) -> void:
	for st in w.sim_structures:
		if st.skind == "town" and st.team < 0 and not st.gone:
			_draw_town(st, sc)
	for st in w.owned_structures:
		if st.gone:
			continue
		if st.skind == "town":
			_draw_town(st, sc)
			continue
		if not st.visible or st.team < 0:
			continue
		var p := _pt(st.position)
		var c: Color = Defs.TEAM_COLORS[st.team]
		if st.skind == "fob" or st.skind == "depot":
			var hs := 5.5 * sc
			draw_rect(Rect2(p - Vector2(hs + 1.0, hs + 1.0), Vector2(hs * 2.0 + 2.0, hs * 2.0 + 2.0)), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(p - Vector2(hs, hs), Vector2(hs * 2.0, hs * 2.0)), c)
			if st.skind == "fob":
				draw_rect(Rect2(p - Vector2(hs * 0.4, hs * 0.4), Vector2(hs * 0.8, hs * 0.8)), Color(0, 0, 0, 0.55))
		else:
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(c.r, c.g, c.b, 0.7).darkened(0.2))


## A town or village: its ground as a faint ring in its holder's colour (the
## town's own while nobody holds it), the flag on its dump, and how far
## whoever is taking it has got, round the ring.
func _draw_town(st: Structure, sc: float) -> void:
	var c := _pt(st.zone_c if st.zone_c != Vector3.INF else st.position)
	var r := maxf(3.0, st.zone_r * size.x / MapDims.SIZE)
	var col: Color = Defs.TEAM_COLORS[st.team] if st.team >= 0 else Structure.C_TOWN_FLAG
	draw_circle(c, r, Color(col.r, col.g, col.b, 0.1))
	draw_arc(c, r, 0, TAU, 28, Color(col.r, col.g, col.b, 0.55), 1.0, true)
	if st.cap_team >= 0 and st.cap_prog > 0.0:
		draw_arc(c, r + 1.6, -PI * 0.5, -PI * 0.5 + TAU * st.cap_prog / 100.0, 28, Defs.TEAM_COLORS[st.cap_team], 2.2, true)
	var p := _pt(st.position)
	var h := (8.0 if st.variant == 1 else 6.5) * sc
	draw_line(p + Vector2(0, h * 0.35), p - Vector2(0, h), Color(0, 0, 0, 0.8), 2.6)
	draw_line(p + Vector2(0, h * 0.35), p - Vector2(0, h), Color(0.92, 0.92, 0.88), 1.2)
	var fr := Rect2(p + Vector2(0.6, -h), Vector2(h * 0.85, h * 0.55))
	draw_rect(fr.grow(0.8), Color(0, 0, 0, 0.8))
	draw_rect(fr, col)


## Where men are firing: a ring pulses over each patch of the fight, so a
## glance at the map shows where the battle is.
func _draw_fighting(w: World, sc: float) -> void:
	_fight.clear()
	for s in w.soldiers:
		if not s.visible or s.life != Soldier.Life.ALIVE or (s.flags & Soldier.F_SHOOTING) == 0:
			continue
		var key := int((s.position.x + MapDims.HALF) / 24.0) * 64 + int((s.position.z + MapDims.HALF) / 24.0)
		if not _fight.has(key):
			_fight[key] = s.position
	var ph := fmod(Time.get_ticks_msec() / 1000.0 * 1.4, 1.0)
	for key in _fight:
		var p := _pt(_fight[key])
		draw_arc(p, (3.5 + ph * 5.0) * sc, 0, TAU, 14, Color(C_FIGHT.r, C_FIGHT.g, C_FIGHT.b, 0.85 * (1.0 - ph)), 1.6, true)
		draw_circle(p, 1.6 * sc, Color(C_FIGHT.r, C_FIGHT.g, C_FIGHT.b, 0.5))


## Every man you can see as a dot with a dark edge (allies brightest, the
## selected white), vehicles by their map symbols, drones as yellow points.
func _draw_units(w: World, sc: float) -> void:
	var r := 1.3 * sc
	var edge := Color(0, 0, 0, 0.65)
	for s in w.soldiers:
		if not s.visible or s.life == Soldier.Life.HIDDEN or s.life == Soldier.Life.DEAD:
			continue
		var c: Color
		var rr := r
		if s.selected:
			c = Color(1, 1, 1)
			rr = r * 1.3
		elif s.team < 0:
			c = Color(0.9, 0.9, 0.85)
		elif s.team == w.local_team:
			c = Defs.TEAM_COLORS[s.team].lightened(0.4)
		else:
			c = Defs.TEAM_COLORS[s.team].lightened(0.12)
		if s.life == Soldier.Life.DOWNED:
			c.a = 0.55
		var p := _pt(s.position)
		draw_rect(Rect2(p - Vector2(rr + 0.9, rr + 0.9), Vector2(rr * 2.0 + 1.8, rr * 2.0 + 1.8)), edge)
		draw_rect(Rect2(p - Vector2(rr, rr), Vector2(rr * 2.0, rr * 2.0)), c)
	for v in w.vehicles:
		if not v.visible or v.team < 0:
			continue
		var vs2: Array = MapSymbols.vehicle_symbol(v.vkind)
		var vp := _pt(v.position)
		if v.selected:
			draw_arc(vp, 8.5 * sc, 0, TAU, 20, Color(1, 1, 1, 0.9), 1.4, true)
		MapSymbols.nato(self, vp, 11.0 * sc, v.team == w.local_team or w.local_team < 0, v.team, vs2[0])
	for d in w.drones:
		if d.visible:
			draw_circle(_pt(d.position), 2.0, Color(1, 1, 0.3))


## Where the enemy was last seen (by your men, towers, drones or a recon
## flight), fading with age: a hollow red diamond, larger for vehicles.
func _draw_intel(w: World, sc: float) -> void:
	var t := w.view_team
	if t < 0 or t >= w.team_info.size():
		return
	for it in (w.team_info[t] as Dictionary).get("intel", []):
		var age := float(it[2])
		if age < 3.0:
			continue  # in sight: drawn as a unit
		var a := clampf(1.0 - age / 90.0, 0.25, 0.85)
		var p := _pt(it[0])
		var hs := (2.6 if String(it[1]) == "inf" else 3.6) * sc
		var d := PackedVector2Array([p + Vector2(0, -hs), p + Vector2(hs, 0), p + Vector2(0, hs), p + Vector2(-hs, 0), p + Vector2(0, -hs)])
		draw_polyline(d, Color(0, 0, 0, 0.55 * a), 2.6, true)
		draw_polyline(d, Color(C_INTEL.r, C_INTEL.g, C_INTEL.b, a), 1.2, true)


## Aircraft over the battlefield (you hear and see them, whoever's they are): a
## small arrowhead in the side's colour along its heading, and round your own
## the ground its camera or crew can see.
func _draw_aircraft(w: World, sc: float) -> void:
	for p in w.projectiles:
		if p.gone or not p.ptype in ["jet", "a10", "ac130"] or not Defs.in_map(p.position, -60.0):
			continue
		var pp := _pt(p.position)
		var c: Color = Defs.TEAM_COLORS[p.team].lightened(0.3) if p.team >= 0 else Color(0.9, 0.9, 0.85)
		if p.team >= 0 and p.team == w.view_team:
			var eyes := PackedVector3Array()
			p.add_eyes(eyes)
			for e in eyes:
				draw_arc(_pt(Vector3(e.x, 0, e.y)), e.z * size.x / MapDims.SIZE, 0, TAU, 28, Color(C_RECON.r, C_RECON.g, C_RECON.b, 0.45), 1.0, true)
		var fw3: Vector3 = p.heading()
		var fw := (_pt(p.position + fw3) - pp).normalized() if fw3.length() > 0.1 else Vector2(0, -1)
		var sd := Vector2(-fw.y, fw.x)
		var s := 4.5 * sc
		var tri := PackedVector2Array([pp + fw * s, pp - fw * s * 0.6 + sd * s * 0.75, pp - fw * s * 0.25, pp - fw * s * 0.6 - sd * s * 0.75])
		MapSymbols.poly(self, tri, Color(0, 0, 0, 0.6))
		var tri2 := PackedVector2Array()
		for q in tri:
			tri2.append(pp + (q - pp) * 0.72)
		MapSymbols.poly(self, tri2, c)


## Alerts and intelligence reports, pulsing until they expire.
func _draw_pings(w: World) -> void:
	var now := w.time
	for pg in w.pings:
		if pg[1] < now:
			continue
		var pp := _pt(pg[0])
		var r := 4.0 + fmod(now * 2.0, 1.0) * 6.0
		draw_arc(pp, r, 0, TAU, 16, Color(0.5, 0.9, 1.0) if pg[2] == "intel" else Color(1, 0.5, 0.3), 1.5, true)


## The other commanders on our side: each one's view as a wedge in his colour
## (yours is the white one) with his initials at his camera, his cursor, a ring
## round each unit he has selected - and everyone's pings.
func _draw_coop(w: World, sc: float) -> void:
	var co := w.coop
	if co == null:
		return
	if bool(Settings.get_v("coop_show")):
		var groups: Dictionary = hud.overlay._groups
		for p in co.list():
			var col := co.color(p.peer)
			var a := 1.0 if p.idle < 45 else 0.5
			if p.s_quad.size() == 4:
				var pts := PackedVector2Array()
				for q in p.s_quad:
					pts.append(_pt(q))
				var eye := _pt(p.eye())
				draw_line(eye, pts[3], Color(col.r, col.g, col.b, 0.32 * a), 1.0, true)
				draw_line(eye, pts[2], Color(col.r, col.g, col.b, 0.32 * a), 1.0, true)
				if absf((pts[2] - pts[0]).cross(pts[3] - pts[1])) > 8.0:
					draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.09 * a))
				pts.append(pts[0])
				draw_polyline(pts, Color(col.r, col.g, col.b, 0.9 * a), 1.4, true)
				draw_rect(Rect2(eye - Vector2(5.5, 5.5) * sc, Vector2(11, 11) * sc), Color(0, 0, 0, 0.6 * a))
				draw_rect(Rect2(eye - Vector2(4.6, 4.6) * sc, Vector2(9.2, 9.2) * sc), Color(col.r, col.g, col.b, a))
				var ini := co.initials(p.peer).substr(0, 1)
				var fs := 8 if sc < 1.1 else 9
				draw_string(UiKit.mono(500), eye + Vector2(-UiKit.mono_w(ini, fs) * 0.5, fs * 0.36), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, HudCoop.INK)
			for sid in p.sq:
				var g: Dictionary = groups.get(sid, {})
				if not g.is_empty() and int(g["n"]) > 0:
					draw_arc(_pt(g["c"]), 4.8 * sc, 0.0, TAU, 16, Color(col.r, col.g, col.b, 0.95), 1.4, true)
			for id in p.veh:
				var v = w.entity(id)
				if v is Vehicle and v.visible:
					draw_arc(_pt(v.position), 8.5 * sc, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.95), 1.4, true)
			if p.cur_on:
				var cp := _pt(p.s_cur)
				var arrow := PackedVector2Array([cp, cp + Vector2(0, 9) * sc, cp + Vector2(2.5, 7) * sc, cp + Vector2(6.5, 6.5) * sc])
				MapSymbols.poly(self, arrow, Color(col.r, col.g, col.b, a))
				arrow.append(arrow[0])
				draw_polyline(arrow, Color(0, 0, 0, 0.7 * a), 1.0, true)
	var now := Time.get_ticks_msec()
	for pg in co.pings:
		var age := (now - int(pg.born)) / 1000.0
		var fade := clampf((float(pg.life) - age) / 1.5, 0.0, 1.0)
		var pp := _pt(co.ping_pos(pg))
		var col: Color = co.color(pg.peer)
		var mark: Color = CoCommand.PING_COLORS.get(pg.kind, Color(0.96, 0.97, 0.94))
		var ph := fmod(age * 1.6, 1.0)
		draw_arc(pp, (3.0 + ph * 8.0) * sc, 0.0, TAU, 18, Color(col.r, col.g, col.b, (1.0 - ph) * fade), 1.8, true)
		draw_circle(pp, 3.4 * sc, Color(0, 0, 0, 0.7 * fade))
		draw_circle(pp, 2.5 * sc, Color(mark.r, mark.g, mark.b, fade))
	# lines drawn for the side, and the one being drawn now
	for sk in co.sketches:
		var sage := (now - int(sk.born)) / 1000.0
		var grow := 1.0 if sk.peer == w.local_peer else clampf(sage / 0.6, 0.0, 1.0)
		_sketch_line(sk.pts, co.color(sk.peer), clampf((CoCommand.SKETCH_LIFE - sage) / 2.5, 0.0, 1.0), grow)
	if sketch.size() >= 2:
		_sketch_line(sketch, co.color(w.local_peer), 0.9, 1.0)
	if w.input and w.input.sketching:
		_sketch_line(w.input.sketch_pts, co.color(w.local_peer), 0.9, 1.0)


## A drawn line on the map, with an arrowhead where it ends.
func _sketch_line(pts: PackedVector3Array, col: Color, a: float, grow: float) -> void:
	if pts.size() < 2 or a <= 0.01:
		return
	var sp := PackedVector2Array()
	for i in mini(pts.size(), maxi(2, ceili(pts.size() * grow))):
		sp.append(_pt(pts[i]))
	draw_polyline(sp, Color(0, 0, 0, 0.6 * a), 3.6, true)
	draw_polyline(sp, Color(col.r, col.g, col.b, a), 1.9, true)
	var tip := sp[sp.size() - 1]
	var back := sp[maxi(0, sp.size() - 3)]
	if grow >= 1.0 and tip.distance_to(back) > 2.0:
		var dv := (tip - back).normalized()
		var nv := Vector2(-dv.y, dv.x)
		MapSymbols.poly(self, PackedVector2Array([tip + dv * 4.5, tip - dv * 2.5 + nv * 3.8, tip - dv * 2.5 - nv * 3.8]), Color(col.r, col.g, col.b, a))


## What the camera sees: the patch of ground on screen, lit, and faint lines
## back to where the camera stands, so you can tell which way it looks.
func _draw_view(w: World) -> void:
	var cam := w.cam
	if cam == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var pts := PackedVector2Array()
	for sp in [Vector2(0, 0), Vector2(vs.x, 0), vs, Vector2(0, vs.y)]:
		pts.append(_pt(cam.ground_point(sp)))
	var eye := _pt(cam.cam.global_position)
	draw_line(eye, pts[3], Color(1, 1, 1, 0.3), 1.0, true)
	draw_line(eye, pts[2], Color(1, 1, 1, 0.3), 1.0, true)
	# a quad seen edge-on (a window shrunk to nothing) won't triangulate
	var area := (pts[2] - pts[0]).cross(pts[3] - pts[1])
	if absf(area) > 8.0:
		draw_colored_polygon(pts, Color(1, 1, 1, 0.1))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.85), 1.4, true)
	draw_circle(eye, 2.4, Color(1, 1, 1, 0.95))
	draw_circle(_pt(cam.focus_pos), 1.5, Color(1, 1, 1, 0.7))


## North as the camera sees it: straight up when it looks north, turning as
## it turns (and with the map, when the map turns).
func _draw_compass(w: World) -> void:
	var c := _compass_c()
	var hot := _hover.x >= 0.0 and _on_compass(_hover)
	draw_circle(c, COMPASS_R, UiKit.fa(UiKit.INK, 0.82))
	draw_arc(c, COMPASS_R, 0, TAU, 28, UiKit.ACCENT if hot else UiKit.RULE2, 1.0, true)
	var yaw: float = w.cam.yaw if w.cam else 0.0
	var n := Vector2(sin(yaw), -cos(yaw))
	var side := Vector2(-n.y, n.x) * 3.2
	var tip := c + n * (COMPASS_R - 2.5)
	var tail := c - n * (COMPASS_R - 2.5)
	draw_colored_polygon(PackedVector2Array([tip, c + side, c - side]), Color(0.95, 0.32, 0.26))
	draw_colored_polygon(PackedVector2Array([tail, c - side, c + side]), Color(0.86, 0.86, 0.8))


## The grid square under the cursor, beside it.
func _draw_hover() -> void:
	if _hover.x < 0.0 or _on_compass(_hover) or not _on_map(_hover):
		return
	var g := Defs.grid_ref(_to_world(_hover))
	var p := _hover + Vector2(10, -6)
	p.x = minf(p.x, size.x - UiKit.mono_w(g, 12) - 4.0)
	p.y = maxf(p.y, 14.0)
	UiKit.mono_at(self, p, g, 12, UiKit.TEXT)
