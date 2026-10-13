class_name FieldManual
extends PanelContainer
## The field manual: every soldier, team, weapon, vehicle, building, defence,
## fire mission and upgrade in the game, with its numbers (read live from Defs,
## so they are always the game's own) and a 3D model to turn over. Opened from
## the main menu and in battle (F4 / Esc menu).

signal closed

const CATS := [
	["infantry", "Infantry"], ["squads", "Squads & teams"], ["weapons", "Weapons"], ["vehicles", "Vehicles"],
	["bases", "Base buildings"], ["defences", "Field defences"], ["support", "Fire support"], ["upgrades", "Upgrades"],
]
const BASES := ["fob", "barracks", "factory", "helipad", "medic_tent", "research", "tunnel"]

## What each thing is modelled on.
const PATTERN := {
	"rifle": "M4A1 carbine, 5.56x45 mm", "ak": "AKM assault rifle, 7.62x39 mm", "smg": "compact carbine, 5.56 mm",
	"lmg": "M249 SAW, 5.56 mm (Coalition) / PKM, 7.62x54R (Rebels)", "pistol": "service pistol, 9 mm",
	"mmg": "M240B on the M192 mount (Coalition) / PKM on its tripod (Rebels), 7.62 mm",
	"m2": "M2HB Browning, .50 BMG (12.7x99 mm); the Rebels' DShKM fires 12.7x108 mm",
	"chaingun": "M230 chain gun, 30x113 mm", "zu23": "ZU-23-2 twin autocannon, 23x152 mm",
	"bushmaster": "M242 Bushmaster, 25x137 mm with airburst rounds", "kpvt": "KPVT heavy machine gun, 14.5x114 mm",
	"coax": "coaxial machine gun, 7.62 mm",
	"tank": "modern main battle tank, Abrams class, 120 mm smoothbore", "old_tank": "T-55 / T-62 class, 100 / 115 mm gun",
	"technical": "Toyota Hilux pickup with a heavy machine gun in the bed", "ifv": "M2 Bradley class tracked IFV",
	"btr": "BTR-80 class 8x8 armoured personnel carrier", "humvee": "M1151 HMMWV with a roof-ring M2",
	"gunship": "AH-64 Apache class attack helicopter", "aa_tech": "pickup carrying a ZU-23-2",
	"heli": "UH-60 Black Hawk class utility helicopter", "truck": "4x4 cargo truck",
	"airstrike": "F-16 class strike jet, four 500 lb bombs", "a10": "A-10C Thunderbolt II, GAU-8 Avenger 30 mm",
	"ac130": "AC-130J Ghostrider: 105 mm howitzer, 30 mm and 25 mm cannon", "artillery": "M777 155 mm howitzers, off-map",
	"barrage": "BM-21 Grad, 122 mm rockets", "mortars": "82 mm mortar battery",
	"mg_nest": "M240B on M192 (Coalition) / PKM on tripod (Rebels); placed on a trench it becomes a gun bay",
	"hmg_nest": "M2HB on the M3 tripod (Coalition) / DShKM with a gun shield (Rebels); placed on a trench it becomes a gun bay",
	"at_post": "Javelin class guided missile (Coalition) / SPG-9 recoilless rifle (Rebels)", "mortar_pit": "81 / 82 mm mortar",
	"bunker": "concrete pillbox (Coalition) / log-and-earth dugout (Rebels)", "trench": "fire trench, revetted, with fire bays",
}

var _cat := "infantry"
var _side := -1  # -1 both
var _query := ""
var _sel := ""
var _entries: Array = []  # all entries (dictionaries), built once
var _cat_btns := {}
var _side_btns := {}
var _list: VBoxContainer
var _title: Label
var _chips: HBoxContainer
var _desc: Label
var _pattern: Label
var _stats: GridContainer
var _rel: Label
var _view: SubViewport
var _stage: Node3D
var _turn: Node3D
var _cam: Camera3D
var _model: Node3D
var _floor: MeshInstance3D
var _floor_mat: ShaderMaterial
var _focus := Vector3.ZERO
var _dist := 6.0
var _yaw := 0.6
var _pitch := -0.32
var _drag := false
var _idle_t := 0.0


