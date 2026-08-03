# res://scripts/towers/chess_pattern.gd
#
# NƯỚC ĐI QUÂN CỜ — nguồn sự thật duy nhất cho việc "quân này với tới ô nào".
#
# Vì sao đổi từ bán kính sang nước đi: với bán kính, đặt quân ở đâu cũng gần như
# nhau — đo được bot rải 106 tháp trên bàn mà chưa lần nào phải cân nhắc vị trí.
# Với đường thẳng và đường chéo thì vị trí quyết định tất cả, và người chơi
# KHÔNG CẦN học gì: ai cũng biết Xe đi dọc, Tượng đi chéo, Mã nhảy chữ L.
# Ngân sách dạy về 0, dồn hết cho các lớp phía trên (thế cờ, di vật).
#
# Hai nhóm nước đi:
#   • TRƯỢT (Xe/Tượng/Hậu) — đi tới khi chạm quân khác. Bị CHẶN chính là ràng
#     buộc tạo ra câu đố xếp hình; bỏ chặn thì Xe nào cũng phủ trọn cột.
#   • NHẢY (Mã/Tốt/Vua) — tập ô cố định, KHÔNG bị chặn.
#
# Chặn chỉ tính QUÂN CỦA MÌNH. Địch là mục tiêu, không phải vật cản — nếu không
# thì con địch đầu hàng che hết cả cột và tháp phía sau vô dụng.
class_name ChessPattern
extends Object


## Kiểu nước đi. Khai trong `TowerStats.attack_pattern` nên đổi được bằng
## Inspector — thêm quân mới không phải sửa dòng code nào.
enum Kind {
	ROOK,      # dọc hàng + cột, trượt
	BISHOP,    # hai đường chéo, trượt
	QUEEN,     # cả 8 hướng, trượt
	KNIGHT,    # 8 ô chữ L, không bị chặn
	PAWN,      # 4 ô chéo kề, không bị chặn
	KING,      # 8 ô kề, không bị chặn
	SIEGE,     # vành khuyên: có tầm TỐI THIỂU, không đánh được sát mình
	RADIAL,    # mọi ô trong bán kính — hành vi cũ, để dành cho quân "ngoài luật cờ"
}

const ORTHO: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const DIAG: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const KNIGHT_STEPS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
	Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1),
]

## Bước nhảy chữ L XA — chỉ dùng khi có di vật "Vó Ngựa".
const KNIGHT_FAR: Array[Vector2i] = [
	Vector2i(1, 3), Vector2i(3, 1), Vector2i(-1, 3), Vector2i(-3, 1),
	Vector2i(1, -3), Vector2i(3, -1), Vector2i(-1, -3), Vector2i(-3, -1),
]

## Tầm tối thiểu của SIEGE — máy bắn đá không hạ nòng được.
const SIEGE_MIN_RANGE: int = 2

## Tên tiếng Việt để hiện trong panel quân và sách tra cứu.
const KIND_LABEL := {
	Kind.ROOK:   "Dọc hàng & cột (trượt)",
	Kind.BISHOP: "Hai đường chéo (trượt)",
	Kind.QUEEN:  "Tám hướng (trượt)",
	Kind.KNIGHT: "Nhảy chữ L (không bị chặn)",
	Kind.PAWN:   "Bốn ô chéo kề",
	Kind.KING:   "Tám ô kề",
	Kind.SIEGE:  "Vành khuyên (không đánh sát mình)",
	Kind.RADIAL: "Mọi hướng trong tầm",
}

## Ký hiệu ngắn cho card shop — người chơi đọc được hình dạng trước khi đọc chữ.
## Chỉ dùng ký hiệu ĐÃ CÓ trong font tự vẽ. Ký tự lạ sẽ thành ô tofu khi export
## sang máy khác — batch test 8 chặn đúng lớp lỗi này.
const KIND_GLYPH := {
	Kind.ROOK: "＋", Kind.BISHOP: "✕", Kind.QUEEN: "✦", Kind.KNIGHT: "▸",
	Kind.PAWN: "◆", Kind.KING: "▣", Kind.SIEGE: "◎", Kind.RADIAL: "●",
}


static func label(kind: int) -> String:
	return str(KIND_LABEL.get(kind, "?"))


static func glyph(kind: int) -> String:
	return str(KIND_GLYPH.get(kind, "?"))


