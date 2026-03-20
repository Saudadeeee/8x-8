# res://scripts/resources/TerritoryStats.gd
# Dữ liệu tĩnh của mỗi loại Lãnh thổ (Territory tile).
extends Resource
class_name TerritoryStats

# --- NHẬN DIỆN ---
@export_group("Identity")
@export var id: String = "territory_default"
@export var territory_name: String = "Tên Lãnh Thổ"
@export_multiline var description: String = "Mô tả lãnh thổ..."
@export var owner_king_id: String = ""      # ID của vua sở hữu lãnh thổ này
@export var tile_texture: Texture2D         # Hình ảnh tile đặc biệt

# --- BUFF CHO QUÂN ĐỨNG TRÊN ---
@export_group("Tile Buffs")
@export var damage_bonus: float = 0.0       # +% sát thương
@export var speed_bonus: float = 0.0        # +% tốc độ tấn công
@export var range_bonus: float = 0.0        # +% tầm bắn
@export var crit_bonus: float = 0.0         # +% chí mạng
@export var hp_regen_bonus: float = 0.0     # Hồi máu mỗi giây (nếu có cơ chế HP quân)

# --- KỸ NĂNG ĐẶC BIỆT CỦA LÃNH THỔ ---
@export_group("Special Skill")
@export var skill_name: String = ""
@export_multiline var skill_description: String = ""
# VD: "Sau mỗi 3 wave, triệu hồi 1 quân Pawn miễn phí"
@export var skill_script: Script            # Script xử lý logic đặc biệt

# --- CHI PHÍ GIAO DỊCH ---
@export_group("Economy")
@export var purchase_cost: int = 20         # Giá mua lãnh thổ từ shop
# Chi phí để dùng lãnh thổ của vua khác (phải trả bằng điểm gì đó)
@export var foreign_use_cost: int = 5
@export var foreign_use_currency: String = "gold" # "gold", "decree", "favor"
