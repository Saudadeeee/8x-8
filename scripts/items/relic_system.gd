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
## Nguồn CHÍNH: .tres mở được bằng Inspector.
const RES_DIR: String = "res://res/relics/"
const SELL_REFUND_PCT: float = 0.4

const RARITY_WEIGHTS: Dictionary = {"rare": 40, "epic": 45, "legendary": 15}

## Khoá `effect` engine hiểu.
const EFFECT_KEYS: Array[String] = [
	"reaction_mult", "max_marks", "no_consume_chance", "equip_slot_bonus",
	"potion_slot_bonus", "potion_radius", "potion_duration_bonus",
	"elite_always_drop", "marked_damage_taken", "tile_discount",
	"vein_spread", "all_elements_damage_pct", "crystal_gold_mult",
	# Khoá chạm thẳng vào công thức Nền × Bội. THÊM KHOÁ MỚI PHẢI THÊM VÀO ĐÂY:
	# `_sanitize` lọc trắng, khoá lạ bị VỨT im lặng (chỉ push_warning) nên di vật
	# vẫn mua được, vẫn hiện mô tả, mà không làm gì cả. Đã dính đúng lỗi này với
	# cả 8 di vật cờ — audit_wiring không bắt được vì khoá có người ĐỌC, chỉ là
	# không bao giờ có giá trị.
	"formation_mult_bonus", "variety_mult", "endgame_mult",
	"knight_reach", "pierce_count", "pawn_tithe",
	# ── Đổi LUẬT chơi, không chỉ đổi số ──────────────────────────────────
	# Đây là lớp Joker thật sự: món sửa CÁCH quân hoạt động. Mượn cơ chế từ
	# các loại cờ khác (Pháo cờ tướng, thả quân Shogi, vây bắt cờ vây).
	"pawn_pattern",       # đổi nước đi của MỌI Tốt (số = ChessPattern.Kind)
	"rook_as_cannon",     # mọi Xe thành Pháo (cần ngòi) — đổi lại sát thương
	"cannon_damage_mult", # hệ số bù cho Xe-thành-Pháo
	"star3_pattern",      # quân ★3 đánh theo nước đi này
	"tile_spread",        # ô nguyên tố lan sang 4 ô kề (cấp thấp hơn 1)
	"plain_tile_mult",    # ô KHÔNG nguyên tố cộng Bội — build phản nguyên tố
	"surround_mult",      # cờ vây: ô có ≥3 quân kề cộng Bội
	"equip_share",        # trang bị áp cho MỌI quân cùng loại
	"equip_stack_mult",   # hai trang bị trùng loại thì NHÂN thay vì cộng
	# ── ENGINE TỔNG QUÁT (xem relic_conditions.gd) ───────────────────────
	# Hai khoá này thay cho việc đẻ ~100 khoá riêng. Nội dung nằm ở DỮ LIỆU,
	# code chỉ có MỘT bộ máy — nên chỉ có một chỗ có thể chết âm thầm, và
	# test chỉ phải kiểm một chỗ đó.
	"cond_mult",          # {tên_điều_kiện: cộng_thêm} — Bội khi điều kiện đúng
	"per_mult",           # {tên_bộ_đếm: mỗi_đơn_vị}   — Bội theo số lượng
]

