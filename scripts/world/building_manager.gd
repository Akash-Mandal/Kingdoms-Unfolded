extends Node3D
## BuildingManager — owns placed buildings, handles tap-to-place raycasting,
## deducts costs, recomputes CE production, and restores saved buildings.

var selected_id: String = ""
var _terrain: Node3D
var _camera: Camera3D

var _placed: Array[Node3D] = []
var _pool: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _atlas_mat_cache: Dictionary = {}
const BUILDING_CULL_DIST := 380.0

func setup(terrain: Node3D, camera: Camera3D) -> void:
	if terrain == null:
		push_warning("BuildingManager: terrain null")
	if camera == null:
		push_warning("BuildingManager: camera null")
	_terrain = terrain
	_camera = camera
	if _terrain != null and not _terrain.is_inside_tree():
		await _terrain.ready
	_restore_saved()

func _restore_saved() -> void:
	for entry in Game.placed_buildings:
		var id: String = entry.get("id", "")
		var x: float = float(entry.get("x", 0.0))
		var z: float = float(entry.get("z", 0.0))
		_spawn(id, Vector3(x, 0, z), false, false)
	_recompute()

signal place_failed(reason: String)
signal ghost_update(pos: Variant, can_afford: bool)

var _ghost: MeshInstance3D
var _last_hover: Variant = null
var _last_tap_ms := 0
var _last_tap_pos := Vector2.ZERO
var _tap_count := 0

var _long_press_timer: SceneTreeTimer = null
var _is_long_pressing := false

var _ghost_tween: Tween = null

func _process(_delta: float) -> void:
	if selected_id == "":
		if _ghost != null:
			_ghost.visible = false
		return
	var mp := get_viewport().get_mouse_position()
	if mp == Vector2.ZERO:
		if _ghost != null:
			_ghost.visible = false
		return
	var hover: Variant = _ray_to_terrain(mp)
	_last_hover = hover
	_update_ghost(hover)

func _is_over_ui() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var h: Control = vp.gui_get_hovered_control()
	return h != null

func _handle_double_tap(screen_pos: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 350 and screen_pos.distance_to(_last_tap_pos) < 40:
		_tap_count += 1
	else:
		_tap_count = 1
	_last_tap_ms = now
	_last_tap_pos = screen_pos
	if _tap_count == 2:
		_focus_building_at(screen_pos)
		_tap_count = 0

func _focus_building_at(screen_pos: Vector2) -> void:
	var wp: Variant = _ray_to_terrain(screen_pos)
	if wp == null:
		return
	var cam: Camera3D = _camera
	if cam != null and cam.has_method("update_camera"):
		cam.target = Vector3(wp.x, _terrain_ground_height(wp.x, wp.z), wp.z)
		if "distance" in cam:
			cam.distance = clampf(float(cam.get("distance")) * 0.65, 12.0, 220.0)
		if cam.has_method("update_camera"):
			cam.update_camera()
		var hud: Node = get_parent().get_node_or_null("HUD")
		if hud != null and hud.has_method("_show_toast"):
			hud.call("_show_toast", "◎ Focused")

func _start_long_press(pos: Vector2) -> void:
	_is_long_pressing = true
	_long_press_timer = get_tree().create_timer(0.55)
	_long_press_timer.timeout.connect(func() -> void:
		if _is_long_pressing:
			var w: Variant = _ray_to_terrain(pos)
			if w != null:
				var tip := "Terrain %.0f,%.0f" % [w.x, w.z]
				var hud: Node = get_parent().get_node_or_null("HUD")
				if hud != null and hud.has_method("_show_toast"):
					hud.call("_show_toast", tip)
	)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_double_tap(event.position)
		_start_long_press(event.position)
	if event is InputEventScreenTouch and not event.pressed:
		_is_long_pressing = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_double_tap(event.position)
	if selected_id == "":
		return
	if _is_over_ui():
		return
	var is_touch := event is InputEventScreenTouch and event.pressed
	var is_click := event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not is_touch and not is_click:
		return
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pos = (event as InputEventScreenTouch).position
	else:
		pos = (event as InputEventMouseButton).position
	var world_pos: Variant = _ray_to_terrain(pos)
	if world_pos == null:
		place_failed.emit("No ground — aim at terrain")
		if _ghost != null: _ghost.visible = false
		return
	if not try_place(selected_id, world_pos):
		place_failed.emit("Can't afford")
		return
	get_viewport().set_input_as_handled()

func _ray_to_terrain(screen_pos: Vector2) -> Variant:
	if _camera == null:
		return null
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if dir.y > -0.02:
		return null
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2000.0)
		q.collide_with_areas = false
		q.collide_with_bodies = true
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			var p: Vector3 = hit.position
			if p.distance_to(from) < 1800.0:
				return p
	var plane := Plane(Vector3.UP, 0)
	var hit2: Variant = plane.intersects_ray(from, dir)
	if hit2 == null:
		return null
	var hp: Vector3 = hit2 as Vector3
	if hp.distance_to(from) > 1800.0:
		return null
	var limit := 320.0
	if absf(hp.x) > limit or absf(hp.z) > limit:
		return null
	return hit2

