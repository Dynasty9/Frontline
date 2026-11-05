extends Node


func _ready() -> void:
	assert(ClassDB.class_exists("SimulationRandomCore"))
	var actual := SimulationRandom.new()
	var expected := RandomNumberGenerator.new()
	for initial in [0, 1, 3, 4719, -1, -9223372036854775807, 9223372036854775807]:
		actual.seed = initial
		expected.seed = initial
		assert(actual.seed == expected.seed and actual.state == expected.state)
		for i in 10000:
			match i % 6:
				0:
					assert(actual.randi() == expected.randi())
				1:
					assert(actual.randf() == expected.randf())
				2:
					assert(actual.randf_range(-18.7, 916.4) == expected.randf_range(-18.7, 916.4))
				3:
					assert(actual.randi_range(35, -17) == expected.randi_range(35, -17))
				4:
					assert(actual.randi_range(-2147483648, 2147483647) == expected.randi_range(-2147483648, 2147483647))
				5:
					assert(actual.randi_range(11, 11) == expected.randi_range(11, 11))
			assert(actual.state == expected.state, "Draw count and state must match Godot")
		var saved := actual.state
		var next := actual.randi()
		actual.state = saved
		assert(actual.randi() == next)
	# Literal reference vectors let standalone Rust tests check compatibility too.
	expected.seed = 3
	var values := []
	for i in 8:
		values.append(expected.randi())
	print("RNG_REFERENCE ", values, " state=", expected.state)
	print("SIMULATION_RANDOM passed")
	get_tree().quit()
