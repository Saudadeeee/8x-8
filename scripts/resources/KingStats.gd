# res://scripts/resources/KingStats.gd
# Dữ liệu tĩnh của mỗi vị Vua. Được tạo dưới dạng .tres trong editor.
extends Resource
class_name KingStats

# --- NHẬN DIỆN ---
@export_group("Identity")
@export var id: String = "king_default"
@export var king_name: String = "Tên Vua"
@export_multiline var lore: String = "Câu chuyện của vua..."
@export var portrait: Texture2D         # Ảnh chân dung trong menu chọn vua
@export var crown_texture: Texture2D    # Ảnh vương miện hiển thị trên bàn cờ

# --- CHỈ SỐ CƠ BẢN ---
@export_group("Base Stats")
@export var base_health: int = 20               # Máu căn cứ
@export var base_royal_decree: float = 10.0     # Royal Decree (Mana) ban đầu
@export var decree_regen_rate: float = 1.0      # Tốc độ hồi Decree mỗi giây
@export var decree_max: float = 100.0           # Tối đa Decree

# --- QUÂN ĐỘI KHỞI ĐẦU ---
@export_group("Starting Army")
# ID của các tower khởi đầu, khớp với TowerStats.id (ví dụ: "pawn", "rook")
@export var starting_unit_ids: Array[String] = []
# Số lượng tương ứng với mỗi id trong starting_unit_ids (phải cùng size)
@export var starting_unit_quantities: Array[int] = []
@export var starting_territory_count: int = 3   # Số ô lãnh thổ ban đầu

# --- ĐẶC QUYỀN LÃNH THỔ (King's Favor) ---
@export_group("King's Favor - Buffs")
# Loại quân được buff bởi vua này
@export var favored_unit_types: Array[String] = []
# Phần trăm buff bonus (VD: 0.2 = +20%)
@export var favor_damage_bonus: float = 0.0
@export var favor_speed_bonus: float = 0.0
@export var favor_range_bonus: float = 0.0

# --- KỸ NĂNG ĐẶC BIỆT CỦA VUA ---
@export_group("Royal Ability")
@export var ability_name: String = "Hoàng Lệnh"
@export_multiline var ability_description: String = "Mô tả kỹ năng..."
@export var ability_decree_cost: float = 30.0   # Tốn bao nhiêu Decree để dùng
@export var ability_cooldown: float = 60.0       # Thời gian hồi chiêu (giây)
# Script xử lý logic kỹ năng riêng của từng vua
@export var ability_script: Script

# --- META PROGRESSION ---
@export_group("Meta")
@export var unlock_cost: int = 0        # Tốn bao nhiêu điểm Meta để mở khóa
@export var is_starter_king: bool = false
