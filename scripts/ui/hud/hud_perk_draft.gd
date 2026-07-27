# res://scripts/ui/hud/hud_perk_draft.gd
#
# DRAFT PERK — màn chọn 1 trong 3 sau mỗi wave. Cũng được dùng lại cho phần
# thưởng boss (game_map gọi cùng show_perk_draft với 3 lựa chọn khác).
# Tách khỏi game_hud.gd; HUD giữ hai hàm uỷ quyền cùng tên nên game_map không
# phải đổi gì.
extends Node
class_name HudPerkDraft

var hud: CanvasLayer = null

static func attach(owner_hud: CanvasLayer) -> HudPerkDraft:
	var c := HudPerkDraft.new()
	c.name = "HudPerkDraft"
	c.hud = owner_hud
	owner_hud.add_child(c)
	return c

# ── Perk Draft (chọn 1 trong 3 sau mỗi wave) ──────────────────────────────────
const PERK_RARITY_COLORS := {
	"common":    Color(0.62, 0.62, 0.62, 1.0),   # xám
	"rare":      Color(0.35, 0.55, 1.00, 1.0),   # xanh dương
	"epic":      Color(0.72, 0.35, 0.95, 1.0),   # tím
	"legendary": Color(1.00, 0.78, 0.15, 1.0),   # vàng
}
const PERK_RARITY_NAMES := {
	"common": "Thường", "rare": "Hiếm", "epic": "Sử Thi", "legendary": "Huyền Thoại",
}

var _perk_draft_overlay: ColorRect = null
## Khóa input khi card đang chạy animation chọn — chặn double-pick.
var _perk_pick_locked: bool = false
## Shop đang bị ẩn tạm vì perk draft → cần trả lại khi draft đóng.
var _shop_hidden_by_draft: bool = false

## Hiện popup draft: 3 card cạnh nhau, viền màu theo rarity, click để chọn.
## on_pick được gọi với perk id (String) — popup tự đóng sau khi chọn.
func show_perk_draft(perks: Array, on_pick: Callable) -> void:
	hide_perk_draft()
	_perk_pick_locked = false
	if perks.is_empty():
		return
	var root_ctrl = hud.get_node_or_null("Control")
	if not root_ctrl:
		return

	# Shop mở cùng lúc sẽ lộ ra sau các card → tạm ẩn, trả lại sau khi chọn.
	_shop_hidden_by_draft = is_instance_valid(hud.shop_panel) and hud.shop_panel.visible
	if _shop_hidden_by_draft:
		hud.shop_panel.visible = false

	# Overlay chặn input phía sau — player phải chọn 1 perk
	# 0.86 chu khong 0.62: ban co 3D sang va nhieu chi tiet, dim nhat thi the bai
	# khong noi len duoc va man hinh doc rat roi.
	_perk_draft_overlay = UIStyle.dim_overlay(0.86)
	_perk_draft_overlay.name = "PerkDraftOverlay"
	root_ctrl.add_child(_perk_draft_overlay)

	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 14)
	_perk_draft_overlay.add_child(center)

	var title = Label.new()
	title.text = "⭐  CHỌN 1 ĐẶC QUYỀN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title, 30, UIStyle.GOLD)
	center.add_child(title)
	UIStyle.pop_in(title)

	var subtitle = Label.new()
	subtitle.text = "Phần thưởng sau wave — hiệu lực đến hết ván"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(subtitle, 13, UIStyle.TEXT_DIM)
	center.add_child(subtitle)

	var cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 18)
	center.add_child(cards_row)

	var card_index := 0
	for perk in perks:
		var card := _create_perk_card(perk, on_pick)
		cards_row.add_child(card)
		# Stagger — card lật ra lần lượt, tạo cảm giác "chia bài"
		UIStyle.pop_in(card, 0.08 + card_index * 0.09)
		card_index += 1

func hide_perk_draft() -> void:
	if _perk_draft_overlay and is_instance_valid(_perk_draft_overlay):
		# Rời tree trước khi free → ModelIcon trong card perk nhả hạn mức 3D ngay
		var parent := _perk_draft_overlay.get_parent()
		if parent:
			parent.remove_child(_perk_draft_overlay)
		_perk_draft_overlay.queue_free()
	_perk_draft_overlay = null
	_perk_pick_locked = false
	if _shop_hidden_by_draft and is_instance_valid(hud.shop_panel):
		hud.shop_panel.visible = true
	_shop_hidden_by_draft = false

