# res://scripts/items/relic_system.gd
# HỆ DI VẬT — 5 ô, hiệu lực CẢ RUN, phải bán mới đổi (futureplan.md §3.3).
#
# Di vật khác trang bị ở chỗ: nó KHÔNG gắn vào tháp nào cả mà đổi LUẬT CHƠI
# (mọi phản ứng +40%, địch mang được 3 Dấu, ô nguyên tố rẻ 40%...). Vì vậy hệ
# này không giữ buff riêng — nó ghi vào các nguồn sự thật sẵn có:
#   GameManager.global_reaction_mult / crystal_gold_mult / relic_* fields
#   EquipmentSystem.slots_per_tower
#   PotionSystem.max_slots / radius_mult / duration_bonus
#   ElementTypes.DEFAULT_MAX_MARKS → ghi vào enemy.marks.max_marks lúc spawn
#
# `_apply_all()` LUÔN tính lại từ đầu rồi GHI ĐÈ (không cộng dồn) — bán một di
# vật là giá trị tự trở về mặc định, không cần undo riêng cho từng món.
extends Node
class_name RelicSystem

signal relics_changed(ids: Array)

const MAX_SLOTS: int = 5
const CUSTOM_DIR: String = "res://data/relics/"
const SELL_REFUND_PCT: float = 0.4

const RARITY_WEIGHTS: Dictionary = {"rare": 40, "epic": 45, "legendary": 15}

## Khoá `effect` engine hiểu.
const EFFECT_KEYS: Array[String] = [
	"reaction_mult", "max_marks", "no_consume_chance", "equip_slot_bonus",
	"potion_slot_bonus", "potion_radius", "potion_duration_bonus",
	"elite_always_drop", "marked_damage_taken", "tile_discount",
	"vein_spread", "all_elements_damage_pct", "crystal_gold_mult",
]

const RELICS: Array[Dictionary] = [
	{
		"id": "alchemy_book", "name": "Sách Giả Kim", "rarity": "epic", "cost": 220,
		"desc": "Mọi phản ứng nguyên tố +40% sát thương.",
		"effect": {"reaction_mult": 1.4},
	},
	{
		"id": "element_wheel", "name": "Bánh Xe Nguyên Tố", "rarity": "legendary", "cost": 300,
		"desc": "Địch mang được 3 Dấu cùng lúc thay vì 2.",
		"effect": {"max_marks": 3},
	},
	{
		"id": "reactor", "name": "Lò Phản Ứng", "rarity": "legendary", "cost": 320,
		"desc": "20% phản ứng nổ mà KHÔNG tiêu thụ Dấu.",
		"effect": {"no_consume_chance": 0.2},
	},
	{
		"id": "god_anvil", "name": "Đe Của Thần", "rarity": "epic", "cost": 240,
		"desc": "Mỗi tháp có thêm 1 ô trang bị (2 → 3).",
		"effect": {"equip_slot_bonus": 1},
	},
	{
		"id": "big_pouch", "name": "Túi Thuốc Rộng", "rarity": "rare", "cost": 150,
		"desc": "Túi thuốc +2 ô.",
		"effect": {"potion_slot_bonus": 2},
	},
	{
		"id": "spyglass", "name": "Ống Nhòm", "rarity": "rare", "cost": 160,
		"desc": "Bán kính mọi bình thuốc tăng lên 4m.",
		"effect": {"potion_radius": 4.0},
	},
	{
		"id": "apothecary_hand", "name": "Bàn Tay Dược Sư", "rarity": "epic", "cost": 200,
		"desc": "Thuốc buff kéo dài thêm 20 giây.",
		"effect": {"potion_duration_bonus": 20.0},
	},
	{
		"id": "treasure_map", "name": "Bản Đồ Kho Báu", "rarity": "rare", "cost": 170,
		"desc": "Địch Elite LUÔN rơi thuốc.",
		"effect": {"elite_always_drop": true},
	},
	{
		"id": "hunter_necklace", "name": "Vòng Cổ Thợ Săn", "rarity": "epic", "cost": 230,
		"desc": "Địch đang mang Dấu nhận +15% sát thương từ MỌI nguồn.",
		"effect": {"marked_damage_taken": 0.15},
	},
	{
		"id": "geomancer", "name": "Địa Chất Sư", "rarity": "epic", "cost": 210,
		# Không có "ghép ô không cần kề": cách nâng cấp hiện tại là đặt ô cùng loại
		# lên CHÍNH NÓ, vốn đã chẳng đòi hỏi ô kề. Khoá đó từng được khai rồi ghi
		# vào GameManager mà không ai đọc — đã gỡ hẳn, chỉ giữ phần giảm giá.
		"desc": "Ô nguyên tố rẻ 40% — xây mạng lưới nhanh gấp đôi.",
		"effect": {"tile_discount": 0.4},
	},
	{
		"id": "living_vein", "name": "Long Mạch Sống", "rarity": "legendary", "cost": 310,
		"desc": "Ô Lv3 lan Dấu của nó sang 4 ô kề.",
		"effect": {"vein_spread": true},
	},
	{
		"id": "primal_heart", "name": "Trái Tim Nguyên Sơ", "rarity": "legendary", "cost": 330,
		"desc": "Đủ 6 nguyên tố trên bàn: mọi tháp +30% sát thương.",
		"effect": {"all_elements_damage_pct": 0.3},
	},
]

