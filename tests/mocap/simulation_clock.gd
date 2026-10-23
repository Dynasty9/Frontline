extends Node

class ClockWorld extends World:
	var steps := 0
	var elapsed := 0.0
	func _simulate(dt: float) -> void:
		steps += 1
		elapsed += dt

func _ready() -> void:
	var original_hz := Engine.physics_ticks_per_second
	var original_scale := Engine.time_scale
	for hz in [60, 120]:
		Engine.physics_ticks_per_second = hz
		for scale in [0.5, 1.0, 5.0]:
			Engine.time_scale = scale
			var clock := ClockWorld.new()
			for frame in hz * 2:
				clock._physics_process(scale / hz)
			assert(clock.steps == 120, "Battle cadence followed the physics rate")
			assert(absf(clock.elapsed - 2.0 * scale) < 0.000001, "Simulation lost elapsed time")
			clock.free()
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 1.0
	var clock := ClockWorld.new()
	var unit := Entity.new()
	unit.world = clock
	unit.ip_capture()
	unit.position.x = 1.0
	unit.ip_capture()
	clock._physics_process(1.0 / 120.0)
	assert(clock.steps == 0)
	var halfway := (unit.transform * unit.ip_offset()).origin.x
	assert(halfway >= 0.5 and halfway <= 1.0, "Host motion restarted interpolation at the intermediate physics tick")
	clock._physics_process(1.0 / 120.0)
	assert(clock.steps == 1 and absf(clock.elapsed - 1.0 / 60.0) < 0.000001)
	Engine.time_scale = 0.0
	clock._physics_process(0.0)
	assert(clock.steps == 1 and clock.simulation_fraction() == 0.0)
	unit.free()
	clock.free()
	Engine.physics_ticks_per_second = original_hz
	Engine.time_scale = original_scale
	print("SIMULATION CLOCK PASS 60/120 Hz, slow/normal/fast time, intermediate interpolation and pause")
	get_tree().quit()
