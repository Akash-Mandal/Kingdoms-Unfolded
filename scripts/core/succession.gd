extends Node
signal ruler_died(old_ruler: Dictionary, cause: String)
signal heir_ascended(new_ruler: Dictionary)
signal regency_started(heir: Dictionary, regent: Dictionary)
signal regency_ended

var ruler: Dictionary = {}
var heir: Dictionary = {}
var lineage: Array[Dictionary] = []
var is_regency: bool = false
var regent: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_init_from_game()

func _init_from_game() -> void:
	if has_node("/root/Game"):
		var g: Node = get_node("/root/Game")
		var s: Dictionary = g.get("settings") if "settings" in g else {}
		ruler = {
			"name": str(s.get("ruler_name", "Aurelia")),
			"age": int(s.get("ruler_age", 28)),
			"gender": str(s.get("ruler_gender", "male")),
			"traits": s.get("traits", []),
			"reign_start_turn": int(g.get("turn")) if "turn" in g else 0,
		}
		heir = _generate_heir(ruler, 0)

func _generate_heir(parent: Dictionary, age: int = 0) -> Dictionary:
	var names_m: PackedStringArray = ["Aric","Cael","Darian","Edric","Joren"]
	var names_f: PackedStringArray = ["Aurelia","Lyssa","Mira","Seren","Yara"]
	var g: String = "male" if _rng.randi() % 2 == 0 else "female"
	var pool: PackedStringArray = names_m if g == "male" else names_f
	var nm: String = pool[_rng.randi() % pool.size()]
	var traits_pool: PackedStringArray = ["Brave","Wise","Just","Ambitious","Kind","Cunning","Pious","Stubborn"]
	var t: Array = []
	for i in 2:
		t.append(traits_pool[_rng.randi() % traits_pool.size()])
	return {"name": nm, "age": age, "gender": g, "traits": t, "claim": 1.0, "born_turn": _turn()}

func get_ruler() -> Dictionary:
	return ruler.duplicate(true)

func get_heir() -> Dictionary:
	return heir.duplicate(true)

func is_child_heir() -> bool:
	return int(heir.get("age", 16)) < 16

func tick() -> void:
	if ruler.is_empty():
		_init_from_game()
	ruler["age"] = int(ruler.get("age", 28)) + 0
	if has_node("/root/Game") and int(get_node("/root/Game").get("turn")) % 12 == 0 and not ruler.is_empty():
		ruler["age"] = int(ruler.get("age", 28)) + 1
		heir["age"] = int(heir.get("age", 0)) + 1
		if is_regency and int(heir.get("age", 0)) >= 16:
			_resolve_regency()

func trigger_death(cause: String = "natural") -> Dictionary:
	if ruler.is_empty():
		_init_from_game()
	var old: Dictionary = ruler.duplicate(true)
	lineage.append(old)
	ruler_died.emit(old, cause)
	_push_event("Death of %s, aged %d — %s. Heir %s ascends." % [String(old.get("name", "?")), int(old.get("age", 0)), cause, String(heir.get("name", "?"))])
	if is_child_heir():
		is_regency = true
		regent = _pick_regent()
		regency_started.emit(heir.duplicate(true), regent.duplicate(true))
		return {"regency": true, "heir": heir.duplicate(true), "regent": regent.duplicate(true)}
	else:
		ruler = heir.duplicate(true)
		ruler["reign_start_turn"] = _turn()
		heir = _generate_heir(ruler, 0)
		heir_ascended.emit(ruler.duplicate(true))
		is_regency = false
		regent.clear()
		_sync_to_game()
		return {"regency": false, "ruler": ruler.duplicate(true)}

func _pick_regent() -> Dictionary:
	var pool: PackedStringArray = ["Lord Regent Calder","Dowager Empress","Archon Virelle","Council of Three"]
	var nm: String = pool[_rng.randi() % pool.size()]
	return {"name": nm, "loyalty": 0.6 + _rng.randf() * 0.3, "ambition": _rng.randf()}

func _resolve_regency() -> void:
	if not is_regency:
		return
	ruler = heir.duplicate(true)
	ruler["reign_start_turn"] = _turn()
	heir = _generate_heir(ruler, 0)
	is_regency = false
	regent.clear()
	regency_ended.emit()
	heir_ascended.emit(ruler.duplicate(true))
	_push_event("Regency ends. %s crowned at age %d." % [String(ruler.get("name", "?")), int(ruler.get("age", 0))])
	_sync_to_game()

func force_succession(new_name: String = "") -> void:
	if new_name != "":
		heir["name"] = new_name
	trigger_death("abdication")

func _sync_to_game() -> void:
	if has_node("/root/Game") and "settings" in get_node("/root/Game"):
		var g: Node = get_node("/root/Game")
		g.settings["ruler_name"] = String(ruler.get("name", ""))
		g.settings["ruler_age"] = int(ruler.get("age", 28))
		g.settings["ruler_gender"] = String(ruler.get("gender", "male"))
		g.settings["traits"] = ruler.get("traits", [])

func _push_event(text: String) -> void:
	if not has_node("/root/Game"):
		return
	var g: Node = get_node("/root/Game")
	var ev := {"id": g.events.size() if "events" in g else 0, "turn": _turn(), "type": "succession", "severity": 3, "text": text}
	if "events" in g and g.events is Array:
		g.events.push_front(ev)
	if g.has_signal("event_occurred"):
		g.event_occurred.emit(ev)

func _turn() -> int:
	if has_node("/root/Game"):
		return int(get_node("/root/Game").get("turn"))
	return 0

func serialize() -> Dictionary:
	return {"ruler": ruler.duplicate(true), "heir": heir.duplicate(true), "lineage": lineage.duplicate(true), "is_regency": is_regency, "regent": regent.duplicate(true)}

func restore(data: Dictionary) -> void:
	ruler = data.get("ruler", ruler)
	heir = data.get("heir", heir)
	var lin: Variant = data.get("lineage", [])
	if lin is Array:
		lineage.clear()
		for e in lin as Array:
			if e is Dictionary:
				lineage.append(e as Dictionary)
	is_regency = bool(data.get("is_regency", false))
	regent = data.get("regent", {})
