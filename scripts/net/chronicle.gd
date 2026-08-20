extends Node
signal entry_added(entry: Dictionary)
signal chronicle_cleared
var entries: Array[Dictionary] = []
var _hooks: PackedStringArray = []
const MAX_ENTRIES := 500
const SAVE_PATH := "user://saves/chronicle.json"
func _ready() -> void:
	_load()
	var np: Node = get_node_or_null("/root/NarrativeProvider")
	if np != null and np.has_signal("narrative_ready"):
		np.narrative_ready.connect(_on_narrative)
	Game.turned.connect(_on_turn_backup)
func _on_narrative(event: Dictionary, result: Dictionary) -> void:
	append(event, result)
func append(event: Dictionary, result: Dictionary) -> void:
	var entry: Dictionary = {
		"turn": Game.turn,
		"year": Game.year,
		"month": Game.month,
		"season": Game.season(),
		"event_id": str(event.get("id", event.get("template_id", ""))),
		"event_type": str(event.get("type", event.get("category", "random"))),
		"event_name": str(event.get("name", event.get("type", ""))),
		"raw_text": str(event.get("text", "")),
		"text": str(result.get("text", "")),
		"choices": result.get("choices", []),
		"hooks": result.get("hooks", []),
		"provider": str(result.get("provider", "local")),
		"kingdom": str(Game.settings.get("kingdom_name", "Eterna")),
		"timestamp": Time.get_unix_time_from_system(),
	}
	entries.append(entry)
	for h in entry["hooks"] as Array:
		if typeof(h) == TYPE_STRING and not _hooks.has(h as String):
			_hooks.append(h as String)
	while _hooks.size() > 12:
		_hooks.remove_at(0)
	while entries.size() > MAX_ENTRIES:
		entries.remove_at(0)
	entry_added.emit(entry)
	_save()
func on_turn() -> void:
	if entries.is_empty() or int(entries.back().get("turn", -1)) != Game.turn:
		var filler: Dictionary = {
			"turn": Game.turn,
			"year": Game.year,
			"month": Game.month,
			"season": Game.season(),
			"event_id": "turn_%d" % Game.turn,
			"event_type": "chronicle",
			"event_name": "Month's passage",
			"raw_text": "",
			"text": _turn_prose(),
			"choices": [],
			"hooks": [],
			"provider": "local",
			"kingdom": str(Game.settings.get("kingdom_name", "Eterna")),
			"timestamp": Time.get_unix_time_from_system(),
		}
		entries.append(filler)
		entry_added.emit(filler)
		_save()
func _turn_prose() -> String:
	var k: String = str(Game.settings.get("kingdom_name", "Eterna"))
	var s: String = Game.season()
	var pop: int = int(Game.pop_count)
	var food: int = int(Game.get_stock("food"))
	return "%s endures through %s — %d souls, %d food in store." % [k, s, pop, food]
func recent_hooks(n: int) -> Array:
	var out: Array = []
	var start: int = maxi(0, _hooks.size() - n)
	for i in range(start, _hooks.size()):
		out.append(_hooks[i])
	return out
func history(limit: int = 20) -> Array[Dictionary]:
	if limit <= 0 or limit >= entries.size():
		return entries.duplicate()
	return entries.slice(entries.size() - limit, entries.size())
func full_text(limit: int = 40) -> String:
	var parts: PackedStringArray = []
	var arr: Array[Dictionary] = history(limit)
	for e in arr:
		parts.append("[Y%d M%d %s] %s" % [int(e.get("year", 0)), int(e.get("month", 1)), str(e.get("season", "")), str(e.get("text", ""))])
	return "\n\n".join(parts)
func serialize() -> Array:
	return entries.duplicate(true)
func restore(data: Array) -> void:
	entries.clear()
	_hooks.clear()
	for e in data:
		if typeof(e) == TYPE_DICTIONARY:
			entries.append(e as Dictionary)
			for h in (e as Dictionary).get("hooks", []) as Array:
				if typeof(h) == TYPE_STRING and not _hooks.has(h as String):
					_hooks.append(h as String)
func clear() -> void:
	entries.clear()
	_hooks.clear()
	chronicle_cleared.emit()
	_save()
func _save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"entries": entries, "hooks": Array(_hooks)}))
	f.close()
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed as Dictionary
		var arr: Variant = d.get("entries", [])
		if typeof(arr) == TYPE_ARRAY:
			for e in arr as Array:
				if typeof(e) == TYPE_DICTIONARY:
					entries.append(e as Dictionary)
		var hk: Variant = d.get("hooks", [])
		if typeof(hk) == TYPE_ARRAY:
			for h in hk as Array:
				if typeof(h) == TYPE_STRING:
					_hooks.append(h as String)
func _on_turn_backup() -> void:
	_save()
