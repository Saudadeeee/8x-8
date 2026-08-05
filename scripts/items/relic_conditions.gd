# res://scripts/items/relic_conditions.gd
#
# ĐIỀU KIỆN & BỘ ĐẾM cho di vật kiểu Joker.
#
# VÌ SAO TỒN TẠI
# Muốn ~100 di vật mà mỗi món một khoá hiệu ứng riêng thì thành ~100 nhánh code,
# và mỗi nhánh là một chỗ có thể CHẾT ÂM THẦM (khoá được ghi ra nhưng không ai
# nhân nó vào sát thương — đúng lỗi đã dính với 7 thế cờ + 9 di vật).
#
# Thay vào đó: HAI khoá tổng quát, một bộ máy, và nội dung nằm ở DỮ LIỆU.
#
#     cond_mult : {tên_điều_kiện: cộng_thêm}   → Bội = 1 + Σ khi điều kiện ĐÚNG
#     per_mult  : {tên_bộ_đếm:   mỗi_đơn_vị}   → Bội = 1 + đếm × giá_trị
#
# Cả hai đi vào `BoardScore.mult_breakdown` với cờ `combat = true`, tức chúng
# NHÂN THẲNG vào `Tower.formation_damage_mult`. Chỉ có MỘT chỗ nối dây, và test
# chỉ phải kiểm một bộ máy thay vì 100 món.
#
# THÊM NỘI DUNG: viết thêm một dòng vào bảng .tres, KHÔNG cần sửa file này.
# THÊM ĐIỀU KIỆN MỚI: thêm một nhánh vào `_cond` / `_count` — và nhớ rằng mọi
# tên không nhận ra đều trả về "không thoả / bằng 0", tức di vật đó vô hại chứ
# không làm hỏng ván.
class_name RelicConditions
extends Object

# ── Bảng tra cho UI (tên đọc được) ──────────────────────────────────────────
const COND_LABELS := {
	"few_pieces": "with 9 or fewer pieces",
	"many_pieces": "with 14 or more pieces",
	"full_board": "when your army is at its cap",
	"no_veins": "while you own no elemental veins",
	"many_veins": "with 5 or more veins",
	"has_formation": "while 2+ formations are active",
	"three_formations": "with 3+ different formations",
	"boss_wave": "on Rival King waves",
	"odd_wave": "on odd-numbered waves",
	"even_wave": "on even-numbered waves",
	"rich": "while holding 400+ gold",
	"broke": "while holding 30 gold or less",
	"has_star3": "while any piece is ★3",
	"all_star2": "while every piece is ★2 or better",
	"single_kind": "while every piece moves the same way",
	"five_kinds": "with 5+ different movement types",
	"king_hurt": "while your King is below half HP",
	"full_hp": "while your King is at full HP",
	"deck_thin": "while your set holds 10 pieces or fewer",
	"late_wave": "from wave 8 onward",
}

const COUNT_LABELS := {
	"pieces": "piece on the board beyond the first 10",
	"empty_squares": "empty square beyond the first 22",
	"formations": "active formation beyond the first 1",
	"formation_kinds": "different formation type beyond the first 1",
	"veins": "elemental vein beyond the first 2",
	"vein_levels": "vein level beyond the first 3",
	"elements": "different element on the board beyond the first 2",
	"stars": "star above ★1 beyond the first 2",
	"pawns": "Pawn beyond the first 2", "rooks": "Rook beyond the first 2", "knights": "Knight beyond the first 1",
	"bishops": "Bishop beyond the first 1", "queens": "Queen", "cannons": "Cannon beyond the first 1",
	"relics": "relic you own beyond the first 2",
	"wave": "wave survived beyond the first 7",
	"path_covered": "path square your army covers beyond the first 12",
}

# ── Ảnh chụp trạng thái bàn ─────────────────────────────────────────────────
# `mult_breakdown` chạy MỘT LẦN MỖI Ô, mà quét bàn thì O(số quân). Nhớ đệm theo
# số frame: trong cùng một frame các dữ kiện không đổi, và cách này tự hết hạn
# nên không cần ai nhớ gọi invalidate.
static var _facts: Dictionary = {}
static var _facts_frame: int = -1


static func facts(map: Node) -> Dictionary:
	var frame := int(Engine.get_process_frames())
	if frame == _facts_frame and not _facts.is_empty():
		return _facts
	_facts = _build(map)
	_facts_frame = frame
	return _facts


## Ép tính lại ngay (test gọi — headless có thể đứng nguyên một frame).
static func invalidate() -> void:
	_facts_frame = -1
	_facts = {}


