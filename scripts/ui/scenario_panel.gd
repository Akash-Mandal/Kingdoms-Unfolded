extends CanvasLayer
var _list: VBoxContainer
var _detail: Label
var _custom_input: LineEdit
var _header: Label
var _visible_flag := false
var _panel: PanelContainer
var _toggle_btn: Button
var _selected_id: String = ""

func _ready() -> void:
	layer = 16
	_build_ui()
	_refresh()
	if has_node("/root/Scenarios"):
		var s: Node = get_node("/root/Scenarios")
		if s.has_signal("scenario_changed"):
			s.scenario_changed.connect(func(_id: String) -> void: _refresh())
	if has_node("/root/Game"):
		var g: Node = get_node("/root/Game")
		if g.has_signal("turned"):
			g.turned.connect(_refresh)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_toggle_btn = Button.new()
	_toggle_btn.text = "🌍 Scenarios"
	_toggle_btn.custom_minimum_size = Vector2(150, 40)
	_toggle_btn.anchor_left = 1.0
	_toggle_btn.anchor_top = 0.0
	_toggle_btn.anchor_right = 1.0
	_toggle_btn.anchor_bottom = 0.0
	_toggle_btn.offset_left = -168.0
	_toggle_btn.offset_top = 54.0
	_toggle_btn.offset_right = -12.0
	_toggle_btn.offset_bottom = 94.0
	_toggle_btn.add_theme_font_size_override("font_size", 15)
	_toggle_btn.pressed.connect(_toggle)
	root.add_child(_toggle_btn)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -380.0
	_panel.offset_right = 380.0
	_panel.offset_top = -320.0
	_panel.offset_bottom = 320.0
	_panel.visible = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	ps.corner_radius_top_left = 10
	ps.corner_radius_top_right = 10
	ps.corner_radius_bottom_left = 10
	ps.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", ps)
	root.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	_header = Label.new()
	_header.text = "Scenarios & Timeline"
	_header.add_theme_font_size_override("font_size", 20)
	_header.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_header)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_toggle)
	title_row.add_child(close_btn)
	vbox.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 340)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	sc.add_child(_list)
	_detail = Label.new()
	_detail.text = "Select a scenario."
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_detail)
	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 6)
	vbox.add_child(custom_row)
	_custom_input = LineEdit.new()
	_custom_input.placeholder_text = "Custom prompt e.g., comet cult, salt famine…"
	_custom_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_input.custom_minimum_size = Vector2(0, 36)
	custom_row.add_child(_custom_input)
	var gen_btn := Button.new()
	gen_btn.text = "✨ Generate Custom"
	gen_btn.custom_minimum_size = Vector2(160, 36)
	gen_btn.add_theme_font_size_override("font_size", 13)
	gen_btn.pressed.connect(_on_generate_custom)
	custom_row.add_child(gen_btn)
	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 6)
	vbox.add_child(bot_row)
	var apply_btn := Button.new()
	apply_btn.text = "Apply Scenario"
	apply_btn.custom_minimum_size = Vector2(180, 40)
	apply_btn.add_theme_font_size_override("font_size", 14)
	var abg := StyleBoxFlat.new()
	abg.bg_color = Color(0.2, 0.55, 0.28)
	abg.corner_radius_top_left = 6
	abg.corner_radius_top_right = 6
	abg.corner_radius_bottom_left = 6
	abg.corner_radius_bottom_right = 6
	apply_btn.add_theme_stylebox_override("normal", abg)
	apply_btn.pressed.connect(_on_apply)
	bot_row.add_child(apply_btn)
	var note_btn := Button.new()
	note_btn.text = "📝 Annotate Timeline"
	note_btn.custom_minimum_size = Vector2(180, 40)
	note_btn.add_theme_font_size_override("font_size", 14)
	note_btn.pressed.connect(_on_annotate)
	bot_row.add_child(note_btn)

func _toggle() -> void:
	_visible_flag = not _visible_flag
	_panel.visible = _visible_flag
	if _visible_flag:
		_refresh()

func open() -> void:
	_visible_flag = true
	_panel.visible = true
	_refresh()

