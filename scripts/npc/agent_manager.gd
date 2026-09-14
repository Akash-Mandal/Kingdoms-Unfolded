extends Node3D
class_name AgentManager

var TIER_A_DIST := 30.0
var TIER_B_DIST := 120.0
var MAX_TIER_A := 800
func apply_graphics(cfg: Dictionary) -> void:
	TIER_A_DIST = float(cfg.get("lod_tier_a", 30.0))
	TIER_B_DIST = float(cfg.get("lod_tier_b", 120.0))
	MAX_TIER_A = int(cfg.get("max_tier_a", 800))
	_update_lod(true)
const GRID_SIZE := 20.0
const SPAWN_RADIUS := 95.0
const SPAWN_MIN := 80
const SPAWN_MAX := 120
const LOD_INTERVAL := 0.15
const MAX_TICK_PER_FRAME := 200
const THREAD_CHUNK := 32
const HASH_MOVE_EPS := 0.01

var _terrain: Node3D
var _camera: Camera3D
var _agents: Array[Agent] = []
var _spatial_hash: Dictionary = {}
var _next_id := 0
var _rng := RandomNumberGenerator.new()
var _lod_accum := 0.0
var _last_sim_ms := 0.0
var _tick_cursor := 0
var _hash_dirty := true
var _mm_capacity := 0
var _prev_pos: PackedVector3Array = []

var _mm_body: MultiMeshInstance3D
var _mm_head: MultiMeshInstance3D
var _mm_billboard: MultiMeshInstance3D
var _tier_a_indices: Array[int] = []
var _tier_b_indices: Array[int] = []

func setup(terrain: Node3D, camera: Camera3D) -> void:
	_terrain = terrain
	_camera = camera
	_rng.seed = int(Game.settings.world_seed) if int(Game.settings.world_seed) != 0 else 12345
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs != null:
		if gs.has_signal("graphics_changed") and not gs.graphics_changed.is_connected(apply_graphics):
			gs.graphics_changed.connect(apply_graphics)
		if gs.has_method("get_config"):
			apply_graphics(gs.call("get_config") as Dictionary)
	_build_multimesh_nodes()
	_spawn_initial()
	_rebuild_hash()
	_refresh_multimesh_counts()
	_connect_signals()
	_update_lod(true)

func _connect_signals() -> void:
	if not Game.population_changed.is_connected(_on_population_changed):
		Game.population_changed.connect(_on_population_changed)

func _build_multimesh_nodes() -> void:
	_mm_body = MultiMeshInstance3D.new()
	_mm_body.name = "MM_Bodies"
	_mm_body.multimesh = MultiMesh.new()
	_mm_body.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_mm_body.multimesh.use_colors = true
	_mm_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mm_body.visibility_range_end = 140.0
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.45
	var body_mat := StandardMaterial3D.new()
	body_mat.vertex_color_use_as_albedo = true
	body_mat.roughness = 0.85
	cap.material = body_mat
	_mm_body.multimesh.mesh = cap
	add_child(_mm_body)
	_mm_head = MultiMeshInstance3D.new()
	_mm_head.name = "MM_Heads"
	_mm_head.multimesh = MultiMesh.new()
	_mm_head.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_mm_head.multimesh.use_colors = true
	_mm_head.multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mm_head.visibility_range_end = 140.0
	var sph := SphereMesh.new()
	sph.radius = 0.28
	sph.height = 0.56
	var head_mat := StandardMaterial3D.new()
	head_mat.vertex_color_use_as_albedo = true
	head_mat.roughness = 0.8
	sph.material = head_mat
	_mm_head.multimesh.mesh = sph
	add_child(_mm_head)
	_mm_billboard = MultiMeshInstance3D.new()
	_mm_billboard.name = "MM_Billboards"
	_mm_billboard.multimesh = MultiMesh.new()
	_mm_billboard.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_mm_billboard.multimesh.use_colors = true
	_mm_billboard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm_billboard.visibility_range_end = 260.0
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.orientation = PlaneMesh.FACE_Y
	var bb_mat := StandardMaterial3D.new()
	bb_mat.vertex_color_use_as_albedo = true
	bb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bb_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = bb_mat
	_mm_billboard.multimesh.mesh = quad
	add_child(_mm_billboard)

