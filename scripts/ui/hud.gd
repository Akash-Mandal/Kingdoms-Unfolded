extends CanvasLayer
## HUD — Phase 1. Resource bar + time/season/pop, building picker, speed controls,
## event banner, and month-end summary card.

var _res_labels := {}
var _chain_labels := {}
var _turn_label: Label
var _time_label: Label
var _season_label: Label
var _pop_label: Label
var _event_label: Label
var _month_card: PanelContainer
var _month_text: Label
var _speed_btns: Array[Button] = []
var _build_mgr: Node3D

var _event_timer: SceneTreeTimer
var _month_timer: SceneTreeTimer

func _ready() -> void:
	_build_mgr = get_parent().get_node_or_null("BuildingManager")
	if has_meta("build_mgr"):
		_build_mgr = get_meta("build_mgr")
	_build_hud()
	Game.turned.connect(_on_turned)
	Game.resources_changed.connect(_on_resources_changed)
	Game.population_changed.connect(_on_pop_changed)
	Game.event_occurred.connect(_on_event)
	TimeClock.hour_changed.connect(_on_hour)
	TimeClock.speed_changed.connect(_on_speed)
	TimeClock.month_ended.connect(_on_month_ended)
	_update_all()

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := VBoxContainer.new()
	top.anchor_left = 0.0
	top.anchor_right = 1.0
	top.offset_left = 10.0
	top.offset_right = -10.0
	top.offset_top = 10.0
	root.add_child(top)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	top.add_child(row1)
	_turn_label = _make_label("Year 0 · Month 1", 24)
	row1.add_child(_turn_label)
	_time_label = _make_label("06:00", 22)
	row1.add_child(_time_label)
	_season_label = _make_label("spring · clear", 22)
	row1.add_child(_season_label)
	_pop_label = _make_label("👥 50", 22)
	row1.add_child(_pop_label)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	top.add_child(row2)
	for key in Game.RESOURCE_KEYS:
		var chip: Label = _make_resource_chip(key)
		row2.add_child(chip)
	for key in Game.CHAIN_KEYS:
		var chip: Label = _make_label("", 20)
		chip.tooltip_text = key.capitalize()
		chip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
		_chain_labels[key] = chip
		row2.add_child(chip)

	var bottom := Control.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_bottom = -10.0
	bottom.offset_left = 10.0
	bottom.offset_right = -10.0
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(bottom)

	var bottom_h := HBoxContainer.new()
	bottom_h.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	bottom.add_child(bottom_h)

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	bottom_h.add_child(left)
	for id in ["house", "farm", "mill", "bakery"]:
		var def: Dictionary = Catalog.get_building(id) if Catalog != null else {}
		var btn := Button.new()
		var icon: String = String(def.get("icon", id))
		btn.text = "%s %s" % [icon, String(def.get("name", id))]
		btn.add_theme_font_size_override("font_size", 18)
		var bid: String = id
		btn.pressed.connect(func() -> void: _select_building(bid))
		left.add_child(btn)
	var clear_btn := Button.new()
	clear_btn.text = "✕"
	clear_btn.add_theme_font_size_override("font_size", 18)
	clear_btn.pressed.connect(func() -> void: _select_building(""))
	left.add_child(clear_btn)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_END
	bottom_h.add_child(right)
	for s in [0, 1, 4, 12]:
		var label: String = "⏸" if s == 0 else "×%d" % s
		var btn := Button.new()
		btn.text = label
		btn.add_theme_font_size_override("font_size", 20)
		var sv: int = s
		btn.pressed.connect(func() -> void: TimeClock.set_speed(sv))
		_speed_btns.append(btn)
		right.add_child(btn)
	var next_btn := Button.new()
	next_btn.text = "► End Turn"
	next_btn.add_theme_font_size_override("font_size", 22)
	next_btn.pressed.connect(func() -> void: TimeClock.end_turn_now())
	right.add_child(next_btn)

	_event_label = _make_label("", 22)
	_event_label.anchor_left = 0.5
	_event_label.anchor_right = 0.5
	_event_label.anchor_top = 0.82
	_event_label.offset_left = -420.0
	_event_label.offset_right = 420.0
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.modulate.a = 0.0
	root.add_child(_event_label)

	_month_card = PanelContainer.new()
	_month_card.anchor_left = 0.5
	_month_card.anchor_right = 0.5
	_month_card.anchor_top = 0.5
	_month_card.offset_left = -220.0
	_month_card.offset_right = 220.0
	_month_card.offset_top = -60.0
	_month_card.offset_bottom = 60.0
	_month_card.visible = false
	root.add_child(_month_card)
	_month_text = _make_label("", 22)
	_month_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_month_card.add_child(_month_text)

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
	var l := _make_label("", 22)
	l.tooltip_text = key.capitalize()
	_res_labels[key] = l
	return l

func _select_building(id: String) -> void:
	if _build_mgr != null:
		_build_mgr.selected_id = id

func _on_turned() -> void:
	_turn_label.text = "Year %d · Month %d" % [Game.year, Game.month]
	_on_pop_changed()
	_show_month_card()

func _on_resources_changed() -> void:
	for key in Game.RESOURCE_KEYS:
		var lab: Label = _res_labels[key]
		var stock: float = Game.get_stock(key)
		var icon: String = String({
			"food": "🌾", "gold": "💰", "wood": "🪵", "stone": "🪨",
			"iron": "⚙️", "cloth": "🧶", "horses": "🐎", "knowledge": "📜",
		}.get(key, key))
		lab.text = "%s %d" % [icon, int(stock)]
	for key in Game.CHAIN_KEYS:
		var lab: Label = _chain_labels[key]
		lab.text = "%s %d" % [key.capitalize(), int(Game.get_stock(key))] if Game.get_stock(key) > 0.5 else ""

func _on_pop_changed() -> void:
	_pop_label.text = "👥 %d/%d ♥%.0f%%" % [int(Game.pop_count), int(Game.pop_capacity_base + Game.building_cap.get("housing", 0.0)), Game.pop_happiness * 100.0]

func _on_event(event: Dictionary) -> void:
	_event_label.text = String(event.get("text", ""))
	_event_label.modulate.a = 1.0
	_event_timer = get_tree().create_timer(5.0)
	_event_timer.timeout.connect(func() -> void: _event_label.modulate.a = 0.0)

func _on_hour(hour: float) -> void:
	_time_label.text = TimeClock.time_of_day()
	var s: String = Game.season()
	var w: String = "clear"
	var weather: Node = get_parent().get_node_or_null("Weather")
	if weather != null and "state" in weather:
		w = String(weather.state)
	_season_label.text = "%s · %s" % [s, w]

func _on_speed(_s: int) -> void:
	for btn in _speed_btns:
		btn.modulate = Color(1, 1, 1, 0.5)
	var idx: int = [0, 1, 4, 12].find(TimeClock.speed)
	if idx >= 0 and idx < _speed_btns.size():
		_speed_btns[idx].modulate = Color(1, 1, 1, 1)

func _on_month_ended() -> void:
	_show_month_card()

func _show_month_card() -> void:
	_month_text.text = "Month %d — Year %d\nPop %d  Food %d  Season: %s" % [
		Game.month, Game.year, int(Game.pop_count), int(Game.get_stock("food")), Game.season()
	]
	_month_card.visible = true
	_month_timer = get_tree().create_timer(2.2)
	_month_timer.timeout.connect(func() -> void: _month_card.visible = false)

func _update_all() -> void:
	_on_turned()
	_on_resources_changed()
	_on_pop_changed()
	_on_hour(TimeClock.sim_hour)
	_on_speed(TimeClock.speed)
