# res://scripts/items/potion_system.gd
# HỆ THUỐC dùng theo VÙNG (futureplan.md §3.1).
#
# Túi 3 ô, ném theo vùng bán kính 2.5 m, DÙNG ĐƯỢC GIỮA TRẬN (khác đặt tháp —
# đây là điểm cốt lõi khiến thuốc vui). Là child node của game_map nên tự reset
# khi scene reload mỗi run mới (giống PerkSystem).
#
# Ba loại mục tiêu (`target`):
#   allies  — buff mọi THÁP trong vùng, hết hạn sau `duration` giây.
#             Đi qua `tower.apply_potion_buff(data, duration)` — tháp tự quản
#             token hết hạn, PotionSystem KHÔNG giữ timer nào cho tháp.
#   enemies — gây sát thương / chậm / gắn Dấu nguyên tố cho ĐỊCH trong vùng.
#   self    — hiệu ứng khẩn cấp lên chính người chơi (`special`), phải nhờ
#             game_map thực thi vì máu/khiên là nguồn sự thật của game_map.
#
# Nội dung thuốc: `POTIONS` built-in trong file này là BẢN DỰ PHÒNG. File
# `res://data/potions/core.json` là bản dữ liệu chính để cân bằng số liệu —
# entry trùng `id` sẽ GHI ĐÈ built-in (không cảnh báo), entry id mới thì thêm
# vào pool. Thiếu/hỏng file JSON → dùng nguyên built-in, game vẫn chạy.
extends Node
class_name PotionSystem

# ── Signals ────────────────────────────────────────────────────────────────
## Túi thay đổi (nhận thêm / dùng / reset). `bag` là Array[String] các id.
signal bag_changed(bag: Array)
## Vừa dùng xong một bình tại vị trí world `pos`.
signal potion_used(id: String, pos: Vector3)

# ── Hằng số ────────────────────────────────────────────────────────────────
## Số ô túi mặc định. Di Vật "Túi Thuốc Rộng" sẽ nâng qua `set_max_slots()`.
const MAX_SLOTS: int = 3
## Bán kính vùng mặc định (m) khi thuốc không khai báo `radius`.
const DEFAULT_RADIUS: float = 2.5
## Thời lượng buff mặc định (giây) khi thuốc không khai báo `duration`.
const DEFAULT_DURATION: float = 12.0
## Bán kính coi như "toàn bản đồ" — dùng cho Bình Nước Bẩn.
const GLOBAL_RADIUS: float = 999.0

## Thư mục dữ liệu thuốc — mỗi file *.json là MỘT JSON array các potion dict.
const CUSTOM_POTION_DIR: String = "res://data/potions/"
## Nguồn CHÍNH: .tres mở được bằng Inspector.
const RES_POTION_DIR: String = "res://res/potions/"

const RARITY_WEIGHTS: Dictionary = {
	"common":    60,
	"rare":      25,
	"epic":      12,
	"legendary":  3,
}

const VALID_TARGETS: Array[String] = ["allies", "enemies", "self"]

## Khoá engine hiểu trong `buff` (target = allies).
## LƯU Ý: `tower.apply_potion_buff` hiện chỉ đọc damage_flat / speed_bonus /
## range_bonus / grant_element. `projectile_bonus` và `pierce_armor` được
## chuyển nguyên vẹn xuống tháp để có hiệu lực NGAY khi tower.gd hỗ trợ.
const BUFF_KEYS: Array[String] = [
	"damage_pct", "damage_flat", "speed_bonus", "range_bonus",
	"projectile_bonus", "grant_element", "pierce_armor",
]

## Khoá engine hiểu trong `strike` (target = enemies).
const STRIKE_KEYS: Array[String] = [
	"damage", "element", "slow", "slow_duration", "poison_stacks", "lingering",
]

## Các `special` engine biết thực thi (target = self).
const SPECIAL_HEAL_KING: String   = "heal_king"
const SPECIAL_KING_SHIELD: String = "king_shield"
const SPECIAL_TIME_SAND: String   = "time_sand"
const SPECIALS: Array[String] = [SPECIAL_HEAL_KING, SPECIAL_KING_SHIELD, SPECIAL_TIME_SAND]