func _update_ghost(world_pos: Variant) -> void:
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.name = "Ghost"
		add_child(_ghost)
	if world_pos == null:
		_ghost.visible = false
		return
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	_ghost.visible = true
	var mesh: ArrayMesh = _make_building_mesh(selected_id)
	_ghost.mesh = mesh
	var gy: float = _terrain_ground_height(world_pos.x, world_pos.z) + 0.15
	var target := Vector3(world_pos.x, gy, world_pos.z)
	if _ghost.global_position.distance_squared_to(target) > 0.01:
		_ghost.global_position = _ghost.global_position.lerp(target, 0.35)
	else:
		_ghost.global_position = target
	var ok := can_afford(selected_id)
	ghost_update.emit(world_pos, ok)
	for i in _ghost.get_surface_override_material_count():
		_ghost.set_surface_override_material(i, null)
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.4, 1.0, 0.4, 0.45) if ok else Color(1.0, 0.35, 0.35, 0.45)
	for i in mesh.get_surface_count():
		_ghost.set_surface_override_material(i, ghost_mat)

func can_afford(id: String) -> bool:
	if Catalog == null:
		return false
	if id.strip_edges() == "":
		return false
	var def: Dictionary = Catalog.get_building(id)
	if def.is_empty():
		return false
	var cost: Dictionary = def.get("cost", {})
	if cost.is_empty():
		return true
	for key in cost:
		if Game.get_stock(key) < float(cost[key]) - 0.001:
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
			r["stock"] = maxf(0.0, float(r.get("stock", 0.0)) - float(cost[key]))
	_spawn(id, pos, true, true)
	return true

func _acquire_from_pool(id: String) -> Node3D:
	var arr: Array = _pool.get(id, [])
	if arr.is_empty():
		return null
	var n: Node3D = arr.pop_back()
	if is_instance_valid(n):
		n.visible = true
		n.process_mode = Node.PROCESS_MODE_INHERIT
		return n
	return null

func _release_to_pool(node: Node3D) -> void:
	var bid: String = node.get("building_id") if "building_id" in node else ""
	if bid == "":
		bid = "house"
	if not _pool.has(bid):
		_pool[bid] = []
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	(_pool[bid] as Array).append(node)

func _get_atlas_material(key: String, color: Color) -> StandardMaterial3D:
	if _atlas_mat_cache.has(key):
		return _atlas_mat_cache[key] as StandardMaterial3D
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_atlas_mat_cache[key] = m
	return m

func _get_cached_mesh(id: String) -> ArrayMesh:
	if _mesh_cache.has(id):
		return _mesh_cache[id] as ArrayMesh
	var mesh := _make_building_mesh_raw(id)
	_mesh_cache[id] = mesh
	return mesh

