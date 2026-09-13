extends CanvasLayer
var _res_labels := {}
var _chain_labels := {}
var _turn_label: Label
var _time_label: Label
var _season_label: Label
var _pop_label: Label
var _event_label: Label
var _toast_label: Label
var _month_card: PanelContainer
var _month_text: Label
var _speed_btns: Array[Button] = []
var _build_btns: Dictionary = {}
var _build_mgr: Node3D
var _selected_id: String = ""
var _radial: PanelContainer
var _tech_panel: PanelContainer
var _tech_vbox: VBoxContainer
var _research_label: Label
var _research_bar: ProgressBar
var _tech_btn: Button
var _acc_scale_btn: Button
var _acc_slow_btn: Button
var _dirty_resources := true
var _dirty_pop := true
var _dirty_time := true
var _dirty_build := true
var _dirty_tech := false
var _cached_stock := {}
var _cached_pop_text := ""
var _cached_time_text := ""
func _safe_insets() -> Dictionary:
	var t := 0
	var b := 0
	var l := 0
	var r := 0
	if OS.has_feature("mobile") or DisplayServer.get_name() == "Android":
		var sa := Rect2i()
		if DisplayServer.has_method("get_display_safe_area"):
			sa = DisplayServer.get_display_safe_area()
			var vp: Vector2i = DisplayServer.window_get_size()
			if sa.position.y > 0: t = sa.position.y
			if sa.size.y < vp.y: b = max(0, vp.y - (sa.position.y + sa.size.y))
			if sa.position.x > 0: l = sa.position.x
			if sa.size.x < vp.x: r = max(0, vp.x - (sa.position.x + sa.size.x))
		if t == 0 and b == 0:
			t = 24
			b = 18
	return {"top": t, "bottom": b, "left": l, "right": r}
func _haptic(kind: String) -> void:
	if OS.has_feature("mobile"):
		var ms := 30
		match kind:
			"place": ms = 40
			"danger": ms = 100
			"turn": ms = 60
			_: ms = 30
		if OS.has_method("vibrate_handheld"):
			OS.vibrate_handheld(ms)
		elif OS.has_method("vibrate"):
			OS.call("vibrate", ms)
	var ac: Node = get_node_or_null("/root/Main/Accessibility")
	if ac == null:
		ac = get_parent().get_node_or_null("Accessibility")
	if ac != null and ac.has_method("haptic_for_event"):
		ac.call("haptic_for_event", kind)
func _add_pressed_feedback(btn: Button) -> void:
	if not is_instance_valid(btn) or btn.has_meta("_press_fb"):
		return
	btn.set_meta("_press_fb", true)
	btn.button_down.connect(func() -> void:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.08)
		btn.modulate = Color(0.9, 0.9, 0.95)
	)
	btn.button_up.connect(func() -> void:
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw2.tween_property(btn, "scale", Vector2.ONE, 0.18)
		btn.modulate = Color(1, 1, 1)
	)
	btn.focus_entered.connect(func() -> void: btn.modulate = Color(1, 1, 0.95))
	btn.focus_exited.connect(func() -> void: btn.modulate = Color(1, 1, 1))

func _apply_text_scale() -> void:
	var ac: Node = get_node_or_null("/root/Main/Accessibility")
	if ac == null:
		ac = get_parent().get_node_or_null("Accessibility")
	var factor: float = 1.0
	if ac != null and ac.has_method("get_scale_factor"):
		factor = float(ac.call("get_scale_factor"))
	for lbl in _res_labels.values():
		if lbl is Label:
			(lbl as Label).add_theme_font_size_override("font_size", int(15 * factor))
	for lbl in _chain_labels.values():
		if lbl is Label:
			(lbl as Label).add_theme_font_size_override("font_size", int(14 * factor))
	if _turn_label != null:
		_turn_label.add_theme_font_size_override("font_size", int(18 * factor))
	if _pop_label != null:
		_pop_label.add_theme_font_size_override("font_size", int(16 * factor))

