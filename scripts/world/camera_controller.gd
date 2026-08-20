extends Camera3D
## OrbitCamera — touch/mouse orbit, pinch & wheel zoom, two-finger pan.

var target := Vector3.ZERO
var yaw := 0.35
var pitch := 0.62
var distance := 55.0

const MIN_DIST := 12.0
const MAX_DIST := 220.0

var _touches := {}
var _drag := false
var _last_pinch_dist := 0.0

func apply_graphics(cfg: Dictionary) -> void:
	var rs: float = clampf(float(cfg.get("render_scale", 1.0)), 0.7, 1.0)
	if get_viewport() != null:
		get_viewport().scaling_3d_scale = rs
	far = 520.0 if rs > 0.9 else 380.0

func _ready() -> void:
	var gs: Node = get_node_or_null("/root/GraphicsSettings")
	if gs != null:
		if gs.has_signal("graphics_changed") and not gs.graphics_changed.is_connected(apply_graphics):
			gs.graphics_changed.connect(apply_graphics)
		if gs.has_method("get_config"):
			apply_graphics(gs.call("get_config") as Dictionary)
	update_camera()

func _is_over_ui() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var hover: Control = vp.gui_get_hovered_control()
	if hover != null:
		return true
	return vp.gui_is_dragging() and vp.gui_get_focus_owner() != null

func _is_building_placement_active() -> bool:
	var bm: Node = get_node_or_null("/root/Main/BuildingManager")
	if bm != null and "selected_id" in bm and str(bm.get("selected_id")) != "":
		return true
	var bm2: Node = get_parent().get_node_or_null("BuildingManager") if get_parent() != null else null
	if bm2 != null and "selected_id" in bm2 and str(bm2.get("selected_id")) != "":
		return true
	return false

func _input(event: InputEvent) -> void:
	if _is_building_placement_active():
		if event is InputEventMouseMotion and _drag:
			return
		if event is InputEventScreenDrag and _touches.size() < 2:
			return
	if _is_over_ui() and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton):
		var hover: Control = get_viewport().gui_get_hovered_control()
		if hover != null and hover is Button:
			return
		if hover != null:
			return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_last_pinch_dist = _pinch_dist()
		else:
			_touches.erase(event.index)
			_last_pinch_dist = _pinch_dist()
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, MIN_DIST, MAX_DIST)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var d := _pinch_dist()
			if _last_pinch_dist > 0.0 and d > 0.0:
				var factor := d / _last_pinch_dist
				if absf(factor - 1.0) > 0.01:
					distance = clampf(distance / factor, MIN_DIST, MAX_DIST)
			_last_pinch_dist = d
			var avg_rel := _avg_relative(event)
			var dd := distance * 0.0012
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			var right := Vector3(fwd.z, 0, -fwd.x)
			target -= right * avg_rel.x * dd
			target -= fwd * avg_rel.y * dd
		else:
			yaw -= event.relative.x * 0.005
			pitch = clampf(pitch - event.relative.y * 0.005, -1.2, 1.25)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clampf(distance * 0.85, MIN_DIST, MAX_DIST)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clampf(distance / 0.85, MIN_DIST, MAX_DIST)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		if _is_over_ui():
			return
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch - event.relative.y * 0.004, -1.2, 1.25)
		get_viewport().set_input_as_handled()

func _pinch_dist() -> float:
	if _touches.size() < 2:
		return 0.0
	var vals: Array = _touches.values()
	return (vals[0] as Vector2).distance_to(vals[1] as Vector2)

func _avg_relative(_event: InputEventScreenDrag) -> Vector2:
	return _event.relative

func _process(delta: float) -> void:
	var d := distance * 0.01
	if Input.is_key_pressed(KEY_LEFT):
		target.x -= d * 4.0
	if Input.is_key_pressed(KEY_RIGHT):
		target.x += d * 4.0
	if Input.is_key_pressed(KEY_UP):
		target.z -= d * 4.0
	if Input.is_key_pressed(KEY_DOWN):
		target.z += d * 4.0
	update_camera()

func update_camera() -> void:
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * distance
	global_position = target + offset
	look_at(target, Vector3.UP)