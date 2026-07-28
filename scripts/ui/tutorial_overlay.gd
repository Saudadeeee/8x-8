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
const PAGES: Array[Dictionary] = [
	{
		"title": "Bàn cờ 8×8",
		"body": "Địch đi theo con đường có mũi tên vàng, từ mép bàn tới chỗ Vua.\n"
			+ "Vua mất hết máu là thua.\n\n"
			+ "Bạn đặt quân lên các ô TRỐNG hai bên đường. Quân là tháp cố định —\n"
			+ "đặt xuống là tự bắn, không di chuyển được.",
		"accent": "Chuột giữa xoay góc nhìn · lăn chuột phóng to · WASD di chuyển",
	},
	{
		"title": "Nguyên tố đến từ Ô, KHÔNG từ quân",
		"body": "Đây là điều quan trọng nhất của game.\n\n"
			+ "Mua ô nguyên tố trong shop rồi đặt xuống bàn. Quân nào đứng trên ô đó\n"
			+ "sẽ mang nguyên tố của ô — cùng một con Pawn đứng trên Mạch Hoả và trên\n"
			+ "Mạch Băng là hai thứ hoàn toàn khác nhau.",
		"accent": "Vòng sáng dưới chân tháp cho biết nó đang mang nguyên tố nào",
	},
	{
		"title": "Ghép Dấu để nổ phản ứng",
		"body": "Mỗi phát bắn để lại một Dấu nguyên tố trên địch. Mỗi con mang tối đa\n"
			+ "2 Dấu. Khi hai Dấu hợp thành cặp thì NỔ và tiêu thụ cả hai.\n\n"
			+ "Hoả + Băng = Tan Chảy · Hoả + Thuỷ = Bốc Hơi · Lôi + Thuỷ = Dẫn Điện\n"
			+ "Trộn nhiều nguyên tố sát thương cao hơn hẳn dồn một loại.",
		"accent": "Nhấn F1 bất cứ lúc nào để mở Sách Nguyên Tố — đủ 10 phản ứng",
	},
	{
		"title": "Ghép sao và xếp hình thế",
		"body": "Đặt quân CÙNG LOẠI lên quân đã có để ghép sao: ★★ mạnh gấp 1.8 lần,\n"
			+ "★★★ gấp 3.2 lần. Ô nguyên tố cũng ghép được để lên cấp.\n\n"
			+ "Xếp 3 ô cùng nguyên tố thành hàng ngang/dọc sẽ tạo hình thế Hàng Long,\n"
			+ "cho thêm thưởng cho cả vùng.",
		"accent": "Ba ô cùng loại thành hàng = Hàng Long · bốn ô vuông = Tứ Trụ",
	},
	{
		"title": "Nhịp một ván",
		"body": "Chuẩn bị → Wave → Shop → chọn 1 trong 3 Perk → lặp lại.\n\n"
			+ "Cứ 3 wave bản đồ mở rộng thêm một hướng. Wave 10 là boss.\n"
			+ "Vàng không tiêu là vàng lãng phí — cuối mỗi wave có lãi, nhưng có trần.",
		"accent": "Bấm Z / X / C để ném thuốc ngay giữa trận",
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
