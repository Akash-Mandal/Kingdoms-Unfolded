extends CanvasLayer
var _preset_opt: OptionButton
var _scale_slider: HSlider
var _scale_label: Label
var _msaa_opt: OptionButton
var _shadows_opt: OptionButton
var _fog_slider: HSlider
var _fog_label: Label
var _lod_a_opt: OptionButton
var _lod_b_opt: OptionButton
var _max_a_opt: OptionButton
var _tree_opt: OptionButton
var _atlas_opt: OptionButton
var _glow_check: CheckButton
var _vsync_check: CheckButton
var _status: Label
var _pending: Dictionary = {}

func _ready() -> void:
	layer = 30
	visible = false
	_build_ui()
	_load_from_autoload()
	_connect_graphics_signal()

func _connect_graphics_signal() -> void:
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs != null and gs.has_signal("graphics_changed"):
		if not gs.graphics_changed.is_connected(_on_graphics_changed):
			gs.graphics_changed.connect(_on_graphics_changed)

func _on_graphics_changed(_preset: String, _cfg: Dictionary) -> void:
	_load_from_autoload()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			visible = false
	)
	root.add_child(bg)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -360
	panel.offset_bottom = 360
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.09, 0.09, 0.12, 0.98), 14))
	root.add_child(panel)
	var mv := MarginContainer.new()
	mv.add_theme_constant_override("margin_left", 14)
	mv.add_theme_constant_override("margin_right", 14)
	mv.add_theme_constant_override("margin_top", 12)
	mv.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(mv)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	mv.add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "🎮 Graphics Settings"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := UITheme.make_button("✕", "danger", Vector2(44, 44))
	close.pressed.connect(func() -> void: visible = false)
	header.add_child(close)
	vbox.add_child(HSeparator.new())
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	vbox.add_child(preset_row)
	var plab := Label.new()
	plab.text = "Preset"
	plab.custom_minimum_size = Vector2(90, 0)
	preset_row.add_child(plab)
	_preset_opt = OptionButton.new()
	_preset_opt.custom_minimum_size = Vector2(260, 44)
	for p in ["Potato", "Balanced", "High", "Ultra"]:
		_preset_opt.add_item(p)
	_preset_opt.item_selected.connect(_on_preset_picked)
	preset_row.add_child(_preset_opt)
	var auto_btn := UITheme.make_button("Auto-Detect", "ghost", Vector2(120, 44), 13)
	auto_btn.pressed.connect(_on_auto_detect)
	preset_row.add_child(auto_btn)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(sc)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	sc.add_child(form)
	var scale_row := HBoxContainer.new()
	form.add_child(scale_row)
	var sl := Label.new()
	sl.text = "Render Scale"
	sl.custom_minimum_size = Vector2(110, 0)
	scale_row.add_child(sl)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.7
	_scale_slider.max_value = 1.0
	_scale_slider.step = 0.05
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.value_changed.connect(_on_scale_changed)
	scale_row.add_child(_scale_slider)
	_scale_label = Label.new()
	_scale_label.custom_minimum_size = Vector2(44, 0)
	scale_row.add_child(_scale_label)
	_msaa_opt = _add_option_row(form, "MSAA", ["Off (0)", "2× (1)", "4× (2)", "8× (4)"], _on_msaa_picked)
	_shadows_opt = _add_option_row(form, "Shadows", ["Off", "Soft"], _on_shadows_picked)
	var fog_row := HBoxContainer.new()
	form.add_child(fog_row)
	var fl := Label.new()
	fl.text = "Fog Density"
	fl.custom_minimum_size = Vector2(110, 0)
	fog_row.add_child(fl)
	_fog_slider = HSlider.new()
	_fog_slider.min_value = 0.5
	_fog_slider.max_value = 1.4
	_fog_slider.step = 0.05
	_fog_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fog_slider.value_changed.connect(_on_fog_changed)
	fog_row.add_child(_fog_slider)
	_fog_label = Label.new()
	_fog_label.custom_minimum_size = Vector2(44, 0)
	fog_row.add_child(_fog_label)
	_lod_a_opt = _add_option_row(form, "LOD Tier A", ["20", "30", "45"], _on_lod_a_picked)
	_lod_b_opt = _add_option_row(form, "LOD Tier B", ["80", "120", "180"], _on_lod_b_picked)
	_max_a_opt = _add_option_row(form, "Max Tier-A", ["400", "800", "1200"], _on_max_a_picked)
	_tree_opt = _add_option_row(form, "Tree Count", ["120", "260", "400"], _on_tree_picked)
	_atlas_opt = _add_option_row(form, "Shadow Atlas", ["1024", "2048", "4096"], _on_atlas_picked)
	var glow_row := HBoxContainer.new()
	form.add_child(glow_row)
	var gl := Label.new()
	gl.text = "Glow"
	gl.custom_minimum_size = Vector2(110, 0)
	glow_row.add_child(gl)
	_glow_check = CheckButton.new()
	_glow_check.text = "Enabled"
	_glow_check.toggled.connect(_on_glow_toggled)
	glow_row.add_child(_glow_check)
	var vsync_row := HBoxContainer.new()
	form.add_child(vsync_row)
	var vl := Label.new()
	vl.text = "VSync"
	vl.custom_minimum_size = Vector2(110, 0)
	vsync_row.add_child(vl)
	_vsync_check = CheckButton.new()
	_vsync_check.text = "Enabled"
	_vsync_check.toggled.connect(_on_vsync_toggled)
	vsync_row.add_child(_vsync_check)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_status)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	var cancel := UITheme.make_button("Cancel", "ghost", Vector2(96, 44))
	cancel.pressed.connect(func() -> void: _load_from_autoload(); visible = false)
	btn_row.add_child(cancel)
	var apply := UITheme.make_button("Apply", "primary", Vector2(110, 48))
	apply.pressed.connect(_on_apply)
	btn_row.add_child(apply)

