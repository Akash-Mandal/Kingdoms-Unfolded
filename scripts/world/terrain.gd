extends Node3D

const GRID := 160
const SPACING := 4.0
const AMPLITUDE := 16.0
const SEA_LEVEL := 0.05
var TREE_COUNT := 260
var _tree_container: Node3D
func apply_graphics(cfg: Dictionary) -> void:
	var nt: int = int(cfg.get("tree_count", TREE_COUNT))
	var shadows_off: bool = str(cfg.get("shadows", "soft")) == "off"
	if nt != TREE_COUNT:
		TREE_COUNT = nt
		_rebuild_trees()
	for ch in _chunks:
		if is_instance_valid(ch):
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if shadows_off else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _mm_trunk != null:
		_mm_trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if shadows_off else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _mm_crown != null:
		_mm_crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if shadows_off else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _rebuild_trees() -> void:
	build_trees()
const CHUNK_DIV := 2
const CHUNK_GRID := 80
const COLLISION_GRID := 40
const COLLISION_USE_HEIGHTMAP := true
const TREE_CULL_DIST := 180.0
const TERRAIN_CULL_DIST := 520.0
const FAR_LOD_DISTANCE := 260.0

var world_seed := 0
var height_noise := FastNoiseLite.new()
var moisture_noise := FastNoiseLite.new()
var terrain_material: ShaderMaterial
var _chunks: Array[MeshInstance3D] = []
var _collision_body: StaticBody3D
var _mm_trunk: MultiMeshInstance3D
var _mm_crown: MultiMeshInstance3D
var _tree_xform_cache: PackedVector3Array
var _tree_scale_cache: PackedVector3Array
var _tree_visibility := {}
var chunk_aabb: AABB

func _ready() -> void:
	seed(world_seed)
	height_noise.seed = world_seed
	height_noise.fractal_octaves = 5
	height_noise.fractal_gain = 0.5
	height_noise.frequency = 0.012
	height_noise.domain_warp_enabled = true
	height_noise.domain_warp_amplitude = 28.0
	moisture_noise.seed = world_seed + 1013
	moisture_noise.frequency = 0.008
	build_terrain()
	_terrain_ready = true

func height_at(x: float, z: float) -> float:
	return height_noise.get_noise_2d(x, z)

func moisture_at(x: float, z: float) -> float:
	return moisture_noise.get_noise_2d(x, z)

var _terrain_ready := false
func ground_height(wx: float, wz: float) -> float:
	if not _terrain_ready and height_noise.seed != world_seed:
		height_noise.seed = world_seed
		moisture_noise.seed = world_seed + 1013
	var half := (GRID - 1) * SPACING * 0.5
	var nx := (wx + half) / SPACING
	var nz := (wz + half) / SPACING
	nx = clampf(nx, 0.0, float(GRID - 1))
	nz = clampf(nz, 0.0, float(GRID - 1))
	return height_at(nx, nz) * AMPLITUDE

func biome_color(h: float, m: float) -> Color:
	if h < -SEA_LEVEL - 0.06:
		return Color(0.15, 0.35, 0.55)
	if h < -SEA_LEVEL:
		return Color(0.25, 0.45, 0.65)
	if h < -SEA_LEVEL + 0.03:
		return Color(0.83, 0.78, 0.6)
	var c := Color(0.42, 0.62, 0.31)
	c = c.lerp(Color(0.2, 0.42, 0.2), maxf(m, 0.0) * 1.2)
	c = c.lerp(Color(0.75, 0.72, 0.5), maxf(-m, 0.0) * 1.1)
	if h > 0.35:
		c = c.lerp(Color(0.5, 0.46, 0.42), 0.6)
	if h > 0.6:
		c = c.lerp(Color(0.95, 0.95, 0.98), 0.85)
	return c

func build_terrain() -> void:
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs != null:
		if gs.has_method("get_config"):
			TREE_COUNT = int((gs.call("get_config") as Dictionary).get("tree_count", TREE_COUNT))
		if gs.has_signal("graphics_changed") and not gs.graphics_changed.is_connected(apply_graphics):
			gs.graphics_changed.connect(apply_graphics)
	for c in _chunks:
		if is_instance_valid(c):
			c.queue_free()
	_chunks.clear()
	if _collision_body != null and is_instance_valid(_collision_body):
		_collision_body.queue_free()
		_collision_body = null
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/terrain.gdshader")
	sm.set_shader_parameter("snow_amount", 0.0)
	sm.set_shader_parameter("season_tint", Color(1, 1, 1))
	sm.set_shader_parameter("snow_max_height", 18.0)
	terrain_material = sm
	_build_chunks()
	_build_collision_simplified()
	build_water()
	build_trees()
	if gs != null and gs.has_signal("graphics_changed") and not gs.graphics_changed.is_connected(apply_graphics):
		gs.graphics_changed.connect(apply_graphics)
	var cfg: Dictionary = gs.call("get_config") as Dictionary if gs != null and gs.has_method("get_config") else {}
	if not cfg.is_empty():
		apply_graphics(cfg)

