extends "res://scripts/main.gd"
## Staged work orders and idle choice, using normal battle entities and animation.
var worker
var smoker
var inspection: Camera3D
var started := -1.0
var saw_build := false
var saw_smoke := false
var hit := false
var soldier_script: Script

func _ready() -> void:
	name = "Main"
	super._ready()

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world) or not world.loaded or not world.srv: return
	if worker == null:
		soldier_script = GameScripts.load_script("res://scripts/game/soldier.gd")
		var at := Vector3(40, 0, 40)
		var work = world.spawn("structure", {"skind":"sandbags", "team":0, "pos":at + Vector3(0,0,-2), "built":false, "progress":0.0})
		worker = world.spawn("soldier", {"utype":"rifleman", "team":0, "pos":at})
		worker.start_build(work)
		smoker = world.spawn("soldier", {"utype":"rifleman", "team":0, "pos":at + Vector3(4,0,0)})
		smoker.hold_pos = smoker.position
		smoker.calm_t = 30.0
		smoker.last_shot_t = -100.0
		smoker.idle_act = soldier_script.Act.IDLE_SMOKE
		smoker.idle_until = world.time + 30.0
		started = world.time
		inspection = Camera3D.new()
		world.add_child(inspection)
		inspection.fov = 40
		return
	var elapsed: float = world.time - started
	saw_build = saw_build or worker.act == soldier_script.Act.BUILD
	saw_smoke = saw_smoke or smoker.act == soldier_script.Act.IDLE_SMOKE
	var focus: Vector3 = smoker.position if elapsed >= 6.0 and elapsed < 12.0 else worker.position
	inspection.position = focus + Vector3(3,1.8,3)
	inspection.look_at(focus + Vector3(0,0.8,0))
	inspection.make_current()
	if elapsed > 13.0 and not hit:
		hit = true
		worker.take_damage(1000.0, null, Vector3.RIGHT, "bullet")
	if elapsed > 18.0:
		print("GAME ACTIVITIES build=", saw_build, " smoke=", saw_smoke, " hit=", hit)
		if not saw_build or not saw_smoke: TestRun.fail()
		TestRun.quit(get_tree())
