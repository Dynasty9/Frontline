extends "res://tests/fixtures/structure-production.gd"

func _ready() -> void:
	MapDims.N = 256; MapDims.SIZE = 256.0; MapDims.HALF = 128.0; MapDims.BIOME = 256; Defs.MAP_HALF = 128.0
	Nav.N = 256; Nav.H = 128.0; HNav.C = 16; HNav.NC = 16; HNav.NCC = 256; HNav._corner = HNav._corners()
	TerrainMap.N = 256; TerrainMap.H = 128.0; TerrainMap.DN = 512
	var core: RefCounted = ClassDB.instantiate("BuildingPlacementCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var state: RefCounted = ClassDB.instantiate("StructureStateCore"); var water: RefCounted = ClassDB.instantiate("WaterRaster")
	var network: RefCounted = ClassDB.instantiate("SupplyNetworkCore")
	var distances := PackedFloat64Array([Defs.BUILD_RADIUS,Defs.FOB_MIN_SPACING,Defs.FOB_EXPAND_RADIUS])
	var positions := [Vector3.ZERO,Vector3(0,0,-23),Vector3(0,0,-25),Vector3(-60,0,60),Vector3(-20,0,60),Vector3(-10,0,60),Vector3(-20,0,-60),Vector3(60,0,-30),Vector3(118,0,12),Vector3(120,0,12),Vector3(-120,0,12),Vector3(0,0,119.99),Vector3(40,0,0),Vector3(-70,0,-100),Vector3(60,0,70),Vector3(80,0,-70)]
	var count := 0; var accepted := 0; var rejected := {}; var snapped := 0
	for trial in 12:
		var w := ProductionWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.rules = Rules.new(w); add_child(w)
		if trial % 3 == 1: w.water.rivers = [{"pts":PackedVector3Array([Vector3(-128,0,0),Vector3(128,0,0)]),"w":22.0}]
		if trial % 3 == 2: w.water.coast = {"x":64.0,"s":0.0}
		if not w.water.is_empty():
			w.water.bridges = [[Vector3(40,0,-20),Vector3(40,0,20),3.0]]; w.water.paint_kinds()
		var definitions := [["fob",0,Vector3(-60,0,60)],["fob",1,Vector3(60,0,-60)],["town",0,Vector3(-20,0,-95)],["depot",0,Vector3(-100,0,100)],["trench",0,Vector3(0,0,-24)],["floor",-1,Vector3.ZERO],["camo_net",0,Vector3(60,0,70)],["sandbags",1,Vector3(-20,0,60)],["roof",-1,Vector3(40,0,30)]]
		for row: Array in definitions:
			var props := {"skind":row[0],"team":row[1],"pos":row[2],"yaw":trial*0.317-1.3}
			if row[0] == "trench": props.size = Vector3(12 if trial % 4 else 2.2,3,1.4)
			var st: Structure = w.spawn("structure",props)
			if row[0] == "fob": st.wrecked = trial % 4 == 2
			if row[0] in ["fob","town"]: st.built = trial % 4 != 3
		w.roads = [[PackedVector3Array([Vector3(-90,0,30),Vector3(90,0,30)])],[PackedVector3Array([Vector3(-90,0,-30),Vector3(90,0,-30)])],[]]
		w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		var blocks := []; var types := PackedByteArray(); var names := {}
		for st: Structure in w.structures:
			assert(state.load_state(StructureState.capture(st))); blocks.append(state.checkpoint()); types.append(1); names[st.eid] = st.display_name()
		assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w)))
		assert(network.load_state(PackedInt64Array([0,0]),PackedInt64Array(),0,w.roads,w._painted_roads)); assert(water.configure(256,w.water.to_dict()))
		for key: String in Defs.BUILDINGS:
			var d: Dictionary = Defs.BUILDINGS[key]; var mask := 0
			for team: int in d.teams: mask |= 1 << team
			var definition := [key,String(d.name),mask,int(d.cost),d.size,float(d.hp)]
			for team in 2:
				for index in positions.size():
					var pos: Vector3 = positions[index]; var yaw := trial*0.317-1.3+index*0.071; var variant := 0
					var snap := index % 2 == 0; var result: Array = core.query(actors,geometry,network,water,[team,pos,yaw,distances,snap],definition,names)
					var label := "%s/%d/%d/%d" % [key,team,trial,index]; assert(result.size() == 4,"result "+label)
					if snap and key in ["mg_nest","hmg_nest"]:
						var spot := w.trench_mount_spot(pos,yaw)
						if not spot.is_empty(): pos = spot.pos; yaw = spot.yaw; variant = 1; snapped += 1
					assert((result[0] as Vector3).distance_to(pos) < 0.000001 and absf(float(result[1])-yaw) < 0.000001 and result[2] == variant,"snap "+label)
					var error := w.placement_error(team,key,pos,yaw)
					assert(result[3] == error,"placement %s native=%s godot=%s" % [label,result[3],error])
					if error.is_empty(): accepted += 1
					else: rejected[error] = true
					count += 1
		w.free()
	assert(accepted > 0 and rejected.size() > 8 and snapped > 0,"coverage")
	print("BUILDING_PLACEMENT passed states=",count); get_tree().quit()
