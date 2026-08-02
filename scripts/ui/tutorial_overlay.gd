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
const PAGES: Array[Dictionary] = [
	{
		"title": "Một con số phải vượt",
		"body": "Đáy màn hình có hai con số: SÁT THƯƠNG đội hình bạn gây ra trong wave,
"
			+ "và TỔNG MÁU của wave đó.

"
			+ "Xanh = đủ sức. Đỏ = biết trước sẽ thủng, hãy sửa bố cục rồi hãy bấm.
"
			+ "Không có đồng hồ đếm ngược — bạn có bao nhiêu thời gian tuỳ ý.",
		"accent": "Rê chuột lên một ô để xem Nền × Bội của ô đó đến từ đâu",
	},
	{
		"title": "Quân đánh theo nước đi thật",
		"body": "Xe bắn dọc hàng và cột. Tượng bắn hai đường chéo. Mã nhảy chữ L.
"
			+ "Tốt đánh bốn ô chéo kề. Bạn đã biết những luật này rồi.

"
			+ "Quân CỦA BẠN chắn đường trượt của Xe và Tượng — đứng sai chỗ là tự
"
			+ "bịt đường bắn của mình. Ô sáng vàng lúc đặt là ô ĐƯỜNG ĐI bạn phủ được;
"
			+ "chỉ ô đường mới sinh sát thương.",
		"accent": "Bàn khoá 8×8 cả ván và có trần số quân — chọn chỗ đứng là quyết định lớn nhất",
	},
	{
		"title": "Thế cờ nhân sát thương",
		"body": "Xếp quân thành thế có tên để nhân BỘI cho cả vùng:

"
			+ "Trận Pháo — hai Xe cùng hàng hoặc cùng cột (×2.0)
"
			+ "Giao Hoả — một ô bị cả Xe lẫn Tượng phủ (×2.2)
"
			+ "Tường Tốt — ba Tốt liền nhau một hàng (×2.2)
"
			+ "Nước Chĩa — một Mã phủ từ 3 ô đường trở lên (×3.0)

"
			+ "Thế chồng lên nhau thì BỘI nhân với nhau. Đó là đường phá vỡ ván đấu.

"
			+ "Nguồn BỘI thứ hai là Ô NGUYÊN TỐ mua trong shop: quân đứng trên ô nào
"
			+ "thì mang nguyên tố của ô đó, và ô lên cấp thì Bội tăng theo.",
		"accent": "Ô thuộc một thế được tô màu · vòng sáng dưới chân là nguyên tố của ô",
	},
	{
		"title": "Bộ quân là build của bạn",
		"body": "Bạn khởi đầu với một bộ cờ thật. Shop RÚT quân từ bộ đó — muốn thấy Xe
"
			+ "thường xuyên hơn thì phải LOẠI bớt Tốt khỏi bộ.

"
			+ "Shop cũng bán: nâng sao vĩnh viễn cho một loại quân, và phong Hậu cho
"
			+ "toàn bộ Tốt. Bộ mỏng và nặng ký thắng bộ dày và loãng.",
		"accent": "Bấm B để xem bộ quân và tỉ lệ rút từng loại",
	},
	{
		"title": "Nhịp một ván",
		"body": "Chuẩn bị → bấm BẮT ĐẦU WAVE → Shop → chọn 1 trong 3 Perk → lặp lại.

"
			+ "12 wave. Rival King ở wave 5, 9 và 12 — mỗi vua ĐỔI MỘT LUẬT của bàn cờ
"
			+ "(khoá Tượng, chỉ tính nửa bàn, cấm thế cờ cộng dồn…). Đọc luật rồi xếp lại.

"
			+ "Sao chỉ lên bằng cách đặt quân CÙNG LOẠI chồng lên nhau.",
		"accent": "F1 mở Sách tra cứu · Z/X/C ném thuốc giữa trận",
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
	skip.text = "Bỏ qua"
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
	_step_lbl.text = "Bước %d / %d" % [_page + 1, PAGES.size()]
	_title_lbl.text = str(page.get("title", ""))
	_body_lbl.text = str(page.get("body", ""))
	_accent_lbl.text = str(page.get("accent", ""))
	_accent_lbl.visible = _accent_lbl.text != ""
	_next_btn.text = "Bắt đầu chơi" if _page == PAGES.size() - 1 else "Tiếp ›"
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
