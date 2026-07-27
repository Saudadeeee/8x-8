# res://scripts/elements/formation_detector.gd
# Phát hiện HÌNH THẾ (formation) từ bố cục Ô Nguyên Tố trên bàn — futureplan.md §2.3.
#
# Nguyên tắc: file này CHỈ ĐỌC bố cục và TRẢ VỀ dữ liệu thuần. Nó KHÔNG tự áp buff,
# KHÔNG đụng tới tháp / địch / BuffLayer / FX. Bên tiêu thụ (TerritoryManager →
# game_map → tower) tự quyết định dùng phần thưởng thế nào.
#
# Chi phí: O(n) với n = số Ô Nguyên Tố đang có — duyệt theo KEY của `element_map`,
# KHÔNG quét toàn bộ w×h. Mỗi ô chỉ kiểm vài ô kề cố định (không đệ quy, không
# flood-fill) nên gọi lại sau mỗi lần đặt/gỡ ô vẫn rẻ kể cả trên board 24×24.
#
# Quy ước gắn thẻ: một ô được gắn id hình thế khi PHẦN THƯỞNG của hình thế đó áp lên
# THÁP ĐỨNG TRÊN Ô ĐÓ. Riêng "Trận Vòng" chỉ gắn cho ô GIỮA (ô thường được bao quanh);
# 4 ô nguyên tố tạo vòng nằm trong `group["ring_cells"]` để UI tô sáng.
class_name FormationDetector
extends Object

# ── ID hình thế ───────────────────────────────────────────────────────────────
const DRAGON_LINE: String = "dragon_line"   # Hàng Long
const FOUR_PILLAR: String = "four_pillar"   # Tứ Trụ
const DUAL_POLE:   String = "dual_pole"     # Song Cực
const RING:        String = "ring"          # Trận Vòng

const ALL_IDS: Array[String] = [DRAGON_LINE, FOUR_PILLAR, DUAL_POLE, RING]

## Tên hiển thị + mô tả ngắn cho HUD. Key = hằng ID ở trên (viết literal để dict hằng
## chắc chắn parse được ở mọi phiên bản GDScript).
const INFO: Dictionary = {
	"dragon_line": {"name": "Hàng Long", "desc": "3 ô cùng loại thẳng hàng — tháp trên đó +1 tầm"},
	"four_pillar": {"name": "Tứ Trụ",    "desc": "Khối 2×2 cùng loại — phản ứng từ khối +40%"},
	"dual_pole":   {"name": "Song Cực",  "desc": "2 ô khác loại có phản ứng kề nhau — tự kích mỗi 4s"},
	"ring":        {"name": "Trận Vòng", "desc": "4 ô cùng loại bao quanh 1 ô thường — ô giữa nhận cả 4 Dấu"},
}

## Phần thưởng — DỮ LIỆU THUẦN, bên tiêu thụ tự áp.
const BONUS: Dictionary = {
	"dragon_line": {"range_bonus": 1},
	"four_pillar": {"reaction_mult": 1.40},
	"dual_pole":   {"auto_reaction_interval": 4.0},
	# Trận Vòng: 4 ô bao quanh đều CÙNG một nguyên tố, nên "nhận 4 Dấu luân phiên"
	# vô nghĩa — 4 Dấu giống nhau chỉ là 1 Dấu. Hiệu lực thật: tháp ở ô giữa (vốn
	# là ô THƯỜNG) mượn nguyên tố của vòng vây; territory_manager cấp qua khoá
	# `ring_element`, tower đọc trong `current_element()`.
	# KHÔNG khai khoá ở đây nữa: bảng BONUS chỉ chứa thứ có nơi tiêu thụ.
	"ring":        {},
}

## Cặp nguyên tố CÓ phản ứng (futureplan §1.2). Key = 2 nguyên tố sắp xếp A→Z, nối "|".
## CỐ TÌNH hardcode thay vì import `reaction_table.gd` — file đó đang được viết song song,
## phụ thuộc chéo lúc này sẽ làm parse lỗi cả hệ.
const REACTIVE_PAIR_SET: Dictionary = {
	"fire|water":    true,   # Bốc Hơi
	"fire|ice":      true,   # Tan Chảy
	"ice|water":     true,   # Đóng Băng
	"thunder|water": true,   # Dẫn Điện
	"fire|thunder":  true,   # Quá Tải
	"poison|water":  true,   # Lan Truyền
	"earth|thunder": true,   # Chấn Địa
}

