extends Node
signal graphics_changed(preset: String, config: Dictionary)
const VAULT_PATH := "user://settings/graphics.json"
const PRESETS := {
	"potato": {
		"render_scale": 0.7,
		"msaa": 0,
		"shadows": "off",
		"fog_density_mult": 0.6,
		"lod_tier_a": 20.0,
		"lod_tier_b": 80.0,
		"max_tier_a": 400,
		"tree_count": 120,
		"shadow_atlas": 1024,
		"glow_enabled": false,
		"vsync": 1
	},
	"balanced": {
		"render_scale": 0.85,
		"msaa": 1,
		"shadows": "soft",
		"fog_density_mult": 0.85,
		"lod_tier_a": 30.0,
		"lod_tier_b": 120.0,
		"max_tier_a": 800,
		"tree_count": 260,
		"shadow_atlas": 2048,
		"glow_enabled": true,
		"vsync": 1
	},
	"high": {
		"render_scale": 0.95,
		"msaa": 2,
		"shadows": "soft",
		"fog_density_mult": 1.0,
		"lod_tier_a": 45.0,
		"lod_tier_b": 180.0,
		"max_tier_a": 1200,
		"tree_count": 400,
		"shadow_atlas": 4096,
		"glow_enabled": true,
		"vsync": 1
	},
	"ultra": {
		"render_scale": 1.0,
		"msaa": 4,
		"shadows": "soft",
		"fog_density_mult": 1.15,
		"lod_tier_a": 45.0,
		"lod_tier_b": 180.0,
		"max_tier_a": 1200,
		"tree_count": 400,
		"shadow_atlas": 4096,
		"glow_enabled": true,
		"vsync": 0
	}
}
var current_preset := "balanced"
var current_config: Dictionary = {}
var device_tier := "mid"
var renderer_name := ""
var _loaded := false

func _ready() -> void:
	renderer_name = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "mobile"))
	if FileAccess.file_exists(VAULT_PATH):
		_load()
	else:
		device_tier = auto_detect()
		current_preset = _tier_to_preset(device_tier)
		current_config = PRESETS[current_preset].duplicate(true)
		save()
	_apply_viewport(current_config)
	graphics_changed.emit(current_preset, current_config)

func _tier_to_preset(tier: String) -> String:
	match tier:
		"low": return "potato"
		"mid": return "balanced"
		"high": return "high"
		"ultra": return "ultra"
		_: return "balanced"

func auto_detect() -> String:
	var cores: int = OS.get_processor_count()
	var mem_mb: float = _get_memory_mb()
	var screen_px: int = _get_screen_pixels()
	var rend: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")).to_lower()
	var adapter: String = ""
	if RenderingServer.has_method("get_video_adapter_name"):
		adapter = str(RenderingServer.get_video_adapter_name()).to_lower()
	var low_mem: bool = mem_mb > 0 and mem_mb < 2800
	var mid_mem: bool = mem_mb > 0 and mem_mb < 4500
	var small_screen: bool = screen_px > 0 and screen_px < 1000000
	var is_gl: bool = rend == "gl_compatibility" or adapter.contains("adreno 3") or adapter.contains("mali-4")
	if cores <= 3 or low_mem or small_screen or is_gl:
		return "low"
	if cores <= 6 or mid_mem or screen_px < 2073600:
		return "mid"
	if cores >= 8 and mem_mb >= 6000 and not small_screen:
		return "high"
	return "high"

func _get_memory_mb() -> float:
	var info: Variant = null
	if OS.has_method("get_memory_info"):
		info = OS.call("get_memory_info")
		if typeof(info) == TYPE_DICTIONARY:
			var phys: Variant = (info as Dictionary).get("physical", null)
			if phys == null:
				phys = (info as Dictionary).get("ram", null)
			if phys != null:
				return float(phys) / 1048576.0
	if OS.has_method("get_static_memory_usage"):
		return float(OS.get_static_memory_usage()) / 1048576.0
	return 0.0

func _get_screen_pixels() -> int:
	if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless":
		return 0
	var sz: Vector2i = Vector2i.ZERO
	if DisplayServer.get_screen_count() > 0:
		sz = DisplayServer.screen_get_size()
	if sz == Vector2i.ZERO:
		sz = DisplayServer.window_get_size()
	if sz == Vector2i.ZERO and get_viewport() != null:
		sz = Vector2i(get_viewport().get_visible_rect().size)
	return sz.x * sz.y

