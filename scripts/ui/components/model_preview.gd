class_name UiModelPreview
extends SubViewportContainer
## Owns a preview model in an isolated world; no gameplay or entity dependency.
var _view: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _model: Node3D
var _environment: Environment
var _rim: DirectionalLight3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_view = SubViewport.new()
	_view.size = Vector2i(144, 160)
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.msaa_3d = Viewport.MSAA_2X
	add_child(_view)
	_stage = Node3D.new()
	_view.add_child(_stage)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = UiKit.fa(UiKit.INK, 0.0)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = UiKit.TEXT
	_environment.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = _environment
	_stage.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -35, 0)
	light.light_energy = 1.8
	_stage.add_child(light)
	_rim = DirectionalLight3D.new()
	_rim.rotation_degrees = Vector3(-20, 145, 0)
	_rim.light_color = UiKit.ACCENT
	_rim.light_energy = 1.5
	_stage.add_child(_rim)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_stage.add_child(_camera)
	resized.connect(func(): _view.render_target_update_mode = SubViewport.UPDATE_ONCE)


func set_model(model: Node3D, bust := false) -> void:
	if _model:
		_model.free()
	_model = model
	_stage.add_child(_model)
	frame_model(bust)


func refresh_theme() -> void:
	_environment.background_color = UiKit.fa(UiKit.INK, 0.0)
	_environment.ambient_light_color = UiKit.TEXT
	_rim.light_color = UiKit.ACCENT
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func frame_model(bust := false) -> void:
	refresh_theme()
	var bounds := _bounds(_model)
	var focus := bounds.get_center()
	var span := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if bust:
		focus.y = bounds.position.y + bounds.size.y * 0.7
		_camera.size = bounds.size.y * 0.7
	else:
		_camera.size = span * 1.35
	_camera.position = focus + Vector3(0.7, 0.3, -1.0).normalized() * maxf(3, span * 3)
	_camera.look_at(focus)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var visuals := node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		visuals.append(node)
	for child in visuals:
		var visual := child as VisualInstance3D
		var b: AABB = visual.global_transform * visual.get_aabb()
		result = result.merge(b) if found else b
		found = true
	return result if found else AABB(Vector3.ZERO, Vector3.ONE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _view and _environment and _rim:
		refresh_theme()
