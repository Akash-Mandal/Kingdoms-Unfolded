extends Node
var buildings: Dictionary = {}
var units: Dictionary = {}
var tech: Dictionary = {}
var events: Array[Dictionary] = []
var main_quest: Dictionary = {}
var missions: Dictionary = {}
var treaties: Dictionary = {}
var side_stories: Dictionary = {}
var side_games: Dictionary = {}
var scenarios: Dictionary = {}
var balance: Dictionary = {}
var _loaded := false

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_load_buildings()
	_load_units()
	_load_tech()
	_load_events()
	_load_main_quest()
	_load_missions()
	_load_treaties()
	_load_side_stories()
	_load_side_games()
	_load_scenarios()
	_load_balance()
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
	for entry in parsed as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			var id: String = str(entry.get("id", "")).strip_edges()
			if id == "":
				continue
			if not entry.has("cost"):
				entry["cost"] = {}
			if not entry.has("prod"):
				entry["prod"] = {}
			if not entry.has("cons"):
				entry["cons"] = {}
			if not entry.has("capacity"):
				entry["capacity"] = {}
			if not entry.has("icon"):
				entry["icon"] = "🏠"
			if not entry.has("name"):
				entry["name"] = id.capitalize()
			for k in ["cost", "prod", "cons", "capacity"]:
				var dv: Variant = entry.get(k, {})
				if typeof(dv) != TYPE_DICTIONARY:
					entry[k] = {}
			buildings[id] = entry

func _load_events() -> void:
	var path := "res://data/catalog/events.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Catalog: events.json malformed")
		return
	events.clear()
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			events.append(e as Dictionary)

func _load_main_quest() -> void:
	var path := "res://data/catalog/main_quest.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		main_quest = parsed as Dictionary

func _load_missions() -> void:
	var path := "res://data/catalog/missions.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	missions.clear()
	if typeof(parsed) == TYPE_ARRAY:
		for e in parsed as Array:
			if typeof(e) == TYPE_DICTIONARY:
				var id: String = str(e.get("id", ""))
				if id != "":
					missions[id] = e
	elif typeof(parsed) == TYPE_DICTIONARY:
		for k in (parsed as Dictionary).keys():
			var v: Variant = (parsed as Dictionary)[k]
			if typeof(v) == TYPE_DICTIONARY:
				var nid: String = str(v.get("id", k))
				if nid != "":
					missions[nid] = v
		if missions.is_empty():
			push_warning("Catalog: missions.json Dictionary with no id fields")
	else:
		push_warning("Catalog: missions.json malformed expected Array or Dictionary")

func _load_treaties() -> void:
	var path := "res://data/catalog/treaties.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		treaties.clear()
		for k in (parsed as Dictionary).keys():
			var v: Variant = (parsed as Dictionary)[k]
			if typeof(v) == TYPE_DICTIONARY:
				var nid: String = str(v.get("id", k))
				if nid != "":
					treaties[nid] = v
					var aliases: Variant = v.get("aliases", [])
					if aliases is Array:
						for a in aliases as Array:
							var alias_key: String = str(a).strip_edges()
							if alias_key != "" and not treaties.has(alias_key):
								treaties[alias_key] = v
	elif typeof(parsed) == TYPE_ARRAY:
		treaties.clear()
		for e in parsed as Array:
			if typeof(e) == TYPE_DICTIONARY:
				var tid: String = str(e.get("id", "")).strip_edges()
				if tid != "":
					treaties[tid] = e
					var aliases: Variant = e.get("aliases", [])
					if aliases is Array:
						for a in aliases as Array:
							var alias_key2: String = str(a).strip_edges()
							if alias_key2 != "" and not treaties.has(alias_key2):
								treaties[alias_key2] = e

func _load_tech() -> void:
	var path := "res://data/catalog/tech.json"
	if not FileAccess.file_exists(path):
		push_warning("Catalog: tech.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Catalog: tech.json malformed")
		return
	tech.clear()
	for entry in parsed as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			var id: String = str(entry.get("id", ""))
			if id != "":
				tech[id] = entry

