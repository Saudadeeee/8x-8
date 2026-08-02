# res://scripts/perks/perk_system.gd
# Hệ thống Đặc Quyền (Perk) theo run — sau mỗi wave player chọn 1 trong 3 perk
# ngẫu nhiên (roguelike draft). Là child node của game_map nên tự reset khi
# scene reload mỗi run mới.
#
# Kênh apply của mỗi perk (một perk có thể có nhiều kênh):
#   tower   — {damage_bonus: % của base_damage, speed_bonus: giây trừ vào
#              attack_speed, range_bonus: số ô} → gộp thành MỘT layer PERK
#              duy nhất, re-apply cho mọi tháp (giống synergy).
#   economy — {gold_per_kill / interest_cap / interest_rate} → ghi vào
#              GameManagerSingleton (per-run, reset trong start_run).
#   instant — {hp_delta / gold_delta} one-shot — game_map áp dụng qua signal
#              perk_picked (vì máu/vàng nguồn sự thật nằm ở game_map).
#   rd      — {per_wave_start / grant_mult} → ghi vào GameManagerSingleton.
#
# Perk tùy chỉnh: đặt file *.json (JSON array các perk dict, đúng schema trên)
# vào res://data/perks/ — được nạp và validate trong _ready, merge vào pool
# chung, đi qua đúng pipeline như perk built-in. Xem docs/CONTENT_AUTHORING.md.
extends Node
class_name PerkSystem

signal perk_picked(perk: Dictionary)

const DRAFT_SIZE: int = 3

## Trọng số NỀN (wave 1). Cũng là danh sách rarity hợp lệ dùng để validate perk
## JSON. Trọng số THỰC khi roll do `_rarity_weight()` tính theo wave — xem dưới.
const RARITY_WEIGHTS: Dictionary = {
	"common":    60,
	"rare":      25,
	"epic":      12,
	"legendary":  3,
}

# ── Rarity theo tiến trình wave ────────────────────────────────────────────────
# Trước đây trọng số CỐ ĐỊNH cho mọi wave: wave 1 đã có 3% rúng ra huyền thoại
# "Thần Chiến Tranh" và run coi như xong từ lá đầu; ngược lại wave 12 vẫn 60%
# ra perk thường nên phần thưởng cuối run nhạt dần.
#
# Nay mỗi bậc có (1) wave MỞ KHOÁ — chưa tới thì không xuất hiện chút nào, và
# (2) đường trọng số tuyến tính từ lúc mở khoá. Perk thường tụt dần xuống sàn,
# ba bậc trên leo dần tới trần.
const RARITY_UNLOCK_WAVE: Dictionary = {
	"common": 1, "rare": 3, "epic": 5, "legendary": 8,
}

## base = trọng số ngay tại wave mở khoá; step = cộng thêm mỗi wave sau đó;
## floor/cap = chặn hai đầu để không bậc nào biến mất hẳn hay nuốt trọn bảng.
const RARITY_CURVE: Dictionary = {
	"common":    {"base": 60, "step": -3, "floor": 20, "cap": 60},
	"rare":      {"base": 10, "step":  4, "floor":  4, "cap": 40},
	"epic":      {"base":  4, "step":  3, "floor":  2, "cap": 28},
	"legendary": {"base":  2, "step":  2, "floor":  1, "cap": 12},
}

## Wave hiện tại — game_map ghi vào trước mỗi lần roll_draft().
var current_wave: int = 1

func set_wave(wave: int) -> void:
	current_wave = maxi(1, wave)

## Trọng số roll của một bậc tại wave hiện tại. 0 = chưa mở khoá.
func _rarity_weight(rarity: String) -> int:
	var unlock: int = int(RARITY_UNLOCK_WAVE.get(rarity, 1))
	if current_wave < unlock:
		return 0
	var curve: Dictionary = RARITY_CURVE.get(rarity, {})
	if curve.is_empty():
		return int(RARITY_WEIGHTS.get(rarity, 1))
	var raw: int = int(curve["base"]) + int(curve["step"]) * (current_wave - unlock)
	return clampi(raw, int(curve["floor"]), int(curve["cap"]))

## Thư mục chứa perk tùy chỉnh — mỗi file *.json là MỘT JSON array các perk
## dict dùng đúng schema như PERKS built-in. Perk hợp lệ được merge vào pool
## chung trước mọi lần roll; perk lỗi chỉ push_warning rồi bỏ qua.
const CUSTOM_PERK_DIR: String = "res://data/perks/"
## Nguồn CHÍNH: .tres mở được bằng Inspector.
const RES_PERK_DIR: String = "res://res/perks/"

