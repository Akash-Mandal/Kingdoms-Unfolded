extends Node3D

signal battle_finished(outcome: Dictionary)

var _attacker_mm: MultiMeshInstance3D
var _defender_mm: MultiMeshInstance3D
var _attacker_count: int = 32
var _defender_count: int = 28
var _duration: float = 4.0
var _elapsed: float = 0.0
var _running: bool = false
var _outcome: Dictionary = {}
var _terrain_name: String = "plains"
var _attacker_power: float = 0.0
var _defender_power: float = 0.0
var _start_a: Vector3 = Vector3(-34, 0, 0)
var _start_d: Vector3 = Vector3(34, 0, 0)
var _mid: Vector3 = Vector3(0, 0, 0)
var _ground_y: float = 0.0

func setup(center: Vector3, ground_y: float, attacker: Dictionary, defender: Dictionary, terrain: String) -> void:
	_mid = center
	_ground_y = ground_y
	_terrain_name = terrain
	_attacker_power = 0.0
	_defender_power = 0.0
	if Engine.has_singleton("Military"):
		pass
	var mil: Node = get_node_or_null("/root/Military")
	if mil != null and mil.has_method("calc_power"):
		_attacker_power = mil.calc_power(attacker, terrain)
		_defender_power = mil.calc_power(defender, terrain)
	else:
		_attacker_power = _fallback_power(attacker)
		_defender_power = _fallback_power(defender)
	_attacker_count = clampi(_count_from_dict(attacker), 8, 64)
	_defender_count = clampi(_count_from_dict(defender), 8, 64)
	if _attacker_count < 8 and _attacker_power > 0:
		_attacker_count = 16
	if _defender_count < 8 and _defender_power > 0:
		_defender_count = 16
	_build_army(true, _attacker_count, _start_a + _mid)
	_build_army(false, _defender_count, _start_d + _mid)

func _fallback_power(side: Dictionary) -> float:
	var s: float = 0.0
	for k in side.keys():
		var v: Variant = side[k]
		var c: int = int(v.get("count", 0)) if typeof(v) == TYPE_DICTIONARY else int(v)
		s += float(c) * 5.0
	return s

func _count_from_dict(d: Dictionary) -> int:
	var s: int = 0
	for k in d.keys():
		var v: Variant = d[k]
		if typeof(v) == TYPE_DICTIONARY:
			s += int(v.get("count", 0))
		else:
			s += int(v)
	return s

func _build_army(is_attacker: bool, count: int, center: Vector3) -> void:
	var mesh: Mesh = _unit_mesh(is_attacker)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.25, 0.25) if is_attacker else Color(0.25, 0.45, 0.85)
	mat.roughness = 0.7
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = 2.2
	var half: float = (float(cols) * spacing) * 0.5
	for i in count:
		var r: int = i / cols
		var c: int = i % cols
		var jitter := Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		var pos := Vector3(center.x + float(c) * spacing - half, _ground_y + 0.9, center.z + float(r) * spacing - half) + jitter
		var t := Transform3D(Basis.IDENTITY, pos)
		t = t.scaled(Vector3(1, 1, 1) * randf_range(0.9, 1.15))
		mm.set_instance_transform(i, t)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(inst)
	if is_attacker:
		if _attacker_mm != null:
			_attacker_mm.queue_free()
		_attacker_mm = inst
	else:
		if _defender_mm != null:
			_defender_mm.queue_free()
		_defender_mm = inst

func _unit_mesh(is_attacker: bool) -> Mesh:
	var m := ArrayMesh.new()
	var body := CapsuleMesh.new()
	body.radius = 0.35
	body.height = 1.8
	body.radial_segments = 8
	body.rings = 1
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.get_mesh_arrays())
	var head := SphereMesh.new()
	head.radius = 0.42
	head.height = 0.84
	var carr: Array = head.get_mesh_arrays()
	var verts: PackedVector3Array = carr[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += Vector3(0, 1.05, 0)
	carr[Mesh.ARRAY_VERTEX] = verts
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, carr)
	return m

func launch() -> void:
	if _running:
		return
	_running = true
	_elapsed = 0.0
	if _outcome.is_empty():
		var mil: Node = get_node_or_null("/root/Military")
		if mil != null and mil.has_method("resolve_battle"):
			_outcome = mil.resolve_battle(_attacker_power, _defender_power, _terrain_name)
		else:
			var total: float = _attacker_power + _defender_power
			var roll: float = randf() * total
			_outcome = {"winner": "attacker" if roll < _attacker_power else "defender", "attacker_power": _attacker_power, "defender_power": _defender_power, "terrain": _terrain_name}

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var march: float = ease(t, 0.45)
	_update_positions(march)
	if t >= 1.0:
		_running = false
		_flash_outcome()
		battle_finished.emit(_outcome)
		var mil: Node = get_node_or_null("/root/Military")
		if mil != null and mil.has_method("auto_resolve"):
			pass
		await get_tree().create_timer(2.0).timeout
		queue_free()

func _update_positions(march: float) -> void:
	if _attacker_mm == null or _defender_mm == null:
		return
	var clash_a: Vector3 = _mid + Vector3(-2.5, 0, 0)
	var clash_d: Vector3 = _mid + Vector3(2.5, 0, 0)
	_shift_multimesh(_attacker_mm, _start_a + _mid, clash_a, march, true)
	_shift_multimesh(_defender_mm, _start_d + _mid, clash_d, march, false)
	if march > 0.88:
		var shake: float = sin(_elapsed * 28.0) * 0.12 * (1.0 - march)
		_attacker_mm.position.x += shake
		_defender_mm.position.x -= shake

func _shift_multimesh(inst: MultiMeshInstance3D, from_c: Vector3, to_c: Vector3, march: float, is_attacker: bool) -> void:
	var mm: MultiMesh = inst.multimesh
	if mm == null:
		return
	var count: int = mm.instance_count
	var cols: int = int(ceil(sqrt(float(count))))
	var spacing: float = 2.2
	var half: float = (float(cols) * spacing) * 0.5
	var dir: float = -1.0 if is_attacker else 1.0
	var bob: float = sin(_elapsed * 6.0) * 0.06
	for i in count:
		var r: int = i / cols
		var c: int = i % cols
		var base_from := Vector3(from_c.x + float(c) * spacing - half, _ground_y + 0.9, from_c.z + float(r) * spacing - half)
		var base_to := Vector3(to_c.x + float(c) * spacing * 0.85 - half * 0.85, _ground_y + 0.9, to_c.z + float(r) * spacing * 0.85 - half * 0.85)
		var pos: Vector3 = base_from.lerp(base_to, march)
		pos.y += bob * (0.5 + 0.5 * sin(float(i) * 1.7))
		pos.x += dir * march * 0.15 * sin(float(i) * 2.3 + _elapsed * 4.0)
		var t := Transform3D(Basis.IDENTITY, pos)
		mm.set_instance_transform(i, t)

func _flash_outcome() -> void:
	var winner: String = str(_outcome.get("winner", "attacker"))
	var color := Color(0.95, 0.25, 0.25) if winner == "attacker" else Color(0.25, 0.55, 0.95)
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.0
	sphere.height = 6.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color * 0.9
	sphere.material = mat
	flash.mesh = sphere
	flash.position = _mid + Vector3(0, 2.5, 0)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3(2.2, 2.2, 2.2), 0.35)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
