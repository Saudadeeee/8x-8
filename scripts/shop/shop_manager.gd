extends Node
class_name ShopPanelManager

signal shop_item_purchased(item_data: ShopItemData)
signal shop_purchase_failed(item_id: String, reason: String)
signal unit_stock_changed(stats_id: String, amount: int)
signal shop_offers_refreshed(items: Array)

@export var shop_items: Array[ShopItemData] = []

# 5 chu khong 4: quay nay con phai chua o nguyen to (pity), trang bi va di vat.
# Voi 4 o, ba loai do chiem het cho va co luot KHONG CON QUAN NAO de mua —
# nguoi choi khong the dat thap ca wave do.
const SHOP_SLOT_COUNT: int = 5

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

# ── Giá xáo shop ──────────────────────────────────────────────────────────
# 2 vàng là quá rẻ để làm gì: đo thực tế cho thấy người chơi tồn hơn 1200 vàng ở
# wave 9 mà không có chỗ tiêu. Xáo shop CHÍNH LÀ nơi tiêu số vàng dư đó — trả
# tiền để đào đúng món mình cần. Giá tăng dần trong CÙNG một phiên shop rồi reset
# ở phiên sau, nên xáo một hai lần thì rẻ, xáo lì thì đắt dần.
const REROLL_COST: int = 10
const REROLL_COST_STEP: int = 6
const REROLL_COST_MAX: int = 40

var _rerolls_this_phase: int = 0

func get_reroll_cost() -> int:
	return mini(REROLL_COST + _rerolls_this_phase * REROLL_COST_STEP, REROLL_COST_MAX)

## PhaseController gọi khi mở phiên shop mới — giá xáo về mức nền.
func reset_reroll_cost() -> void:
	_rerolls_this_phase = 0

# Troop wave gates: boss troops locked until wave 4 (Summer season),
# content-pack-2 towers (longbowman/paladin/alchemist/ice_guardian/ballista) from wave 2.
const BOSS_TROOP_MIN_WAVE: Dictionary = {
	"queen": 4, "commander": 4, "warlock": 4, "catapult": 4, "dark_mage": 4,
	"longbowman": 2, "paladin": 2, "alchemist": 2, "ice_guardian": 2, "ballista": 2,
}

var active_shop_offers: Array[ShopItemData] = []
var unit_stock: Dictionary = {}
var unit_stats_registry: Dictionary = {}
var limited_units: Dictionary = {}
var current_wave: int = 1

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

func refresh_shop(is_free: bool = false) -> void:
	# Tiền do game_map.attempt_shop_reroll() trừ TRƯỚC khi gọi vào đây.
	if not is_free:
		_rerolls_this_phase += 1
	_roll_shop_offers()
	shop_offers_refreshed.emit(active_shop_offers.duplicate())

## Giá thực trả sau giảm giá. Hiện chỉ ô lãnh thổ/nguyên tố được giảm
## (di vật "Địa Chất Sư", perk "Địa Chủ"); các loại khác trả nguyên giá.
## HUD gọi cùng hàm này để số hiển thị luôn khớp số bị trừ.
func effective_cost(item: ShopItemData) -> float:
	if item == null:
		return 0.0
	if item.item_type != ShopItemData.ItemType.TERRITORY \
			and item.item_type != ShopItemData.ItemType.EQUIPMENT:
		return item.cost
	# ShopPanelManager không nằm trong cây scene → không dùng được get_node_or_null
	# của chính nó; đi vòng qua SceneTree gốc.
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return item.cost
	var gm: Node = (loop as SceneTree).root.get_node_or_null("GameManagerSingleton")
	if gm == null:
		return item.cost
	# Gán từng nhánh chứ không dùng ternary: literal mảng trong ternary suy ra
	# kiểu `Array` (không phải `Array[String]`) và Godot từ chối gán.
	var fields: Array[String] = ["perk_equip_discount"]
	if item.item_type == ShopItemData.ItemType.TERRITORY:
		fields = ["relic_tile_discount", "perk_tile_discount"]
	var discount := 0.0
	for field in fields:
		var value: Variant = gm.get(field)
		if value is int or value is float:
			discount += maxf(0.0, float(value))
	return maxf(0.0, item.cost * (1.0 - clampf(discount, 0.0, 0.85)))

