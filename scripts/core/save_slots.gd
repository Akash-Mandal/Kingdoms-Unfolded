extends Node
const MAX_SLOTS := 5
const AUTOSAVE_INTERVAL := 5
const SAVE_DIR := "user://saves"
const EXPORT_DIR := "user://exports"
signal slot_saved(idx: int, path: String)
signal slot_loaded(idx: int, path: String)
signal autosaved(path: String)
signal exported(path: String)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(EXPORT_DIR)
	var g: Node = get_node_or_null("/root/Game")
	if g != null and g.has_signal("turned"):
		if not g.turned.is_connected(_on_turned):
			g.turned.connect(_on_turned)

func slot_path(idx: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(idx, 0, MAX_SLOTS - 1)]

func autosave_path() -> String:
	return "%s/autosave.json" % SAVE_DIR

func slot_name_path(idx: int) -> String:
	return "%s/slot_%d.name" % [SAVE_DIR, clampi(idx, 0, MAX_SLOTS - 1)]

func save_slot(idx: int, custom_name: String = "") -> bool:
	var i := clampi(idx, 0, MAX_SLOTS - 1)
	var path := slot_path(i)
	if custom_name != "":
		var nf := FileAccess.open(slot_name_path(i), FileAccess.WRITE)
		if nf != null:
			nf.store_string(custom_name)
			nf.close()
	var ok: bool = Game.save_to_file(path)
	if ok:
		slot_saved.emit(i, path)
	return ok

func load_slot(idx: int) -> bool:
	var i := clampi(idx, 0, MAX_SLOTS - 1)
	var path := slot_path(i)
	if not FileAccess.file_exists(path):
		return false
	var ok: bool = Game.load_from_file(path)
	if ok:
		slot_loaded.emit(i, path)
	return ok

func slot_exists(idx: int) -> bool:
	return FileAccess.file_exists(slot_path(clampi(idx, 0, MAX_SLOTS - 1)))

func slot_info(idx: int) -> Dictionary:
	var i := clampi(idx, 0, MAX_SLOTS - 1)
	var path := slot_path(i)
	if not FileAccess.file_exists(path):
		return {"exists": false, "idx": i}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"exists": false, "idx": i}
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		# Recovery: try .bak written by atomic save.
		if FileAccess.file_exists(path + ".bak"):
			var b := FileAccess.open(path + ".bak", FileAccess.READ)
			if b != null:
				var bp: Variant = JSON.parse_string(b.get_as_text())
				b.close()
				if typeof(bp) == TYPE_DICTIONARY:
					parsed = bp
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": false, "idx": i, "corrupt": true}
	var d: Dictionary = parsed as Dictionary
	var meta: Dictionary = d.get("meta", {})
	var settings: Dictionary = d.get("settings", {})
	var name := ""
	if FileAccess.file_exists(slot_name_path(i)):
		var nf := FileAccess.open(slot_name_path(i), FileAccess.READ)
		if nf != null:
			name = nf.get_as_text().strip_edges()
			nf.close()
	if name == "":
		name = str(meta.get("kingdomName", settings.get("kingdom_name", "Slot %d" % (i + 1))))
	return {"exists": true, "idx": i, "path": path, "meta": meta, "settings": settings, "display_name": name, "turn": int(meta.get("turnCount", 0)), "date": str(meta.get("saveDate", ""))}

func all_slots_info() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in MAX_SLOTS:
		out.append(slot_info(i))
	return out

func delete_slot(idx: int) -> void:
	var i := clampi(idx, 0, MAX_SLOTS - 1)
	var p := slot_path(i)
	var n := slot_name_path(i)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	if FileAccess.file_exists(n):
		DirAccess.remove_absolute(n)

func autosave_check() -> void:
	if Game.turn <= 0:
		return
	if Game.turn % AUTOSAVE_INTERVAL == 0:
		_autosave()

func _on_turned() -> void:
	autosave_check()

func _autosave() -> void:
	var ok: bool = Game.save_to_file(autosave_path())
	if ok:
		autosaved.emit(autosave_path())

func export_kingdom(idx: int, out_path: String = "") -> String:
	var i := clampi(idx, 0, MAX_SLOTS - 1)
	var src := slot_path(i)
	if not FileAccess.file_exists(src):
		src = autosave_path()
		if not FileAccess.file_exists(src):
			return ""
	var dest := out_path
	if dest == "":
		var info: Dictionary = slot_info(i)
		var safe: String = str(info.get("display_name", "kingdom")).to_lower().replace(" ", "_")
		dest = "%s/%s_turn%d.kingdom" % [EXPORT_DIR, safe, Game.turn]
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		return ""
	var txt := f.get_as_text()
	f.close()
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var o := FileAccess.open(dest, FileAccess.WRITE)
	if o == null:
		return ""
	o.store_string(txt)
	o.close()
	exported.emit(dest)
	return dest

func import_kingdom(kingdom_path: String, target_idx: int) -> bool:
	if not FileAccess.file_exists(kingdom_path):
		return false
	var f := FileAccess.open(kingdom_path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var i := clampi(target_idx, 0, MAX_SLOTS - 1)
	var dest := slot_path(i)
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var o := FileAccess.open(dest, FileAccess.WRITE)
	if o == null:
		return false
	o.store_string(JSON.stringify(parsed, "\t"))
	o.close()
	return true

func quick_save() -> bool:
	return save_slot(0, "")

func quick_load() -> bool:
	# Prefer newest of slot_0 vs autosave (was: always slot_0).
	var s0 := slot_path(0)
	var auto := autosave_path()
	var s0t: int = int(FileAccess.get_modified_time(s0)) if FileAccess.file_exists(s0) else -1
	var autot: int = int(FileAccess.get_modified_time(auto)) if FileAccess.file_exists(auto) else -1
	if s0t < 0 and autot < 0:
		return false
	if autot > s0t:
		return Game.load_from_file(auto)
	return load_slot(0)
