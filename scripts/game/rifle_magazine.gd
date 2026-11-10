extends RefCounted
## Separate the vendor M4's disconnected magazine geometry without changing
## its UVs or material. The rifle and magazine then have independent transforms.
static var body_mesh: ArrayMesh
static var magazine_mesh: ArrayMesh
var mesh: MeshInstance3D
var receiver: MeshInstance3D
var hand_socket := Transform3D.IDENTITY
var actor: SkinnedRifleman
var detached_weight := 0.0
const GRIP := Vector3(0, -0.035, 0.145)

func setup(character: SkinnedRifleman) -> void:
	actor = character
	receiver = actor.weapon.find_children("*", "MeshInstance3D", true, false)[0]
	if body_mesh == null: _split(receiver.mesh)
	if magazine_mesh == null: return
	receiver.mesh = body_mesh
	mesh = MeshInstance3D.new()
	mesh.mesh = magazine_mesh
	mesh.material_override = receiver.material_override
	receiver.add_child(mesh)

static func _root(parents: PackedInt32Array, index: int) -> int:
	while parents[index] != index: index = parents[index]
	return index

static func _split(original: Mesh) -> void:
	var arrays := original.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parents := PackedInt32Array()
	parents.resize(vertices.size())
	var welded := {}
	for i in vertices.size():
		parents[i] = i
		var key := Vector3i((vertices[i] * 100000.0).round())
		if welded.has(key): parents[i] = welded[key]
		else: welded[key] = i
	for i in range(0, indices.size(), 3):
		var a := _root(parents, indices[i])
		for corner in [1, 2]:
			var b := _root(parents, indices[i + corner])
			parents[b] = a
	var low := 0
	for i in vertices.size():
		if vertices[i].y < vertices[low].y: low = i
	var magazine_root := _root(parents, low)
	var body_indices := PackedInt32Array()
	var mag_indices := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var is_mag := _root(parents, indices[i]) == magazine_root
		for corner in 3:
			if is_mag: mag_indices.append(indices[i + corner])
			else: body_indices.append(indices[i + corner])
	# This adapter is deliberately specific to the supplied M4, not arbitrary
	# weapons: fail closed if its geometry changes rather than remove a barrel.
	if mag_indices.size() < 100 or mag_indices.size() > 2000:
		push_error("M4 magazine component could not be identified")
		return
	body_mesh = ArrayMesh.new()
	arrays[Mesh.ARRAY_INDEX] = body_indices
	body_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, original.surface_get_format(0))
	magazine_mesh = ArrayMesh.new()
	arrays[Mesh.ARRAY_INDEX] = mag_indices
	magazine_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, original.surface_get_format(0))

func calibrate() -> void:
	if mesh == null: return
	var hand := actor.joint("LeftHand")
	hand_socket = hand.affine_inverse() * receiver.global_transform
	# Different rifle proportions must not leave the detached prop floating
	# at the source weapon's magwell offset from the animated palm.
	hand_socket.origin = hand.affine_inverse() * actor.joint("LeftHandMiddle1").origin - hand_socket.basis * GRIP

func update(seconds: float, active: bool) -> void:
	if mesh == null: return
	detached_weight = 0.0
	mesh.transform = Transform3D.IDENTITY
	# The old magazine is stowed before the replacement leaves the pouch.
	# Derive visibility from clip time so scrubbing and replay restore it too.
	mesh.visible = not active or seconds < 0.68 or seconds >= 1.12
	if not active: return
	# Release, pouch visit, and insertion follow the captured reload. Contact
	# correction is strongest at the magwell and releases the arm in between.
	var contact := (1.0 - smoothstep(0.40, 0.62, seconds)) * smoothstep(0.12, 0.32, seconds)
	contact = maxf(contact, smoothstep(1.65, 1.95, seconds) * (1.0 - smoothstep(2.1, 2.35, seconds)))
	if contact > 0.0:
		var hand := actor.joint("LeftHand")
		var fingers := actor.joint("LeftHandMiddle1").origin
		var target := receiver.global_transform * GRIP - (fingers - hand.origin)
		actor.solve_limb("LeftArm", "LeftForeArm", "LeftHand", hand.origin.lerp(target, contact), actor.joint("LeftForeArm").origin - actor.joint("LeftArm").origin)
	var detached := smoothstep(0.40, 0.62, seconds) * (1.0 - smoothstep(1.65, 1.95, seconds))
	detached_weight = detached
	mesh.global_transform = receiver.global_transform.interpolate_with(actor.joint("LeftHand") * hand_socket, detached)
