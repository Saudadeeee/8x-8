# res://scripts/resources/tower_stats.gd
extends Resource
class_name TowerStats

enum AttackType { AOE, SINGLE_TARGET, CHAIN_ATTACK, DEBUFF_ATTACK }
enum UnitType { PAWN, ROOK, KNIGHT, QUEEN, BISHOP, WISP, CROSSBOWMAN, WARLOCK, CATAPULT, DARK_MAGE }
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
@export var element: Element = Element.FIRE
@export var faction: String = "iron"   # "iron" | "wild" | "hell" | "magic"

@export_group("Special Effects")
@export var slow_amount: float = 0.0       # 0.0–1.0: fraction of speed reduced
@export var slow_duration: float = 0.0    # seconds
@export var splash_radius: float = 0.0    # world-px AoE radius (0 = none)
@export var burn_dps: int = 0             # damage-per-second DoT
@export var burn_duration: float = 0.0   # seconds
@export var projectile_count: int = 1    # >1 = multishot
