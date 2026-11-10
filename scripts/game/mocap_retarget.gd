class_name MocapRetarget
extends RefCounted
## Rest-space rotation retargeting onto Frontline's articulated rig. The source
## has a T pose; the game's arms hang down, so binding explicitly matches poses.
## Limb lengths stay those of the target, not the mannequin.

const MAP := {
	"hips": "Hips", "torso": "Spine2", "head": "Head",
	"arm_l": "LeftArm", "forearm_l": "LeftForeArm",
	"arm_r": "RightArm", "forearm_r": "RightForeArm",
	"thigh_l": "LeftUpLeg", "shin_l": "LeftLeg",
	"thigh_r": "RightUpLeg", "shin_r": "RightLeg",
}

var target: SoldierModel
var source: MocapCharacter
var joints: Array[Node3D] = []
var bones: Array[int] = []
var corrections: Array[Basis] = []
var hip_rest := Vector3.ZERO
var height_ratio := 1.0


func bind(model: SoldierModel, actor: MocapCharacter) -> bool:
	target = model
	source = actor
	model.arm_l.rotation.z = -PI * 0.5
	model.arm_r.rotation.z = PI * 0.5
	var source_space := actor.global_transform.affine_inverse() * actor.skeleton.global_transform
	var target_space := model.global_transform.affine_inverse()
	for key in HumanoidRig.ORDER:
		var index := actor.skeleton.find_bone(MAP[key])
		if index < 0:
			push_error("Missing retarget bone " + MAP[key])
			return false
		var node: Node3D = model.get(key)
		var rest := source_space * actor.skeleton.get_bone_global_rest(index)
		var target_rest := target_space * node.global_transform
		joints.append(node)
		bones.append(index)
		corrections.append(rest.basis.orthonormalized().inverse() * target_rest.basis.orthonormalized())
		if key == "hips":
			hip_rest = rest.origin
			height_ratio = SoldierModel.H0 / maxf(0.1, rest.origin.y)
	model.pistol.visible = false
	model.nade.visible = false
	return true


func apply(dt: float) -> void:
	if target.ragdoll != null or target.ragdoll_done:
		return
	var space := source.global_transform.affine_inverse() * source.skeleton.global_transform
	var hip := space * source.skeleton.get_bone_global_pose(bones[0])
	target.hips.position = Vector3(0, SoldierModel.H0 + (hip.origin.y - hip_rest.y) * height_ratio, 0)
	for i in joints.size():
		var pose := space * source.skeleton.get_bone_global_pose(bones[i])
		joints[i].global_basis = target.global_basis * pose.basis.orthonormalized() * corrections[i]
	target.torso.rotation += target.motion.hit.step(dt)
	# The existing rifle has a different grip convention from the supplied M4.
	# Seat it at the trigger hand and point the barrel through the support hand.
	var right := target.forearm_r.global_transform * Vector3(0, -SoldierModel.LOWER, 0)
	var left := target.forearm_l.global_transform * Vector3(0, -SoldierModel.LOWER, 0)
	var forward := (left - right).normalized()
	if forward.length_squared() > 0.9 and absf(forward.dot(Vector3.UP)) < 0.98:
		target.gun.global_basis = Basis.looking_at(forward, Vector3.UP)
		target.gun.global_position = right + target.gun.global_basis.y * 0.07
