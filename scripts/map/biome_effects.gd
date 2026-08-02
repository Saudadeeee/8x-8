# res://scripts/map/biome_effects.gd
# Hiệu ứng GAMEPLAY của hệ BIOME (đa môi trường).
#
# Là child node của game_map (giống PerkSystem). Phần render/địa hình do
# GridController + BiomeLibrary lo — file này CHỈ chuyển "mod" của biome thành
# hiệu ứng số học lên các hệ thống đang chạy.
#
# Kênh mod → nơi áp:
#   tower_dmg_pct / tower_spd_delta → BuffLayer.BIOME_CLIMATE trên MỌI tháp
#       (tháp mới đặt được bắt qua signal tower_placer.tower_placed).
#       LƯU Ý: khác hoàn toàn BuffLayer.BIOME — layer đó dành cho biome của
#       Ô LÃNH THỔ (territory), không phải khí hậu toàn bản đồ.
#   enemy_speed_mult / enemy_hp_mult → GameManagerSingleton (enemy.gd đọc lúc
#       load_enemy_data). Quái ĐÃ spawn không đổi — biome chỉ đổi giữa 2 wave.
#   gold_per_kill → GameManagerSingleton.biome_gold_per_kill, được gộp sẵn
#       trong GameManager.get_perk_gold_per_kill() nên game_map không phải sửa.
#   burn_mult → GameManagerSingleton.biome_burn_mult (enemy.gd nhân vào DoT).
#
# BiomeLibrary (res://scripts/map/biome_library.gd) có thể CHƯA tồn tại: mọi
# truy cập đi qua load() + guard, thiếu thì dùng mod trung tính, KHÔNG crash.
extends Node
class_name BiomeEffects

## Phát sau khi một biome được áp xong (mod đã chuẩn hoá) — dùng cho debug/test.
signal biome_applied(biome_id: String, mod: Dictionary)

const BIOME_LIBRARY_PATH: String = "res://scripts/map/biome_library.gd"
const DEFAULT_BIOME_ID:   String = "wasteland"

## Mod trung tính — mọi giá trị "như bình thường". Là nền để merge spec vào,
## đồng thời là fallback khi BiomeLibrary vắng mặt hoặc id không hợp lệ.
const NEUTRAL_MOD: Dictionary = {
	"enemy_speed_mult": 1.0,
	"enemy_hp_mult":    1.0,
	"tower_dmg_pct":    0.0,
	"tower_spd_delta":  0.0,
	"gold_per_kill":    0,
	"burn_mult":        1.0,
}

## Kẹp giá trị đọc từ spec để một biome viết sai không phá gameplay.
const CLAMP_RANGES: Dictionary = {
	"enemy_speed_mult": Vector2(0.05, 10.0),
	"enemy_hp_mult":    Vector2(0.05, 10.0),
	"tower_dmg_pct":    Vector2(-0.90, 5.00),
	"tower_spd_delta":  Vector2(-2.00, 2.00),
	"burn_mult":        Vector2(0.00, 10.0),
	"gold_per_kill":    Vector2(-50.0, 50.0),
}

const TOWER_GROUP:        String = "towers"
const PLACER_RETRY_DELAY: float  = 0.5
const PLACER_RETRIES:     int    = 6

# ── Refs (điền trong setup, mọi thứ đều có thể null) ──────────────────────
var _map:             Node = null
var _tower_placer:    Node = null
var _grid_controller: Node = null

# ── State ─────────────────────────────────────────────────────────────────
var _biome_id: String     = ""
var _spec:     Dictionary = {}
var _mod:      Dictionary = NEUTRAL_MOD.duplicate(true)

var _library: Script = null
var _library_warned: bool = false

## apply_biome() gọi trước khi node vào scene tree → hoãn phần cần get_tree().
var _pending_tower_refresh: bool = false

# ==========================================================================
# LIFECYCLE
# ==========================================================================

## setup()/apply_biome() có thể được gọi TRƯỚC add_child (BiomeEffects.new()
## → setup() → add_child()) — hoàn tất phần cần scene tree tại đây.
func _ready() -> void:
	if _map != null and _tower_placer == null:
		_bind_tower_placer(PLACER_RETRIES)
	if _pending_tower_refresh:
		_pending_tower_refresh = false
		_apply_tower_channel()

# ==========================================================================
# PUBLIC API (game_map gọi — mọi call site đều guard bằng has_method)
# ==========================================================================

