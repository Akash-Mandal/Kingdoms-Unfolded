extends Node3D
## Building — a placed building instance. Holds its catalog id and a procedural mesh.

var building_id: String = ""

func setup(id: String, mesh: ArrayMesh) -> void:
	building_id = id
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position.y = 0.3
	add_child(inst)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 4, 6)
	col.shape = shape
	col.position.y = 1.0
	add_child(col)
