extends Camera3D
## OrbitCamera — touch/mouse orbit, pinch & wheel zoom, two-finger pan.

var target := Vector3.ZERO
var yaw := 0.0
var pitch := 0.55
var distance := 320.0

const MIN_DIST := 8.0
const MAX_DIST := 900.0

var _touches := {}
var _drag := false

func _ready() -> void:
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
	elif event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, MIN_DIST, MAX_DIST)
	elif event is InputEventScreenDrag:
		if _touches.size() >= 2:
			var d := distance * 0.0015
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			var right := Vector3(fwd.z, 0, -fwd.x)
			target -= right * event.relative.x * d
			target -= fwd * event.relative.y * d
		else:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch - event.relative.y * 0.006, -1.25, 1.2)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clampf(distance * 0.85, MIN_DIST, MAX_DIST)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clampf(distance / 0.85, MIN_DIST, MAX_DIST)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.25, 1.2)

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