extends Node3D

var _camera
var _sun: DirectionalLight3D
var _hemi: DirectionalLight3D
var _env: Environment
var _terrain
var _rig: Node
var _build_mgr: Node3D
var _weather: Node
var _npc_mgr: Node3D
var _battle_scene: Node3D
var _has_built_world := false
var _start_screen: CanvasLayer
var _debug_overlay: CanvasLayer
var _tutorial: CanvasLayer
var _save_slots: Node
var _accessibility: Node

func _ready() -> void:
	_show_loading_cover()
	await get_tree().process_frame
	if Catalog != null and Catalog.get("buildings") is Dictionary and (Catalog.get("buildings") as Dictionary).is_empty():
		await get_tree().process_frame
	if _try_load_existing():
		_build_all()
		_hide_loading_cover()
		return
	_build_minimal()
	call_deferred("_show_start_screen")

var _loading_cover: CanvasLayer = null
func _show_loading_cover() -> void:
	if _loading_cover != null and is_instance_valid(_loading_cover):
		return
	var cover := CanvasLayer.new()
	cover.name = "LoadingCover"
	cover.layer = 99
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.05, 0.075, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	var title := Label.new()
	title.text = "Kingdoms Unfolded"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "Raising the realm…"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.68, 0.67, 0.70))
	vbox.add_child(sub)
	add_child(cover)
	_loading_cover = cover

func _hide_loading_cover() -> void:
	if _loading_cover != null and is_instance_valid(_loading_cover):
		_loading_cover.queue_free()
		_loading_cover = null

func _show_fatal_error(msg: String) -> void:
	_hide_loading_cover()
	var cover := CanvasLayer.new()
	cover.name = "FatalError"
	cover.layer = 200
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.05, 0.075, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var lbl := Label.new()
	lbl.text = "Something went wrong starting the game.\n%s\n\nRestart the app. Your saves are kept." % msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(560, 0)
	lbl.add_theme_font_size_override("font_size", 16)
	center.add_child(lbl)

func _try_load_existing() -> bool:
	if not FileAccess.file_exists("user://saves/slot_0.json"):
		return false
	if Game.load_from_file():
		return true
	return false

func _build_minimal() -> void:
	_build_environment()
	_build_sun()
	_build_camera()

func _build_all() -> void:
	if _env == null:
		_build_environment()
	if _sun == null:
		_build_sun()
	if _camera == null:
		_build_camera()
	if not _has_built_world:
		_build_terrain()
		_build_rig()
		_build_weather()
		_build_buildings()
		_build_npcs()
		_build_military()
		_has_built_world = true
	if get_node_or_null("HUD") == null:
		_build_hud()
	if get_node_or_null("DiplomacyPanel") == null:
		_build_diplomacy_panel()
	if get_node_or_null("DebugOverlay") == null:
		_build_debug_overlay()
	if get_node_or_null("Tutorial") == null:
		_build_tutorial()
	if get_node_or_null("SaveSlots") == null:
		_build_save_slots()
	if get_node_or_null("Accessibility") == null:
		_build_accessibility()
	if get_node_or_null("NarrativeSettings") == null:
		_build_narrative_settings()
	if get_node_or_null("GraphicsSettings") == null:
		_build_graphics_settings()

func _build_graphics_settings() -> void:
	var pnl := CanvasLayer.new()
	pnl.name = "GraphicsSettings"
	pnl.layer = 26
	pnl.set_script(load("res://scripts/ui/graphics_settings.gd"))
	add_child(pnl)
	pnl.visible = false
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs != null and gs.has_signal("graphics_changed"):
		if not gs.graphics_changed.is_connected(_on_graphics_changed):
			gs.graphics_changed.connect(_on_graphics_changed)
	_apply_graphics_to_world()

func _on_graphics_changed(_preset: String, cfg: Dictionary) -> void:
	_apply_graphics_to_world_cfg(cfg)

func _apply_graphics_to_world() -> void:
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs == null or not gs.has_method("get_config"):
		return
	_apply_graphics_to_world_cfg(gs.call("get_config") as Dictionary)

func _apply_graphics_to_world_cfg(cfg: Dictionary) -> void:
	if _rig != null and _rig.has_method("apply_graphics"):
		_rig.call("apply_graphics", cfg)
	if _terrain != null and _terrain.has_method("apply_graphics"):
		_terrain.call("apply_graphics", cfg)
	if _npc_mgr != null and _npc_mgr.has_method("apply_graphics"):
		_npc_mgr.call("apply_graphics", cfg)
	if _camera != null and (_camera as Object).has_method("apply_graphics"):
		(_camera as Object).call("apply_graphics", cfg)