## Lưu tham chiếu game_map và bắt các manager cần thiết.
## An toàn khi gọi nhiều lần (idempotent).
func setup(map: Node) -> void:
	if map == null or not is_instance_valid(map):
		push_warning("BiomeEffects.setup: map null/không hợp lệ — bỏ qua.")
		return
	_map = map
	_grid_controller = _node_ref(map, "grid_controller")
	_bind_tower_placer(PLACER_RETRIES)

## Áp mod của một biome cho toàn bộ hệ thống. Gọi nhiều lần sẽ THAY THẾ mod
## cũ (layer trên tháp được clear trước khi set, field GameManager được GÁN
## chứ không cộng dồn). Truyền "" → trả mọi thứ về trung tính.
func apply_biome(biome_id: String) -> void:
	var resolved_id: String = biome_id if biome_id != "" else DEFAULT_BIOME_ID
	_spec    = fetch_spec(resolved_id)
	_biome_id = resolved_id
	# Khí hậu biome đã TẮT (FeatureFlags.BIOME_CLIMATE_ENABLED): giữ HÌNH ẢNH
	# (ánh sáng, sương, màu nền vẫn đổi theo vùng) nhưng bỏ phần sửa chỉ số ngầm
	# — nó không xuất hiện ở đâu trong bảng Nền × Bội nên người chơi chỉ thấy số
	# nhảy mà không biết vì sao.
	_mod = _normalize_mod(_spec.get("mod", {})) if FeatureFlags.BIOME_CLIMATE_ENABLED 		else _normalize_mod({})
	_apply_tower_channel()
	_push_to_game_manager()
	biome_applied.emit(_biome_id, _mod.duplicate(true))

## Mod đang áp (bản sao — người gọi sửa không ảnh hưởng state).
func current_mod() -> Dictionary:
	return _mod.duplicate(true)

func get_biome_id() -> String:
	return _biome_id

## Spec đầy đủ của biome đang áp (name/desc/mod) — rỗng nếu chưa áp/thiếu lib.
func current_spec() -> Dictionary:
	return _spec.duplicate(true)

## Tên hiển thị của biome đang áp; fallback về id khi thiếu spec.
func current_name() -> String:
	var display_name: Variant = _spec.get("name", "")
	if display_name is String and (display_name as String) != "":
		return str(display_name)
	return _biome_id

## Tra spec của MỘT biome từ BiomeLibrary. Trả {} nếu thiếu lib/id sai.
func fetch_spec(biome_id: String) -> Dictionary:
	if biome_id == "":
		return {}
	var lib := _get_library()
	if lib == null:
		return {}
	var all: Variant = lib.get("ALL")
	if all is Dictionary:
		var entry: Variant = (all as Dictionary).get(biome_id, null)
		if entry is Dictionary:
			return entry
	if lib.has_method("get_spec"):
		var spec: Variant = lib.call("get_spec", biome_id)
		if spec is Dictionary:
			return spec
	return {}

## Danh sách id biome khả dụng — rỗng khi BiomeLibrary chưa tồn tại.
func available_ids() -> Array[String]:
	var out: Array[String] = []
	var lib := _get_library()
	if lib == null:
		return out
	if lib.has_method("ids"):
		var raw: Variant = lib.call("ids")
		if raw is Array:
			for v in (raw as Array):
				if v is String:
					out.append(v)
			return out
	var all: Variant = lib.get("ALL")
	if all is Dictionary:
		for k in (all as Dictionary).keys():
			if k is String:
				out.append(k)
	return out

## Có BiomeLibrary hợp lệ hay không (HUD/test dùng để hiển thị fallback).
func has_library() -> bool:
	return _get_library() != null

# ==========================================================================
# KÊNH THÁP (BuffLayer.BIOME_CLIMATE)
# ==========================================================================

## Áp lại layer khí hậu cho MỌI tháp đang đứng trên board.
func _apply_tower_channel() -> void:
	if not is_inside_tree():
		_pending_tower_refresh = true   # _ready() sẽ chạy lại
		return
	for tower in get_tree().get_nodes_in_group(TOWER_GROUP):
		_apply_to_tower(tower)

## Áp layer khí hậu cho MỘT tháp. Luôn clear trước → không bao giờ cộng dồn.
func _apply_to_tower(tower: Node) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	if tower.has_method("clear_climate_buff"):
		tower.call("clear_climate_buff")
	var dmg_pct:   float = float(_mod.get("tower_dmg_pct",   0.0))
	var spd_delta: float = float(_mod.get("tower_spd_delta", 0.0))
	if is_zero_approx(dmg_pct) and is_zero_approx(spd_delta):
		return   # mod trung tính — layer đã clear là đủ
	if tower.has_method("apply_climate_buff"):
		tower.call("apply_climate_buff", dmg_pct, spd_delta)