func _load() -> void:
	var f := FileAccess.open(VAULT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed as Dictionary
	device_tier = str(d.get("device_tier", d.get("tier", "mid")))
	renderer_name = str(d.get("renderer", renderer_name))
	current_preset = str(d.get("preset", "balanced")).to_lower()
	if not PRESETS.has(current_preset):
		current_preset = "balanced"
	var base: Dictionary = PRESETS[current_preset].duplicate(true)
	var saved: Variant = d.get("config", null)
	if typeof(saved) == TYPE_DICTIONARY:
		for k in (saved as Dictionary).keys():
			base[k] = (saved as Dictionary)[k]
	var custom: Variant = d.get("custom", null)
	if typeof(custom) == TYPE_DICTIONARY:
		for k in (custom as Dictionary).keys():
			base[k] = (custom as Dictionary)[k]
	current_config = base
	_loaded = true

func save() -> void:
	DirAccess.make_dir_recursive_absolute(VAULT_PATH.get_base_dir())
	var f := FileAccess.open(VAULT_PATH, FileAccess.WRITE)
	if f == null:
		return
	var data := {
		"preset": current_preset,
		"device_tier": device_tier,
		"renderer": renderer_name,
		"config": current_config,
		"auto_detected": _loaded == false
	}
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func get_preset_list() -> PackedStringArray:
	return PackedStringArray(["potato", "balanced", "high", "ultra"])

func get_config() -> Dictionary:
	return current_config.duplicate(true)

func get_preset_config(name: String) -> Dictionary:
	if PRESETS.has(name):
		return (PRESETS[name] as Dictionary).duplicate(true)
	return PRESETS["balanced"].duplicate(true)

func apply_preset(name: String) -> void:
	var key := name.to_lower()
	if not PRESETS.has(key):
		return
	current_preset = key
	current_config = (PRESETS[key] as Dictionary).duplicate(true)
	_apply_viewport(current_config)
	save()
	graphics_changed.emit(current_preset, current_config)

func apply_custom(cfg: Dictionary) -> void:
	for k in cfg.keys():
		current_config[k] = cfg[k]
	current_preset = _find_closest_preset(current_config)
	_apply_viewport(current_config)
	save()
	graphics_changed.emit(current_preset, current_config)

func _find_closest_preset(cfg: Dictionary) -> String:
	var best := "balanced"
	var best_diff := 1e20
	for p in PRESETS.keys():
		var diff := 0.0
		var pc: Dictionary = PRESETS[p]
		for k in pc.keys():
			if cfg.has(k):
				var a: Variant = cfg[k]
				var b: Variant = pc[k]
				if typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT:
					diff += absf(float(a) - float(b)) * 0.1
				elif str(a) != str(b):
					diff += 1.0
		if diff < best_diff:
			best_diff = diff
			best = str(p)
	return best

func _apply_viewport(cfg: Dictionary) -> void:
	var vp: Viewport = get_viewport()
	if vp != null:
		var rs: float = clampf(float(cfg.get("render_scale", 1.0)), 0.7, 1.0)
		vp.scaling_3d_scale = rs
		var msaa: int = int(cfg.get("msaa", 1))
		var mode: int = 0
		match msaa:
			0: mode = Viewport.MSAA_DISABLED
			1: mode = Viewport.MSAA_2X
			2: mode = Viewport.MSAA_4X
			4: mode = Viewport.MSAA_8X
			_: mode = Viewport.MSAA_2X if msaa == 1 else Viewport.MSAA_DISABLED
		vp.msaa_3d = mode
		vp.use_taa = false
	var vsync: int = int(cfg.get("vsync", 1))
	if not OS.has_feature("dedicated_server") and DisplayServer.get_name() != "headless":
		var vsync_mode: int = DisplayServer.VSYNC_ENABLED if vsync != 0 else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode(0) != vsync_mode:
			DisplayServer.window_set_vsync_mode(vsync_mode)
	var atlas: int = int(cfg.get("shadow_atlas", 2048))
	if RenderingServer.has_method("directional_shadow_atlas_set_size"):
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
