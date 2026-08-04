# res://scripts/ui/tutorial_overlay.gd
#
# HƯỚNG DẪN NHẬP MÔN — 5 thẻ, hiện MỘT LẦN ở ván đầu tiên.
#
# Vì sao cần: bất biến thiết kế cốt lõi của game là **"nguyên tố đến từ Ô, không
# từ loại tháp"**. Không ai tự đoán ra được điều đó. Người chơi mới sẽ chỉ mua
# tháp rồi đặt bừa — tức bỏ qua toàn bộ hệ thống làm nên bản sắc của game.
# Sách Nguyên Tố (F1) là chỗ TRA CỨU, không phải chỗ DẠY.
#
# Thiết kế: thẻ tuần tự, không chặn thao tác lâu, bỏ qua được bất cứ lúc nào, và
# KHÔNG BAO GIỜ hiện lại (ghi cờ vào MetaProgress). Người chơi cũ mở lại được
# bằng nút trong màn Cài Đặt.
extends CanvasLayer
class_name TutorialOverlay

signal finished

const DIM_ALPHA: float = 0.72
const CARD_W: int = 560

## Nội dung từng thẻ: tiêu đề, thân, và dòng nhấn mạnh (có thể rỗng).
## Nội dung từng thẻ: tiêu đề, thân, và dòng nhấn mạnh (có thể rỗng).
##
## Thứ tự có chủ đích, dạy theo đúng thứ tự người chơi CẦN biết:
##   1. mục tiêu (số phải vượt)  2. công cụ (nước đi)  3. nhân số (thế cờ)
##   4. build dài hạn (bộ quân)  5. nhịp ván
## Không dạy nguyên tố ở đây: nó là lớp NÂNG CAO, học sau khi đã hiểu Nền × Bội.
## Noi dung tung the: tieu de, than, va dong nhan manh (co the rong).
##
## Thu tu co chu dich, day theo dung thu tu nguoi choi CAN biet:
##   1. muc tieu (so phai vuot)  2. cong cu (nuoc di)  3. nhan so (the co)
##   4. build dai han (bo quan)  5. nhip van
const PAGES: Array[Dictionary] = [
	{
		"title": "One number to beat",
		"body": "Two numbers sit at the bottom of the screen: the DAMAGE your board deals
"
			+ "this wave, and the TOTAL HP of that wave.

"
			+ "Green means you can clear it. Red means you already know you cannot -
"
			+ "fix your board first. There is no countdown; take as long as you want.",
		"accent": "Hover any square to see where its Base x Mult comes from",
	},
	{
		"title": "Pieces move by real chess rules",
		"body": "Rooks fire along ranks and files. Bishops fire on both diagonals.
"
			+ "Knights jump in an L. Pawns hit the four adjacent diagonals.

"
			+ "YOUR OWN pieces block a Rook's or Bishop's line - a bad placement seals
"
			+ "off your own fire. The gold squares shown while placing are PATH squares
"
			+ "you cover; only path squares deal damage.",
		"accent": "The board stays 8x8 all run and your unit count is capped - placement is your biggest decision",
	},
	{
		"title": "Formations multiply your damage",
		"body": "Arrange pieces into named formations to multiply MULT across an area:

"
			+ "Battery - two Rooks on the same rank or file (x2.0)
"
			+ "Crossfire - a square covered by both a Rook and a Bishop (x2.2)
"
			+ "Pawn Wall - three Pawns side by side on one rank (x2.2)
"
			+ "Fork - one Knight covering 3 or more path squares (x3.0)

"
			+ "Overlapping formations MULTIPLY together. That is how a run breaks open.

"
			+ "Your second MULT source is the ELEMENT VEIN bought in the shop: a piece
"
			+ "takes the element of the square it stands on, and levelling that vein
"
			+ "raises the Mult.",
		"accent": "Squares in a formation are tinted - the glowing ring underfoot is the square's element",
	},
	{
		"title": "Your set is your build",
		"body": "You start with a real chess set. The shop DRAWS from it - to see Rooks
"
			+ "more often, you must REMOVE Pawns from the set.

"
			+ "The shop also sells a permanent star-up for one piece type, and promotion
"
			+ "to Queen for all your Pawns. A thin, heavy set beats a thick, diluted one.",
		"accent": "Press B to see your set and each piece's draw odds",
	},
	{
		"title": "The rhythm of a run",
		"body": "Prepare -> press START WAVE -> Shop -> pick 1 of 3 Perks -> repeat.

"
			+ "12 waves. Rival Kings at waves 5, 9 and 12 - each one CHANGES ONE RULE
"
			+ "of the board (silencing Bishops, counting only half the board, banning
"
			+ "formation stacking...). Read the rule, then rebuild.

"
			+ "Stars only come from stacking pieces of the SAME type on each other.",
		"accent": "F1 opens the Codex - Z/X/C throw potions mid-fight",
	},
]


