class_name UITheme
extends RefCounted

const BG_DEEP := Color(0.055, 0.05, 0.075, 1.0)
const BG_PANEL := Color(0.11, 0.105, 0.14, 0.98)
const BG_CARD := Color(0.075, 0.07, 0.10, 1.0)
const BG_INPUT := Color(0.16, 0.155, 0.20, 1.0)
const GOLD := Color(0.93, 0.78, 0.38, 1.0)
const GOLD_DIM := Color(0.62, 0.52, 0.26, 1.0)
const TEXT_MAIN := Color(0.94, 0.93, 0.90, 1.0)
const TEXT_DIM := Color(0.68, 0.67, 0.70, 1.0)
const TEXT_FAINT := Color(0.50, 0.49, 0.52, 1.0)
const GREEN := Color(0.30, 0.68, 0.36, 1.0)
const GREEN_DARK := Color(0.19, 0.48, 0.25, 1.0)
const RED := Color(0.78, 0.30, 0.28, 1.0)
const BLUE := Color(0.28, 0.44, 0.68, 1.0)

const PAD_XS := 4
const PAD_S := 8
const PAD_M := 12
const PAD_L := 16
const PAD_XL := 24
const RADIUS_S := 6
const RADIUS_M := 10
const RADIUS_L := 14
const TOUCH_MIN := 44
const FONT_S := 13
const FONT_M := 15
const FONT_L := 18
const FONT_XL := 22

static func panel_style(bg: Color = BG_PANEL, radius: int = RADIUS_L, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = PAD_M
	sb.content_margin_right = PAD_M
	sb.content_margin_top = PAD_M
	sb.content_margin_bottom = PAD_M
	if border_w > 0:
		sb.border_color = border
		sb.border_width_left = border_w
		sb.border_width_right = border_w
		sb.border_width_top = border_w
		sb.border_width_bottom = border_w
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	return sb

static func button_style(kind: String, state: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var r := RADIUS_M
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.content_margin_left = PAD_M
	sb.content_margin_right = PAD_M
	sb.content_margin_top = PAD_S
	sb.content_margin_bottom = PAD_S
	var base := BLUE
	match kind:
		"primary":
			base = GREEN_DARK
		"danger":
			base = RED
		"ghost":
			base = Color(0.20, 0.19, 0.24, 1.0)
		"gold":
			base = Color(0.45, 0.36, 0.16, 1.0)
		_:
			base = BLUE
	match state:
		"normal":
			sb.bg_color = base
			sb.border_color = GOLD_DIM
			sb.border_width_bottom = 2
		"hover":
			sb.bg_color = base.lightened(0.14)
			sb.border_color = GOLD_DIM
			sb.border_width_bottom = 2
		"pressed":
			sb.bg_color = base.darkened(0.22)
		"focus":
			sb.bg_color = base
			sb.border_color = GOLD
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_top = 2
			sb.border_width_bottom = 2
		"disabled":
			sb.bg_color = Color(0.22, 0.22, 0.24, 1.0)
	return sb

static func make_button(text: String, kind: String = "default", min_size: Vector2 = Vector2(96, TOUCH_MIN), font_size: int = FONT_M) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 0.9))
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	b.add_theme_color_override("font_focus_color", TEXT_MAIN)
	b.add_theme_stylebox_override("normal", button_style(kind, "normal"))
	b.add_theme_stylebox_override("hover", button_style(kind, "hover"))
	b.add_theme_stylebox_override("pressed", button_style(kind, "pressed"))
	b.add_theme_stylebox_override("focus", button_style(kind, "focus"))
	b.add_theme_stylebox_override("disabled", button_style(kind, "disabled"))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func make_label(text: String, size: int = FONT_M, color: Color = TEXT_MAIN, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

static func make_title(text: String, size: int = FONT_XL) -> Label:
	var l := make_label(text, size, Color(1.0, 0.96, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

static func make_card(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(BG_CARD, RADIUS_M, Color(0.30, 0.28, 0.22, 0.6), 1))
	if min_size != Vector2.ZERO:
		p.custom_minimum_size = min_size
	return p

static func make_input(min_size: Vector2 = Vector2(0, TOUCH_MIN), font_size: int = FONT_M) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = min_size
	e.add_theme_font_size_override("font_size", font_size)
	e.add_theme_color_override("font_color", TEXT_MAIN)
	e.add_theme_color_override("font_placeholder_color", TEXT_FAINT)
	e.add_theme_stylebox_override("normal", panel_style(BG_INPUT, RADIUS_S))
	e.add_theme_stylebox_override("focus", panel_style(BG_INPUT, RADIUS_S, GOLD, 2))
	e.add_theme_stylebox_override("read_only", panel_style(BG_INPUT, RADIUS_S))
	return e

static func make_option(items: PackedStringArray, selected: int = 0, min_size: Vector2 = Vector2(170, TOUCH_MIN)) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = min_size
	o.add_theme_font_size_override("font_size", FONT_M)
	o.add_theme_color_override("font_color", TEXT_MAIN)
	for it in items:
		o.add_item(it)
	o.selected = selected
	o.add_theme_stylebox_override("normal", button_style("ghost", "normal"))
	o.add_theme_stylebox_override("hover", button_style("ghost", "hover"))
	o.add_theme_stylebox_override("pressed", button_style("ghost", "pressed"))
	o.add_theme_stylebox_override("focus", button_style("ghost", "focus"))
	return o

static func vbox(separation: int = PAD_S) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v

static func hbox(separation: int = PAD_S) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h

static func margins(left: int = PAD_M, top: int = PAD_M, right: int = PAD_M, bottom: int = PAD_M) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m

static func press_feedback(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	if btn.has_meta("_press_fb"):
		return
	btn.set_meta("_press_fb", true)
	btn.resized.connect(func() -> void:
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size * 0.5
	)
	btn.pivot_offset = btn.size * 0.5
