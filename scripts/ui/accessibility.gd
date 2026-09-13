extends CanvasLayer
var _panel: PanelContainer
var _scale_opt: OptionButton
var _slow_check: CheckBox
var _haptics_check: CheckBox
const SCALE_KEYS: PackedStringArray = ["small", "normal", "large", "xlarge"]
const SCALE_LABELS: PackedStringArray = ["×0.8 Small", "×1.0 Normal", "×1.3 Large", "×1.6 X-Large"]

func _ready() -> void:
	layer = 20
	_build()
	visible = false

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_CENTER)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.10, 0.10, 0.13, 0.96), 10))
	margin.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var title := Label.new()
	title.text = "Accessibility"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var row1 := HBoxContainer.new()
	v.add_child(row1)
	var lab := Label.new()
	lab.text = "Text Scale"
	lab.custom_minimum_size = Vector2(120, 36)
	row1.add_child(lab)
	_scale_opt = OptionButton.new()
	_scale_opt.custom_minimum_size = Vector2(160, 36)
	for l in SCALE_LABELS:
		_scale_opt.add_item(l)
	row1.add_child(_scale_opt)
	_scale_opt.item_selected.connect(_on_scale)
	var slow_row := HBoxContainer.new()
	v.add_child(slow_row)
	_slow_check = CheckBox.new()
	_slow_check.text = "Slow-mode ×0.5 (Accessibility)"
	_slow_check.toggled.connect(_on_slow)
	slow_row.add_child(_slow_check)
	var hap_row := HBoxContainer.new()
	v.add_child(hap_row)
	_haptics_check = CheckBox.new()
	_haptics_check.text = "Haptics (vibrate on tap/event)"
	_haptics_check.button_pressed = true
	_haptics_check.toggled.connect(_on_haptics)
	hap_row.add_child(_haptics_check)
	var close := UITheme.make_button("Close", "danger", Vector2(120, 44))
	close.pressed.connect(func() -> void: visible = false)
	v.add_child(close)
	_sync()

func _sync() -> void:
	var ac: Node = get_node_or_null("/root/Main/Accessibility")
	if ac == null: ac = get_node_or_null("/root/Accessibility")
	if ac == null: return
	if "text_scale_key" in ac:
		_scale_opt.selected = SCALE_KEYS.find(str(ac.get("text_scale_key")))
	if "slow_mode" in ac:
		_slow_check.button_pressed = bool(ac.get("slow_mode"))
	if "haptics_enabled" in ac:
		_haptics_check.button_pressed = bool(ac.get("haptics_enabled"))

func _on_scale(idx: int) -> void:
	var key: String = SCALE_KEYS[idx]
	var ac: Node = get_node_or_null("/root/Main/Accessibility")
	if ac == null: ac = get_node_or_null("/root/Accessibility")
	if ac != null and ac.has_method("set_text_scale"): ac.call("set_text_scale", key)

func _on_slow(pressed: bool) -> void:
	var ac: Node = get_node_or_null("/root/Main/Accessibility")
	if ac == null: ac = get_node_or_null("/root/Accessibility")
	if ac != null and ac.has_method("set_slow_mode"): ac.call("set_slow_mode", pressed)

func _on_haptics(pressed: bool) -> void:
	var ac: Node = get_node_or_null("/root/Main/Accessibility")
	if ac == null: ac = get_node_or_null("/root/Accessibility")
	if ac != null and ac.has_method("set_haptics"): ac.call("set_haptics", pressed)

func open() -> void:
	_sync()
	visible = true