# ── Trạng thái ─────────────────────────────────────────────────────────────
var _catalog: Dictionary = {}
var _owned: Array[String] = []
var _equipment: EquipmentSystem = null
var _potions: PotionSystem = null

func _ready() -> void:
	_build_catalog()

## game_map gọi ngay sau add_child. Hai hệ kia là NƠI di vật ghi giá trị vào.
func setup(equipment: EquipmentSystem, potions: PotionSystem) -> void:
	_equipment = equipment
	_potions = potions
	_apply_all()

# ==========================================================================
# CATALOG
# ==========================================================================

func _build_catalog() -> void:
	_catalog.clear()
	for relic in RELICS:
		_catalog[str(relic["id"])] = _sanitize(relic)
	for relic in _load_custom():
		var clean := _sanitize(relic)
		if not clean.is_empty():
			_catalog[str(clean["id"])] = clean

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
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_DIR + file_name))
		if parsed is Array:
			for entry in parsed:
				if entry is Dictionary:
					out.append(entry)
		else:
			push_warning("RelicSystem: '%s' phải là JSON array" % file_name)
	return out

func _sanitize(raw: Dictionary) -> Dictionary:
	var id := str(raw.get("id", "")).strip_edges()
	if id.is_empty():
		push_warning("RelicSystem: bỏ qua di vật thiếu 'id'")
		return {}
	var effect_in: Dictionary = raw.get("effect", {}) if raw.get("effect") is Dictionary else {}
	var effect: Dictionary = {}
	for key in effect_in.keys():
		if EFFECT_KEYS.has(str(key)):
			effect[str(key)] = effect_in[key]
		else:
			push_warning("RelicSystem: di vật '%s' có khoá lạ '%s'" % [id, key])
	return {
		"id": id,
		"name": str(raw.get("name", id)),
		"rarity": str(raw.get("rarity", "epic")),
		"cost": maxi(0, int(raw.get("cost", 200))),
		"desc": str(raw.get("desc", "")),
		"effect": effect,
	}

func relic_data(id: String) -> Dictionary:
	var found: Variant = _catalog.get(id)
	return (found as Dictionary).duplicate(true) if found is Dictionary else {}

func all_ids() -> Array[String]:
	var out: Array[String] = []
	for key in _catalog.keys():
		out.append(str(key))
	out.sort()
	return out

## Bốc ngẫu nhiên một di vật CHƯA sở hữu (di vật không cộng dồn được).
func roll_random() -> String:
	var pool: Array[String] = []
	for id in all_ids():
		if not _owned.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	var total := 0
	for id in pool:
		total += int(RARITY_WEIGHTS.get(str(_catalog[id].get("rarity", "epic")), 20))
	var roll := randi() % maxi(1, total)
	for id in pool:
		roll -= int(RARITY_WEIGHTS.get(str(_catalog[id].get("rarity", "epic")), 20))
		if roll < 0:
			return id
	return pool.back()

# ==========================================================================
# SỞ HỮU
# ==========================================================================

