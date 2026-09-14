extends Node
# Local-only analytics, opt-in off by default. No network.
var enabled := false
const PATH := "user://settings/analytics.json"
var _events: Array[Dictionary] = []

func _ready() -> void:
	_load()

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var p: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(p) == TYPE_DICTIONARY:
		enabled = bool((p as Dictionary).get("enabled", false))

func set_enabled(v: bool) -> void:
	enabled = v
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"enabled": enabled}))
		f.close()

func track(name: String, props: Dictionary = {}) -> void:
	if not enabled:
		return
	_events.append({"t": Time.get_ticks_msec(), "name": name, "props": props})
	if _events.size() > 200:
		_events.pop_front()

func flush_to_file() -> void:
	if not enabled or _events.is_empty():
		return
	DirAccess.make_dir_recursive_absolute("user://logs")
	var f: FileAccess = null
	if FileAccess.file_exists("user://logs/analytics.jsonl"):
		f = FileAccess.open("user://logs/analytics.jsonl", FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open("user://logs/analytics.jsonl", FileAccess.WRITE)
	if f == null:
		return
	for e in _events:
		f.store_string(JSON.stringify(e) + "\n")
	f.close()
	_events.clear()
