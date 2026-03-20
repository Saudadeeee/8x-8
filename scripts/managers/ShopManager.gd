# res://scripts/managers/ShopManager.gd
# Quản lý hệ thống Shop (Cửa hàng).
extends Node
class_name ShopManager

# --- SIGNALS ---
signal shop_refreshed(items: Array)
signal item_purchased(item: Resource)
signal soldier_dismissed(soldier: Node)

# --- CẤU HÌNH ---
@export var shop_size: int = 5                      # Số slot trong shop
@export var reroll_cost: int = 2                    # Chi phí refresh shop (vàng)
@export var all_soldiers: Array[Resource] = []      # Pool quân có thể mua
@export var all_territories: Array[Resource] = []   # Pool lãnh thổ có thể mua

# --- RUNTIME ---
var current_shop_items: Array[Resource] = []        # Các item đang hiển thị
var shop_tier: int = 1                              # Tier shop tăng theo wave

# --- MỞ SHOP ---
func open_shop() -> void:
	GameManagerSingleton.change_state(GameManagerSingleton.GameState.SHOP)
	if current_shop_items.is_empty():
		refresh_shop()

func close_shop() -> void:
	GameManagerSingleton.change_state(GameManagerSingleton.GameState.PREPARING)

# --- LÀM MỚI SHOP ---
func refresh_shop(free: bool = false) -> void:
	if not free:
		if not GameManagerSingleton.spend_gold(reroll_cost):
			push_warning("ShopManager: Không đủ vàng để refresh!")
			return
	current_shop_items = _generate_shop_items()
	shop_refreshed.emit(current_shop_items)

func _generate_shop_items() -> Array:
	var items = []
	var pool = _get_available_pool()
	pool.shuffle()
	for i in range(min(shop_size, pool.size())):
		items.append(pool[i])
	return items

func _get_available_pool() -> Array:
	var pool: Array = []

	# Lấy danh sách unlock từ MetaProgress
	var gm = get_node_or_null("/root/GameManagerSingleton")
	var meta: MetaProgress = gm.meta_progress if gm else null
	var unlocked_ids: Array = meta.unlocked_soldier_ids if meta else []

	for s in all_soldiers:
		var stats := s as SoldierStats
		if not stats:
			continue
		# Nếu có danh sách unlock và unit chưa unlock → bỏ qua
		if unlocked_ids.size() > 0 and not stats.id in unlocked_ids:
			continue
		pool.append(s)

	for t in all_territories:
		pool.append(t)

	return pool

# --- MUA VẬT PHẨM ---
func purchase_soldier(stats: SoldierStats) -> bool:
	if not GameManagerSingleton.spend_gold(stats.gold_cost):
		return false
	current_shop_items.erase(stats)
	item_purchased.emit(stats)
	return true

func purchase_territory(stats: TerritoryStats) -> bool:
	if not GameManagerSingleton.spend_gold(stats.purchase_cost):
		return false
	current_shop_items.erase(stats)
	item_purchased.emit(stats)
	return true

# --- ĐUỔI QUÂN (DISMISS) ---
func dismiss_soldier(soldier: Node, stats: SoldierStats) -> void:
	if not soldier or not stats:
		push_warning("ShopManager: dismiss_soldier nhận null soldier hoặc stats.")
		return
	GameManagerSingleton.add_gold(stats.sell_value)
	# Signal này được lắng nghe bởi game_map.gd (hoặc scene tương đương)
	# để thực hiện: xóa khỏi grid_data, gọi SynergyManager.on_tower_removed(), queue_free()
	soldier_dismissed.emit(soldier)
