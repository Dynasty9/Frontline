extends UiModelPreview
## Adapter from a selected entity to the reusable, simulation-free preview stage.
var _key := ""


func show_entity(entity: Entity) -> void:
	if not is_instance_valid(entity) or _view == null:
		return
	var soldier := entity is Soldier
	var kind: String = entity.utype if soldier else (entity.vkind if entity is Vehicle else "")
	if kind.is_empty():
		hide()
		return
	var key := "%s:%s:%s" % [soldier, kind, entity.team]
	if key == _key:
		return
	_key = key
	var model: Node3D
	if soldier:
		var figure := SoldierModel.new()
		figure.build(kind, entity.team, 7)
		for i in 6:
			figure.pose(0.5, 0, Soldier.Post.STAND, Soldier.Act.IDLE, 0.0, false, false)
		model = figure
	else:
		model = VehicleModels.build(kind, entity.team, 7).root
	set_model(model, soldier)
