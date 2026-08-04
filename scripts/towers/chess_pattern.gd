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

	# ── Nước đi mượn từ các loại cờ khác ─────────────────────────────────
	# Mỗi loại cờ đóng góp một cơ chế mà cờ vua KHÔNG có. Đây là cách mở rộng
	# chiều sâu mà không đụng vào concept: vẫn là `attack_pattern` trong .tres,
	# vẫn là nước đi quyết định tầm phủ.
	CANNON,    # PHÁO (cờ tướng) — đi như Xe nhưng PHẢI có đúng 1 quân làm NGÒI
	LANCE,     # HƯƠNG XA (shogi) — chỉ một hướng, nhưng tầm rất xa
	GOLD,      # KIM TƯỚNG (shogi) — 6 ô bất đối xứng: 4 hướng + 2 chéo trước
	XIANG,     # TƯỢNG (cờ tướng) — chéo ĐÚNG 2 ô, bị cản ở ô giữa
	DICE,      # CÁ NGỰA — vành khuyên nhưng bỏ qua ô chẵn/lẻ theo nhịp
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

## Bước nhảy chữ L XA — chỉ dùng khi có di vật "Horseshoe".
const KNIGHT_FAR: Array[Vector2i] = [
	Vector2i(1, 3), Vector2i(3, 1), Vector2i(-1, 3), Vector2i(-3, 1),
	Vector2i(1, -3), Vector2i(3, -1), Vector2i(-1, -3), Vector2i(-3, -1),
]

## TẦM = SỐ VÒNG cho mọi nước nhảy. Bậc 1 chứ không phải 2-3.
##
## Bậc thưa (2 hoặc 3) làm phần lớn nguồn "+1 reach" trở thành số chết — đo được
## Mã tầm 4 và tầm 5 phủ y hệt 16 ô, Tốt tầm 3 và 4 y hệt 8 ô. Người chơi nhặt
## được mà không thấy gì đổi, đúng thứ vừa báo lỗi.
## Bậc 1 thì luật đọc được bằng một câu — "tầm N = N vòng" — và MỌI +1 đều đổi.
const JUMP_RING_STEP: int = 1
const KNIGHT_RING_STEP: int = 1
const XIANG_RING_STEP: int = 1

## Tầm tối thiểu của SIEGE — máy bắn đá không hạ nòng được.
const SIEGE_MIN_RANGE: int = 2

## Tên tiếng Việt để hiện trong panel quân và sách tra cứu.
## Hướng "tiến" mặc định của quân bất đối xứng (Hương Xa, Kim Tướng).
## Địch đi từ path[0] tới Vua, nên hướng tiến hợp lý nhất là +Y (xuống dưới).
const FORWARD: Vector2i = Vector2i(0, 1)

const KIND_LABEL := {
	Kind.ROOK:   "Rank & file (sliding)",
	Kind.BISHOP: "Both diagonals (sliding)",
	Kind.QUEEN:  "All eight directions (sliding)",
	Kind.KNIGHT: "L-jump (never blocked)",
	Kind.PAWN:   "Four adjacent diagonals",
	Kind.KING:   "Eight adjacent squares",
	Kind.SIEGE:  "Ring (cannot hit adjacent)",
	Kind.RADIAL: "All directions in range",
	Kind.CANNON: "Cannon - needs EXACTLY 1 screen piece",
	Kind.LANCE:  "Lance - one direction, very long reach",
	Kind.GOLD:   "Gold General - 4 straight + 2 forward diagonals",
	Kind.XIANG:  "Xiangqi Elephant - exactly 2 diagonal, blockable at midpoint",
	Kind.DICE:   "Dice Rider - wide ring, heavy damage",
}