## Giá trị `grant_element` đặc biệt: mỗi tháp trong vùng nhận MỘT Dấu ngẫu nhiên
## khác nhau (Nước Ép Đa Sắc) thay vì cùng một Dấu.
const ELEMENT_RANDOM: String = "random"

# ── Số liệu khẩn cấp (futureplan §3.1) ─────────────────────────────────────
const HEAL_KING_AMOUNT: int    = 5
const KING_SHIELD_SECONDS: float = 10.0
const TIME_SAND_SLOW: float    = 0.6
const TIME_SAND_SECONDS: float = 5.0

# ==========================================================================
# ĐỊNH NGHĨA THUỐC (bản dự phòng — bản chính ở data/potions/core.json)
# ==========================================================================
const POTIONS: Array = [
	# ── TIẾP SỨC — buff tháp trong vùng, 12 giây ──────────────────────────
	{
		"id": "ruou_cuong_luc", "name": "Rượu Cường Lực", "rarity": "common",
		"desc": "Tháp trong vùng +40% sát thương trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"damage_pct": 0.40},
	},
	{
		"id": "dau_nhanh_tay", "name": "Dầu Nhanh Tay", "rarity": "common",
		"desc": "Tháp trong vùng giảm 0.35s hồi chiêu trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"speed_bonus": 0.35},
	},
	{
		"id": "nuoc_mat_dai_bang", "name": "Nước Mắt Đại Bàng", "rarity": "rare",
		"desc": "Tháp trong vùng +2 tầm bắn trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"range_bonus": 2},
	},
	{
		"id": "bua_da_thu", "name": "Bùa Đa Thủ", "rarity": "epic",
		"desc": "Tháp trong vùng bắn thêm 1 mũi đạn mỗi đòn trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"projectile_bonus": 1},
	},
	{
		"id": "tinh_dau_xuyen_giap", "name": "Tinh Dầu Xuyên Giáp", "rarity": "rare",
		"desc": "Tháp trong vùng bỏ qua hoàn toàn giáp trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"pierce_armor": true},
	},
	{
		"id": "mau_rong", "name": "Máu Rồng", "rarity": "rare",
		"desc": "Tháp trong vùng gắn Dấu Hoả trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"grant_element": "fire"},
	},
	{
		"id": "suong_bang_gia", "name": "Sương Băng Giá", "rarity": "rare",
		"desc": "Tháp trong vùng gắn Dấu Băng trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"grant_element": "ice"},
	},
	{
		"id": "tia_set_dong_chai", "name": "Tia Sét Đóng Chai", "rarity": "rare",
		"desc": "Tháp trong vùng gắn Dấu Lôi trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"grant_element": "thunder"},
	},
	{
		"id": "noc_ran", "name": "Nọc Rắn", "rarity": "rare",
		"desc": "Tháp trong vùng gắn Dấu Độc trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"grant_element": "poison"},
	},
	{
		"id": "nuoc_thanh", "name": "Nước Thánh", "rarity": "rare",
		"desc": "Tháp trong vùng gắn Dấu Thuỷ trong 12 giây.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"grant_element": "water"},
	},
	{
		"id": "nuoc_ep_da_sac", "name": "Nước Ép Đa Sắc", "rarity": "epic",
		"desc": "Mỗi tháp trong vùng gắn một Dấu NGẪU NHIÊN trong 12 giây, kể cả khi đứng ô thường.",
		"target": "allies", "radius": 2.5, "duration": 12.0,
		"buff": {"grant_element": "random"},
	},
	# ── TẤN CÔNG — ném vào địch ───────────────────────────────────────────
	{
		"id": "bom_lua", "name": "Bom Lửa", "rarity": "common",
		"desc": "120 sát thương trong vùng 2m và gắn Dấu Hoả.",
		"target": "enemies", "radius": 2.0,
		"strike": {"damage": 120, "element": "fire"},
	},
	{
		"id": "cau_bang", "name": "Cầu Băng", "rarity": "common",
		"desc": "60 sát thương, gắn Dấu Băng và làm chậm 50% trong 5 giây.",
		"target": "enemies", "radius": 2.5,
		"strike": {"damage": 60, "element": "ice", "slow": 0.5, "slow_duration": 5.0},
	},
	{
		"id": "lo_set", "name": "Lọ Sét", "rarity": "rare",
		"desc": "80 sát thương xuyên giáp và gắn Dấu Lôi.",
		"target": "enemies", "radius": 2.5,
		"strike": {"damage": 80, "element": "thunder"},
	},
	{
		"id": "binh_nuoc_ban", "name": "Bình Nước Bẩn", "rarity": "rare",
		"desc": "Không gây sát thương — gắn Dấu Thuỷ cho TOÀN BỘ địch trên màn.",
		"target": "enemies", "radius": 999.0,
		"strike": {"damage": 0, "element": "water"},
	},
	{
		"id": "khi_doc", "name": "Khí Độc", "rarity": "rare",
		"desc": "Vùng khí độc tồn tại 8 giây — địch đi vào dính 3 tầng Độc.",
		"target": "enemies", "radius": 2.5, "duration": 8.0,
		"strike": {"damage": 0, "element": "poison", "poison_stacks": 3, "lingering": true},
	},
	{
		"id": "vun_da", "name": "Vụn Đá", "rarity": "common",
		"desc": "Gắn Dấu Thổ và làm chậm 40% trong 6 giây.",
		"target": "enemies", "radius": 2.5,
		"strike": {"damage": 0, "element": "earth", "slow": 0.4, "slow_duration": 6.0},
	},
	# ── KHẨN CẤP — hiệu ứng đặc biệt lên người chơi ───────────────────────
	{
		"id": "mau_vua", "name": "Máu Vua", "rarity": "rare",
		"desc": "Hồi ngay 5 máu cho Nhà Vua.",
		"target": "self", "special": "heal_king",
	},
	{
		"id": "khien_vuong_trieu", "name": "Khiên Vương Triều", "rarity": "epic",
		"desc": "Nhà Vua miễn mọi sát thương trong 10 giây.",
		"target": "self", "special": "king_shield", "duration": 10.0,
	},
	{
		"id": "cat_thoi_gian", "name": "Cát Thời Gian", "rarity": "legendary",
		"desc": "Toàn bộ địch trên bản đồ bị chậm 60% trong 5 giây.",
		"target": "self", "special": "time_sand", "duration": 5.0,
	},
]