func _spawn_initial() -> void:
	var pop: int = int(roundf(Game.pop_count))
	var count: int = clampi(pop, SPAWN_MIN, SPAWN_MAX)
	count = clampi(count, SPAWN_MIN, SPAWN_MAX)
	if pop > SPAWN_MAX:
		count = clampi(int(pop * 0.95), SPAWN_MIN, SPAWN_MAX)
	_rng.state = int(Game.settings.world_seed) if int(Game.settings.world_seed) != 0 else _rng.state
	for i in count:
		_spawn_one(_random_spawn_pos())

func _random_spawn_pos() -> Vector3:
	var ang := _rng.randf_range(0.0, TAU)
	var rad := sqrt(_rng.randf()) * SPAWN_RADIUS
	var x := cos(ang) * rad
	var z := sin(ang) * rad
	var y := _ground_height(x, z)
	return Vector3(x, y, z)

func _spawn_one(pos: Vector3) -> Agent:
	var klass: String = Agent.CLASSES[_rng.randi_range(0, Agent.CLASSES.size() - 1)]
	var job: String = Agent.JOBS[_rng.randi_range(0, Agent.JOBS.size() - 1)]
	var household := _next_id / 4
	var culture: String = str(Game.settings.get("culture", "highland"))
	var ag := Agent.create(_next_id, pos, culture, klass, job, household, _rng)
	for j in _agents.size():
		if _agents[j].household == household:
			ag.relations[_agents[j].id] = randf_range(0.4, 0.9)
			_agents[j].relations[ag.id] = randf_range(0.4, 0.9)
	_next_id += 1
	_agents.append(ag)
	_prev_pos.append(ag.pos)
	_hash_dirty = true
	return ag

func _ground_height(x: float, z: float) -> float:
	if _terrain != null and is_instance_valid(_terrain) and _terrain.has_method("ground_height"):
		return _terrain.ground_height(x, z)
	return 0.0

func _cell_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / GRID_SIZE), floori(pos.z / GRID_SIZE))

func _rebuild_hash() -> void:
	_spatial_hash.clear()
	for idx in _agents.size():
		var ag: Agent = _agents[idx]
		var key := _cell_key(ag.pos)
		if not _spatial_hash.has(key):
			_spatial_hash[key] = []
		(_spatial_hash[key] as Array).append(idx)
	_hash_dirty = false

func _rebuild_hash_if_dirty() -> void:
	if not _hash_dirty:
		return
	if _prev_pos.size() != _agents.size():
		_prev_pos.resize(_agents.size())
		_rebuild_hash()
		return
	var moved := false
	for i in _agents.size():
		if _prev_pos[i].distance_squared_to(_agents[i].pos) > HASH_MOVE_EPS * HASH_MOVE_EPS:
			moved = true
			break
	if moved:
		_rebuild_hash()
		for i in _agents.size():
			_prev_pos[i] = _agents[i].pos
	else:
		_hash_dirty = false

func _ensure_mm_capacity(n: int) -> void:
	if _mm_body == null or _mm_body.multimesh == null:
		return
	if n <= _mm_capacity:
		return
	var grow := maxi(n, int(_mm_capacity * 1.35) + 8)
	_mm_capacity = grow
	if _mm_body.multimesh.mesh == null or _mm_head.multimesh.mesh == null:
		return
	_mm_body.multimesh.instance_count = grow
	_mm_head.multimesh.instance_count = grow
	_mm_billboard.multimesh.instance_count = grow
	for i in range(n, grow):
		var hide_t := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -9999, 0))
		_mm_body.multimesh.set_instance_transform(i, hide_t)
		_mm_head.multimesh.set_instance_transform(i, hide_t)
		_mm_billboard.multimesh.set_instance_transform(i, hide_t)