func _ready() -> void:
	_build_mgr = get_parent().get_node_or_null("BuildingManager")
	if has_meta("build_mgr"):
		var mb: Variant = get_meta("build_mgr")
		if mb is Node3D:
			_build_mgr = mb as Node3D
	if _build_mgr != null and _build_mgr.has_signal("place_failed") and not _build_mgr.place_failed.is_connected(_on_place_failed):
		_build_mgr.place_failed.connect(_on_place_failed)
	_build_hud()
	if not Game.turned.is_connected(_on_turned):
		Game.turned.connect(_on_turned)
	if not Game.resources_changed.is_connected(_on_resources_changed):
		Game.resources_changed.connect(_on_resources_changed)
	if not Game.population_changed.is_connected(_on_pop_changed):
		Game.population_changed.connect(_on_pop_changed)
	if not Game.event_occurred.is_connected(_on_event):
		Game.event_occurred.connect(_on_event)
	if not TimeClock.hour_changed.is_connected(_on_hour):
		TimeClock.hour_changed.connect(_on_hour)
	if not TimeClock.speed_changed.is_connected(_on_speed):
		TimeClock.speed_changed.connect(_on_speed)
	if not TimeClock.month_ended.is_connected(_on_month_ended):
		TimeClock.month_ended.connect(_on_month_ended)
	var np: Node = get_node_or_null("/root/NarrativeProvider")
	if np != null and np.has_signal("narrative_ready"):
		np.narrative_ready.connect(_on_narrative)
	var chron: Node = get_node_or_null("/root/Chronicle")
	if chron != null and chron.has_signal("entry_added"):
		chron.entry_added.connect(_on_chronicle)
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null:
		if tn.has_signal("tech_unlocked"):
			tn.tech_unlocked.connect(_on_tech_unlocked)
		if tn.has_signal("research_started"):
			tn.research_started.connect(_on_research_started)
		if tn.has_signal("research_progressed"):
			tn.research_progressed.connect(_on_research_progressed)
		if tn.has_signal("research_failed"):
			tn.research_failed.connect(func(r): _show_toast(r))
	var ss: Node = get_parent().get_node_or_null("SaveSlots")
	if ss != null and ss.has_signal("autosaved"):
		ss.autosaved.connect(func(_p: String) -> void: _autosave_indicator())
	_update_all()
