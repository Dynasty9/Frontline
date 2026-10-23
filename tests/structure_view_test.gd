extends Node

class ViewStub extends Structure:
	var builds := 0
	func set_view_active(value: bool) -> void:
		view_active = value
		if value:
			builds += 1

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	var world := World.new()
	var view := StructureView.new()
	view.world = world
	view.focus_at(Vector3.ZERO)
	var near := ViewStub.new()
	near.eid = 1
	near.view_active = false
	var far := ViewStub.new()
	far.eid = 2
	far.position = Vector3(1400, 0, 0)
	far.view_active = false
	view.add(near)
	view.add(far)
	check(view.warming() and view.pending.size() == 1, "Only nearby scenery should delay initial loading")
	view._process(0.016)
	check(near.builds == 1 and far.builds == 0 and not view.warming(), "Distant scenery must remain unbuilt")
	view.focus_at(far.position)
	view._process(0.016)
	check(not near.view_active and far.view_active, "Moving across the map must switch active scenery")
	view.focus_at(Vector3.ZERO)
	view.remove(near)
	near.free()
	view._process(0.016)
	check(view.pending.is_empty() and not view.resident.has(1), "Despawn during queued construction must leave no stale reference")
	far.position = Vector3.ZERO
	view.remove(far)
	check(view.cells.is_empty() and view.memberships.is_empty(), "Removing a moved structure must clear its original spatial membership")
	far.free()
	view.free()
	world.has_view = true
	var actual := Structure.new()
	actual.world = world
	actual.skind = "tall_wall"
	actual.built = false
	actual.defer_view = true
	world.add_child(actual)
	actual.on_spawned()
	check(actual.model == null and actual.body == null, "Deferred scenery must not allocate models or cosmetic bodies")
	actual.set_view_active(true)
	check(actual.model != null and actual.body == null, "An unfinished visible wall must draw without completed collision")
	actual.set_view_active(false)
	actual.built = true
	actual.set_view_active(true)
	check(actual.body != null and actual.body.collision_layer == Defs.L_COVER, "Construction completed off-screen must gain collision when revisited")
	actual.team = 0
	actual._recolor()
	check(actual.is_processing(), "Capturing neutral scenery must resume ownership and fog updates")
	actual.set_view_active(false)
	check(not actual.model.visible and actual.body.collision_layer == 0, "Inactive scenery must leave rendering and cosmetic collision")
	world.free()
	print("STRUCTURE_VIEW_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