# Bốn hướng kề trực giao — dùng cho Trận Vòng.
const _ORTHO: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## Hai hướng quét "phải" và "xuống" — đủ để mỗi cặp/dãy chỉ được đếm MỘT lần.
const _STEPS_RD: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]

# ── API CHÍNH ─────────────────────────────────────────────────────────────────

## Quét toàn bộ bố cục và trả về mọi hình thế đang thành hình.
##
## `element_map`: Vector2i → String (id nguyên tố, xem ElementTypes). Ô KHÔNG có mặt
##                trong dict = ô thường (không nguyên tố).
## `grid_w` / `grid_h`: kích thước board — dùng để loại ô ngoài biên.
##
## Trả về:
## ```
## {
##   "cells":      { Vector2i: Array[String] },   # ô → danh sách id hình thế áp lên tháp ở đó
##   "formations": { String: int },               # id → SỐ LƯỢNG hình thế (không phải số ô)
##   "groups":     [ { id, element, cells, ... } ],
## }
## ```
static func detect(element_map: Dictionary, grid_w: int, grid_h: int) -> Dictionary:
	var result := _empty_result()
	if element_map.is_empty() or grid_w <= 0 or grid_h <= 0:
		return result

	var tagged: Dictionary = {}   # Vector2i → Dictionary(id → true) — dedup thẻ trùng
	var groups: Array = []

	for key in element_map.keys():
		if not (key is Vector2i):
			continue
		var cell := key as Vector2i
		if not _in_bounds(cell, grid_w, grid_h):
			continue
		var element: String = str(element_map[key])
		if element == "":
			continue
		_scan_dragon_line(cell, element, element_map, grid_w, grid_h, tagged, groups)
		_scan_four_pillar(cell, element, element_map, grid_w, grid_h, tagged, groups)
		_scan_dual_pole(cell, element, element_map, grid_w, grid_h, tagged, groups)
		_scan_ring(cell, element, element_map, grid_w, grid_h, tagged, groups)

	# Chuyển Dictionary(id → true) thành Array[String] có thứ tự ổn định.
	var cells: Dictionary = {}
	for cell in tagged.keys():
		var ids: Array[String] = []
		for id in ALL_IDS:
			if (tagged[cell] as Dictionary).has(id):
				ids.append(id)
		cells[cell] = ids

	var counts: Dictionary = {}
	for group in groups:
		var id: String = str((group as Dictionary).get("id", ""))
		counts[id] = int(counts.get(id, 0)) + 1

	result["cells"] = cells
	result["formations"] = counts
	result["groups"] = groups
	return result

