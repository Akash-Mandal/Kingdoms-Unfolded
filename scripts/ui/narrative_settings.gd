extends CanvasLayer
var _provider_opt: OptionButton
var _key_input: LineEdit
var _model_opt: OptionButton
var _temp_slider: HSlider
var _temp_label: Label
var _base_url_input: LineEdit
var _status: Label
var _save_btn: Button
var _test_btn: Button
var _hooks_label: Label
var _current_provider: String = "local"
var _models: Dictionary = {
	"local": ["procedural"],
	"gemini": ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.5-pro"],
	"openai": ["gpt-4o-mini", "gpt-4o", "o3-mini", "custom"],
	"ollama": ["llama3.1", "mistral", "gemma2", "qwen2.5", "custom"],
}
func _ready() -> void:
	layer = 20
	_build_ui()
	_refresh_models()
	_load_state()
	_refresh_models()
	_on_temp_changed(_temp_slider.value)
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380.0
	panel.offset_right = 380.0
	panel.offset_top = -300.0
	panel.offset_bottom = 300.0
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.10, 0.10, 0.13, 0.97), 14))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "⚙️ Narrative Settings — AI Soul"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vbox.add_child(row1)
	var plab := Label.new()
	plab.text = "Provider"
	plab.custom_minimum_size = Vector2(90, 0)
	row1.add_child(plab)
	_provider_opt = OptionButton.new()
	_provider_opt.custom_minimum_size = Vector2(220, 36)
	for p in ["local", "gemini", "openai", "ollama"]:
		_provider_opt.add_item(p.capitalize())
	_provider_opt.item_selected.connect(_on_provider_picked)
	row1.add_child(_provider_opt)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(spacer)
	var close := UITheme.make_button("✕", "danger", Vector2(44, 44))
	close.pressed.connect(func() -> void: visible = false)
	row1.add_child(close)
	var row2 := HBoxContainer.new()
	vbox.add_child(row2)
	var klab := Label.new()
	klab.text = "API Key"
	klab.custom_minimum_size = Vector2(90, 0)
	row2.add_child(klab)
	_key_input = LineEdit.new()
	_key_input.custom_minimum_size = Vector2(0, 44)
	_key_input.placeholder_text = "sk-… (encrypted via OS keystore stub)"
	_key_input.secret = true
	_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_key_input)
	var reveal := UITheme.make_button("👁", "ghost", Vector2(44, 44))
	reveal.pressed.connect(func() -> void: _key_input.secret = not _key_input.secret)
	row2.add_child(reveal)
	var row3 := HBoxContainer.new()
	vbox.add_child(row3)
	var mlab := Label.new()
	mlab.text = "Model"
	mlab.custom_minimum_size = Vector2(90, 0)
	row3.add_child(mlab)
	_model_opt = OptionButton.new()
	_model_opt.custom_minimum_size = Vector2(260, 36)
	row3.add_child(_model_opt)
	_model_opt.item_selected.connect(_on_model_picked)
	var row4 := HBoxContainer.new()
	vbox.add_child(row4)
	var blab := Label.new()
	blab.text = "Base URL"
	blab.custom_minimum_size = Vector2(90, 0)
	row4.add_child(blab)
	_base_url_input = LineEdit.new()
	_base_url_input.custom_minimum_size = Vector2(0, 44)
	_base_url_input.placeholder_text = "OpenAI-compat / Ollama URL (leave blank for default)"
	_base_url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row4.add_child(_base_url_input)
	var row5 := HBoxContainer.new()
	row5.add_theme_constant_override("separation", 8)
	vbox.add_child(row5)
	var tlab := Label.new()
	tlab.text = "Creativity"
	tlab.custom_minimum_size = Vector2(90, 0)
	row5.add_child(tlab)
	_temp_slider = HSlider.new()
	_temp_slider.min_value = 0.0
	_temp_slider.max_value = 1.5
	_temp_slider.step = 0.05
	_temp_slider.value = 0.8
	_temp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_temp_slider.value_changed.connect(_on_temp_changed)
	row5.add_child(_temp_slider)
	_temp_label = Label.new()
	_temp_label.text = "0.80"
	_temp_label.custom_minimum_size = Vector2(44, 0)
	row5.add_child(_temp_label)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)
	_hooks_label = Label.new()
	_hooks_label.add_theme_font_size_override("font_size", 12)
	_hooks_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	_hooks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hooks_label)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	_test_btn = UITheme.make_button("Test Connection", "primary", Vector2(150, 48))
	_test_btn.pressed.connect(_on_test)
	btn_row.add_child(_test_btn)
	_save_btn = UITheme.make_button("Save", "primary", Vector2(100, 48))
	_save_btn.pressed.connect(_on_save)
	btn_row.add_child(_save_btn)
	var hint := Label.new()
	hint.text = "Keys encrypted on-device, never in saves or git. Offline prose always works."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)