func _build_chunks() -> void:
	var half := (GRID - 1) * SPACING * 0.5
	var step := CHUNK_GRID
	var div := CHUNK_DIV
	for cz in div:
		for cx in div:
			var sx := cx * (CHUNK_GRID - 1)
			var sz := cz * (CHUNK_GRID - 1)
			var gw := CHUNK_GRID
			var gh := CHUNK_GRID
			if cx == div - 1:
				gw = GRID - sx
			if cz == div - 1:
				gh = GRID - sz
			var mesh := _build_mesh_chunk(sx, sz, gw, gh)
			var mi := MeshInstance3D.new()
			mi.name = "TerrainChunk_%d_%d" % [cx, cz]
			mi.mesh = mesh
			mi.material_override = terrain_material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.visibility_range_end = TERRAIN_CULL_DIST
			mi.visibility_range_begin = 0.0
			mi.set_instance_shader_parameter("chunk_id", Vector2(cx, cz))
			add_child(mi)
			_chunks.append(mi)
			var notifier := VisibleOnScreenNotifier3D.new()
			notifier.aabb = mi.get_aabb()
			notifier.screen_enter.connect(_on_chunk_visible.bind(mi, true))
			notifier.screen_exit.connect(_on_chunk_visible.bind(mi, false))
			mi.add_child(notifier)
	if not _chunks.is_empty():
		var ab := _chunks[0].get_aabb()
		for i in range(1, _chunks.size()):
			ab = ab.merge(_chunks[i].get_aabb())
		chunk_aabb = ab

func _on_chunk_visible(mi: MeshInstance3D, vis: bool) -> void:
	mi.visible = vis

func _build_mesh_chunk(sx: int, sz: int, gw: int, gh: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := (GRID - 1) * SPACING * 0.5
	for z in gh:
		for x in gw:
			var gx := sx + x
			var gz := sz + z
			var wx := -half + gx * SPACING
			var wz := -half + gz * SPACING
			var h := height_at(gx, gz)
			var m := moisture_at(gx, gz)
			st.set_color(biome_color(h, m))
			st.add_vertex(Vector3(wx, h * AMPLITUDE, wz))
	for z in (gh - 1):
		for x in (gw - 1):
			var i := z * gw + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + gw)
			st.add_index(i + gw)
			st.add_index(i + 1)
			st.add_index(i + gw + 1)
	st.generate_normals()
	return st.commit()

func build_mesh() -> ArrayMesh:
	return _build_mesh_chunk(0, 0, GRID, GRID)

func _build_collision_simplified() -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	add_child(body)
	_collision_body = body
	if COLLISION_USE_HEIGHTMAP and ClassDB.class_exists("HeightMapShape3D"):
		var hmap := HeightMapShape3D.new()
		var w := COLLISION_GRID
		var h := COLLISION_GRID
		var half_world := (GRID - 1) * SPACING * 0.5
		var step_x := float(GRID - 1) / float(w - 1)
		var step_z := float(GRID - 1) / float(h - 1)
		var heights := PackedFloat32Array()
		heights.resize(w * h)
		var min_h := INF
		var max_h := -INF
		for z in h:
			for x in w:
				var gx := int(roundf(x * step_x))
				var gz := int(roundf(z * step_z))
				gx = clampi(gx, 0, GRID - 1)
				gz = clampi(gz, 0, GRID - 1)
				var hv := height_at(gx, gz) * AMPLITUDE
				heights[z * w + x] = hv
				min_h = minf(min_h, hv)
				max_h = maxf(max_h, hv)
		hmap.map_width = w
		hmap.map_depth = h
		hmap.map_data = heights
		var shape_holder := CollisionShape3D.new()
		shape_holder.shape = hmap
		var world_size := (GRID - 1) * SPACING
		shape_holder.position = Vector3(0, (min_h + max_h) * 0.5, 0)
		body.add_child(shape_holder)
		shape_holder.scale = Vector3(world_size / float(w - 1), 1.0, world_size / float(h - 1))
		return
	var s_mesh := _build_mesh_chunk_decimated(COLLISION_GRID)
	var shape := s_mesh.create_convex_shape(true, false)
	if shape == null:
		shape = s_mesh.create_trimesh_shape()
	if shape != null:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)

func _build_mesh_chunk_decimated(target_grid: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := (GRID - 1) * SPACING * 0.5
	var step_f := float(GRID - 1) / float(target_grid - 1)
	for z in target_grid:
		for x in target_grid:
			var gx := int(roundf(x * step_f))
			var gz := int(roundf(z * step_f))
			var wx := -half + gx * SPACING
			var wz := -half + gz * SPACING
			var h := height_at(gx, gz)
			st.add_vertex(Vector3(wx, h * AMPLITUDE, wz))
	for z in (target_grid - 1):
		for x in (target_grid - 1):
			var i := z * target_grid + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + target_grid)
			st.add_index(i + target_grid)
			st.add_index(i + 1)
			st.add_index(i + target_grid + 1)
	return st.commit()

