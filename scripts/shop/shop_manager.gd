extends Node
class_name ShopPanelManager

signal shop_item_purchased(item_data: ShopItemData)
signal shop_purchase_failed(item_id: String, reason: String)
signal unit_stock_changed(stats_id: String, amount: int)
signal shop_offers_refreshed(items: Array)

@export var shop_items: Array[ShopItemData] = []

const SHOP_SLOT_COUNT: int = 4

# Tower stats paths — only needed for upgrade items that reference a specific tower
const TOWER_PATHS := {
	"pawn":   "res://res/towers/pawn.tres",
	"knight": "res://res/towers/knight.tres",
}

# Territory biome icon paths
const BIOME_ICON_PATHS := {
	"fire":    "res://assets/ui/shop_icons/icon_fire.png",
	"swamp":   "res://assets/ui/shop_icons/icon_swamp.png",
	"ice":     "res://assets/ui/shop_icons/icon_ice.png",
	"forest":  "res://assets/ui/shop_icons/icon_forest.png",
	"desert":  "res://assets/ui/shop_icons/icon_desert.png",
	"thunder": "res://assets/ui/shop_icons/icon_thunder.png",
}
const DISMISS_ICON_PATH := "res://assets/ui/shop_icons/icon_dismiss.png"

const REROLL_COST: int = 2

# Boss troops that are locked until wave 4 (Summer season)
const BOSS_TROOP_MIN_WAVE: Dictionary = {
	"queen": 4, "commander": 4, "warlock": 4, "catapult": 4, "dark_mage": 4
}

var active_shop_offers: Array[ShopItemData] = []
var unit_stock: Dictionary = {}
var unit_stats_registry: Dictionary = {}
var limited_units: Dictionary = {}
var current_wave: int = 1

func get_reroll_cost() -> int:
	return REROLL_COST

func remove_from_active_offers(item_id: String) -> void:
	for i in range(active_shop_offers.size() - 1, -1, -1):
		if active_shop_offers[i] and active_shop_offers[i].id == item_id:
			active_shop_offers.remove_at(i)
			break
	shop_offers_refreshed.emit(active_shop_offers.duplicate())

func update_wave(wave: int) -> void:
	current_wave = wave

func _ready() -> void:
	if shop_items.is_empty():
		_populate_default_items()
	refresh_shop(true)

func get_items() -> Array[ShopItemData]:
	return active_shop_offers

func refresh_shop(_is_free: bool = false) -> void:
	# Gold cost is handled by game_map.attempt_shop_reroll() before this is called.
	_roll_shop_offers()
	shop_offers_refreshed.emit(active_shop_offers.duplicate())

func attempt_purchase(item_id: String, king_manager: KingManager) -> bool:
	var item = _find_item(item_id)
	if item == null:
		shop_purchase_failed.emit(item_id, "Mục hàng không tồn tại.")
		return false
	if king_manager == null:
		shop_purchase_failed.emit(item_id, "Chưa chọn vua.")
		return false
	if item.cost > 0.0 and not king_manager.can_afford(item.cost):
		shop_purchase_failed.emit(item_id, "Royal Decree không đủ.")
		return false
	if not king_manager.spend_royal_decree(item.cost):
		shop_purchase_failed.emit(item_id, "Không thể trừ Royal Decree.")
		return false
	shop_item_purchased.emit(item)
	return true

func register_troop_purchase(stats: TowerStats) -> void:
	if stats == null:
		return
	var key = stats.id
	var count = unit_stock.get(key, 0) + 1
	unit_stock[key] = count
	unit_stats_registry[key] = stats
	limited_units[key] = true
	unit_stock_changed.emit(key, count)

func get_unit_stock_amount(stats_id: String) -> int:
	return unit_stock.get(stats_id, 0)

func get_unit_stock_items() -> Dictionary:
	return unit_stock.duplicate()

func get_tower_stats_by_id(stats_id: String) -> TowerStats:
	return unit_stats_registry.get(stats_id, null)

func is_unit_limited(stats_id: String) -> bool:
	return limited_units.get(stats_id, false)

