class_name MapSymbols
extends RefCounted
## Map symbols and icons shared by the HUD widgets: NATO unit symbols, status
## glyphs, guarded polygons and word wrap.

## The icon over a soldier for each Soldier.DOING state ("" = nothing worth an icon).
const DOING_GLYPH := ["", "", "", "fire", "supp", "pinned", "reload", "grenade", "cover",
	"medic", "drag", "medic", "build", "gun", "retreat", "ammo", "eye",
	"wounded", "wounded", "flag", "flag", "wounded", "", "drone", "melee",
	"noammo", "fire", "wounded", "dazed", "fire", "", "grenade", "supp",
	"fire", "supp", "chat", "chat", "smoke", "", "", "", "eye"]
## The badge next to a squad's symbol for its orders (holding: none), and its colour.
const ORDER_GLYPH := {"move": "move", "assault": "assault", "defend": "defend", "retreat": "retreat", "attack": "fire", "build": "build", "tunnel": "tunnel"}
const ORDER_COLORS := {"assault": Color(1.0, 0.56, 0.44), "attack": Color(1.0, 0.5, 0.4), "defend": Color(0.55, 0.85, 1.0), "retreat": Color(1.0, 0.8, 0.4), "build": Color(1.0, 0.84, 0.45)}


# --- NATO (APP-6) unit symbols ----------------------------------------------------------

## Draws a unit symbol centred on c: friendly = rectangle, hostile = diamond,
## the glyph inside says what it is (X infantry, oval armour, both mechanised,
## bow-tie rotary wing), a short tag above for teams (MG, AT, MORT, ENG).
static func nato(ci: CanvasItem, c: Vector2, w: float, friendly: bool, team: int, glyph: String, tag := "", alpha := 1.0) -> void:
	var col: Color = Defs.TEAM_COLORS[team] if team >= 0 else Color(0.8, 0.8, 0.8)
	var fill := Color(col.r, col.g, col.b, 0.82 * alpha)
	var ink := Color(0.02, 0.03, 0.03, 0.95 * alpha)
	var hw := w * 0.5
	var hh := w * 0.34
	var box := Rect2(c - Vector2(hw, hh), Vector2(w, hh * 2.0))
	if friendly:
		ci.draw_rect(box, fill)
		ci.draw_rect(box, ink, false, 1.5)
	else:
		var d := PackedVector2Array([c + Vector2(0, -hw * 0.8), c + Vector2(hw * 0.8, 0), c + Vector2(0, hw * 0.8), c + Vector2(-hw * 0.8, 0), c + Vector2(0, -hw * 0.8)])
		MapSymbols.poly(ci, d, fill)
		ci.draw_polyline(d, ink, 1.5, true)
		box = Rect2(c - Vector2(hw * 0.42, hh * 0.62), Vector2(hw * 0.84, hh * 1.24))
	var lw := 1.4
	if glyph in ["inf", "mech"]:
		ci.draw_line(box.position, box.end, ink, lw, true)
		ci.draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), ink, lw, true)
	if glyph in ["armor", "mech", "motor"]:
		var ow := box.size.x * 0.62
		var oh := box.size.y * 0.5
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(c + Vector2(cos(a) * ow * 0.5, sin(a) * oh * 0.5))
		ci.draw_polyline(pts, ink, lw, true)
	if glyph == "motor":
		ci.draw_line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), ink, lw, true)
	if glyph == "air":
		MapSymbols.poly(ci, PackedVector2Array([c, c + Vector2(-box.size.x * 0.35, -box.size.y * 0.3), c + Vector2(-box.size.x * 0.35, box.size.y * 0.3)]), ink)
		MapSymbols.poly(ci, PackedVector2Array([c, c + Vector2(box.size.x * 0.35, -box.size.y * 0.3), c + Vector2(box.size.x * 0.35, box.size.y * 0.3)]), ink)
	if tag != "":
		UiKit.text(ci, c + Vector2(-UiKit.text_width(tag, 9, 600) * 0.5, -hh - 3.0), tag, 9, Color(1, 1, 1, 0.9 * alpha), 600)


