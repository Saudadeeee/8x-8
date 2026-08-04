# res://scripts/resources/StartingDeckData.gd
#
# BỘ KHAI CUỘC — biến thể chơi lại rẻ nhất và mạnh nhất.
#
# Balatro có 15 bộ bài, mỗi bộ đổi LUẬT khởi đầu chứ không chỉ đổi chỉ số. Đó là
# lý do ván thứ hai không giống ván thứ nhất. 8x-8 trước đây chỉ có 6 Vua khác
# nhau ở buff — ván nào cũng mở bàn với cùng một bộ quân, cùng một cách nghĩ.
#
# Mỗi bộ ở đây gắn với MỘT loại cờ, và mang theo luật riêng của loại cờ đó:
#   Cờ vua   — bộ chuẩn, nền tảng
#   Cờ tướng — có Pháo, cần ngòi
#   Shogi    — Hương Xa / Kim Tướng, quân bất đối xứng
#   Cá ngựa  — ít quân nhưng đánh mạnh, ngẫu nhiên
#
# Mở khoá bằng điểm tích luỹ (meta) — đây là phần "mở LỐI CHƠI mới" thay cho
# việc chỉ cộng chỉ số.
class_name StartingDeckData
extends Resource

@export var id: String = "deck_standard"
@export var display_name: String = "Standard Set"
@export_multiline var desc: String = ""
## Loại cờ mà bộ này lấy cảm hứng — dùng để nhóm khi hiển thị.
@export_enum("Chess", "Xiangqi", "Shogi", "Ludo") var origin: String = "Chess"

## id quân → số lượng trong bộ khởi đầu.
@export var deck: Dictionary = {}

## Điểm tích luỹ cần để mở. 0 = có sẵn từ đầu.
@export var unlock_cost: int = 0

## Luật riêng của bộ — cùng khoá với EFFECT_KEYS của di vật, áp SUỐT VÁN.
## Nhờ dùng chung khoá nên không phải viết hệ áp dụng thứ hai.
@export var rule: Dictionary = {}

## Chênh lệch tài nguyên khởi đầu (âm = khó hơn).
@export var gold_delta: int = 0
@export var unit_cap_delta: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id, "display_name": display_name, "desc": desc,
		"origin": origin, "deck": deck.duplicate(),
		"unlock_cost": unlock_cost, "rule": rule.duplicate(),
		"gold_delta": gold_delta, "unit_cap_delta": unit_cap_delta,
	}
