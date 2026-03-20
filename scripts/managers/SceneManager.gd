# res://scripts/managers/SceneManager.gd
# Handles scene transitions with a black fade effect. Autoload singleton.
extends Node

signal transition_finished

var _canvas: CanvasLayer
var _overlay: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_overlay)

func go_to_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween = create_tween()
	tween.tween_property(_overlay, "color", Color(0, 0, 0, 1), 0.35)
	await tween.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	var tween2 = create_tween()
	tween2.tween_property(_overlay, "color", Color(0, 0, 0, 0), 0.35)
	await tween2.finished

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit()
