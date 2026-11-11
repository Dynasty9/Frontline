extends "res://scripts/main.gd"
## A camera move on the simulation clock. Land shots measure height from the
## original terrain, so digging a trench does not pull the camera underground.

@export var first_eye: Vector3
@export var last_eye: Vector3
@export var subject: Vector3
@export var travel_seconds: Vector2
@export var relative_to_land := true

@onready var lens: Camera3D = $Camera3D


func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world):
		return
	var fraction := smoothstep(travel_seconds.x, travel_seconds.y, world.time)
	lens.position = _world_point(first_eye.lerp(last_eye, fraction))
	lens.look_at(_world_point(subject))
	if not lens.current:
		lens.make_current()


func _world_point(point: Vector3) -> Vector3:
	if relative_to_land:
		point.y += world.terrain.landform.height(point)
	return point