## Symbol and tag for a group of soldiers (one squad), from who's in it.
static func squad_symbol(mem: Array) -> Array:
	var types := {}
	for s in mem:
		types[s.utype] = true
	if types.has("mortar_gunner") or types.has("r_mortar"):
		return ["inf", "MORT"]
	if types.has("engineer") or types.has("digger"):
		return ["inf", "ENG"]
	if (types.has("at_soldier") or types.has("rpg")) and mem.size() <= 2:
		return ["inf", "AT"]
	if (types.has("mg_gunner") or types.has("pkm")) and mem.size() <= 2:
		return ["inf", "MG"]
	if types.has("fpv_op"):
		return ["inf", "UAS"]
	return ["inf", ""]


static func vehicle_symbol(vk: String) -> Array:
	match vk:
		"tank", "old_tank":
			return ["armor", ""]
		"ifv", "btr":
			return ["mech", ""]
		"humvee", "technical":
			return ["motor", ""]
		"aa_tech":
			return ["motor", "AA"]
		"heli", "gunship":
			return ["air", ""]
		"truck":
			return ["motor", "LOG"]
	return ["motor", ""]


## A small status icon, by default on a round dark badge.
static func glyph(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color, a := 1.0, badge := true) -> void:
	if a <= 0.01:
		return
	if badge:
		ci.draw_circle(c, r + 1.5, Color(0, 0, 0, 0.5 * a))
		ci.draw_circle(c, r, Color(0.05, 0.06, 0.05, 0.86 * a))
		ci.draw_arc(c, r, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.7 * a), 1.2, true)
	var k := Color(col.r, col.g, col.b, a)
	var s := r * (0.62 if badge else 0.92)
	var lw := maxf(1.3, r * 0.17)
	match kind:
		"fire":
			ci.draw_arc(c, s * 0.55, 0.0, TAU, 16, k, lw, true)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				ci.draw_line(c + d * s * 0.3, c + d * s * 1.0, k, lw, true)
		"supp", "pinned":
			var n := 2 if kind == "supp" else 3
			for i in n:
				var y := c.y - s * 0.7 + i * s * (1.3 / n)
				ci.draw_polyline(PackedVector2Array([Vector2(c.x - s * 0.75, y), Vector2(c.x, y + s * 0.5), Vector2(c.x + s * 0.75, y)]), k, lw, true)
		"reload", "noammo":
			var mag := PackedVector2Array([c + Vector2(-0.45, -0.85) * s, c + Vector2(0.2, -0.85) * s, c + Vector2(0.5, 0.8) * s, c + Vector2(-0.15, 0.9) * s])
			if kind == "reload":
				MapSymbols.poly(ci, mag, k)
			else:
				mag.append(mag[0])
				ci.draw_polyline(mag, k, lw, true)
				ci.draw_line(c + Vector2(-0.9, 0.9) * s, c + Vector2(0.9, -0.9) * s, k, lw, true)
		"ammo":
			for i in 3:
				var x := c.x + (i - 1) * s * 0.6
				ci.draw_rect(Rect2(x - s * 0.18, c.y - s * 0.45, s * 0.36, s * 1.2), k)
				ci.draw_circle(Vector2(x, c.y - s * 0.45), s * 0.18, k)
		"grenade":
			ci.draw_circle(c + Vector2(0, s * 0.2), s * 0.6, k)
			ci.draw_rect(Rect2(c + Vector2(-0.22, -0.85) * s, Vector2(0.44, 0.45) * s), k)
			ci.draw_line(c + Vector2(0.2, -0.7) * s, c + Vector2(0.75, -0.25) * s, k, lw, true)
		"medic", "wounded":
			var t := s * 0.3
			ci.draw_rect(Rect2(c - Vector2(t, s * 0.85), Vector2(t * 2.0, s * 1.7)), k)
			ci.draw_rect(Rect2(c - Vector2(s * 0.85, t), Vector2(s * 1.7, t * 2.0)), k)
		"drag":
			ci.draw_rect(Rect2(c + Vector2(-0.75, -0.5) * s, Vector2(0.3, 1.0) * s), k)
			ci.draw_rect(Rect2(c + Vector2(-1.1, -0.15) * s, Vector2(1.0, 0.3) * s), k)
			ci.draw_line(c, c + Vector2(0.7, 0) * s, k, lw, true)
			MapSymbols.poly(ci, PackedVector2Array([c + Vector2(1.05, 0) * s, c + Vector2(0.55, -0.4) * s, c + Vector2(0.55, 0.4) * s]), k)
		"build":
			ci.draw_line(c + Vector2(-0.7, 0.8) * s, c + Vector2(0.25, -0.15) * s, k, lw * 1.3, true)
			var d2 := Vector2(0.707, -0.707)
			var n2 := Vector2(0.707, 0.707)
			var h := c + Vector2(0.3, -0.3) * s
			MapSymbols.poly(ci, PackedVector2Array([h + n2 * s * 0.55 + d2 * s * 0.22, h - n2 * s * 0.55 + d2 * s * 0.22, h - n2 * s * 0.55 - d2 * s * 0.22, h + n2 * s * 0.55 - d2 * s * 0.22]), k)
		"gun":
			ci.draw_line(c + Vector2(-0.9, -0.2) * s, c + Vector2(0.95, -0.2) * s, k, lw, true)
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.45) * s, Vector2(0.75, 0.5) * s), k)
			ci.draw_line(c + Vector2(-0.1, 0.05) * s, c + Vector2(-0.6, 0.85) * s, k, lw, true)
			ci.draw_line(c + Vector2(-0.1, 0.05) * s, c + Vector2(0.4, 0.85) * s, k, lw, true)
		"retreat":
			for i in 2:
				var x2 := c.x + (i - 0.5) * s * 0.7 + s * 0.12
				ci.draw_polyline(PackedVector2Array([Vector2(x2 + s * 0.3, c.y - s * 0.7), Vector2(x2 - s * 0.35, c.y), Vector2(x2 + s * 0.3, c.y + s * 0.7)]), k, lw, true)
		"move":
			ci.draw_line(c + Vector2(-0.85, 0) * s, c + Vector2(0.3, 0) * s, k, lw, true)
			MapSymbols.poly(ci, PackedVector2Array([c + Vector2(0.95, 0) * s, c + Vector2(0.25, -0.55) * s, c + Vector2(0.25, 0.55) * s]), k)
		"assault":
			ci.draw_rect(Rect2(c + Vector2(-0.9, -0.22) * s, Vector2(1.15, 0.44) * s), k)
			MapSymbols.poly(ci, PackedVector2Array([c + Vector2(1.0, 0) * s, c + Vector2(0.2, -0.72) * s, c + Vector2(0.2, 0.72) * s]), k)
		"defend", "cover":
			var sh := PackedVector2Array([c + Vector2(-0.7, -0.8) * s, c + Vector2(0.7, -0.8) * s, c + Vector2(0.7, 0.05) * s, c + Vector2(0, 0.95) * s, c + Vector2(-0.7, 0.05) * s])
			if kind == "defend":
				MapSymbols.poly(ci, sh, k)
			else:
				sh.append(sh[0])
				ci.draw_polyline(sh, k, lw, true)
		"hold":
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.7) * s, Vector2(0.38, 1.4) * s), k)
			ci.draw_rect(Rect2(c + Vector2(0.17, -0.7) * s, Vector2(0.38, 1.4) * s), k)
		"flag":
			ci.draw_line(c + Vector2(-0.6, -0.9) * s, c + Vector2(-0.6, 0.95) * s, k, lw, true)
			MapSymbols.poly(ci, PackedVector2Array([c + Vector2(-0.6, -0.9) * s, c + Vector2(0.85, -0.65) * s, c + Vector2(0.6, -0.25) * s, c + Vector2(-0.6, -0.1) * s]), Color(1, 1, 1, a))
		"drone":
			ci.draw_line(c + Vector2(-0.7, -0.7) * s, c + Vector2(0.7, 0.7) * s, k, lw, true)
			ci.draw_line(c + Vector2(-0.7, 0.7) * s, c + Vector2(0.7, -0.7) * s, k, lw, true)
			for d3 in [Vector2(-0.7, -0.7), Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7)]:
				ci.draw_arc(c + d3 * s, s * 0.3, 0.0, TAU, 10, k, lw * 0.8, true)
		"melee":
			MapSymbols.poly(ci, PackedVector2Array([c + Vector2(0.85, -0.85) * s, c + Vector2(0.15, 0.05) * s, c + Vector2(-0.05, -0.15) * s]), k)
			ci.draw_line(c + Vector2(-0.25, -0.2) * s, c + Vector2(0.2, 0.25) * s, k, lw * 1.2, true)
			ci.draw_line(c + Vector2(0.0, 0.0) * s, c + Vector2(-0.7, 0.75) * s, k, lw * 1.5, true)
		"dazed":
			var tt := Time.get_ticks_msec() / 300.0
			for i in 3:
				var ang := tt + TAU * i / 3.0
				ci.draw_circle(c + Vector2(cos(ang), sin(ang) * 0.5) * s * 0.75, s * 0.2, k)
		"chat":
			ci.draw_rect(Rect2(c + Vector2(-0.9, -0.72) * s, Vector2(1.8, 1.15) * s), k)
			MapSymbols.poly(ci, PackedVector2Array([c + Vector2(-0.45, 0.4) * s, c + Vector2(0.0, 0.4) * s, c + Vector2(-0.55, 0.95) * s]), k)
			for i in 3:
				ci.draw_circle(c + Vector2(-0.45 + i * 0.45, -0.15) * s, s * 0.13, Color(0.05, 0.06, 0.05, a))
		"radio":
			var o := c + Vector2(-0.45, 0.35) * s
			ci.draw_circle(o, s * 0.24, k)
			ci.draw_arc(o, s * 0.65, -PI * 0.5, 0.0, 8, k, lw, true)
			ci.draw_arc(o, s * 1.1, -PI * 0.5, 0.0, 10, k, lw, true)
		"eye":
			var pts := PackedVector2Array()
			for i in 17:
				var ang2 := TAU * i / 16.0
				pts.append(c + Vector2(cos(ang2) * 0.9, sin(ang2) * 0.5) * s)
			ci.draw_polyline(pts, k, lw, true)
			ci.draw_circle(c, s * 0.28, k)
		"smoke":
			ci.draw_line(c + Vector2(-0.8, 0.45) * s, c + Vector2(0.5, 0.45) * s, k, lw * 1.6, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.55, 0.2) * s, c + Vector2(0.35, -0.2) * s, c + Vector2(0.6, -0.55) * s, c + Vector2(0.4, -0.9) * s]), k, lw * 0.8, true)
		"tunnel":
			ci.draw_arc(c + Vector2(0, 0.4) * s, s * 0.7, PI, TAU, 12, k, lw * 1.4, true)
			ci.draw_line(c + Vector2(-0.9, 0.45) * s, c + Vector2(0.9, 0.45) * s, k, lw, true)


## A filled polygon, skipped when it has collapsed to nothing on screen (points
## projected on top of each other, or off at infinity) so it can't fail to triangulate.
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var area := 0.0
	for i in pts.size():
		var a: Vector2 = pts[i]
		if not (is_finite(a.x) and is_finite(a.y)) or absf(a.x) > 20000.0 or absf(a.y) > 20000.0:
			return
		var b: Vector2 = pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	if absf(area) < 0.5:
		if OS.has_environment("FL_DEBUG_POLY"):
			print("degenerate polygon ", pts, "
", get_stack())
		return
	ci.draw_colored_polygon(pts, col)


static func wrap(t: String, fs: int, weight: int, wmax: float) -> Array:
	var out := []
	var cur := ""
	for word in t.split(" "):
		var cand: String = word if cur == "" else cur + " " + word
		if cur != "" and UiKit.text_width(cand, fs, weight) > wmax:
			out.append(cur)
			cur = word
		else:
			cur = cand
	if cur != "":
		out.append(cur)
	return out