func _refresh_multimesh_counts() -> void:
	if _mm_body == null or _mm_head == null or _mm_billboard == null:
		return
	if _mm_body.multimesh == null or _mm_body.multimesh.mesh == null:
		return
	var n := _agents.size()
	_ensure_mm_capacity(n)
	_mm_body.multimesh.visible_instance_count = n
	_mm_head.multimesh.visible_instance_count = n
	_mm_billboard.multimesh.visible_instance_count = n
	for i in n:
		var ag: Agent = _agents[i]
		var col := _color_for_class(ag.agent_class)
		_mm_body.multimesh.set_instance_color(i, col)
		_mm_head.multimesh.set_instance_color(i, col.lerp(Color(1, 1, 1), 0.35))
		_mm_billboard.multimesh.set_instance_color(i, col)
	_prev_pos.resize(n)
	for i in n:
		_prev_pos[i] = _agents[i].pos

func _color_for_class(klass: String) -> Color:
	match klass:
		"peasants": return Color(0.58, 0.62, 0.45)
		"merchants": return Color(0.65, 0.55, 0.32)
		"clergy": return Color(0.72, 0.72, 0.78)
		"nobles": return Color(0.55, 0.45, 0.65)
		"soldiers": return Color(0.62, 0.32, 0.32)
		"scholars": return Color(0.42, 0.55, 0.68)
		_: return Color(0.6, 0.6, 0.6)

var _tick_accum := 0.0
const TICK_INTERVAL_NEEDS := 0.5

func _process(delta: float) -> void:
	_lod_accum += delta
	_tick_accum += delta
	if _tick_accum >= TICK_INTERVAL_NEEDS:
		_tick_accum = 0.0
		var t0 := Time.get_ticks_usec()
		_tick_agents_threaded_v2(TICK_INTERVAL_NEEDS)
		_last_sim_ms = (Time.get_ticks_usec() - t0) / 1000.0
		_push_sim_ms()
		_rebuild_hash_if_dirty()
	_tick_move(delta)
	if _lod_accum < LOD_INTERVAL:
		return
	_lod_accum = 0.0
	_update_lod(false)

func _push_sim_ms() -> void:
	var p: Node = get_parent()
	if p != null:
		var dbg: Node = p.get_node_or_null("DebugOverlay")
		if dbg != null and dbg.has_method("push_sim_ms"):
			dbg.push_sim_ms(_last_sim_ms)

func _tick_agents(delta: float) -> void:
	var hour: float = TimeClock.sim_hour if TimeClock != null else 12.0
	for ag in _agents:
		var best: String = Needs.pick_best_deterministic(ag.needs, hour, ag.job)
		var rec: Dictionary = Needs.RECOVERY.get(best, {}) if Needs != null else {}
		for k in Needs.NEED_KEYS if Needs != null else []:
			var cur: float = float(ag.needs.get(k, 0.5))
			var drift: float = float(Needs.DRIFT_RATES.get(k, 0.0) if Needs != null else 0.0) * delta * 0.5
			ag.needs[k] = clampf(cur + drift, 0.0, 1.0)
		for k in rec:
			var cur2: float = float(ag.needs.get(k, 0.5))
			var rate: float = float(rec[k])
			ag.needs[k] = clampf(cur2 - rate * delta * 0.45, 0.0, 1.0)

func _tick_agents_threaded_v2(delta: float) -> void:
	if _agents.is_empty():
		return
	var step: float = clampf(delta, 0.0, 1.0)
	# Dictionaries are not thread-safe: run on main thread to avoid torn writes.
	_tick_agents(step)