## Card perk: khung rarity (vàng/tím/xanh/xám) bọc panel giấy da + icon 3D nếu
## perk gắn với một unit, ngược lại icon ký hiệu ◆ theo màu rarity.
func _create_perk_card(perk: Dictionary, on_pick: Callable) -> Control:
	var rarity: String = perk.get("rarity", "common")
	var accent: Color = UIStyle.rarity_color(rarity)

	var boxes := UIStyle.framed_card(rarity, "parchment")
	var card: PanelContainer = boxes[0]
	var inner: PanelContainer = boxes[1]
	card.custom_minimum_size = Vector2(206, 268)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	inner.add_child(vbox)

	var rarity_lbl = Label.new()
	rarity_lbl.text = "◆ %s" % UIStyle.RARITY_NAMES_VI.get(rarity, rarity)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(rarity_lbl, 12, accent)
	vbox.add_child(rarity_lbl)

	# Icon, theo thứ tự ưu tiên:
	#   1. PNG 48×48 tại assets/ui/perks/<id>.png — tác giả nội dung chỉ cần thả
	#      file đúng tên id là card có tranh riêng, không phải đụng code.
	#   2. Model 3D nếu perk gắn với một loại quân (`unit_id`).
	#   3. Ký hiệu ◆ theo bậc hiếm — luôn có, nên card không bao giờ trống.
	var perk_unit_id := String(perk.get("unit_id", ""))
	var perk_tex: Texture2D = HudIcons.perk(String(perk.get("id", "")))
	if perk_tex != null:
		var art := TextureRect.new()
		art.texture = perk_tex
		art.custom_minimum_size = Vector2(76, 76)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(art)
	elif perk_unit_id != "" and ResourceLoader.exists("res://assets/models/%s.gltf" % perk_unit_id):
		var icon := ModelIcon.new()
		icon.name = "PerkModelIcon"
		icon.set_icon_size(76)
		vbox.add_child(icon)
		icon.setup_by_id(perk_unit_id)
	else:
		var symbol = Label.new()
		symbol.text = String(perk.get("icon", "✦"))
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.glyph(symbol, 46, accent)
		vbox.add_child(symbol)

	var name_lbl = Label.new()
	name_lbl.text = perk.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.title(name_lbl, 16, UIStyle.TEXT)
	vbox.add_child(name_lbl)

	vbox.add_child(UIStyle.separator(accent.darkened(0.25)))

	var desc_lbl = Label.new()
	desc_lbl.text = perk.get("desc", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyle.body(desc_lbl, 11, UIStyle.TEXT.darkened(0.15))
	vbox.add_child(desc_lbl)

	var pick_btn = Button.new()
	pick_btn.text = "CHỌN"
	pick_btn.custom_minimum_size = Vector2(0, 38)
	UIStyle.apply_button_accent(pick_btn, accent, 14)
	pick_btn.pressed.connect(func():
		_pick_perk_card_animated(card, perk.get("id", ""), on_pick))
	vbox.add_child(pick_btn)

	# Click cả card cũng chọn được
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_pick_perk_card_animated(card, perk.get("id", ""), on_pick))
	UIStyle.make_click_target(card)  # nút "Chọn" bên trong vẫn bấm được
	UIStyle.hover_lift(card, 1.055)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return card

## Scale card mượt về target — kill tween cũ (lưu trong meta) để không giật.
func _tween_card_scale(card: Control, target: Vector2) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size / 2.0
	# has_meta trước: get_meta(key, null) vẫn báo lỗi khi thiếu key.
	if card.has_meta("scale_tween"):
		var prev = card.get_meta("scale_tween")
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(card, "scale", target, 0.12)
	card.set_meta("scale_tween", t)

## Chọn perk kèm hiệu ứng: khóa input → sfx perk_pick → flash card sáng lên
## → đóng draft và gọi on_pick.
func _pick_perk_card_animated(card: Control, perk_id: String, on_pick: Callable) -> void:
	if _perk_pick_locked:
		return
	_perk_pick_locked = true
	_lock_perk_cards_hover()
	hud._play_sfx("perk_pick")
	if not is_instance_valid(card):
		_on_perk_card_picked(perk_id, on_pick)
		return
	UIStyle.center_pivot(card)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(card, "modulate", Color(1.9, 1.8, 1.4, 1.0), 0.08)
	t.tween_property(card, "scale", Vector2(1.14, 1.14), 0.08)
	t.set_parallel(false)
	t.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.12)
	t.tween_callback(func(): _on_perk_card_picked(perk_id, on_pick))

## Khoá hover-lift trên mọi card perk khi đã chọn — tránh scale giật khi chuột
## di chuyển trong lúc animation chạy.
func _lock_perk_cards_hover() -> void:
	if not is_instance_valid(_perk_draft_overlay):
		return
	for node in _perk_draft_overlay.find_children("*", "PanelContainer", true, false):
		if node is Control:
			UIStyle.set_hover_locked(node as Control, true)

func _on_perk_card_picked(perk_id: String, on_pick: Callable) -> void:
	hide_perk_draft()
	if perk_id != "" and on_pick.is_valid():
		on_pick.call(perk_id)
