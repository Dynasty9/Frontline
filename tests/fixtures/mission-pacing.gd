extends Node

class RaisedWorld extends World:
	func ground_y(_p: Vector3) -> float:
		return 12.0

class ReviewMissions extends Missions:
	var mortar_calls := 0

	func _enemy_support(_d: MissionDirector, _kind: String, _pos: Vector3) -> void:
		mortar_calls += 1

class TestMissionDirector extends MissionDirector:
	var friendly := 1
	var enemies := 0

	func _init() -> void:
		pass

	func radio(_text: String, _ping = null) -> void:
		pass

	func win(text: String) -> void:
		over = 1
		end_text = text

	func fail(text: String) -> void:
		over = 2
		end_text = text

	func afoot_in(_c: Vector3, _r: float) -> int:
		return friendly

	func foes_in(_c: Vector3, _r: float) -> int:
		return enemies


func _ready() -> void:
	var w := World.new()
	w.has_view = false
	var d := TestMissionDirector.new()
	d.world = w
	var m := ReviewMissions.new()
	var tank := Vehicle.new()
	m.ctx = {"east": Vector3.ZERO, "relief": [tank]}
	tank.position = Vector3(100, 0, 0)
	m._bridgehead_relief(d)
	assert(d.over == 0, "A distant relief tank must not end the mission")
	tank.track_broken = true
	m._bridgehead_relief(d)
	assert(d.over == 2, "An immobilised relief force cannot leave the mission waiting forever")
	d.over = 0
	tank.track_broken = false
	tank.position = Vector3(20, 0, 0)
	d.enemies = 1
	m._bridgehead_relief(d)
	assert(d.over == 0, "Clear the bridgehead before handing it over")
	d.enemies = 0
	d.friendly = 0
	m._bridgehead_relief(d)
	assert(d.over == 0, "The player cannot abandon the bridgehead")
	d.friendly = 1
	tank.track_broken = true
	d._events.clear()
	m._bridgehead_relief(d)
	assert(d.over == 0 and d._events.size() == 1, "Let the player see the handover before the report")
	assert(d._events[0][0] == w.time + 6.0)
	(d._events[0][1] as Callable).call()
	assert(d.over == 1, "A tank immobilised after reaching the position still provides relief")
	d.over = 0
	tank.hp = 0
	m._bridgehead_relief(d)
	assert(d.over == 2, "Destroyed relief must fail instead of waiting forever")
	d._events.clear()
	d.over = 0
	var delivered := d.add("deliver", "Deliver", "deliver")
	var column := d.add("column", "Column", "destroy")
	column.state = MissionDirector.DONE
	m._skyhook_finish(d)
	assert(d.over == 0, "Destroying armour does not replace the airlift")
	delivered.state = MissionDirector.DONE
	column.state = MissionDirector.ACTIVE
	m._skyhook_finish(d)
	assert(d.over == 0, "Delivery alone does not win")
	column.state = MissionDirector.DONE
	m._skyhook_finish(d)
	assert(d.over == 1)
	d.over = 0
	tank.hp = tank.max_hp
	m.ctx = {"convoy": [tank], "kz": Vector3.ZERO}
	var qrf := d.add("qrf", "Reaction force", "timer", {"secs": 45.0})
	m._ambush_contact(d)
	assert(qrf.state == MissionDirector.HIDDEN, "A quiet convoy does not summon the QRF")
	tank.hp -= 1.0
	m._ambush_contact(d)
	assert(qrf.state == MissionDirector.ACTIVE, "First damage starts the response clock")
	qrf.prog = 12.0
	m._ambush_contact(d)
	assert(qrf.prog == 12.0, "More damage must not restart the response clock")
	tank.free()
	qrf.state = MissionDirector.HIDDEN
	m._ambush_contact(d)
	assert(qrf.state == MissionDirector.ACTIVE, "A destroyed lead vehicle also raises the alarm")
	var target := Soldier.new()
	target.eid = 7
	target.team = d.foe
	w.entities[target.eid] = target
	target.position = Vector3(70, 0, 0)
	m.ctx = {"hvt": target, "hv": Vector3.ZERO}
	var hvt := d.add("hvt", "Target", "destroy", {"pos": Vector3.ZERO})
	hvt.state = MissionDirector.ACTIVE
	m._kingpin_watch(d)
	assert(hvt.pos == Vector3.ZERO, "An unseen target must not move the objective marker")
	target.vis_mask = 1 << d.side
	m._kingpin_watch(d)
	assert(hvt.pos == target.position, "A sighting updates the last known location")
	target.vis_mask = 0
	target.position = Vector3(110, 0, 0)
	m._kingpin_watch(d)
	assert(hvt.pos == Vector3(70, 0, 0), "Losing sight preserves the last known location")
	d._events.clear()
	m.ctx = {"east": Vector3.ZERO, "e": Vector3.RIGHT}
	d.add("spotters", "Observers", "destroy", {"eids": [target.eid]})
	m._bridgehead_mortars(d)
	assert(m.mortar_calls == 1 and d._events.size() == 1, "Live observers sustain the mortar threat")
	target.life = Soldier.Life.SURRENDER
	d._events.clear()
	m._bridgehead_mortars(d)
	assert(m.mortar_calls == 1 and d._events.is_empty(), "Neutralising observers cuts off further fire")
	d.obj("spotters").state = MissionDirector.DONE
	target.life = Soldier.Life.ALIVE
	m._bridgehead_mortars(d)
	assert(m.mortar_calls == 1 and d._events.is_empty(), "A completed disruption stays effective if a casualty is later revived")
	d.objs.clear()
	d.over = 0
	d.friendly = 3
	d.enemies = 1
	var quay := d.add("quay", "Hold the quay", "hold", {"secs": 1.0, "afoot": true, "clear_end": true})
	d.start("quay")
	d._evaluate(1.0)
	assert(quay.state == MissionDirector.ACTIVE, "A landing area must be clear, even when defenders outnumber the attackers")
	assert(d._prog_text(quay) == "clear area", "An expired timer explains what still blocks victory")
	d.enemies = 0
	d._evaluate(0.5)
	assert(quay.state == MissionDirector.DONE, "The defence ends once the timer is up and the quay is clear")
	d.objs.clear()
	target.free()
	w.mission_info = {"over": 1, "objs": [
		["A", "Required", MissionDirector.DONE, "clear", null, 30, "", false],
		["", "Saved transport", MissionDirector.DONE, "protect", null, 30, "", true],
		["", "Lost transport", MissionDirector.FAILED, "protect", null, 30, "", true],
		["", "Remaining target", MissionDirector.ACTIVE, "destroy", null, 30, "", true]]}
	var hud := Hud.new()
	hud.world = w
	var header := VBoxContainer.new()
	var facts := hud._mission_head(header)
	assert("OBJECTIVES 1/1" in facts, "Optional challenges do not inflate required completion")
	var bonus: Label = header.get_child(header.get_child_count() - 1)
	assert(bonus.text == "OPTIONAL OBJECTIVES 1/3", "The report distinguishes completed, failed and unfinished optional objectives")
	assert("Complete: Saved transport" in bonus.tooltip_text and "Not completed: Remaining target" in bonus.tooltip_text)
	assert(bonus.mouse_filter == Control.MOUSE_FILTER_PASS, "Optional results can be inspected on hover")
	header.free()
	hud.free()
	w.free()
	_test_elevated_objectives()
	var report := StatsPanel.new()
	report.report = {"t": 209.0}
	var page := StatsPanel._Summary.new()
	page.p = report
	assert(not page.begin(), "A populated report must wait for its page width before drawing")
	page.free()
	report.free()
	print("MISSION_PACING passed")
	get_tree().quit()