func _build_hud() -> void:
	var insets := _safe_insets()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vbox)
	var top_panel := PanelContainer.new()
	top_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	top_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(UITheme.BG_CARD, 0.88), UITheme.RADIUS_M, Color(UITheme.GOLD_DIM, 0.5), 1))
	vbox.add_child(top_panel)
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 8 + int(insets["left"]))
	top_margin.add_theme_constant_override("margin_right", 8 + int(insets["right"]))
	top_margin.add_theme_constant_override("margin_top", 6 + int(insets["top"]))
	top_margin.add_theme_constant_override("margin_bottom", 6)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_child(top_margin)
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(top)
	var row1 := HBoxContainer.new()
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_theme_constant_override("separation", 10)
	top.add_child(row1)
	_turn_label = _make_label("Year 0 · Month 1", 18)
	row1.add_child(_turn_label)
	_time_label = _make_label("06:00", 16)
	row1.add_child(_time_label)
	_season_label = _make_label("spring · clear", 16)
	row1.add_child(_season_label)
	_pop_label = _make_label("👥 50", 16)
	row1.add_child(_pop_label)
	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(spacer1)
	_tech_btn = UITheme.make_button("🔬 Tech", "gold", Vector2(96, 44), 15)
	_tech_btn.tooltip_text = "Research tree (6 branches)"
	_tech_btn.pressed.connect(_toggle_tech_panel)
	row1.add_child(_tech_btn)
	var narr_btn := UITheme.make_button("📖 AI", "ghost", Vector2(76, 44), 15)
	narr_btn.tooltip_text = "Narrative provider settings"
	narr_btn.pressed.connect(_open_narrative_settings)
	row1.add_child(narr_btn)
	var gfx_btn := UITheme.make_button("🎮 GFX", "ghost", Vector2(76, 44), 15)
	gfx_btn.tooltip_text = "Graphics settings — presets, LOD, MSAA"
	gfx_btn.pressed.connect(_open_graphics_settings)
	row1.add_child(gfx_btn)
	_add_pressed_feedback(gfx_btn)
	_acc_scale_btn = UITheme.make_button("A+", "ghost", Vector2(48, 44), 14)
	_acc_scale_btn.tooltip_text = "Text scale (Accessibility)"
	_acc_scale_btn.pressed.connect(func() -> void:
		var ac: Node = get_node_or_null("/root/Main/Accessibility")
		if ac == null: ac = get_parent().get_node_or_null("Accessibility")
		if ac != null and ac.has_method("cycle_text_scale"): ac.call("cycle_text_scale")
		_apply_text_scale()
		_haptic("tap")
	)
	row1.add_child(_acc_scale_btn)
	_acc_slow_btn = UITheme.make_button("🐢", "ghost", Vector2(48, 44), 14)
	_acc_slow_btn.tooltip_text = "Slow-mode ×0.5"
	_acc_slow_btn.pressed.connect(func() -> void:
		var ac2: Node = get_node_or_null("/root/Main/Accessibility")
		if ac2 == null: ac2 = get_parent().get_node_or_null("Accessibility")
		if ac2 != null and "slow_mode" in ac2:
			var nv: bool = not bool(ac2.get("slow_mode"))
			if ac2.has_method("set_slow_mode"): ac2.call("set_slow_mode", nv)
			_acc_slow_btn.modulate = Color(0.5, 1, 0.5) if nv else Color(1, 1, 1)
		_haptic("tap")
	)
	row1.add_child(_acc_slow_btn)
	var dbg_btn := UITheme.make_button("DBG", "ghost", Vector2(48, 44), 12)
	dbg_btn.tooltip_text = "F1 Debug overlay"
	dbg_btn.pressed.connect(func() -> void:
		var d: Node = get_parent().get_node_or_null("DebugOverlay")
		if d != null and d.has_method("toggle"): d.call("toggle")
		_haptic("tap")
	)
	row1.add_child(dbg_btn)
	var menu_btn := UITheme.make_button("☰", "ghost", Vector2(48, 44), 20)
	menu_btn.pressed.connect(_toggle_radial)
	_add_pressed_feedback(menu_btn)
	row1.add_child(menu_btn)
	for b in [narr_btn, _acc_scale_btn, _acc_slow_btn, dbg_btn, menu_btn, _tech_btn]:
		if b != null: _add_pressed_feedback(b)
	var row2_scroll := ScrollContainer.new()
	row2_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row2_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row2_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(row2_scroll)
	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_theme_constant_override("separation", 8)
	row2_scroll.add_child(row2)
	for key in Game.RESOURCE_KEYS:
		var chip: Label = _make_resource_chip(key)
		chip.add_theme_font_size_override("font_size", 15)
		row2.add_child(chip)
	for key in Game.CHAIN_KEYS:
		var chip: Label = _make_label("", 14)
		chip.tooltip_text = key.capitalize()
		chip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
		_chain_labels[key] = chip
		row2.add_child(chip)
	var center_spacer := Control.new()
	center_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(center_spacer)
	var bottom_panel := PanelContainer.new()
	bottom_panel.custom_minimum_size = Vector2(0, 96)
	bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(UITheme.BG_CARD, 0.90), UITheme.RADIUS_M, Color(UITheme.GOLD_DIM, 0.5), 1))
	vbox.add_child(bottom_panel)
	var bottom_margin := MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 8 + int(insets["left"]))
	bottom_margin.add_theme_constant_override("margin_right", 8 + int(insets["right"]))
	bottom_margin.add_theme_constant_override("margin_top", 6)
	bottom_margin.add_theme_constant_override("margin_bottom", 6 + int(insets["bottom"]))
	bottom_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_panel.add_child(bottom_margin)
	var bottom_scroll := ScrollContainer.new()
	bottom_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	bottom_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_margin.add_child(bottom_scroll)
	var bottom_h := HBoxContainer.new()
	bottom_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_h.alignment = BoxContainer.ALIGNMENT_SPACE_BETWEEN
	bottom_h.add_theme_constant_override("separation", 8)
	bottom_scroll.add_child(bottom_h)
	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 8)
	bottom_h.add_child(left)
	for id in ["house", "farm", "mill", "bakery"]:
		var def: Dictionary = Catalog.get_building(id) if Catalog != null else {}
		var icon: String = String(def.get("icon", id))
		var btn := UITheme.make_button("%s %s" % [icon, String(def.get("name", id))], "default", Vector2(84, 48), 15)
		btn.tooltip_text = _cost_tooltip(id)
		var bid: String = id
		btn.pressed.connect(func() -> void: _select_building(bid))
		_add_pressed_feedback(btn)
		_add_long_press_tooltip(btn, _cost_tooltip(id))
		_build_btns[id] = btn
		left.add_child(btn)
	var clear_btn := UITheme.make_button("✕", "danger", Vector2(48, 48), 18)
	clear_btn.pressed.connect(func() -> void: _select_building(""))
	_add_pressed_feedback(clear_btn)
	left.add_child(clear_btn)
	var more_btn := UITheme.make_button("⋯", "ghost", Vector2(48, 48), 18)
	more_btn.pressed.connect(_toggle_radial)
	_add_pressed_feedback(more_btn)
	left.add_child(more_btn)
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 8)
	right.alignment = BoxContainer.ALIGNMENT_END
	bottom_h.add_child(right)
	for s in [0, 1, 4, 12]:
		var label: String = "⏸" if s == 0 else "×%d" % s
		var btn := UITheme.make_button(label, "ghost", Vector2(48, 48), 17)
		var sv: int = s
		btn.pressed.connect(func() -> void: TimeClock.set_speed(sv); _haptic("tap"))
		_add_pressed_feedback(btn)
		_speed_btns.append(btn)
		right.add_child(btn)
	var battle_btn := UITheme.make_button("⚔️ Battle", "danger", Vector2(104, 48), 15)
	battle_btn.tooltip_text = "Trigger test battle (3D MultiMesh)"
	battle_btn.pressed.connect(_trigger_battle)
	_add_pressed_feedback(battle_btn)
	right.add_child(battle_btn)
	var next_btn := UITheme.make_button("► End Turn", "primary", Vector2(118, 48), 15)
	next_btn.pressed.connect(func() -> void: TimeClock.end_turn_now(); _haptic("turn"))
	_add_pressed_feedback(next_btn)
	right.add_child(next_btn)
	_event_label = _make_label("", 18)
	_event_label.anchor_left = 0.5
	_event_label.anchor_right = 0.5
	_event_label.anchor_top = 0.72
	_event_label.offset_left = -420.0
	_event_label.offset_right = 420.0
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.modulate.a = 0.0
	_event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_event_label)
	_toast_label = _make_label("", 18)
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_right = 0.5
	_toast_label.anchor_top = 0.78
	_toast_label.offset_left = -360.0
	_toast_label.offset_right = 360.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	root.add_child(_toast_label)
	_month_card = PanelContainer.new()
	_month_card.anchor_left = 0.5
	_month_card.anchor_right = 0.5
	_month_card.anchor_top = 0.5
	_month_card.offset_left = -240.0
	_month_card.offset_right = 240.0
	_month_card.offset_top = -70.0
	_month_card.offset_bottom = 70.0
	_month_card.visible = false
	_month_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_month_card)
	_month_text = _make_label("", 18)
	_month_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_month_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_month_card.add_child(_month_text)
	_radial = _build_radial()
	_radial.visible = false
	root.add_child(_radial)
	_tech_panel = _build_tech_panel()
	_tech_panel.visible = false
	root.add_child(_tech_panel)
	_update_build_buttons()