func _ready() -> void:
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.boxc(Color(0.04, 0.05, 0.045, 0.97), 10, UiKit.LINE, 1, 14.0, 8))
	_entries = _build_entries()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	# title bar: name, side filter, search, close
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	var tl := UiKit.label("Field Manual", 24, UiKit.TEXT, 700)
	top.add_child(tl)
	var sub := UiKit.label("  every unit, weapon, vehicle and work in the field, with its numbers", 13, UiKit.DIM)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sub)
	for s in [[-1, "Both sides"], [0, "Coalition"], [1, "Rebels"]]:
		var b := Button.new()
		b.text = s[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(96, 32)
		var sv: int = s[0]
		b.pressed.connect(func(): _set_side(sv))
		top.add_child(b)
		_side_btns[sv] = b
	var search := LineEdit.new()
	search.placeholder_text = "Search"
	search.custom_minimum_size = Vector2(170, 32)
	search.text_changed.connect(func(t: String): _query = t.strip_edges().to_lower(); _fill_list())
	top.add_child(search)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(80, 32)
	close.pressed.connect(func(): closed.emit())
	top.add_child(close)
	# body: categories | list | detail
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	var cats := VBoxContainer.new()
	cats.custom_minimum_size = Vector2(170, 0)
	cats.add_theme_constant_override("separation", 4)
	body.add_child(cats)
	for c in CATS:
		var b2 := Button.new()
		b2.text = c[1]
		b2.toggle_mode = true
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.custom_minimum_size = Vector2(0, 36)
		var ck: String = c[0]
		b2.pressed.connect(func(): _set_cat(ck))
		cats.add_child(b2)
		_cat_btns[ck] = b2
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(300, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	sc.add_child(_list)
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_constant_override("separation", 8)
	body.add_child(det)
	det.add_child(_make_view())
	var dsc := ScrollContainer.new()
	dsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	det.add_child(dsc)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.add_theme_constant_override("separation", 6)
	dsc.add_child(dv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	dv.add_child(head)
	_title = UiKit.label("", 22, UiKit.TEXT, 700)
	head.add_child(_title)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 6)
	head.add_child(_chips)
	_pattern = UiKit.label("", 13, UiKit.ACCENT)
	_pattern.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_pattern)
	_desc = UiKit.label("", 14, UiKit.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_desc)
	_stats = GridContainer.new()
	_stats.columns = 3
	_stats.add_theme_constant_override("h_separation", 12)
	_stats.add_theme_constant_override("v_separation", 5)
	dv.add_child(_stats)
	_rel = UiKit.label("", 13, UiKit.DIM)
	_rel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_rel)
	_set_side(-1)
	_set_cat("infantry")
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))


## Opens on a page: a category, optionally an entry, optionally one side.
func open(cat: String, key := "", side := -1) -> void:
	visible = true
	_set_side(side)
	_set_cat(cat)
	if key != "":
		_select(key)


func _set_cat(c: String) -> void:
	_cat = c
	for k in _cat_btns:
		_cat_btns[k].button_pressed = k == c
	_sel = ""
	_fill_list()


func _set_side(s: int) -> void:
	_side = s
	for k in _side_btns:
		_side_btns[k].button_pressed = k == s
	_fill_list()


func _visible_entries() -> Array:
	var out := []
	for e in _entries:
		if e.cat != _cat:
			continue
		if _side >= 0 and int(e.team) >= 0 and int(e.team) != _side and not (e.get("both", false)):
			continue
		if _query != "" and not (String(e.name).to_lower().contains(_query) or String(e.get("pattern", "")).to_lower().contains(_query)):
			continue
		out.append(e)
	return out


func _fill_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var vis := _visible_entries()
	for e in vis:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 46)
		b.button_pressed = e.key == _sel
		b.text = ""
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -10
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 30)
		dot.color = _side_col(int(e.team), e.get("both", false))
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var n := UiKit.label(String(e.name), 15, UiKit.TEXT, 600)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(n)
		var s2 := UiKit.label(String(e.get("sub", "")), 11, UiKit.DIM)
		s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s2.clip_text = true
		col.add_child(s2)
		var k: String = e.key
		b.set_meta("key", k)
		b.pressed.connect(func(): _select(k))
		_list.add_child(b)
	if _sel == "" and not vis.is_empty():
		_select(String(vis[0].key))


func _select(key: String) -> void:
	_sel = key
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(String(b.get_meta("key", "")) == key)
	var e: Dictionary = {}
	for x in _visible_entries():
		if x.key == key:
			e = x
	if e.is_empty():
		return
	_title.text = String(e.name)
	for c in _chips.get_children():
		c.queue_free()
	_chips.add_child(_chip(_side_name(int(e.team), e.get("both", false)), _side_col(int(e.team), e.get("both", false))))
	if e.has("role"):
		_chips.add_child(_chip(String(e.role), UiKit.DIM))
	_pattern.text = ("Pattern: " + String(e.pattern)) if e.has("pattern") else ""
	_pattern.visible = e.has("pattern")
	_desc.text = String(e.get("desc", ""))
	for c in _stats.get_children():
		c.queue_free()
	for s in e.stats:
		var lab := UiKit.label(String(s[0]), 13, UiKit.DIM)
		lab.custom_minimum_size = Vector2(150, 0)
		_stats.add_child(lab)
		var bar := StatBar.new()
		bar.frac = float(s[2])
		bar.col = UiKit.ACCENT if float(s[2]) >= 0.0 else Color(0, 0, 0, 0)
		bar.custom_minimum_size = Vector2(160, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stats.add_child(bar)
		var val := UiKit.label(String(s[1]), 13, UiKit.TEXT, 600)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(val)
	_rel.text = "\n".join(e.get("rel", []))
	_show_model(e)


func _chip(t: String, c: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.boxc(Color(c.r, c.g, c.b, 0.16), 4, Color(c.r, c.g, c.b, 0.5), 1, 4.0))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiKit.label(t, 12, c.lightened(0.2), 600)
	p.add_child(l)
	return p


func _side_col(t: int, both: bool) -> Color:
	if both or t < 0:
		return UiKit.ACCENT
	return Defs.TEAM_COLORS[t]


func _side_name(t: int, both: bool) -> String:
	if both or t < 0:
		return "Both sides"
	return Defs.TEAM_NAMES[t]


# --- the 3D view ---------------------------------------------------------------------

func _make_view() -> Control:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(0, 420)
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_view_input)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(_view)
	_stage = Node3D.new()
	_view.add_child(_stage)
	# a dark studio: warm key light, a cold rim from behind that outlines the
	# silhouette, a faint fill, and a matte floor with a tactical grid that
	# fades into the dark
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.028, 0.032, 0.036)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.65, 0.62)
	env.ambient_light_energy = 0.16
	env.tonemap_mode = Environment.TONE_MAPPER_AGX  # as in the game
	env.tonemap_exposure = 0.85
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.86
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	_stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-38), 0)
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.93, 0.82)
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 40.0
	_stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-14), deg_to_rad(165), 0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.78, 0.86, 1.0)
	_stage.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-10), deg_to_rad(70), 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.85, 0.88, 0.95)
	_stage.add_child(fill)
	_floor = MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(80, 80)
	_floor.mesh = fm
	var fsh := Shader.new()
	fsh.code = FLOOR_SHADER
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = fsh
	_floor.material_override = _floor_mat
	_stage.add_child(_floor)
	_turn = Node3D.new()
	_stage.add_child(_turn)
	_cam = Camera3D.new()
	_cam.fov = 28.0  # a longer lens: less of the toy-like close-up distortion
	_stage.add_child(_cam)
	return svc


