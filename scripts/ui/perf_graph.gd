class_name PerfGraph
extends Control
## The console's frame graph (`graph`): every frame of the last ten seconds or
## so as a column, stacked by what its time went on (the game logic, the view's
## scripts, the renderer, the rest), the GPU's time as a line over it, and a
## red mark on each stutter. A slow stretch shows which colour grew; a spike
## shows what it was.

const W := 640.0
const H := 214.0
const REDRAW_MS := 50  # (it redraws twenty times a second, not every frame: it's hundreds of columns)
const COLS := [Color(1.0, 0.75, 0.35), Color(0.4, 0.75, 1.0), Color(0.75, 0.55, 1.0), Color(0.42, 0.44, 0.42)]
const GPU_COL := Color(0.45, 1.0, 0.6)
const HITCH_COL := Color(1.0, 0.35, 0.3)
const SCALES := [25.0, 40.0, 60.0, 100.0, 160.0]

var probe: PerfProbe
# each part's column ends, two points a frame (members, filled in place: packed arrays are values)
var _s0 := PackedVector2Array()
var _s1 := PackedVector2Array()
var _s2 := PackedVector2Array()
var _s3 := PackedVector2Array()
var _gpu := PackedVector2Array()
var _n := -1
var _drawn_ms := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = 58.0
	offset_bottom = offset_top + H


func _process(_dt: float) -> void:
	if visible and Time.get_ticks_msec() - _drawn_ms >= REDRAW_MS:
		_drawn_ms = Time.get_ticks_msec()
		queue_redraw()


func _draw() -> void:
	var p := probe
	draw_style_box(UiKit.boxc(Color(0.02, 0.025, 0.022, 0.86), 6, Color(1, 1, 1, 0.12)), Rect2(Vector2.ZERO, size))
	var fps := 1000.0 / maxf(0.01, p.frame_ms)
	UiKit.text(self, Vector2(0, 20), "%.0f FPS   %.1f ms   1%% low %.0f   GPU %.1f ms" % [fps, p.frame_ms, p.low1, p.gpu_ms], 13,
		Color(0.55, 1.0, 0.55) if fps >= 55.0 else (Color(1.0, 0.85, 0.4) if fps >= 30.0 else Color(1.0, 0.45, 0.4)), 400, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 12)
	var g := Rect2(12, 30, size.x - 24, size.y - 66)
	draw_rect(g, Color(0, 0, 0, 0.35))
	# the scale: the smallest that holds most frames, so a spike stands out rather than flattening the rest
	var gmax: float = SCALES[SCALES.size() - 1]
	for s in SCALES:
		if s >= maxf(p.median_ms * 2.2, 20.0):
			gmax = s
			break
	for ref: float in [16.7, 33.3]:
		if ref < gmax:
			var ry := g.end.y - ref / gmax * g.size.y
			draw_line(Vector2(g.position.x, ry), Vector2(g.end.x, ry), Color(1, 1, 1, 0.16), 1.0)
			UiKit.text(self, Vector2(g.end.x - 48, ry - 3), "%d FPS" % roundi(1000.0 / ref), 10, Color(1, 1, 1, 0.4))
	UiKit.text(self, Vector2(g.position.x + 4, g.position.y + 12), "%.0f ms" % gmax, 10, Color(1, 1, 1, 0.4))
	var n := p.count
	if n != _n:
		_n = n
		_s0.resize(n * 2)
		_s1.resize(n * 2)
		_s2.resize(n * 2)
		_s3.resize(n * 2)
		_gpu.resize(n)
	var cw := g.size.x / PerfProbe.RING
	var k := g.size.y / gmax
	var clipped := []
	var span := 0.0
	# each column: game logic from the bottom, then the scripts, the renderer and the rest up to the frame's whole time
	for j in n:
		var back := n - 1 - j
		var x := g.end.x - (back + 0.5) * cw
		var ms := p.at(p.f_ms, back)
		span += ms
		var top := g.end.y - minf(ms, gmax) * k
		var y0 := g.end.y
		var y1 := maxf(top, y0 - p.at(p.f_sim, back) * k)
		var y2 := maxf(top, y1 - p.at(p.f_view, back) * k)
		var y3 := maxf(top, y2 - p.at(p.f_rcpu, back) * k)
		_s0[j * 2] = Vector2(x, y0)
		_s0[j * 2 + 1] = Vector2(x, y1)
		_s1[j * 2] = Vector2(x, y1)
		_s1[j * 2 + 1] = Vector2(x, y2)
		_s2[j * 2] = Vector2(x, y2)
		_s2[j * 2 + 1] = Vector2(x, y3)
		_s3[j * 2] = Vector2(x, y3)
		_s3[j * 2 + 1] = Vector2(x, top)
		_gpu[j] = Vector2(x, g.end.y - minf(p.at(p.f_gpu, back), gmax) * k)
		if ms > gmax:
			clipped.append(x)
	if n > 0:
		draw_multiline(_s0, COLS[0], cw + 0.35)
		draw_multiline(_s1, COLS[1], cw + 0.35)
		draw_multiline(_s2, COLS[2], cw + 0.35)
		draw_multiline(_s3, COLS[3], cw + 0.35)
	if p.measuring and n > 1:
		draw_polyline(_gpu, GPU_COL, 1.2)
	for x in clipped:
		draw_rect(Rect2(x - cw, g.position.y, cw * 2.0, 3.0), HITCH_COL)
	UiKit.text(self, Vector2(12, 20), "FRAMES", 13, UiKit.ACCENT, 600)
	UiKit.text(self, Vector2(74, 20), "the last %.0f s, newest on the right" % (span / 1000.0), 12, UiKit.DIM)
	# the stutters
	for h in p.hitches:
		var back: int = p.frames - 1 - int(h.n)
		if back < n:
			var hx := g.end.x - (back + 0.5) * cw
			draw_line(Vector2(hx, g.position.y), Vector2(hx, g.end.y), Color(HITCH_COL.r, HITCH_COL.g, HITCH_COL.b, 0.35), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(hx - 4, g.position.y - 1), Vector2(hx + 4, g.position.y - 1), Vector2(hx, g.position.y + 6)]), HITCH_COL)
	# the key, with this half second's averages
	var lx := 12.0
	var ly := size.y - 14.0
	var parts := [["game logic", p.sim_ms], ["view scripts", p.view_ms], ["renderer", p.cpu_ms], ["the rest", maxf(0.0, p.frame_ms - p.sim_ms - p.view_ms - p.cpu_ms)]]
	for i in parts.size():
		draw_rect(Rect2(lx, ly - 9, 9, 9), COLS[i])
		var t := "%s %.1f" % [parts[i][0], parts[i][1]]
		UiKit.text(self, Vector2(lx + 13, ly), t, 12, Color(0.88, 0.88, 0.84))
		lx += 13.0 + UiKit.text_width(t, 12) + 16.0
	draw_line(Vector2(lx, ly - 4), Vector2(lx + 12, ly - 4), GPU_COL, 2.0)
	UiKit.text(self, Vector2(lx + 16, ly), "GPU %.1f" % p.gpu_ms if p.measuring else "GPU (not measured)", 12, Color(0.88, 0.88, 0.84))
	UiKit.text(self, Vector2(0, ly), "ms a frame", 11, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 12)

