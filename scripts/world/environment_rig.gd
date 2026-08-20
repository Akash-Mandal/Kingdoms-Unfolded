extends Node
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
var _tech_tint := Color(1.0, 1.0, 1.0)
var _tech_fog: Variant = null
var _base_tint := Color(1, 1, 1)
var _fog_mult := 1.0
var _glow_base := true
func apply_graphics(cfg: Dictionary) -> void:
	_fog_mult = float(cfg.get("fog_density_mult", 1.0))
	_glow_base = bool(cfg.get("glow_enabled", true))
	if _env != null:
		_env.glow_enabled = _glow_base
		_env.fog_density = clampf(_env.fog_density * _fog_mult, 0.00005, 0.004)
	if _sun != null:
		var sh: String = str(cfg.get("shadows", "soft"))
		_sun.shadow_enabled = sh != "off"
		if sh == "off":
			_sun.shadow_enabled = false
		else:
			_sun.shadow_enabled = true
			_sun.shadow_opacity = 0.85
		var atlas: int = int(cfg.get("shadow_atlas", 2048))
		if RenderingServer.has_method("directional_shadow_atlas_set_size"):
			RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	_on_hour(TimeClock.sim_hour if TimeClock != null else 12.0)

func setup(sun: DirectionalLight3D, hemi: DirectionalLight3D, env: Environment, terrain_mat: ShaderMaterial) -> void:
	_sun = sun
	_hemi = hemi
	_env = env
	_terrain_mat = terrain_mat
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		_sky_mat = env.sky.sky_material
	TimeClock.hour_changed.connect(_on_hour)
	Game.turned.connect(_on_month)
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null and tn.has_signal("tech_unlocked"):
		tn.tech_unlocked.connect(_on_tech_unlocked)
		_apply_existing_tech()
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs != null:
		if gs.has_signal("graphics_changed") and not gs.graphics_changed.is_connected(apply_graphics):
			gs.graphics_changed.connect(apply_graphics)
		if gs.has_method("get_config"):
			apply_graphics(gs.call("get_config") as Dictionary)
	_on_hour(TimeClock.sim_hour)
	_on_month()
func _apply_existing_tech() -> void:
	_tech_tint = Color(1,1,1)
	_tech_fog = null
	var tn: Node = get_node_or_null("/root/Tech")
	if tn == null:
		return
	var unlocked: Variant = tn.get("unlocked")
	if typeof(unlocked) != TYPE_ARRAY:
		return
	for tid in unlocked as Array:
		_accumulate_tech_visual(String(tid), true)
func _on_tech_unlocked(id: String) -> void:
	_accumulate_tech_visual(id, false)
	_flash_tech_unlock(id)
	_on_month()
func _accumulate_tech_visual(id: String, silent: bool) -> void:
	var entry: Dictionary = {}
	var tn: Node = get_node_or_null("/root/Tech")
	if tn != null and tn.has_method("get_tech"):
		entry = tn.call("get_tech", id) as Dictionary
	if entry.is_empty() and has_node("/root/Catalog"):
		entry = get_node("/root/Catalog").call("get_tech", id) as Dictionary
	var vis: Dictionary = entry.get("visual", {})
	var shift: Variant = vis.get("season_tint_shift", null)
	if typeof(shift) == TYPE_ARRAY and (shift as Array).size() >= 3:
		var arr: Array = shift as Array
		var dr: float = float(arr[0])
		var dg: float = float(arr[1])
		var db: float = float(arr[2])
		_tech_tint = Color(clampf(_tech_tint.r + dr * 0.35, 0.85, 1.15), clampf(_tech_tint.g + dg * 0.35, 0.85, 1.15), clampf(_tech_tint.b + db * 0.35, 0.85, 1.15))
	var fog: Variant = vis.get("fog_tint", null)
	if typeof(fog) == TYPE_ARRAY and (fog as Array).size() >= 3:
		var fa: Array = fog as Array
		_tech_fog = Color(float(fa[0]) / 255.0 if float(fa[0]) > 1.5 else float(fa[0]), float(fa[1]) / 255.0 if float(fa[1]) > 1.5 else float(fa[1]), float(fa[2]) / 255.0 if float(fa[2]) > 1.5 else float(fa[2]))
		if not silent and _env != null:
			var cur := _env.fog_light_color
			var tw := create_tween()
			tw.tween_property(_env, "fog_light_color", (cur.lerp(_tech_fog as Color, 0.35)), 1.2)
