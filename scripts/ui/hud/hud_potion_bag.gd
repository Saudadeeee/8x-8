# res://scripts/ui/hud/hud_potion_bag.gd
#
# TÚI THUỐC (futureplan §3.1) — thanh 3 ô góc dưới-TRÁI + chế độ ngắm.
# Tách khỏi game_hud.gd. HUD giữ phần bắt phím (Z/X/C) vì _unhandled_input
# nằm ở đó, rồi gọi request_aim() vào đây; hai signal potion_aim_requested /
# potion_aim_cancelled vẫn phát TỪ HUD nên game_map không phải đổi gì.
extends Node
class_name HudPotionBag

var hud: CanvasLayer = null

static func attach(owner_hud: CanvasLayer) -> HudPotionBag:
	var c := HudPotionBag.new()
	c.name = "HudPotionBag"
	c.hud = owner_hud
	owner_hud.add_child(c)
	c._build_potion_bag()
	return c

# TÚI THUỐC (futureplan §3.1) — thanh 3 ô góc dưới-TRÁI + chế độ ngắm
# ==============================================================================
# Góc dưới-PHẢI đã có cụm tốc độ game nên túi thuốc nằm bên trái.
# HUD chỉ lo hiển thị + phím tắt; vòng ngắm 3D và việc dùng bình do game_map xử lý
# (HUD phát potion_aim_requested / potion_aim_cancelled).

## Phím tắt 3 ô túi. KHÔNG trùng 1/2/3 (tốc độ game) và Space (pause).
# Z/X/C chứ KHÔNG phải Q/W/E: camera_controller poll thẳng Input.is_key_pressed(KEY_W…)
# nên set_input_as_handled() không chặn được — bấm W sẽ vừa ném thuốc vừa lia camera.
# 1/2/3 đã dành cho tốc độ game, WASD cho pan → Z/X/C là dãy còn trống, sát tay trái.
const HOTKEYS: Array = [KEY_Z, KEY_X, KEY_C]
const POTION_HOTKEY_NAMES: Array[String] = ["Z", "X", "C"]
const POTION_SLOT_SIZE := Vector2(68, 62)
const POTION_SLOTS_SHOWN: int = 3

var _potion_panel: PanelContainer = null
var _potion_slots: Array[PanelContainer] = []
var _potion_key_labels: Array[Label] = []
var _potion_name_labels: Array[Label] = []
## Icon 32x32 của từng ô túi (ẩn khi chưa có file art tương ứng).
var _potion_icons: Array[TextureRect] = []
const POTION_ICON_SIZE: int = 32
var _potion_hint: Label = null
## Bản sao túi lần refresh gần nhất — phần tử là id (String) hoặc dict thuốc.
var _potion_bag_cache: Array = []
var _potion_aiming: bool = false
## Ô đang được ngắm (-1 = không ngắm). HUD tự nhớ vì set_potion_aiming chỉ
## nhận bán kính, không nhận slot.
var _potion_aim_slot: int = -1