func _tick_chunk(start: int, end: int, hour: float, delta: float) -> void:
	if _agents.is_empty():
		return
	var n: int = _agents.size()
	var s0: int = clampi(start, 0, n)
	var e0: int = clampi(end, 0, n)
	for i in range(s0, e0):
		var ag: Agent = _agents[i]
		var best: String = Needs.pick_best_deterministic(ag.needs, hour, ag.job)
		var rec: Dictionary = Needs.RECOVERY.get(best, {}) as Dictionary
		for k in Needs.NEED_KEYS:
			var cur: float = float(ag.needs.get(k, 0.5))
			var drift: float = float(Needs.DRIFT_RATES.get(k, 0.0)) * delta * 0.5
			ag.needs[k] = clampf(cur + drift, 0.0, 1.0)
		for k in rec:
			var cur2: float = float(ag.needs.get(k, 0.5))
			var rate: float = float(rec[k])
			ag.needs[k] = clampf(cur2 - rate * delta * 0.45, 0.0, 1.0)

func _tick_move(delta: float) -> void:
	var any_moved := false
	for ag in _agents:
		var prev := ag.pos
		if ag.job == "farmer" or ag.job == "builder":
			ag.pos += Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03))
			ag.pos.x = clampf(ag.pos.x, -SPAWN_RADIUS*1.6, SPAWN_RADIUS*1.6)
			ag.pos.z = clampf(ag.pos.z, -SPAWN_RADIUS*1.6, SPAWN_RADIUS*1.6)
			var gh: float = _ground_height(ag.pos.x, ag.pos.z) + 0.02
			ag.pos.y = lerpf(ag.pos.y, gh, 0.4)
			if absf(ag.pos.y - gh) > 0.6:
				ag.pos.y = gh
		elif ag.job == "idle":
			if randf() < 0.02:
				ag.pos += Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
				ag.pos.x = clampf(ag.pos.x, -SPAWN_RADIUS*1.6, SPAWN_RADIUS*1.6)
				ag.pos.z = clampf(ag.pos.z, -SPAWN_RADIUS*1.6, SPAWN_RADIUS*1.6)
				var gh2: float = _ground_height(ag.pos.x, ag.pos.z) + 0.02
				ag.pos.y = lerpf(ag.pos.y, gh2, 0.4)
				if absf(ag.pos.y - gh2) > 0.6:
					ag.pos.y = gh2
		if ag.pos.distance_squared_to(prev) > HASH_MOVE_EPS * HASH_MOVE_EPS:
			any_moved = true
	if any_moved:
		_hash_dirty = true

func notify_buildings_changed() -> void:
	var demand: Dictionary = JobSystem.compute_demand(Game.placed_buildings) if JobSystem != null else {}
	JobSystem.assign(_agents, demand) if JobSystem != null else null
	_refresh_multimesh_counts()

func _update_lod(force: bool) -> void:
	var cam_pos := Vector3.ZERO
	if _camera != null:
		cam_pos = _camera.global_position
	else:
		cam_pos = Vector3(0, 12, 35)
	var frustum: Array[Plane] = []
	if _camera != null:
		frustum = _camera.get_frustum()
	var tier_a_candidates: Array[Dictionary] = []
	var b_count := 0
	for i in _agents.size():
		var ag: Agent = _agents[i]
		var d := ag.pos.distance_to(cam_pos)
		if frustum.size() == 6:
			var visible := true
			for pl in frustum:
				if pl.distance_to(ag.pos) < -1.2:
					visible = false
					break
			if not visible:
				continue
		if d < TIER_A_DIST:
			tier_a_candidates.append({"idx": i, "dist": d})
		elif d < TIER_B_DIST:
			b_count += 1
	tier_a_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	var tier_a_count := mini(tier_a_candidates.size(), MAX_TIER_A)
	var tier_a_set := {}
	for k in tier_a_count:
		tier_a_set[int(tier_a_candidates[k]["idx"])] = true
	for i in _agents.size():
		var ag: Agent = _agents[i]
		var d := ag.pos.distance_to(cam_pos)
		if frustum.size() == 6:
			var vis2 := true
			for pl in frustum:
				if pl.distance_to(ag.pos) < -1.2:
					vis2 = false
					break
			if not vis2:
				var hide_t := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -9999, 0))
				_mm_body.multimesh.set_instance_transform(i, hide_t)
				_mm_head.multimesh.set_instance_transform(i, hide_t)
				_mm_billboard.multimesh.set_instance_transform(i, hide_t)
				continue
		var in_a: bool = tier_a_set.has(i)
		var is_a := in_a
		var is_b := (not is_a) and d < TIER_B_DIST
		var hide_t := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -9999, 0))
		if is_a:
			var t_body := Transform3D(Basis.IDENTITY, ag.pos + Vector3(0, 0.72, 0))
			var t_head := Transform3D(Basis.IDENTITY, ag.pos + Vector3(0, 1.42, 0))
			_mm_body.multimesh.set_instance_transform(i, t_body)
			_mm_head.multimesh.set_instance_transform(i, t_head)
			_mm_billboard.multimesh.set_instance_transform(i, hide_t)
		elif is_b:
			_mm_body.multimesh.set_instance_transform(i, hide_t)
			_mm_head.multimesh.set_instance_transform(i, hide_t)
			var t_bb := Transform3D(Basis.IDENTITY, ag.pos + Vector3(0, 0.9, 0))
			_mm_billboard.multimesh.set_instance_transform(i, t_bb)
		else:
			_mm_body.multimesh.set_instance_transform(i, hide_t)
			_mm_head.multimesh.set_instance_transform(i, hide_t)
			_mm_billboard.multimesh.set_instance_transform(i, hide_t)

