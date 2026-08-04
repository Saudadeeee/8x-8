# res://scripts/elements/element_synergy.gd
# SYNERGY THEO NGUYÊN TỐ — trục đếm THỨ HAI (futureplan.md §4).
#
# `SynergyManager` đếm theo LOẠI QUÂN (pawn/knight/…) và gắn với vòng đời
# tower_placed/tower_removed. Nguyên tố thì khác: nó đến từ Ô, nên số lượng có
# thể đổi mà KHÔNG có tháp nào được đặt hay gỡ (mua một ô, nâng cấp ô, mở rộng
# bản đồ). Vì vậy đây là hệ RIÊNG, đếm lại toàn bộ mỗi lần bố cục thay đổi,
# thay vì nhét thêm tag vào SynergyManager.
#
# Ngưỡng 2/4/6 giống trục loại quân để người chơi không phải học luật mới.
# Mốc ×6 mở một hiệu ứng ĐỔI LUẬT (không phải cộng chỉ số) — đó là phần thưởng
# cho việc đi thuần một nguyên tố, xem §4 nhóm A.
extends Node
class_name ElementSynergy

## Phát khi bậc của bất kỳ nguyên tố nào đổi. `levels` = {nguyên tố: bậc 0..3}.
signal element_synergy_changed(levels: Dictionary)

const THRESHOLDS: Array[int] = [2, 4, 6]

## Buff chỉ số theo bậc, áp cho THÁP ĐANG BẮN nguyên tố đó (index = bậc - 1).
const LEVEL_STATS: Array[Dictionary] = [
	{"damage_pct": 0.08, "speed_bonus": 0.00, "range_bonus": 0},
	{"damage_pct": 0.18, "speed_bonus": 0.05, "range_bonus": 0},
	{"damage_pct": 0.30, "speed_bonus": 0.10, "range_bonus": 1},
]

## Tên mốc ×6 — hiệu ứng đổi luật, mỗi nguyên tố một kiểu.
const CAPSTONE: Dictionary = {
	ElementTypes.FIRE:    {"name": "Sea of Flame",   "desc": "Fire Marks erupt: each burn tick spreads to enemies within 1.5m."},
	ElementTypes.ICE:     {"name": "Eternal Ice",    "desc": "Bone-deep cold: Freeze loses its hidden cooldown entirely."},
	ElementTypes.THUNDER: {"name": "Thunderstorm", "desc": "Chained thunder: Conduct spreads to as many as 8 targets."},
	ElementTypes.POISON:  {"name": "Ancient Plague",    "desc": "Deep venom: Poison Marks stack up to 10 times."},
	ElementTypes.WATER:   {"name": "Raging Tide", "desc": "A rolling tide: every enemy spawns already carrying a Water Mark."},
	ElementTypes.EARTH:   {"name": "Glacier Split",    "desc": "The earth breeds gold: Crystallize condenses 40 gold instead of 15."},
}

## Bảng Địa Chấn: 40/15 ≈ 2.67. Viết thành hằng để chỉnh một chỗ.
const QUAKE_GOLD_MULT: float = 40.0 / 15.0
const PLAGUE_STACKS: int = 10
const STORM_TARGETS: int = 8
const SEA_OF_FIRE_RADIUS: float = 1.5

# ── Trạng thái ─────────────────────────────────────────────────────────────
## nguyên tố → số tháp đang bắn nguyên tố đó.
var counts: Dictionary = {}
## nguyên tố → bậc 0..3.
var levels: Dictionary = {}
## Bát Quái: đủ 6 nguyên tố KHÁC NHAU trên bàn → mở phản ứng Nguyên Sơ.
var bagua_active: bool = false

var _game_manager: Node = null
var _territory_manager: Node = null

func setup(territory_manager: Node) -> void:
	_territory_manager = territory_manager
	_game_manager = get_node_or_null("/root/GameManagerSingleton")
	recount()

# ==========================================================================
# ĐẾM LẠI
# ==========================================================================

