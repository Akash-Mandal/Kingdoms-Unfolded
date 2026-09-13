extends CanvasLayer

var _list: VBoxContainer
var _header: Label
var _visible_flag := false
var _toggle_btn: Button
var _panel: PanelContainer

func _ready() -> void:
	layer = 15
	_build_ui()
	_refresh()
	if has_node("/root/Diplomacy"):
		var d: Node = get_node("/root/Diplomacy")
		if d.has_signal("diplomacy_changed"):
			d.diplomacy_changed.connect(_refresh)
		if d.has_signal("relation_changed"):
			d.relation_changed.connect(func(_id: String) -> void: _refresh())
		if d.has_signal("treaty_changed"):
			d.treaty_changed.connect(func(_a: String, _b: String) -> void: _refresh())
	if has_node("/root/Game"):
		var g: Node = get_node("/root/Game")
		if g.has_signal("turned"):
			g.turned.connect(_refresh)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_toggle_btn = UITheme.make_button("🤝 Diplomacy", "ghost", Vector2(140, 44), 15)
	_toggle_btn.anchor_left = 1.0
	_toggle_btn.anchor_top = 0.0
	_toggle_btn.anchor_right = 1.0
	_toggle_btn.anchor_bottom = 0.0
	_toggle_btn.offset_left = -158.0
	_toggle_btn.offset_top = 98.0
	_toggle_btn.offset_right = -12.0
	_toggle_btn.offset_bottom = 142.0
	_toggle_btn.pressed.connect(_toggle)
	root.add_child(_toggle_btn)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -360.0
	_panel.offset_right = 360.0
	_panel.offset_top = -300.0
	_panel.offset_bottom = 300.0
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.12, 0.12, 0.14, 0.96), 10))
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
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	_header = Label.new()
	_header.text = "Diplomacy"
	_header.add_theme_font_size_override("font_size", 20)
	_header.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_header)
	var close_btn := UITheme.make_button("✕", "danger", Vector2(44, 44))
	close_btn.pressed.connect(_toggle)
	title_row.add_child(close_btn)
	vbox.add_child(HSeparator.new())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	sc.add_child(_list)

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
	var d: Variant = get_node_or_null("/root/Diplomacy")
	var cat: Variant = get_node_or_null("/root/Catalog")
	if d == null:
		var lbl := Label.new()
		lbl.text = "Diplomacy not initialised."
		lbl.add_theme_font_size_override("font_size", 14)
		_list.add_child(lbl)
		return
	var kids: Array = d.kingdom_ids() if d.has_method("kingdom_ids") else []
	if kids.is_empty():
		var lbl2 := Label.new()
		lbl2.text = "No rival kingdoms discovered yet."
		lbl2.add_theme_font_size_override("font_size", 14)
		_list.add_child(lbl2)
		return
	_header.text = "Diplomacy — %d Rivals" % kids.size()
	for kid in kids:
		var kingdom: Dictionary = d.get_kingdom(kid) if d.has_method("get_kingdom") else {}
		var rel: Dictionary = d.get_relation(kid) if d.has_method("get_relation") else {}
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.18, 0.18, 0.20, 1), 8))
		_list.add_child(row)
		var inner := MarginContainer.new()
		inner.add_theme_constant_override("margin_left", 8)
		inner.add_theme_constant_override("margin_right", 8)
		inner.add_theme_constant_override("margin_top", 6)
		inner.add_theme_constant_override("margin_bottom", 6)
		row.add_child(inner)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		inner.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		v.add_child(top)
		var name_lbl := Label.new()
		name_lbl.text = "%s" % String(kingdom.get("name", kid))
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 0.85))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_lbl)
		var cult_lbl := Label.new()
		cult_lbl.text = "%s · PWR %d" % [String(kingdom.get("culture", "?")), int(float(kingdom.get("power", 0.0)))]
		cult_lbl.add_theme_font_size_override("font_size", 13)
		cult_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		top.add_child(cult_lbl)
		var score: int = int(rel.get("score", 0))
		var trust: float = float(rel.get("trust", 0.0))
		var treaty: String = String(rel.get("treaty", "none"))
		var treaty_icon: String = _treaty_icon(treaty, cat)
		var mid := HBoxContainer.new()
		mid.add_theme_constant_override("separation", 8)
		v.add_child(mid)
		var score_lbl := Label.new()
		var sc_col: Color = Color(0.5, 1, 0.5) if score > 10 else (Color(1, 0.5, 0.5) if score < -10 else Color(0.9, 0.9, 0.9))
		score_lbl.text = "Score %d" % score
		score_lbl.add_theme_font_size_override("font_size", 14)
		score_lbl.add_theme_color_override("font_color", sc_col)
		mid.add_child(score_lbl)
		var trust_lbl := Label.new()
		trust_lbl.text = "Trust %.2f" % trust
		trust_lbl.add_theme_font_size_override("font_size", 14)
		var tr_col: Color = Color(0.5, 0.8, 1) if trust > 0.12 else (Color(1, 0.6, 0.4) if trust < -0.12 else Color(0.9, 0.9, 0.9))
		trust_lbl.add_theme_color_override("font_color", tr_col)
		mid.add_child(trust_lbl)
		var treaty_lbl := Label.new()
		treaty_lbl.text = "%s %s" % [treaty_icon, treaty.capitalize() if treaty != "none" else "No treaty"]
		treaty_lbl.add_theme_font_size_override("font_size", 14)
		mid.add_child(treaty_lbl)
		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(0, 6)
		bar_bg.color = Color(0.22, 0.22, 0.22, 1)
		v.add_child(bar_bg)
		var fill := ColorRect.new()
		fill.custom_minimum_size = Vector2(maxf(0.0, (float(score + 100) / 200.0) * 640.0), 6)
		fill.color = sc_col
		bar_bg.add_child(fill)
		var trust_bar_bg := ColorRect.new()
		trust_bar_bg.custom_minimum_size = Vector2(0, 4)
		trust_bar_bg.color = Color(0.22, 0.22, 0.22, 1)
		v.add_child(trust_bar_bg)
		var trust_fill := ColorRect.new()
		trust_fill.custom_minimum_size = Vector2(maxf(0.0, (trust + 1.0) / 2.0 * 640.0), 4)
		trust_fill.color = tr_col
		trust_bar_bg.add_child(trust_fill)
		var mem: Variant = rel.get("memory", null)
		var mem_arr: Array = []
		if mem != null:
			if mem is Array:
				mem_arr = mem
			elif mem.has_method("to_array"):
				mem_arr = mem.to_array()
		var mem_lbl := Label.new()
		if mem_arr.is_empty():
			mem_lbl.text = "Memory: —"
		else:
			var last: int = mini(3, mem_arr.size())
			var tags: PackedStringArray = []
			for i in range(mem_arr.size() - last, mem_arr.size()):
				var e: Variant = mem_arr[i]
				if e is Dictionary:
					tags.append(String((e as Dictionary).get("tag", "?")))
			mem_lbl.text = "Memory [%d]: %s · last turn %d" % [mem_arr.size(), ", ".join(tags), int(rel.get("last_event", 0))]
		mem_lbl.add_theme_font_size_override("font_size", 12)
		mem_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		v.add_child(mem_lbl)
		if has_node("/root/Diplomacy") and get_node("/root/Diplomacy").has_method("ai_utility"):
			var util: Dictionary = get_node("/root/Diplomacy").ai_utility(kid)
			var best: String = ""
			var best_v: float = -1e9
			for k2 in util:
				if float(util[k2]) > best_v:
					best_v = float(util[k2])
					best = String(k2)
			var util_lbl := Label.new()
			util_lbl.text = "AI leans: %s (war:%.0f trade:%.0f marry:%.0f betray:%.0f gift:%.0f)" % [best, float(util.get("war", 0.0)), float(util.get("trade", 0.0)), float(util.get("marry", 0.0)), float(util.get("betray", 0.0)), float(util.get("gift", 0.0))]
			util_lbl.add_theme_font_size_override("font_size", 11)
			util_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
			v.add_child(util_lbl)
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		v.add_child(btn_row)
		var gift_btn := UITheme.make_button("🎁 Gift (10g)", "primary", Vector2(120, 44), 13)
		var gkid: String = String(kid)
		gift_btn.pressed.connect(func() -> void:
			var dip: Variant = get_node_or_null("/root/Diplomacy")
			if dip != null and dip.has_method("gift_to"):
				dip.gift_to(gkid, 10)
				_refresh()
		)
		btn_row.add_child(gift_btn)
		var nap_btn := UITheme.make_button("🤝 Pact", "primary", Vector2(96, 44), 13)
		nap_btn.pressed.connect(func() -> void:
			var dip2: Variant = get_node_or_null("/root/Diplomacy")
			if dip2 != null and dip2.has_method("set_treaty"):
				dip2.set_treaty(gkid, "non_aggression_pact")
				_refresh()
		)
		nap_btn.disabled = treaty != "none"
		btn_row.add_child(nap_btn)
		var ally_btn := UITheme.make_button("🛡️ Ally", "primary", Vector2(96, 44), 13)
		ally_btn.pressed.connect(func() -> void:
			var dip3: Variant = get_node_or_null("/root/Diplomacy")
			if dip3 != null and dip3.has_method("set_treaty"):
				dip3.set_treaty(gkid, "alliance")
				_refresh()
		)
		ally_btn.disabled = treaty != "none"
		btn_row.add_child(ally_btn)
		var break_btn := UITheme.make_button("💔 Break", "danger", Vector2(96, 44), 13)
		break_btn.pressed.connect(func() -> void:
			var dip4: Variant = get_node_or_null("/root/Diplomacy")
			if dip4 != null and dip4.has_method("break_treaty"):
				dip4.break_treaty(gkid)
				_refresh()
		)
		break_btn.disabled = treaty == "none"
		btn_row.add_child(break_btn)

func _treaty_icon(treaty_id: String, cat: Variant) -> String:
	if cat != null and "treaties" in cat and cat.treaties is Dictionary and cat.treaties.has(treaty_id):
		return String(cat.treaties[treaty_id].get("icon", "—"))
	match treaty_id:
		"non_aggression_pact": return "🤝"
		"trade_agreement": return "⚖️"
		"royal_marriage": return "💍"
		"alliance": return "🛡️"
		"vassalage": return "👑"
		"confederation": return "🏰"
		_: return "—"
