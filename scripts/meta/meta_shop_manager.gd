extends Node
class_name MetaShopManager

signal meta_item_purchased(item: MetaShopItemData)

@export var meta_items: Array[MetaShopItemData] = []

var unlocked_item_ids: Array[String] = []
var unlocked_unit_paths: Array[String] = []

func _ready() -> void:
	_populate_defaults()

func _populate_defaults() -> void:
	if meta_items.size() > 0:
		return
	var knight_stats = load("res://res/towers/knight.tres") as TowerStats
	var rook_stats = load("res://res/towers/rook.tres") as TowerStats
	var bishop_stats = load("res://res/towers/bishop.tres") as TowerStats
	var items: Array[MetaShopItemData] = []
	if knight_stats:
		var knight_item = MetaShopItemData.new()
		knight_item.id = "meta_knight"
		knight_item.display_name = "Knight Vanguard"
		knight_item.description = "Unlocks a Knight unit that excels at frontline defense."
		knight_item.cost = 12.0
		knight_item.tower_stats = knight_stats
		knight_item.icon = knight_stats.texture
		items.append(knight_item)
	if rook_stats:
		var rook_item = MetaShopItemData.new()
		rook_item.id = "meta_rook"
		rook_item.display_name = "Rook Sentinel"
		rook_item.description = "Unlocks a Rook unit with heavy bolts."
		rook_item.cost = 15.0
		rook_item.tower_stats = rook_stats
		rook_item.icon = rook_stats.texture
		items.append(rook_item)
	if bishop_stats:
		var bishop_item = MetaShopItemData.new()
		bishop_item.id = "meta_bishop"
		bishop_item.display_name = "Bishop Sage"
		bishop_item.description = "Unlocks a Bishop with arcane artillery."
		bishop_item.cost = 14.0
		bishop_item.tower_stats = bishop_stats
		bishop_item.icon = bishop_stats.texture
		items.append(bishop_item)
	if items.size() > 0:
		meta_items = items

func get_all_meta_items() -> Array[MetaShopItemData]:
	return meta_items

func get_unlocked_tower_paths() -> Array[String]:
	return unlocked_unit_paths.duplicate()

func is_item_unlocked(item: MetaShopItemData) -> bool:
	return unlocked_item_ids.has(item.id)

func attempt_purchase(item_id: String, king_manager: KingManager) -> bool:
	var item = _find_item(item_id)
	if item == null:
		push_warning("MetaShopManager: Item %s not found." % item_id)
		return false
	if unlocked_item_ids.has(item.id):
		return false
	if king_manager == null:
		return false
	if item.cost > 0.0 and not king_manager.can_afford(item.cost):
		return false
	if not king_manager.spend_royal_decree(item.cost):
		return false
	_unlock_item(item)
	return true

func _find_item(item_id: String) -> MetaShopItemData:
	for data in meta_items:
		if data and data.id == item_id:
			return data
	return null

func _unlock_item(item: MetaShopItemData) -> void:
	unlocked_item_ids.append(item.id)
	if item.tower_stats:
		var path = item.tower_stats.resource_path
		if path and not unlocked_unit_paths.has(path):
			unlocked_unit_paths.append(path)
	meta_item_purchased.emit(item)
