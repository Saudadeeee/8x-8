# res://scripts/items/equipment_system.gd
# HỆ TRANG BỊ — 2 ô mỗi tháp, vĩnh viễn trong run (futureplan.md §3.2).
#
# Khác thuốc (dùng một lần, theo vùng) và perk (toàn cục): trang bị gắn vào MỘT
# tháp cụ thể và ở đó tới khi tháp bị bán. Đây là nhóm vật phẩm mở khoá lối chơi —
# "6 tháp trên ô Hoả" chỉ thành build khi có Nhẫn Cộng Hưởng / Hộ Phù Thợ Săn.
#
# KIẾN TRÚC — vì sao gộp rồi mới đẩy xuống tháp:
#   tower.apply_equipment_buff(dict) nhận MỘT dict đã gộp, không phải từng món.
#   Tháp chỉ có một BuffLayer.EQUIP; nếu gọi hai lần cho hai món thì món sau ghi
#   đè món trước. Nơi gộp là `_aggregate()` ở đây.
#
# Nội dung: `ITEMS` built-in là bản dự phòng, `res://data/equipment/*.json`
# ghi đè theo `id` — cùng quy ước với PerkSystem/PotionSystem.
#
# Là child node của game_map → tự reset mỗi run mới khi scene reload.
extends Node
class_name EquipmentSystem

# ── Signals ────────────────────────────────────────────────────────────────
## Kho (món chưa gắn) thay đổi. `inventory` là Array[String] các id.
signal inventory_changed(inventory: Array)
## Trang bị của một tháp thay đổi — HUD mở panel tháp đó thì vẽ lại.
signal tower_equipment_changed(tower: Node, ids: Array)

# ── Hằng số ────────────────────────────────────────────────────────────────
## Số ô trang bị mặc định mỗi tháp. Di Vật "Anvil of the Gods" nâng lên 3.
const BASE_SLOTS: int = 2
## Trần kho — vượt thì món mới bị chặn (báo qua `add_item` trả false).
const MAX_INVENTORY: int = 12
const CUSTOM_DIR: String = "res://data/equipment/"
## Nguồn CHÍNH: file .tres mở được bằng Inspector. JSON và bảng cứng bên dưới
## chỉ còn là tương thích ngược / lưới an toàn.
const RES_DIR: String = "res://res/equipment/"

const RARITY_WEIGHTS: Dictionary = {
	"common": 55, "rare": 28, "epic": 14, "legendary": 3,
}

## Khoá `effect` engine hiểu. Món khai khoá ngoài danh sách này bị bỏ qua
## kèm push_warning — sai chính tả trong JSON không được im lặng trôi qua.
const EFFECT_KEYS: Array[String] = [
	"damage_flat", "damage_pct", "speed_bonus", "range_bonus",
	"reaction_power_mult", "mark_duration_mult", "element_secondary",
	"grant_element", "crit_bonus", "projectile_bonus", "pierce_armor",
	"bonus_vs_full", "bonus_vs_low", "bonus_vs_marked", "stun_chance",
	"pierce_targets", "lifesteal", "reaction_radius_bonus", "cooldown_refund",
	"immune_disable", "conduit", "dual_vessel", "growth_per_wave",
]

