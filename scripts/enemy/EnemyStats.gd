# res://scripts/enemies/enemy_stats.gd
extends Resource
class_name EnemyStats

@export_group("Identity")
@export var id: String = ""

@export_group("Visuals")
@export var texture: Texture2D
@export var scale: Vector2 = Vector2(1, 1)

@export_group("Attributes")
@export var max_hp: int = 100
@export var speed: float = 40.0
@export var damage_to_base: int = 1
@export var gold_reward: int = 10