static func _build(map: Node) -> Dictionary:
	var f := {
		"pieces": 0, "empty_squares": 0, "formations": 0, "formation_kinds": 0,
		"veins": 0, "vein_levels": 0, "elements": 0, "stars": 0,
		"pawns": 0, "rooks": 0, "knights": 0, "bishops": 0, "queens": 0,
		"cannons": 0, "relics": 0, "wave": 1, "path_covered": 0,
		"kinds": 0, "max_units": 0, "gold": 0, "hp": 1, "hp_max": 1,
		"deck_size": 99, "boss_wave": false, "min_star": 0, "max_star": 0,
	}
	if map == null or not is_instance_valid(map):
		return f

	var kinds := {}
	var towers: Array = []
	if map.is_inside_tree():
		for t in map.get_tree().get_nodes_in_group("towers"):
			if is_instance_valid(t) and not t.is_queued_for_deletion():
				towers.append(t)
	f["pieces"] = towers.size()
	var min_star := 99
	var max_star := 0
	for t in towers:
		var k: int = int(t.pattern_kind()) if t.has_method("pattern_kind") else -1
		if k >= 0:
			kinds[k] = true
			match k:
				ChessPattern.Kind.PAWN:   f["pawns"] = int(f["pawns"]) + 1
				ChessPattern.Kind.ROOK:   f["rooks"] = int(f["rooks"]) + 1
				ChessPattern.Kind.KNIGHT: f["knights"] = int(f["knights"]) + 1
				ChessPattern.Kind.BISHOP: f["bishops"] = int(f["bishops"]) + 1
				ChessPattern.Kind.QUEEN:  f["queens"] = int(f["queens"]) + 1
				ChessPattern.Kind.CANNON: f["cannons"] = int(f["cannons"]) + 1
		var s: int = int(t.get("star")) if t.get("star") != null else 1
		f["stars"] = int(f["stars"]) + maxi(0, s - 1)
		min_star = mini(min_star, s)
		max_star = maxi(max_star, s)
	f["kinds"] = kinds.size()
	f["min_star"] = min_star if towers.size() > 0 else 0
	f["max_star"] = max_star

	var gc = map.get("grid_controller")
	if gc != null and is_instance_valid(gc):
		var empty := 0
		var covered := {}
		for y in range(gc.grid_height):
			for x in range(gc.grid_width):
				var c := Vector2i(x, y)
				if gc.is_path_cell(c):
					continue
				if not (gc.grid_data.get(c) is Node):
					empty += 1
		f["empty_squares"] = empty
		for t in towers:
			if not t.has_method("covers_cell"):
				continue
			for y2 in range(gc.grid_height):
				for x2 in range(gc.grid_width):
					var c2 := Vector2i(x2, y2)
					if gc.is_path_cell(c2) and t.covers_cell(c2):
						covered[c2] = true
		f["path_covered"] = covered.size()

	var cf = map.get_node_or_null("ChessFormations")
	if cf != null and cf.has_method("counts"):
		var fc: Dictionary = cf.counts()
		f["formation_kinds"] = fc.size()
		var total := 0
		for k in fc:
			total += int(fc[k])
		f["formations"] = total

	var tm = map.get("territory_manager")
	if tm != null and is_instance_valid(tm) and tm.get("biome_tiles") is Dictionary:
		var elems := {}
		var lv := 0
		var bt: Dictionary = tm.get("biome_tiles")
		for cell in bt:
			var key := str(bt[cell])
			elems[key] = true
			lv += int(tm.tile_level.get(cell, 1)) if tm.get("tile_level") is Dictionary else 1
		f["veins"] = bt.size()
		f["elements"] = elems.size()
		f["vein_levels"] = lv

	var gm := map.get_node_or_null("/root/GameManagerSingleton")
	if gm != null:
		f["gold"] = int(map.get("current_gold")) if map.get("current_gold") != null else 0
		f["hp"] = int(gm.current_health)
		var king = gm.get("selected_king")
		f["hp_max"] = int(king.base_health) if king != null and king.get("base_health") != null else maxi(1, int(gm.current_health))
	var pc = map.get("phase_controller")
	if pc != null and is_instance_valid(pc):
		f["wave"] = int(pc.wave_number)
	var ws = map.get("wave_spawner")
	if ws != null and is_instance_valid(ws) and ws.has_method("is_boss_wave"):
		f["boss_wave"] = bool(ws.is_boss_wave(int(f["wave"])))
	if map.get("max_units") != null and map.has_method("max_units"):
		f["max_units"] = int(map.max_units())
	var rs = map.get("relic_system")
	if rs != null and is_instance_valid(rs) and rs.get("_owned") is Array:
		f["relics"] = (rs.get("_owned") as Array).size()
	var deck = map.get("army_deck")
	if deck != null and is_instance_valid(deck) and deck.has_method("size"):
		f["deck_size"] = int(deck.size())
	return f


