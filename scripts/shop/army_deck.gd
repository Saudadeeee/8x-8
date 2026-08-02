# res://scripts/shop/army_deck.gd
#
# BỘ QUÂN — bản dịch của bộ bài trong Balatro.
#
# Balatro cho bạn 52 lá và cả ván là chuyện sửa bộ đó: thêm lá, xoá lá, nâng cấp
# lá, đổi chất. "Build" của bạn CHÍNH LÀ bộ bài. Shop không bán món lẻ rời rạc —
# nó bán THAO TÁC LÊN BỘ.
#
# Trước đây 8x-8 không có khái niệm bộ: shop roll 5 món ngẫu nhiên, mua được gì
# thì mua. Không có bộ thì không có build, không có build thì không có ván nào
# khác ván nào — và đó là lý do một roguelike thấy nhạt dù có đủ perk với di vật.
#
# Ở đây bộ khởi đầu là MỘT BỘ CỜ THẬT (8 Tốt, 2 Xe, 2 Mã, 2 Tượng, 1 Hậu). Người
# chơi ai cũng biết bộ đó gồm gì — lại thêm một khoản dạy về 0.
#
# Bốn thao tác, đúng như Balatro:
#   THÊM  — nhét một quân mới vào bộ
#   XOÁ   — bỏ một quân khỏi bộ (tăng tỉ lệ rút quân tốt — đây là nước đi MẠNH)
#   NÂNG  — một quân trong bộ lên sao vĩnh viễn
#   ĐỔI   — biến mọi quân loại A trong bộ thành loại B
class_name ArmyDeck
extends Node

signal deck_changed(counts: Dictionary)
signal drawn(stats_id: String)

## Bộ cờ tiêu chuẩn. Không đếm Vua — Vua là mục tiêu bảo vệ, không phải quân đặt.
const STARTING_DECK := {
	"pawn": 6, "rook": 3, "knight": 2, "bishop": 2, "queen": 1,
}

## Trần số quân trong bộ. Bộ phình vô hạn thì "xoá quân" mất hết ý nghĩa —
## mà xoá quân chính là nước đi chiến thuật sâu nhất của mô hình này.
const MAX_DECK_SIZE: int = 24
## Sàn: dưới mức này thì không xoá được nữa, tránh tự khoá bản thân.
const MIN_DECK_SIZE: int = 6

const TOWER_DIR := "res://res/towers/%s.tres"

## id → số lượng còn TRONG BỘ (chưa rút).
var deck: Dictionary = {}
## id → số sao vĩnh viễn của quân loại đó khi rút ra (1..3).
var permanent_star: Dictionary = {}
## Quân đã rút trong wave này — đầu wave sau trả hết về bộ.
var _drawn_this_wave: Dictionary = {}


func _ready() -> void:
	add_to_group("army_decks")
	if deck.is_empty():
		reset_to_standard()


func reset_to_standard() -> void:
	deck = STARTING_DECK.duplicate()
	permanent_star.clear()
	_drawn_this_wave.clear()
	deck_changed.emit(counts())


# ── Đọc ─────────────────────────────────────────────────────────────────────

func counts() -> Dictionary:
	return deck.duplicate()


func size() -> int:
	var n := 0
	for k in deck:
		n += int(deck[k])
	return n


func star_of(stats_id: String) -> int:
	return clampi(int(permanent_star.get(stats_id, 1)), 1, 3)


## Xác suất rút trúng một loại, tính theo bộ hiện tại. Hiện trong UI để việc
## XOÁ quân đọc được thành con số — không thấy số thì không ai chịu xoá.
func draw_chance(stats_id: String) -> float:
	var total := size()
	if total <= 0:
		return 0.0
	return float(int(deck.get(stats_id, 0))) / float(total)


func stats_for(stats_id: String) -> TowerStats:
	var path := TOWER_DIR % stats_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as TowerStats


# ── Thao tác lên bộ (shop bán những thứ này) ────────────────────────────────

## Thêm `n` quân loại `stats_id` vào bộ. Trả false nếu bộ đã đầy.
func add_unit(stats_id: String, n: int = 1) -> bool:
	if size() + n > MAX_DECK_SIZE:
		return false
	if stats_for(stats_id) == null:
		return false
	deck[stats_id] = int(deck.get(stats_id, 0)) + n
	deck_changed.emit(counts())
	return true


## Xoá `n` quân loại `stats_id` khỏi bộ. Nước đi MẠNH: bộ mỏng đi thì tỉ lệ rút
## trúng quân tốt tăng lên. Chặn ở MIN_DECK_SIZE để không tự khoá.
func remove_unit(stats_id: String, n: int = 1) -> bool:
	var have := int(deck.get(stats_id, 0))
	if have < n or size() - n < MIN_DECK_SIZE:
		return false
	if have - n <= 0:
		deck.erase(stats_id)
	else:
		deck[stats_id] = have - n
	deck_changed.emit(counts())
	return true


## Nâng sao VĨNH VIỄN cho một loại — mọi quân loại đó rút ra đều mang sao này.
func upgrade_star(stats_id: String) -> bool:
	if not deck.has(stats_id):
		return false
	var cur := star_of(stats_id)
	if cur >= 3:
		return false
	permanent_star[stats_id] = cur + 1
	deck_changed.emit(counts())
	return true


## Biến MỌI quân loại `from_id` trong bộ thành `to_id` (Tốt phong Hậu).
func transmute(from_id: String, to_id: String) -> bool:
	var have := int(deck.get(from_id, 0))
	if have <= 0 or stats_for(to_id) == null:
		return false
	deck.erase(from_id)
	deck[to_id] = int(deck.get(to_id, 0)) + have
	deck_changed.emit(counts())
	return true


# ── Rút ─────────────────────────────────────────────────────────────────────

## Rút ngẫu nhiên một quân từ bộ (theo tỉ lệ số lượng). Trả "" nếu bộ rỗng.
## Quân rút ra bị TRỪ khỏi bộ trong wave này — bộ mỏng dần trong wave, đầy lại
## ở đầu wave sau. Đây là nhịp "tay bài" của Balatro.
func draw() -> String:
	var total := size()
	if total <= 0:
		return ""
	var roll := randi() % total
	var acc := 0
	for id in deck:
		acc += int(deck[id])
		if roll < acc:
			_take(id)
			return str(id)
	return ""


## Rút `n` quân khác nhau nếu có thể — dùng để lấp quầy shop.
func draw_hand(n: int) -> Array[String]:
	var out: Array[String] = []
	for _i in n:
		var id := draw()
		if id == "":
			break
		out.append(id)
	return out


func _take(id: String) -> void:
	var have := int(deck.get(id, 0))
	if have <= 1:
		deck.erase(id)
	else:
		deck[id] = have - 1
	_drawn_this_wave[id] = int(_drawn_this_wave.get(id, 0)) + 1
	drawn.emit(id)
	deck_changed.emit(counts())


## Trả mọi quân đã rút về bộ. game_map gọi ở đầu mỗi pha chuẩn bị.
func restock() -> void:
	if _drawn_this_wave.is_empty():
		return
	for id in _drawn_this_wave:
		deck[id] = int(deck.get(id, 0)) + int(_drawn_this_wave[id])
	_drawn_this_wave.clear()
	deck_changed.emit(counts())