func _build_radial() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -220.0
	p.offset_right = 220.0
	p.offset_top = -180.0
	p.offset_bottom = 180.0
	p.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.RADIUS_L, Color(UITheme.GOLD_DIM, 0.8), 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var title := _make_label("Build Menu", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for id in Catalog.building_ids() if Catalog != null else ["house", "farm", "mill", "bakery"]:
		var def: Dictionary = Catalog.get_building(id) if Catalog != null else {}
		var btn := UITheme.make_button("%s %s" % [String(def.get("icon", id)), String(def.get("name", id))], "default", Vector2(130, 48), 15)
		btn.tooltip_text = _cost_tooltip(id)
		var bid: String = id
		btn.pressed.connect(func() -> void: _select_building(bid); _radial.visible = false)
		grid.add_child(btn)
	var close := UITheme.make_button("Close", "ghost", Vector2(0, 48), 15)
	close.pressed.connect(func() -> void: _radial.visible = false)
	v.add_child(close)
	return p
func _build_tech_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -420.0
	p.offset_right = 420.0
	p.offset_top = -300.0
	p.offset_bottom = 300.0
	p.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.RADIUS_L, Color(UITheme.GOLD_DIM, 0.8), 1))
	var mv := MarginContainer.new()
	mv.add_theme_constant_override("margin_left", 10)
	mv.add_theme_constant_override("margin_right", 10)
	mv.add_theme_constant_override("margin_top", 10)
	mv.add_theme_constant_override("margin_bottom", 10)
	p.add_child(mv)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mv.add_child(v)
	var header := HBoxContainer.new()
	v.add_child(header)
	var title := _make_label("🔬 Research — 6 Branches", 20)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := UITheme.make_button("✕", "ghost", Vector2(48, 44), 16)
	close.pressed.connect(func() -> void: _tech_panel.visible = false)
	header.add_child(close)
	var research_row := HBoxContainer.new()
	research_row.add_theme_constant_override("separation", 8)
	v.add_child(research_row)
	_research_label = _make_label("No research", 14)
	_research_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	research_row.add_child(_research_label)
	_research_bar = ProgressBar.new()
	_research_bar.custom_minimum_size = Vector2(220, 14)
	_research_bar.show_percentage = false
	_research_bar.max_value = 100.0
	_research_bar.value = 0.0
	research_row.add_child(_research_bar)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_tech_vbox = VBoxContainer.new()
	_tech_vbox.add_theme_constant_override("separation", 10)
	sc.add_child(_tech_vbox)
	_refresh_tech_tree()
	return p
