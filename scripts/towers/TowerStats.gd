# res://scripts/resources/tower_stats.gd
extends Resource
class_name TowerStats

enum AttackType { AOE, SINGLE_TARGET, CHAIN_ATTACK, DEBUFF_ATTACK }
enum UnitType { PAWN, ROOK, KNIGHT, QUEEN, BISHOP, WISP, CROSSBOWMAN, WARLOCK, CATAPULT, DARK_MAGE, LONGBOWMAN, PALADIN, ALCHEMIST, ICE_GUARDIAN, BALLISTA }
enum Element { FIRE, WATER, WOOD, EARTH, METAL, DARK, LIGHT }

@export_group("General")
@export var id: String = "unit_id"
@export var name: String = "Tên Đơn Vị"
@export_multiline var description: String = "Mô tả đơn vị..."
@export var cost: int = 5           # Vàng — mua trong Shop
@export var decree_cost: float = 1.0 # Royal Decree — để triển khai lên bàn cờ

@export_group("Visuals")
@export var texture: Texture2D            
@export var projectile_texture: Texture2D 
@export_group("Combat Stats")
@export var base_damage: int = 10
@export var attack_speed: float = 1.0
@export var attack_range: int = 1
@export var attack_style: AttackType = AttackType.SINGLE_TARGET
@export_group("Synergies")
@export var type: UnitType = UnitType.PAWN
## Nhánh synergy dạng CHUỖI. Để rỗng thì suy từ `type` ở trên (tương thích
## ngược — mọi .tres cũ không phải sửa gì).
##
## Điền chuỗi vào đây thì thêm một nhánh synergy HOÀN TOÀN MỚI không cần đụng
## code: đặt tag ở đây + thả một file res/synergies/<tag>.tres. Trước đây phải
## sửa `enum UnitType` trong GDScript, tức không thể làm bằng kéo thả.
@export var synergy_tag: String = ""
@export var element: Element = Element.FIRE
@export var faction: String = "iron"   # "iron" | "wild" | "hell" | "magic"

@export_group("Special Effects")
@export var slow_amount: float = 0.0       # 0.0–1.0: fraction of speed reduced
@export var slow_duration: float = 0.0    # seconds
@export var splash_radius: float = 0.0    # world-px AoE radius (0 = none)
@export var burn_dps: int = 0             # damage-per-second DoT
@export var burn_duration: float = 0.0   # seconds
@export var projectile_count: int = 1    # >1 = multishot

## Tag synergy thực dùng: ưu tiên chuỗi `synergy_tag`, không có thì lấy tên
## hằng của `type` viết thường. Mọi nơi đếm synergy phải gọi hàm này, KHÔNG
## đọc thẳng `type` — nếu không thì nhánh mới khai bằng chuỗi sẽ bị bỏ qua.
func get_synergy_tag() -> String:
	if not synergy_tag.is_empty():
		return synergy_tag
	return UnitType.keys()[type].to_lower()
