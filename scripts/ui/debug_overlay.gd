extends CanvasLayer

var _panel: PanelContainer
var _label: Label
var _visible_overlay := false
var _accum := 0.0
var _sim_ms := 0.0
var _agent_count_cache := 0
var _frame_ms := 0.0
var _peak_sim := 0.0

func _ready() -> void:
	layer = 90
	_build()
	visible = false

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 8.0
	margin.offset_top = 100.0
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.05, 0.05, 0.07, 0.82), 6))
	margin.add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 3)
	_label.text = "FPS -- | DC -- | Agents -- | Sim -- ms"
	_panel.add_child(_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	_visible_overlay = not _visible_overlay
	visible = _visible_overlay

func set_visible_overlay(v: bool) -> void:
	_visible_overlay = v
	visible = v

func push_sim_ms(ms: float) -> void:
	_sim_ms = ms
	_peak_sim = maxf(_peak_sim, ms)

func _get_draw_calls() -> int:
	if RenderingServer.has_method("get_rendering_info"):
		var v: Variant = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		if typeof(v) == TYPE_INT and int(v) > 0:
			return int(v)
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _process(delta: float) -> void:
	_frame_ms = lerp(_frame_ms, delta * 1000.0, 0.15)
	if not _visible_overlay:
		return
	_accum += delta
	if _accum < 0.2:
		return
	_accum = 0.0
	var fps := Engine.get_frames_per_second()
	if fps == 0:
		fps = int(Performance.get_monitor(Performance.TIME_FPS))
	var dc := _get_draw_calls()
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var agents := _agent_count()
	_agent_count_cache = agents
	var vram: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var vram_tex: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var warn_fps := "⚠" if fps < 30 else "✓"
	var warn_dc := "⚠" if dc > 400 else "✓"
	var warn_sim := "⚠" if _sim_ms > 4.0 else "✓"
	_label.text = "FPS %d %s | DC %d %s (obj %d prim %d) | Agents %d | Sim %.2f ms %s (peak %.1f) | Frame %.1f ms | VRAM %.0f MB (tex %.0f)" % [fps, warn_fps, dc, warn_dc, objs, primitives, agents, _sim_ms, warn_sim, _peak_sim, _frame_ms, vram, vram_tex]
	_peak_sim = lerp(_peak_sim, _sim_ms, 0.05)

func _agent_count() -> int:
	var m: Node = get_parent().get_node_or_null("AgentManager") if get_parent() != null else null
	if m == null:
		m = get_node_or_null("/root/Main/AgentManager")
	if m != null and m.has_method("agent_count"):
		return int(m.agent_count())
	return _agent_count_cache