## Toàn bộ ô mà quân đứng ở `from` với `max_range` vươn tới được.
##
## `blocked` là {Vector2i → true} các ô CÓ QUÂN CỦA MÌNH (kể cả ô `from`).
## Ô bị chặn không nằm trong kết quả và cắt đường trượt phía sau nó.
##
## Trả về mảng mới mỗi lần gọi — nơi gọi được phép sửa thoải mái.
## `pierce` = số quân CỦA MÌNH mà đường trượt đi xuyên qua được trước khi dừng.
## 0 = luật cờ chuẩn. Đây là thang ĐỘ, không phải công tắc bật/tắt: đo được chặn
## làm mất 0% tầm phủ khi có 4 quân nhưng 19% khi có 7 quân, và trần cuối ván là
## 20 quân — một di vật "xuyên hết" sẽ vô dụng lúc đầu và khổng lồ lúc cuối.
##
## Đo tầm phủ trung bình của Xe (tầm 5) trên bàn 8×8:
##     quân |  0  |  1  |  2  | ∞
##       10 |15.0 |18.6 |18.6 | 20.0
##       18 |11.0 |15.7 |16.3 | 20.0
##       22 | 9.6 |14.4 |15.5 | 20.0
## Xuyên 1 lấy lại phần lớn (+24%…+49%), xuyên 2 chỉ thêm ~7%, vô hạn hơn xuyên
## 2 không đáng kể. Nghĩa là giá trị dồn hết vào lượt xuyên ĐẦU — định giá di vật
## phải theo đó, đừng bán lượt thứ hai với giá gấp đôi.
static func cells(kind: int, from: Vector2i, max_range: int,
		blocked: Dictionary = {}, pierce: int = 0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = maxi(1, max_range)
	match kind:
		Kind.ROOK:
			_slide(out, from, ORTHO, r, blocked, pierce)
		Kind.BISHOP:
			_slide(out, from, DIAG, r, blocked, pierce)
		Kind.QUEEN:
			_slide(out, from, ORTHO, r, blocked, pierce)
			_slide(out, from, DIAG, r, blocked, pierce)
		Kind.KNIGHT:
			_jump(out, from, KNIGHT_STEPS, blocked)
		Kind.PAWN:
			_jump(out, from, DIAG, blocked)
		Kind.KING:
			_jump(out, from, ORTHO, blocked)
			_jump(out, from, DIAG, blocked)
		Kind.SIEGE:
			_ring(out, from, SIEGE_MIN_RANGE, r, blocked)
		_:
			_ring(out, from, 1, r, blocked)
	return out


## Quân ở `from` có với tới `to` không. Dùng ở vòng lặp bắn nên tránh dựng mảng.
static func covers(kind: int, from: Vector2i, to: Vector2i, max_range: int,
		blocked: Dictionary = {}, pierce: int = 0) -> bool:
	if from == to:
		return false
	var d := to - from
	var r: int = maxi(1, max_range)
	match kind:
		Kind.KNIGHT:
			return absi(d.x * d.y) == 2
		Kind.PAWN:
			return absi(d.x) == 1 and absi(d.y) == 1
		Kind.KING:
			return maxi(absi(d.x), absi(d.y)) == 1
		Kind.SIEGE:
			var cheb_s: int = maxi(absi(d.x), absi(d.y))
			return cheb_s >= SIEGE_MIN_RANGE and cheb_s <= r
		Kind.RADIAL:
			return maxi(absi(d.x), absi(d.y)) <= r
		Kind.ROOK:
			if d.x != 0 and d.y != 0:
				return false
			return _clear_line(from, to, r, blocked, pierce)
		Kind.BISHOP:
			if absi(d.x) != absi(d.y):
				return false
			return _clear_line(from, to, r, blocked, pierce)
		Kind.QUEEN:
			var straight := (d.x == 0 or d.y == 0)
			var diagonal := absi(d.x) == absi(d.y)
			if not (straight or diagonal):
				return false
			return _clear_line(from, to, r, blocked, pierce)
	return false


## Đường trượt từ `from` tới `to` có thông không (và trong tầm không).
static func _clear_line(from: Vector2i, to: Vector2i, max_range: int,
		blocked: Dictionary, pierce: int = 0) -> bool:
	var d := to - from
	var dist: int = maxi(absi(d.x), absi(d.y))
	if dist > max_range:
		return false
	var step := Vector2i(signi(d.x), signi(d.y))
	var cur := from + step
	var left: int = maxi(0, pierce)
	while cur != to:
		if blocked.has(cur):
			if left <= 0:
				return false
			left -= 1
		cur += step
	return true


static func _slide(out: Array[Vector2i], from: Vector2i, dirs: Array[Vector2i],
		max_range: int, blocked: Dictionary, pierce: int = 0) -> void:
	for dir in dirs:
		var cur := from
		var left: int = maxi(0, pierce)
		for _i in max_range:
			cur += dir
			if blocked.has(cur):
				if left <= 0:
					break     # hết lượt xuyên — dừng hẳn hướng này
				left -= 1
				continue      # xuyên qua, nhưng KHÔNG phủ chính ô có quân đứng
			out.append(cur)


static func _jump(out: Array[Vector2i], from: Vector2i, steps: Array[Vector2i],
		blocked: Dictionary) -> void:
	for s in steps:
		var c := from + s
		if not blocked.has(c):
			out.append(c)


static func _ring(out: Array[Vector2i], from: Vector2i, min_r: int, max_r: int,
		blocked: Dictionary) -> void:
	for dx in range(-max_r, max_r + 1):
		for dy in range(-max_r, max_r + 1):
			var cheb: int = maxi(absi(dx), absi(dy))
			if cheb < min_r or cheb > max_r:
				continue
			var c := from + Vector2i(dx, dy)
			if not blocked.has(c):
				out.append(c)