# ── State ──────────────────────────────────────────────────────────────────
## Túi thuốc — mảng id, tối đa `max_slots` phần tử.
var bag: Array[String] = []
## Số ô túi hiệu lực (nâng được bằng Di Vật).
var max_slots: int = MAX_SLOTS
## Pool hiệu lực = built-in + override/thêm từ JSON. Khởi tạo lười.
var _all_potions: Array = []

# ── Sửa đổi từ Di Vật (RelicSystem ghi vào, mặc định = không đổi) ──────────
## Ống Nhòm: ép bán kính MỌI bình lên giá trị này. 0 = giữ bán kính gốc.
## Bình "toàn màn" (radius ≥ GLOBAL_RADIUS) không bị ép xuống.
var radius_override: float = 0.0
## Bàn Tay Dược Sư: cộng thêm giây cho thuốc buff.
var duration_bonus: float = 0.0

## Bán kính hiệu lực của một bình sau khi tính Di Vật.
func effective_radius(data: Dictionary) -> float:
	var base := radius_of(data)
	if base >= GLOBAL_RADIUS or radius_override <= 0.0:
		return base
	return maxf(base, radius_override)

## Thời lượng hiệu lực của một bình sau khi tính Di Vật.
func effective_duration(data: Dictionary) -> float:
	return duration_of(data) + maxf(0.0, duration_bonus)

func _ready() -> void:
	_initialize_pool()

# ==========================================================================
# PUBLIC API
# ==========================================================================

## Bỏ một bình vào túi. false nếu id sai hoặc túi đã đầy.
func add_potion(potion_id: String) -> bool:
	_initialize_pool()
	if get_potion_by_id(potion_id).is_empty():
		push_warning("PotionSystem: id thuốc không tồn tại: %s" % potion_id)
		return false
	if bag.size() >= max_slots:
		return false
	bag.append(potion_id)
	bag_changed.emit(get_bag())
	return true

## Ô túi có dùng được không (có bình + node còn trong cây scene).
func can_use(slot: int) -> bool:
	if slot < 0 or slot >= bag.size():
		return false
	if not is_inside_tree():
		return false
	return bag[slot] != ""

