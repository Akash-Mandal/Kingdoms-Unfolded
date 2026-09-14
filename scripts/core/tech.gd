extends Node
signal tech_unlocked(id: String)
signal research_started(id: String)
signal research_progressed(id: String, progress: float, total: float)
signal research_failed(reason: String)
var catalog: Dictionary = {}
var unlocked: Array[String] = []
var researching: String = ""
var progress: float = 0.0
var _loaded := false
const BRANCHES: Array[String] = ["agriculture", "military", "commerce", "architecture", "arcane", "governance"]
func _ready() -> void:
	_load_catalog()
func _load_catalog() -> void:
	var path := "res://data/catalog/tech.json"
	if not FileAccess.file_exists(path):
		push_warning("Tech: tech.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Tech: tech.json malformed")
		return
	catalog.clear()
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY:
			var id: String = entry.get("id", "")
			if id != "":
				catalog[id] = entry
	_loaded = true
func get_tech(id: String) -> Dictionary:
	return catalog.get(id, {})
func is_unlocked(id: String) -> bool:
	return unlocked.has(id)
func is_researching(id: String) -> bool:
	return researching == id
func can_unlock(id: String) -> bool:
	if not catalog.has(id):
		return false
	if is_unlocked(id):
		return false
	if researching != "" and researching != id:
		return false
	var entry: Dictionary = catalog[id]
	var prereqs: Array = entry.get("prereqs", [])
	for p in prereqs:
		if not is_unlocked(String(p)):
			return false
	var cost: Dictionary = entry.get("cost", {})
	var need_gold: float = float(cost.get("gold", 0.0))
	var need_know: float = float(cost.get("knowledge", 0.0))
	if need_gold > 0.0 and Game.get_stock("gold") < need_gold and researching == "":
		return false
	if need_know <= 0.0:
		return false
	return true
func can_research(id: String) -> bool:
	return can_unlock(id)
func start_research(id: String) -> bool:
	if not can_unlock(id):
		research_failed.emit("Prerequisites or cost not met: %s" % id)
		return false
	var entry: Dictionary = catalog[id]
	var cost: Dictionary = entry.get("cost", {})
	var need_gold: float = float(cost.get("gold", 0.0))
	if need_gold > 0.0:
		var r: Dictionary = Game.resources.get("gold", {})
		if float(r.get("stock", 0.0)) < need_gold:
			research_failed.emit("Not enough gold")
			return false
		r["stock"] = float(r["stock"]) - need_gold
		Game.resources_changed.emit()
	if researching != id:
		researching = id
		progress = 0.0
		research_started.emit(id)
		Game.resources_changed.emit()
	return true
func unlock(id: String) -> bool:
	if not catalog.has(id):
		return false
	if is_unlocked(id):
		return false
	if not _prereqs_met(id):
		return false
	unlocked.append(id)
	researching = ""
	progress = 0.0
	tech_unlocked.emit(id)
	_push_visible_event(id)
	Game.resources_changed.emit()
	Game.population_changed.emit()
	return true
func _prereqs_met(id: String) -> bool:
	var entry: Dictionary = catalog.get(id, {})
	for p in entry.get("prereqs", []):
		if not is_unlocked(String(p)):
			return false
	return true
func cancel_research() -> void:
	researching = ""
	progress = 0.0
func tick() -> void:
	if researching == "":
		return
	var entry: Dictionary = catalog.get(researching, {})
	if entry.is_empty():
		cancel_research()
		return
	var total: float = float(entry.get("cost", {}).get("knowledge", 0.0))
	if total <= 0.0:
		_complete()
		return
	var stock: float = Game.get_stock("knowledge")
	if stock <= 0.01:
		return
	var need: float = total - progress
	var consume: float = minf(stock, minf(need, 10.0))
	Game.resources["knowledge"]["stock"] = stock - consume
	progress += consume
	research_progressed.emit(researching, progress, total)
	Game.resources_changed.emit()
	if progress >= total - 0.001:
		_complete()
func _complete() -> void:
	var done := researching
	if done == "":
		return
	unlocked.append(done)
	researching = ""
	progress = 0.0
	tech_unlocked.emit(done)
	_push_visible_event(done)
	var an: Node = get_node_or_null("/root/Analytics")
	if an != null and an.has_method("track"):
		an.call("track", "tech_completed", {"id": done})
	Game.resources_changed.emit()
	Game.population_changed.emit()
func _push_visible_event(id: String) -> void:
	var entry: Dictionary = catalog.get(id, {})
	var txt: String = "Research complete: %s — %s" % [String(entry.get("name", id)), String(entry.get("visible_upgrade", ""))]
	var ev := {"id": Game.events.size(), "turn": Game.turn, "type": "tech", "severity": 1, "text": txt, "tech_id": id}
	Game.events.push_front(ev)
	Game.event_occurred.emit(ev)
func get_total_prod_mult(key: String) -> float:
	var m := 1.0
	for tid in unlocked:
		var e: Dictionary = catalog.get(tid, {})
		var bm: Dictionary = e.get("bonuses", {}).get("prod_mult", {})
		if bm.has(key):
			m *= float(bm[key])
	return m
func get_total_cap_add(key: String) -> float:
	var s := 0.0
	for tid in unlocked:
		var e: Dictionary = catalog.get(tid, {})
		var ca: Dictionary = e.get("bonuses", {}).get("cap_add", {})
		if ca.has(key):
			s += float(ca[key])
	return s
func get_total_happiness_add() -> float:
	var s := 0.0
	for tid in unlocked:
		var e: Dictionary = catalog.get(tid, {})
		s += float(e.get("bonuses", {}).get("happiness_add", 0.0))
	return s
func get_military_mult() -> float:
	var m := 1.0
	for tid in unlocked:
		var e: Dictionary = catalog.get(tid, {})
		var v: Variant = e.get("bonuses", {}).get("military_power_mult", null)
		if v != null:
			m *= float(v)
	return m
func get_trade_mult() -> float:
	var m := 1.0
	for tid in unlocked:
		var e: Dictionary = catalog.get(tid, {})
		var v: Variant = e.get("bonuses", {}).get("trade_value_mult", null)
		if v != null:
			m *= float(v)
	return m

func get_spoilage_mult() -> float:
	var m := 1.0
	for tid in unlocked:
		var e: Dictionary = catalog.get(tid, {})
		var v: Variant = e.get("bonuses", {}).get("spoilage_mult", null)
		if v != null:
			m *= float(v)
	return clampf(m, 0.2, 1.0)
func branch_of(id: String) -> String:
	return String(catalog.get(id, {}).get("branch", ""))
func ids_for_branch(branch: String) -> Array:
	var out: Array = []
	for k in catalog:
		if String(catalog[k].get("branch", "")) == branch:
			out.append(k)
	out.sort_custom(func(a, b): return int(catalog[a].get("tier", 99)) < int(catalog[b].get("tier", 99)))
	return out
func serialize() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "researching": researching, "progress": progress}
func deserialize(data: Dictionary) -> void:
	unlocked.clear()
	var arr: Array = data.get("unlocked", [])
	for v in arr:
		unlocked.append(String(v))
	researching = String(data.get("researching", ""))
	progress = float(data.get("progress", 0.0))
	if researching != "" and not catalog.has(researching):
		researching = ""
		progress = 0.0
func reset_state() -> void:
	unlocked.clear()
	researching = ""
	progress = 0.0
