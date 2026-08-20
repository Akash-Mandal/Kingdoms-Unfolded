extends Node
signal scenario_changed(id: String)
signal custom_generated(prompt: String, scenario: Dictionary)

var catalog: Dictionary = {}
var active_id: String = "default"
var custom_scenario: Dictionary = {}
var timeline_notes: Array[Dictionary] = []
var _loaded := false

func _ready() -> void:
	_load()

func _load() -> void:
	var c: Node = get_node_or_null("/root/Catalog")
	if c != null and "scenarios" in c and c.scenarios is Dictionary and not (c.scenarios as Dictionary).is_empty():
		catalog = (c.scenarios as Dictionary).duplicate(true)
		_loaded = true
		return
	var path := "res://data/catalog/scenarios.json"
	if not FileAccess.file_exists(path):
		push_warning("Scenarios: scenarios.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Scenarios: malformed")
		return
	catalog.clear()
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			var id: String = str(e.get("id", ""))
			if id != "":
				catalog[id] = (e as Dictionary).duplicate(true)
	_loaded = true

func reload() -> void:
	_load()

func scenario_ids() -> Array:
	return catalog.keys()

func preset_ids() -> Array:
	var out: Array = []
	for k in catalog.keys():
		if not bool(catalog[k].get("is_custom", false)):
			out.append(k)
	return out

func get_scenario(id: String) -> Dictionary:
	return catalog.get(id, {})

func get_active() -> Dictionary:
	return get_scenario(active_id)

func has_custom() -> bool:
	return not custom_scenario.is_empty()

func apply_scenario(id: String, to_game: bool = true) -> bool:
	if not catalog.has(id):
		return false
	active_id = id
	if to_game and has_node("/root/Game"):
		var g: Node = get_node("/root/Game")
		var sc: Dictionary = catalog[id]
		var mods: Variant = sc.get("starting_modifiers", {})
		if mods is Dictionary:
			for k in (mods as Dictionary).keys():
				if k in ["happiness"] and "pop_happiness" in g:
					g.set("pop_happiness", clampf(float(g.get("pop_happiness")) + float((mods as Dictionary)[k]), 0.0, 1.0))
				elif k in ["gold","food","wood","stone","iron","cloth","horses","knowledge","grain","flour"]:
					if "resources" in g and g.resources is Dictionary and g.resources.has(k):
						var r: Dictionary = g.resources[k]
						r["stock"] = float(r.get("stock", 0.0)) + float((mods as Dictionary)[k])
		var era: Variant = sc.get("era", null)
		if era != null and str(era) != "custom" and str(era) != "" and "settings" in g:
			g.settings["era"] = str(era)
			g.settings["scenario"] = id
		elif "settings" in g:
			g.settings["scenario"] = id
		var season: Variant = sc.get("starting_season", null)
		if season != null and g.has_method("season"):
			pass
		if g.has_signal("resources_changed"):
			g.resources_changed.emit()
		if g.has_signal("population_changed"):
			g.population_changed.emit()
		_note_timeline("Applied scenario: %s" % str(sc.get("name", id)))
	scenario_changed.emit(id)
	return true

func generate_custom(prompt: String) -> Dictionary:
	var base: Dictionary = get_scenario("custom").duplicate(true)
	if base.is_empty():
		base = {"id": "custom", "name": "Custom", "icon": "✨"}
	var p: String = prompt.strip_edges()
	if p == "":
		p = "Fertile but fractured borderlands seeking legitimacy."
	var gen: Dictionary = {
		"id": "custom_generated",
		"name": "Custom: %s" % p.substr(0, 32),
		"icon": "✨",
		"description": "AI premise: %s" % p,
		"timeline_label": "Custom — %s" % p.substr(0, 24),
		"duration_turns": 36,
		"difficulty": "iron",
		"era": "custom",
		"victory": "AI victory: stabilize within 36 turns",
		"defeat": "Collapse before narrative resolves",
		"starting_modifiers": {},
		"special_rules": ["Gemini will narrate this premise each turn"],
		"gemini_theme": p,
		"is_custom": true,
		"prompt": p,
		"generated_at_turn": _turn(),
	}
	custom_scenario = gen
	catalog["custom_generated"] = gen
	active_id = "custom_generated"
	custom_generated.emit(p, gen)
	scenario_changed.emit(active_id)
	_note_timeline("Custom scenario generated: %s" % p)
	return gen

func _turn() -> int:
	if has_node("/root/Game"):
		return int(get_node("/root/Game").get("turn"))
	return 0

func _note_timeline(text: String) -> void:
	timeline_notes.append({"turn": _turn(), "text": text})
	if timeline_notes.size() > 64:
		timeline_notes.remove_at(0)

func annotate_timeline(turn: int, note: String) -> void:
	timeline_notes.append({"turn": turn, "text": note})

func get_timeline() -> Array[Dictionary]:
	return timeline_notes.duplicate()

func compare_timelines(a: Array[Dictionary], b: Array[Dictionary]) -> Dictionary:
	return {"a_size": a.size(), "b_size": b.size(), "a_last": a.back() if not a.is_empty() else {}, "b_last": b.back() if not b.is_empty() else {}}

func summarize_range(from_turn: int, to_turn: int) -> String:
	var slice: Array[Dictionary] = []
	for n in timeline_notes:
		if int(n.get("turn", 0)) >= from_turn and int(n.get("turn", 0)) <= to_turn:
			slice.append(n)
	if slice.is_empty():
		return "No notable events between turns %d–%d." % [from_turn, to_turn]
	var parts: PackedStringArray = PackedStringArray()
	for n in slice:
		parts.append("T%d: %s" % [int(n.get("turn", 0)), String(n.get("text", ""))])
	return "\n".join(parts)

func serialize() -> Dictionary:
	return {"active_id": active_id, "custom_scenario": custom_scenario.duplicate(true), "timeline_notes": timeline_notes.duplicate(true)}

func restore(data: Dictionary) -> void:
	active_id = str(data.get("active_id", "default"))
	var cs: Variant = data.get("custom_scenario", {})
	if cs is Dictionary:
		custom_scenario = (cs as Dictionary).duplicate(true)
		if not custom_scenario.is_empty():
			catalog["custom_generated"] = custom_scenario
	var tl: Variant = data.get("timeline_notes", [])
	if tl is Array:
		timeline_notes.clear()
		for e in tl as Array:
			if e is Dictionary:
				timeline_notes.append(e as Dictionary)
