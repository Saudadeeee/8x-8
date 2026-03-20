extends Resource
class_name KingData

@export var id: String = "king_id"
@export var display_name: String = "Unnamed King"
@export var description: String = ""
@export var avatar: Texture2D

@export var starting_royal_decree: float = 20.0
@export var max_royal_decree: float = 120.0
@export var decree_regen: float = 1.0

@export var king_favor_targets: Array[String] = []
@export var territory_preferences: Array[String] = []
@export var territory_bonus: Dictionary = {}

@export var synergy_tags: Array[String] = []
@export var unique_units: Array[String] = []
@export var meta_unlock_level: int = 0