func attempt_purchase(item_id: String, king_manager: KingManager) -> bool:
	var item = _find_item(item_id)
	if item == null:
		shop_purchase_failed.emit(item_id, "Mục hàng không tồn tại.")
		return false
	if king_manager == null:
		shop_purchase_failed.emit(item_id, "Chưa chọn vua.")
		return false
	var price: float = effective_cost(item)
	if price > 0.0 and not king_manager.can_afford(price):
		shop_purchase_failed.emit(item_id, "Royal Decree không đủ.")
		return false
	if not king_manager.spend_royal_decree(price):
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
					# Thu tu: texture trong .tres -> assets/towers/<id>.png ->
					# projectile_texture. Nho buoc giua, tac gia noi dung chi can
					# tha mot PNG dung ten id la card shop co anh ngay.
					item.icon = stats.texture
					if item.icon == null:
						item.icon = HudIcons.tower(stats.id)
					if item.icon == null:
						item.icon = stats.projectile_texture
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
	# Tên + giá ở đây; MÔ TẢ lấy thẳng từ TerritoryManager.BIOME_STATS để không bao
	# giờ lệch với chỉ số thật (bảng cũ viết cứng "+6 Sát thương" và đã lệch sau
	# khi buff ô chuyển sang phần trăm).
	var biome_defs = [
		{"id": "territory_fire",    "name": "Mạch Hoả",  "cost": 3.0, "tag": "fire"},
		{"id": "territory_swamp",   "name": "Mạch Thuỷ", "cost": 2.0, "tag": "swamp"},
		{"id": "territory_ice",     "name": "Mạch Băng", "cost": 2.5, "tag": "ice"},
		{"id": "territory_forest",  "name": "Mạch Độc",  "cost": 2.5, "tag": "forest"},
		{"id": "territory_desert",  "name": "Mạch Thổ",  "cost": 2.5, "tag": "desert"},
		{"id": "territory_thunder", "name": "Mạch Lôi",  "cost": 3.0, "tag": "thunder"},
	]
	for bd in biome_defs:
		bd["desc"] = str((TerritoryManager.BIOME_STATS.get(bd["tag"], {}) as Dictionary)
			.get("desc", ""))

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

# ── Trang bị & Di vật trong shop ──────────────────────────────────────────
# Shop tiêu Royal Decree, còn catalog trang bị/di vật ghi giá bằng VÀNG (dùng
# cho giá bán lại). Quy đổi bằng hai hằng dưới thay vì viết hai bảng giá — một
# nguồn số liệu, chỉnh cân bằng ở một chỗ.
const EQUIP_GOLD_PER_RD: float = 40.0
const RELIC_GOLD_PER_RD: float = 60.0
## Wave tối thiểu để di vật xuất hiện — di vật đổi luật chơi, ra sớm quá thì
## run bị quyết định trước khi người chơi kịp hiểu bàn cờ.
const RELIC_MIN_WAVE: int = 5

var equipment_system: Node = null
var relic_system: Node = null

## game_map gắn hai hệ này sau khi tạo. Không gắn → shop chạy y như cũ.
func setup_item_systems(equipment: Node, relics: Node) -> void:
	equipment_system = equipment
	relic_system = relics

## Wave tối thiểu bật pity — trước đó người chơi chưa có build để mà "khớp".
const PITY_MIN_WAVE: int = 3
## Ô lãnh thổ pity: từ wave này, quầy luôn có ≥1 ô khớp nguyên tố đang mạnh nhất.
## Lý do tồn tại (futureplan §6.2): không ai được chết vì shop không ra đồ.
var _pity_element_provider: Callable = Callable()

## game_map gắn hàm trả về nguyên tố người chơi đang có nhiều tháp nhất.
func set_pity_element_provider(provider: Callable) -> void:
	_pity_element_provider = provider

func _dominant_element() -> String:
	if not _pity_element_provider.is_valid():
		return ""
	var value = _pity_element_provider.call()
	return str(value) if value is String else ""