func owned() -> Array[String]:
	return _owned.duplicate()

func has_relic(id: String) -> bool:
	return _owned.has(id)

func is_full() -> bool:
	return _owned.size() >= MAX_SLOTS

func add_relic(id: String) -> bool:
	if not _catalog.has(id) or _owned.has(id) or is_full():
		return false
	_owned.append(id)
	_apply_all()
	relics_changed.emit(owned())
	return true

func sell_relic(index: int) -> int:
	if index < 0 or index >= _owned.size():
		return 0
	var id: String = _owned[index]
	_owned.remove_at(index)
	_apply_all()
	relics_changed.emit(owned())
	var refund := int(round(float(relic_data(id).get("cost", 0)) * SELL_REFUND_PCT))
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm != null and gm.has_method("add_gold") and refund > 0:
		gm.add_gold(refund)
	return refund

# ==========================================================================
# ÁP HIỆU ỨNG
# ==========================================================================

## Gộp effect của mọi di vật đang giữ. Hệ số nhân thì NHÂN, còn lại lấy MAX
## (di vật không trùng nhau nên MAX = giá trị của món duy nhất có khoá đó).
func totals() -> Dictionary:
	var out: Dictionary = {
		"reaction_mult": 1.0, "max_marks": ElementTypes.DEFAULT_MAX_MARKS,
		"no_consume_chance": 0.0, "equip_slot_bonus": 0, "potion_slot_bonus": 0,
		"potion_radius": 0.0, "potion_duration_bonus": 0.0,
		"elite_always_drop": false, "marked_damage_taken": 0.0,
		"tile_discount": 0.0, "vein_spread": false,
		"all_elements_damage_pct": 0.0, "crystal_gold_mult": 1.0,
	}
	for id in _owned:
		var effect: Dictionary = relic_data(id).get("effect", {})
		for key in effect.keys():
			var value: Variant = effect[key]
			match str(key):
				"reaction_mult", "crystal_gold_mult":
					out[key] = float(out[key]) * float(value)
				"max_marks", "equip_slot_bonus", "potion_slot_bonus":
					out[key] = maxi(int(out[key]), int(value))
				"elite_always_drop", "vein_spread":
					out[key] = bool(out[key]) or bool(value)
				_:
					out[key] = maxf(float(out[key]), float(value))
	return out

## Đẩy giá trị đã gộp vào mọi nguồn sự thật. Gọi sau MỌI thay đổi sở hữu.
func _apply_all() -> void:
	var t := totals()

	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm != null:
		gm.set("global_reaction_mult", float(t["reaction_mult"]))
		gm.set("crystal_gold_mult", float(t["crystal_gold_mult"]))
		gm.set("relic_max_marks", int(t["max_marks"]))
		gm.set("relic_no_consume_chance", float(t["no_consume_chance"]))
		gm.set("relic_marked_damage_taken", float(t["marked_damage_taken"]))
		gm.set("relic_tile_discount", float(t["tile_discount"]))
		gm.set("relic_vein_spread", bool(t["vein_spread"]))
		gm.set("relic_elite_always_drop", bool(t["elite_always_drop"]))
		gm.set("relic_all_elements_pct", float(t["all_elements_damage_pct"]))

	if _equipment != null and is_instance_valid(_equipment):
		_equipment.slots_per_tower = EquipmentSystem.BASE_SLOTS + int(t["equip_slot_bonus"])

	if _potions != null and is_instance_valid(_potions):
		_potions.max_slots      = PotionSystem.MAX_SLOTS + int(t["potion_slot_bonus"])
		_potions.radius_override = float(t["potion_radius"])
		_potions.duration_bonus  = float(t["potion_duration_bonus"])

	# global_reaction_mult là một trong ba nguồn của tower.reaction_power_mult →
	# phải bảo tháp tính lại, nếu không di vật chỉ có tác dụng với tháp đặt SAU.
	if is_inside_tree():
		for tower in get_tree().get_nodes_in_group("towers"):
			if is_instance_valid(tower) and tower.has_method("_refresh_element_mults"):
				tower.call("_refresh_element_mults")
	if _equipment != null and is_instance_valid(_equipment):
		_equipment.refresh_all()