const RELICS: Array[Dictionary] = [
	{
		"id": "alchemy_book", "name": "Alchemist's Tome", "rarity": "epic", "cost": 220,
		"desc": "All elemental reactions deal +40% damage.",
		"effect": {"reaction_mult": 1.4},
	},
	{
		"id": "element_wheel", "name": "Elemental Wheel", "rarity": "legendary", "cost": 300,
		"desc": "Enemies can carry 3 Marks at once instead of 2.",
		"effect": {"max_marks": 3},
	},
	{
		"id": "reactor", "name": "Reactor Core", "rarity": "legendary", "cost": 320,
		"desc": "20% of reactions fire WITHOUT consuming their Marks.",
		"effect": {"no_consume_chance": 0.2},
	},
	{
		"id": "god_anvil", "name": "Anvil of the Gods", "rarity": "epic", "cost": 240,
		"desc": "Every piece gains 1 more equipment slot (2 -> 3).",
		"effect": {"equip_slot_bonus": 1},
	},
	{
		"id": "big_pouch", "name": "Deep Satchel", "rarity": "rare", "cost": 150,
		"desc": "+2 potion slots.",
		"effect": {"potion_slot_bonus": 2},
	},
	{
		"id": "spyglass", "name": "Spyglass", "rarity": "rare", "cost": 160,
		"desc": "Every potion's radius increases to 4m.",
		"effect": {"potion_radius": 4.0},
	},
	{
		"id": "apothecary_hand", "name": "Apothecary's Hand", "rarity": "epic", "cost": 200,
		"desc": "Potion buffs last 20 seconds longer.",
		"effect": {"potion_duration_bonus": 20.0},
	},
	{
		"id": "treasure_map", "name": "Treasure Map", "rarity": "rare", "cost": 170,
		"desc": "Elite enemies ALWAYS drop a potion.",
		"effect": {"elite_always_drop": true},
	},
	{
		"id": "hunter_necklace", "name": "Hunter's Collar", "rarity": "epic", "cost": 230,
		"desc": "Marked enemies take +15% damage from EVERY source.",
		"effect": {"marked_damage_taken": 0.15},
	},
	{
		"id": "geomancer", "name": "Geomancer", "rarity": "epic", "cost": 210,
		# Không có "ghép ô không cần kề": cách nâng cấp hiện tại là đặt ô cùng loại
		# lên CHÍNH NÓ, vốn đã chẳng đòi hỏi ô kề. Khoá đó từng được khai rồi ghi
		# vào GameManager mà không ai đọc — đã gỡ hẳn, chỉ giữ phần giảm giá.
		"desc": "Element veins cost 40% less - build your network twice as fast.",
		"effect": {"tile_discount": 0.4},
	},
	{
		"id": "living_vein", "name": "Living Ley Line", "rarity": "legendary", "cost": 310,
		"desc": "Level 3 veins spread their Mark to the 4 adjacent squares.",
		"effect": {"vein_spread": true},
	},
	{
		"id": "primal_heart", "name": "Primal Heart", "rarity": "legendary", "cost": 330,
		"desc": "With all 6 elements on the board, every piece deals +30% damage.",
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
	for entry in ContentLoader.load_dir(RES_DIR, "relics"):
		var res_clean := _sanitize(entry)
		if not res_clean.is_empty():
			_catalog[str(res_clean["id"])] = res_clean
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
		# ── Khoá chạm thẳng vào công thức Nền × Bội ──────────────────────
		# Đây là lớp nội dung kiểu Joker: mỗi món sửa CÁCH TÍNH, không chỉ
		# cộng một con số. Không có lớp này thì di vật chỉ là +% nhàm chán.
		"formation_mult_bonus": 0.0,   # cộng vào Bội của MỌI thế cờ
		"variety_mult": 0.0,           # cộng Bội theo số LOẠI thế đang có
		"endgame_mult": 0.0,           # càng ít quân trên bàn, Bội càng cao
		"knight_reach": 0,             # Mã phủ thêm vòng ô chữ L xa hơn
		"pierce_count": 0,             # đường trượt xuyên qua N quân của mình
		"pawn_tithe": 0.0,             # mỗi Tốt trên bàn cộng Bội cho quân khác
		# Đổi luật: -1 nghĩa là "không đổi" (0 là một Kind hợp lệ — ROOK).
		"pawn_pattern": -1, "star3_pattern": -1,
		"rook_as_cannon": false, "cannon_damage_mult": 1.0,
		"tile_spread": false, "plain_tile_mult": 0.0,
		"surround_mult": 0.0,
		"equip_share": false, "equip_stack_mult": 1.0,
		# Gộp theo KHOÁ CON: hai di vật cùng dùng `few_pieces` thì cộng dồn giá
		# trị chứ không đè nhau. Bội cuối = 1 + tổng.
		"cond_mult": {}, "per_mult": {},
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
				"elite_always_drop", "vein_spread", "rook_as_cannon", "tile_spread", "equip_share":
					out[key] = bool(out[key]) or bool(value)
				"pawn_pattern", "star3_pattern":
					out[key] = int(value)                   # món sau ghi đè món trước
				"cannon_damage_mult", "equip_stack_mult":
					out[key] = float(out[key]) * float(value)
				"formation_mult_bonus", "variety_mult", "endgame_mult", "pawn_tithe", "plain_tile_mult", "surround_mult":
					out[key] = float(out[key]) + float(value)   # CỘNG DỒN, không lấy max
				"knight_reach", "pierce_count":
					out[key] = int(out[key]) + int(value)   # CỘNG DỒN — xếp chồng được
				"cond_mult", "per_mult":
					# Gộp theo KHOÁ CON. Hai di vật cùng dùng `few_pieces` phải
					# cộng dồn, không đè nhau — nếu không thì mua món thứ hai
					# lại thấy sức mạnh đứng yên.
					if value is Dictionary:
						var acc: Dictionary = out[key]
						for sub in (value as Dictionary):
							acc[sub] = float(acc.get(sub, 0.0)) + float((value as Dictionary)[sub])
						out[key] = acc
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
		gm.set("relic_formation_mult_bonus", float(t["formation_mult_bonus"]))
		gm.set("relic_variety_mult", float(t["variety_mult"]))
		gm.set("relic_endgame_mult", float(t["endgame_mult"]))
		gm.set("relic_knight_reach", int(t["knight_reach"]))
		gm.set("relic_pierce_count", int(t["pierce_count"]))
		gm.set("relic_pawn_pattern", int(t["pawn_pattern"]))
		gm.set("relic_star3_pattern", int(t["star3_pattern"]))
		gm.set("relic_rook_as_cannon", bool(t["rook_as_cannon"]))
		gm.set("relic_cannon_damage_mult", float(t["cannon_damage_mult"]))
		gm.set("relic_tile_spread", bool(t["tile_spread"]))
		gm.set("relic_plain_tile_mult", float(t["plain_tile_mult"]))
		gm.set("relic_surround_mult", float(t["surround_mult"]))
		gm.set("relic_equip_share", bool(t["equip_share"]))
		gm.set("relic_equip_stack_mult", float(t["equip_stack_mult"]))
		gm.set("relic_pawn_tithe", float(t["pawn_tithe"]))
		# Engine tổng quát — BoardScore đọc hai dict này trong mult_breakdown.
		gm.set("relic_cond_mult", t["cond_mult"])
		gm.set("relic_per_mult", t["per_mult"])
		# Nước đi đổi ⇒ tầm phủ của MỌI quân đổi theo. Không bảo dựng lại thì di
		# vật chỉ có tác dụng với quân đặt SAU khi mua.
		if is_inside_tree():
			Tower.bump_layout(get_tree())
			for t2 in get_tree().get_nodes_in_group("towers"):
				if is_instance_valid(t2) and t2.has_method("refresh_coverage"):
					t2.refresh_coverage()

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