func _flash_tech_unlock(id: String) -> void:
	if _terrain_mat == null:
		return
	var tw := create_tween()
	var orig: Color = _terrain_mat.get_shader_parameter("season_tint") as Color if _terrain_mat.get_shader_parameter("season_tint") != null else Color(1, 1, 1)
	var flash := orig.lerp(Color(1.3, 1.3, 1.1), 0.25)
	tw.tween_property(_terrain_mat, "shader_parameter/season_tint", flash, 0.18)
	tw.tween_property(_terrain_mat, "shader_parameter/season_tint", _base_tint * _tech_tint, 0.9)
var _hour_tween: Tween = null
var _target_day_f := 0.5
func _on_hour(hour: float) -> void:
	if _sun == null or _env == null:
		return
	var elev := (hour - 6.0) * 15.0
	var rad := deg_to_rad(elev)
	var day_f := clampf(sin(rad), 0.0, 1.0)
	var horiz_f := 1.0 - clampf(absf(sin(rad)) * 3.0, 0.0, 1.0)
	horiz_f = horiz_f * (1.0 - day_f * 0.2)
	if _hour_tween != null and _hour_tween.is_valid():
		_hour_tween.kill()
	var tw := create_tween()
	_hour_tween = tw
	tw.set_parallel(true)
	tw.tween_property(_sun, "rotation_degrees", Vector3(-elev, 45.0, 0.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sun, "light_energy", 0.05 + day_f * 1.2, 0.9)
	tw.tween_property(_sun, "light_color", _moon_col.lerp(_sun_col, day_f).lerp(_warm_sun, horiz_f * 0.7), 0.9)
	if _hemi != null:
		tw.tween_property(_hemi, "light_energy", 0.15 + day_f * 0.15, 0.9)
	tw.tween_property(_env, "ambient_light_energy", 0.15 + day_f * 0.65, 0.9)
	var top := _night_top.lerp(_day_top, day_f)
	var horiz := _night_horiz.lerp(_day_horiz, day_f).lerp(_warm_horiz, horiz_f * 0.55)
	if _sky_mat != null:
		_sky_mat.sky_top_color = _sky_mat.sky_top_color.lerp(top, 0.5)
		_sky_mat.sky_horizon_color = _sky_mat.sky_horizon_color.lerp(horiz, 0.5)
		_sky_mat.ground_horizon_color = (_sky_mat.ground_horizon_color as Color).lerp(horiz.lerp(Color(0.15, 0.12, 0.08), horiz_f * 0.4), 0.5)
	var fog_target: Color = horiz
	if _tech_fog != null and day_f > 0.3:
		fog_target = horiz.lerp(_tech_fog as Color, 0.18)
	tw.tween_property(_env, "fog_light_color", fog_target, 0.9)
	tw.tween_property(_env, "fog_density", (0.00028 + (1.0 - day_f) * 0.00022) * _fog_mult, 0.9)
	if not _glow_base and _env != null:
		_env.glow_enabled = false
var _month_tween: Tween = null
func _on_month() -> void:
	if _terrain_mat == null:
		return
	var s: String = Game.season()
	match s:
		"winter":
			_base_tint = Color(0.90, 0.92, 0.97)
		"spring":
			_base_tint = Color(0.95, 1.02, 0.92)
		"summer":
			_base_tint = Color(1.05, 1.02, 0.92)
		"autumn":
			_base_tint = Color(1.0, 0.92, 0.78)
	var snow_t := 0.32 if s == "winter" else 0.0
	var cur_snow: float = float(_terrain_mat.get_shader_parameter("snow_amount") if _terrain_mat.get_shader_parameter("snow_amount") != null else 0.0)
	if absf(cur_snow - snow_t) > 0.01:
		var tws := create_tween()
		tws.tween_property(_terrain_mat, "shader_parameter/snow_amount", snow_t, 1.2)
	else:
		_terrain_mat.set_shader_parameter("snow_amount", snow_t)
	var final_tint: Color = Color(clampf(_base_tint.r * _tech_tint.r,0.8,1.2), clampf(_base_tint.g * _tech_tint.g,0.8,1.2), clampf(_base_tint.b * _tech_tint.b,0.8,1.2))
	var cur_tint: Variant = _terrain_mat.get_shader_parameter("season_tint")
	if cur_tint is Color:
		if _month_tween != null and _month_tween.is_valid(): _month_tween.kill()
		_month_tween = create_tween()
		_month_tween.tween_property(_terrain_mat, "shader_parameter/season_tint", final_tint, 1.0)
	else:
		_terrain_mat.set_shader_parameter("season_tint", final_tint)