## Ô lãnh thổ khớp nguyên tố đang mạnh nhất — chèn vào quầy khi pity bật.
## Trả null nếu chưa đủ wave, chưa có build, hoặc quầy đã có sẵn ô đó.
func _make_pity_tile_offer() -> ShopItemData:
	if current_wave < PITY_MIN_WAVE:
		return null
	var element := _dominant_element()
	if element.is_empty():
		return null
	var biome: String = TerritoryManager.biome_of_element(element)
	if biome.is_empty():
		return null
	for existing in shop_items:
		if existing and existing.item_type == ShopItemData.ItemType.TERRITORY \
				and existing.territory_tag == biome:
			return existing
	return null

## Lay mot the TROOP ngau nhien trong danh sach ung vien (da loc theo min_wave).
## Tra null neu khong con quan nao hop le — luc do quay danh chiu, nhung it nhat
## khong phai do cac loai hang khac chen cho.
func _pick_guaranteed_troop(candidates: Array) -> ShopItemData:
	var troops: Array[ShopItemData] = []
	for item in candidates:
		if item != null and item.item_type == ShopItemData.ItemType.TROOP:
			troops.append(item)
	if troops.is_empty():
		return null
	return troops[randi() % troops.size()]

func _make_equipment_offer() -> ShopItemData:
	if equipment_system == null or not is_instance_valid(equipment_system):
		return null
	var id: String = str(equipment_system.call("roll_random"))
	if id.is_empty():
		return null
	var data: Dictionary = equipment_system.call("item_data", id)
	if data.is_empty():
		return null
	var item := ShopItemData.new()
	item.id = "equip_%s" % id
	item.catalog_id = id
	item.item_type = ShopItemData.ItemType.EQUIPMENT
	item.display_name = str(data.get("name", id))
	item.description = str(data.get("desc", ""))
	item.cost = maxf(1.0, ceil(float(data.get("cost", 80)) / EQUIP_GOLD_PER_RD))
	# Icon 32x32 theo id — thieu file thi card tu roi ve nhan chu, khong vo UI.
	item.icon = HudIcons.equipment(id)
	return item

func _make_relic_offer() -> ShopItemData:
	if relic_system == null or not is_instance_valid(relic_system):
		return null
	if bool(relic_system.call("is_full")):
		return null
	var id: String = str(relic_system.call("roll_random"))
	if id.is_empty():
		return null
	var data: Dictionary = relic_system.call("relic_data", id)
	if data.is_empty():
		return null
	var item := ShopItemData.new()
	item.id = "relic_%s" % id
	item.catalog_id = id
	item.item_type = ShopItemData.ItemType.RELIC
	item.display_name = "★ %s" % str(data.get("name", id))
	item.description = str(data.get("desc", ""))
	item.cost = maxf(2.0, ceil(float(data.get("cost", 200)) / RELIC_GOLD_PER_RD))
	item.icon = HudIcons.relic(id)
	return item

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

	# Vật phẩm chiếm ô TRƯỚC: bốc sau cùng thì gần như luôn hết chỗ, và trang bị
	# chính là thứ mở khoá lối chơi — không thấy nó thì build không thành hình.
	# BAO DAM MOT QUAN moi luot roll. Khong co dong nay thi cac loai hang khac
	# (o nguyen to / trang bi / di vat / nang cap) co the chiem sach quay va
	# nguoi choi khong mua duoc thap nao ca wave.
	var troop_offer := _pick_guaranteed_troop(unit_candidates)
	if troop_offer != null:
		active_shop_offers.append(troop_offer)
		unit_candidates.erase(troop_offer)

	# Pity ĐẦU TIÊN: đây là ô được bảo đảm, mọi thứ khác chỉ lấp chỗ còn lại.
	var pity_offer := _make_pity_tile_offer()
	if pity_offer != null:
		active_shop_offers.append(pity_offer)
		unit_candidates.erase(pity_offer)   # không để nó ra hai lần trong cùng quầy

	var equip_offer := _make_equipment_offer()
	if equip_offer != null:
		active_shop_offers.append(equip_offer)
	if current_wave >= RELIC_MIN_WAVE:
		var relic_offer := _make_relic_offer()
		if relic_offer != null:
			active_shop_offers.append(relic_offer)

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