func _spawn(id: String, pos: Vector3, record: bool, recompute: bool) -> void:
	var mesh: ArrayMesh = _get_cached_mesh(id)
	var node: Node3D = _acquire_from_pool(id)
	if node == null:
		node = load("res://scripts/world/building.gd").new()
		node.name = "Building_%s_%d" % [id, _placed.size()]
		add_child(node)
		node.setup(id, mesh)
	else:
		node.global_position = Vector3.ZERO
		if node.get_parent() == null:
			add_child(node)
		node.visible = true
		node.process_mode = Node.PROCESS_MODE_INHERIT
		if node.has_method("setup"):
			var mi: MeshInstance3D = node.get_child(0) as MeshInstance3D if node.get_child_count() > 0 else null
			if mi != null:
				mi.mesh = mesh
				mi.visibility_range_end = BUILDING_CULL_DIST
				mi.visibility_range_begin = 0.0
			else:
				node.setup(id, mesh)
		node.set("building_id", id)
	var h: float = _terrain_ground_height(pos.x, pos.z) if _terrain != null and _terrain.has_method("ground_height") else 0.0
	node.global_position = Vector3(pos.x, h, pos.z)
	for c in node.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visibility_range_end = BUILDING_CULL_DIST
		if c is VisibleOnScreenNotifier3D:
			c.queue_free()
	var notifier := VisibleOnScreenNotifier3D.new()
	notifier.aabb = AABB(Vector3(-4, 0, -4), Vector3(8, 6, 8))
	notifier.screen_enter.connect(func() -> void: node.visible = true)
	notifier.screen_exit.connect(func() -> void: if node.visible: node.visible = true)
	node.add_child(notifier)
	if not _placed.has(node):
		_placed.append(node)
	if record:
		Game.record_building(id, pos.x, pos.z)
	if recompute:
		_recompute()
		Game.resources_changed.emit()

func _terrain_ground_height(wx: float, wz: float) -> float:
	if _terrain != null and is_instance_valid(_terrain) and _terrain.has_method("ground_height"):
		return _terrain.ground_height(wx, wz)
	return 0.0

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
	var npc: Node = get_parent().get_node_or_null("AgentManager")
	if npc != null and npc.has_method("notify_buildings_changed"):
		npc.notify_buildings_changed()

func _make_building_mesh(id: String) -> ArrayMesh:
	return _get_cached_mesh(id)

func _make_building_mesh_raw(id: String) -> ArrayMesh:
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
	var wood := _get_atlas_material("house_wood", Color(0.72, 0.62, 0.45))
	body.material = wood
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var roof := PrismMesh.new()
	roof.size = Vector3(5.8, 2.2, 5.8)
	var roof_mat := _get_atlas_material("house_roof", Color(0.55, 0.28, 0.18))
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
	var field_mat := _get_atlas_material("farm_field", Color(0.42, 0.62, 0.22))
	field.material = field_mat
	var farr: Array = field.get_mesh_arrays()
	var fv: PackedVector3Array = farr[Mesh.ARRAY_VERTEX]
	for i in fv.size():
		fv[i] += Vector3(0, 0.05, 0)
	farr[Mesh.ARRAY_VERTEX] = fv
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, farr)
	var hut := BoxMesh.new()
	hut.size = Vector3(3, 2, 3)
	var hut_mat := _get_atlas_material("farm_hut", Color(0.65, 0.55, 0.38))
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
	var stone := _get_atlas_material("mill_stone", Color(0.68, 0.66, 0.62))
	body.material = stone
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 2.8
	roof.height = 2.5
	var roof_mat := _get_atlas_material("mill_roof", Color(0.45, 0.28, 0.22))
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
	var mat := _get_atlas_material("bakery_wall", Color(0.75, 0.68, 0.55))
	body.material = mat
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var chim := BoxMesh.new()
	chim.size = Vector3(1.0, 2.5, 1.0)
	var chim_mat := _get_atlas_material("bakery_chim", Color(0.35, 0.32, 0.30))
	chim.material = chim_mat
	var carr: Array = chim.get_mesh_arrays()
	var cv: PackedVector3Array = carr[Mesh.ARRAY_VERTEX]
	for i in cv.size():
		cv[i] += Vector3(1.8, 2.8, 0)
	carr[Mesh.ARRAY_VERTEX] = cv
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	return m
