extends World
## Small controlled range shared by effects regression tests and recordings.
## No simulation, map generation, replication or automatic effect prewarming.
var floor_height := 0.0

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	has_view = false
	fx = Fx.new()
	fx.world = self
	add_child(fx)
	fx.set_process(false)
	fx.vfx = Vfx.new()
	fx.vfx.world = self
	fx.add_child(fx.vfx)
	fx.gunfx = GunFx.new()
	fx.gunfx.world = self
	fx.gunfx.vfx = fx.vfx
	fx.add_child(fx.gunfx)
	has_view = true

func ground_y(_p: Vector3) -> float:
	return floor_height