# ── Nội dung built-in (20 món) ─────────────────────────────────────────────
# `slot`: "weapon" | "accessory" | "base" — thuần phân loại cho UI, engine
# KHÔNG ràng buộc ô nào lắp loại nào (2 ô đều lắp được mọi món).
const ITEMS: Array[Dictionary] = [
	# --- VŨ KHÍ: đổi cách đánh ---
	{
		"id": "piercing_bow", "name": "Piercing Bow", "slot": "weapon",
		"rarity": "rare", "cost": 90,
		"desc": "Every shot pierces 2 more enemies behind the target.",
		"effect": {"pierce_targets": 2},
	},
	{
		"id": "quake_hammer", "name": "Quake Hammer", "slot": "weapon",
		"rarity": "rare", "cost": 95,
		"desc": "20% of hits stun for 0.5s.",
		"effect": {"stun_chance": 0.2},
	},
	{
		"id": "repeater", "name": "Repeater", "slot": "weapon",
		"rarity": "rare", "cost": 85,
		"desc": "-40% damage, double attack speed. A Mark-applying machine.",
		"effect": {"damage_pct": -0.4, "speed_bonus": 0.5},
	},
	{
		"id": "armor_axe", "name": "Armor Axe", "slot": "weapon",
		"rarity": "common", "cost": 65,
		"desc": "Ignores all target armor.",
		"effect": {"pierce_armor": true},
	},
	{
		"id": "hunt_javelin", "name": "Hunting Javelin", "slot": "weapon",
		"rarity": "common", "cost": 60,
		"desc": "+60% damage against enemies at full HP.",
		"effect": {"bonus_vs_full": 0.6},
	},
	{
		"id": "finisher_mace", "name": "Finisher Mace", "slot": "weapon",
		"rarity": "rare", "cost": 80,
		"desc": "+100% damage against enemies below 25% HP.",
		"effect": {"bonus_vs_low": 1.0},
	},
	{
		"id": "vampire_blade", "name": "Vampiric Blade", "slot": "weapon",
		"rarity": "epic", "cost": 130,
		"desc": "Each kill restores 1 HP to the King (max 3 per wave).",
		"effect": {"lifesteal": 1},
	},
	# --- PHỤ KIỆN: khuếch đại nguyên tố (nhóm mở khoá lối chơi) ---
	{
		"id": "resonance_ring", "name": "Resonance Ring", "slot": "accessory",
		"rarity": "epic", "cost": 140,
		"desc": "Reactions triggered by this piece deal +50% damage.",
		"effect": {"reaction_power_mult": 1.5},
	},
	{
		"id": "conductor_stone", "name": "Conductor Stone", "slot": "accessory",
		"rarity": "rare", "cost": 100,
		"desc": "Marks applied by this piece last twice as long.",
		"effect": {"mark_duration_mult": 2.0},
	},
	{
		"id": "hunter_charm", "name": "Hunter's Charm", "slot": "accessory",
		"rarity": "rare", "cost": 105,
		"desc": "+30% damage against marked enemies.",
		"effect": {"bonus_vs_marked": 0.3},
	},
	{
		"id": "storm_eye", "name": "Storm Eye", "slot": "accessory",
		"rarity": "epic", "cost": 135,
		"desc": "Every reaction from this piece gains +1m radius.",
		"effect": {"reaction_radius_bonus": 1.0},
	},
	{
		"id": "reverse_clock", "name": "Reverse Clock", "slot": "accessory",
		"rarity": "epic", "cost": 125,
		"desc": "Each nearby reaction cuts this piece's cooldown by 0.1s.",
		"effect": {"cooldown_refund": 0.1},
	},
	{
		"id": "vein_conduit", "name": "Ley Conduit", "slot": "accessory",
		"rarity": "rare", "cost": 110,
		"desc": "On a plain square, still gains the Mark of an ADJACENT vein.",
		"effect": {"conduit": true},
	},
	{
		"id": "dual_vessel", "name": "Dual Vessel", "slot": "accessory",
		"rarity": "legendary", "cost": 190,
		"desc": "Also applies the Mark of an adjacent vein - triggering reactions on its own.",
		"effect": {"dual_vessel": true},
	},
	{
		"id": "element_staff", "name": "Element Staff", "slot": "accessory",
		"rarity": "epic", "cost": 145,
		"desc": "Always fires Fire Marks regardless of the square below.",
		"effect": {"grant_element": "fire"},
	},
	{
		"id": "focus_lens", "name": "Focus Lens", "slot": "accessory",
		"rarity": "common", "cost": 70,
		"desc": "+12% critical chance.",
		"effect": {"crit_bonus": 0.12},
	},
	# --- NỀN TẢNG ---
	{
		"id": "solid_base", "name": "Steadfast Base", "slot": "base",
		"rarity": "rare", "cost": 100,
		"desc": "Immune to boss abilities that disable pieces.",
		"effect": {"immune_disable": true},
	},
	{
		"id": "swivel_base", "name": "Swivel Mount", "slot": "base",
		"rarity": "common", "cost": 60,
		"desc": "+1 reach.",
		"effect": {"range_bonus": 1},
	},
	{
		"id": "ancient_roots", "name": "Ancient Roots", "slot": "base",
		"rarity": "epic", "cost": 120,
		"desc": "+5 permanent damage for every wave this piece survives.",
		"effect": {"growth_per_wave": 5.0},
	},
	{
		"id": "lightning_rod", "name": "Lightning Rod", "slot": "base",
		"rarity": "rare", "cost": 95,
		"desc": "Always fires Thunder Marks, and Marks last 50% longer.",
		"effect": {"grant_element": "thunder", "mark_duration_mult": 1.5},
	},
]