## Dùng bình ở ô `slot`, ném xuống `world_pos`.
## Bình bị GỠ KHỎI TÚI TRƯỚC khi thực thi → dù hiệu ứng lỗi cũng chỉ trừ 1 lần.
func use_potion(slot: int, world_pos: Vector3) -> bool:
	if not can_use(slot):
		return false
	var potion_id: String = bag[slot]
	var data: Dictionary = get_potion_by_id(potion_id)
	bag.remove_at(slot)
	bag_changed.emit(get_bag())
	if data.is_empty():
		push_warning("PotionSystem: bình '%s' trong túi không còn định nghĩa — bỏ qua." % potion_id)
		return false
	_execute(data, world_pos)
	potion_used.emit(potion_id, world_pos)
	return true

## Bản sao túi hiện tại (Array[String]) — người gọi sửa không ảnh hưởng state.
func get_bag() -> Array:
	return bag.duplicate()

## Số ô trống còn lại.
func free_slots() -> int:
	return maxi(0, max_slots - bag.size())

## Nâng số ô túi (Di Vật "Túi Thuốc Rộng"). Không bao giờ giảm dưới số bình đang giữ.
func set_max_slots(value: int) -> void:
	max_slots = maxi(bag.size(), maxi(1, value))
	bag_changed.emit(get_bag())

## Bốc ngẫu nhiên MỘT id thuốc theo trọng số rarity.
## [param rarity_hint] khác rỗng → chỉ bốc trong rarity đó (rỗng thì bốc toàn pool).
## Trả "" nếu pool rỗng.
func roll_random(rarity_hint: String = "") -> String:
	_initialize_pool()
	var pool: Array = []
	for potion in _all_potions:
		if rarity_hint == "" or str(potion.get("rarity", "")) == rarity_hint:
			pool.append(potion)
	if pool.is_empty():
		pool = _all_potions
	if pool.is_empty():
		return ""
	return str(_weighted_pick(pool).get("id", ""))

## Toàn bộ id thuốc trong pool.
func all_ids() -> Array:
	_initialize_pool()
	var ids: Array = []
	for potion in _all_potions:
		ids.append(str(potion.get("id", "")))
	return ids

func get_potion_by_id(potion_id: String) -> Dictionary:
	_initialize_pool()
	for potion in _all_potions:
		if str(potion.get("id", "")) == potion_id:
			return potion
	return {}

## Định nghĩa của bình đang nằm ở ô `slot` ({} nếu ô trống).
func get_potion_at(slot: int) -> Dictionary:
	if slot < 0 or slot >= bag.size():
		return {}
	return get_potion_by_id(bag[slot])

## Bán kính vùng của bình ở ô `slot` (dùng để vẽ vòng ngắm).
func radius_at(slot: int) -> float:
	var data: Dictionary = get_potion_at(slot)
	if data.is_empty():
		return DEFAULT_RADIUS
	return effective_radius(data)

static func radius_of(data: Dictionary) -> float:
	return maxf(0.2, float(data.get("radius", DEFAULT_RADIUS)))

static func duration_of(data: Dictionary) -> float:
	return maxf(0.1, float(data.get("duration", DEFAULT_DURATION)))

## Nhãn ngắn (≤ 4 ký tự) cho ô túi trên HUD — ghép chữ cái đầu các từ.
static func short_label(data: Dictionary) -> String:
	var full: String = str(data.get("name", data.get("id", "?")))
	var initials: String = ""
	for word in full.split(" ", false):
		if word.length() > 0:
			initials += word.substr(0, 1)
	if initials.length() >= 2:
		return initials.to_upper().substr(0, 4)
	return full.to_upper().substr(0, 4)

## Màu đại diện — theo nguyên tố nếu có, không thì theo loại mục tiêu.
static func color_of(data: Dictionary) -> Color:
	var element: String = _element_of(data)
	if ElementTypes.is_valid(element):
		return ElementTypes.color_of(element)
	var target: String = target_of(data)
	if target == "enemies":
		return Color(0.90, 0.35, 0.25)
	if target == "self":
		return Color(0.45, 0.85, 0.55)
	return Color(1.00, 0.80, 0.30)