func _refresh_tech_tree() -> void:
	if _tech_vbox == null:
		return
	for c in _tech_vbox.get_children():
		c.queue_free()
	var branches: Array[String] = ["agriculture", "military", "commerce", "architecture", "arcane", "governance"]
	var branch_icons := {"agriculture": "🌾", "military": "⚔️", "commerce": "💰", "architecture": "🏛️", "arcane": "✨", "governance": "⚖️"}
	for branch in branches:
		var sec := VBoxContainer.new()
		sec.add_theme_constant_override("separation", 8)
		_tech_vbox.add_child(sec)
		var h := HBoxContainer.new()
		sec.add_child(h)
		var blab := _make_label("%s %s" % [String(branch_icons.get(branch, "•")), branch.capitalize()], 16)
		blab.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
		h.add_child(blab)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		sec.add_child(grid)
		var ids: Array = []
		if Catalog != null and Catalog.has_method("tech_by_branch"):
			var arr: Array[Dictionary] = Catalog.call("tech_by_branch", branch) as Array[Dictionary]
			for e in arr:
				ids.append(String(e.get("id", "")))
		elif has_node("/root/Tech"):
			var tn: Node = get_node("/root/Tech")
			if tn.has_method("ids_for_branch"):
				ids = tn.call("ids_for_branch", branch) as Array
		else:
			continue
		for tid in ids:
			var card := _make_tech_card(String(tid))
			grid.add_child(card)
		var sep := HSeparator.new()
		sec.add_child(sep)
	_update_research_row()
func _make_tech_card(id: String) -> PanelContainer:
	var entry: Dictionary = Catalog.get_tech(id) if Catalog != null and Catalog.has_method("get_tech") else {}
	if entry.is_empty() and has_node("/root/Tech"):
		entry = get_node("/root/Tech").call("get_tech", id) as Dictionary
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 96)
	var sb := StyleBoxFlat.new()
	var unlocked: bool = false
	var researching: bool = false
	var can: bool = false
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null:
		if tn.has_method("is_unlocked"):
			unlocked = bool(tn.call("is_unlocked", id))
		if tn.has_method("is_researching"):
			researching = bool(tn.call("is_researching", id))
		if tn.has_method("can_unlock"):
			can = bool(tn.call("can_unlock", id))
	if unlocked:
		sb.bg_color = Color(0.18, 0.32, 0.18, 0.95)
	elif researching:
		sb.bg_color = Color(0.26, 0.28, 0.18, 0.95)
	elif can:
		sb.bg_color = Color(0.18, 0.20, 0.28, 0.95)
	else:
		sb.bg_color = Color(0.16, 0.16, 0.17, 0.88)
	sb.corner_radius_top_left = UITheme.RADIUS_M
	sb.corner_radius_top_right = UITheme.RADIUS_M
	sb.corner_radius_bottom_left = UITheme.RADIUS_M
	sb.corner_radius_bottom_right = UITheme.RADIUS_M
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left", 8)
	mm.add_theme_constant_override("margin_right", 8)
	mm.add_theme_constant_override("margin_top", 8)
	mm.add_theme_constant_override("margin_bottom", 8)
	mm.add_child(v)
	p.add_child(mm)
	var title := _make_label("%s %s" % [String(entry.get("icon", "•")), String(entry.get("name", id))], 14)
	title.add_theme_color_override("font_color", Color(1, 1, 1) if can or unlocked else Color(0.7, 0.7, 0.7))
	v.add_child(title)
	var cost: Dictionary = entry.get("cost", {})
	var cost_txt: String = "◈%s  💰%s" % [str(cost.get("knowledge", "?")), str(cost.get("gold", "?"))]
	var cost_lab := _make_label(cost_txt, 12)
	cost_lab.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	v.add_child(cost_lab)
	var vis: String = String(entry.get("visible_upgrade", ""))
	var vis_lab := _make_label(vis, 11)
	vis_lab.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))
	vis_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(vis_lab)
	var bonuses: Dictionary = entry.get("bonuses", {})
	var bonus_txt := _bonuses_tooltip(bonuses)
	if bonus_txt != "":
		var b_lab := _make_label(bonus_txt, 11)
		b_lab.add_theme_color_override("font_color", Color(0.8, 0.82, 0.95))
		v.add_child(b_lab)
	var prereqs: Array = entry.get("prereqs", [])
	if not prereqs.is_empty():
		var pre_lab := _make_label("Req: %s" % ", ".join(prereqs), 10)
		pre_lab.add_theme_color_override("font_color", Color(0.85, 0.6, 0.6) if not unlocked and not can else Color(0.6, 0.85, 0.6))
		v.add_child(pre_lab)
	var btn: Button
	if unlocked:
		btn = UITheme.make_button("✓ Unlocked", "ghost", Vector2(0, 44), 13)
		btn.disabled = true
	elif researching:
		btn = UITheme.make_button("Researching…", "ghost", Vector2(0, 44), 13)
		btn.disabled = true
	elif can:
		btn = UITheme.make_button("Research", "primary", Vector2(0, 44), 13)
		btn.pressed.connect(func() -> void: _try_research(id))
	else:
		btn = UITheme.make_button("Locked", "ghost", Vector2(0, 44), 13)
		btn.disabled = true
	v.add_child(btn)
	if researching and tn != null:
		var prog: float = float(tn.get("progress"))
		var total: float = float(entry.get("cost", {}).get("knowledge", 1.0))
		var bar := ProgressBar.new()
		bar.max_value = total
		bar.value = prog
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		v.add_child(bar)
	return p