func _view_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(_dist * 0.9, 0.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(_dist * 1.1, 80.0)
	elif ev is InputEventMouseMotion and _drag:
		var mm := ev as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.01
		_pitch = clampf(_pitch - mm.relative.y * 0.006, -1.3, 0.05)
		_idle_t = 2.5


func _process(dt: float) -> void:
	if _cam == null:
		return
	_idle_t -= dt
	if _idle_t <= 0.0 and not _drag:
		_yaw += dt * 0.28  # a slow turntable when left alone
	var off := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Vector3(0, 0, _dist)
	_cam.position = _focus + off
	_cam.look_at(_focus, Vector3.UP)


func _show_model(e: Dictionary) -> void:
	if _model:
		_model.queue_free()
		_model = null
	var m: Node3D = _make_model(e)
	if m == null:
		_view.get_parent().visible = false
		return
	_view.get_parent().visible = true
	_model = m
	_turn.add_child(m)
	# frame it: everything it's made of, seen from a little above
	var ab := AABB()
	var first := true
	for n in _all_visuals(m):
		var vi := n as VisualInstance3D
		var t: Transform3D = m.global_transform.affine_inverse() * vi.global_transform
		var b := t * vi.get_aabb()
		ab = b if first else ab.merge(b)
		first = false
	if first:
		ab = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	_focus = ab.get_center()
	if OS.has_environment("FL_DEBUG_FM"):
		print("FM ", e.key, " aabb=", ab, " vs=", _view.size)
	# fit it whichever way the turntable has it: a cylinder round its footprint,
	# seen from the camera's pitch, inside the vertical and horizontal field
	var vs: Vector2 = _view.size
	# (before the first layout the view has no size yet)
	var aspect := clampf(vs.x / vs.y, 1.2, 4.0) if vs.x > 16.0 and vs.y > 16.0 else 2.4
	var wide := maxf(ab.size.x, ab.size.z)
	var rxz := Vector2(ab.size.x, ab.size.z).length() * 0.5
	_pitch = -0.28 if ab.size.y > wide * 0.5 else -0.42
	var half_v := ab.size.y * 0.5 * cos(_pitch) + rxz * sin(absf(_pitch))
	var tv := tan(deg_to_rad(_cam.fov * 0.5))
	_dist = maxf(half_v / tv, rxz / (tv * aspect)) * 1.0 + rxz * 0.35
	var span := maxf(wide, ab.size.y)
	_floor_mat.set_shader_parameter("radius", maxf(1.6, span * 1.3))
	_floor_mat.set_shader_parameter("cell", 1.0 if span > 3.0 else (0.5 if span > 1.2 else 0.25))
	# a front three-quarter view (models face -z)
	# (soldiers more side-on, so a raised rifle isn't pointing at the lens)
	_yaw = PI - (1.05 if String(e.cat) in ["infantry", "squads"] else 0.62)
	_idle_t = 4.0  # hold the opening view a moment before the turntable starts


func _all_visuals(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is VisualInstance3D and (c as VisualInstance3D).is_visible_in_tree():
			out.append(c)
		out.append_array(_all_visuals(c))
	return out


func _make_model(e: Dictionary) -> Node3D:
	var side: int = int(e.team) if int(e.team) >= 0 else (_side if _side >= 0 else 0)
	match String(e.cat):
		"infantry":
			# armed men stand to, weapon up; the rest at ease
			var armed: bool = String(Defs.UNITS[e.key].weapon) in ["rifle", "ak", "smg", "lmg"]
			return _soldier(String(e.key), side, Soldier.Act.SHOOT if armed else Soldier.Act.IDLE)
		"squads":
			var g := Node3D.new()
			var mem: Array = Defs.SQUADS[e.key].members
			for i in mem.size():
				var armed2: bool = String(Defs.UNITS[mem[i]].weapon) in ["rifle", "ak", "smg", "lmg"]
				var s := _soldier(String(mem[i]), side, Soldier.Act.SHOOT if armed2 and i % 2 == 0 else Soldier.Act.IDLE, 11 + i * 7)
				s.position = Vector3((i - (mem.size() - 1) * 0.5) * 0.95, 0, absf(i - (mem.size() - 1) * 0.5) * 0.35)
				g.add_child(s)
			return g
		"weapons":
			return _weapon_model(String(e.key), side)
		"vehicles":
			var vm := VehicleModels.build(String(e.key), side if int(e.team) >= 0 else 0, 7)
			return vm.root
		"bases", "defences":
			if e.key == "trench":
				return _trench_diorama()
			var bteams: Array = Defs.BUILDINGS[e.key].teams
			var bs: int = side if side in bteams else int(bteams[0])
			return Structure.preview_model(String(e.key), bs)
		"support":
			match String(e.key):
				"airstrike":
					return VehicleModels.build("jet", 0, 3).root
				"a10":
					return VehicleModels.build("a10", 0, 3).root
				"ac130":
					return VehicleModels.build("ac130", 0, 3).root
				"mortars":
					return Structure.preview_model("mortar_pit", 1)
				_:
					return _shells(String(e.key))
	return null


func _soldier(ut: String, side: int, act: int, sd := 7) -> Node3D:
	var sm := SoldierModel.new()
	sm.build(ut, side if Defs.UNITS[ut].team < 0 else int(Defs.UNITS[ut].team), sd)
	for i in 6:
		sm.pose(0.5, 0, Soldier.Post.STAND, act, 0.0, false, false)
	sm.rotation.y = 0.0
	return sm


## Small arms come out of a soldier's hands; crew-served guns on their mounts;
## vehicle guns on the vehicle.
func _weapon_model(key: String, side: int) -> Node3D:
	match key:
		"mmg", "m2", "hmg":
			var cg := WeaponModels.build(("pkm" if side == 1 else "m240") if key == "mmg" else ("dshk" if side == 1 else "m2"))
			var cr: Node3D = cg.root
			cr.position.y = float(cg.h)  # tripod feet on the floor
			var hold := Node3D.new()
			hold.add_child(cr)
			return hold
		"chaingun":
			return VehicleModels.build("gunship", 0, 7).root
		"zu23":
			return VehicleModels.build("aa_tech", 1, 7).root
		"bushmaster":
			return VehicleModels.build("ifv", 0, 7).root
		"kpvt":
			return VehicleModels.build("btr", 1, 7).root
		"coax":
			return VehicleModels.build("tank" if side != 1 else "old_tank", side if side >= 0 else 0, 7).root
	var ut: String = {"rifle": "rifleman", "ak": "fighter", "smg": "medic", "lmg": "pkm" if side == 1 else "mg_gunner", "pistol": "fpv_op"}.get(key, "rifleman")
	var sm := SoldierModel.new()
	sm.build(ut, int(Defs.UNITS[ut].team), 3)
	var g: Node3D = sm.gun
	g.get_parent().remove_child(g)
	g.transform = Transform3D.IDENTITY
	g.visible = true
	sm.free()
	var holder := Node3D.new()
	holder.add_child(g)
	g.position.y = 0.6
	return holder


## Shells and rockets for the off-map fire missions.
func _shells(key: String) -> Node3D:
	var g := Node3D.new()
	var n := 4
	for i in n:
		var x := (i - (n - 1) * 0.5) * 0.32
		if key == "barrage":
			# 122 mm Grad rocket: long tube, ogive nose, tail fins
			WeaponModels._tube(g, 0.12, -1.4, 1.2, 0.061, "paint", -1.0, x, Color(0.5, 0.53, 0.42))
			WeaponModels._tube(g, 0.12, -1.4, -1.75, 0.061, "paint", 0.01, x, Color(0.5, 0.53, 0.42))
			for a in 4:
				WeaponModels._box(g, Vector3(0.006, 0.12, 0.18), Vector3(x, 0.12, 1.12), "gunmetal", Vector3(0, 0, a * PI / 2))
		else:
			# 155 mm high-explosive shell with its fuze and driving band
			WeaponModels._tube(g, 0.08, -0.3, 0.25, 0.0775, "paint", -1.0, x, Color(0.42, 0.45, 0.3))
			WeaponModels._tube(g, 0.08, -0.3, -0.58, 0.0775, "paint", 0.02, x, Color(0.42, 0.45, 0.3))
			WeaponModels._tube(g, 0.08, 0.18, 0.21, 0.082, "paint", -1.0, x, Color(0.72, 0.45, 0.25))
			WeaponModels._tube(g, 0.08, -0.58, -0.66, 0.02, "paint", 0.012, x, Color(0.75, 0.62, 0.3))
	g.rotation.x = 0.0
	return g


## A short length of fire trench cut into a block of ground, revetted.
func _trench_diorama() -> Node3D:
	var g := Node3D.new()
	var L := 6.0
	var hw := TrenchNet.HALF_W
	var d := -TrenchNet.FLOOR_Y
	for s in [-1.0, 1.0]:
		var blk := MeshInstance3D.new()
		blk.mesh = Res.box(Vector3(L, d, 2.0))
		blk.position = Vector3(0, -d * 0.5, s * (hw + 1.0))
		Mats.apply(blk, "earth")
		g.add_child(blk)
		# revetment boards and posts on the trench wall
		var wall := MeshInstance3D.new()
		wall.mesh = Res.box(Vector3(L, d * 0.8, 0.05))
		wall.position = Vector3(0, -d * 0.55, s * (hw + 0.02))
		Mats.apply(wall, "wood", Color(0.7, 0.6, 0.48))
		g.add_child(wall)
		for i in 5:
			var post := MeshInstance3D.new()
			post.mesh = Res.box(Vector3(0.1, d + 0.1, 0.1))
			post.position = Vector3(-L * 0.5 + 0.6 + i * 1.2, -d * 0.5 + 0.05, s * (hw - 0.03))
			Mats.apply(post, "wood_dark")
			g.add_child(post)
	var fl := MeshInstance3D.new()
	fl.mesh = Res.box(Vector3(L, 0.05, hw * 2.0))
	fl.position = Vector3(0, -d, 0)
	Mats.apply(fl, "wood", Color(0.55, 0.48, 0.38))
	g.add_child(fl)
	# spoil thrown up as a parapet in front, sandbags along it
	var berm := MeshInstance3D.new()
	berm.mesh = Res.box(Vector3(L, 0.3, 1.2))
	berm.position = Vector3(0, 0.15, -(hw + 0.7))
	Mats.apply(berm, "earth")
	g.add_child(berm)
	for i in 8:
		var bag := MeshInstance3D.new()
		bag.mesh = Res.box(Vector3(0.55, 0.16, 0.32))
		bag.position = Vector3(-L * 0.5 + 0.5 + i * 0.7, 0.38, -(hw + 0.45))
		bag.rotation.y = (i % 3) * 0.06
		Mats.apply(bag, "sandbag")
		g.add_child(bag)
	var gun := WeaponModels.build("m240", true)
	var gr: Node3D = gun.root
	gr.position = Vector3(0.8, float(gun.h), -(hw + 0.5))
	g.add_child(gr)
	g.position.y = d
	return g


const FLOOR_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform float radius = 6.0;
uniform float cell = 1.0;
varying vec3 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	float r = length(wp.xz);
	vec2 q = wp.xz / cell;
	vec2 g = abs(fract(q) - 0.5);
	float w = fwidth(q.x) * 1.2;
	float ln = 1.0 - smoothstep(0.0, w, 0.5 - max(g.x, g.y));
	vec2 g10 = abs(fract(q / 5.0) - 0.5);
	float ln2 = 1.0 - smoothstep(0.0, w * 0.2, 0.5 - max(g10.x, g10.y));
	vec3 c = vec3(0.034, 0.037, 0.04);
	c = mix(c, vec3(0.06, 0.075, 0.08), max(ln * 0.5, ln2 * 0.8));
	float fade = 1.0 - smoothstep(radius * 0.3, radius, r);
	ALBEDO = c * fade;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
}
"""


# --- the entries -----------------------------------------------------------------------

func _build_entries() -> Array:
	var out := []
	# who carries / mounts each weapon
	var users := {}
	for u in Defs.UNITS:
		var w: String = Defs.UNITS[u].weapon
		if w != "":
			users[w] = users.get(w, []) + [String(Defs.UNITS[u].name)]
	for v in Defs.VEHICLES:
		var vw: String = Defs.VEHICLES[v].get("mg", "")
		if vw != "":
			users[vw] = users.get(vw, []) + [String(Defs.VEHICLES[v].name)]
	users["mmg"] = users.get("mmg", []) + ["MG Nest"]
	users["m2"] = users.get("m2", []) + [".50 Cal Nest"]
	var squads_of := {}
	for sq in Defs.SQUADS:
		for m in Defs.SQUADS[sq].members:
			if not String(Defs.SQUADS[sq].name) in squads_of.get(m, []):
				squads_of[m] = squads_of.get(m, []) + [String(Defs.SQUADS[sq].name)]
	# category maxima for the bars
	var mx := func(table: Dictionary, f: Callable) -> float:
		var best := 0.001
		for k in table:
			best = maxf(best, float(f.call(table[k])))
		return best

	# weapons
	var wmax := {"dmg": mx.call(Defs.WEAPONS, func(w): return w.dmg), "range": mx.call(Defs.WEAPONS, func(w): return w.range),
		"rpm": mx.call(Defs.WEAPONS, func(w): return 60.0 / float(w.interval)), "supp": mx.call(Defs.WEAPONS, func(w): return w.supp),
		"dps": mx.call(Defs.WEAPONS, func(w): return _dps(w)), "acc": mx.call(Defs.WEAPONS, func(w): return w.acc)}
	for k in Defs.WEAPONS:
		if not users.has(k):
			continue  # nothing in the game carries it
		var w: Dictionary = Defs.WEAPONS[k]
		var rpm := 60.0 / float(w.interval)
		var bmin: int = (w.burst as Vector2i).x
		var bmax: int = (w.burst as Vector2i).y
		var flags := []
		if w.get("ap", false):
			flags.append("armour-piercing")
		if w.has("he"):
			flags.append("high-explosive (%.1f m)" % float(w.he))
		if w.get("airburst", false):
			flags.append("airburst over trenches")
		if w.get("aa", false):
			flags.append("anti-aircraft")
		var sides := {}
		for u in Defs.UNITS:
			if Defs.UNITS[u].weapon == k:
				sides[int(Defs.UNITS[u].team)] = true
		for v in Defs.VEHICLES:
			if Defs.VEHICLES[v].get("mg", "") == k:
				sides[int(Defs.VEHICLES[v].team)] = true
		var wt := -1 if sides.size() != 1 else int(sides.keys()[0])
		out.append({"cat": "weapons", "key": k, "name": String(w.name), "team": wt, "both": sides.size() > 1 or k in ["mmg", "m2"],
			"sub": "%d dmg · %d m · %d rpm" % [int(w.dmg), int(w.range), int(rpm)], "pattern": PATTERN.get(k, ""),
			"role": "crew-served" if k in ["mmg", "m2"] else ("vehicle weapon" if not k in ["rifle", "ak", "smg", "lmg", "pistol"] else "small arm"),
			"desc": ", ".join(flags).capitalize() + ("." if not flags.is_empty() else "Bursts of %d-%d rounds." % [bmin, bmax]),
			"stats": [
				["Damage per hit", "%d" % int(w.dmg), float(w.dmg) / wmax.dmg],
				["Effective range", "%d m" % int(w.range), float(w.range) / wmax.range],
				["Rate of fire", "%d rounds / min" % int(rpm), rpm / wmax.rpm],
				["Accuracy", "%d%%" % int(float(w.acc) * 100.0), float(w.acc) / wmax.acc],
				["Sustained damage", "%.0f / s" % _dps(w), _dps(w) / wmax.dps],
				["Suppression", "%d per burst round" % int(w.supp), float(w.supp) / wmax.supp],
				["Bursts", "%d-%d rounds" % [bmin, bmax], -1.0],
				["Magazine / belt", ("%d" % int(w.mag)) + ("" if int(w.ammo) >= 9000 else "  (%d carried)" % int(w.ammo)), -1.0],
				["Reload", "%.1f s" % float(w.reload), -1.0],
			],
			"rel": ["Used by: " + ", ".join(users.get(k, []))]})

	# infantry
	var hmax: float = mx.call(Defs.UNITS, func(u): return u.hp)
	for k in Defs.UNITS:
		var u: Dictionary = Defs.UNITS[k]
		var wk: String = u.weapon
		var wd: Dictionary = Defs.WEAPONS.get(wk, {})
		var kit := []
		if int(u.frags) > 0:
			kit.append("%d frag grenade%s" % [int(u.frags), "s" if int(u.frags) > 1 else ""])
		if int(u.smokes) > 0:
			kit.append("%d smoke" % int(u.smokes))
		if int(u.get("rockets", 0)) > 0:
			kit.append("%d %s" % [int(u.rockets), "RPG-7 rockets" if int(u.team) == 1 else "AT rockets"])
		if int(u.get("mortar", 0)) > 0:
			kit.append("%d mortar bombs" % int(u.mortar))
		if int(u.get("drones", 0)) > 0:
			kit.append("%d FPV drones" % int(u.drones))
		var role := "rifleman"
		if u.get("medic", false):
			role = "medic"
		elif u.get("engineer", false):
			role = "engineer"
		elif int(u.get("rockets", 0)) > 0:
			role = "anti-tank"
		elif int(u.get("mortar", 0)) > 0:
			role = "indirect fire"
		elif int(u.get("drones", 0)) > 0:
			role = "drone operator"
		elif wk == "lmg":
			role = "automatic rifleman"
		elif u.get("bearer", false):
			role = "casualty evacuation"
		var st := [
			["Health", "%d" % int(u.hp), float(u.hp) / hmax],
			["Weapon", (String(wd.get("name", "unarmed")) + ("  (%d dmg, %d m)" % [int(wd.dmg), int(wd.range)] if not wd.is_empty() else "")), -1.0],
			["Kit", ", ".join(kit) if not kit.is_empty() else "-", -1.0],
		]
		if float(u.get("heal", 1.0)) > 1.0:
			st.append(["First aid", "x%.1f faster" % float(u.heal), -1.0])
		if float(u.get("build", 1.0)) > 1.0:
			st.append(["Building / digging", "x%.1f faster" % float(u.build), -1.0])
		out.append({"cat": "infantry", "key": k, "name": String(u.name), "team": int(u.team), "role": role,
			"sub": "%s · %d hp" % [String(wd.get("name", "unarmed")), int(u.hp)], "pattern": PATTERN.get(wk, "") if wk != "" else "",
			"desc": _unit_desc(k, u), "stats": st,
			"rel": (["In: " + ", ".join(squads_of.get(k, []))] if squads_of.has(k) else [])})

	# squads
	var cmax: float = mx.call(Defs.SQUADS, func(s): return s.cost)
	var fmax: float = mx.call(Defs.SQUADS, func(s): return _squad_fire(s))
	for k in Defs.SQUADS:
		var s: Dictionary = Defs.SQUADS[k]
		var names := []
		for m in s.members:
			names.append(String(Defs.UNITS[m].name))
		var free: bool = int(s.cost) == 0
		out.append({"cat": "squads", "key": k, "name": String(s.name), "team": int(s.team),
			"sub": ("%d men · %d supply" % [s.members.size(), int(s.cost)]) if not free else "%d men · comes with its vehicle" % s.members.size(),
			"desc": String(s.desc), "stats": [
				["Men", "%d" % s.members.size(), float(s.members.size()) / 6.0],
				["Firepower", "%.0f damage / s" % _squad_fire(s), _squad_fire(s) / fmax],
				["Cost", ("%d supply" % int(s.cost)) if not free else "-", float(s.cost) / cmax],
				["Training time", ("%d s" % int(s.time)) if not free else "-", -1.0],
			], "rel": ["Members: " + ", ".join(names), "Trained at: " + ("the Barracks" if not free else ("an IFV (Factory)" if int(s.team) == 0 else "a BTR (Factory)"))]})

	# vehicles
	var vhp: float = mx.call(Defs.VEHICLES, func(v): return v.hp)
	var vsp: float = mx.call(Defs.VEHICLES, func(v): return v.speed)
	var vco: float = mx.call(Defs.VEHICLES, func(v): return v.cost)
	for k in Defs.VEHICLES:
		var v: Dictionary = Defs.VEHICLES[k]
		var arm: String = ["none (soft-skinned)", "light (stops rifle fire)", "heavy (small arms bounce off)"][clampi(int(v.armor), 0, 2)]
		var guns := []
		if v.get("cannon", false):
			guns.append("main gun")
		if String(v.get("mg", "")) != "":
			guns.append(String(Defs.WEAPONS[v.mg].name))
		var where := "the Factory"
		for b in Defs.BUILDINGS:
			var pr: Array = Defs.BUILDINGS[b].get("produces", [[], []])
			for side_list in pr:
				if k in side_list:
					where = "the " + String(Defs.BUILDINGS[b].name)
		var st2 := [
			["Hit points", "%d" % int(v.hp), float(v.hp) / vhp],
			["Armour", arm, float(v.armor) / 2.0],
			["Top speed", "%d km/h" % int(float(v.speed) * 3.6), float(v.speed) / vsp],
			["Armament", ", ".join(guns) if not guns.is_empty() else "unarmed", -1.0],
			["Cost", ("%d supply" % int(v.cost)) if int(v.cost) > 0 else "-", float(v.cost) / vco],
			["Build time", ("%d s" % int(v.time)) if float(v.time) > 0.0 else "-", -1.0],
		]
		if v.has("carry"):
			st2.append(["Carries", "%s (%d men)" % [String(Defs.SQUADS[v.carry].name), Defs.SQUADS[v.carry].members.size()], -1.0])
		out.append({"cat": "vehicles", "key": k, "name": String(v.name), "team": int(v.team),
			"role": "aircraft" if v.get("air", false) or k == "heli" else ("tracked" if v.get("tracked", false) or k in ["tank", "old_tank"] else "wheeled"),
			"sub": "%d hp · %s" % [int(v.hp), ", ".join(guns) if not guns.is_empty() else "unarmed"], "pattern": PATTERN.get(k, ""),
			"desc": String(v.desc), "stats": st2, "rel": (["Built at " + where] if int(v.cost) > 0 else ["Drives supply from your depot to the FOBs"])})

	# buildings and defences
	var bhp: float = mx.call(Defs.BUILDINGS, func(b): return b.hp)
	var bco: float = mx.call(Defs.BUILDINGS, func(b): return b.cost)
	for k in Defs.BUILDINGS:
		var b: Dictionary = Defs.BUILDINGS[k]
		var tms: Array = b.teams
		var rel := []
		var pr2: Array = b.get("produces", [])
		for si in pr2.size():
			if not (pr2[si] as Array).is_empty():
				var nm := []
				for it in pr2[si]:
					nm.append(String(Defs.SQUADS[it].name) if Defs.SQUADS.has(it) else String(Defs.VEHICLES[it].name))
				rel.append("%s: %s" % [Defs.TEAM_NAMES[si], ", ".join(nm)])
		if k == "research":
			var ups := []
			for u2 in Defs.UPGRADES:
				ups.append(String(Defs.UPGRADES[u2].name))
			rel.append("Researches: " + ", ".join(ups))
		var crew := ""
		match k:
			"mg_nest":
				crew = "GPMG: %d dmg, %d m" % [int(Defs.WEAPONS.mmg.dmg), int(Defs.WEAPONS.mmg.range)]
			"hmg_nest":
				crew = ".50 cal: %d dmg, %d m, armour-piercing" % [int(Defs.WEAPONS.m2.dmg), int(Defs.WEAPONS.m2.range)]
		var st3 := [
			["Hit points", "%d" % int(b.hp), float(b.hp) / bhp],
			["Cost", "%d supply" % int(b.cost), float(b.cost) / bco],
			["Build time", "%d s (one engineer)" % int(b.time), -1.0],
			["Footprint", "%.1f x %.1f m" % [(b.size as Vector2).x, (b.size as Vector2).y], -1.0],
		]
		if crew != "":
			st3.insert(0, ["Crewed weapon", crew, -1.0])
		out.append({"cat": "bases" if k in BASES else "defences", "key": k, "name": String(b.name),
			"team": int(tms[0]) if tms.size() == 1 else -1, "both": tms.size() > 1,
			"sub": "%d supply · %d hp" % [int(b.cost), int(b.hp)], "pattern": PATTERN.get(k, ""),
			"desc": String(b.desc), "stats": st3, "rel": rel})

	# fire support
	var sco: float = mx.call(Defs.SUPPORT, func(s): return s.cost)
	var scd: float = mx.call(Defs.SUPPORT, func(s): return s.cooldown)
	var srr: float = mx.call(Defs.SUPPORT, func(s): return s.r)
	for k in Defs.SUPPORT:
		var s2: Dictionary = Defs.SUPPORT[k]
		if int(s2.team) < 0:
			continue
		var shape: String = {"line": "a line, dragged to set the run-in", "strafe": "a strafing line, dragged", "orbit": "an orbit over a circle", "circle": "a circle"}.get(String(s2.shape), String(s2.shape))
		out.append({"cat": "support", "key": k, "name": String(s2.name), "team": int(s2.team),
			"sub": "%d supply · every %d s" % [int(s2.cost), int(s2.cooldown)], "pattern": PATTERN.get(k, ""),
			"desc": String(s2.desc), "stats": [
				["Cost", "%d supply" % int(s2.cost), float(s2.cost) / sco],
				["Cooldown", "%d s" % int(s2.cooldown), float(s2.cooldown) / scd],
				["Area", "%d m radius" % int(s2.r), float(s2.r) / srr],
				["Aimed as", shape, -1.0],
			], "rel": ["Called from the support panel or Z, from minute five"]})

	# upgrades
	for k in Defs.UPGRADES:
		var up: Dictionary = Defs.UPGRADES[k]
		var ut: Array = up.teams
		out.append({"cat": "upgrades", "key": k, "name": String(up.name), "team": int(ut[0]) if ut.size() == 1 else -1, "both": ut.size() > 1,
			"sub": "%d supply · %d s" % [int(up.cost), int(up.time)], "desc": String(up.desc), "stats": [
				["Cost", "%d supply" % int(up.cost), -1.0], ["Research time", "%d s" % int(up.time), -1.0]],
			"rel": ["Researched at the Research Post"]})
	return out


## Damage per second over a long fight: bursts with the pauses between them,
## times the chance a round hits.
static func _dps(w: Dictionary) -> float:
	var b: Vector2i = w.burst
	var avg := (b.x + b.y) * 0.5
	var cycle := avg * float(w.interval) + 0.85
	return float(w.dmg) * float(w.acc) * avg / cycle


static func _squad_fire(s: Dictionary) -> float:
	var t := 0.0
	for m in s.members:
		var wk: String = Defs.UNITS[m].weapon
		if Defs.WEAPONS.has(wk):
			t += _dps(Defs.WEAPONS[wk])
	return t


func _unit_desc(k: String, u: Dictionary) -> String:
	if u.get("medic", false):
		return "Patches up the wounded under fire, drags them to cover and calls the stretcher bearers."
	if u.get("engineer", false):
		return "Builds bases and defences, digs trenches%s and repairs tracks." % (" and tunnels" if int(u.team) == 1 else "")
	if int(u.get("rockets", 0)) > 0:
		return "Hunts vehicles and bunkers with rockets; pops up from cover to fire."
	if int(u.get("mortar", 0)) > 0:
		return "Carries a light mortar and drops bombs on anything his side has spotted, behind cover too."
	if int(u.get("drones", 0)) > 0:
		return "Flies kamikaze FPV drones into infantry and armour from behind cover."
	if u.get("bearer", false):
		return "Carries the wounded and the dead back to the medic tent."
	if u.weapon == "lmg":
		return "The squad's automatic weapon: pins the enemy down so the riflemen can move. Crews MG nests."
	return "The backbone of the squad: fights from cover, throws grenades, moves by bounds."


## A thin bar of how a number compares with the rest of its kind.
class StatBar extends Control:
	var frac := 0.0
	var col := Color.WHITE

	func _draw() -> void:
		if frac < 0.0:
			return
		var r := Rect2(Vector2(0, size.y * 0.5 - 3), Vector2(size.x, 6))
		draw_rect(r, Color(1, 1, 1, 0.08))
		draw_rect(Rect2(r.position, Vector2(size.x * clampf(frac, 0.02, 1.0), 6)), col)
