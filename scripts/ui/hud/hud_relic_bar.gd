# res://scripts/ui/hud/hud_relic_bar.gd
#
# THANH DI VẬT (futureplan §3.3) — 5 ô, góc trên-PHẢI. Tách khỏi game_hud.gd.
# HUD uỷ quyền qua refresh_relics(); bấm một ô = bán di vật đó.
extends Node
class_name HudRelicBar

var hud: CanvasLayer = null

static func attach(owner_hud: CanvasLayer) -> HudRelicBar:
	var c := HudRelicBar.new()
	c.name = "HudRelicBar"
	c.hud = owner_hud
	owner_hud.add_child(c)
	c._build_relic_bar()
	return c

# THANH DI VẬT (futureplan §3.3) — 5 ô, góc trên-PHẢI
# ==============================================================================
# Di vật đổi LUẬT CHƠI cả run nên phải nhìn thấy thường trực, khác trang bị
# (gắn từng tháp, chỉ xem khi mở panel tháp đó).
# Bấm một ô = bán di vật đó, hoàn 40% giá.

const RELIC_SLOTS_SHOWN: int = 5
# 34x50: rong vua du 5 o trong panel 210px (5*34 + 4*4 separation + 8 pad = 194),
# cao 50 de icon 32px khong bi bop.
const RELIC_SLOT_SIZE := Vector2(34, 50)

var _relic_panel: PanelContainer = null
var _relic_slots: Array[Button] = []

func _build_relic_bar() -> void:
	var root_ctrl := hud.get_node_or_null("Control") as Control
	if root_ctrl == null:
		return

	_relic_panel = PanelContainer.new()
	_relic_panel.name = "RelicBar"
	_relic_panel.anchor_left   = 1.0
	_relic_panel.anchor_right  = 1.0
	_relic_panel.anchor_top    = 0.0
	_relic_panel.anchor_bottom = 0.0
	# Thẳng hàng với cột King (rộng UIStyle.HUD_RIGHT_PANEL_WIDTH, cách mép 12) và nằm DƯỚI nó.
	_relic_panel.offset_left   = -float(UIStyle.HUD_RIGHT_PANEL_WIDTH) - 12.0
	_relic_panel.offset_right  = -12.0
	_relic_panel.offset_top    = 306
	_relic_panel.offset_bottom = 372
	_relic_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_relic_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	UIStyle.apply_panel(_relic_panel, "wood")
	UIStyle.set_pad(_relic_panel, 4)
	root_ctrl.add_child(_relic_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_panel.add_child(row)

	_relic_slots.clear()
	for i in RELIC_SLOTS_SHOWN:
		var slot := Button.new()
		slot.custom_minimum_size = RELIC_SLOT_SIZE
		slot.flat = true
		slot.text = "·"
		slot.disabled = true
		HudText.style_button_text(slot, 10, UIStyle.TEXT_DIM)
		slot.pressed.connect(_on_relic_slot_pressed.bind(i))
		row.add_child(slot)
		_relic_slots.append(slot)

	_relic_panel.visible = false   # chưa có di vật thì không chiếm chỗ màn hình

	# Nhắc phím codex — đặt ngay dưới thanh di vật, luôn hiện.
	# Hệ nguyên tố không tự giải thích được, người chơi phải biết chỗ tra.
	var codex_hint := Label.new()
	codex_hint.name = "CodexHint"
	codex_hint.text = "F1 — Sách Nguyên Tố"
	codex_hint.anchor_left = 1.0
	codex_hint.anchor_right = 1.0
	codex_hint.offset_left = -float(UIStyle.HUD_RIGHT_PANEL_WIDTH) - 12.0
	codex_hint.offset_right = -12.0
	codex_hint.offset_top = 378
	codex_hint.offset_bottom = 400
	codex_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	codex_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	codex_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.body(codex_hint, 12, UIStyle.TEXT_DIM)
	root_ctrl.add_child(codex_hint)

## game_map / RelicSystem gọi mỗi khi danh sách di vật đổi.
func refresh_relics(ids: Array) -> void:
	if _relic_panel == null:
		return
	_relic_panel.visible = not ids.is_empty()
	var relics := _find_relic_system()
	for i in range(_relic_slots.size()):
		var slot := _relic_slots[i]
		if i >= ids.size():
			slot.icon = null
			slot.text = "·"
			slot.tooltip_text = ""
			slot.disabled = true
			HudText.style_button_text(slot, 10, UIStyle.TEXT_DIM)
			continue
		var id := str(ids[i])
		var data: Dictionary = relics.call("relic_data", id) if relics != null else {}
		var display := str(data.get("name", id))
		# Icon 32x32 nếu có (assets/ui/relics/<id>.png); thiếu file thì rơi về
		# nhãn viết tắt chữ đầu mỗi từ — ô 46px không chứa nổi tên đầy đủ.
		var tex := HudIcons.relic(id)
		if tex != null:
			slot.icon = tex
			slot.text = ""
			slot.expand_icon = true
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			slot.icon = null
			slot.text = HudText.short_label({"name": display})
		slot.tooltip_text = "%s\n%s\n\n(Bấm để bán, hoàn 40%%)" % [display, str(data.get("desc", ""))]
		slot.disabled = false
		HudText.style_button_text(slot, 13, UIStyle.GOLD)

func _find_relic_system() -> Node:
	var map: Node3D = hud._find_game_map()
	if map == null:
		return null
	var found: Variant = map.get("relic_system")
	return found as Node if (found is Node and is_instance_valid(found)) else null

func _on_relic_slot_pressed(index: int) -> void:
	var relics := _find_relic_system()
	if relics == null:
		return
	relics.call("sell_relic", index)
	refresh_relics(relics.call("owned"))

# ==============================================================================
