extends Node3D
## Main — Phase 1 scene builder. Environment, lighting, camera, terrain, HUD,
## environment rig (day/night/seasons), weather, and building system.

var _camera
var _sun: DirectionalLight3D
var _hemi: DirectionalLight3D
var _env: Environment
var _terrain
var _rig: Node
var _build_mgr: Node3D
var _weather: Node

func _ready() -> void:
	_restore_or_new_game()
	_build_environment()
	_build_sun()
	_build_camera()
	_build_terrain()
	_build_rig()
	_build_weather()
	_build_buildings()
	_build_hud()

func _restore_or_new_game() -> void:
	if Game.load_from_file():
		return
	var rng := RandomNumberGenerator.new()
	Game.settings.world_seed = rng.randi_range(1, 999999)
	Game.reset()

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
	cam.set_script(load("res://scripts/world/camera_controller.gd"))
	add_child(cam)
	cam.make_current()
	_camera = cam
	_camera.target = Vector3(0, 0, 0)

func _build_terrain() -> void:
	var terrain = load("res://scripts/world/terrain.gd").new()
	terrain.name = "TerrainSource"
	terrain.world_seed = Game.settings.world_seed
	add_child(terrain)
	_terrain = terrain
	call_deferred("_save_early")

func _build_rig() -> void:
	var rig = load("res://scripts/world/environment_rig.gd").new()
	rig.name = "EnvironmentRig"
	add_child(rig)
	_rig = rig
	var mat: ShaderMaterial = null
	if _terrain != null and "terrain_material" in _terrain:
		mat = _terrain.terrain_material
	rig.setup(_sun, _hemi, _env, mat)

func _build_weather() -> void:
	var w = load("res://scripts/world/weather.gd").new()
	w.name = "Weather"
	add_child(w)
	_weather = w
	if _env != null:
		w.weather_changed.connect(func(state: String) -> void:
			if state == "fog":
				_env.fog_density = 0.0012
			elif state == "rain" or state == "snow":
				_env.fog_density = 0.0007
			else:
				_env.fog_density = 0.0004
		)

func _build_buildings() -> void:
	var mgr = load("res://scripts/world/building_manager.gd").new()
	mgr.name = "BuildingManager"
	add_child(mgr)
	_build_mgr = mgr
	mgr.setup(_terrain, _camera as Camera3D)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	hud.set_script(load("res://scripts/ui/hud.gd"))
	add_child(hud)
	var m: Dictionary = {"mgr": _build_mgr}
	hud.set_meta("build_mgr", _build_mgr)

func _save_early() -> void:
	Game.save_to_file()