## Loại mục tiêu chuẩn hoá — giá trị lạ quy về "allies".
static func target_of(data: Dictionary) -> String:
	var t: String = str(data.get("target", "allies"))
	return t if VALID_TARGETS.has(t) else "allies"

# ==========================================================================
# THỰC THI
# ==========================================================================

func _execute(data: Dictionary, pos: Vector3) -> void:
	var radius: float = effective_radius(data)
	var duration: float = effective_duration(data)
	var affected: int = 0
	match target_of(data):
		"allies":
			affected = _apply_allies(data, pos, radius, duration)
		"enemies":
			affected = _apply_enemies(data, pos, radius, duration)
		"self":
			affected = _apply_special(data, pos, duration)
	_spawn_use_fx(data, pos, radius, affected)

## Buff mọi tháp trong vùng. `damage_pct` quy đổi sang `damage_flat` theo
## base_damage CỦA TỪNG THÁP (không dùng chung một con số).
func _apply_allies(data: Dictionary, pos: Vector3, radius: float, duration: float) -> int:
	var raw: Variant = data.get("buff", null)
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		push_warning("PotionSystem: thuốc '%s' target=allies nhưng thiếu 'buff'." % str(data.get("id", "?")))
		return 0
	var buff: Dictionary = raw as Dictionary
	var count: int = 0
	for tower in _nodes_in_radius("towers", pos, radius):
		if not tower.has_method("apply_potion_buff"):
			continue
		tower.apply_potion_buff(_build_tower_payload(buff, tower), duration)
		count += 1
	return count

## Dựng payload riêng cho MỘT tháp — quy đổi % theo base_damage của chính nó
## và giải nghĩa grant_element = "random".
func _build_tower_payload(buff: Dictionary, tower: Node) -> Dictionary:
	var payload: Dictionary = buff.duplicate(true)
	var pct: float = float(payload.get("damage_pct", 0.0))
	if pct != 0.0:
		payload.erase("damage_pct")
		payload["damage_flat"] = float(payload.get("damage_flat", 0.0)) + _base_damage_of(tower) * pct
	if str(payload.get("grant_element", "")) == ELEMENT_RANDOM:
		payload["grant_element"] = ElementTypes.ALL[randi() % ElementTypes.ALL.size()]
	return payload

## base_damage của tháp — 0.0 nếu tháp chưa có stats (guard mọi truy cập chéo).
func _base_damage_of(tower: Node) -> float:
	var stats: Variant = tower.get("stats")
	if stats == null:
		return 0.0
	var base: Variant = stats.get("base_damage")
	if base is float or base is int:
		return float(base)
	return 0.0

## Đánh/gắn Dấu lên địch trong vùng. Vùng `lingering` thì tồn tại `duration`
## giây và bồi lại mỗi giây.
func _apply_enemies(data: Dictionary, pos: Vector3, radius: float, duration: float) -> int:
	var raw: Variant = data.get("strike", null)
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		push_warning("PotionSystem: thuốc '%s' target=enemies nhưng thiếu 'strike'." % str(data.get("id", "?")))
		return 0
	var strike: Dictionary = raw as Dictionary
	var count: int = _strike_once(strike, pos, radius)
	if bool(strike.get("lingering", false)):
		_spawn_lingering_field(strike, pos, radius, duration)
	return count

## Một nhịp tác động lên mọi địch trong vùng. Trả về số địch bị trúng.
func _strike_once(strike: Dictionary, pos: Vector3, radius: float) -> int:
	var damage: int = int(strike.get("damage", 0))
	var element: String = str(strike.get("element", ""))
	var slow: float = float(strike.get("slow", 0.0))
	var slow_duration: float = float(strike.get("slow_duration", 0.0))
	var stacks: int = maxi(1, int(strike.get("poison_stacks", 1)))
	var count: int = 0
	for enemy in _nodes_in_radius("enemies", pos, radius):
		count += 1
		if damage > 0 and enemy.has_method("take_damage"):
			enemy.take_damage(damage, "hit")
		if not is_instance_valid(enemy):
			continue   # địch có thể chết ngay ở đòn trên
		if slow > 0.0 and slow_duration > 0.0 and enemy.has_method("apply_slow"):
			enemy.apply_slow(slow, slow_duration)
		if ElementTypes.is_valid(element):
			_mark_enemy(enemy, element, stacks)
	return count

