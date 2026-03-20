# res://scripts/resources/EncounterChoice.gd
# Một lựa chọn trong sự kiện Random Encounter.
extends Resource
class_name EncounterChoice

# --- NỘI DUNG ---
@export var choice_text: String = "Lựa chọn..."
@export_multiline var outcome_preview: String = "Có thể xảy ra..." # Hint cho người chơi

# --- HẬU QUẢ ---
@export_group("Outcomes")
@export var gold_delta: int = 0             # +/- vàng
@export var health_delta: int = 0          # +/- máu căn cứ
@export var decree_delta: float = 0.0      # +/- Decree tối đa
@export var add_soldier: Resource = null   # Thêm 1 quân vào army (SoldierStats)
@export var remove_soldier_tag: String = ""# Xóa 1 quân có tag này khỏi army
@export var add_territory: Resource = null # Thêm 1 lãnh thổ
@export var trigger_script: Script        # Logic phức tạp hơn dùng script
