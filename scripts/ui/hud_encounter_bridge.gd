# res://scripts/ui/hud_encounter_bridge.gd
# Bridge script that instantiates the encounter_screen CanvasLayer
# and adds it to the gameplay scene. Add this node to any gameplay scene
# to get encounter support without manually editing the scene file.
extends Node

const ENCOUNTER_SCENE_PATH = "res://scenes/ui/encounter_screen.tscn"

func _ready() -> void:
	if ResourceLoader.exists(ENCOUNTER_SCENE_PATH):
		var scene = load(ENCOUNTER_SCENE_PATH)
		if scene:
			var overlay = scene.instantiate()
			# Add to the root viewport so it draws above everything
			get_tree().get_root().add_child(overlay)
	else:
		push_warning("HudEncounterBridge: encounter_screen.tscn not found at " + ENCOUNTER_SCENE_PATH)