func _show_start_screen() -> void:
	if _start_screen != null and is_instance_valid(_start_screen):
		_hide_loading_cover()
		return
	var start_script: Script = load("res://scripts/ui/start_screen.gd") as Script
	if start_script == null:
		_show_fatal_error("Start screen script failed to load.")
		return
	var screen: CanvasLayer = start_script.new() as CanvasLayer
	if screen == null:
		_show_fatal_error("Start screen failed to initialize.")
		return
	screen.name = "StartScreen"
	screen.layer = 100
	add_child(screen)
	_start_screen = screen
	_hide_loading_cover()
	if not screen.start_requested.is_connected(_on_start_requested):
		screen.start_requested.connect(_on_start_requested)
	if not screen.continue_requested.is_connected(_on_continue_requested):
		screen.continue_requested.connect(_on_continue_requested)

func _on_start_requested(cfg: Dictionary) -> void:
	Game.apply_start_config(cfg)
	_build_all()
	if _start_screen != null:
		_start_screen.queue_free()
		_start_screen = null
	call_deferred("_save_early")

func _on_continue_requested() -> void:
	if _has_built_world:
		if _start_screen != null:
			_start_screen.queue_free()
			_start_screen = null
		return
	if Game.load_from_file():
		_build_all()
	if _start_screen != null:
		_start_screen.queue_free()
		_start_screen = null

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 1.0
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.78, 0.82, 0.86)
	_env.fog_density = 0.0004
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.15
	var wenv := WorldEnvironment.new()
	wenv.environment = _env
	add_child(wenv)

func _build_sun() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(_sun)
	_hemi = DirectionalLight3D.new()
	_hemi.name = "SkyFill"
	_hemi.light_color = Color(0.6, 0.7, 0.9)
	_hemi.light_energy = 0.25
	_hemi.rotation_degrees = Vector3(80, -40, 0)
	add_child(_hemi)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "MainCamera"
	cam.far = 600.0
	cam.near = 0.1
	cam.fov = 55.0
	cam.set_script(load("res://scripts/world/camera_controller.gd"))
	add_child(cam)
	cam.make_current()
	_camera = cam
	_camera.target = Vector3(0, 0, 0)

func _build_terrain() -> void:
	if _terrain != null and is_instance_valid(_terrain):
		return
	var terrain = load("res://scripts/world/terrain.gd").new()
	terrain.name = "TerrainSource"
	terrain.world_seed = Game.settings.world_seed
	add_child(terrain)
	_terrain = terrain
	await get_tree().process_frame

func _build_rig() -> void:
	var rig = load("res://scripts/world/environment_rig.gd").new()
	rig.name = "EnvironmentRig"
	add_child(rig)
	_rig = rig
	var mat: ShaderMaterial = null
	if _terrain != null and "terrain_material" in _terrain:
		mat = _terrain.terrain_material
	rig.setup(_sun, _hemi, _env, mat)