func consume_unit_stock(stats_id: String) -> bool:
	if not unit_stock.has(stats_id) or unit_stock[stats_id] <= 0:
		return false
	unit_stock[stats_id] -= 1
	unit_stock_changed.emit(stats_id, unit_stock[stats_id])
	if unit_stock[stats_id] == 0:
		unit_stats_registry.erase(stats_id)
		unit_stock.erase(stats_id)
	return true

func reset_unit_stock() -> void:
	for stats_id in unit_stock.keys():
		unit_stock_changed.emit(stats_id, 0)
	unit_stock.clear()
	unit_stats_registry.clear()
	limited_units.clear()

# Thực thi mua hàng (đã kiểm tra tiền từ bên ngoài — game_map)
func execute_purchase(item_id: String) -> bool:
	var item = _find_item(item_id)
	if item == null:
		return false
	shop_item_purchased.emit(item)
	return true

func get_item_by_id(item_id: String) -> ShopItemData:
	return _find_item(item_id)

func _find_item(item_id: String) -> ShopItemData:
	for data in active_shop_offers:
		if data and data.id == item_id:
			return data
	return null

func _populate_default_items() -> void:
	var dismiss_icon = load(DISMISS_ICON_PATH) as Texture2D

	# --- TROOP ITEMS (Gold) — auto-discovered from res://res/towers/*.tres ---
	var dir = DirAccess.open("res://res/towers/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var stats = load("res://res/towers/" + file) as TowerStats
				if stats:
					var item = ShopItemData.new()
					item.id = stats.id + "_buy"
					item.display_name = stats.name
					item.description = stats.description
					item.cost = float(stats.cost)
					item.use_royal_decree = false
					item.icon = stats.texture if stats.texture else stats.projectile_texture
					item.item_type = ShopItemData.ItemType.TROOP
					item.tower_stats = stats
					item.min_wave = BOSS_TROOP_MIN_WAVE.get(stats.id, 1)
					shop_items.append(item)
			file = dir.get_next()
		dir.list_dir_end()

	# --- UPGRADE ITEMS (Gold) ---
	var pawn_stats = load(TOWER_PATHS["pawn"]) as TowerStats
	if pawn_stats:
		var u1 = ShopItemData.new()
		u1.id = "pawn_training"
		u1.display_name = "Pawn Strike Training"
		u1.description = "+5 Damage cho tất cả Pawn trên bàn."
		u1.cost = 8.0
		u1.use_royal_decree = false
		u1.icon = pawn_stats.texture
		u1.item_type = ShopItemData.ItemType.UPGRADE
		u1.tower_stats = pawn_stats
		u1.upgrade_damage_bonus = 5
		u1.upgrade_description = "+5 Damage cho Pawn"
		shop_items.append(u1)

		var u2 = ShopItemData.new()
		u2.id = "pawn_quickness"
		u2.display_name = "Pawn Field Drills"
		u2.description = "-0.15s Cooldown cho tất cả Pawn trên bàn."
		u2.cost = 8.0
		u2.use_royal_decree = false
		u2.icon = pawn_stats.texture
		u2.item_type = ShopItemData.ItemType.UPGRADE
		u2.tower_stats = pawn_stats
		u2.upgrade_attack_speed_reduction = 0.15
		u2.upgrade_description = "-0.15s Cooldown cho Pawn"
		shop_items.append(u2)

	var knight_stats = load(TOWER_PATHS["knight"]) as TowerStats
	if knight_stats:
		var u3 = ShopItemData.new()
		u3.id = "knight_training"
		u3.display_name = "Knight Rage Drills"
		u3.description = "+6 Damage cho tất cả Knight trên bàn."
		u3.cost = 12.0
		u3.use_royal_decree = false
		u3.icon = knight_stats.texture
		u3.item_type = ShopItemData.ItemType.UPGRADE
		u3.tower_stats = knight_stats
		u3.upgrade_damage_bonus = 6
		u3.upgrade_description = "+6 Damage cho Knight"
		u3.min_wave = 2
		shop_items.append(u3)

		var u4 = ShopItemData.new()
		u4.id = "knight_quickstep"
		u4.display_name = "Knight Quickstep"
		u4.description = "-0.18s Cooldown cho tất cả Knight trên bàn."
		u4.cost = 11.0
		u4.use_royal_decree = false
		u4.icon = knight_stats.texture
		u4.item_type = ShopItemData.ItemType.UPGRADE
		u4.tower_stats = knight_stats
		u4.upgrade_attack_speed_reduction = 0.18
		u4.upgrade_description = "-0.18s Cooldown cho Knight"
		u4.min_wave = 2
		shop_items.append(u4)

	# --- TERRITORY ITEMS (Royal Decree) ---
	var biome_defs = [
		{"id": "territory_fire",    "name": "Hỏa Địa",    "cost": 3.0, "tag": "fire",    "desc": "Vùng đất lửa: quân đứng đây được +6 Sát thương."},
		{"id": "territory_swamp",   "name": "Đầm Lầy",    "cost": 2.0, "tag": "swamp",   "desc": "Đầm lầy: quân đứng đây được -0.2s Cooldown tấn công."},
		{"id": "territory_ice",     "name": "Băng Nguyên", "cost": 2.5, "tag": "ice",     "desc": "Băng tuyết: quân đứng đây được +2 Tầm bắn."},
		{"id": "territory_forest",  "name": "Rừng Rậm",   "cost": 2.5, "tag": "forest",  "desc": "Rừng rậm: quân đứng đây được +3 Sát thương và +1 Tầm."},
		{"id": "territory_desert",  "name": "Sa Mạc",      "cost": 2.5, "tag": "desert",  "desc": "Sa mạc: quân đứng đây được +4 Sát thương và -0.1s CD."},
		{"id": "territory_thunder", "name": "Lôi Vực",    "cost": 3.0, "tag": "thunder", "desc": "Vùng sấm sét: quân đứng đây được +3 Sát thương và +1 Tầm."},
	]
	for bd in biome_defs:
		var ti = ShopItemData.new()
		ti.id = bd["id"]
		ti.display_name = bd["name"]
		ti.description = bd["desc"]
		ti.cost = bd["cost"]
		ti.use_royal_decree = true
		ti.icon = load(BIOME_ICON_PATHS[bd["tag"]]) as Texture2D
		ti.item_type = ShopItemData.ItemType.TERRITORY
		ti.territory_tag = bd["tag"]
		shop_items.append(ti)

	# --- DISMISS ITEM (Free — reward comes from tower sold) ---
	var dismiss_item = ShopItemData.new()
	dismiss_item.id = "dismiss_order"
	dismiss_item.display_name = "Dismiss Order"
	dismiss_item.description = "Giải tán một tháp, hoàn trả 50% giá trị Vàng."
	dismiss_item.cost = 0.0
	dismiss_item.use_royal_decree = false
	dismiss_item.item_type = ShopItemData.ItemType.DISMISS
	dismiss_item.icon = dismiss_icon
	shop_items.append(dismiss_item)

func _roll_shop_offers() -> void:
	active_shop_offers.clear()
	var unit_candidates: Array[ShopItemData] = []
	var upgrade_candidates: Array[ShopItemData] = []
	for item in shop_items:
		if not item:
			continue
		# Tier gate: hide items that require a later wave
		if item.min_wave > current_wave:
			continue
		match item.item_type:
			ShopItemData.ItemType.UPGRADE:
				upgrade_candidates.append(item)
			ShopItemData.ItemType.TROOP, ShopItemData.ItemType.TERRITORY, ShopItemData.ItemType.DISMISS:
				unit_candidates.append(item)
			_:
				unit_candidates.append(item)
	unit_candidates.shuffle()
	upgrade_candidates.shuffle()
	var pick_upgrade = randi() % 2 == 0
	while active_shop_offers.size() < SHOP_SLOT_COUNT and (unit_candidates.size() + upgrade_candidates.size()) > 0:
		if pick_upgrade and upgrade_candidates.size() > 0:
			active_shop_offers.append(upgrade_candidates.pop_back())
		elif unit_candidates.size() > 0:
			active_shop_offers.append(unit_candidates.pop_back())
		elif upgrade_candidates.size() > 0:
			active_shop_offers.append(upgrade_candidates.pop_back())
		else:
			break
		pick_upgrade = !pick_upgrade
	if active_shop_offers.is_empty() and shop_items.size() > 0:
		active_shop_offers.append(shop_items[0])