func query_radius(center: Vector3, radius: float) -> Array[Agent]:
	_rebuild_hash_if_dirty()
	var out: Array[Agent] = []
	var r_cells := int(ceil(radius / GRID_SIZE)) + 1
	var base := _cell_key(center)
	var rsq := radius * radius
	for dx in range(-r_cells, r_cells + 1):
		for dz in range(-r_cells, r_cells + 1):
			var key := Vector2i(base.x + dx, base.y + dz)
			if not _spatial_hash.has(key):
				continue
			var indices: Array = _spatial_hash[key]
			for idx in indices:
				var ag: Agent = _agents[int(idx)]
				if ag.pos.distance_squared_to(center) <= rsq:
					out.append(ag)
	return out

func agents_in_cell(cell: Vector2i) -> Array[Agent]:
	_rebuild_hash_if_dirty()
	if not _spatial_hash.has(cell):
		return []
	var indices: Array = _spatial_hash[cell]
	var out: Array[Agent] = []
	for idx in indices:
		out.append(_agents[int(idx)])
	return out

func get_agent(idx: int) -> Agent:
	if idx < 0 or idx >= _agents.size():
		return null
	return _agents[idx]

func agent_count() -> int:
	return _agents.size()

func add_agent_at(pos: Vector3, klass: String = "", job: String = "") -> Agent:
	var ag := _spawn_one(pos)
	if klass != "":
		ag.agent_class = klass
	if job != "":
		ag.job = job
	_rebuild_hash()
	_refresh_multimesh_counts()
	_update_lod(true)
	return ag

func remove_agent(aid: int) -> void:
	for i in _agents.size():
		if _agents[i].id == aid:
			_agents.remove_at(i)
			_prev_pos.remove_at(i)
			break
	_hash_dirty = true
	_rebuild_hash()
	_refresh_multimesh_counts()

func _on_population_changed() -> void:
	var target: int = clampi(int(roundf(Game.pop_count)), SPAWN_MIN, SPAWN_MAX)
	if target > _agents.size():
		var need := target - _agents.size()
		for i in need:
			_spawn_one(_random_spawn_pos())
		_rebuild_hash()
		_refresh_multimesh_counts()
		_update_lod(true)
	elif target < _agents.size() - 8:
		var excess := _agents.size() - target
		for i in excess:
			_agents.pop_back()
			_prev_pos.pop_back()
		_hash_dirty = true
		_rebuild_hash()
		_refresh_multimesh_counts()
		_update_lod(true)

func tick_needs(delta: float) -> void:
	for ag in _agents:
		ag.tick_needs(delta)

func tick_needs_threaded(delta: float) -> void:
	_tick_agents_threaded_v2(delta)

func get_sim_ms() -> float:
	return _last_sim_ms