## Ký hiệu ngắn cho card shop — người chơi đọc được hình dạng trước khi đọc chữ.
## Chỉ dùng ký hiệu ĐÃ CÓ trong font tự vẽ. Ký tự lạ sẽ thành ô tofu khi export
## sang máy khác — batch test 8 chặn đúng lớp lỗi này.
const KIND_GLYPH := {
	Kind.ROOK: "＋", Kind.BISHOP: "✕", Kind.QUEEN: "✦", Kind.KNIGHT: "▸",
	Kind.PAWN: "◆", Kind.KING: "▣", Kind.SIEGE: "◎", Kind.RADIAL: "●",
	Kind.CANNON: "✷", Kind.LANCE: "▲", Kind.GOLD: "⬢",
	Kind.XIANG: "✕", Kind.DICE: "⛁",
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
			# Mã đắt vòng hơn: bước dài sẵn nên mỗi vòng thêm rất nhiều ô.
			_jump(out, from, KNIGHT_STEPS, blocked, rings_for(r, KNIGHT_RING_STEP))
		Kind.PAWN:
			_jump(out, from, DIAG, blocked, rings_for(r, JUMP_RING_STEP))
		Kind.KING:
			_jump(out, from, ORTHO, blocked, rings_for(r, JUMP_RING_STEP))
			_jump(out, from, DIAG, blocked, rings_for(r, JUMP_RING_STEP))
		Kind.SIEGE:
			_ring(out, from, SIEGE_MIN_RANGE, r, blocked)
		Kind.CANNON:
			_cannon(out, from, r, blocked)
		Kind.LANCE:
			_lance(out, from, r, blocked)
		Kind.GOLD:
			var gr := rings_for(r, JUMP_RING_STEP)
			_jump(out, from, ORTHO, blocked, gr)
			_jump(out, from, [FORWARD + Vector2i(1, 0), FORWARD + Vector2i(-1, 0)],
				blocked, gr)
		Kind.XIANG:
			_xiang(out, from, blocked, rings_for(r, XIANG_RING_STEP))
		Kind.DICE:
			_ring(out, from, 1, r, blocked)
		_:
			_ring(out, from, 1, r, blocked)
	return out


## Quân ở `from` có với tới `to` không. Dùng ở vòng lặp bắn nên tránh dựng mảng.
static func covers(kind: int, from: Vector2i, to: Vector2i, max_range: int,
		blocked: Dictionary = {}, pierce: int = 0) -> bool:
	if from == to:
		return false
	# Ô ĐÍCH có quân của mình đứng thì không phải mục tiêu — địch không đứng đó
	# được. `_slide`/`_jump` đã loại ô này khỏi `cells()`, nhưng `_clear_line`
	# duyệt HỞ ở đầu cuối nên `covers()` lại trả true. Hai điểm vào phải khớp
	# nhau tuyệt đối, nếu không tầm phủ vẽ ra một đằng và bắn một nẻo.
	if blocked.has(to):
		return false
	var d := to - from
	var r: int = maxi(1, max_range)
	match kind:
		Kind.KNIGHT:
			# Vòng k: bước chữ L nhân k. |dx·dy| = 2k².
			var kn_rings := rings_for(r, KNIGHT_RING_STEP)
			for k in range(1, kn_rings + 1):
				if absi(d.x) == k and absi(d.y) == 2 * k: return true
				if absi(d.x) == 2 * k and absi(d.y) == k: return true
			return false
		Kind.PAWN:
			var pw_rings := rings_for(r, JUMP_RING_STEP)
			return absi(d.x) == absi(d.y) and absi(d.x) >= 1 and absi(d.x) <= pw_rings
		Kind.KING:
			var kg_rings := rings_for(r, JUMP_RING_STEP)
			var cheb_k: int = maxi(absi(d.x), absi(d.y))
			# Vòng k gồm ô có |dx| và |dy| đều thuộc {0, k} (chữ thập + chéo).
			for k in range(1, kg_rings + 1):
				if (absi(d.x) == k or d.x == 0) and (absi(d.y) == k or d.y == 0) 						and cheb_k == k:
					return true
			return false
		Kind.SIEGE:
			var cheb_s: int = maxi(absi(d.x), absi(d.y))
			return cheb_s >= SIEGE_MIN_RANGE and cheb_s <= r
		Kind.RADIAL, Kind.DICE:
			return maxi(absi(d.x), absi(d.y)) <= r
		Kind.GOLD:
			var gd_rings := rings_for(r, JUMP_RING_STEP)
			var cheb_g: int = maxi(absi(d.x), absi(d.y))
			if cheb_g < 1 or cheb_g > gd_rings:
				return false
			if absi(d.x) != 0 and absi(d.x) != cheb_g: return false
			if absi(d.y) != 0 and absi(d.y) != cheb_g: return false
			# 4 hướng thẳng + 2 chéo TRƯỚC; hai chéo sau thì không.
			if d.x == 0 or d.y == 0:
				return true
			# So DẤU, không so giá trị: ở vòng 2 thì d.y = 2 chứ không phải 1.
			return signi(d.y) == FORWARD.y
		Kind.XIANG:
			var xg_rings := rings_for(r, XIANG_RING_STEP)
			if absi(d.x) != absi(d.y) or absi(d.x) % 2 != 0 					or absi(d.x) / 2 < 1 or absi(d.x) / 2 > xg_rings:
				return false
			# Cản tâm: ô chéo kề bị chiếm thì không đi hướng đó được.
			return not blocked.has(from + Vector2i(signi(d.x), signi(d.y)))
		Kind.LANCE:
			if d.x != 0 or signi(d.y) != FORWARD.y:
				return false
			return _clear_line(from, to, r, blocked, pierce)
		Kind.CANNON:
			if d.x != 0 and d.y != 0:
				return false
			return _cannon_hits(from, to, r, blocked)
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


## Nước NHẢY có nhiều VÒNG theo tầm bắn.
##
## Vì sao phải có: nước nhảy vốn là một tập ô CỐ ĐỊNH, nên `max_range` không ảnh
## hưởng gì — đo được Mã/Tốt/Vua/Kim Tướng/Tượng Điền phủ y hệt nhau ở tầm 3, 4
## và 6. Nghĩa là mọi nguồn "+1 reach" (perk, trang bị, ô Băng, ★3, Hàng Long)
## là SỐ CHẾT với sáu trên mười ba nước đi. Người chơi nhặt được mà không thấy
## khác biệt gì — đúng lớp lỗi "tính năng chết" nặng nhất.
##
## Cách sửa: mỗi bậc tầm mở thêm một VÒNG cùng hình dạng (bước × k). Mã tầm cao
## nhảy được cả vòng chữ L xa; Tốt tầm cao đánh chéo hai ô. Luật vẫn đọc được
## bằng một câu, và mọi nước đi đều phản ứng với tầm.
static func rings_for(max_range: int, step_size: int) -> int:
	return 1 + maxi(0, int(floor(float(maxi(1, max_range) - 1) / float(maxi(1, step_size)))))


static func _jump(out: Array[Vector2i], from: Vector2i, steps: Array[Vector2i],
		blocked: Dictionary, rings: int = 1) -> void:
	for k in range(1, maxi(1, rings) + 1):
		for s in steps:
			var c := from + s * k
			if not blocked.has(c) and not out.has(c):
				out.append(c)


## PHÁO (cờ tướng) — đi thẳng như Xe, nhưng CHỈ ăn được khi có ĐÚNG MỘT quân
## nằm giữa nó và mục tiêu ("ngòi"). Ô trước ngòi KHÔNG bắn được.
##
## Đây là nước đi thú vị nhất mượn từ các loại cờ khác: cả game dạy "quân mình
## chắn đường là xấu", Pháo lật ngược lại — bạn PHẢI đặt một quân làm ngòi thì
## nó mới bắn được. Quân của mình từ vật cản thành tài nguyên nhắm bắn.
static func _cannon(out: Array[Vector2i], from: Vector2i, max_range: int,
		blocked: Dictionary) -> void:
	for dir in ORTHO:
		var cur := from
		var screened := false        # đã vượt qua ngòi chưa
		for _i in max_range:
			cur += dir
			if blocked.has(cur):
				if screened:
					break            # quân THỨ HAI chặn hẳn
				screened = true      # quân ĐẦU là ngòi
				continue
			if screened:
				out.append(cur)      # chỉ ô SAU ngòi mới bắn được


static func _cannon_hits(from: Vector2i, to: Vector2i, max_range: int,
		blocked: Dictionary) -> bool:
	var d := to - from
	var dist: int = maxi(absi(d.x), absi(d.y))
	if dist > max_range or dist == 0:
		return false
	var step := Vector2i(signi(d.x), signi(d.y))
	var cur := from + step
	var screens := 0
	while cur != to:
		if blocked.has(cur):
			screens += 1
		cur += step
	return screens == 1              # đúng MỘT ngòi, không hơn không kém


## HƯƠNG XA (shogi) — chỉ tiến thẳng một hướng, nhưng đi xa hơn Xe nhiều.
static func _lance(out: Array[Vector2i], from: Vector2i, max_range: int,
		blocked: Dictionary) -> void:
	_slide(out, from, [FORWARD], max_range, blocked)


## TƯỢNG cờ tướng — chéo ĐÚNG hai ô, và bị "cản tâm": ô chéo kề bị chiếm thì
## không đi được hướng đó. Khác hẳn Tượng cờ vua (trượt vô hạn).
static func _xiang(out: Array[Vector2i], from: Vector2i, blocked: Dictionary,
		rings: int = 1) -> void:
	for dir in DIAG:
		if blocked.has(from + dir):
			continue                 # cản tâm
		for k in range(1, maxi(1, rings) + 1):
			var c := from + dir * (2 * k)
			if not blocked.has(c) and not out.has(c):
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
