class_name HudLayers
extends Control
## The map layers, a column of toggles beside the minimap: unit symbols,
## orders and attack plans, intelligence (last known enemy positions), the fog
## of war, weapon ranges, soldier labels, and the tactical map (Tab).

const ITEMS := [
	["tactical", "Tactical map\nDims the battlefield and shows it as a map: every unit, order and contact.", "map"],
	["units", "Unit symbols\nA symbol for every squad and vehicle at any zoom.", "units"],
	["orders", "Orders\nRoutes, objectives and attack plans for all your units, not just the selected ones.", "orders"],
	["intel", "Intelligence\nWhere the enemy was last seen, and how long ago.", "intel"],
	["vision", "Fog of war\nGround your side can't see right now is drawn darker, on the battlefield and the minimap.", "vision"],
	["ranges", "Weapon ranges\nHow far the selected units can reach.", "ranges"],
	["labels", "Soldier labels\nNames, what each man is doing, and the chatter.", "labels"],
]
const S := 30.0

var hud: Hud
var _hover := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(S, S * ITEMS.size() + 4.0 * (ITEMS.size() - 1))


func _get_tooltip(at: Vector2) -> String:
	var i := _index(at)
	if i < 0:
		return ""
	var tip: String = ITEMS[i][1]
	if ITEMS[i][0] == "tactical" and Keys.label("tactical") != "":
		# its key, as bound now, on the first line
		tip = tip.replace("Tactical map", "Tactical map  (%s)" % Keys.label("tactical"))
	return tip


func _index(p: Vector2) -> int:
	for i in ITEMS.size():
		if Rect2(0, i * (S + 4.0), S, S).has_point(p):
			return i
	return -1


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _index(ev.position)
		if h != _hover:
			_hover = h
			tooltip_text = ITEMS[h][1] if h >= 0 else ""
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var i := _index(ev.position)
		if i >= 0:
			var key: String = ITEMS[i][0]
			if key == "tactical":
				hud.toggle_tactical()
			else:
				hud.set_map_layer(key, not hud.map_layer(key))
			accept_event()
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()


## The tools as plain line icons (docs/UI.md): faint when off, the accent
## when on, lit under the cursor. No boxes.
func _draw() -> void:
	for i in ITEMS.size():
		var key: String = ITEMS[i][0]
		var on: bool = hud.tactical if key == "tactical" else hud.map_layer(key)
		var r := Rect2(0, i * (S + 4.0), S, S)
		if i == _hover:
			draw_rect(r, UiKit.fa(UiKit.TEXT, 0.06))
		var c := r.get_center()
		var col := UiKit.ACCENT if on else (UiKit.TEXT if i == _hover else UiKit.FAINT)
		_icon(String(ITEMS[i][2]), c, col)


func _icon(kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"map":
			draw_polyline(PackedVector2Array([c + Vector2(-8, -5), c + Vector2(-3, -7), c + Vector2(3, -5), c + Vector2(8, -7), c + Vector2(8, 6), c + Vector2(3, 8), c + Vector2(-3, 6), c + Vector2(-8, 8), c + Vector2(-8, -5)]), col, 1.4)
			draw_line(c + Vector2(-3, -7), c + Vector2(-3, 6), col, 1.2)
			draw_line(c + Vector2(3, -5), c + Vector2(3, 8), col, 1.2)
		"units":
			var r := Rect2(c - Vector2(8, 5.5), Vector2(16, 11))
			draw_rect(r, col, false, 1.6)
			draw_line(r.position, r.end, col, 1.4, true)
			draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), col, 1.4, true)
		"orders":
			draw_line(c + Vector2(-8, 6), c + Vector2(2, -2), col, 2.0, true)
			MapSymbols.poly(self, PackedVector2Array([c + Vector2(8, -7), c + Vector2(0, -5), c + Vector2(5, 1)]), col)
			draw_arc(c + Vector2(-7, 6), 2.2, 0, TAU, 10, col, 1.4, true)
		"intel":
			var d := PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0), c + Vector2(0, -8)])
			draw_polyline(d, col, 1.6, true)
			UiKit.text(self, c + Vector2(-3, 4), "?", 11, col, 700)
		"vision":
			# an eye
			var lid := PackedVector2Array()
			for k in 13:
				var a := PI * k / 12.0
				lid.append(c + Vector2(-cos(a) * 9.0, -sin(a) * 5.5))
			for k in 13:
				var a := PI * k / 12.0
				lid.append(c + Vector2(cos(a) * 9.0, sin(a) * 5.5))
			draw_polyline(lid, col, 1.5, true)
			draw_circle(c, 2.8, col)
		"ranges":
			draw_arc(c, 8.0, 0, TAU, 24, col, 1.4, true)
			draw_arc(c, 4.0, 0, TAU, 16, col, 1.2, true)
			draw_circle(c, 1.4, col)
		"labels":
			draw_rect(Rect2(c + Vector2(-9, -5), Vector2(18, 9)), col, false, 1.4)
			MapSymbols.poly(self, PackedVector2Array([c + Vector2(-4, 4), c + Vector2(1, 4), c + Vector2(-3, 8)]), col)
			draw_line(c + Vector2(-6, -1), c + Vector2(6, -1), col, 1.2)
