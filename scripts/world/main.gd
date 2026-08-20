extends Node3D
## Main — Phase 0 scene builder. Assembles environment, lighting, camera,
## terrain and HUD. Everything is constructed in code for git-friendliness.

var _camera

func _ready() -> void:
	_restore_or_new_game()
	_build_environment()
	_build_sun()
	_build_camera()
	_build_terrain()
	_build_hud()

func _restore_or_new_game() -> void:
	if Game.load_from_file():
		return
	var rng := RandomNumberGenerator.new()
	Game.settings.world_seed = rng.randi_range(1, 999999)
	Game.reset()

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.86)
	env.fog_density = 0.0004
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.15
	var wenv := WorldEnvironment.new()
	wenv.environment = env
	add_child(wenv)

func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(sun)
	var hemi := DirectionalLight3D.new()
	hemi.name = "SkyFill"
	hemi.light_color = Color(0.6, 0.7, 0.9)
	hemi.light_energy = 0.25
	hemi.rotation_degrees = Vector3(80, -40, 0)
	add_child(hemi)

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "MainCamera"
	cam.set_script(load("res://scripts/world/camera_controller.gd"))
	add_child(cam)
	cam.make_current()
	_camera = cam
	var terrain_half := (160 - 1) * 4.0 * 0.5   # mirrors terrain.gd GRID/SPACING
	_camera.target = Vector3(0, 0, 0)

func _build_terrain() -> void:
	var terrain = load("res://scripts/world/terrain.gd").new()
	terrain.name = "TerrainSource"
	terrain.world_seed = Game.settings.world_seed
	add_child(terrain)
	call_deferred("_save_early")

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	hud.set_script(load("res://scripts/ui/hud.gd"))
	add_child(hud)

func _save_early() -> void:
	Game.save_to_file()