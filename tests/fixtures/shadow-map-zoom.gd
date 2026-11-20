extends Node
## Renderer map coverage only: no world, emitters, or simulation.
func _ready() -> void:
	var previous := SmokeShadow.map_span(0.0)
	assert(previous == 256.0)
	for i in range(1, 10001):
		var distance := i * 0.05
		var span := SmokeShadow.map_span(distance)
		assert(span >= previous and span >= 256.0 and span <= 1024.0)
		assert(span - previous < 1.0, "A small zoom step must not double the reconstruction filter")
		previous = span
	assert(previous == 1024.0)
	for boundary in [60.0, 70.0, 80.0, 100.0, 160.0, 180.0, 200.0]:
		assert(absf(SmokeShadow.map_span(boundary + 0.001) - SmokeShadow.map_span(boundary - 0.001)) < 0.05)
	for pair in [[0.0, 256.0], [55.0, 256.0], [90.0, 512.0], [150.0, 512.0], [220.0, 1024.0]]:
		assert(SmokeShadow.map_span(pair[0]) == pair[1], "Coverage away from transitions stays unchanged")
	print("SHADOW_MAP_ZOOM passed")
	get_tree().quit()
