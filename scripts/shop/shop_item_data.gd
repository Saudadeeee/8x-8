extends Resource
class_name ShopItemData

enum ItemType {
	TROOP,
	TERRITORY,
	DISMISS,
	UPGRADE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: float = 0.0
@export var use_royal_decree: bool = false
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.TROOP
@export var tower_stats: TowerStats
@export var territory_tag: String = ""
@export var territory_buff_summary: String = ""
@export var territory_color: Color = Color(1, 1, 1, 1)
@export var upgrade_damage_bonus: int = 0
@export var upgrade_attack_speed_reduction: float = 0.0
@export var upgrade_description: String = ""
@export var dismiss_reward: int = 0
@export var min_wave: int = 1     # Minimum wave before this item appears in shop