# ── Trạng thái ─────────────────────────────────────────────────────────────
## id → dict món (built-in đã trộn JSON).
var _catalog: Dictionary = {}
## Món đang nằm trong kho, chưa gắn tháp nào.
var _inventory: Array[String] = []
## instance_id của tháp → Array[String] id món đang gắn.
var _equipped: Dictionary = {}
## instance_id của tháp → tổng sát thương cộng dồn từ "Ancient Roots".
var _growth: Dictionary = {}
## Số ô mỗi tháp — Di Vật "Anvil of the Gods" nâng lên.
var slots_per_tower: int = BASE_SLOTS
## Giảm giá trang bị trong shop (perk "Wandering Smith"). 0.3 = rẻ 30%.
var shop_discount: float = 0.0

func _ready() -> void:
	_build_catalog()

# ==========================================================================
# CATALOG
# ==========================================================================

func _build_catalog() -> void:
	_catalog.clear()
	for item in ITEMS:
		_catalog[str(item["id"])] = _sanitize(item)
	for item in _load_custom():
		var clean := _sanitize(item)
		if clean.is_empty():
			continue
		_catalog[str(clean["id"])] = clean   # trùng id → JSON thắng

func _load_custom() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(CUSTOM_DIR):
		return out
	var dir := DirAccess.open(CUSTOM_DIR)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(CUSTOM_DIR + file_name)
		if text.is_empty():
			push_warning("EquipmentSystem: không đọc được '%s'" % file_name)
			continue
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Array):
			push_warning("EquipmentSystem: '%s' phải là JSON array" % file_name)
			continue
		for entry in parsed:
			if entry is Dictionary:
				out.append(entry)
	return out

## Chuẩn hoá + loại khoá lạ. Trả `{}` nếu thiếu id (món không dùng được).
func _sanitize(raw: Dictionary) -> Dictionary:
	var id := str(raw.get("id", "")).strip_edges()
	if id.is_empty():
		push_warning("EquipmentSystem: bỏ qua món thiếu 'id'")
		return {}
	var effect_in: Dictionary = raw.get("effect", {}) if raw.get("effect") is Dictionary else {}
	var effect: Dictionary = {}
	for key in effect_in.keys():
		if EFFECT_KEYS.has(str(key)):
			effect[str(key)] = effect_in[key]
		else:
			push_warning("EquipmentSystem: món '%s' có khoá lạ '%s'" % [id, key])
	return {
		"id": id,
		"name": str(raw.get("name", id)),
		"slot": str(raw.get("slot", "accessory")),
		"rarity": str(raw.get("rarity", "common")),
		"cost": maxi(0, int(raw.get("cost", 80))),
		"desc": str(raw.get("desc", "")),
		"effect": effect,
	}

## Dữ liệu một món. `{}` nếu id không tồn tại.
func item_data(id: String) -> Dictionary:
	var found: Variant = _catalog.get(id)
	return (found as Dictionary).duplicate(true) if found is Dictionary else {}

func all_ids() -> Array[String]:
	var out: Array[String] = []
	for key in _catalog.keys():
		out.append(str(key))
	out.sort()
	return out

## Giá sau giảm (perk Thợ Rèn Lang Thang).
func price_of(id: String) -> int:
	var data := item_data(id)
	if data.is_empty():
		return 0
	return maxi(1, int(round(float(data["cost"]) * (1.0 - clampf(shop_discount, 0.0, 0.9)))))

## Bốc ngẫu nhiên theo trọng số độ hiếm. `""` nếu catalog rỗng.
func roll_random() -> String:
	var pool: Array[String] = all_ids()
	if pool.is_empty():
		return ""
	var total := 0
	for id in pool:
		total += int(RARITY_WEIGHTS.get(str(_catalog[id].get("rarity", "common")), 10))
	if total <= 0:
		return pool[randi() % pool.size()]
	var roll := randi() % total
	for id in pool:
		roll -= int(RARITY_WEIGHTS.get(str(_catalog[id].get("rarity", "common")), 10))
		if roll < 0:
			return id
	return pool.back()

# ==========================================================================
# KHO
# ==========================================================================

func inventory() -> Array[String]:
	return _inventory.duplicate()

func add_item(id: String) -> bool:
	if not _catalog.has(id):
		push_warning("EquipmentSystem: không có món '%s'" % id)
		return false
	if _inventory.size() >= MAX_INVENTORY:
		return false
	_inventory.append(id)
	inventory_changed.emit(inventory())
	return true

## Bán món trong kho, hoàn `SELL_REFUND_PCT` giá gốc. Trả số vàng hoàn.
const SELL_REFUND_PCT: float = 0.5