func _bonuses_tooltip(bonuses: Dictionary) -> String:
	var parts: PackedStringArray = []
	var pm: Variant = bonuses.get("prod_mult", null)
	if typeof(pm) == TYPE_DICTIONARY:
		for k in (pm as Dictionary):
			parts.append("%s ×%s" % [k, str(pm[k])])
	var ca: Variant = bonuses.get("cap_add", null)
	if typeof(ca) == TYPE_DICTIONARY:
		for k in (ca as Dictionary):
			parts.append("%s +%s" % [k, str(ca[k])])
	var ha: Variant = bonuses.get("happiness_add", null)
	if ha != null and float(ha) != 0.0:
		parts.append("♥%+0.2f" % float(ha))
	var mm: Variant = bonuses.get("military_power_mult", null)
	if mm != null:
		parts.append("⚔️×%s" % str(mm))
	var tm: Variant = bonuses.get("trade_value_mult", null)
	if tm != null:
		parts.append("trade×%s" % str(tm))
	return ", ".join(parts)
func _try_research(id: String) -> void:
	var tn: Node = get_node_or_null("/root/Tech")
	if tn == null or not tn.has_method("start_research"):
		_show_toast("Tech system not ready")
		return
	var ok: bool = bool(tn.call("start_research", id))
	if ok:
		_show_toast("🔬 Researching %s" % id)
		_refresh_tech_tree()
	else:
		_show_toast("Cannot research: prereqs or cost")
func _toggle_tech_panel() -> void:
	_refresh_tech_tree()
	_tech_panel.visible = not _tech_panel.visible
	if _tech_panel.visible:
		_radial.visible = false
func _update_research_row() -> void:
	if _research_label == null or _research_bar == null:
		return
	var tn: Node = get_node_or_null("/root/Tech")
	if tn == null:
		_research_label.text = "No research"
		_research_bar.value = 0.0
		return
	var rid: String = String(tn.get("researching"))
	if rid == "":
		_research_label.text = "Idle — pick a tech"
		_research_bar.value = 0.0
		_research_bar.max_value = 100.0
		return
	var entry: Dictionary = Catalog.get_tech(rid) if Catalog != null else {}
	if entry.is_empty():
		entry = tn.call("get_tech", rid) as Dictionary
	var prog: float = float(tn.get("progress"))
	var total: float = float(entry.get("cost", {}).get("knowledge", 1.0))
	_research_label.text = "🔬 %s %d/%d" % [String(entry.get("name", rid)), int(prog), int(total)]
	_research_bar.max_value = total
	_research_bar.value = prog
func _on_tech_unlocked(id: String) -> void:
	_show_toast("✨ Unlocked %s!" % id)
	_refresh_tech_tree()
	_update_research_row()
func _on_research_started(id: String) -> void:
	_show_toast("🔬 Started %s" % id)
	_refresh_tech_tree()
	_update_research_row()
func _on_research_progressed(id: String, prog: float, total: float) -> void:
	_update_research_row()
	if _tech_panel.visible:
		_refresh_tech_tree()
func _cost_tooltip(id: String) -> String:
	var def: Dictionary = Catalog.get_building(id) if Catalog != null else {}
	var cost: Dictionary = def.get("cost", {})
	if cost.is_empty():
		return "Free"
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%s:%s" % [k, str(cost[k])])
	return ", ".join(parts)
