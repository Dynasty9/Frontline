extends Node


func _ready() -> void:
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var motion := HumanoidMotion.new()
		motion.react(direction, 0.5)
		var tilt := motion.hit.step(0.08)
		var displaced := Basis.from_euler(tilt) * Vector3.UP - Vector3.UP
		if displaced.dot(direction) <= 0.0:
			fail("A hit bends the body toward the shooter instead of away")
			return
	# A distant unit updated once must recover like a nearby unit updated at 60 Hz.
	var near := ImpactResponse.new()
	var far := ImpactResponse.new()
	near.kick(Vector3(2, -1, 0.5))
	far.kick(Vector3(2, -1, 0.5))
	for i in 30:
		near.step(1.0 / 60.0)
	far.step(0.5)
	if near.offset.distance_to(far.offset) > 0.00001 or near.velocity.distance_to(far.velocity) > 0.00001:
		fail("Impact recovery depends on rendering frequency")
		return
	for i in 100:
		near.kick(Vector3(100, 0, 0))
	if near.velocity.length() > 3.001:
		fail("Repeated hits exceed the bounded reaction")
		return
	near.step(10.0)
	if not near.offset.is_finite() or near.offset.length() > 0.001:
		fail("A long frame leaves an unstable reaction")
		return
	var travel := Vector3(0, 0, -4)
	for part in HumanoidRig.ORDER:
		if not ImpactResponse.death_velocity(travel, Vector3.ZERO, 2, part).is_equal_approx(travel):
			fail("A collapsing limb loses the soldier's movement")
			return
	print("IMPACT_TEST passed: hit direction, frame-rate independence, bounded repeated hits, recovery and momentum")
	get_tree().quit()


func fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
