extends Node3D
## BuildingManager — owns placed buildings, handles tap-to-place raycasting,
## deducts costs, recomputes CE production, and restores saved buildings.

var selected_id: String = ""
var _terrain: Node3D
var _camera: Camera3D

var _placed: Array[Node3D] = []

func setup(terrain: Node3D, camera: Camera3D) -> void:
	_terrain = terrain
	_camera = camera
	_restore_saved()

func _restore_saved() -> void:
	for entry in Game.placed_buildings:
		var id: String = entry.get("id", "")
		var x: float = float(entry.get("x", 0.0))
		var z: float = float(entry.get("z", 0.0))
		_spawn(id, Vector3(x, 0, z), false, false)
	_recompute()

func _unhandled_input(event: InputEvent) -> void:
	if selected_id == "":
		return
	if not (event is InputEventScreenTouch and event.pressed):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
	else:
		pos = (event as InputEventMouseButton).position
	var world_pos: Variant = _ray_to_terrain(pos)
	if world_pos == null:
		return
	try_place(selected_id, world_pos)

func _ray_to_terrain(screen_pos: Vector2) -> Variant:
	if _camera == null or _terrain == null:
		return null
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2000.0)
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit.position

func can_afford(id: String) -> bool:
	var def: Dictionary = Catalog.get_building(id)
	var cost: Dictionary = def.get("cost", {})
	for key in cost:
		if Game.get_stock(key) < float(cost[key]):
			return false
	return true

func try_place(id: String, pos: Vector3) -> bool:
	if not can_afford(id):
		return false
	var def: Dictionary = Catalog.get_building(id)
	var cost: Dictionary = def.get("cost", {})
	for key in cost:
		var r: Dictionary = Game.resources.get(key, {})
		if not r.is_empty():
			r["stock"] -= float(cost[key])
	_spawn(id, pos, true, true)
	return true

func _spawn(id: String, pos: Vector3, record: bool, recompute: bool) -> void:
	var mesh: ArrayMesh = _make_building_mesh(id)
	var node = load("res://scripts/world/building.gd").new()
	node.name = "Building_%s_%d" % [id, _placed.size()]
	add_child(node)
	node.setup(id, mesh)
	var h: float = _terrain_ground_height(pos.x, pos.z) if _terrain != null and _terrain.has_method("ground_height") else 0.0
	node.global_position = Vector3(pos.x, h, pos.z)
	_placed.append(node)
	if record:
		Game.record_building(id, pos.x, pos.z)
	if recompute:
		_recompute()
		Game.resources_changed.emit()

func _terrain_ground_height(wx: float, wz: float) -> float:
	return _terrain.ground_height(wx, wz)

func _recompute() -> void:
	var prod: Dictionary = {}
	var cons: Dictionary = {}
	var cap: Dictionary = {}
	for n in _placed:
		var bid: String = n.building_id
		var def: Dictionary = Catalog.get_building(bid)
		for key in def.get("prod", {}):
			prod[key] = prod.get(key, 0.0) + float(def["prod"][key])
		for key in def.get("cons", {}):
			cons[key] = cons.get(key, 0.0) + float(def["cons"][key])
		for key in def.get("capacity", {}):
			cap[key] = cap.get(key, 0.0) + float(def["capacity"][key])
	Game.set_building_contributions(prod, cons, cap)

func _make_building_mesh(id: String) -> ArrayMesh:
	match id:
		"farm":
			return _farm_mesh()
		"mill":
			return _mill_mesh()
		"bakery":
			return _bakery_mesh()
		_:
			return _house_mesh()

func _house_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var body := BoxMesh.new()
	body.size = Vector3(5, 3, 5)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.72, 0.62, 0.45)
	body.material = wood
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var roof := PrismMesh.new()
	roof.size = Vector3(5.8, 2.2, 5.8)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.55, 0.28, 0.18)
	roof.material = roof_mat
	var carr: Array = roof.get_mesh_arrays()
	var verts: PackedVector3Array = carr[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += Vector3(0, 2.6, 0)
	carr[Mesh.ARRAY_VERTEX] = verts
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	return m

func _farm_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var field := PlaneMesh.new()
	field.size = Vector2(14, 14)
	var field_mat := StandardMaterial3D.new()
	field_mat.albedo_color = Color(0.42, 0.62, 0.22)
	field.material = field_mat
	var farr: Array = field.get_mesh_arrays()
	var fv: PackedVector3Array = farr[Mesh.ARRAY_VERTEX]
	for i in fv.size():
		fv[i] += Vector3(0, 0.05, 0)
	farr[Mesh.ARRAY_VERTEX] = fv
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, farr)
	var hut := BoxMesh.new()
	hut.size = Vector3(3, 2, 3)
	var hut_mat := StandardMaterial3D.new()
	hut_mat.albedo_color = Color(0.65, 0.55, 0.38)
	hut.material = hut_mat
	var harr: Array = hut.get_mesh_arrays()
	var hv: PackedVector3Array = harr[Mesh.ARRAY_VERTEX]
	for i in hv.size():
		hv[i] += Vector3(0, 1.0, 0)
	harr[Mesh.ARRAY_VERTEX] = hv
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, harr)
	return m

func _mill_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var body := CylinderMesh.new()
	body.top_radius = 2.2
	body.bottom_radius = 2.6
	body.height = 5.0
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.68, 0.66, 0.62)
	body.material = stone
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 2.8
	roof.height = 2.5
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.45, 0.28, 0.22)
	roof.material = roof_mat
	var carr: Array = roof.get_mesh_arrays()
	var cv: PackedVector3Array = carr[Mesh.ARRAY_VERTEX]
	for i in cv.size():
		cv[i] += Vector3(0, 3.8, 0)
	carr[Mesh.ARRAY_VERTEX] = cv
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	return m

func _bakery_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var body := BoxMesh.new()
	body.size = Vector3(5, 3.2, 4.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.68, 0.55)
	body.material = mat
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var chim := BoxMesh.new()
	chim.size = Vector3(1.0, 2.5, 1.0)
	var chim_mat := StandardMaterial3D.new()
	chim_mat.albedo_color = Color(0.35, 0.32, 0.30)
	chim.material = chim_mat
	var carr: Array = chim.get_mesh_arrays()
	var cv: PackedVector3Array = carr[Mesh.ARRAY_VERTEX]
	for i in cv.size():
		cv[i] += Vector3(1.8, 2.8, 0)
	carr[Mesh.ARRAY_VERTEX] = cv
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	return m
