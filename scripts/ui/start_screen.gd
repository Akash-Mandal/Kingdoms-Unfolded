extends CanvasLayer

signal start_requested(cfg: Dictionary)
signal continue_requested

var _step := 0
const STEP_TITLES: PackedStringArray = ["World", "Kingdom", "Ruler", "Starting"]

var _seed_edit: LineEdit
var _era_btn: OptionButton
var _diff_btn: OptionButton
var _kingdom_name: LineEdit
var _banner_btn: ColorPickerButton
var _sigil_btn: OptionButton
var _gov_btn: OptionButton
var _religion_btn: OptionButton
var _culture_btn: OptionButton
var _ruler_name: LineEdit
var _ruler_age: SpinBox
var _ruler_gender: OptionButton
var _legacy_btn: OptionButton
var _trait_checks: Array[CheckBox] = []
var _trait_vals: PackedStringArray = []
var _territory_btn: OptionButton
var _rivals_spin: SpinBox
var _scenario_btn: OptionButton
var _season_btn: OptionButton
var _res_sliders: Dictionary = {}
var _res_labels: Dictionary = {}

var _panels: Array[Control] = []
var _step_dots: Array[Label] = []
var _back_btn: Button
var _next_btn: Button
var _apply_btn: Button
var _title_lbl: Label

const TRAITS_24: PackedStringArray = [
	"Brave","Wise","Just","Merciful","Wrathful","Cunning",
	"Charismatic","Pious","Stubborn","Generous","Greedy","Loyal",
	"Ambitious","Humble","Diligent","Slothful","Honest","Deceitful",
	"Valiant","Craven","Temperate","Proud","Patient","Zealous"
]

const RES_KEYS_8: PackedStringArray = ["food","gold","wood","stone","iron","cloth","horses","knowledge"]
const SIGILS: PackedStringArray = ["Eagle","Lion","Dragon","Wolf","Bear","Stag","Raven","Sun"]
const GOVS: PackedStringArray = ["Feudal","Tribal","Theocratic","Republic","Autocracy","Oligarchy"]
const RELIGIONS: PackedStringArray = ["Old Gods","One Faith","Ancestors","Nature","None"]
const CULTURES: PackedStringArray = ["Highland","Lowland","Desert","Northern","Riverfolk","Imperial"]
const ERAS: PackedStringArray = ["Ancient","Medieval","Renaissance","Custom"]
const DIFFS: PackedStringArray = ["Peaceful","Iron","Chaos","Legendary"]
const GENDERS: PackedStringArray = ["Male","Female","Other"]
const LEGACIES: PackedStringArray = ["Conqueror","Builder","Sage","Diplomat","Explorer","Guardian"]
const TERRITORIES: PackedStringArray = ["Small","Medium","Large","Huge"]
const SCENARIOS: PackedStringArray = ["Default","Fertile Lands","Harsh Winter","Raiders Nearby","Rich Veins","Isolated"]
const SEASONS: PackedStringArray = ["Spring","Summer","Autumn","Winter"]
const SEASON_MONTH := {"spring": 3, "summer": 6, "autumn": 9, "winter": 12}

func _ready() -> void:
	layer = 100
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.05, 0.075, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 500)
	var ps := UITheme.panel_style(UITheme.BG_PANEL, UITheme.RADIUS_L, Color(0.38, 0.32, 0.20, 0.8), 1)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)
	var margin := UITheme.margins(16, 14, 16, 14)
	panel.add_child(margin)
	var vbox := UITheme.vbox(10)
	margin.add_child(vbox)
	_title_lbl = UITheme.make_title("New Kingdom — Step 1/4: World", 22)
	vbox.add_child(_title_lbl)
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	vbox.add_child(dots)
	for i in 4:
		var d := Label.new()
		d.text = "●" if i == 0 else "○"
		d.add_theme_font_size_override("font_size", 18)
		d.add_theme_color_override("font_color", UITheme.GOLD if i == 0 else UITheme.TEXT_FAINT)
		dots.add_child(d)
		_step_dots.append(d)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var content := PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(820, 340)
	var cs := UITheme.panel_style(UITheme.BG_CARD, UITheme.RADIUS_M, Color(0.30, 0.28, 0.22, 0.5), 1)
	content.add_theme_stylebox_override("panel", cs)
	vbox.add_child(content)
	var s1 := _build_step1()
	var s2 := _build_step2()
	var s3 := _build_step3()
	var s4 := _build_step4()
	for p in [s1, s2, s3, s4]:
		content.add_child(p)
		_panels.append(p)
		p.visible = false
	_panels[0].visible = true
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_SPACE_BETWEEN
	nav.add_theme_constant_override("separation", 8)
	vbox.add_child(nav)
	_back_btn = _btn("← Back", func() -> void: _go(-1), "ghost")
	_back_btn.custom_minimum_size = Vector2(120, 48)
	_back_btn.disabled = true
	nav.add_child(_back_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	if FileAccess.file_exists("user://saves/slot_0.json"):
		var cont := _btn("Continue", func() -> void: continue_requested.emit(), "gold")
		cont.custom_minimum_size = Vector2(130, 48)
		nav.add_child(cont)
	_next_btn = _btn("Next →", func() -> void: _go(1))
	_next_btn.custom_minimum_size = Vector2(130, 48)
	nav.add_child(_next_btn)
	_apply_btn = _btn("Apply & Begin", func() -> void: _apply(), "primary")
	_apply_btn.custom_minimum_size = Vector2(170, 48)
	_apply_btn.visible = false
	nav.add_child(_apply_btn)

func _btn(text: String, cb: Callable, kind: String = "default") -> Button:
	var b := UITheme.make_button(text, kind, Vector2(96, UITheme.TOUCH_MIN), 16)
	b.pressed.connect(cb)
	UITheme.press_feedback(b)
	return b

func _opt(items: PackedStringArray, selected: int = 0) -> OptionButton:
	return UITheme.make_option(items, selected)

func _label(t: String, sz: int = 14) -> Label:
	return UITheme.make_label(t, sz, UITheme.TEXT_MAIN)

func _field_row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_FILL
	var lab := _label(label_text, 15)
	lab.custom_minimum_size = Vector2(140, 44)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lab)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)

