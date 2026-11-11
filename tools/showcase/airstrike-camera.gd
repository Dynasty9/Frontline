extends "res://scripts/main.gd"
## Photograph the same live flyover from a nearby aircraft.

@export var formation_pass := false
var camera: Camera3D
var subject: Node3D
var forward: Vector3
var right: Vector3

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world):
		return
	if not is_instance_valid(subject):
		for plane in world.projectiles:
			if plane.ptype != "jet" or not is_instance_valid(plane.model):
				continue
			subject = plane
			forward = plane.vel.normalized()
			right = forward.cross(Vector3.UP)
			camera = Camera3D.new()
			plane.add_child(camera)
			camera.fov = 48.0
			camera.position = right * 12.0 - forward * 19.0 + Vector3.UP * 8.0
			camera.look_at(plane.global_position + forward * 2.0)
			camera.make_current()
			break
	if formation_pass and is_instance_valid(subject):
		# The camera aircraft keeps its course while the faster jet overtakes it.
		var elapsed := clampf(world.time - 4.3, -0.5, 2.6)
		camera.global_position = subject.global_position - right * 17.0 + forward * (9.0 - elapsed * 9.0) + Vector3.UP * 8.0
		camera.look_at(subject.global_position + forward * 1.2)
