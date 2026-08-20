extends CanvasLayer
var _panel: PanelContainer
var _text: Label
var _next_btn: Button
var _skip_btn: Button
var _progress: Label
var _step := 0
var _elapsed := 0.0
var _done := false
var _await_farm := false
var _await_advance := false
var _await_event := false
const MAX_SECONDS := 300.0
const STEPS: Array[Dictionary] = [
	{"title": "Welcome, Ruler", "hint": "Your village awaits. Advisor: tap 🎣 Farm then place it on plains — green ghost = can afford."},
	{"title": "Place a Farm", "hint": "Tap the field where ghost is green. Farms feed the realm — grain→flour→bread."},
	{"title": "Advance Time", "hint": "Great! Now press ► End Turn or ▶×1 to let a month pass. Watch seasons change."},
	{"title": "First Event", "hint": "The realm stirs… Resolve your first event by choosing an option when the banner appears."},
	{"title": "You’re Ready", "hint": "Basics mastered! Build mills & bakeries, research Tech, trade & rule. Hints fade now — good reign!"},
]

func _ready() -> void:
	layer = 85
	visible = false
	if FileAccess.file_exists("user://tutorial_done.flag"):
		return
	_build()
	visible = true
	_show_step(0)
	_connect_signals()
	set_process(true)

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -140.0
	margin.offset_bottom = -92.0
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	add_child(margin)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.08, 0.92)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = Color(0.9, 0.78, 0.35, 0.9)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	_panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 12)
	_progress.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	_progress.text = "Advisor 1/5"
	top.add_child(_progress)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_skip_btn = Button.new()
	_skip_btn.text = "Skip"
	_skip_btn.custom_minimum_size = Vector2(64, 32)
	_skip_btn.add_theme_font_size_override("font_size", 13)
	_skip_btn.pressed.connect(_finish)
	top.add_child(_skip_btn)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 15)
	_text.add_theme_color_override("font_color", Color(1, 1, 0.92))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(600, 0)
	v.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	_next_btn = Button.new()
	_next_btn.text = "Next →"
	_next_btn.custom_minimum_size = Vector2(110, 36)
	_next_btn.add_theme_font_size_override("font_size", 14)
	_next_btn.pressed.connect(_on_next)
	row.add_child(_next_btn)

func _connect_signals() -> void:
	if Game.has_signal("turned"):
		if not Game.turned.is_connected(_on_turned):
			Game.turned.connect(_on_turned)
	if Game.has_signal("event_occurred"):
		if not Game.event_occurred.is_connected(_on_event):
			Game.event_occurred.connect(_on_event)
	var bm: Node = get_parent().get_node_or_null("BuildingManager") if get_parent() != null else null
	if bm == null:
		bm = get_node_or_null("/root/Main/BuildingManager")
	if bm != null and bm.has_signal("place_failed"):
		pass
	call_deferred("_hook_building_signal")

func _hook_building_signal() -> void:
	var bm: Node = get_parent().get_node_or_null("BuildingManager") if get_parent() != null else null
	if bm == null:
		bm = get_node_or_null("/root/Main/BuildingManager")
	if bm != null:
		if bm.has_signal("ghost_update"):
			pass
	await get_tree().process_frame
	var check: Node = get_node_or_null("/root/Main/BuildingManager")
	if check != null:
		pass
	Game.resources_changed.connect(_check_farm_placed)

func _check_farm_placed() -> void:
	if _step == 1 or _step == 0:
		for b in Game.placed_buildings:
			if str(b.get("id", "")) == "farm":
				if _step < 2:
					_show_step(2)
				return

func _show_step(idx: int) -> void:
	_step = clampi(idx, 0, STEPS.size() - 1)
	var s: Dictionary = STEPS[_step]
	_progress.text = "Advisor %d/%d — %s" % [_step + 1, STEPS.size(), str(s.get("title", ""))]
	_text.text = str(s.get("hint", ""))
	_next_btn.text = "Done" if _step == STEPS.size() - 1 else "Next →"
	visible = true

func _on_next() -> void:
	if _step == STEPS.size() - 1:
		_finish()
		return
	if _step == 0:
		_show_step(1)
	elif _step == 1:
		_show_step(2)
	elif _step == 2:
		_show_step(3)
	elif _step == 3:
		_show_step(4)

func _on_turned() -> void:
	if _step == 2:
		_show_step(3)

func _on_event(_ev: Dictionary) -> void:
	if _step == 3:
		_show_step(4)
		var t := get_tree().create_timer(4.0)
		t.timeout.connect(_finish)

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed >= MAX_SECONDS:
		_finish()
		return

func _finish() -> void:
	if _done:
		return
	_done = true
	visible = false
	var f := FileAccess.open("user://tutorial_done.flag", FileAccess.WRITE)
	if f != null:
		f.store_string(Time.get_datetime_string_from_system())
		f.close()
	set_process(false)

func reset_tutorial() -> void:
	_done = false
	_step = 0
	_elapsed = 0.0
	if FileAccess.file_exists("user://tutorial_done.flag"):
		DirAccess.remove_absolute("user://tutorial_done.flag")
	_show_step(0)
	visible = true
	set_process(true)