func _build_potion_bag() -> void:
	var root_ctrl := hud.get_node_or_null("Control") as Control
	if root_ctrl == null:
		return

	_potion_hint = Label.new()
	_potion_hint.name = "PotionAimHint"
	_potion_hint.anchor_left   = 0.0
	_potion_hint.anchor_right  = 0.0
	_potion_hint.anchor_top    = 1.0
	_potion_hint.anchor_bottom = 1.0
	_potion_hint.offset_left   = 14
	_potion_hint.offset_right  = 470
	_potion_hint.offset_top    = -112
	_potion_hint.offset_bottom = -88
	_potion_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_potion_hint.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_potion_hint.process_mode  = Node.PROCESS_MODE_ALWAYS
	UIStyle.title(_potion_hint, 15, UIStyle.GOLD)
	_potion_hint.visible = false
	root_ctrl.add_child(_potion_hint)

	_potion_panel = PanelContainer.new()
	_potion_panel.name = "PotionBag"
	_potion_panel.anchor_left   = 0.0
	_potion_panel.anchor_right  = 0.0
	_potion_panel.anchor_top    = 1.0
	_potion_panel.anchor_bottom = 1.0
	_potion_panel.offset_left   = 14
	_potion_panel.offset_right  = 250
	_potion_panel.offset_top    = -84
	_potion_panel.offset_bottom = -14
	_potion_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# BẮT BUỘC: thiếu dòng này thì túi thuốc chết cứng khi get_tree().paused
	_potion_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	UIStyle.apply_panel(_potion_panel, "wood")
	UIStyle.set_pad(_potion_panel, 5)
	root_ctrl.add_child(_potion_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_potion_panel.add_child(row)

	_potion_slots.clear()
	_potion_key_labels.clear()
	_potion_name_labels.clear()
	_potion_icons.clear()
	for i in POTION_SLOTS_SHOWN:
		row.add_child(_make_potion_slot(i))

	refresh_potion_bag([])
	UIStyle.pop_in(_potion_panel, 0.14)

## Một ô túi = PanelContainer khung rarity + 2 dòng chữ (phím tắt / tên viết tắt).
## Dùng gui_input thay vì Button để giữ được layout 2 dòng.
func _make_potion_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "PotionSlot%d" % index
	slot.custom_minimum_size = POTION_SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.process_mode = Node.PROCESS_MODE_ALWAYS
	slot.add_theme_stylebox_override("panel", UIStyle.rarity_frame("common"))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 1)
	slot.add_child(vbox)

	var key_lbl := Label.new()
	key_lbl.text = POTION_HOTKEY_NAMES[index] if index < POTION_HOTKEY_NAMES.size() else "?"
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.glyph(key_lbl, 13, UIStyle.TEXT_DIM)
	vbox.add_child(key_lbl)

	# Icon 32x32 (assets/ui/potions/<id>.png). Thiếu file thì ẩn đi và ô rơi về
	# nhãn chữ viết tắt — không có icon vẫn chơi được.
	var icon := TextureRect.new()
	icon.name = "PotionIcon"
	icon.custom_minimum_size = Vector2(POTION_ICON_SIZE, POTION_ICON_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	vbox.add_child(icon)
	_potion_icons.append(icon)

	var name_lbl := Label.new()
	name_lbl.text = "—"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.title(name_lbl, 15, UIStyle.TEXT)
	vbox.add_child(name_lbl)

	slot.gui_input.connect(_on_potion_slot_gui_input.bind(index))
	UIStyle.make_click_target(slot)
	UIStyle.hover_lift(slot, 1.06)

	_potion_slots.append(slot)
	_potion_key_labels.append(key_lbl)
	_potion_name_labels.append(name_lbl)
	return slot

func _on_potion_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	# accept_event() phải gọi trên chính Control nhận input — game_hud là
	# CanvasLayer nên không có hàm đó.
	var slot: PanelContainer = null
	if index >= 0 and index < _potion_slots.size():
		slot = _potion_slots[index]
	if mb.button_index == MOUSE_BUTTON_LEFT:
		request_aim(index)
		if is_instance_valid(slot):
			slot.accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and _potion_aiming:
		cancel_aim()
		if is_instance_valid(slot):
			slot.accept_event()

# ── API công khai (game_map gọi) ─────────────────────────────────────────────

## Vẽ lại 3 ô túi. `bag` nhận id (String) hoặc dict thuốc đầy đủ — id sẽ được
## tra ngược qua PotionSystem để lấy tên/rarity/mô tả.
func refresh_potion_bag(bag: Array) -> void:
	_potion_bag_cache = bag.duplicate()
	for i in _potion_slots.size():
		_update_potion_slot(i)
	# Bình vừa dùng/mất khiến ô đang ngắm rỗng → thoát chế độ ngắm cho sạch.
	if _potion_aiming and _potion_slot_data(_potion_aim_slot).is_empty():
		set_potion_aiming(false, 0.0)

## Bật/tắt chế độ ngắm: đổi con trỏ, hiện dòng nhắc, làm nổi ô đang chọn.
func set_potion_aiming(active: bool, radius: float) -> void:
	_potion_aiming = active
	if not active:
		_potion_aim_slot = -1
	if _potion_hint:
		_potion_hint.visible = active
		if active:
			var data := _potion_slot_data(_potion_aim_slot)
			var pname: String = str(data.get("name", "Thuốc"))
			var scope: String = "TOÀN MAP" if radius >= 100.0 else "bán kính %.1fm" % radius
			_potion_hint.text = " %s — Chọn vùng thả (%s) · Chuột phải để huỷ" % [pname, scope]
			UIStyle.pulse(_potion_hint, 1.08)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if active else Input.CURSOR_ARROW)
	for i in _potion_slots.size():
		_update_potion_slot(i)

# ── Nội bộ ───────────────────────────────────────────────────────────────────

