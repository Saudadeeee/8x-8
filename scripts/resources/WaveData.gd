# res://scripts/resources/WaveData.gd
# Dữ liệu cấu hình cho mỗi đợt quái (Wave).
extends Resource
class_name WaveData

# --- NHẬN DIỆN ---
@export_group("Identity")
@export var wave_number: int = 1
@export var wave_name: String = "Wave 1"    # VD: "Tiền Quân", "Đại Quân", "Quân Tinh Nhuệ"
@export var is_boss_wave: bool = false

# --- CẤU HÌNH QUÁI ---
@export_group("Enemy Spawn")
# Mỗi phần tử: { "stats": EnemyStats, "count": 5, "delay": 0.5 }
@export var spawn_groups: Array[Dictionary] = []
@export var spawn_interval: float = 0.5    # Giây giữa mỗi con quái
@export var total_enemies: int = 10

# --- MỞ RỘNG BÀN CỜ ---
@export_group("Grid Expansion")
# Sau wave này, bàn cờ mở rộng thêm bao nhiêu hàng
@export var grid_expand_rows: int = 0      # 0 = không mở rộng

# --- PHẦN THƯỞNG ---
@export_group("Rewards")
@export var gold_reward: int = 20
@export var decree_reward: float = 5.0
# Sau wave này có Random Encounter hay không
@export var has_encounter: bool = false
@export var forced_encounter_id: String = "" # Nếu rỗng = random