## Các kênh hiệu ứng hợp lệ và subkey được engine hiểu — dùng để validate
## perk JSON. Perk phải có ít nhất MỘT kênh chứa ít nhất MỘT subkey hợp lệ.
const EFFECT_CHANNELS: Dictionary = {
	"tower":   ["damage_bonus", "speed_bonus", "range_bonus"],
	"economy": ["gold_per_kill", "interest_cap", "interest_rate"],
	"instant": ["hp_delta", "gold_delta"],
	"rd":      ["per_wave_start", "grant_mult"],
	# Kênh "element": perk gắn với LỐI CHƠI nguyên tố (futureplan §3.4).
	# Mỗi subkey ghi vào đúng một field perk_* của GameManager — xem _apply_element.
	"element": [
		"tile_discount", "equip_discount", "element_damage", "freeze_bonus",
		"conduct_extra", "water_spread", "poison_max_stacks",
		"potion_per_reactions", "no_element_damage",
	],
}

const PERKS: Array = [
	# ── TOWER LAYER ──────────────────────────────────────────────────────
	{
		"id": "ren_vu_khi", "name": "Rèn Vũ Khí", "rarity": "common",
		"desc": "+10% sát thương cho toàn bộ tháp.",
		"tower": {"damage_bonus": 0.10},
	},
	{
		"id": "dau_boi_tron", "name": "Dầu Bôi Trơn", "rarity": "common",
		"desc": "Giảm 0.08s thời gian hồi đòn của toàn bộ tháp.",
		"tower": {"speed_bonus": 0.08},
	},
	{
		"id": "mat_dai_bang", "name": "Mắt Đại Bàng", "rarity": "rare",
		"desc": "+1 tầm bắn cho toàn bộ tháp.",
		"tower": {"range_bonus": 1},
	},
	{
		"id": "lo_ren_hoang_gia", "name": "Lò Rèn Hoàng Gia", "rarity": "epic",
		"desc": "+20% sát thương cho toàn bộ tháp.",
		"tower": {"damage_bonus": 0.20},
	},
	{
		"id": "than_chien_tranh", "name": "Thần Chiến Tranh", "rarity": "legendary",
		"desc": "+30% sát thương, -0.1s hồi đòn và +1 tầm bắn cho toàn bộ tháp.",
		"tower": {"damage_bonus": 0.30, "speed_bonus": 0.1, "range_bonus": 1},
	},
	# ── ECONOMY ──────────────────────────────────────────────────────────
	{
		"id": "thue_mau", "name": "Thuế Máu", "rarity": "common",
		"desc": "+1 vàng mỗi khi tiêu diệt một địch.",
		"economy": {"gold_per_kill": 1},
	},
	{
		"id": "ngan_kho", "name": "Ngân Khố", "rarity": "rare",
		"desc": "Trần lãi vàng cuối wave tăng từ 15 lên 25.",
		"economy": {"interest_cap": 25},
	},
	{
		"id": "ham_vang", "name": "Hầm Vàng", "rarity": "epic",
		"desc": "Lãi suất vàng cuối wave tăng từ 10% lên 15%.",
		"economy": {"interest_rate": 0.15},
	},
	# ── SURVIVAL (instant / one-shot) ────────────────────────────────────
	{
		"id": "tuong_thanh", "name": "Tường Thành", "rarity": "common",
		"desc": "+5 máu ngay lập tức.",
		"instant": {"hp_delta": 5},
		"stackable": true,
	},
	{
		"id": "hien_te", "name": "Hiến Tế", "rarity": "rare",
		"desc": "Mất 10 máu, nhận ngay 60 vàng.",
		"instant": {"hp_delta": -10, "gold_delta": 60},
		"stackable": true,
		"requires_hp": 11,
	},
	# ── ROYAL DECREE ─────────────────────────────────────────────────────
	{
		"id": "sac_lenh_khan", "name": "Sắc Lệnh Khẩn", "rarity": "rare",
		"desc": "+5 Sắc Lệnh Hoàng Gia mỗi khi wave mới bắt đầu.",
		"rd": {"per_wave_start": 5.0},
	},
	{
		"id": "quyen_uy", "name": "Quyền Uy", "rarity": "epic",
		"desc": "Sắc Lệnh Hoàng Gia nhận được khi thắng wave tăng 50%.",
		"rd": {"grant_mult": 1.5},
	},
]

