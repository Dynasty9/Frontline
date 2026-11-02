class_name HumanoidRig
extends RefCounted
## Shared joint names, collision shapes, masses and limits for human bodies.
## Models expose these joints; their clothing and weapons do not change the rig.

const ORDER := ["hips", "torso", "head", "arm_l", "forearm_l", "arm_r", "forearm_r", "thigh_l", "shin_l", "thigh_r", "shin_r"]
## part: [parent, shape, size, shape offset from the joint, mass]
const SPEC := {
	"hips": ["", "box", Vector3(0.34, 0.2, 0.22), Vector3(0, -0.02, 0), 12.0],
	"torso": ["hips", "box", Vector3(0.4, 0.56, 0.25), Vector3(0, 0.3, 0), 22.0],
	"head": ["torso", "sphere", Vector3(0.12, 0, 0), Vector3(0, 0.14, 0), 5.0],
	"arm_l": ["torso", "capsule", Vector3(0.055, 0.3, 0), Vector3(0, -0.14, 0), 2.6],
	"forearm_l": ["arm_l", "capsule", Vector3(0.05, 0.32, 0), Vector3(0, -0.15, 0), 1.8],
	"arm_r": ["torso", "capsule", Vector3(0.055, 0.3, 0), Vector3(0, -0.14, 0), 2.6],
	"forearm_r": ["arm_r", "capsule", Vector3(0.05, 0.32, 0), Vector3(0, -0.15, 0), 1.8],
	"thigh_l": ["hips", "capsule", Vector3(0.075, 0.46, 0), Vector3(0, -0.23, 0), 8.0],
	"shin_l": ["thigh_l", "capsule", Vector3(0.062, 0.5, 0), Vector3(0, -0.24, 0), 4.0],
	"thigh_r": ["hips", "capsule", Vector3(0.075, 0.46, 0), Vector3(0, -0.23, 0), 8.0],
	"shin_r": ["thigh_r", "capsule", Vector3(0.062, 0.5, 0), Vector3(0, -0.24, 0), 4.0],
}
## How far each joint turns from the rest pose, in the parent's frame (radians):
## [x lo, x hi, y lo, y hi, z lo, z hi]. +x swings a limb forward; a knee bends
## the other way.
const LIMITS := {
	"torso": [-0.9, 0.45, -0.5, 0.5, -0.4, 0.4],
	"head": [-0.8, 0.7, -1.1, 1.1, -0.5, 0.5],
	"arm_l": [-0.8, 3.0, -0.9, 0.9, -1.8, 0.35],
	"arm_r": [-0.8, 3.0, -0.9, 0.9, -0.35, 1.8],
	"forearm_l": [0.0, 2.5, -0.4, 0.4, -0.05, 0.05],
	"forearm_r": [0.0, 2.5, -0.4, 0.4, -0.05, 0.05],
	"thigh_l": [-0.55, 1.9, -0.5, 0.5, -0.8, 0.25],
	"thigh_r": [-0.55, 1.9, -0.5, 0.5, -0.25, 0.8],
	"shin_l": [-2.4, 0.0, -0.08, 0.08, -0.06, 0.06],
	"shin_r": [-2.4, 0.0, -0.08, 0.08, -0.06, 0.06],
}