func _test_elevated_objectives() -> void:
	var w := RaisedWorld.new()
	w.has_view = false
	var d := MissionDirector.new(w, "skyhook", null)
	var v := Vehicle.new()
	v.eid = 1
	v.team = d.side
	v.owner_peer = d.owners[0]
	v.position = Vector3(0, 12.0, 0)
	w.vehicles.append(v)
	w.entities[v.eid] = v
	assert(d.ours_in(Vector3.ZERO, 20.0) == 1, "Grounded armour holds elevated ground")
	v.team = d.foe
	assert(d.foes_in(Vector3.ZERO, 20.0) == 1, "Enemy armour contests elevated ground")
	v.team = d.side
	v.position.y = 20.0
	assert(d.ours_in(Vector3.ZERO, 20.0) == 0, "Airborne vehicles do not hold ground")
	var passenger := Soldier.new()
	passenger.team = d.side
	passenger.owner_peer = d.owners[0]
	passenger.life = Soldier.Life.HIDDEN
	passenger.riding = v
	w.soldiers.append(passenger)
	assert(d.ours_in(Vector3.ZERO, 20.0) == 0, "Airborne passengers do not capture ground either")
	passenger.team = d.foe
	assert(d.foes_in(Vector3.ZERO, 20.0) == 0, "Airborne passengers do not contest ground")
	v.position.y = 12.0
	assert(d.foes_in(Vector3.ZERO, 20.0) == 1, "Landed enemy passengers still contest ground")
	passenger.team = d.side
	assert(d.ours_in(Vector3.ZERO, 20.0) == 2, "Landed troops and their transport count on elevated ground")
	w.soldiers.clear()
	passenger.free()
	v.position.y = 20.0
	var o := d.add("deliver", "Deliver on the hill", "deliver", {"pos": Vector3.ZERO, "r": 20.0, "eids": [v.eid]})
	d.start("deliver")
	d._evaluate(0.5)
	assert(o.state == MissionDirector.ACTIVE)
	v.position.y = 12.0
	v.slung_by = Vehicle.new()
	d._evaluate(0.5)
	assert(o.state == MissionDirector.ACTIVE, "Suspended cargo must be released")
	v.slung_by.free()
	v.slung_by = null
	d._evaluate(0.5)
	assert(o.state == MissionDirector.DONE, "Released cargo on the hill is delivered")
	v.free()
	w.free()