func close() -> void:
	_visible_flag = false
	_panel.visible = false

func _refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var scn: Variant = get_node_or_null("/root/Scenarios")
	var cat: Variant = get_node_or_null("/root/Catalog")
	if scn == null:
		var lbl := Label.new()
		lbl.text = "Scenarios not initialised. Add Scenarios autoload."
		_list.add_child(lbl)
		return
	var ids: Array = scn.scenario_ids() if scn.has_method("scenario_ids") else []
	if ids.is_empty() and cat != null and cat.has_method("scenario_ids"):
		ids = cat.scenario_ids()
	if ids.is_empty():
		var lbl2 := Label.new()
		lbl2.text = "No scenarios found. Check data/catalog/scenarios.json"
		_list.add_child(lbl2)
		return
	var active: String = scn.get("active_id") if "active_id" in scn else ""
	_header.text = "Scenarios & Timeline — Active: %s" % (active if active != "" else "none")
	for sid in ids:
		var entry: Dictionary = scn.get_scenario(str(sid)) if scn.has_method("get_scenario") else {}
		if entry.is_empty() and cat != null and cat.has_method("get_scenario"):
			entry = cat.get_scenario(str(sid))
		var row := Button.new()
		row.text = "%s %s — %s" % [String(entry.get("icon", "—")), String(entry.get("name", sid)), String(entry.get("timeline_label", ""))]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 38)
		row.add_theme_font_size_override("font_size", 14)
		if str(sid) == active:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.22, 0.4, 0.22)
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			row.add_theme_stylebox_override("normal", sb)
		var csid: String = str(sid)
		row.pressed.connect(func() -> void: _select(csid))
		_list.add_child(row)
	if _selected_id != "":
		_show_detail(_selected_id)
	elif active != "":
		_show_detail(active)

func _select(id: String) -> void:
	_selected_id = id
	_show_detail(id)
	_refresh()

func _show_detail(id: String) -> void:
	var scn: Variant = get_node_or_null("/root/Scenarios")
	if scn == null or not scn.has_method("get_scenario"):
		return
	var e: Dictionary = scn.get_scenario(id)
	if e.is_empty():
		_detail.text = "No detail for %s" % id
		return
	var txt: String = "%s %s\n%s\n\nVictory: %s\nDefeat: %s\nDuration: %s turns · Difficulty: %s\nRules: %s" % [
		String(e.get("icon", "")), String(e.get("name", id)), String(e.get("description", "")),
		String(e.get("victory", "—")), String(e.get("defeat", "—")),
		String(e.get("duration_turns", "—")), String(e.get("difficulty", "—")),
		", ".join(e.get("special_rules", []))
	]
	_detail.text = txt

func _on_apply() -> void:
	var id: String = _selected_id
	if id == "":
		var scn2: Variant = get_node_or_null("/root/Scenarios")
		if scn2 != null and "active_id" in scn2:
			id = str(scn2.get("active_id"))
	if id == "":
		return
	var scn: Variant = get_node_or_null("/root/Scenarios")
	if scn != null and scn.has_method("apply_scenario"):
		scn.apply_scenario(id, true)
		_refresh()

func _on_generate_custom() -> void:
	var prompt: String = _custom_input.text.strip_edges()
	if prompt == "":
		_detail.text = "Enter a custom prompt first."
		return
	var scn: Variant = get_node_or_null("/root/Scenarios")
	if scn != null and scn.has_method("generate_custom"):
		var gen: Dictionary = scn.generate_custom(prompt)
		_selected_id = str(gen.get("id", "custom_generated"))
		_show_detail(_selected_id)
		_refresh()

func _on_annotate() -> void:
	var scn: Variant = get_node_or_null("/root/Scenarios")
	if scn == null or not scn.has_method("annotate_timeline"):
		return
	var turn: int = 0
	if has_node("/root/Game") and "turn" in get_node("/root/Game"):
		turn = int(get_node("/root/Game").turn)
	var note: String = _custom_input.text.strip_edges()
	if note == "":
		note = "Player note at turn %d" % turn
	scn.annotate_timeline(turn, note)
	_detail.text = "Annotated T%d: %s" % [turn, note]