## Danh sách id perk đã sở hữu trong run này (perk stackable có thể lặp lại).
var owned: Array[String] = []

## Pool perk hiệu lực trong run = PERKS built-in + perk JSON hợp lệ.
## Được khởi tạo lazy trong _ready / lần truy cập đầu — custom perk đi qua
## đúng pipeline như built-in (không special-case).
var _all_perks: Array = []

func _ready() -> void:
	_initialize_perk_pool()

# ==========================================================================
# PUBLIC API
# ==========================================================================

## Nguồn cho draft ĐỊNH HƯỚNG — game_map gắn hàm trả về nguyên tố đang mạnh nhất.
## Thiếu provider thì draft chạy y như cũ (thuần ngẫu nhiên).
var dominant_element_provider: Callable = Callable()

func set_dominant_element_provider(provider: Callable) -> void:
	dominant_element_provider = provider

## Trả về tối đa DRAFT_SIZE perk ngẫu nhiên, phân biệt nhau, theo trọng số
## rarity. Loại perk đã sở hữu (trừ stackable) và perk không đủ điều kiện HP.
func roll_draft() -> Array:
	_initialize_perk_pool()
	var pool: Array = []
	for perk in _all_perks:
		if _is_eligible(perk):
			pool.append(perk)

	# Chặn cứng theo wave: bậc chưa mở khoá thì KHÔNG xuất hiện, không phải
	# "xác suất thấp". Nếu lọc xong không đủ 3 lá (hết perk thường vì đã lấy
	# hết) thì nới ra dùng pool đầy đủ — thà lệch tiến trình còn hơn draft rỗng.
	var gated: Array = []
	for perk in pool:
		if _rarity_weight(str(perk.get("rarity", "common"))) > 0:
			gated.append(perk)
	if gated.size() >= DRAFT_SIZE:
		pool = gated

	var draft: Array = []

	# LÁ ĐỊNH HƯỚNG (futureplan §6.3): 1 trong 3 lá luôn khớp lối chơi hiện tại.
	# Rút TRƯỚC để nó chắc chắn có chỗ; hai lá còn lại vẫn ngẫu nhiên hoàn toàn
	# nên draft không biến thành đường ray một chiều.
	var guided := _pick_guided(pool)
	if not guided.is_empty():
		draft.append(guided)
		pool.erase(guided)

	while draft.size() < DRAFT_SIZE and pool.size() > 0:
		var chosen: Dictionary = _weighted_pick(pool)
		draft.append(chosen)
		pool.erase(chosen)
	# Xáo để lá định hướng không luôn nằm ở vị trí đầu — người chơi phải đọc,
	# không được đoán theo chỗ đứng.
	draft.shuffle()
	return draft

## Perk khớp nguyên tố đang mạnh nhất. Ưu tiên perk chỉ đích danh nguyên tố đó
## (`element.element_damage`), sau đó tới perk cùng nhóm nguyên tố nói chung.
func _pick_guided(pool: Array) -> Dictionary:
	if pool.is_empty() or not dominant_element_provider.is_valid():
		return {}
	var value = dominant_element_provider.call()
	var element := str(value) if value is String else ""
	if element.is_empty():
		return {}

	var exact: Array = []
	var generic: Array = []
	for perk in pool:
		var el = (perk as Dictionary).get("element")
		if not (el is Dictionary):
			continue
		var damage_table = (el as Dictionary).get("element_damage")
		if damage_table is Dictionary and (damage_table as Dictionary).has(element):
			exact.append(perk)
		else:
			generic.append(perk)
	if not exact.is_empty():
		return _weighted_pick(exact)
	if not generic.is_empty():
		return _weighted_pick(generic)
	return {}