var _page: int = 0
var _root: Control = null
var _card: PanelContainer = null
var _title_lbl: Label = null
var _body_lbl: Label = null
var _accent_lbl: Label = null
var _step_lbl: Label = null
var _next_btn: Button = null

## Dựng và hiện hướng dẫn. Trả về node để bên gọi `await node.finished`.
static func show_for(parent: Node) -> TutorialOverlay:
	var t := TutorialOverlay.new()
	t.name = "TutorialOverlay"
	t.layer = 128            # trên mọi HUD
	parent.add_child(t)
	return t

func _ready() -> void:
	# Chạy được cả khi game đang tạm dừng.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_render_page()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP chứ không IGNORE: nuốt click để người chơi không lỡ tay đặt tháp
	# xuyên qua lớp hướng dẫn.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var boxes := UIStyle.framed_card("epic", "parchment")
	_card = boxes[0]
	var inner: PanelContainer = boxes[1]
	_card.custom_minimum_size = Vector2(CARD_W, 0)
	center.add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	inner.add_child(vbox)

	_step_lbl = Label.new()
	_step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(_step_lbl, 11, UIStyle.TEXT_DIM)
	vbox.add_child(_step_lbl)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.title(_title_lbl, 22, UIStyle.GOLD)
	vbox.add_child(_title_lbl)

	vbox.add_child(UIStyle.separator(UIStyle.BORDER_DIM))

	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_body_lbl, 14, UIStyle.TEXT)
	vbox.add_child(_body_lbl)

	_accent_lbl = Label.new()
	_accent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_accent_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_accent_lbl, 12, UIStyle.GREEN)
	vbox.add_child(_accent_lbl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var skip := Button.new()
	skip.text = "Skip"
	skip.custom_minimum_size = Vector2(150, 38)
	UIStyle.apply_button(skip)
	skip.pressed.connect(_finish)
	row.add_child(skip)

	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(210, 38)
	UIStyle.apply_button(_next_btn)
	_next_btn.pressed.connect(_next)
	row.add_child(_next_btn)

	UIStyle.make_click_target(_card)

func _render_page() -> void:
	var page: Dictionary = PAGES[_page]
	_step_lbl.text = "Step %d of %d" % [_page + 1, PAGES.size()]
	_title_lbl.text = str(page.get("title", ""))
	_body_lbl.text = str(page.get("body", ""))
	_accent_lbl.text = str(page.get("accent", ""))
	_accent_lbl.visible = _accent_lbl.text != ""
	_next_btn.text = "Start playing" if _page == PAGES.size() - 1 else "Next ›"
	UIStyle.pop_in(_card)

func _next() -> void:
	if _page >= PAGES.size() - 1:
		_finish()
		return
	_page += 1
	_render_page()

func _finish() -> void:
	_mark_seen()
	finished.emit()
	queue_free()

## Ghi cờ đã xem vào MetaProgress. Không có save thì bỏ qua yên lặng — hướng dẫn
## hiện lại lần sau còn hơn là crash.
func _mark_seen() -> void:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return
	var meta = gm.get("meta_progress")
	if meta == null:
		return
	meta.set("seen_tutorial", true)
	if meta.has_method("save"):
		meta.save()

## Người chơi đã xem hướng dẫn chưa.
static func already_seen() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return true
	var gm: Node = (loop as SceneTree).root.get_node_or_null("GameManagerSingleton")
	if gm == null:
		return true
	var meta = gm.get("meta_progress")
	if meta == null:
		return true
	return bool(meta.get("seen_tutorial"))

## Xoá cờ để xem lại (nút trong màn Cài Đặt gọi).
static func reset_seen() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var gm: Node = (loop as SceneTree).root.get_node_or_null("GameManagerSingleton")
	if gm == null:
		return
	var meta = gm.get("meta_progress")
	if meta == null:
		return
	meta.set("seen_tutorial", false)
	if meta.has_method("save"):
		meta.save()