func _toggle_radial() -> void:
	_radial.visible = not _radial.visible
	if _radial.visible:
		_tech_panel.visible = false
func _make_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", UITheme.TEXT_MAIN)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
func _make_resource_chip(key: String) -> Label:
	var l := _make_label("", 15)
	l.tooltip_text = key.capitalize()
	_res_labels[key] = l
	return l
func _select_building(id: String) -> void:
	_selected_id = id
	if _build_mgr != null:
		_build_mgr.selected_id = id
	_update_build_buttons()
	_haptic("tap")
	if id == "":
		_show_toast("Selection cleared")
	else:
		var def: Dictionary = Catalog.get_building(id) if Catalog != null else {}
		_show_toast("Selected %s — %s" % [String(def.get("name", id)), _cost_tooltip(id)])
func _flush_dirty() -> void:
	if _dirty_resources:
		_dirty_resources = false
		for key in Game.RESOURCE_KEYS:
			var cur := int(maxf(0.0, Game.get_stock(key)))
			if _cached_stock.get(key, 999999) == cur:
				continue
			_cached_stock[key] = cur
			var lab: Label = _res_labels[key]
			if lab == null:
				continue
			var icon: String = String({"food":"🌾","gold":"💰","wood":"🪵","stone":"🪨","iron":"⚙️","cloth":"🧶","horses":"🐎","knowledge":"📜"}.get(key, key))
			lab.text = "%s %d" % [icon, cur]
		for key in Game.CHAIN_KEYS:
			var lab2: Label = _chain_labels[key]
			if lab2 == null:
				continue
			var v := int(Game.get_stock(key))
			lab2.text = "%s %d" % [key.capitalize(), v] if v > 0 else ""
		_dirty_build = true
		var tn: Node = get_node_or_null("/root/Tech")
		if tn != null and _tech_btn != null:
			var unlocked: int = int((tn.get("unlocked") as Array).size()) if "unlocked" in tn else 0
			var nt := "🔬 Tech %d" % unlocked
			if _tech_btn.text != nt:
				_tech_btn.text = nt
		_update_research_row()
	if _dirty_pop:
		_dirty_pop = false
		var agents: int = 0
		var ag_mgr: Node = get_parent().get_node_or_null("AgentManager")
		if ag_mgr != null and ag_mgr.has_method("agent_count"):
			agents = int(ag_mgr.agent_count())
		var ap: String = " · 👤%d" % agents if agents > 0 else ""
		var hap := clampf(Game.pop_happiness, 0.0, 1.0)
		var nt2 := "👥 %d/%d ♥%.0f%%%s" % [int(max(0, Game.pop_count)), int(Game.pop_capacity_base + Game.building_cap.get("housing", 0.0) + _tech_cap()), hap * 100.0, ap]
		if nt2 != _cached_pop_text:
			_cached_pop_text = nt2
			_pop_label.text = nt2
	if _dirty_build:
		_dirty_build = false
		_update_build_buttons_immediate()
	if _dirty_tech:
		_dirty_tech = false
		_refresh_tech_tree()
	if _dirty_time:
		_dirty_time = false
		var nt := TimeClock.time_of_day()
		if _time_label.text != nt:
			_time_label.text = nt
		var s: String = Game.season()
		var w: String = "clear"
		var weather: Node = get_parent().get_node_or_null("Weather")
		if weather != null and "state" in weather:
			w = String(weather.state)
		var ns := "%s · %s" % [s, w]
		if ns != _cached_time_text:
			_cached_time_text = ns
			_season_label.text = ns

func _update_build_buttons_immediate() -> void:
	for id in _build_btns:
		var btn: Button = _build_btns[id]
		var affordable := true
		if _build_mgr != null and _build_mgr.has_method("can_afford"):
			affordable = _build_mgr.can_afford(id)
		btn.disabled = not affordable
		btn.modulate = Color(1, 1, 1, 1) if affordable else Color(1, 1, 1, 0.45)
		if id == _selected_id:
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			btn.add_theme_color_override("font_color", Color(1, 1, 1))

func _update_build_buttons() -> void:
	_dirty_build = true
func _on_turned() -> void:
	_turn_label.text = "Year %d · Month %d" % [Game.year, Game.month]
	_dirty_pop = true
	_dirty_build = true
	_dirty_tech = true
	_show_month_card()
	_haptic("turn")
