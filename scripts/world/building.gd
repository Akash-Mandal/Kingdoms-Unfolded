extends Node3D

var building_id: String = ""

func setup(id: String, mesh: ArrayMesh) -> void:
	building_id = id
	var existing: MeshInstance3D = null
	for c in get_children():
		if c is MeshInstance3D:
			existing = c as MeshInstance3D
			break
	if existing != null:
		existing.mesh = mesh
		existing.visibility_range_end = 380.0
		existing.visibility_range_begin = 0.0
		return
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position.y = 0.3
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	inst.visibility_range_end = 380.0
	inst.visibility_range_begin = 0.0
	add_child(inst)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 4, 6)
	col.shape = shape
	col.position.y = 1.0
	add_child(col)

func reuse(id: String, mesh: ArrayMesh) -> void:
	building_id = id
	visible = true
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).mesh = mesh
			(c as MeshInstance3D).visible = true
			break