## Điều kiện có thoả không. Tên lạ → false (di vật vô hại, không làm hỏng ván).
static func test(cond_id: String, f: Dictionary) -> bool:
	match cond_id:
		# ── NGƯỠNG ĐƯỢC SIẾT (2026-08-05) ────────────────────────────────
		# Đo được: bot mua BỪA 5 di vật vẫn đạt Bội ×3.11, tức điều kiện dễ
		# thoả tới mức không cần chọn. Ngưỡng dưới đây đòi một CAM KẾT thật:
		# ≤6 quân là chơi mỏng có chủ đích, ≥8 ô là dồn hẳn vào nguyên tố.
		"few_pieces":       return int(f.get("pieces", 0)) <= 9
		"many_pieces":      return int(f.get("pieces", 0)) >= 14
		"full_board":       return int(f.get("max_units", 0)) > 0 			and int(f.get("pieces", 0)) >= int(f.get("max_units", 0))
		"no_veins":         return int(f.get("veins", 0)) == 0
		"many_veins":       return int(f.get("veins", 0)) >= 5
		# "có thế cờ nào đó" gần như LUÔN đúng ⇒ nó là quà miễn phí, không phải
		# lựa chọn. Đòi HAI thế đang bật cùng lúc.
		"has_formation":    return int(f.get("formations", 0)) >= 2
		"three_formations": return int(f.get("formation_kinds", 0)) >= 3
		"boss_wave":        return bool(f.get("boss_wave", false))
		"odd_wave":         return int(f.get("wave", 1)) % 2 == 1
		"even_wave":        return int(f.get("wave", 1)) % 2 == 0
		"rich":             return int(f.get("gold", 0)) >= 400
		"broke":            return int(f.get("gold", 0)) <= 30
		"has_star3":        return int(f.get("max_star", 0)) >= 3
		"all_star2":        return int(f.get("pieces", 0)) >= 4 and int(f.get("min_star", 0)) >= 2
		"single_kind":      return int(f.get("pieces", 0)) >= 4 and int(f.get("kinds", 0)) == 1
		"five_kinds":       return int(f.get("kinds", 0)) >= 5
		"king_hurt":        return float(f.get("hp", 1)) < float(f.get("hp_max", 1)) * 0.5
		"full_hp":          return int(f.get("hp", 0)) >= int(f.get("hp_max", 1))
		"deck_thin":        return int(f.get("deck_size", 99)) <= 10
		"late_wave":        return int(f.get("wave", 1)) >= 8
	return false


## SÀN của mỗi bộ đếm — chỉ phần VƯỢT sàn mới được tính.
##
## Không có sàn thì di vật bộ đếm là gậy chỉ số vô điều kiện: `pieces`, `stars`,
## `relics`, `wave` luôn > 0 nên mua món nào cũng có lãi. Đo được: bot mua BỪA 5
## di vật đạt Bội ×3.23, còn bot CHỌN LỌC chỉ ×2.42 — chọn lọc bị phạt vì nó
## mua ít món hơn. Đúng ngược với ý định thiết kế.
##
## Có sàn thì mỗi món thành một CAM KẾT: 2 Mã không cho gì, 6 Mã cho gấp bốn.
const COUNT_FLOOR := {
	"pieces": 10, "empty_squares": 22, "formations": 1, "formation_kinds": 1,
	"veins": 2, "vein_levels": 3, "elements": 2, "stars": 2,
	"pawns": 2, "rooks": 2, "knights": 1, "bishops": 1, "queens": 0,
	"cannons": 1, "relics": 2, "wave": 7, "path_covered": 12,
}

## Giá trị bộ đếm, ĐÃ TRỪ SÀN. Tên lạ → 0 (di vật không cộng gì).
static func count(counter_id: String, f: Dictionary) -> float:
	if not f.has(counter_id):
		return 0.0
	var v = f[counter_id]
	if not (v is int or v is float):
		return 0.0
	return maxf(0.0, float(v) - float(COUNT_FLOOR.get(counter_id, 0)))


## Mô tả người chơi đọc — sinh THẲNG từ hiệu ứng nên mô tả không bao giờ lệch
## với con số thật (bảng chép tay là chỗ hay nói dối nhất).
static func describe(effect: Dictionary) -> String:
	var parts: Array[String] = []
	var cm = effect.get("cond_mult", {})
	if cm is Dictionary:
		for k in cm:
			parts.append("+%.0f%% damage %s" % [float(cm[k]) * 100.0,
				str(COND_LABELS.get(k, k))])
	var pm = effect.get("per_mult", {})
	if pm is Dictionary:
		for k in pm:
			parts.append("+%.0f%% damage per %s" % [float(pm[k]) * 100.0,
				str(COUNT_LABELS.get(k, k))])
	return " · ".join(parts)