func get_building(id: String) -> Dictionary:
	return buildings.get(id, {})

func building_ids() -> Array:
	return buildings.keys()

func _load_units() -> void:
	var path := "res://data/catalog/units.json"
	if not FileAccess.file_exists(path):
		push_warning("Catalog: units.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Catalog: units.json malformed")
		return
	for entry in parsed as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			var id: String = entry.get("id", "")
			if id != "":
				units[id] = entry

func get_unit(id: String) -> Dictionary:
	return units.get(id, {})

func unit_ids() -> Array:
	return units.keys()

func get_tech(id: String) -> Dictionary:
	return tech.get(id, {})

func tech_ids() -> Array:
	return tech.keys()

func tech_by_branch(branch: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in tech:
		if str(tech[k].get("branch", "")) == branch:
			out.append(tech[k])
	out.sort_custom(func(a, b): return int(a.get("tier", 99)) < int(b.get("tier", 99)))
	return out

func get_event(id: String) -> Dictionary:
	for e in events:
		if str(e.get("id", "")) == id:
			return e
	return {}

func event_ids() -> Array:
	var out: Array = []
	for e in events:
		out.append(str(e.get("id", "")))
	return out

func events_by_category(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if str(e.get("category", "")) == cat:
			out.append(e)
	return out

func get_main_quest() -> Dictionary:
	return main_quest

func get_acts() -> Array:
	var a: Variant = main_quest.get("acts", [])
	if typeof(a) == TYPE_ARRAY:
		return a as Array
	return []

func get_mission(id: String) -> Dictionary:
	return missions.get(id, {})

func mission_ids() -> Array:
	return missions.keys()

func missions_by_category(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in missions.keys():
		var m: Dictionary = missions[k] as Dictionary
		if str(m.get("category", "")) == cat:
			out.append(m)
	return out

func get_treaty(id: String) -> Dictionary:
	return treaties.get(id, {})

func treaty_ids() -> Array:
	var uniq: Dictionary = {}
	for k in treaties.keys():
		var e: Dictionary = treaties[k]
		var canonical: String = str(e.get("id", k))
		uniq[canonical] = true
	return uniq.keys()

func _load_side_stories() -> void:
	var path := "res://data/catalog/side_stories.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Catalog: side_stories.json malformed")
		return
	side_stories.clear()
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			var id: String = str(e.get("id", ""))
			if id != "":
				side_stories[id] = e

func _load_side_games() -> void:
	var path := "res://data/catalog/side_games.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Catalog: side_games.json malformed")
		return
	side_games.clear()
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			var id: String = str(e.get("id", ""))
			if id != "":
				side_games[id] = e

func _load_scenarios() -> void:
	var path := "res://data/catalog/scenarios.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Catalog: scenarios.json malformed")
		return
	scenarios.clear()
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			var id: String = str(e.get("id", ""))
			if id != "":
				scenarios[id] = e

func get_side_story(id: String) -> Dictionary:
	return side_stories.get(id, {})

func side_story_ids() -> Array:
	return side_stories.keys()

func get_side_game(id: String) -> Dictionary:
	return side_games.get(id, {})

func side_game_ids() -> Array:
	return side_games.keys()

func get_scenario(id: String) -> Dictionary:
	return scenarios.get(id, {})

func scenario_ids() -> Array:
	return scenarios.keys()

func preset_scenario_ids() -> Array:
	var out: Array = []
	for k in scenarios.keys():
		if not bool(scenarios[k].get("is_custom", false)):
			out.append(k)
	return out

func _load_balance() -> void:
	var path := "res://data/catalog/balance.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		balance = parsed as Dictionary

func get_balance(path: String = "") -> Variant:
	if path == "":
		return balance
	var cur: Variant = balance
	for part in path.split("."):
		if typeof(cur) == TYPE_DICTIONARY and (cur as Dictionary).has(part):
			cur = (cur as Dictionary)[part]
		else:
			return null
	return cur