## Chọn một perk theo id — hoạt động độc lập với UI (dùng được cho test).
## Trả về false nếu id sai, perk không stack được mà đã sở hữu,
## hoặc hiệu ứng instant sẽ giết player.
func pick(perk_id: String) -> bool:
	var perk: Dictionary = get_perk_by_id(perk_id)
	if perk.is_empty():
		push_warning("PerkSystem: perk id không tồn tại: %s" % perk_id)
		return false
	if owned.has(perk_id) and not perk.get("stackable", false):
		push_warning("PerkSystem: perk '%s' đã sở hữu và không thể stack." % perk_id)
		return false

	var gm := _get_game_manager()
	var inst: Dictionary = perk.get("instant", {})
	var hp_delta: int = int(inst.get("hp_delta", 0))
	if hp_delta < 0 and gm and gm.current_health + hp_delta <= 0:
		push_warning("PerkSystem: không đủ máu để chọn perk '%s'." % perk_id)
		return false

	owned.append(perk_id)
	_apply_economy(perk, gm)
	_apply_rd(perk, gm)
	_apply_element(perk, gm)
	if gm:
		gm.active_perks = owned.duplicate()
	if perk.has("tower"):
		_reapply_tower_layer_to_all()
	perk_picked.emit(perk)
	return true

## Áp dụng layer PERK tổng hợp hiện tại lên MỘT tháp (gọi khi tower_placed).
func apply_to_tower(tower: Node) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	if not tower.has_method("apply_perk_buff"):
		return
	var agg: Dictionary = get_tower_aggregate()
	if _is_aggregate_empty(agg):
		return
	tower.apply_perk_buff(agg)

## Tổng hợp mọi perk kênh tower thành 1 dictionary buff duy nhất.
func get_tower_aggregate() -> Dictionary:
	var total: Dictionary = {"damage_bonus": 0.0, "speed_bonus": 0.0, "range_bonus": 0}
	for perk_id in owned:
		var perk: Dictionary = get_perk_by_id(perk_id)
		if not perk.has("tower"):
			continue
		var t: Dictionary = perk["tower"]
		total["damage_bonus"] += float(t.get("damage_bonus", 0.0))
		total["speed_bonus"]  += float(t.get("speed_bonus", 0.0))
		total["range_bonus"]  += int(t.get("range_bonus", 0))
	return total

func get_perk_by_id(perk_id: String) -> Dictionary:
	_initialize_perk_pool()
	for perk in _all_perks:
		if perk.get("id", "") == perk_id:
			return perk
	return {}

## Tên hiển thị (VN) của các perk đã sở hữu — dùng cho HUD counter/tooltip.
func get_owned_names() -> Array[String]:
	var names: Array[String] = []
	for perk_id in owned:
		var perk: Dictionary = get_perk_by_id(perk_id)
		if not perk.is_empty():
			names.append(perk.get("name", perk_id))
	return names

# ==========================================================================
# INTERNAL
# ==========================================================================

func _is_eligible(perk: Dictionary) -> bool:
	var perk_id: String = perk.get("id", "")
	if perk_id == "":
		return false
	if owned.has(perk_id) and not perk.get("stackable", false):
		return false
	var required_hp: int = int(perk.get("requires_hp", 0))
	if required_hp > 0:
		var gm := _get_game_manager()
		if gm == null or gm.current_health < required_hp:
			return false
	return true

func _weighted_pick(pool: Array) -> Dictionary:
	var total_weight: int = 0
	for perk in pool:
		total_weight += _rarity_weight(str(perk.get("rarity", "common")))
	if total_weight <= 0:
		return pool[0]
	var roll: int = randi_range(1, total_weight)
	var accumulated: int = 0
	for perk in pool:
		accumulated += _rarity_weight(str(perk.get("rarity", "common")))
		if roll <= accumulated:
			return perk
	return pool[pool.size() - 1]

func _apply_economy(perk: Dictionary, gm: GameManager) -> void:
	if gm == null or not perk.has("economy"):
		return
	var eco: Dictionary = perk["economy"]
	if eco.has("gold_per_kill"):
		gm.perk_gold_per_kill += int(eco["gold_per_kill"])
	if eco.has("interest_cap"):
		gm.perk_interest_cap = maxi(gm.perk_interest_cap, int(eco["interest_cap"]))
	if eco.has("interest_rate"):
		gm.perk_interest_rate = maxf(gm.perk_interest_rate, float(eco["interest_rate"]))

func _apply_rd(perk: Dictionary, gm: GameManager) -> void:
	if gm == null or not perk.has("rd"):
		return
	var rd: Dictionary = perk["rd"]
	if rd.has("per_wave_start"):
		gm.perk_rd_per_wave_start += float(rd["per_wave_start"])
	if rd.has("grant_mult"):
		gm.perk_decree_grant_mult = maxf(gm.perk_decree_grant_mult, float(rd["grant_mult"]))