## Gắn Dấu nguyên tố. Hệ Dấu do agent khác cung cấp (`apply_element`) — chưa có
## thì hạ cấp mềm sang slow/burn để thuốc vẫn có tác dụng.
func _mark_enemy(enemy: Node, element: String, stacks: int) -> void:
	if enemy.has_method("apply_element"):
		for _i in stacks:
			enemy.apply_element(element, null, 1.0)
		return
	var spec: Dictionary = ElementTypes.spec(element)
	var dps: float = float(spec.get("dps", 0.0))
	var slow: float = float(spec.get("slow", 0.0))
	var dur: float = float(spec.get("duration", 4.0))
	if dps > 0.0 and enemy.has_method("apply_burn"):
		enemy.apply_burn(int(round(dps * stacks)), dur)
	elif slow > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow, dur)

## Vùng tồn tại (Khí Độc): bồi lại mỗi giây trong `duration`.
## Timer VÀ mesh đều là con của PotionSystem → scene reload là dọn sạch, không rò.
func _spawn_lingering_field(strike: Dictionary, pos: Vector3, radius: float, duration: float) -> void:
	var element: String = str(strike.get("element", ""))
	var tint: Color = ElementTypes.color_of(element) if ElementTypes.is_valid(element) else Color(0.6, 0.9, 0.4)
	# Mesh treo dưới game_map (Node3D) cho đúng cây không gian; Timer treo dưới
	# PotionSystem → scene reload là cả hai cùng bị dọn, không rò node nào.
	var field := _make_field_mesh(pos, radius, tint)
	var host: Node = get_parent()
	if host == null or not host.is_inside_tree():
		host = self
	host.add_child(field)
	field.global_position = Vector3(pos.x, FIELD_MESH_Y, pos.z)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	add_child(timer)
	# Array 1 phần tử làm ô nhớ đếm ngược cho lambda (int là value type).
	var ticks_left: Array[int] = [maxi(1, int(round(duration)))]
	timer.timeout.connect(func() -> void:
		ticks_left[0] -= 1
		if ticks_left[0] > 0:
			_strike_once(strike, pos, radius)
			return
		timer.stop()
		timer.queue_free()
		if is_instance_valid(field):
			field.queue_free())

## Cao độ đĩa vùng tồn tại. BẤT BIẾN: mặt tile y = 0, territory mesh y = 0.052,
## overlay quad y = 0.06 → 0.07 để không z-fight với bất cứ lớp nào.
const FIELD_MESH_Y: float = 0.07

## Đĩa phẳng đánh dấu vùng tồn tại (vị trí do người gọi đặt sau add_child).
func _make_field_mesh(_pos: Vector3, radius: float, tint: Color) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.26)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.8
	cyl.material = mat
	disc.mesh = cyl
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc

## Hiệu ứng khẩn cấp — máu/khiên là nguồn sự thật của game_map nên phải gọi ngược
## lên (guard has_method: thiếu API thì cảnh báo, không crash).
func _apply_special(data: Dictionary, _pos: Vector3, duration: float) -> int:
	var special: String = str(data.get("special", ""))
	var map: Node = get_parent()
	match special:
		SPECIAL_HEAL_KING:
			if map and map.has_method("potion_heal_king"):
				map.potion_heal_king(HEAL_KING_AMOUNT)
				return 1
			push_warning("PotionSystem: thiếu game_map.potion_heal_king() — '%s' vô hiệu." % special)
		SPECIAL_KING_SHIELD:
			if map and map.has_method("potion_king_shield"):
				map.potion_king_shield(duration if duration > 0.0 else KING_SHIELD_SECONDS)
				return 1
			push_warning("PotionSystem: thiếu game_map.potion_king_shield() — '%s' vô hiệu." % special)
		SPECIAL_TIME_SAND:
			var count: int = 0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
					enemy.apply_slow(TIME_SAND_SLOW, TIME_SAND_SECONDS)
					count += 1
			return count
		_:
			push_warning("PotionSystem: special '%s' không được engine hiểu." % special)
	return 0