func _fix_collision(_terrain: MeshInstance3D) -> void:
	pass

func build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plan := PlaneMesh.new()
	plan.size = Vector2((GRID - 1) * SPACING, (GRID - 1) * SPACING)
	water.mesh = plan
	water.position = Vector3(0, SEA_LEVEL * AMPLITUDE - 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.42, 0.62, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	water.material_override = mat
	water.visibility_range_end = TERRAIN_CULL_DIST
	add_child(water)

func build_trees() -> void:
	for c in get_children():
		if c is MultiMeshInstance3D and String(c.name).begins_with("MM_Trees"):
			c.queue_free()
	_tree_xform_cache = PackedVector3Array()
	_tree_scale_cache = PackedVector3Array()
	var half := (GRID - 1) * SPACING * 0.5
	var positions: Array[Transform3D] = []
	var scales: Array[Vector3] = []
	var placed := 0
	var attempts := 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 6:
		attempts += 1
		var wx := randf_range(-half, half)
		var wz := randf_range(-half, half)
		var h := height_at(wx / SPACING, wz / SPACING)
		var m := moisture_at(wx / SPACING, wz / SPACING)
		if h < 0.03 or h > 0.5 or m < -0.05:
			continue
		var y := h * AMPLITUDE
		var s := randf_range(0.7, 1.5)
		var sy := randf_range(0.9, 1.4)
		var t := Transform3D(Basis.IDENTITY.scaled(Vector3(s, sy, s)), Vector3(wx, y, wz))
		var yaw := randf_range(0, TAU)
		t.basis = t.basis.rotated(Vector3.UP, yaw)
		positions.append(t)
		scales.append(Vector3(s, sy, s))
		placed += 1
	_mm_trunk = _create_tree_multimesh("MM_Trees_Trunk", _make_trunk_mesh(), positions, scales, 1.6)
	_mm_crown = _create_tree_multimesh("MM_Trees_Crown", _make_crown_mesh(), positions, scales, 1.4)
	add_child(_mm_trunk)
	add_child(_mm_crown)
	_update_tree_visibility(true)

func _create_tree_multimesh(p_name: String, mesh: Mesh, xforms: Array[Transform3D], scales: Array[Vector3], y_off: float) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = p_name
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.visibility_range_end = TREE_CULL_DIST
	mmi.visibility_range_begin = 0.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	mm.visible_instance_count = xforms.size()
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		var adj := Transform3D(t.basis, t.origin + Vector3(0, y_off * scales[i].y * 0.5, 0))
		if p_name.contains("Crown"):
			adj.origin = t.origin + Vector3(0, 1.4 * scales[i].y + 0.8, 0)
			adj.basis = Basis.IDENTITY.scaled(Vector3(scales[i].x, scales[i].y, scales[i].x)).rotated(Vector3.UP, randf() * TAU)
		mm.set_instance_transform(i, adj)
	mmi.multimesh = mm
	return mmi

func _update_tree_visibility(force: bool) -> void:
	if _mm_trunk == null or _mm_crown == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var cam_pos := cam.global_position
	var frustum := cam.get_frustum()
	var planes: Array[Plane] = []
	for p in frustum:
		planes.append(p as Plane)
	var n := _mm_trunk.multimesh.instance_count
	var vis := 0
	for i in n:
		var t := _mm_trunk.multimesh.get_instance_transform(i)
		var inside := true
		for pl in planes:
			if pl.distance_to(t.origin) < -2.0:
				inside = false
				break
		if inside and t.origin.distance_squared_to(cam_pos) > TREE_CULL_DIST * TREE_CULL_DIST:
			inside = false
		if inside:
			vis += 1
	_mm_trunk.multimesh.visible_instance_count = vis if vis > 0 else -1
	_mm_crown.multimesh.visible_instance_count = vis if vis > 0 else -1

var _cull_accum := 0.0
func _process(delta: float) -> void:
	_cull_accum += delta
	if _cull_accum < 0.25:
		return
	_cull_accum = 0.0
	_update_tree_visibility(false)

func make_tree_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.28, 0.16)
	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.16, 0.34, 0.16)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.25
	trunk.height = 1.6
	trunk.material = wood
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk.get_mesh_arrays())
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 1.6
	crown.material = leaves
	var carr: Array = crown.get_mesh_arrays()
	var verts: PackedVector3Array = carr[Mesh.ARRAY_VERTEX]
	var offset := Vector3(0, 1.4, 0)
	for i in verts.size():
		verts[i] += offset
	carr[Mesh.ARRAY_VERTEX] = verts
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	return m

func _make_trunk_mesh() -> Mesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.25
	trunk.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.28, 0.16)
	mat.roughness = 0.9
	trunk.material = mat
	return trunk

func _make_crown_mesh() -> Mesh:
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.34, 0.16)
	mat.roughness = 0.95
	crown.material = mat
	return crown