## Đếm lại toàn bộ và áp hiệu ứng. Gọi sau MỌI thay đổi có thể đổi nguyên tố
## của tháp: đặt/gỡ tháp, mua/nâng ô, mở rộng bản đồ, lắp trang bị ép nguyên tố.
func recount() -> void:
	if not is_inside_tree():
		return
	var previous: Dictionary = levels.duplicate()
	counts = {}
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.has_method("current_element"):
			continue
		var element := str(tower.call("current_element"))
		if ElementTypes.is_valid(element):
			counts[element] = int(counts.get(element, 0)) + 1

	levels = {}
	for element in counts.keys():
		levels[element] = _level_for(int(counts[element]))

	_refresh_bagua()
	_apply_tower_buffs()
	_apply_capstones()

	if levels != previous:
		element_synergy_changed.emit(levels.duplicate())

func _level_for(count: int) -> int:
	var level := 0
	for i in range(THRESHOLDS.size()):
		if count >= THRESHOLDS[i]:
			level = i + 1
	return level

## Bát Quái đếm theo Ô TRÊN BÀN, không theo tháp: mục tiêu của nó là "sưu tầm đủ
## 6 nguyên tố", không đòi hỏi phải có tháp đứng trên từng ô.
func _refresh_bagua() -> void:
	var distinct := 0
	if _territory_manager != null and is_instance_valid(_territory_manager) \
			and _territory_manager.has_method("distinct_element_count"):
		distinct = int(_territory_manager.call("distinct_element_count"))
	bagua_active = distinct >= ElementTypes.ALL.size()
	if _game_manager != null:
		_game_manager.set("bagua_active", bagua_active)

# ==========================================================================
# ÁP HIỆU ỨNG
# ==========================================================================

## Mỗi tháp nhận buff của ĐÚNG nguyên tố nó đang bắn. Tháp vật lý thuần được
## gỡ lớp (không phải giữ lại giá trị cũ) — nếu không, dời tháp khỏi ô nguyên tố
## mà vẫn còn buff thì đó là lỗ khai thác hiển nhiên.
func _apply_tower_buffs() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.has_method("apply_element_synergy_buff"):
			continue
		var element := str(tower.call("current_element")) if tower.has_method("current_element") else ""
		var level := int(levels.get(element, 0))
		if level <= 0:
			tower.call("apply_element_synergy_buff", {})
		else:
			tower.call("apply_element_synergy_buff", LEVEL_STATS[level - 1])

## Mốc ×6 ghi vào GameManager. LUÔN ghi cả nhánh tắt: mất tháp thứ 6 thì hiệu
## ứng phải biến mất ngay, giống synergy loại quân.
func _apply_capstones() -> void:
	if _game_manager == null:
		return
	_game_manager.set("syn_fire_spread", SEA_OF_FIRE_RADIUS if _at_cap(ElementTypes.FIRE) else 0.0)
	_game_manager.set("syn_ice_no_freeze_cd", _at_cap(ElementTypes.ICE))
	_game_manager.set("syn_thunder_targets", STORM_TARGETS if _at_cap(ElementTypes.THUNDER) else 0)
	_game_manager.set("syn_poison_stacks", PLAGUE_STACKS if _at_cap(ElementTypes.POISON) else 0)
	_game_manager.set("syn_water_spawn_mark", _at_cap(ElementTypes.WATER))
	# Kết Tinh 15 → 40 vàng. Nhân chứ không gán: di vật cũng có thể nhân vào đây.
	_game_manager.set("crystal_gold_mult", QUAKE_GOLD_MULT if _at_cap(ElementTypes.EARTH) else 1.0)

func _at_cap(element: String) -> bool:
	return int(levels.get(element, 0)) >= THRESHOLDS.size()

# ==========================================================================
# TRA CỨU (HUD)
# ==========================================================================

## Dòng tóm tắt cho HUD: "Hoả 4/6 · Băng 2/4". Rỗng khi chưa có synergy nào.
func summary_text() -> String:
	var parts: PackedStringArray = []
	for element in ElementTypes.ALL:
		var count := int(counts.get(element, 0))
		if count < THRESHOLDS[0]:
			continue
		var level := int(levels.get(element, 0))
		var next_threshold: int = THRESHOLDS[mini(level, THRESHOLDS.size() - 1)]
		parts.append("%s %d/%d" % [ElementTypes.display_name(element), count, next_threshold])
	if bagua_active:
		parts.append("☯ Bagua")
	return " · ".join(parts)

## Danh sách mốc ×6 đang bật — HUD hiện tên để người chơi biết mình mở được gì.
func active_capstones() -> Array[String]:
	var out: Array[String] = []
	for element in ElementTypes.ALL:
		if _at_cap(element):
			out.append(str(CAPSTONE[element]["name"]))
	return out
