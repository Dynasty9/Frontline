extends ColorRect
## Record the game's score in isolation so a picture cut never restarts a phrase.
## The same take supplies the menu wordmark when an edit calls for an end title.

var elapsed := 0.0
var resolved := false

func _ready() -> void:
	Settings.no_save = true
	Settings.v.merge({"volume": 1.0, "vol_music": 1.0, "battle_music": true, "mute_bg": false}, true)
	Settings.apply_global()
	Settings.changed.emit()

	var map := TopoBackdrop.new()
	map.shade = 1.0
	add_child(map)
	move_child(map, 0)

	var row: HBoxContainer = $Center/Title/Row
	var emblem := preload("res://scripts/ui/menu.gd").Emblem.new()
	emblem.custom_minimum_size = Vector2(84, 84)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(emblem)
	var title := UiKit.label("FRONTLINE", 108, UiKit.TEXT, 700)
	var font := FontVariation.new()
	font.base_font = UiKit.font(700)
	font.spacing_glyph = 10
	title.add_theme_font_override("font", font)
	row.add_child(title)
	var invitation := UiKit.label("Play for free on Windows, macOS and Linux", 43, UiKit.TEXT, 600)
	invitation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/Title.add_child(invitation)
	var license_line := UiKit.label("OPEN SOURCE  ·  MIT LICENSE", 29, UiKit.TEXT, 600)
	license_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Center/Title.add_child(license_line)

	# Finish the instrument render before frame zero. Otherwise a faster GPU
	# could move the first note several beats later in the recorded movie.
	if Music._task >= 0:
		while not WorkerThreadPool.is_task_completed(Music._task):
			OS.delay_msec(5)
	Music._rng.seed = 3
	Music.play_cue("battle")

func _process(dt: float) -> void:
	elapsed += dt
	Music.heat = lerpf(0.25, 1.0, smoothstep(1.0, 19.0, elapsed))
	if not resolved and elapsed >= 21.5:
		resolved = true
		Music.sting("victory")