func _add_option_row(parent: VBoxContainer, label_txt: String, items: PackedStringArray, cb: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = label_txt
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(200, 44)
	for it in items:
		opt.add_item(it)
	opt.item_selected.connect(cb)
	row.add_child(opt)
	return opt

func _load_from_autoload() -> void:
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	var cfg: Dictionary = {}
	var preset := "balanced"
	if gs != null:
		preset = str(gs.get("current_preset"))
		cfg = gs.get("get_config").call() as Dictionary if gs.has_method("get_config") else gs.get("current_config") as Dictionary
		if cfg.is_empty() and gs.has_method("get_preset_config"):
			cfg = gs.call("get_preset_config", preset) as Dictionary
		var tier: String = str(gs.get("device_tier")) if "device_tier" in gs else ""
		var rend: String = str(gs.get("renderer_name")) if "renderer_name" in gs else ""
		_status.text = "Device: %s · Renderer: %s · Preset: %s" % [tier, rend, preset.capitalize()]
	else:
		cfg = {
			"render_scale": 0.85, "msaa": 1, "shadows": "soft", "fog_density_mult": 0.85,
			"lod_tier_a": 30.0, "lod_tier_b": 120.0, "max_tier_a": 800, "tree_count": 260,
			"shadow_atlas": 2048, "glow_enabled": true, "vsync": 1
		}
	_pending = cfg.duplicate(true)
	_sync_ui(cfg, preset)
	_pending = cfg.duplicate(true)

func _sync_ui(cfg: Dictionary, preset: String) -> void:
	var map := {"potato": 0, "balanced": 1, "high": 2, "ultra": 3}
	_preset_opt.select(int(map.get(preset.to_lower(), 1)))
	_scale_slider.value = float(cfg.get("render_scale", 0.85))
	_scale_label.text = "%.2f" % float(cfg.get("render_scale", 0.85))
	var msaa: int = int(cfg.get("msaa", 1))
	var msaa_idx := 0
	match msaa:
		0: msaa_idx = 0
		1: msaa_idx = 1
		2: msaa_idx = 2
		4: msaa_idx = 3
		_: msaa_idx = 1
	_msaa_opt.select(msaa_idx)
	_shadows_opt.select(0 if str(cfg.get("shadows", "soft")) == "off" else 1)
	_fog_slider.value = float(cfg.get("fog_density_mult", 0.85))
	_fog_label.text = "%.2f" % float(cfg.get("fog_density_mult", 0.85))
	_lod_a_opt.select(_idx_for_value([20, 30, 45], int(cfg.get("lod_tier_a", 30))))
	_lod_b_opt.select(_idx_for_value([80, 120, 180], int(cfg.get("lod_tier_b", 120))))
	_max_a_opt.select(_idx_for_value([400, 800, 1200], int(cfg.get("max_tier_a", 800))))
	_tree_opt.select(_idx_for_value([120, 260, 400], int(cfg.get("tree_count", 260))))
	_atlas_opt.select(_idx_for_value([1024, 2048, 4096], int(cfg.get("shadow_atlas", 2048))))
	_glow_check.button_pressed = bool(cfg.get("glow_enabled", true))
	_vsync_check.button_pressed = bool(int(cfg.get("vsync", 1)) != 0)

func _idx_for_value(arr: Array, v: int) -> int:
	for i in arr.size():
		if int(arr[i]) == v:
			return i
	return 1

func _on_preset_picked(idx: int) -> void:
	var names := ["potato", "balanced", "high", "ultra"]
	var name: String = names[idx]
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs != null and gs.has_method("get_preset_config"):
		_pending = gs.call("get_preset_config", name) as Dictionary
		_sync_ui(_pending, name)

func _on_auto_detect() -> void:
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs == null or not gs.has_method("auto_detect"):
		return
	var tier: String = str(gs.call("auto_detect"))
	var map := {"low": "potato", "mid": "balanced", "high": "high", "ultra": "ultra"}
	var preset: String = str(map.get(tier, "balanced"))
	if gs.has_method("get_preset_config"):
		_pending = gs.call("get_preset_config", preset) as Dictionary
		_sync_ui(_pending, preset)
	_status.text = "Auto-detected: %s → %s (press Apply)" % [tier, preset.capitalize()]

func _on_scale_changed(v: float) -> void:
	_scale_label.text = "%.2f" % v
	_pending["render_scale"] = v

func _on_msaa_picked(idx: int) -> void:
	var vals := [0, 1, 2, 4]
	_pending["msaa"] = vals[idx]

func _on_shadows_picked(idx: int) -> void:
	_pending["shadows"] = "off" if idx == 0 else "soft"

func _on_fog_changed(v: float) -> void:
	_fog_label.text = "%.2f" % v
	_pending["fog_density_mult"] = v

func _on_lod_a_picked(idx: int) -> void:
	_pending["lod_tier_a"] = [20.0, 30.0, 45.0][idx]

func _on_lod_b_picked(idx: int) -> void:
	_pending["lod_tier_b"] = [80.0, 120.0, 180.0][idx]

func _on_max_a_picked(idx: int) -> void:
	_pending["max_tier_a"] = [400, 800, 1200][idx]

func _on_tree_picked(idx: int) -> void:
	_pending["tree_count"] = [120, 260, 400][idx]

func _on_atlas_picked(idx: int) -> void:
	_pending["shadow_atlas"] = [1024, 2048, 4096][idx]

func _on_glow_toggled(v: bool) -> void:
	_pending["glow_enabled"] = v

func _on_vsync_toggled(v: bool) -> void:
	_pending["vsync"] = 1 if v else 0

func _on_apply() -> void:
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs == null:
		visible = false
		return
	if gs.has_method("apply_custom"):
		gs.call("apply_custom", _pending)
	_status.text += " — Applied."
	_hot_reload()
	visible = false

func _hot_reload() -> void:
	var main: Node = get_parent()
	if main == null:
		main = get_tree().current_scene
	if main != null:
		var rig: Node = main.get_node_or_null("EnvironmentRig")
		if rig != null and rig.has_method("apply_graphics"):
			rig.call("apply_graphics", _pending)
		var terrain: Node = main.get_node_or_null("TerrainSource")
		if terrain != null and terrain.has_method("apply_graphics"):
			terrain.call("apply_graphics", _pending)
		var ag: Node = main.get_node_or_null("AgentManager")
		if ag != null and ag.has_method("apply_graphics"):
			ag.call("apply_graphics", _pending)
		var cam: Camera3D = main.get_node_or_null("MainCamera") as Camera3D
		if cam != null and cam.has_method("apply_graphics"):
			cam.call("apply_graphics", _pending)

func open() -> void:
	_load_from_autoload()
	visible = true