## Perk lối chơi nguyên tố. Quy tắc: giá trị CỘNG DỒN thì cộng, ngưỡng thì lấy
## MAX, cờ thì OR — giống _apply_economy, để chọn 2 perk cùng nhóm không bị nuốt.
func _apply_element(perk: Dictionary, gm: GameManager) -> void:
	if gm == null or not perk.has("element"):
		return
	var el: Dictionary = perk["element"]
	if el.has("tile_discount"):
		gm.perk_tile_discount += float(el["tile_discount"])
	if el.has("equip_discount"):
		gm.perk_equip_discount += float(el["equip_discount"])
	if el.has("freeze_bonus"):
		gm.perk_freeze_bonus += float(el["freeze_bonus"])
	if el.has("conduct_extra"):
		gm.perk_conduct_extra += int(el["conduct_extra"])
	if el.has("water_spread"):
		gm.perk_water_spread = gm.perk_water_spread or bool(el["water_spread"])
	if el.has("poison_max_stacks"):
		gm.perk_poison_max_stacks = maxi(gm.perk_poison_max_stacks, int(el["poison_max_stacks"]))
	if el.has("potion_per_reactions"):
		gm.perk_potion_per_reactions = int(el["potion_per_reactions"])
	if el.has("no_element_damage"):
		gm.perk_no_element_damage += float(el["no_element_damage"])
	if el.has("element_damage") and el["element_damage"] is Dictionary:
		var table: Dictionary = gm.perk_element_damage.duplicate()
		for element in (el["element_damage"] as Dictionary).keys():
			var key := str(element)
			table[key] = float(table.get(key, 0.0)) + float(el["element_damage"][element])
		gm.perk_element_damage = table   # gán lại cả dict: perk_* là state chia sẻ,
		                                 # sửa tại chỗ thì bên đọc cache sẽ lệch
	# Giảm giá trang bị nằm ở EquipmentSystem, không phải GameManager.
	if el.has("equip_discount"):
		var map := get_parent()
		var equipment: Variant = map.get("equipment_system") if map else null
		if equipment is Node and is_instance_valid(equipment):
			(equipment as Node).set("shop_discount", gm.perk_equip_discount)

## Re-apply layer PERK tổng hợp lên MỌI tháp đang đứng trên board.
func _reapply_tower_layer_to_all() -> void:
	var agg: Dictionary = get_tower_aggregate()
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("apply_perk_buff"):
			tower.apply_perk_buff(agg)

func _is_aggregate_empty(agg: Dictionary) -> bool:
	return float(agg.get("damage_bonus", 0.0)) == 0.0 \
		and float(agg.get("speed_bonus", 0.0)) == 0.0 \
		and int(agg.get("range_bonus", 0)) == 0

func _get_game_manager() -> GameManager:
	return get_node_or_null("/root/GameManagerSingleton") as GameManager

# ==========================================================================
# CUSTOM PERK LOADING (JSON — res://data/perks/*.json)
# ==========================================================================

## Khởi tạo pool = built-in + custom JSON. Idempotent — gọi lại vô hại.
## File/perk lỗi CHỈ push_warning và bị bỏ qua — không bao giờ phá built-in.
func _initialize_perk_pool() -> void:
	if not _all_perks.is_empty():
		return
	_all_perks = PERKS.duplicate()
	_merge_perks(ContentLoader.load_dir(RES_PERK_DIR, "perk"))
	_load_custom_perks()

## Trộn vào pool: trùng `id` thì bản MỚI thắng.
func _merge_perks(entries: Array) -> void:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if not _validate_custom_perk(entry, "res"):
			continue
		var pid := str((entry as Dictionary).get("id", ""))
		var replaced := false
		for i in _all_perks.size():
			if str(_all_perks[i].get("id", "")) == pid:
				_all_perks[i] = entry
				replaced = true
				break
		if not replaced:
			_all_perks.append(entry)

func _load_custom_perks() -> void:
	var dir := DirAccess.open(CUSTOM_PERK_DIR)
	if dir == null:
		return  # Không có thư mục data/perks/ — hoàn toàn hợp lệ, bỏ qua.
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
			_load_perk_file(CUSTOM_PERK_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Nạp MỘT file JSON: phải là array các perk dict. Perk hợp lệ append vào
## _all_perks; perk lỗi warning + skip (từng perk độc lập, 1 perk hỏng
## không làm hỏng cả file).
func _load_perk_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("PerkSystem: không đọc được file perk '%s' (lỗi %d)." % [path, FileAccess.get_open_error()])
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Array):
		push_warning("PerkSystem: '%s' không phải JSON array hợp lệ — bỏ qua cả file." % path)
		return
	var added: int = 0
	for entry in parsed:
		if not (entry is Dictionary):
			push_warning("PerkSystem: '%s' chứa phần tử không phải object — bỏ qua phần tử đó." % path)
			continue
		if _validate_custom_perk(entry, path):
			_all_perks.append(entry)
			added += 1
	if added > 0:
		print_verbose("PerkSystem: nạp %d perk tùy chỉnh từ %s" % [added, path])