func _build_step1() -> Control:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	v.add_child(seed_row)
	var lab := _label("World Seed", 15)
	lab.custom_minimum_size = Vector2(140, 44)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_row.add_child(lab)
	_seed_edit = UITheme.make_input(Vector2(200, 44), 15)
	_seed_edit.placeholder_text = "e.g. 12345 or myworld"
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_seed_edit.text = str(rng.randi_range(1, 999999))
	seed_row.add_child(_seed_edit)
	var rnd := _btn("Random", func() -> void:
		var r := RandomNumberGenerator.new()
		r.randomize()
		_seed_edit.text = str(r.randi_range(1, 999999))
	)
	rnd.custom_minimum_size = Vector2(100, 44)
	seed_row.add_child(rnd)
	_era_btn = _opt(ERAS, 1)
	_field_row(v, "Era", _era_btn)
	_diff_btn = _opt(DIFFS, 0)
	_field_row(v, "Difficulty", _diff_btn)
	var hint := _label("Seed determines terrain. Era & Difficulty affect future events.", 12)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(hint)
	return sc

func _build_step2() -> Control:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	_kingdom_name = UITheme.make_input(Vector2(0, 44), 15)
	_kingdom_name.placeholder_text = "Kingdom name"
	_kingdom_name.text = "Eterna"
	_field_row(v, "Kingdom Name", _kingdom_name)
	var banner_row := HBoxContainer.new()
	banner_row.add_theme_constant_override("separation", 8)
	v.add_child(banner_row)
	var bl := _label("Banner Color", 15)
	bl.custom_minimum_size = Vector2(140, 44)
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_row.add_child(bl)
	_banner_btn = ColorPickerButton.new()
	_banner_btn.custom_minimum_size = Vector2(120, 44)
	_banner_btn.color = Color(0.29, 0.43, 0.65)
	_banner_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_row.add_child(_banner_btn)
	_sigil_btn = _opt(SIGILS, 0)
	_field_row(v, "Sigil", _sigil_btn)
	_gov_btn = _opt(GOVS, 0)
	_field_row(v, "Government", _gov_btn)
	_religion_btn = _opt(RELIGIONS, 0)
	_field_row(v, "Religion", _religion_btn)
	_culture_btn = _opt(CULTURES, 0)
	_field_row(v, "Culture", _culture_btn)
	return sc

func _build_step3() -> Control:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	_ruler_name = UITheme.make_input(Vector2(0, 44), 15)
	_ruler_name.placeholder_text = "Ruler name"
	_ruler_name.text = "Aurelia"
	_field_row(v, "Ruler Name", _ruler_name)
	_ruler_age = SpinBox.new()
	_ruler_age.min_value = 16
	_ruler_age.max_value = 80
	_ruler_age.step = 1
	_ruler_age.value = 28
	_ruler_age.custom_minimum_size = Vector2(0, 44)
	_field_row(v, "Age", _ruler_age)
	_ruler_gender = _opt(GENDERS, 0)
	_field_row(v, "Gender", _ruler_gender)
	_legacy_btn = _opt(LEGACIES, 0)
	_field_row(v, "Legacy Path", _legacy_btn)
	var tl := _label("Traits (pick up to 3):", 15)
	v.add_child(tl)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for t in TRAITS_24:
		var cb := CheckBox.new()
		cb.text = t
		cb.custom_minimum_size = Vector2(0, 44)
		cb.add_theme_font_size_override("font_size", 14)
		var cbt: CheckBox = cb
		cb.toggled.connect(func(pressed: bool) -> void: _on_trait_toggle(cbt, pressed))
		grid.add_child(cb)
		_trait_checks.append(cb)
		_trait_vals.append(t)
	return sc