## Yêu cầu ngắm ô `index`. Bấm lại đúng ô đang ngắm = huỷ (toggle).
func request_aim(index: int) -> void:
	if index < 0 or index >= _potion_slots.size():
		return
	if _potion_slot_data(index).is_empty():
		hud._play_sfx("ui_click", -14.0, 0.7)
		# pulse (scale) chứ KHÔNG shake: shake tween "position", mà slot là con
		# của Container — Container quản vị trí nên node sẽ bị ghim sai chỗ.
		if is_instance_valid(_potion_slots[index]):
			UIStyle.pulse(_potion_slots[index], 1.10)
		return
	if _potion_aiming and _potion_aim_slot == index:
		cancel_aim()
		return
	_potion_aim_slot = index
	hud._play_sfx("ui_click")
	hud.potion_aim_requested.emit(index)

func cancel_aim() -> void:
	set_potion_aiming(false, 0.0)
	hud.potion_aim_cancelled.emit()

## Định nghĩa thuốc ở ô `index` ({} nếu ô trống hoặc index sai).
func _potion_slot_data(index: int) -> Dictionary:
	if index < 0 or index >= _potion_bag_cache.size():
		return {}
	return _potion_entry_data(_potion_bag_cache[index])

## Chuẩn hoá 1 phần tử túi thành dict hiển thị.
func _potion_entry_data(entry: Variant) -> Dictionary:
	if entry is Dictionary:
		return entry as Dictionary
	if not (entry is String) or (entry as String).is_empty():
		return {}
	var potion_id: String = entry as String
	var system := _find_potion_system()
	if system and system.has_method("get_potion_by_id"):
		var data: Dictionary = system.get_potion_by_id(potion_id)
		if not data.is_empty():
			return data
	# Không tra được (PotionSystem chưa sẵn sàng) — vẫn hiện id để không mất ô.
	return {"id": potion_id, "name": potion_id, "rarity": "common", "desc": ""}

func _find_potion_system() -> Node:
	var map: Node3D = hud._find_game_map()
	if map == null:
		return null
	var system: Variant = map.get("potion_system")
	if system is Node:
		return system as Node
	return null

func _update_potion_slot(index: int) -> void:
	if index < 0 or index >= _potion_slots.size():
		return
	var slot := _potion_slots[index]
	if not is_instance_valid(slot):
		return
	var data := _potion_slot_data(index)
	var name_lbl := _potion_name_labels[index]
	var key_lbl  := _potion_key_labels[index]
	var is_aiming_this: bool = _potion_aiming and _potion_aim_slot == index

	if data.is_empty():
		slot.add_theme_stylebox_override("panel", UIStyle.rarity_frame("common"))
		slot.modulate = Color(1, 1, 1, 0.42)
		slot.tooltip_text = "Ô túi trống — hạ Elite hoặc Rival King để nhận thuốc (%s)" \
			% POTION_HOTKEY_NAMES[index]
		if index < _potion_icons.size() and is_instance_valid(_potion_icons[index]):
			_potion_icons[index].visible = false
		if is_instance_valid(name_lbl):
			name_lbl.visible = true
			name_lbl.text = "—"
			name_lbl.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		if is_instance_valid(key_lbl):
			key_lbl.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		return

	var rarity: String = str(data.get("rarity", "common"))
	slot.add_theme_stylebox_override("panel", UIStyle.rarity_frame(rarity))
	slot.modulate = Color(1.25, 1.20, 1.00) if is_aiming_this else Color.WHITE
	slot.tooltip_text = "%s [%s]\n%s\nPhím %s" % [
		str(data.get("name", "?")),
		UIStyle.RARITY_NAMES_VI.get(rarity, rarity),
		str(data.get("desc", "")),
		POTION_HOTKEY_NAMES[index],
	]
	# Icon thay cho chữ viết tắt khi có file art.
	var tex := HudIcons.potion(str(data.get("id", "")))
	var has_icon := tex != null
	if index < _potion_icons.size() and is_instance_valid(_potion_icons[index]):
		_potion_icons[index].texture = tex
		_potion_icons[index].visible = has_icon
	if is_instance_valid(name_lbl):
		name_lbl.visible = not has_icon
		name_lbl.text = HudText.short_label(data)
		name_lbl.add_theme_color_override("font_color", UIStyle.rarity_color(rarity))
	if is_instance_valid(key_lbl):
		key_lbl.add_theme_color_override("font_color", UIStyle.GOLD if is_aiming_this else UIStyle.TEXT)
	if is_aiming_this:
		UIStyle.pulse(slot, 1.10)

## Nhãn ngắn cho ô túi — ưu tiên hàm chuẩn của PotionSystem, không có thì tự ghép.

# ==============================================================================

## HUD hỏi để biết có nên nuốt phím ESC hay không.
func is_aiming() -> bool:
	return _potion_aiming
