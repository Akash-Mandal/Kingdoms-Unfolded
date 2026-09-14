extends Node
signal text_scale_changed(scale: float)
signal slow_mode_changed(enabled: bool)
signal haptics_changed(enabled: bool)
const SAVE_PATH := "user://accessibility.json"
const SCALES: Dictionary = {"small": 0.8, "normal": 1.0, "large": 1.3, "xlarge": 1.6}
var text_scale_key := "normal"
var slow_mode := false
var haptics_enabled := true
var colorblind_mode := false

func _ready() -> void:
	_load()
	call_deferred("_apply_to_tree")

func get_scale_factor() -> float:
	return float(SCALES.get(text_scale_key, 1.0))

func set_text_scale(key: String) -> void:
	if not SCALES.has(key):
		return
	text_scale_key = key
	_save()
	text_scale_changed.emit(get_scale_factor())
	_apply_to_tree()

func cycle_text_scale() -> void:
	var order: PackedStringArray = ["small", "normal", "large", "xlarge"]
	var idx: int = order.find(text_scale_key)
	text_scale_key = order[(idx + 1) % order.size()]
	set_text_scale(text_scale_key)

func _apply_to_tree() -> void:
	var factor: float = get_scale_factor()
	var root: Window = get_tree().root if get_tree() != null else null
	if root == null:
		return
	_apply_scale_recursive(root, factor)

func _apply_scale_recursive(node: Node, factor: float) -> void:
	if node is Control:
		var c: Control = node as Control
		if c.has_theme_font_size_override("font_size"):
			if not c.has_meta("_acc_base_fs"):
				c.set_meta("_acc_base_fs", c.get_theme_font_size("font_size"))
			c.add_theme_font_size_override("font_size", int(float(c.get_meta("_acc_base_fs")) * factor))
	for ch in node.get_children():
		_apply_scale_recursive(ch, factor)

func set_slow_mode(enabled: bool) -> void:
	slow_mode = enabled
	var tc: Node = get_node_or_null("/root/TimeClock")
	if tc != null and tc.has_method("set_slow_mode"):
		tc.call("set_slow_mode", enabled)
	slow_mode_changed.emit(enabled)
	_save()

func set_haptics(enabled: bool) -> void:
	haptics_enabled = enabled
	haptics_changed.emit(enabled)
	_save()

func vibrate(duration_ms: int = 40, pattern: String = "tap") -> void:
	if not haptics_enabled:
		return
	var dur: int = duration_ms
	if pattern == "heavy": dur = 80
	elif pattern == "danger": dur = 120
	elif pattern == "success": dur = 30
	if OS.has_method("vibrate_handheld"):
		OS.vibrate_handheld(dur)
	elif Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(dur)

func haptic_for_event(kind: String) -> void:
	match kind:
		"tap": vibrate(30, "tap")
		"place": vibrate(40, "success")
		"danger": vibrate(120, "danger")
		"turn": vibrate(50, "heavy")
		_: vibrate(30, "tap")

func set_colorblind(enabled: bool) -> void:
	colorblind_mode = enabled
	_save()

func is_colorblind() -> bool:
	return colorblind_mode

func _save() -> void:
	var d: Dictionary = {"text_scale": text_scale_key, "slow_mode": slow_mode, "haptics": haptics_enabled, "colorblind": colorblind_mode}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed as Dictionary
	text_scale_key = str(d.get("text_scale", text_scale_key))
	slow_mode = bool(d.get("slow_mode", false))
	haptics_enabled = bool(d.get("haptics", true))
	colorblind_mode = bool(d.get("colorblind", false))
	var tc: Node = get_node_or_null("/root/TimeClock")
	if tc != null and tc.has_method("set_slow_mode"):
		tc.call("set_slow_mode", slow_mode)
