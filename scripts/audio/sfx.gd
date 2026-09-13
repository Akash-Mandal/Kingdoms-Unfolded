extends Node
const SFX_DIR := "res://assets/audio/sfx/"
const SETTINGS_PATH := "user://settings/audio.json"
const POOL_SIZE := 8
var music_db := -6.0
var sfx_db := 0.0
var muted := false
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _idx := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_load_settings()

func play(sfx_name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if muted:
		return
	if _pool.is_empty():
		return
	var s := _stream(sfx_name)
	if s == null:
		return
	var p := _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	if p.playing:
		p.stop()
	p.stream = s
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = sfx_db + vol_db
	p.play()

func click() -> void:
	play("ui_click")

func _stream(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name] as AudioStream
	var path := SFX_DIR + sfx_name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s != null:
		_cache[sfx_name] = s
	return s

func set_volumes(p_music_db: float, p_sfx_db: float, p_muted: bool) -> void:
	music_db = p_music_db
	sfx_db = p_sfx_db
	muted = p_muted
	_save_settings()
	var m: Node = get_node_or_null("/root/Music")
	if m != null and m.has_method("apply_volumes"):
		m.call("apply_volumes")

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		music_db = float((parsed as Dictionary).get("music_db", music_db))
		sfx_db = float((parsed as Dictionary).get("sfx_db", sfx_db))
		muted = bool((parsed as Dictionary).get("muted", muted))

func _save_settings() -> void:
	var dir := SETTINGS_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"music_db": music_db, "sfx_db": sfx_db, "muted": muted}))
	f.close()