func sell_from_inventory(index: int) -> int:
	if index < 0 or index >= _inventory.size():
		return 0
	var id: String = _inventory[index]
	_inventory.remove_at(index)
	inventory_changed.emit(inventory())
	var refund := int(round(float(item_data(id).get("cost", 0)) * SELL_REFUND_PCT))
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm != null and gm.has_method("add_gold") and refund > 0:
		gm.add_gold(refund)
	return refund

# ==========================================================================
# GẮN / GỠ
# ==========================================================================

## Danh sách id đang gắn trên tháp.
func equipped_on(tower: Node) -> Array[String]:
	var out: Array[String] = []
	if not is_instance_valid(tower):
		return out
	var found: Variant = _equipped.get(tower.get_instance_id())
	if found is Array:
		for id in found:
			out.append(str(id))
	return out

func free_slots(tower: Node) -> int:
	return maxi(0, slots_per_tower - equipped_on(tower).size())

## Gắn món thứ `index` trong kho lên `tower`. Trả false nếu hết ô hoặc index sai.
func equip_from_inventory(tower: Node, index: int) -> bool:
	if not is_instance_valid(tower) or index < 0 or index >= _inventory.size():
		return false
	if free_slots(tower) <= 0:
		return false
	var id: String = _inventory[index]
	_inventory.remove_at(index)
	var key := tower.get_instance_id()
	var list: Array = _equipped.get(key, [])
	list.append(id)
	_equipped[key] = list
	_apply(tower)
	inventory_changed.emit(inventory())
	tower_equipment_changed.emit(tower, equipped_on(tower))
	return true

## Gỡ món ở ô `slot` của tháp, trả về kho.
func unequip(tower: Node, slot: int) -> bool:
	if not is_instance_valid(tower):
		return false
	var key := tower.get_instance_id()
	var list: Array = _equipped.get(key, [])
	if slot < 0 or slot >= list.size():
		return false
	var id: String = str(list[slot])
	list.remove_at(slot)
	_equipped[key] = list
	_inventory.append(id)
	_apply(tower)
	inventory_changed.emit(inventory())
	tower_equipment_changed.emit(tower, equipped_on(tower))
	return true

## Tháp bị bán/xoá → trả hết trang bị về kho. game_map gọi TRƯỚC khi queue_free
## (sau khi free thì không còn đọc được instance_id để tra bảng).
func release_tower(tower: Node) -> void:
	if not is_instance_valid(tower):
		return
	var key := tower.get_instance_id()
	for id in _equipped.get(key, []):
		if _inventory.size() < MAX_INVENTORY:
			_inventory.append(str(id))
	_equipped.erase(key)
	_growth.erase(key)
	inventory_changed.emit(inventory())

## Dọn mục của những tháp đã bị giải phóng mà không qua `release_tower`
## (ví dụ boss xoá tháp). Không dọn thì dict phình theo run.
func prune() -> void:
	for key in _equipped.keys().duplicate():
		if instance_from_id(key) == null:
			_equipped.erase(key)
			_growth.erase(key)

# ==========================================================================
# ÁP HIỆU ỨNG
# ==========================================================================