## Node còn sống trong nhóm `group` nằm trong bán kính (đo trên mặt phẳng XZ —
## tháp/địch có chiều cao khác nhau, đo 3D sẽ hụt rìa vùng).
func _nodes_in_radius(group: String, pos: Vector3, radius: float) -> Array:
	var found: Array = []
	var r2: float = radius * radius
	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var p: Vector3 = (node as Node3D).global_position
		var dx: float = p.x - pos.x
		var dz: float = p.z - pos.z
		if dx * dx + dz * dz <= r2:
			found.append(node)
	return found

## Đếm mục tiêu sẽ trúng — HUD/vòng ngắm dùng để phản hồi trước khi ném.
func count_targets(data: Dictionary, pos: Vector3) -> int:
	if data.is_empty():
		return 0
	var target: String = target_of(data)
	if target == "allies":
		return _nodes_in_radius("towers", pos, effective_radius(data)).size()
	if target == "enemies":
		return _nodes_in_radius("enemies", pos, effective_radius(data)).size()
	return 1

# ==========================================================================
# FX / ÂM THANH
# ==========================================================================

func _spawn_use_fx(data: Dictionary, pos: Vector3, radius: float, affected: int) -> void:
	var host: Node = get_parent()
	if host == null or not host.is_inside_tree():
		return
	var tint: Color = color_of(data)
	FX.spawn_click_ring(host, pos, tint)
	var burst: int = clampi(10 + affected * 3, 10, 40)
	FX.spawn_burst(host, pos + Vector3(0.0, 0.25, 0.0), tint, burst, clampf(radius / 2.5, 0.6, 1.6))
	FX.damage_number(host, pos + Vector3(0.0, 0.9, 0.0),
		"%s ×%d" % [str(data.get("name", "?")), affected], tint, 20)
	_play_sfx(data)

func _play_sfx(data: Dictionary) -> void:
	var am := get_node_or_null("/root/AudioManagerSingleton")
	if am == null or not am.has_method("play_sfx"):
		return
	match target_of(data):
		"enemies": am.play_sfx("hit", -2.0, 0.8)
		"self":    am.play_sfx("heal", -2.0)
		_:         am.play_sfx("overcharge", -4.0)

# ==========================================================================
# INTERNAL
# ==========================================================================

func _weighted_pick(pool: Array) -> Dictionary:
	var total: int = 0
	for potion in pool:
		total += int(RARITY_WEIGHTS.get(str(potion.get("rarity", "common")), 1))
	if total <= 0:
		return pool[0]
	var roll: int = randi_range(1, total)
	var acc: int = 0
	for potion in pool:
		acc += int(RARITY_WEIGHTS.get(str(potion.get("rarity", "common")), 1))
		if roll <= acc:
			return potion
	return pool[pool.size() - 1]

static func _element_of(data: Dictionary) -> String:
	var buff: Variant = data.get("buff", {})
	if buff is Dictionary:
		var granted: String = str((buff as Dictionary).get("grant_element", ""))
		if ElementTypes.is_valid(granted):
			return granted
	var strike: Variant = data.get("strike", {})
	if strike is Dictionary:
		return str((strike as Dictionary).get("element", ""))
	return ""

# ── Nạp dữ liệu JSON ───────────────────────────────────────────────────────

## Khởi tạo pool = built-in, sau đó merge JSON (override theo id). Idempotent.
func _initialize_pool() -> void:
	if not _all_potions.is_empty():
		return
	_all_potions = POTIONS.duplicate(true)
	_merge_potions(ContentLoader.load_dir(RES_POTION_DIR, "thuốc"))
	_load_json_potions()

## Trộn danh sách vào pool: trùng `id` thì bản MỚI thắng (sửa một bình có sẵn =
## sửa file .tres của nó, không phải đụng code).
func _merge_potions(entries: Array) -> void:
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var pid := str((entry as Dictionary).get("id", ""))
		if pid.is_empty():
			continue
		var replaced := false
		for i in _all_potions.size():
			if str(_all_potions[i].get("id", "")) == pid:
				_all_potions[i] = entry
				replaced = true
				break
		if not replaced:
			_all_potions.append(entry)