## Validate 1 perk JSON theo đúng schema built-in:
## - id/name/desc: String không rỗng; id chưa tồn tại trong pool
## - rarity ∈ RARITY_WEIGHTS (common/rare/epic/legendary)
## - có ít nhất 1 kênh hiệu ứng hợp lệ (tower/economy/instant/rd) chứa
##   ít nhất 1 subkey engine hiểu, giá trị là số
func _validate_custom_perk(perk: Dictionary, source: String) -> bool:
	var perk_id: Variant = perk.get("id", "")
	if not (perk_id is String) or (perk_id as String).is_empty():
		push_warning("PerkSystem [%s]: perk thiếu 'id' (String không rỗng) — bỏ qua." % source)
		return false
	if not get_perk_by_id_in_pool(perk_id).is_empty():
		push_warning("PerkSystem [%s]: id '%s' trùng với perk đã có — bỏ qua." % [source, perk_id])
		return false
	for field in ["name", "desc"]:
		var v: Variant = perk.get(field, "")
		if not (v is String) or (v as String).is_empty():
			push_warning("PerkSystem [%s]: perk '%s' thiếu '%s' (String không rỗng) — bỏ qua." % [source, perk_id, field])
			return false
	var rarity: Variant = perk.get("rarity", "")
	if not (rarity is String) or not RARITY_WEIGHTS.has(rarity):
		push_warning("PerkSystem [%s]: perk '%s' có rarity '%s' không hợp lệ (common/rare/epic/legendary) — bỏ qua." % [source, perk_id, str(rarity)])
		return false
	if not _has_valid_effect_channel(perk, perk_id, source):
		return false
	return true

## Kiểm tra perk có ít nhất 1 kênh hiệu ứng engine hiểu được.
func _has_valid_effect_channel(perk: Dictionary, perk_id: String, source: String) -> bool:
	var found: bool = false
	for channel in EFFECT_CHANNELS.keys():
		if not perk.has(channel):
			continue
		var payload: Variant = perk[channel]
		if not (payload is Dictionary):
			push_warning("PerkSystem [%s]: perk '%s' — kênh '%s' phải là object — bỏ qua kênh." % [source, perk_id, channel])
			continue
		var known_keys: Array = EFFECT_CHANNELS[channel]
		for key in (payload as Dictionary).keys():
			# Kênh "element" có subkey không phải số: `water_spread` là bool,
			# `element_damage` là dict {nguyên tố: %}. Chỉ kiểm KHOÁ có được engine
			# hiểu không; kiểm kiểu chi tiết là việc của _apply_element.
			if known_keys.has(key) and _is_valid_effect_value(payload[key]):
				found = true
			elif not known_keys.has(key):
				push_warning("PerkSystem [%s]: perk '%s' — subkey '%s.%s' không được engine hiểu (bỏ qua subkey, perk vẫn dùng được nếu có subkey hợp lệ khác)." % [source, perk_id, channel, key])
	if not found:
		push_warning("PerkSystem [%s]: perk '%s' không có kênh hiệu ứng hợp lệ nào (%s) — bỏ qua." % [source, perk_id, ", ".join(EFFECT_CHANNELS.keys())])
	return found

## Giá trị subkey dùng được: số (đa số), bool (cờ bật/tắt như `water_spread`),
## hoặc dict KHÔNG rỗng (`element_damage` = {nguyên tố: %}).
func _is_valid_effect_value(value: Variant) -> bool:
	if value is float or value is int:
		return true
	if value is bool:
		return bool(value)
	if value is Dictionary:
		return not (value as Dictionary).is_empty()
	return false

## Tìm perk theo id TRONG pool đang build (không lazy-init — dùng nội bộ khi
## validate để tránh đệ quy _initialize_perk_pool).
func get_perk_by_id_in_pool(perk_id: String) -> Dictionary:
	for perk in _all_perks:
		if perk.get("id", "") == perk_id:
			return perk
	return {}
