# res://scripts/resources/SynergyDefinition.gd
# Định nghĩa một loại Synergy: khi đủ N quân cùng loại → kích hoạt buff toàn cục.
extends Resource
class_name SynergyDefinition

@export var tag: String = "pawn"             # Tên loại quân (khớp với UnitType enum key viết thường)
@export var display_name: String = "Pawn Formation"
@export_multiline var description: String = "Pawn synergy bonus."

# Mỗi threshold tương ứng một mức buff trong bonuses
@export var thresholds: Array[int] = [2, 4, 6]
# bonuses[i] áp dụng khi đạt thresholds[i]
# Mỗi dict: { "damage_bonus": float, "speed_bonus": float, "range_bonus": float }
@export var bonuses: Array[Dictionary] = [
	{"damage_bonus": 0.10, "speed_bonus": 0.00, "range_bonus": 0.0},
	{"damage_bonus": 0.20, "speed_bonus": 0.05, "range_bonus": 0.0},
	{"damage_bonus": 0.30, "speed_bonus": 0.10, "range_bonus": 0.0},
]