## Tháp mới đặt phải chịu khí hậu hiện tại ngay lập tức.
func _on_tower_placed(_grid_pos: Vector2i, tower: Node) -> void:
	_apply_to_tower(tower)

## Bắt signal tower_placed. TowerPlacer được game_map tạo bằng code nên có thể
## chưa tồn tại lúc setup — retry vài nhịp rồi bỏ cuộc yên lặng.
func _bind_tower_placer(retries: int) -> void:
	if _map == null or not is_instance_valid(_map):
		return
	var placer := _node_ref(_map, "tower_placer")
	if placer == null:
		if retries > 0 and is_inside_tree():
			get_tree().create_timer(PLACER_RETRY_DELAY).timeout.connect(
				func() -> void: _bind_tower_placer(retries - 1))
		return
	_tower_placer = placer
	if placer.has_signal("tower_placed") \
			and not placer.is_connected("tower_placed", _on_tower_placed):
		placer.connect("tower_placed", _on_tower_placed)

# ==========================================================================
# KÊNH GAMEMANAGER (enemy hp/speed, gold/kill, burn)
# ==========================================================================

func _push_to_game_manager() -> void:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return
	if gm.has_method("set_active_biome"):
		gm.call("set_active_biome", _biome_id, _spec, _mod)
		return
	# Fallback khi GameManager chưa có API — ghi thẳng field rồi tự phát signal.
	gm.set("active_biome",           _biome_id)
	gm.set("biome_enemy_speed_mult", float(_mod.get("enemy_speed_mult", 1.0)))
	gm.set("biome_enemy_hp_mult",    float(_mod.get("enemy_hp_mult",    1.0)))
	gm.set("biome_gold_per_kill",    int(_mod.get("gold_per_kill",      0)))
	gm.set("biome_burn_mult",        float(_mod.get("burn_mult",        1.0)))
	if gm.has_signal("biome_changed"):
		gm.emit_signal("biome_changed", _biome_id, _spec)

# ==========================================================================
# INTERNAL
# ==========================================================================

## Chuẩn hoá mod thô từ spec: merge lên nền trung tính, ép kiểu và kẹp biên.
func _normalize_mod(raw: Variant) -> Dictionary:
	var out: Dictionary = NEUTRAL_MOD.duplicate(true)
	if not (raw is Dictionary):
		return out
	var src: Dictionary = raw
	for key: String in ["enemy_speed_mult", "enemy_hp_mult", "tower_dmg_pct", "tower_spd_delta", "burn_mult"]:
		out[key] = _read_number(src, key, float(NEUTRAL_MOD[key]))
	out["gold_per_kill"] = int(round(_read_number(src, "gold_per_kill", 0.0)))
	return out

## Đọc một số từ dict (chấp nhận int/float), kẹp theo CLAMP_RANGES.
func _read_number(src: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = src.get(key, null)
	if not (value is float or value is int):
		return fallback
	var num: float = float(value)
	if not is_finite(num):
		push_warning("BiomeEffects: '%s' không phải số hữu hạn — dùng mặc định." % key)
		return fallback
	var span: Vector2 = CLAMP_RANGES.get(key, Vector2(-1e9, 1e9))
	return clampf(num, span.x, span.y)

## Lấy một property kiểu Node trên node khác — null nếu thiếu/không hợp lệ.
func _node_ref(owner_node: Node, prop: String) -> Node:
	if owner_node == null or not is_instance_valid(owner_node):
		return null
	var value: Variant = owner_node.get(prop)
	if value is Node and is_instance_valid(value):
		return value
	return null

## Nạp BiomeLibrary một lần rồi cache. Thiếu file = trạng thái hợp lệ
## (agent render có thể chưa tạo) — chỉ cảnh báo đúng MỘT lần.
func _get_library() -> Script:
	if _library != null:
		return _library
	if not ResourceLoader.exists(BIOME_LIBRARY_PATH):
		if not _library_warned:
			_library_warned = true
			push_warning("BiomeEffects: chưa có %s — dùng mod trung tính." % BIOME_LIBRARY_PATH)
		return null
	var res: Resource = load(BIOME_LIBRARY_PATH)
	if res is Script:
		_library = res as Script
		return _library
	if not _library_warned:
		_library_warned = true
		push_warning("BiomeEffects: %s không phải Script hợp lệ." % BIOME_LIBRARY_PATH)
	return null