## Cặp nguyên tố này có phản ứng không (dùng cho Song Cực và cả bên ngoài).
static func has_reaction(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	var key: String = ("%s|%s" % [a, b]) if a < b else ("%s|%s" % [b, a])
	return REACTIVE_PAIR_SET.has(key)

## Phần thưởng của một hình thế — bản SAO, người gọi sửa thoải mái.
static func bonus_of(formation_id: String) -> Dictionary:
	return (BONUS.get(formation_id, {}) as Dictionary).duplicate(true)

static func display_name(formation_id: String) -> String:
	return str((INFO.get(formation_id, {}) as Dictionary).get("name", formation_id))

static func describe(formation_id: String) -> String:
	return str((INFO.get(formation_id, {}) as Dictionary).get("desc", ""))

## Kết quả rỗng đúng khuôn — mọi nơi đọc `.cells` / `.formations` đều an toàn.
static func empty_result() -> Dictionary:
	return _empty_result()

# ── QUÉT TỪNG HÌNH THẾ ────────────────────────────────────────────────────────

## Hàng Long: 3 ô cùng loại thẳng hàng. Chỉ nhận diện từ ô TRÁI NHẤT / TRÊN CÙNG của
## dãy nên mỗi dãy 3 chỉ được đếm một lần. Dãy 4 ô sinh 2 hình thế chồng nhau — đúng
## ý đồ (đầu tư dài hơn được thưởng nhiều hơn), và mọi ô đều được gắn thẻ.
static func _scan_dragon_line(cell: Vector2i, element: String, map: Dictionary,
		w: int, h: int, tagged: Dictionary, groups: Array) -> void:
	for step in _STEPS_RD:
		var b: Vector2i = cell + step
		var c: Vector2i = cell + step * 2
		if not _same(map, b, element, w, h) or not _same(map, c, element, w, h):
			continue
		var line: Array[Vector2i] = [cell, b, c]
		for p in line:
			_tag(tagged, p, DRAGON_LINE)
		groups.append({"id": DRAGON_LINE, "element": element, "cells": line})

## Tứ Trụ: khối 2×2 cùng loại. Nhận diện từ góc TRÊN-TRÁI ⇒ mỗi khối đúng một lần.
static func _scan_four_pillar(cell: Vector2i, element: String, map: Dictionary,
		w: int, h: int, tagged: Dictionary, groups: Array) -> void:
	var right: Vector2i = cell + Vector2i(1, 0)
	var down:  Vector2i = cell + Vector2i(0, 1)
	var diag:  Vector2i = cell + Vector2i(1, 1)
	if not _same(map, right, element, w, h):
		return
	if not _same(map, down, element, w, h):
		return
	if not _same(map, diag, element, w, h):
		return
	var block: Array[Vector2i] = [cell, right, down, diag]
	for p in block:
		_tag(tagged, p, FOUR_PILLAR)
	groups.append({"id": FOUR_PILLAR, "element": element, "cells": block})

## Song Cực: 2 ô KHÁC loại kề nhau mà cặp đó có phản ứng. Chỉ xét hướng phải/xuống
## ⇒ mỗi cặp đúng một lần (cặp trái/lên sẽ do ô kia phát hiện).
static func _scan_dual_pole(cell: Vector2i, element: String, map: Dictionary,
		w: int, h: int, tagged: Dictionary, groups: Array) -> void:
	for step in _STEPS_RD:
		var other: Vector2i = cell + step
		if not _in_bounds(other, w, h) or not map.has(other):
			continue
		var other_element: String = str(map[other])
		if not has_reaction(element, other_element):
			continue
		var pair: Array[Vector2i] = [cell, other]
		for p in pair:
			_tag(tagged, p, DUAL_POLE)
		groups.append({
			"id": DUAL_POLE,
			"element": element,
			"element_b": other_element,
			"cells": pair,
		})

## Trận Vòng: 4 ô cùng loại bao quanh 1 ô THƯỜNG (trên/dưới/trái/phải).
## Nhận diện từ ô PHÍA TRÊN của vòng (center = cell + (0,1)) ⇒ mỗi vòng đúng một lần.
## Chỉ ô GIỮA được gắn thẻ — phần thưởng ("nhận cả 4 Dấu luân phiên") thuộc về tháp
## đứng ở đó, không phải 4 ô tạo vòng.
static func _scan_ring(cell: Vector2i, element: String, map: Dictionary,
		w: int, h: int, tagged: Dictionary, groups: Array) -> void:
	var center: Vector2i = cell + Vector2i(0, 1)
	if not _in_bounds(center, w, h):
		return
	if map.has(center):
		return   # ô giữa phải là ô THƯỜNG
	var ring_cells: Array[Vector2i] = []
	for dir in _ORTHO:
		var p: Vector2i = center + dir
		if not _same(map, p, element, w, h):
			return
		ring_cells.append(p)
	_tag(tagged, center, RING)
	var center_only: Array[Vector2i] = [center]
	groups.append({
		"id": RING,
		"element": element,
		"cells": center_only,
		"center": center,
		"ring_cells": ring_cells,
	})

# ── HELPER ────────────────────────────────────────────────────────────────────

static func _same(map: Dictionary, cell: Vector2i, element: String, w: int, h: int) -> bool:
	if not _in_bounds(cell, w, h):
		return false
	if not map.has(cell):
		return false
	return str(map[cell]) == element

static func _in_bounds(cell: Vector2i, w: int, h: int) -> bool:
	return cell.x >= 0 and cell.x < w and cell.y >= 0 and cell.y < h

static func _tag(tagged: Dictionary, cell: Vector2i, formation_id: String) -> void:
	var ids: Dictionary = tagged.get(cell, {})
	ids[formation_id] = true
	tagged[cell] = ids

static func _empty_result() -> Dictionary:
	return {"cells": {}, "formations": {}, "groups": []}
