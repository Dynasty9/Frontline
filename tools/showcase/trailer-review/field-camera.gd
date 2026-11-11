extends "res://scripts/main.gd"
## A camera move measured from the terrain before the trench was dug. The
## simulation runs normally, including the men crossing in front of the lens.

@export var first_eye: Vector3
@export var last_eye: Vector3
@export var subject: Vector3
@export var travel_seconds: Vector2

@onready var lens: Camera3D = $Camera3D


func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world):
		return
	var fraction := smoothstep(travel_seconds.x, travel_seconds.y, world.time)
	lens.position = _above_land(first_eye.lerp(last_eye, fraction))
	lens.look_at(_above_land(subject))
	if not lens.current:
		lens.make_current()


func _above_land(point: Vector3) -> Vector3:
	point.y += world.terrain.landform.height(point)
	return point
