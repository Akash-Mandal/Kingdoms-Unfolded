extends Node
## Catalog — loads data-driven JSON catalogs from data/catalog/ at startup.
## Single source of truth for content (buildings, units, tech, events, …).

var buildings: Dictionary = {}
var _loaded := false

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_load_buildings()
	_loaded = true

func _load_buildings() -> void:
	var path := "res://data/catalog/buildings.json"
	if not FileAccess.file_exists(path):
		push_warning("Catalog: buildings.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Catalog: buildings.json malformed")
		return
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY:
			var id: String = entry.get("id", "")
			if id != "":
				buildings[id] = entry

func get_building(id: String) -> Dictionary:
	return buildings.get(id, {})

func building_ids() -> Array:
	return buildings.keys()
