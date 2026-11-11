extends "res://scripts/main.gd"
## A chase angle on the same live flyover seen from the shore camera.

var filmed := false

func _process(dt: float) -> void:
	super._process(dt)
	if filmed or not is_instance_valid(world):
		return
	for plane in world.projectiles:
		if plane.ptype != "jet" or not is_instance_valid(plane.model):
			continue
		var camera := Camera3D.new()
		plane.add_child(camera)
		var forward: Vector3 = plane.vel.normalized()
		var right := forward.cross(Vector3.UP)
		camera.position = right * 12.0 - forward * 19.0 + Vector3.UP * 8.0
		camera.fov = 48.0
		camera.look_at(plane.global_position + forward * 2.0)
		camera.make_current()
		filmed = true
		break
