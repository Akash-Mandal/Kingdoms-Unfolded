extends Node
const VAULT_PATH := "user://settings/narrative_vault.json"
var _cache: Dictionary = {}
var _loaded := false
func _ready() -> void:
	_load()
func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(VAULT_PATH):
		_cache = {}
		return
	var f := FileAccess.open(VAULT_PATH, FileAccess.READ)
	if f == null:
		_cache = {}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_cache = parsed as Dictionary
func _save() -> void:
	DirAccess.make_dir_recursive_absolute(VAULT_PATH.get_base_dir())
	var f := FileAccess.open(VAULT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_cache))
	f.close()
func _device_salt() -> String:
	var uid := OS.get_unique_id()
	if uid == "":
		uid = "kingdom-eternal-salt-v1"
	return uid
func _xor_cipher(text: String, salt: String) -> String:
	var out := PackedByteArray()
	var tbytes := text.to_utf8_buffer()
	var sbytes := salt.to_utf8_buffer()
	var slen := sbytes.size()
	if slen == 0:
		return text
	for i in tbytes.size():
		out.append(tbytes[i] ^ sbytes[i % slen])
	return Marshalls.raw_to_base64(out)
func _xor_decipher(b64: String, salt: String) -> String:
	var raw := Marshalls.base64_to_raw(b64)
	if raw.is_empty() and b64 != "":
		return ""
	var sbytes := salt.to_utf8_buffer()
	var slen := sbytes.size()
	var out := PackedByteArray()
	for i in raw.size():
		out.append(raw[i] ^ sbytes[i % slen])
	return out.get_string_from_utf8()
func store(provider: String, key: String) -> void:
	_load()
	_cache[provider] = _xor_cipher(key, _device_salt())
	_save()
func load_key(provider: String) -> String:
	_load()
	var enc: Variant = _cache.get(provider, "")
	if typeof(enc) != TYPE_STRING or (enc as String) == "":
		return ""
	return _xor_decipher(enc as String, _device_salt())
func has_key(provider: String) -> bool:
	return load_key(provider) != ""
func clear(provider: String) -> void:
	_load()
	_cache.erase(provider)
	_save()
func clear_all() -> void:
	_cache.clear()
	_save()
func store_config(provider: String, model: String, temperature: float, base_url: String) -> void:
	_load()
	var cfg: Dictionary = _cache.get("_cfg_" + provider, {}) as Dictionary if _cache.has("_cfg_" + provider) else {}
	cfg["model"] = model
	cfg["temperature"] = temperature
	cfg["base_url"] = base_url
	_cache["_cfg_" + provider] = cfg
	_save()
func load_config(provider: String) -> Dictionary:
	_load()
	var v: Variant = _cache.get("_cfg_" + provider, {})
	if typeof(v) == TYPE_DICTIONARY:
		return v as Dictionary
	return {}