func _load_json_potions() -> void:
	var dir := DirAccess.open(CUSTOM_POTION_DIR)
	if dir == null:
		return   # Không có thư mục — dùng nguyên built-in, hoàn toàn hợp lệ.
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
			_load_potion_file(CUSTOM_POTION_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Nạp MỘT file JSON: phải là array các potion dict. Entry lỗi chỉ warning + skip
## (một bình hỏng không làm hỏng cả file).
func _load_potion_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("PotionSystem: không đọc được '%s' (lỗi %d)." % [path, FileAccess.get_open_error()])
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Array):
		push_warning("PotionSystem: '%s' không phải JSON array hợp lệ — bỏ qua cả file." % path)
		return
	var added: int = 0
	var replaced: int = 0
	for entry in parsed:
		if not (entry is Dictionary):
			push_warning("PotionSystem: '%s' chứa phần tử không phải object — bỏ qua." % path)
			continue
		if not _validate_potion(entry, path):
			continue
		var index: int = _index_of_id(str(entry.get("id", "")))
		if index >= 0:
			_all_potions[index] = entry   # JSON là bản cân bằng chính → ghi đè built-in
			replaced += 1
		else:
			_all_potions.append(entry)
			added += 1
	if added > 0 or replaced > 0:
		print_verbose("PotionSystem: %s — thêm %d, ghi đè %d bình." % [path, added, replaced])

func _index_of_id(potion_id: String) -> int:
	for i in _all_potions.size():
		if str(_all_potions[i].get("id", "")) == potion_id:
			return i
	return -1

## Validate 1 bình JSON:
## - id/name/desc: String không rỗng
## - rarity ∈ RARITY_WEIGHTS
## - target ∈ VALID_TARGETS, và có payload tương ứng (buff / strike / special)
func _validate_potion(potion: Dictionary, source: String) -> bool:
	var potion_id: Variant = potion.get("id", "")
	if not (potion_id is String) or (potion_id as String).is_empty():
		push_warning("PotionSystem [%s]: bình thiếu 'id' — bỏ qua." % source)
		return false
	for field in ["name", "desc"]:
		var v: Variant = potion.get(field, "")
		if not (v is String) or (v as String).is_empty():
			push_warning("PotionSystem [%s]: bình '%s' thiếu '%s' — bỏ qua." % [source, potion_id, field])
			return false
	var rarity: Variant = potion.get("rarity", "")
	if not (rarity is String) or not RARITY_WEIGHTS.has(rarity):
		push_warning("PotionSystem [%s]: bình '%s' có rarity '%s' không hợp lệ — bỏ qua."
			% [source, potion_id, str(rarity)])
		return false
	var target: Variant = potion.get("target", "")
	if not (target is String) or not VALID_TARGETS.has(target):
		push_warning("PotionSystem [%s]: bình '%s' có target '%s' không hợp lệ (%s) — bỏ qua."
			% [source, potion_id, str(target), ", ".join(VALID_TARGETS)])
		return false
	return _validate_payload(potion, str(potion_id), str(target), source)

func _validate_payload(potion: Dictionary, potion_id: String, target: String, source: String) -> bool:
	match target:
		"allies":
			return _validate_effect_dict(potion, potion_id, "buff", BUFF_KEYS, source)
		"enemies":
			return _validate_effect_dict(potion, potion_id, "strike", STRIKE_KEYS, source)
		"self":
			var special: Variant = potion.get("special", "")
			if not (special is String) or not SPECIALS.has(special):
				push_warning("PotionSystem [%s]: bình '%s' target=self cần 'special' ∈ (%s) — bỏ qua."
					% [source, potion_id, ", ".join(SPECIALS)])
				return false
			return true
	return false

## Payload phải là object và chứa ít nhất MỘT khoá engine hiểu.
func _validate_effect_dict(potion: Dictionary, potion_id: String, key: String,
		known_keys: Array[String], source: String) -> bool:
	var payload: Variant = potion.get(key, null)
	if not (payload is Dictionary):
		push_warning("PotionSystem [%s]: bình '%s' thiếu object '%s' — bỏ qua." % [source, potion_id, key])
		return false
	var found: bool = false
	for k in (payload as Dictionary).keys():
		if known_keys.has(k):
			found = true
		else:
			push_warning("PotionSystem [%s]: bình '%s' — khoá '%s.%s' không được engine hiểu (bỏ qua khoá)."
				% [source, potion_id, key, str(k)])
	if not found:
		push_warning("PotionSystem [%s]: bình '%s' — '%s' không có khoá hợp lệ nào (%s) — bỏ qua."
			% [source, potion_id, key, ", ".join(known_keys)])
	return found