func _on_trait_toggle(cb: CheckBox, pressed: bool) -> void:
	var count := 0
	for c in _trait_checks:
		if c.button_pressed:
			count += 1
	if count > 3:
		cb.button_pressed = false

func _build_step4() -> Control:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	_territory_btn = _opt(TERRITORIES, 1)
	_field_row(v, "Territory Size", _territory_btn)
	_rivals_spin = SpinBox.new()
	_rivals_spin.min_value = 2
	_rivals_spin.max_value = 5
	_rivals_spin.step = 1
	_rivals_spin.value = 3
	_rivals_spin.custom_minimum_size = Vector2(0, 44)
	_field_row(v, "Rivals (2-5)", _rivals_spin)
	_scenario_btn = _opt(SCENARIOS, 0)
	_field_row(v, "Scenario", _scenario_btn)
	_season_btn = _opt(SEASONS, 0)
	_field_row(v, "Start Season", _season_btn)
	var res_title := _label("Starting Resources (0-200):", 15)
	v.add_child(res_title)
	for key in RES_KEYS_8:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var lab := _label(key.capitalize(), 14)
		lab.custom_minimum_size = Vector2(110, 44)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lab)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 200
		slider.step = 1
		slider.value = 100
		slider.custom_minimum_size = Vector2(140, 44)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var val := _label("100", 14)
		val.custom_minimum_size = Vector2(40, 44)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(val)
		var captured_val: Label = val
		slider.value_changed.connect(func(v2: float) -> void: captured_val.text = str(int(v2)))
		val.text = str(int(slider.value))
		_res_sliders[key] = slider
		_res_labels[key] = val
	return sc

func _go(dir: int) -> void:
	var nxt := clampi(_step + dir, 0, 3)
	if nxt == _step:
		return
	_panels[_step].visible = false
	_step = nxt
	_panels[_step].visible = true
	_refresh_nav()

func _refresh_nav() -> void:
	_title_lbl.text = "New Kingdom — Step %d/4: %s" % [_step + 1, STEP_TITLES[_step]]
	for i in _step_dots.size():
		_step_dots[i].text = "●" if i == _step else "○"
		_step_dots[i].add_theme_color_override("font_color", UITheme.GOLD if i == _step else UITheme.TEXT_FAINT)
	_back_btn.disabled = _step == 0
	_next_btn.visible = _step < 3
	_apply_btn.visible = _step == 3

func _apply() -> void:
	var cfg := _collect()
	start_requested.emit(cfg)

func _collect() -> Dictionary:
	var seed_text: String = _seed_edit.text.strip_edges()
	var seed_val: int = 0
	if seed_text.is_valid_int():
		seed_val = int(seed_text)
	else:
		seed_val = int(abs(hash(seed_text)) % 999999) + 1
		if seed_val == 0:
			seed_val = 1
	var traits: PackedStringArray = []
	for i in _trait_checks.size():
		if _trait_checks[i].button_pressed:
			traits.append(_trait_vals[i])
	var res: Dictionary = {}
	for k in RES_KEYS_8:
		var s: HSlider = _res_sliders[k]
		res[k] = int(s.value) if s != null else 100
	return {
		"world_seed": seed_val,
		"era": ERAS[_era_btn.selected].to_lower(),
		"difficulty": DIFFS[_diff_btn.selected].to_lower(),
		"kingdom_name": _kingdom_name.text.strip_edges(),
		"banner_color": _banner_btn.color.to_html(false),
		"sigil": SIGILS[_sigil_btn.selected].to_lower(),
		"gov": GOVS[_gov_btn.selected].to_lower(),
		"religion": RELIGIONS[_religion_btn.selected].to_lower(),
		"culture": CULTURES[_culture_btn.selected].to_lower(),
		"ruler_name": _ruler_name.text.strip_edges(),
		"ruler_age": int(_ruler_age.value),
		"ruler_gender": GENDERS[_ruler_gender.selected].to_lower(),
		"traits": traits,
		"legacy_path": LEGACIES[_legacy_btn.selected].to_lower(),
		"territory_size": TERRITORIES[_territory_btn.selected].to_lower(),
		"rivals": int(_rivals_spin.value),
		"scenario": SCENARIOS[_scenario_btn.selected].to_lower().replace(" ", "_"),
		"starting_season": SEASONS[_season_btn.selected].to_lower(),
		"resources": res,
	}
