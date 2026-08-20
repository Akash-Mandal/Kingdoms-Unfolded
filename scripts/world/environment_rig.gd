extends Node
## EnvironmentRig — drives sun, sky, fog and season tint from TimeClock + Game.
## Attach after main builds the sun, WorldEnvironment and terrain.

var _sun: DirectionalLight3D
var _hemi: DirectionalLight3D
var _env: Environment
var _terrain_mat: ShaderMaterial
var _sky_mat: ProceduralSkyMaterial

var _night_top := Color(0.02, 0.03, 0.08)
var _night_horiz := Color(0.05, 0.06, 0.12)
var _day_top := Color(0.12, 0.32, 0.68)
var _day_horiz := Color(0.52, 0.72, 0.92)
var _warm_horiz := Color(0.92, 0.55, 0.25)
var _moon_col := Color(0.4, 0.5, 0.7)
var _sun_col := Color(1.0, 0.97, 0.85)
var _warm_sun := Color(1.0, 0.62, 0.28)

func setup(sun: DirectionalLight3D, hemi: DirectionalLight3D, env: Environment, terrain_mat: ShaderMaterial) -> void:
	_sun = sun
	_hemi = hemi
	_env = env
	_terrain_mat = terrain_mat
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		_sky_mat = env.sky.sky_material
	TimeClock.hour_changed.connect(_on_hour)
	Game.turned.connect(_on_month)
	_on_hour(TimeClock.sim_hour)
	_on_month()

func _on_hour(hour: float) -> void:
	if _sun == null or _env == null:
		return
	var elev := (hour - 6.0) * 15.0
	var rad := deg_to_rad(elev)
	var day_f := clampf(sin(rad), 0.0, 1.0)
	var horiz_f := 1.0 - clampf(absf(sin(rad)) * 3.0, 0.0, 1.0)
	horiz_f = horiz_f * (1.0 - day_f * 0.2)

	_sun.rotation_degrees = Vector3(-elev, 45.0, 0.0)
	_sun.light_energy = 0.05 + day_f * 1.2
	_sun.light_color = _moon_col.lerp(_sun_col, day_f).lerp(_warm_sun, horiz_f * 0.7)
	if _hemi != null:
		_hemi.light_energy = 0.15 + day_f * 0.15

	_env.ambient_light_energy = 0.15 + day_f * 0.65
	var top := _night_top.lerp(_day_top, day_f)
	var horiz := _night_horiz.lerp(_day_horiz, day_f).lerp(_warm_horiz, horiz_f * 0.55)
	if _sky_mat != null:
		_sky_mat.sky_top_color = top
		_sky_mat.sky_horizon_color = horiz
		_sky_mat.ground_horizon_color = horiz.lerp(Color(0.15, 0.12, 0.08), horiz_f * 0.4)
	_env.fog_light_color = horiz
	_env.fog_density = 0.00035 + (1.0 - day_f) * 0.00035

func _on_month() -> void:
	if _terrain_mat == null:
		return
	var s: String = Game.season()
	match s:
		"winter":
			_terrain_mat.set_shader_parameter("snow_amount", 0.6)
			_terrain_mat.set_shader_parameter("season_tint", Color(0.85, 0.88, 0.95))
		"spring":
			_terrain_mat.set_shader_parameter("snow_amount", 0.0)
			_terrain_mat.set_shader_parameter("season_tint", Color(0.95, 1.02, 0.92))
		"summer":
			_terrain_mat.set_shader_parameter("snow_amount", 0.0)
			_terrain_mat.set_shader_parameter("season_tint", Color(1.05, 1.02, 0.92))
		"autumn":
			_terrain_mat.set_shader_parameter("snow_amount", 0.0)
			_terrain_mat.set_shader_parameter("season_tint", Color(1.0, 0.92, 0.78))
