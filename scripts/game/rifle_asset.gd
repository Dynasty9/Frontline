extends RefCounted
## Licensed rifle data is built locally; only the loader belongs in source control.
const SCENE := "res://assets/local_mocap/runtime/m4.scn"

static func instantiate() -> Node3D:
	if not ResourceLoader.exists(SCENE):
		push_error("Run tests/mocap/bake_rifle.gd to build the licensed rifle resource.")
		return null
	var scene := load(SCENE) as PackedScene
	return scene.instantiate() if scene != null else null