func _add_long_press_tooltip(btn: Button, tip: String) -> void:
	var hold_time := 0.55
	var timer: SceneTreeTimer = null
	var holding := false
	btn.button_down.connect(func() -> void:
		holding = true
		timer = get_tree().create_timer(hold_time)
		timer.timeout.connect(func() -> void:
			if holding and btn.is_inside_tree():
				_show_toast(tip)
				_haptic("tap")
		)
	)
	btn.button_up.connect(func() -> void: holding = false)
	btn.mouse_exited.connect(func() -> void: holding = false)
func _autosave_indicator() -> void:
	_show_toast("💾 Autosaved")
	var tw := create_tween()
	tw.tween_property(_toast_label, "scale", Vector2(1.08, 1.08), 0.12)
	tw.tween_property(_toast_label, "scale", Vector2.ONE, 0.14)
func _on_resources_changed() -> void:
	_dirty_resources = true
func _on_pop_changed() -> void:
	_dirty_pop = true
func _process(_delta: float) -> void:
	if _dirty_resources or _dirty_pop or _dirty_build or _dirty_tech or _dirty_time:
		_flush_dirty()

func _tech_cap() -> float:
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null and tn.has_method("get_total_cap_add"):
		return float(tn.call("get_total_cap_add", "housing"))
	return 0.0
func _on_event(event: Dictionary) -> void:
	_event_label.text = String(event.get("text", ""))
	_event_label.modulate.a = 1.0
	var t := get_tree().create_timer(4.0)
	t.timeout.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(_event_label, "modulate:a", 0.0, 0.6)
	)
func _on_place_failed(reason: String) -> void:
	_show_toast(reason)
var _toast_tween: Tween = null
var _toast_timer: SceneTreeTimer = null
func _show_toast(msg: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = msg
	_toast_label.modulate.a = 0.0
	_toast_label.scale = Vector2(0.85, 0.85)
	_toast_label.position.y = 8
	var tw := create_tween()
	_toast_tween = tw
	tw.set_parallel(true)
	tw.tween_property(_toast_label, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_toast_label, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_toast_label, "position:y", 0.0, 0.22)
	tw.set_parallel(false)
	var t := get_tree().create_timer(2.2)
	_toast_timer = t
	t.timeout.connect(func() -> void:
		if not is_instance_valid(_toast_label): return
		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(_toast_label, "modulate:a", 0.0, 0.45)
		tw2.tween_property(_toast_label, "scale", Vector2(0.92, 0.92), 0.35)
	)
func _on_hour(hour: float) -> void:
	_dirty_time = true
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
	var t := get_tree().create_timer(2.4)
	t.timeout.connect(func() -> void: _month_card.visible = false)
func _trigger_battle() -> void:
	var main: Node = get_parent()
	if main != null and main.has_method("trigger_test_battle"):
		main.trigger_test_battle()
		_show_toast("⚔️ Battle marching…")
		_haptic("danger")
	else:
		_show_toast("Battle unavailable")
func _on_narrative(event: Dictionary, result: Dictionary) -> void:
	var txt: String = str(result.get("text", event.get("text", "")))
	var prov: String = str(result.get("provider", "local"))
	_event_label.text = "[%s] %s" % [prov, txt]
	_event_label.modulate.a = 1.0
	var choices: Variant = result.get("choices", [])
	if typeof(choices) == TYPE_ARRAY and not (choices as Array).is_empty():
		var hint: String = str((choices as Array)[0].get("label", ""))
		_show_toast("📖 %s — %s" % [prov, hint])
	var t := get_tree().create_timer(5.5)
	t.timeout.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(_event_label, "modulate:a", 0.0, 0.7)
	)
func _on_chronicle(entry: Dictionary) -> void:
	_show_toast("📜 %s" % str(entry.get("text", "")).substr(0, 48))
func _open_narrative_settings() -> void:
	var ns: CanvasLayer = get_parent().get_node_or_null("NarrativeSettings")
	if ns != null:
		ns.visible = not ns.visible
		if ns.has_method("open") and ns.visible:
			ns.call("open")

func _open_graphics_settings() -> void:
	var gs: CanvasLayer = get_parent().get_node_or_null("GraphicsSettings")
	if gs == null:
		gs = get_node_or_null("/root/Main/GraphicsSettings") as CanvasLayer
	if gs != null:
		gs.visible = not gs.visible
		if gs.has_method("open") and gs.visible:
			gs.call("open")
		_haptic("tap")
	else:
		_show_toast("GFX panel not ready")
func _update_all() -> void:
	_on_turned()
	_on_resources_changed()
	_on_pop_changed()
	_on_hour(TimeClock.sim_hour)
	_on_speed(TimeClock.speed)
	_flush_dirty()
