extends Node
signal story_started(id: String)
signal chapter_advanced(id: String, chapter_idx: int)
signal story_completed(id: String)
signal story_failed(id: String)

var catalog: Dictionary = {}
var progress: Dictionary = {}
var _loaded := false

func _ready() -> void:
	_load()

func _catalog_source() -> Variant:
	var c: Node = get_node_or_null("/root/Catalog")
	if c != null and c.has_method("get_side_story"):
		return c
	return null

func _load() -> void:
	var src: Variant = _catalog_source()
	if src != null and "side_stories" in src:
		var d: Variant = src.get("side_stories")
		if d is Dictionary and not (d as Dictionary).is_empty():
			catalog = (d as Dictionary).duplicate(true)
			_ensure_progress()
			_loaded = true
			return
	var path := "res://data/catalog/side_stories.json"
	if not FileAccess.file_exists(path):
		push_warning("SideStories: side_stories.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("SideStories: malformed")
		return
	catalog.clear()
	for e in parsed as Array:
		if typeof(e) == TYPE_DICTIONARY:
			var id: String = str(e.get("id", ""))
			if id != "":
				catalog[id] = (e as Dictionary).duplicate(true)
	_ensure_progress()
	_loaded = true

func reload() -> void:
	_load()

func _ensure_progress() -> void:
	for id in catalog.keys():
		if not progress.has(id):
			progress[id] = {"started": false, "chapter": 0, "completed": false, "failed": false, "history": []}

func story_ids() -> Array:
	return catalog.keys()

func get_story(id: String) -> Dictionary:
	return catalog.get(id, {})

func get_chapters(id: String) -> Array:
	var s: Dictionary = get_story(id)
	var c: Variant = s.get("chapters", [])
	if c is Array:
		return c as Array
	return []

func chapter_count(id: String) -> int:
	return get_chapters(id).size()

func get_current_chapter(id: String) -> Dictionary:
	var p: Dictionary = progress.get(id, {})
	var cidx: int = int(p.get("chapter", 0))
	var chs: Array = get_chapters(id)
	if chs.is_empty() or cidx < 0 or cidx >= chs.size():
		return {}
	return chs[cidx] as Dictionary

func get_progress(id: String) -> Dictionary:
	return progress.get(id, {"started": false, "chapter": 0, "completed": false})

func is_started(id: String) -> bool:
	return bool(progress.get(id, {}).get("started", false))

func is_completed(id: String) -> bool:
	return bool(progress.get(id, {}).get("completed", false))

func start_story(id: String) -> bool:
	if not catalog.has(id):
		return false
	var p: Dictionary = progress.get(id, {})
	if bool(p.get("completed", false)):
		return false
	if bool(p.get("started", false)):
		return false
	p["started"] = true
	p["chapter"] = 0
	p["history"] = []
	progress[id] = p
	story_started.emit(id)
	return true

func advance(id: String, choice_id: String = "") -> bool:
	if not catalog.has(id):
		return false
	var p: Dictionary = progress.get(id, {})
	if not bool(p.get("started", false)) or bool(p.get("completed", false)):
		return false
	var ch: Dictionary = get_current_chapter(id)
	if ch.is_empty():
		return false
	var hist: Array = p.get("history", [])
	hist.append({"chapter": ch.get("id", ""), "choice": choice_id, "turn": _turn()})
	p["history"] = hist
	var next: int = int(p.get("chapter", 0)) + 1
	if next >= chapter_count(id):
		p["completed"] = true
		p["chapter"] = next
		progress[id] = p
		story_completed.emit(id)
		_push_chronicle(id, ch, choice_id, true)
	else:
		p["chapter"] = next
		progress[id] = p
		chapter_advanced.emit(id, next)
		_push_chronicle(id, ch, choice_id, false)
	return true

func fail_story(id: String) -> bool:
	if not catalog.has(id):
		return false
	var p: Dictionary = progress.get(id, {})
	if bool(p.get("completed", false)):
		return false
	p["failed"] = true
	p["started"] = false
	progress[id] = p
	story_failed.emit(id)
	return true

func reset_story(id: String) -> void:
	if not catalog.has(id):
		return
	progress[id] = {"started": false, "chapter": 0, "completed": false, "failed": false, "history": []}

func _turn() -> int:
	if has_node("/root/Game"):
		return int(get_node("/root/Game").get("turn"))
	return 0

func _push_chronicle(story_id: String, chapter: Dictionary, choice_id: String, done: bool) -> void:
	if not has_node("/root/Game"):
		return
	var g: Node = get_node("/root/Game")
	var txt: String = "[SideStory %s] %s — %s (choice:%s)%s" % [story_id, String(chapter.get("title", "")), String(chapter.get("synopsis", "")), choice_id, " [COMPLETE]" if done else ""]
	var ev := {"id": g.events.size() if "events" in g else 0, "turn": _turn(), "type": "side_story", "story_id": story_id, "chapter": String(chapter.get("id", "")), "text": txt}
	if "events" in g and g.events is Array:
		g.events.push_front(ev)
	if g.has_signal("event_occurred"):
		g.event_occurred.emit(ev)

func serialize() -> Dictionary:
	return {"progress": progress.duplicate(true)}

func restore(data: Dictionary) -> void:
	var p: Variant = data.get("progress", {})
	if p is Dictionary:
		progress.clear()
		for k in (p as Dictionary).keys():
			progress[str(k)] = (p as Dictionary)[k]
		_ensure_progress()

func stories_by_era(era: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in catalog.keys():
		var s: Dictionary = catalog[k]
		var eh: String = str(s.get("era_hint", "any"))
		if eh == "any" or eh == era:
			out.append(s)
	return out
