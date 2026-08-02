# res://scripts/map/king_rules.gd
#
# LUẬT RIVAL KING — bản dịch của Boss Blind trong Balatro.
#
# Boss Blind của Balatro không phải "cần nhiều điểm hơn". Nó ĐỔI LUẬT: lá cơ bị
# úp, chỉ được đánh một lần, lá đã dùng bị khoá. Cùng một bộ bài, luật khác →
# đội hình đang thắng bỗng sai → phải nghĩ lại. Đó là chỗ roguelike sinh ra
# chiều sâu, không phải ở thanh máu dài hơn.
#
# Ở đây mỗi Rival King mang một luật áp lên CẢ BÀN CỜ trong wave của hắn. Luật
# vào thẳng công thức Nền × Bội (qua `cell_mult`) hoặc chặn hẳn một loại quân
# (qua `silences`), nên người chơi thấy con số tụt NGAY khi wave bắt đầu và
# biết chính xác phải sửa gì.
class_name KingRules
extends Node

## Mỗi luật: id → {name, desc, kind, ...tham số}.
## `kind`:
##   "silence"   — một kiểu nước đi ngừng bắn cả wave
##   "half"      — chỉ nửa bàn được tính Bội
##   "no_stack"  — mỗi thế cờ chỉ tính một lần dù lặp lại
##   "haste"     — địch nhanh hơn, bù lại người chơi được thêm lượt đặt
##   "toll"      — mỗi quân trên bàn làm Bội toàn cục giảm một chút
const RULES := {
	"silent_king": {
		"name": "Vua Câm", "kind": "silence", "pattern": ChessPattern.Kind.BISHOP,
		"desc": "Tượng không bắn trong wave này. Đường chéo của ngươi vô dụng.",
	},
	"mute_rook": {
		"name": "Vua Nghẽn", "kind": "silence", "pattern": ChessPattern.Kind.ROOK,
		"desc": "Xe không bắn trong wave này. Cột và hàng im lặng.",
	},
	"tilted_king": {
		"name": "Vua Nghiêng", "kind": "half", "keep_left": true, "mult": 0.35,
		"desc": "Chỉ quân ở nửa bàn BÊN TRÁI được tính Bội đầy đủ.",
	},
	"mirror_king": {
		"name": "Vua Gương", "kind": "no_stack",
		"desc": "Mỗi loại thế cờ chỉ tính MỘT lần, dù ngươi xếp được bao nhiêu.",
	},
	"hasty_king": {
		"name": "Vua Vội", "kind": "haste", "speed_mult": 1.6, "extra_places": 3,
		"desc": "Quân của hắn đi nhanh 60%. Bù lại ngươi được thêm 3 lượt đặt.",
	},
	"toll_king": {
		"name": "Vua Thuế", "kind": "toll", "per_unit": 0.03,
		"desc": "Mỗi quân trên bàn làm Bội toàn cục giảm 3%. Đông chưa chắc mạnh.",
	},
}

## Thứ tự gặp — cố định để mọi ván có cùng nhịp học, không bốc ngẫu nhiên.
## (Cùng lý do `_pick_boss_stats` chọn theo thứ tự wave boss.)
const ORDER: Array[String] = [
	"silent_king", "tilted_king", "mirror_king",
	"mute_rook", "hasty_king", "toll_king",
]

signal rule_changed(rule_id: String)

var map: Node3D = null
var active_id: String = ""


static func attach(target: Node3D) -> KingRules:
	var kr := KingRules.new()
	kr.name = "KingRules"
	kr.map = target
	target.add_child(kr)
	return kr


# ── Bật / tắt ───────────────────────────────────────────────────────────────

## Bật luật cho wave boss thứ `boss_index` (0-based). Ngoài wave boss thì gọi
## `clear()` — luật KHÔNG kéo dài sang wave thường.
func activate_for_boss(boss_index: int) -> void:
	if ORDER.is_empty():
		return
	active_id = ORDER[clampi(boss_index, 0, ORDER.size() - 1)]
	rule_changed.emit(active_id)


func clear() -> void:
	if active_id == "":
		return
	active_id = ""
	rule_changed.emit("")


func is_active() -> bool:
	return active_id != "" and RULES.has(active_id)


func rule_name() -> String:
	return str(_spec().get("name", ""))


func rule_desc() -> String:
	return str(_spec().get("desc", ""))


func _spec() -> Dictionary:
	return RULES.get(active_id, {})


# ── Ảnh hưởng lên công thức ─────────────────────────────────────────────────

## Hệ số Bội mà luật áp lên một ô. 1.0 = không ảnh hưởng.
func cell_mult(cell: Vector2i) -> float:
	if not is_active():
		return 1.0
	var spec := _spec()
	match str(spec.get("kind", "")):
		"half":
			var gc = map.get("grid_controller") if map else null
			if gc == null:
				return 1.0
			var mid: int = int(gc.grid_width / 2.0)
			var left: bool = cell.x < mid
			return 1.0 if left == bool(spec.get("keep_left", true)) \
				else float(spec.get("mult", 0.5))
		"toll":
			var n := 0
			if map and map.is_inside_tree():
				n = map.get_tree().get_nodes_in_group("towers").size()
			return maxf(0.25, 1.0 - float(spec.get("per_unit", 0.0)) * float(n))
	return 1.0


## Kiểu nước đi này có bị câm trong wave hiện tại không.
func silences(pattern_kind: int) -> bool:
	if not is_active():
		return false
	var spec := _spec()
	return str(spec.get("kind", "")) == "silence" \
		and int(spec.get("pattern", -1)) == pattern_kind


## Thế cờ có bị cấm cộng dồn không (Vua Gương).
func no_stack() -> bool:
	return is_active() and str(_spec().get("kind", "")) == "no_stack"


## Hệ số tốc độ địch của luật (Vua Vội).
func enemy_speed_mult() -> float:
	if not is_active():
		return 1.0
	var spec := _spec()
	if str(spec.get("kind", "")) == "haste":
		return float(spec.get("speed_mult", 1.0))
	return 1.0


## Số lượt đặt quân được cộng thêm (đền bù cho luật khắc nghiệt).
func extra_places() -> int:
	if not is_active():
		return 0
	return int(_spec().get("extra_places", 0))