## Gộp mọi món trên tháp thành MỘT dict rồi đẩy xuống tháp.
## Quy tắc gộp: giá trị cộng thì CỘNG, hệ số nhân thì NHÂN, cờ bool thì OR,
## chuỗi (nguyên tố) thì món SAU thắng — người chơi tự chọn thứ tự lắp.
func _aggregate(tower: Node) -> Dictionary:
	var out: Dictionary = {
		"damage_flat": 0.0, "speed_bonus": 0.0, "range_bonus": 0,
		"reaction_power_mult": 1.0, "mark_duration_mult": 1.0,
		"crit_bonus": 0.0, "projectile_bonus": 0, "pierce_armor": false,
		"bonus_vs_full": 0.0, "bonus_vs_low": 0.0, "bonus_vs_marked": 0.0,
		"stun_chance": 0.0, "pierce_targets": 0, "lifesteal": 0,
		"reaction_radius_bonus": 0.0, "cooldown_refund": 0.0,
		"immune_disable": false, "conduit": false, "dual_vessel": false,
		"element_secondary": "", "grant_element": "",
	}
	var base_damage := 0.0
	var stats: Variant = tower.get("stats")
	if stats != null and stats.get("base_damage") != null:
		base_damage = float(stats.get("base_damage"))

	# Di vật "Armory": trang bị lắp trên MỘT quân áp cho MỌI quân cùng loại.
	# Đây là món đổi luật thật sự — nó biến "chọn con nào để lắp" thành "chọn
	# LOẠI nào để đầu tư", một quyết định khác hẳn.
	var ids: Array[String] = equipped_on(tower)
	var gm_e := get_node_or_null("/root/GameManagerSingleton")
	if gm_e != null and bool(gm_e.relic_equip_share) and stats != null 			and is_inside_tree():
		var my_id := str(stats.get("id"))
		for other in get_tree().get_nodes_in_group("towers"):
			if other == tower or not is_instance_valid(other):
				continue
			var ost: Variant = other.get("stats")
			if ost != null and str(ost.get("id")) == my_id:
				for oid in equipped_on(other):
					if not ids.has(oid):
						ids.append(oid)

	# Di vật "Twin Grip": hai trang bị TRÙNG loại thì nhân thay vì cộng.
	var dup_mult := 1.0
	if gm_e != null and float(gm_e.relic_equip_stack_mult) > 1.0:
		var seen := {}
		for id2 in ids:
			if seen.has(id2):
				dup_mult *= float(gm_e.relic_equip_stack_mult)
			seen[id2] = true

	for id in ids:
		var effect: Dictionary = item_data(id).get("effect", {})
		for key in effect.keys():
			var value: Variant = effect[key]
			match str(key):
				"damage_pct":
					# % quy về giá trị tuyệt đối trên base — cùng quy ước với synergy,
					# nhờ đó BuffLayer.EQUIP vẫn là một lớp CỘNG thuần.
					out["damage_flat"] = float(out["damage_flat"]) + base_damage * float(value)
				"damage_flat", "speed_bonus", "crit_bonus", "bonus_vs_full", \
				"bonus_vs_low", "bonus_vs_marked", "stun_chance", \
				"reaction_radius_bonus", "cooldown_refund":
					out[key] = float(out[key]) + float(value)
				"range_bonus", "projectile_bonus", "pierce_targets", "lifesteal":
					out[key] = int(out[key]) + int(value)
				"reaction_power_mult", "mark_duration_mult":
					out[key] = float(out[key]) * float(value)
				"pierce_armor", "immune_disable", "conduit", "dual_vessel":
					out[key] = bool(out[key]) or bool(value)
				"element_secondary", "grant_element":
					out[key] = str(value)
				"growth_per_wave":
					pass   # cộng dồn ở `_growth`, không lấy từ effect mỗi lần gộp
	out["damage_flat"] = float(out["damage_flat"]) + float(_growth.get(tower.get_instance_id(), 0.0))
	if dup_mult > 1.0:
		# Nhân MỌI trục cộng, không chỉ sát thương — nhiều trang bị chỉ cho tầm
		# hoặc tốc đánh, nhân mỗi damage_flat thì với chúng di vật là số chết.
		for k in ["damage_flat", "speed_bonus", "reaction_radius_bonus", "cooldown_refund"]:
			out[k] = float(out[k]) * dup_mult
		for k2 in ["range_bonus", "projectile_bonus", "pierce_targets", "lifesteal"]:
			out[k2] = int(round(float(out[k2]) * dup_mult))
	return out

func _apply(tower: Node) -> void:
	if not is_instance_valid(tower):
		return
	# Thoát sớm chỉ khi tháp này thật sự KHÔNG hưởng gì. Với di vật "Armory"
	# thì một tháp trống vẫn hưởng trang bị của quân CÙNG LOẠI — thoát sớm ở đây
	# là di vật đó không bao giờ chạm tới được. Đã dính.
	var gm_share := get_node_or_null("/root/GameManagerSingleton")
	var sharing: bool = gm_share != null and bool(gm_share.relic_equip_share)
	if equipped_on(tower).is_empty() and not _growth.has(tower.get_instance_id()) 			and not sharing:
		if tower.has_method("clear_equipment_buff"):
			tower.clear_equipment_buff()
		return
	if tower.has_method("apply_equipment_buff"):
		tower.apply_equipment_buff(_aggregate(tower))

## Làm mới toàn bộ tháp — gọi khi di vật đổi số ô hoặc sau khi rebase.
func refresh_all() -> void:
	prune()
	if not is_inside_tree():
		return
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower):
			_apply(tower)

# ==========================================================================
# NHỊP WAVE
# ==========================================================================

## Cuối mỗi wave: cộng dồn "Ancient Roots" cho tháp còn sống, reset hạn mức hút máu.
func on_wave_cleared() -> void:
	prune()
	if not is_inside_tree():
		return
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower):
			continue
		var growth := 0.0
		for id in equipped_on(tower):
			growth += float(item_data(id).get("effect", {}).get("growth_per_wave", 0.0))
		if growth <= 0.0:
			continue
		var key := tower.get_instance_id()
		_growth[key] = float(_growth.get(key, 0.0)) + growth
		_apply(tower)