var _weather_tween: Tween = null
func _build_weather() -> void:
	var w = load("res://scripts/world/weather.gd").new()
	w.name = "Weather"
	add_child(w)
	_weather = w
	if _env != null:
		w.weather_changed.connect(func(state: String) -> void:
			var target := 0.00030
			if state == "fog": target = 0.00065
			elif state == "rain" or state == "snow": target = 0.00045
			if _weather_tween != null and _weather_tween.is_valid(): _weather_tween.kill()
			_weather_tween = create_tween()
			_weather_tween.tween_property(_env, "fog_density", target, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		)

func _build_buildings() -> void:
	if get_node_or_null("BuildingManager") != null:
		_build_mgr = get_node("BuildingManager")
		return
	var mgr = load("res://scripts/world/building_manager.gd").new()
	mgr.name = "BuildingManager"
	add_child(mgr)
	_build_mgr = mgr
	if _terrain != null and not _terrain.is_inside_tree():
		await _terrain.ready
	mgr.setup(_terrain, _camera as Camera3D)

func _build_npcs() -> void:
	if get_node_or_null("AgentManager") != null:
		_npc_mgr = get_node("AgentManager")
		return
	var mgr = load("res://scripts/npc/agent_manager.gd").new()
	mgr.name = "AgentManager"
	add_child(mgr)
	_npc_mgr = mgr
	if _terrain != null and not _terrain.is_inside_tree():
		await _terrain.ready
	mgr.setup(_terrain, _camera as Camera3D)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	hud.set_script(load("res://scripts/ui/hud.gd"))
	add_child(hud)
	hud.set_meta("build_mgr", _build_mgr)

func _build_diplomacy_panel() -> void:
	var pnl := CanvasLayer.new()
	pnl.name = "DiplomacyPanel"
	pnl.layer = 15
	pnl.set_script(load("res://scripts/ui/diplomacy_panel.gd"))
	add_child(pnl)

func _build_narrative_settings() -> void:
	var pnl := CanvasLayer.new()
	pnl.name = "NarrativeSettings"
	pnl.layer = 25
	pnl.set_script(load("res://scripts/ui/narrative_settings.gd"))
	add_child(pnl)
	pnl.visible = false

func _build_military() -> void:
	if Military != null and Military.has_method("ensure_unit"):
		Game.military = Military.units.duplicate(true) if not Game.military.is_empty() else Military.units.duplicate(true)
		if Game.military.is_empty():
			Game._init_military_defaults()
			Military.restore(Game.military)
		else:
			Military.restore(Game.military)
	if has_node("HUD") and get_node("HUD").has_method("trigger_test_battle"):
		pass

func _build_debug_overlay() -> void:
	var dbg := CanvasLayer.new()
	dbg.name = "DebugOverlay"
	dbg.layer = 90
	dbg.set_script(load("res://scripts/ui/debug_overlay.gd"))
	add_child(dbg)
	_debug_overlay = dbg

func _build_tutorial() -> void:
	var tut := CanvasLayer.new()
	tut.name = "Tutorial"
	tut.layer = 85
	tut.set_script(load("res://scripts/ui/tutorial.gd"))
	add_child(tut)
	_tutorial = tut

func _build_save_slots() -> void:
	var ss := Node.new()
	ss.name = "SaveSlots"
	ss.set_script(load("res://scripts/core/save_slots.gd"))
	add_child(ss)
	_save_slots = ss

func _build_accessibility() -> void:
	var ac := Node.new()
	ac.name = "Accessibility"
	ac.set_script(load("res://scripts/core/accessibility.gd"))
	add_child(ac)
	_accessibility = ac

func trigger_test_battle() -> void:
	if _battle_scene != null and is_instance_valid(_battle_scene):
		return
	var center := Vector3(0, 0, 0)
	var gy: float = 0.0
	if _terrain != null and _terrain.has_method("ground_height"):
		gy = _terrain.ground_height(0, 0)
	var battle: Node3D = load("res://scripts/world/battle_scene.gd").new()
	battle.name = "BattleScene"
	add_child(battle)
	_battle_scene = battle
	var atk: Dictionary = {}
	var def: Dictionary = {}
	if Military != null and not Military.units.is_empty():
		for id in Military.units.keys():
			var c: int = int(Military.units[id].get("count", 0))
			if c > 0:
				atk[id] = {"count": maxi(1, c / 3), "morale": 0.8, "supply": 1.0, "experience": 0.2, "commander": "veteran"}
				def[id] = {"count": maxi(1, c / 4), "morale": 0.7, "supply": 0.9, "experience": 0.1, "commander": "novice"}
	if atk.is_empty():
		atk = {"infantry_t1": {"count": 18, "morale": 0.75, "supply": 1.0, "experience": 0.1, "commander": "veteran"}, "archers_t1": {"count": 12, "morale": 0.7, "supply": 1.0, "experience": 0.05, "commander": "novice"}, "cavalry_t1": {"count": 6, "morale": 0.8, "supply": 1.0, "experience": 0.15, "commander": "veteran"}}
		def = {"infantry_t1": {"count": 16, "morale": 0.7, "supply": 0.9, "experience": 0.05, "commander": "novice"}, "archers_t1": {"count": 10, "morale": 0.65, "supply": 0.9, "experience": 0.0, "commander": "none"}, "cavalry_t1": {"count": 5, "morale": 0.75, "supply": 0.9, "experience": 0.1, "commander": "novice"}}
	var terrain: String = "plains"
	if _terrain != null and _terrain.has_method("moisture_at"):
		var m: float = _terrain.moisture_at(0, 0)
		terrain = "forest" if m > 0.3 else "plains"
	battle.setup(center, gy, atk, def, terrain)
	battle.battle_finished.connect(_on_battle_finished)
	battle.launch()
	if _camera != null and "target" in _camera:
		_camera.target = center

func _on_battle_finished(outcome: Dictionary) -> void:
	_battle_scene = null
	var winner: String = str(outcome.get("winner", "attacker"))
	var text: String = "Battle: %s wins! (%.0f vs %.0f on %s)" % [winner, float(outcome.get("attacker_power", 0)), float(outcome.get("defender_power", 0)), str(outcome.get("terrain", "plains"))]
	var ev := {"id": Game.events.size(), "turn": Game.turn, "type": "battle", "severity": 2, "text": text}
	Game.events.push_front(ev)
	Game.event_occurred.emit(ev)
	Game.save_to_file()

func _save_early() -> void:
	Game.save_to_file()
