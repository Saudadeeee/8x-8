# res://scripts/mechanic/camera/camera_controller.gd
# Diorama orbit rig (Towerscaper-style): pivot (self, yaw) → Pitch (Node3D) → Camera3D.
# Được game_map.gd tạo bằng code trong _ready().
extends Node3D

@export_group("Zoom")
## Khoảng cách camera mặc định (m)
@export var default_distance: float = 11.0
## Khoảng cách tối thiểu (m)
@export var min_distance: float = 4.0
## Khoảng cách tối đa (m)
@export var max_distance: float = 30.0
## Bước zoom mỗi nấc lăn chuột (m)
@export var zoom_step: float = 1.0

@export_group("Orbit")
## Độ nhạy xoay khi kéo chuột giữa (rad/px)
@export var orbit_sensitivity: float = 0.008
## Pitch tối thiểu (rad)
@export var min_pitch: float = deg_to_rad(-80.0)
## Pitch tối đa (rad)
@export var max_pitch: float = deg_to_rad(-25.0)

@export_group("Pan")
## Tốc độ pan bằng phím (m/s)
@export var pan_speed: float = 8.0

@export_group("Smoothing")
## Hệ số lerp mượt (nhân delta)
@export var smooth_factor: float = 8.0

var _pitch_node: Node3D = null
var _camera: Camera3D = null
var _target_distance: float = 11.0
var _target_pivot: Vector3 = Vector3.ZERO
var _target_pitch: float = deg_to_rad(-50.0)
var _is_dragging: bool = false
var _shake: float = 0.0
var _last_health: int = -1

func _ready() -> void:
	_target_distance = default_distance
	_target_pivot = position

	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	_pitch_node.rotation.x = _target_pitch
	add_child(_pitch_node)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 45.0
	_camera.position = Vector3(0.0, 0.0, _target_distance)
	_pitch_node.add_child(_camera)
	_camera.current = true

	# Shake khi King mất máu — nghe trực tiếp autoload để không phải wire qua game_map
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_signal("health_changed"):
		gm.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health: int) -> void:
	if _last_health >= 0 and new_health < _last_health:
		add_shake(0.35)
	_last_health = new_health

## Rung camera — cường độ cộng dồn, tự tắt dần.
func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	var t: float = clampf(smooth_factor * delta, 0.0, 1.0)
	position = position.lerp(_target_pivot, t)
	_pitch_node.rotation.x = lerpf(_pitch_node.rotation.x, _target_pitch, t)
	_camera.position.z = lerpf(_camera.position.z, _target_distance, t)

	if _shake > 0.001:
		_shake = maxf(_shake - delta * 1.8, 0.0)
		var s := _shake * _shake * 0.35
		_camera.position.x = randf_range(-s, s)
		_camera.position.y = randf_range(-s, s)
	else:
		_camera.position.x = 0.0
		_camera.position.y = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_distance = clampf(_target_distance - zoom_step, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_distance = clampf(_target_distance + zoom_step, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
	elif event is InputEventMouseMotion and _is_dragging:
		rotation.y -= event.relative.x * orbit_sensitivity
		_target_pitch = clampf(
			_target_pitch - event.relative.y * orbit_sensitivity,
			min_pitch, max_pitch)

## Căn camera vào giữa board — game_map gọi khi tạo map / mở rộng.
func center_on_board(center: Vector3, span: float) -> void:
	_target_pivot = Vector3(center.x, 0.0, center.z)
	_target_distance = clampf(span * 1.4, min_distance, max_distance)

func _handle_keyboard_pan(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
	if input_dir == Vector2.ZERO:
		return
	input_dir = input_dir.normalized()
	# Pan trên mặt XZ, tương đối theo yaw hiện tại của pivot
	var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var right := Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
	_target_pivot += (right * input_dir.x - forward * input_dir.y) * pan_speed * delta
