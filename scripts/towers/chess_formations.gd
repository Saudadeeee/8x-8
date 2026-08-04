# res://scripts/towers/chess_formations.gd
#
# THẾ CỜ — bản dịch của "ván bài" trong Balatro.
#
# Balatro: 5 lá trên tay tạo thành Đôi / Sảnh / Thùng / Cù lũ, mỗi loại một mức
# Chip và Bội. Người chơi không học gì cả — luật poker ai cũng biết.
#
# Ở đây: vị trí quân trên bàn tạo thành thế, mỗi thế một hệ số BỘI. Và cũng
# không phải học gì — "hai Xe cùng cột" thì nhìn là thấy.
#
# Khác cốt lõi với `FormationDetector` cũ: cái đó dò theo Ô NGUYÊN TỐ (mua ô rồi
# xếp ô). Cái này dò theo HÌNH HỌC QUÂN — thứ người chơi động vào mỗi lượt đặt.
# Hai hệ chạy song song được: ô cho Nền, quân cho Bội.
#
# Nguyên tắc thiết kế của từng thế:
#   • Phải NHÌN LÀ THẤY, không cần đọc bảng.
#   • Phải mâu thuẫn với nhau — không xếp được đồng thời mọi thế.
#   • Bội nhân nhau, nên chồng thế là con đường "phá vỡ toán học" kiểu Balatro.
class_name ChessFormations
extends Node

## Định nghĩa thế. `mult` là hệ số BỘI áp lên các ô mà thế đó phủ.
## Thêm thế mới = thêm một mục ở đây + một nhánh trong `_detect`.
const SPEC := {
	"battery": {
		"name": "Battery",  "mult": 2.0,
		"desc": "Two or more Rooks on the same rank or file.",
	},
	"crossfire": {
		"name": "Crossfire",   "mult": 2.2,
		"desc": "A square covered by a Rook and a Bishop at once.",
	},
	"knight_pair": {
		"name": "Knight Pair",    "mult": 1.8,
		"desc": "Two Knights sharing at least one covered square.",
	},
	"pawn_wall": {
		"name": "Pawn Wall",  "mult": 2.2,
		"desc": "Three or more Pawns side by side on one rank.",
	},
	"royal_guard": {
		"name": "Royal Guard",     "mult": 2.6,
		"desc": "A Queen guarded by at least two adjacent pieces.",
	},
	"echelon": {
		"name": "Echelon",    "mult": 2.4,
		"desc": "Three or more pieces on the same diagonal.",
	},
	"fork": {
		"name": "Fork",  "mult": 3.0,
		"desc": "One Knight covering 3 or more path squares.",
	},
}

## Thứ tự hiển thị (và thứ tự dò) — thế mạnh xếp sau để đọc như bảng xếp hạng.
const ORDER: Array[String] = [
	"pawn_wall", "knight_pair", "battery", "crossfire", "echelon",
	"royal_guard", "fork",
]

signal formations_changed(counts: Dictionary)

var map: Node3D = null

## Vector2i → Array[String] các id thế đang phủ ô đó.
var _cells: Dictionary = {}
## id → số lần thế đó thành hình.
var _counts: Dictionary = {}


static func attach(target: Node3D) -> ChessFormations:
	var cf := ChessFormations.new()
	cf.name = "ChessFormations"
	cf.map = target
	target.add_child(cf)
	return cf


static func display_name(id: String) -> String:
	return str(SPEC.get(id, {}).get("name", id))


static func mult_of(id: String) -> float:
	return float(SPEC.get(id, {}).get("mult", 1.0))


static func describe(id: String) -> String:
	return str(SPEC.get(id, {}).get("desc", ""))


# ── API đọc ─────────────────────────────────────────────────────────────────

