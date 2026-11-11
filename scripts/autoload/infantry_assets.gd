extends Node
## Mount the shipped characters before choosing a model for the battle.

const BASE := "res://assets/local_mocap/FBX/"
const CLIPS := {
	"idle": "Animation/Rifle/Animation/Root_Motion/W2_Stand_Aim_Idle_v2.fbx",
	"walk": "Animation/Rifle/Animation/In-Place/W2_Walk_Aim_F_Loop_IPC.fbx",
	"jog": "Animation/Rifle/Animation/In-Place/W2_Jog_Aim_F_Loop_IPC.fbx",
	"relax": "Animation/Rifle/Animation/Root_Motion/W2_Stand_Aim_To_Relaxed.fbx",
	"relaxed": "Animation/Rifle/Animation/Root_Motion/W2_Stand_Relaxed_Idle_v2.fbx",
	"crouch": "Animation/Mobility/IPC/MOB1_CrouchWalk_F_IPC.fbx",
}

const MIXAMO_BASE := "res://assets/local_mocap/mixamo/"
const MIXAMO_CLIPS := {
	"idle": "basic_shooter/rifle aiming idle.fbx",
	"walk": "basic_shooter/walking.fbx",
	"jog": "basic_shooter/rifle run.fbx",
	"relax": "basic_shooter/rifle aiming idle.fbx",
	"relaxed": "basic_shooter/rifle aiming idle.fbx",
	"crouch": "Rifle Crouch Walk.fbx",
}
const SWAT := MIXAMO_BASE + "Swat.fbx"
const SOLDIER := "res://assets/local_mocap/character/Soldier.glb"
const MANNEQUIN := BASE + "MotusMan/MotusMan_v55.fbx"
const Rifle := preload("res://scripts/game/rifle_asset.gd")
var gameplay_model := ""


func _init() -> void:
	if "tests/mocap/pack_infantry.gd" in OS.get_cmdline_args():
		return
	if not ProjectSettings.load_resource_pack("res://assets/infantry/infantry.zip", false):
		push_error("Could not mount Frontline infantry assets")
	gameplay_model = select_model(OS.get_cmdline_user_args(), ResourceLoader.exists)


static func select_model(args: PackedStringArray, exists: Callable) -> String:
	if not exists.call(Rifle.SCENE):
		return ""
	var prefer_legacy := "--skinned-units" in args and "--swat-units" not in args and "--swat" not in args
	for model: String in ([SOLDIER, SWAT] if prefer_legacy else [SWAT, SOLDIER]):
		if not exists.call(model):
			continue
		var mixamo := model == SWAT
		if not mixamo and not exists.call(MANNEQUIN):
			continue
		var base := MIXAMO_BASE if mixamo else BASE
		var clips := MIXAMO_CLIPS if mixamo else CLIPS
		if clips.values().all(func(path: String) -> bool: return exists.call(base + path)):
			return model
	return ""
