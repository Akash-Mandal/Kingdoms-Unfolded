extends Node
signal court_changed
signal advisor_added(id: String)
signal advisor_removed(id: String)
signal marriage_proposed(a: String, b: String)
signal succession_triggered

var advisors: Array[Dictionary] = []
var nobles: Array[Dictionary] = []
var marriages: Array[Dictionary] = []
var court_mood: float = 0.6
var succession: Node = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_seed_defaults()
	if has_node("/root/Succession"):
		succession = get_node("/root/Succession")
		if succession.has_signal("ruler_died"):
			succession.ruler_died.connect(func(o: Dictionary, c: String) -> void: _on_ruler_died(o, c))
		if succession.has_signal("heir_ascended"):
			succession.heir_ascended.connect(func(n: Dictionary) -> void: _on_heir_ascended(n))

func _seed_defaults() -> void:
	if not advisors.is_empty():
		return
	var pool: Array[Dictionary] = [
		{"id": "chancellor", "name": "Chancellor Ivor", "role": "chancellor", "trait": "Wise", "loyalty": 0.72, "influence": 0.65},
		{"id": "marshal", "name": "Marshal Brune", "role": "marshal", "trait": "Brave", "loyalty": 0.68, "influence": 0.7},
		{"id": "steward", "name": "Steward Mera", "role": "steward", "trait": "Diligent", "loyalty": 0.75, "influence": 0.6},
		{"id": "spymaster", "name": "Spymaster Silas", "role": "spymaster", "trait": "Cunning", "loyalty": 0.55, "influence": 0.8},
		{"id": "chaplain", "name": "Chaplain Ysil", "role": "chaplain", "trait": "Pious", "loyalty": 0.8, "influence": 0.5},
	]
	advisors = pool
	nobles = [
		{"id": "house_valen", "name": "House Valen", "power": 22, "loyalty": 0.6, "ambition": 0.5},
		{"id": "house_kerr", "name": "House Kerr", "power": 18, "loyalty": 0.55, "ambition": 0.62},
		{"id": "house_oss", "name": "House Osswold", "power": 15, "loyalty": 0.7, "ambition": 0.4},
	]

func advisor_ids() -> Array:
	var out: Array = []
	for a in advisors:
		out.append(str(a.get("id", "")))
	return out

func get_advisor(id: String) -> Dictionary:
	for a in advisors:
		if str(a.get("id", "")) == id:
			return a
	return {}

func add_advisor(entry: Dictionary) -> bool:
	var id: String = str(entry.get("id", ""))
	if id == "" or not get_advisor(id).is_empty():
		return false
	advisors.append(entry)
	advisor_added.emit(id)
	court_changed.emit()
	return true

func remove_advisor(id: String) -> bool:
	for i in advisors.size():
		if str(advisors[i].get("id", "")) == id:
			advisors.remove_at(i)
			advisor_removed.emit(id)
			court_changed.emit()
			return true
	return false

func get_nobles() -> Array[Dictionary]:
	return nobles.duplicate()

func propose_marriage(a_house: String, b_house: String) -> bool:
	marriages.append({"houses": [a_house, b_house], "turn": _turn(), "status": "proposed"})
	marriage_proposed.emit(a_house, b_house)
	court_changed.emit()
	return true

func resolve_marriage(index: int, accept: bool) -> void:
	if index < 0 or index >= marriages.size():
		return
	marriages[index]["status"] = "accepted" if accept else "declined"
	marriages[index]["resolved_turn"] = _turn()
	if accept:
		court_mood = clampf(court_mood + 0.06, 0.0, 1.0)
	else:
		court_mood = clampf(court_mood - 0.04, 0.0, 1.0)
	court_changed.emit()

func tick() -> void:
	for a in advisors:
		var loy: float = float(a.get("loyalty", 0.6))
		a["loyalty"] = clampf(loy + _rng.randf_range(-0.02, 0.02), 0.1, 1.0)
	court_mood = clampf(court_mood + _rng.randf_range(-0.02, 0.02), 0.1, 1.0)
	if has_node("/root/Game") and has_node("/root/Succession"):
		var suc: Node = get_node("/root/Succession")
		if suc.has_method("tick"):
			suc.tick()
	court_changed.emit()

func trigger_succession(cause: String = "natural") -> Dictionary:
	if succession != null and succession.has_method("trigger_death"):
		var res: Dictionary = succession.trigger_death(cause)
		succession_triggered.emit()
		court_changed.emit()
		return res
	return {}

func _on_ruler_died(old: Dictionary, cause: String) -> void:
	court_mood = clampf(court_mood - 0.08, 0.0, 1.0)
	court_changed.emit()

func _on_heir_ascended(new_ruler: Dictionary) -> void:
	court_mood = clampf(court_mood + 0.05, 0.0, 1.0)
	court_changed.emit()

func gemini_prompt_context() -> String:
	var ruler: String = "?"
	var heir: String = "?"
	if succession != null:
		if succession.has_method("get_ruler"):
			ruler = str(succession.get_ruler().get("name", "?"))
		if succession.has_method("get_heir"):
			heir = str(succession.get_heir().get("name", "?"))
	return "Court mood %.2f, ruler %s, heir %s, advisors %d, nobles %d" % [court_mood, ruler, heir, advisors.size(), nobles.size()]

func _turn() -> int:
	if has_node("/root/Game"):
		return int(get_node("/root/Game").get("turn"))
	return 0

func serialize() -> Dictionary:
	return {"advisors": advisors.duplicate(true), "nobles": nobles.duplicate(true), "marriages": marriages.duplicate(true), "court_mood": court_mood}

func restore(data: Dictionary) -> void:
	var a: Variant = data.get("advisors", [])
	if a is Array:
		advisors.clear()
		for e in a as Array:
			if e is Dictionary:
				advisors.append(e as Dictionary)
	var n: Variant = data.get("nobles", [])
	if n is Array:
		nobles.clear()
		for e in n as Array:
			if e is Dictionary:
				nobles.append(e as Dictionary)
	var m: Variant = data.get("marriages", [])
	if m is Array:
		marriages.clear()
		for e in m as Array:
			if e is Dictionary:
				marriages.append(e as Dictionary)
	court_mood = float(data.get("court_mood", 0.6))
	court_changed.emit()
