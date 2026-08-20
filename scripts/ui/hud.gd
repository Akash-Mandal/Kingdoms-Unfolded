extends CanvasLayer
## HUD — Phase 0 overlay. Resource bar, turn counter, event banner,
## Next Turn button. Built entirely in code (no .tscn dependency).

var _res_labels := {}
var _turn_label: Label
var _event_label: Label
var _event_timer: SceneTreeTimer

func _ready() -> void:
	build_hud()
	Game.turned.connect(_on_turned)
	Game.resources_changed.connect(_on_resources_changed)
	Game.event_occurred.connect(_on_event_occurred)
	_update_all()

func build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 12.0
	top_bar.offset_right = -12.0
	top_bar.offset_top = 12.0
	top_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

	_turn_label = _make_label("Year 0 · Month 1", 28)
	top_bar.add_child(_turn_label)

	for key in Game.RESOURCE_KEYS:
		var chip := _make_resource_chip(key)
		top_bar.add_child(chip)

	var bottom := HBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 12.0
	bottom.offset_right = -12.0
	bottom.offset_bottom = -12.0
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	var next_btn := Button.new()
	next_btn.text = "► Next Turn"
	next_btn.add_theme_font_size_override("font_size", 26)
	next_btn.pressed.connect(Game.advance)
	bottom.add_child(next_btn)

	var speed_label := _make_label("×1", 24)
	bottom.add_child(speed_label)

	_event_label = _make_label("", 22)
	_event_label.anchor_left = 0.5
	_event_label.anchor_right = 0.5
	_event_label.anchor_top = 0.85
	_event_label.offset_left = -400.0
	_event_label.offset_right = 400.0
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.modulate.a = 0.0
	root.add_child(_event_label)

func _make_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_resource_chip(key: String) -> Label:
	var l := _make_label("", 26)
	l.tooltip_text = key.capitalize()
	_res_labels[key] = l
	return l

func _on_turned() -> void:
	_turn_label.text = "Year %d · Month %d" % [Game.year, Game.month]

func _on_resources_changed() -> void:
	for key in Game.RESOURCE_KEYS:
		var l: Label = _res_labels[key]
		var stock := Game.get_stock(key)
		var icon := {
			"food": "🌾", "gold": "💰", "wood": "🪵", "stone": "🪨",
			"iron": "⚙️", "cloth": "🧶", "horses": "🐎", "knowledge": "📜",
		}.get(key, key)
		l.text = "%s %d" % [icon, int(stock)]

func _on_event_occurred(event: Dictionary) -> void:
	_event_label.text = event.get("text", "")
	_event_label.modulate.a = 1.0
	_event_timer = get_tree().create_timer(5.0)
	_event_timer.timeout.connect(func() -> void:
		_event_label.modulate.a = 0.0
	)

func _update_all() -> void:
	_on_turned()
	_on_resources_changed()