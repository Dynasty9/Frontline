extends Curtain
## Record the game's score in isolation so a picture cut never restarts a phrase.
## The same take supplies the menu wordmark when an edit calls for an end title.

const CARD_START := 10.0

var elapsed := 0.0
var resolved := false


func _ready() -> void:
	super._ready()
	Settings.no_save = true
	Settings.v.merge({"volume": 1.0, "vol_music": 1.0, "battle_music": true, "mute_bg": false}, true)
	Settings.apply_global()
	Settings.changed.emit()

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
	hold_at = maxf(0.0, elapsed - CARD_START)
	super._process(dt)
	_map.zoom = 1.0 + 0.27 * smoothstep(0.0, 8.0, hold_at)
	if not resolved and elapsed >= 34.7:
		resolved = true
		Music.sting("victory")


func _draw() -> void:
	super._draw()
	var reveal := smoothstep(0.65, 1.25, hold_at)
	if reveal == 0:
		return
	var u := size.y / 1080.0
	var baseline := Vector2(0, size.y * 0.76)
	draw_string(UiKit.font(600), baseline, "Play for free on Windows, macOS and Linux", HORIZONTAL_ALIGNMENT_CENTER, size.x, roundi(40 * u), Color(WORD, reveal))
	draw_string(UiKit.font(600), baseline + Vector2(0, 55 * u), "OPEN SOURCE  ·  MIT LICENSE", HORIZONTAL_ALIGNMENT_CENTER, size.x, roundi(27 * u), Color(SAND, reveal))
