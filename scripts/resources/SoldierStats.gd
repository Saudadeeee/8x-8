# res://scripts/resources/SoldierStats.gd
# Dữ liệu tĩnh của mỗi loại quân cờ.
extends Resource
class_name SoldierStats

# --- PHÂN LOẠI ---
enum UnitClass { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING_GUARD }
enum AttackType { MELEE, RANGED, SUMMON, AOE, CHAIN, DEBUFF }
enum Element { FIRE, WATER, WOOD, EARTH, METAL, DARK, LIGHT, NEUTRAL }

# --- NHẬN DIỆN ---
@export_group("Identity")
@export var id: String = "soldier_default"
@export var soldier_name: String = "Tên Quân"
@export_multiline var description: String = "Mô tả quân..."
@export var unit_class: UnitClass = UnitClass.PAWN
@export var attack_type: AttackType = AttackType.RANGED
@export var element: Element = Element.NEUTRAL

# --- HÌNH ẢNH ---
@export_group("Visuals")
@export var texture: Texture2D
@export var projectile_texture: Texture2D
@export var scale: Vector2 = Vector2(1, 1)

# --- CHÍ SỐ CHIẾN ĐẤU ---
@export_group("Combat Stats")
@export var base_damage: int = 10
@export var attack_speed: float = 1.0       # Giây/lần tấn công
@export var attack_range: int = 2           # Tính bằng số ô
@export var crit_chance: float = 0.05       # Tỉ lệ chí mạng (0.0 - 1.0)
@export var crit_multiplier: float = 2.0    # Hệ số chí mạng

# --- CHI PHÍ ---
@export_group("Economy")
@export var decree_cost: int = 1            # Chi phí Decree để triệu hồi (1=Tốt, 3=Mã,...)
@export var gold_cost: int = 10             # Chi phí Vàng để mua từ shop
@export var sell_value: int = 5             # Giá trị khi đuổi quân (Dismiss)

# --- SYNERGY ---
@export_group("Synergy")
# Các tag để hệ thống Synergy nhận diện (VD: "infantry", "cavalry", "magic")
@export var synergy_tags: Array[String] = []

# --- BUFF CỦA LÍNH ---
@export_group("Soldier Buffs")
# Buff cố định nội tại của quân (VD: Pawn tăng tốc 50% sau khi đi được 3 ô)
@export var passive_buff_description: String = ""
@export var passive_script: Script         # Script xử lý logic buff riêng

# --- CROWN'S BOON ---
@export_group("Crown's Boon")
@export var boon_duration: float = 5.0     # Thời gian buff Crown's Boon (giây)
@export var boon_damage_multiplier: float = 1.5
@export var boon_speed_multiplier: float = 1.2
