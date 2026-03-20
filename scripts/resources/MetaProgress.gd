# res://scripts/resources/MetaProgress.gd
# Lưu tiến trình Meta (giữa các lần chơi). Dùng ResourceSaver để ghi xuống disk.
extends Resource
class_name MetaProgress

# --- TIẾN TRÌNH ---
@export var total_runs: int = 0             # Tổng số lần chơi
@export var total_wins: int = 0
@export var meta_points: int = 0           # Điểm tích lũy để mở khóa

# --- MỞ KHÓA ---
@export var unlocked_king_ids: Array[String] = ["king_default"]
@export var unlocked_soldier_ids: Array[String] = []
@export var unlocked_territory_ids: Array[String] = []
@export var unlocked_encounter_ids: Array[String] = []

# --- BUFF KHỞI ĐẦU (Meta Upgrades) ---
# Mỗi upgrade là một Dictionary: { "id": "...", "level": 1, "max_level": 5 }
@export var meta_upgrades: Array[Dictionary] = []

# --- THỐNG KÊ ---
@export var best_wave_reached: int = 0
@export var total_enemies_killed: int = 0
@export var total_gold_earned: int = 0

const SAVE_PATH = "user://meta_progress.tres"

static func load_or_create() -> MetaProgress:
	if ResourceLoader.exists(SAVE_PATH):
		return load(SAVE_PATH) as MetaProgress
	var new_data = MetaProgress.new()
	return new_data

func save() -> void:
	ResourceSaver.save(self, SAVE_PATH)