func _on_provider_picked(idx: int) -> void:
	_current_provider = str(_provider_opt.get_item_text(idx)).to_lower()
	_refresh_models()
	_load_key_for_provider()
	_update_status()
func _refresh_models() -> void:
	if _model_opt == null:
		return
	_model_opt.clear()
	var list: Array = _models.get(_current_provider, ["default"]) as Array
	for m in list:
		_model_opt.add_item(str(m))
	var vault: Node = get_node_or_null("/root/KeyVault")
	if vault != null and vault.has_method("load_config"):
		var cfg: Dictionary = vault.call("load_config", _current_provider) as Dictionary
		var cur_model: String = str(cfg.get("model", ""))
		if cur_model != "":
			var found: int = -1
			for i in _model_opt.item_count:
				if _model_opt.get_item_text(i) == cur_model:
					found = i
					break
			if found >= 0:
				_model_opt.select(found)
				return
	_model_opt.select(0)
func _on_model_picked(_idx: int) -> void:
	_update_status()
func _on_temp_changed(v: float) -> void:
	if _temp_label != null:
		_temp_label.text = "%.2f" % clampf(v,0.0,1.5)
func _load_state() -> void:
	var vault: Node = get_node_or_null("/root/KeyVault")
	var np: Node = get_node_or_null("/root/NarrativeProvider")
	var prov := "local"
	var temp := 0.8
	if FileAccess.file_exists("user://settings/narrative.json"):
		var f := FileAccess.open("user://settings/narrative.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				prov = str((parsed as Dictionary).get("provider", "local")).to_lower()
				temp = float((parsed as Dictionary).get("temperature", 0.8))
	elif np != null and "provider" in np:
		prov = str(np.get("provider")).to_lower()
	_current_provider = prov
	var found_prov := false
	for i in _provider_opt.item_count:
		if _provider_opt.get_item_text(i).to_lower() == prov:
			_provider_opt.select(i)
			found_prov = true
			break
	if not found_prov and _provider_opt.item_count>0:
		_provider_opt.select(0)
	_temp_slider.value = clampf(temp,0.0,1.5)
	_on_temp_changed(_temp_slider.value)
	_load_key_for_provider()
	_load_urls()
	_update_status()
func _load_key_for_provider() -> void:
	var vault: Node = get_node_or_null("/root/KeyVault")
	if vault == null or _key_input == null:
		return
	var k: String = str(vault.call("load_key", _current_provider)) if vault.has_method("load_key") else ""
	if k != "":
		_key_input.placeholder_text = "•".repeat(mini(12, k.length())) + " (saved, encrypted)"
		_key_input.text = ""
	else:
		_key_input.placeholder_text = "sk-… (encrypted via OS keystore stub)"
		_key_input.text = ""
func _load_urls() -> void:
	var vault: Node = get_node_or_null("/root/KeyVault")
	if vault == null:
		return
	var cfg: Dictionary = vault.call("load_config", _current_provider) as Dictionary if vault.has_method("load_config") else {}
	if cfg.has("base_url"):
		_base_url_input.text = str(cfg["base_url"])
	if cfg.has("temperature"):
		var tv := clampf(float(cfg["temperature"]),0.0,1.5)
		_temp_slider.value = tv
		_on_temp_changed(tv)
func _update_status() -> void:
	var vault: Node = get_node_or_null("/root/KeyVault")
	var has_key: bool = false
	if vault != null and vault.has_method("has_key"):
		has_key = bool(vault.call("has_key", _current_provider))
	var model_txt: String = _model_opt.get_item_text(_model_opt.get_selected_id()) if _model_opt.get_selected_id() >= 0 else ""
	if _current_provider == "local":
		_status.text = "LocalEngine — always works offline. No key needed."
	elif has_key:
		_status.text = "✓ Key stored (encrypted) for %s — model %s" % [_current_provider, model_txt]
	else:
		_status.text = "No key for %s — will fallback to LocalEngine until saved." % _current_provider
	var chron: Node = get_node_or_null("/root/Chronicle")
	if chron != null and chron.has_method("history"):
		var hist: Array = chron.call("history", 3) as Array
		if not hist.is_empty():
			_hooks_label.text = "Recent: %s" % str(hist.back().get("text", "")).substr(0, 120)
func _on_save() -> void:
	var vault: Node = get_node_or_null("/root/KeyVault")
	var np: Node = get_node_or_null("/root/NarrativeProvider")
	var key_txt: String = _key_input.text.strip_edges()
	if vault != null and key_txt != "" and vault.has_method("store"):
		vault.call("store", _current_provider, key_txt)
		_key_input.text = ""
		_key_input.placeholder_text = "•".repeat(12) + " (saved, encrypted)"
	var model_txt: String = _model_opt.get_item_text(_model_opt.get_selected_id()) if _model_opt.get_selected_id() >= 0 else ""
	var base_url: String = _base_url_input.text.strip_edges()
	var temp: float = _temp_slider.value
	if vault != null and vault.has_method("store_config"):
		vault.call("store_config", _current_provider, model_txt, temp, base_url)
	if np != null:
		if np.has_method("set_provider"):
			np.call("set_provider", _current_provider)
		if "temperature" in np:
			np.set("temperature", temp)
		if "provider" in np:
			np.set("provider", _current_provider)
		var adapters: Dictionary = np.get("model_overrides") as Dictionary if "model_overrides" in np else {}
		adapters[_current_provider] = model_txt
		if "model_overrides" in np:
			np.set("model_overrides", adapters)
		if np.has_method("save_settings"):
			np.call("save_settings")
		var ad: Node = np.get_node_or_null(_current_provider.capitalize()) if np.has_node(_current_provider.capitalize()) else null
		if ad == null:
			ad = np.get_node_or_null("Gemini") if _current_provider == "gemini" else (np.get_node_or_null("OpenAI") if _current_provider == "openai" else np.get_node_or_null("Ollama"))
		if ad != null:
			if "model" in ad:
				ad.set("model", model_txt)
			if "temperature" in ad:
				ad.set("temperature", temp)
			if "base_url" in ad and base_url != "":
				ad.set("base_url", base_url)
	_update_status()
	_status.text += " — Saved."
func _on_test() -> void:
	_on_save()
	_status.text = "Testing %s…" % _current_provider
	var np: Node = get_node_or_null("/root/NarrativeProvider")
	if np == null or not np.has_method("generate"):
		_status.text = "Provider not ready."
		return
	var test_event: Dictionary = {"id": "test", "type": "test", "category": "random", "severity": 1, "text": "Test connection — the court sends a raven.", "name": "Test Dispatch", "choices": [{"id": "ok", "label": "Acknowledge", "hint": "", "effects": {}}]}
	var result: Variant = await np.call("generate", test_event)
	if typeof(result) == TYPE_DICTIONARY:
		var d: Dictionary = result as Dictionary
		_status.text = "✓ %s: %s" % [str(d.get("provider", "local")), str(d.get("text", "")).substr(0, 140)]
		if d.get("cached", false):
			_status.text += " (cached)"
	else:
		_status.text = "Test failed — fallback engaged."
func open() -> void:
	visible = true
	_load_state()