## Các thế đang áp lên một ô, dạng [{name, mult}] — BoardScore đọc thẳng.
func formations_at(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _cells.get(cell, []):
		out.append({"name": display_name(str(id)), "mult": mult_of(str(id))})
	return out


## Tích BỘI của mọi thế phủ ô này.
func mult_at(cell: Vector2i) -> float:
	var m := 1.0
	for id in _cells.get(cell, []):
		m *= mult_of(str(id))
	return m


func counts() -> Dictionary:
	return _counts.duplicate()


# ── Dò ──────────────────────────────────────────────────────────────────────

## Quét lại toàn bộ bàn. game_map gọi mỗi khi bố cục quân đổi.
func recount() -> void:
	_cells = {}
	_counts = {}
	var by_cell := {}          # Vector2i → tower
	for t in _towers():
		if t.has_method("home_cell"):
			by_cell[t.home_cell()] = t
	_detect(by_cell)
	formations_changed.emit(counts())


func _detect(by_cell: Dictionary) -> void:
	var K := ChessPattern.Kind
	var rooks: Array[Vector2i] = []
	var bishops: Array[Vector2i] = []
	var knights: Array = []
	var pawns: Array[Vector2i] = []
	var queens: Array = []
	for cell in by_cell:
		var t = by_cell[cell]
		match int(t.pattern_kind()):
			K.ROOK:   rooks.append(cell)
			K.BISHOP: bishops.append(cell)
			K.KNIGHT: knights.append(t)
			K.PAWN:   pawns.append(cell)
			K.QUEEN:  queens.append(t)

	# Trận Pháo — hai Xe cùng hàng hoặc cùng cột.
	for i in rooks.size():
		for j in range(i + 1, rooks.size()):
			if rooks[i].x == rooks[j].x or rooks[i].y == rooks[j].y:
				_mark("battery", _line_between(rooks[i], rooks[j]))

	# Thê Đội — ba quân trở lên trên cùng một đường chéo.
	var diag_groups := {}
	for cell: Vector2i in by_cell:
		var k1: int = cell.x - cell.y
		var k2: int = cell.x + cell.y
		diag_groups["a%d" % k1] = (diag_groups.get("a%d" % k1, []) as Array) + [cell]
		diag_groups["b%d" % k2] = (diag_groups.get("b%d" % k2, []) as Array) + [cell]
	for key in diag_groups:
		var group: Array = diag_groups[key]
		if group.size() >= 3:
			_mark("echelon", group)

	# Tường Tốt — ba Tốt liền nhau trên một hàng.
	var by_row := {}
	for c in pawns:
		by_row[c.y] = (by_row.get(c.y, []) as Array) + [c.x]
	for row in by_row:
		var xs: Array = by_row[row]
		xs.sort()
		var run: Array[Vector2i] = []
		for i in xs.size():
			if i > 0 and int(xs[i]) != int(xs[i - 1]) + 1:
				if run.size() >= 3:
					_mark("pawn_wall", run)
				run = []
			run.append(Vector2i(int(xs[i]), int(row)))
		if run.size() >= 3:
			_mark("pawn_wall", run)

	# Cấm Vệ — Hậu có ≥2 quân kề.
	for q in queens:
		var qc: Vector2i = q.home_cell()
		var guards := 0
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				if by_cell.has(qc + Vector2i(dx, dy)):
					guards += 1
		if guards >= 2:
			_mark("royal_guard", q.covered_cells)

	# Song Mã — hai Mã phủ chung ≥1 ô.
	for i in knights.size():
		for j in range(i + 1, knights.size()):
			var shared: Array[Vector2i] = []
			for c in knights[i].covered_cells:
				if knights[j].covers_cell(c):
					shared.append(c)
			if not shared.is_empty():
				_mark("knight_pair", shared)

	# Nước Chĩa — một Mã phủ ≥3 ô đường đi.
	var path := _path_lookup()
	for kn in knights:
		var hit: Array[Vector2i] = []
		for c in kn.covered_cells:
			if path.has(c):
				hit.append(c)
		if hit.size() >= 3:
			_mark("fork", hit)

	# Giao Hoả — ô bị cả Xe lẫn Tượng phủ. Dò sau cùng vì cần tầm phủ đã dựng.
	var rook_cover := {}
	var bishop_cover := {}
	for cell in by_cell:
		var t = by_cell[cell]
		var kind := int(t.pattern_kind())
		if kind == K.ROOK or kind == K.QUEEN:
			for c in t.covered_cells: rook_cover[c] = true
		if kind == K.BISHOP or kind == K.QUEEN:
			for c in t.covered_cells: bishop_cover[c] = true
	var cross: Array[Vector2i] = []
	for c in rook_cover:
		if bishop_cover.has(c):
			cross.append(c)
	if not cross.is_empty():
		_mark("crossfire", cross)


func _mark(id: String, cells: Array) -> void:
	_counts[id] = int(_counts.get(id, 0)) + 1
	for c in cells:
		if not (c is Vector2i):
			continue
		var list: Array = _cells.get(c, [])
		if not list.has(id):
			list.append(id)
			_cells[c] = list


## Các ô nằm GIỮA hai quân trên cùng hàng/cột (kể cả hai đầu).
func _line_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [a, b]
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	if step == Vector2i.ZERO:
		return out
	var cur := a + step
	while cur != b:
		out.append(cur)
		cur += step
	return out


func _path_lookup() -> Dictionary:
	var out := {}
	var gc = map.get("grid_controller") if map else null
	if gc == null:
		return out
	for c in gc.current_path_grid:
		out[c] = true
	return out


func _towers() -> Array:
	if map == null or not map.is_inside_tree():
		return []
	return map.get_tree().get_nodes_in_group("towers")
