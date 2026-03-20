# res://scripts/mechanic/camera/camera_controller.gd
extends Camera2D

@export_group("Movement")
@export var base_move_speed: float = 100.0
@export var pan_speed_multiplier: float = 1.0
@export_group("Zoom")
@export var zoom_speed: float = 1.0
@export var min_zoom: float = 1.0
@export var max_zoom: float = 50.0 
@export var zoom_smoothing: float = 15.0
@export_group("Limits")

var target_zoom: Vector2
var is_dragging: bool = false

func _ready():
	make_current()
	zoom = Vector2(4, 4)
	target_zoom = zoom
	position = Vector2(12, 12) 

func _process(delta: float) -> void:
	handle_keyboard_movement(delta)
	handle_smooth_zoom(delta)
	clamp_camera_position() 

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom += Vector2(zoom_speed, zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom -= Vector2(zoom_speed, zoom_speed)
		
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
			
		target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
		target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

	if event is InputEventMouseMotion and is_dragging:
		position -= event.relative / zoom * pan_speed_multiplier

func handle_keyboard_movement(delta: float):
	var direction = Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	
	if direction.length() > 0:
		direction = direction.normalized()
		var current_speed = base_move_speed / (zoom.x / 5.0)
		position += direction * current_speed * delta

func handle_smooth_zoom(delta: float):
	zoom = zoom.lerp(target_zoom, zoom_smoothing * delta)

func clamp_camera_position():
	position.x = clamp(position.x, limit_left, limit_right)
	position.y = clamp(position.y, limit_top, limit_bottom)
