extends Node3D
## TerrainGenerator — Phase 0 procedural world.
## Seeded heightfield (fBM + domain warp), biome tinting, and scattered
## woodland. Water plane and flora are Phase 1 refinements.

const GRID := 160                # grid points per side
const SPACING := 4.0             # world units between points
const AMPLITUDE := 22.0          # vertical scale
const SEA_LEVEL := 0.08
const TREE_COUNT := 260

var world_seed := 0
var height_noise := FastNoiseLite.new()
var moisture_noise := FastNoiseLite.new()

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

func height_at(x: float, z: float) -> float:
	return height_noise.get_noise_2d(x, z)

func moisture_at(x: float, z: float) -> float:
	return moisture_noise.get_noise_2d(x, z)

func ground_height(wx: float, wz: float) -> float:
	return height_at(wx * 0.25, wz * 0.25) * AMPLITUDE

func biome_color(h: float, m: float) -> Color:
	if h < -SEA_LEVEL - 0.06:
		return Color(0.15, 0.35, 0.55)             # deep water
	if h < -SEA_LEVEL:
		return Color(0.25, 0.45, 0.65)             # shallow water
	if h < -SEA_LEVEL + 0.03:
		return Color(0.83, 0.78, 0.6)              # sand
	var c := Color(0.42, 0.62, 0.31)               # grass base
	c = c.lerp(Color(0.2, 0.42, 0.2), maxf(m, 0.0) * 1.2)      # forest tones
	c = c.lerp(Color(0.75, 0.72, 0.5), maxf(-m, 0.0) * 1.1)    # dry plains
	if h > 0.35:
		c = c.lerp(Color(0.5, 0.46, 0.42), 0.6)    # rock
	if h > 0.6:
		c = c.lerp(Color(0.95, 0.95, 0.98), 0.85)  # snow
	return c

func build_terrain() -> void:
	var terrain := MeshInstance3D.new()
	terrain.name = "TerrainMesh"
	terrain.mesh = build_mesh()
	terrain.create_trimesh_collision()
	add_child(terrain)
	build_water()
	build_trees()

func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := (GRID - 1) * SPACING * 0.5
	for z in GRID:
		for x in GRID:
			var wx := -half + x * SPACING
			var wz := -half + z * SPACING
			var h := height_at(x, z)
			var m := moisture_at(x, z)
			st.set_color(biome_color(h, m))
			st.add_vertex(Vector3(wx, h * AMPLITUDE, wz))
	for z in (GRID - 1):
		for x in (GRID - 1):
			var i := z * GRID + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + GRID)
			st.add_index(i + GRID)
			st.add_index(i + 1)
			st.add_index(i + GRID + 1)
	st.generate_normals()
	return st.commit()

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
	add_child(water)

func build_trees() -> void:
	var tree_mesh := make_tree_mesh()
	var half := (GRID - 1) * SPACING * 0.5
	var placed := 0
	var attempts := 0
	while placed < TREE_COUNT and attempts < TREE_COUNT * 4:
		attempts += 1
		var wx := randf_range(-half, half)
		var wz := randf_range(-half, half)
		var h := height_at(wx / SPACING, wz / SPACING)
		var m := moisture_at(wx / SPACING, wz / SPACING)
		if h < 0.03 or h > 0.5 or m < -0.05:
			continue
		var tree := MeshInstance3D.new()
		tree.mesh = tree_mesh
		tree.position = Vector3(wx, h * AMPLITUDE, wz)
		var s := randf_range(0.7, 1.5)
		tree.scale = Vector3(s, randf_range(0.9, 1.4), s)
		add_child(tree)
		placed += 1

func make_tree_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.28, 0.16)
	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.16, 0.34, 0.16)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.25
	trunk.height = 1.6
	trunk.material = wood
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk.get_mesh_arrays())

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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	return mesh