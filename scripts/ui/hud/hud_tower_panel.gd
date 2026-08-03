# res://scripts/ui/hud/hud_tower_panel.gd
#
# PANEL THÔNG TIN (trượt ra từ mép TRÁI) — dùng cho CẢ hai thứ người chơi bấm
# vào trên bàn cờ: một tháp (chỉ số, nguyên tố ô đang đứng, ô trang bị) và một
# ô lãnh thổ trống (nguyên tố, cấp ô, hình thế, nút bán).
# Tách khỏi game_hud.gd; HUD uỷ quyền ba hàm show_tower_info /
# show_territory_info / hide_tower_info nên game_map không phải đổi gì.
extends Node
class_name HudTowerPanel

var hud: CanvasLayer = null

var _tower_info_panel: PanelContainer = null
var _tower_info_visible: bool = false
var _tower_info_tween: Tween = null
## ModelIcon 3D chỉ sống khi panel mở — huỷ khi đóng để không giữ SubViewport.
var _tower_info_icon: ModelIcon = null

static func attach(owner_hud: CanvasLayer) -> HudTowerPanel:
	var c := HudTowerPanel.new()
	c.name = "HudTowerPanel"
	c.hud = owner_hud
	owner_hud.add_child(c)
	c._build_tower_info_panel()
	return c

# ── Tower info panel (slide-in from left) ─────────────────────────────────────
const TOWER_INFO_WIDTH := 220
## Chiều cao khởi điểm của panel tower info; nội dung nới thêm nếu cần.
# 560 chứ không 300: panel nay còn chứa dòng nguyên tố + các ô trang bị + kho.
# Để 300 thì phần trang bị nằm dưới mép ScrollContainer, người chơi không thấy
# là có thể lắp đồ. 560 + top 210 = 770 < 1080 nên vẫn không đụng đáy màn hình.
const TOWER_INFO_MIN_HEIGHT := 560.0
## Mép trên panel tower info — chừa chỗ cho panel trạng thái ở góc trên-trái.
const TOWER_INFO_TOP := 210.0

func _build_tower_info_panel() -> void:
	var root_ctrl = hud.get_node_or_null("Control")
	if not root_ctrl:
		return
	_tower_info_panel = PanelContainer.new()
	_tower_info_panel.name = "TowerInfoPanel"
	# Bám mép trái, cao VỪA NỘI DUNG (trước đây anchor_bottom = 1.0 nên panel
	# giấy da kéo suốt chiều cao màn hình, trông như một cột trống).
	_tower_info_panel.anchor_left   = 0.0
	_tower_info_panel.anchor_right  = 0.0
	_tower_info_panel.anchor_top    = 0.0
	_tower_info_panel.anchor_bottom = 0.0
	_tower_info_panel.offset_left   = -TOWER_INFO_WIDTH
	_tower_info_panel.offset_right  = 0
	# Nằm DƯỚI panel trạng thái (HP/vàng/RD) để không che nhau.
	_tower_info_panel.offset_top    = TOWER_INFO_TOP
	# offset_bottom chỉ là chiều cao khởi điểm — PanelContainer tự nới theo
	# minimum_size của nội dung, nên panel luôn "vừa khít" thay vì kéo hết màn.
	_tower_info_panel.offset_bottom = TOWER_INFO_TOP + TOWER_INFO_MIN_HEIGHT
	_tower_info_panel.grow_vertical = Control.GROW_DIRECTION_END
	UIStyle.apply_panel(_tower_info_panel, "parchment")
	root_ctrl.add_child(_tower_info_panel)

## Giải phóng ModelIcon 3D của tower info (gọi trước khi build lại / khi đóng).
## dispose() nhả hạn mức icon 3D NGAY, không đợi queue_free cuối frame.
func _free_tower_info_icon() -> void:
	if is_instance_valid(_tower_info_icon):
		_tower_info_icon.dispose()
	_tower_info_icon = null

## Biome của ô tháp đang mở panel — nhớ lại để vẽ lại panel sau khi lắp/gỡ trang bị.
var _tower_info_biome: String = ""
## Tháp đang mở panel. Giữ tham chiếu để làm mới khi kho trang bị đổi TỪ NƠI KHÁC
## (mua trong shop, di vật đổi số ô) — không có nó thì panel hiện số liệu cũ.
var _tower_info_node: Node3D = null
var _equipment_signals_bound: bool = false

## Nối một lần vào EquipmentSystem. Gọi lười vì hệ đó do game_map tạo sau HUD.
func _bind_equipment_signals() -> void:
	if _equipment_signals_bound:
		return
	var equipment := _find_equipment_system()
	if equipment == null:
		return
	_equipment_signals_bound = true
	if equipment.has_signal("inventory_changed"):
		equipment.connect("inventory_changed", func(_inv): _on_equipment_state_changed())
	if equipment.has_signal("tower_equipment_changed"):
		equipment.connect("tower_equipment_changed", func(_t, _ids): _on_equipment_state_changed())

func _on_equipment_state_changed() -> void:
	# Chỉ vẽ lại khi panel đang mở — tránh dựng lại UI vô ích mỗi lần mua đồ.
	if _tower_info_visible and is_instance_valid(_tower_info_node):
		_refresh_tower_panel(_tower_info_node)

func show_tower_info(stats: TowerStats, biome_key: String = "", tower_node: Node3D = null) -> void:
	if not _tower_info_panel:
		return
	_tower_info_biome = biome_key
	_tower_info_node = tower_node
	_bind_equipment_signals()
	_free_tower_info_icon()
	for child in _tower_info_panel.get_children():
		_tower_info_panel.remove_child(child)
		child.queue_free()
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tower_info_panel.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header: ModelIcon 3D lớn (fallback texture 2D) đặt trong khung rarity
	var icon_tex = stats.texture if stats.texture else stats.projectile_texture
	var icon_frame := PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", UIStyle.rarity_frame("rare"))
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.pixel_filter(icon_frame)
	vbox.add_child(icon_frame)
	_tower_info_icon = ModelIcon.new()
	_tower_info_icon.name = "TowerInfoModelIcon"
	_tower_info_icon.set_icon_size(112)
	icon_frame.add_child(_tower_info_icon)
	_tower_info_icon.setup_by_id(stats.id, icon_tex)
	UIStyle.pop_in(icon_frame)

	var name_lbl = Label.new()
	# Tên tiếng Việt qua bảng dùng chung; .tres chưa có trong bảng thì giữ tên gốc.
	name_lbl.text = UIStyle.unit_name_vi(str(stats.id)) if str(stats.id) != "" else stats.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(name_lbl, 17, UIStyle.GOLD)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)
	if stats.faction != "":
		var faction_lbl = Label.new()
		faction_lbl.text = "[%s]" % stats.faction
		faction_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.body(faction_lbl, 10, UIStyle.TEXT_DIM)
		vbox.add_child(faction_lbl)

	vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))

	# Real-time stats if tower_node provided, otherwise base stats
	if tower_node and is_instance_valid(tower_node):
		var cur_dmg: int = tower_node.get("current_damage") if tower_node.get("current_damage") != null else stats.base_damage
		var cur_spd: float = tower_node.get("current_attack_speed") if tower_node.get("current_attack_speed") != null else stats.attack_speed
		var cur_rng: int = tower_node.get("current_range") if tower_node.get("current_range") != null else stats.attack_range
		var dmg_bonus: int = cur_dmg - stats.base_damage
		var spd_bonus: float = stats.attack_speed - cur_spd
		var rng_bonus: int = cur_rng - stats.attack_range
		_add_buffed_int_row(vbox, "⚔ Sát thương", stats.base_damage, dmg_bonus)
		_add_buffed_float_row(vbox, " Tốc đánh", stats.attack_speed, -spd_bonus, "s")
		_add_buffed_int_row(vbox, "◎ Tầm bắn", stats.attack_range, rng_bonus)
	else:
		_add_info_row(vbox, "⚔ Sát thương", str(stats.base_damage))
		_add_info_row(vbox, " Tốc đánh", "%.2fs" % stats.attack_speed)
		_add_info_row(vbox, "◎ Tầm bắn", str(stats.attack_range))

	# Special effects
	if stats.slow_amount > 0.0:
		_add_info_row(vbox, "❄ Làm chậm", "%.0f%% × %.1fs" % [stats.slow_amount * 100, stats.slow_duration])
	if stats.burn_dps > 0:
		_add_info_row(vbox, " Thiêu đốt", "%d DPS × %.1fs" % [stats.burn_dps, stats.burn_duration])
	if stats.splash_radius > 0.0:
		# splash_radius trong .tres vẫn là px (16 px = 1 ô) — chỉ quy đổi khi hiển thị
		_add_info_row(vbox, " AoE Splash", "%.1f ô" % (stats.splash_radius / 16.0))
	if stats.projectile_count > 1:
		_add_info_row(vbox, " Số đạn", "×%d" % stats.projectile_count)

	# Territory buff on tile
	if biome_key != "":
		vbox.add_child(UIStyle.separator(UIStyle.GREEN.darkened(0.35)))
		# Đọc thẳng bảng gốc thay vì chép tay: bản chép cũ ghi "+6 ATK" và đã lệch
		# hẳn sau khi buff ô chuyển sang phần trăm.
		var bdata: Dictionary = TerritoryManager.BIOME_STATS.get(biome_key, {})
		var ter_lbl = Label.new()
		ter_lbl.text = "%s — %s" % [str(bdata.get("name", biome_key)),
			str(bdata.get("desc", ""))]
		UIStyle.body(ter_lbl, 11, Color(0.3, 0.85, 0.4))
		ter_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(ter_lbl)

	# Nguyên tố đang bắn + ô trang bị (chỉ khi mở từ một tháp thật trên bàn)
	if tower_node and is_instance_valid(tower_node):
		_build_pattern_row(vbox, tower_node)
		_build_star_row(vbox, tower_node)
		_build_element_row(vbox, tower_node)
		_build_buff_source_section(vbox, tower_node)
		_build_equipment_section(vbox, tower_node)
		_build_performance_section(vbox, tower_node)

	# Description
	if stats.description != "":
		vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
		var desc = Label.new()
		desc.text = stats.description
		UIStyle.body(desc, 10, UIStyle.TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	_slide_tower_info(true)
	_resize_tower_panel.call_deferred()

## Panel tháp cũng KHÔNG nằm trong container nào. Nội dung dài ngắn tuỳ số ô
## trang bị và số món trong kho, nên phải tính lại chiều cao sau mỗi lần dựng —
## để cố định thì dòng cuối bị cắt (đúng lỗi vừa gặp ở panel shop).
const TOWER_INFO_H_MAX: float = 860.0

func _resize_tower_panel() -> void:
	if _tower_info_panel == null or not is_instance_valid(_tower_info_panel):
		return
	# ĐO VBOX BÊN TRONG, không đo panel: panel bọc một ScrollContainer, mà
	# ScrollContainer luôn báo minimum size rất nhỏ (nó cuộn được) nên panel
	# tưởng nội dung ngắn và cắt mất dòng cuối.
	var content_h: float = 0.0
	for scroll in _tower_info_panel.get_children():
		if scroll is ScrollContainer:
			for inner in (scroll as ScrollContainer).get_children():
				if inner is Control:
					content_h = maxf(content_h, (inner as Control).get_combined_minimum_size().y)
	content_h += 28.0   # padding của panel + viền
	var want: float = clampf(content_h, TOWER_INFO_MIN_HEIGHT, TOWER_INFO_H_MAX)
	# Neo mép trên cố định, nới xuống dưới; nếu tràn đáy màn thì kéo lên.
	var top: float = TOWER_INFO_TOP
	var screen_h: float = float(get_viewport().get_visible_rect().size.y)
	if top + want > screen_h - 120.0:
		top = maxf(12.0, screen_h - 120.0 - want)
	_tower_info_panel.offset_top = top
	_tower_info_panel.offset_bottom = top + want

## Nước đi + số ô đang phủ. Đây là dòng QUAN TRỌNG NHẤT của panel trong thiết
## kế mới: sức mạnh của một quân không nằm ở chỉ số mà ở chỗ nó đứng.
func _build_pattern_row(parent: VBoxContainer, tower_node: Node3D) -> void:
	if not tower_node.has_method("pattern_kind"):
		return
	var kind: int = int(tower_node.pattern_kind())
	parent.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
	_add_info_row(parent, "%s Nước đi" % ChessPattern.glyph(kind),
		ChessPattern.label(kind))

	var covered: Array = tower_node.get("covered_cells")
	if not (covered is Array):
		return
	var map := tower_node.get_node_or_null("/root/GameMap")
	var on_path := 0
	if map != null:
		var gc = map.get("grid_controller")
		if gc != null:
			for c in covered:
				if gc.is_path_cell(c):
					on_path += 1
	# Tầm HIỆU DỤNG (đã cộng mọi nguồn) chứ không phải tầm gốc trong .tres —
	# người chơi nhặt "+1 tầm" phải thấy con số này nhúc nhích.
	var base_r: int = int(tower_node.stats.attack_range) if tower_node.stats else 0
	var eff_r: int = int(tower_node.effective_range()) if tower_node.has_method("effective_range") else base_r
	_add_info_row(parent, "◎ Tầm hiệu dụng",
		"%d%s" % [eff_r, "  (gốc %d)" % base_r if eff_r != base_r else ""])
	_add_info_row(parent, "◎ Ô đang phủ", "%d ô (%d trên đường)"
		% [(covered as Array).size(), on_path])
	var hint2 := Label.new()
	hint2.text = "Ô vàng trên bàn = ô đường quân này với tới. Chỉ ô đó sinh sát thương."
	UIStyle.body(hint2, 14, UIStyle.TEXT_DIM)
	hint2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint2)
	if on_path == 0:
		var warn := Label.new()
		warn.text = "⚠ Quân này không phủ ô đường nào — nó không gây sát thương."
		UIStyle.body(warn, 14, UIStyle.RED)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(warn)


# ── "Đang hưởng": liệt kê TỪNG nguồn buff đang tác động lên tháp này ────────
# Vì sao cần: sát thương cuối cùng là tổng của 13 lớp buff cộng lại rồi nhân hệ
# sao. Chỉ hiện con số cuối thì người chơi thấy "Sát thương 31" mà không biết
# 19 điểm chênh đến từ đâu — không đọc được thì không tối ưu được đội hình.
# Đọc THẲNG `_dmg_bonus`/`_spd_bonus`/`_rng_bonus` của tháp: đó là trạng thái
# thật, không phải bảng chép tay nên không bao giờ lệch với chỉ số hiển thị.

const BUFF_LAYER_NAMES := {
	0: "Nâng cấp", 1: "Vùng đất", 2: "Sủng ái Vua", 3: "Ân Vương Miện",
	4: "Hào quang", 5: "Đồng đội cùng loại", 6: "Perk", 7: "Ô Phước/Nguyền",
	8: "Khí hậu vùng", 9: "Trang bị", 10: "Thuốc", 11: "Ô nguyên tố",
	12: "Đồng đội cùng hệ",
}

func _build_buff_source_section(parent: VBoxContainer, tower_node: Node3D) -> void:
	var dmg: Dictionary = tower_node.get("_dmg_bonus")
	var spd: Dictionary = tower_node.get("_spd_bonus")
	var rng: Dictionary = tower_node.get("_rng_bonus")
	if not (dmg is Dictionary and spd is Dictionary and rng is Dictionary):
		return

	var layers := {}
	for d in [dmg, spd, rng]:
		for k in (d as Dictionary):
			layers[k] = true
	var lines: Array[String] = []
	for layer in layers:
		var parts := PackedStringArray()
		var dv := float((dmg as Dictionary).get(layer, 0.0))
		var sv := float((spd as Dictionary).get(layer, 0.0))
		var rv := int((rng as Dictionary).get(layer, 0))
		if not is_zero_approx(dv): parts.append("%+.0f sát thương" % dv)
		# spd là số GIÂY TRỪ vào hồi chiêu → dương = bắn nhanh hơn.
		if not is_zero_approx(sv): parts.append("%s%.2fs hồi chiêu" % ["-" if sv > 0.0 else "+", absf(sv)])
		if rv != 0: parts.append("%+d tầm" % rv)
		if parts.is_empty():
			continue
		lines.append("• %s: %s" % [str(BUFF_LAYER_NAMES.get(layer, "Lớp %s" % layer)),
			", ".join(parts)])

	var star: int = int(tower_node.star) if "star" in tower_node else 1
	if star > 1:
		var mult: float = float(tower_node.star_damage_mult)
		lines.append("• Sao ★%d: ×%.2f sát thương (phép NHÂN, áp sau cùng)" % [star, mult])

	if lines.is_empty():
		return
	parent.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
	var head := Label.new()
	head.text = "✦ Đang hưởng"
	UIStyle.body(head, 14, UIStyle.GOLD)
	parent.add_child(head)
	for line in lines:
		var l := Label.new()
		l.text = line
		UIStyle.body(l, 14, UIStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(l)


## DPS thực tế + tổng sát thương đã gây. Con số duy nhất trả lời được câu
## "quân này có đáng giữ ô không" — GameManager đã ghi sẵn từ tower._fire_projectile.
func _build_performance_section(parent: VBoxContainer, tower_node: Node3D) -> void:
	var dmg: float = float(tower_node.current_damage)
	var cd: float = maxf(0.01, float(tower_node.current_attack_speed))
	var shots: int = 1
	if tower_node.stats and int(tower_node.stats.projectile_count) > 1:
		shots = int(tower_node.stats.projectile_count)
	parent.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
	_add_info_row(parent, " DPS (ước tính)", "%.1f" % (dmg * float(shots) / cd))

	var gm := tower_node.get_node_or_null("/root/GameManagerSingleton")
	if gm != null and tower_node.stats:
		var table: Variant = gm.get("run_tower_damage")
		if table is Dictionary:
			var total: float = float((table as Dictionary).get(str(tower_node.stats.id), 0.0))
			_add_info_row(parent, "⚔ Tổng đã gây (cả loại)", "%d" % int(total))


# ── Nguyên tố + Trang bị trong panel tháp (futureplan §2, §3.2) ────────────

## Dòng "Nguyên tố:  Hoả" — cho biết ngay tháp này đang bắn Dấu gì.
## Đây là thông tin QUAN TRỌNG NHẤT của hệ ô nguyên tố: nguyên tố đến từ Ô chứ
## không từ loại tháp, nên không hiện ra thì người chơi không đọc được bàn cờ.
func _build_element_row(parent: VBoxContainer, tower_node: Node3D) -> void:
	if not tower_node.has_method("current_element"):
		return
	var element := str(tower_node.call("current_element"))
	var secondary := ""
	if tower_node.has_method("current_element_secondary"):
		secondary = str(tower_node.call("current_element_secondary"))

	parent.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
	var row := _make_stat_row(parent)
	var lbl := Label.new()
	lbl.text = "✦ Nguyên tố"
	UIStyle.body(lbl, 11, UIStyle.TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var value := Label.new()
	if ElementTypes.is_valid(element):
		value.text = ElementTypes.display_name(element)
		if ElementTypes.is_valid(secondary):
			value.text += " + " + ElementTypes.display_name(secondary)
		UIStyle.glyph(value, 13, ElementTypes.color_of(element))
	else:
		value.text = "Vật lý"
		UIStyle.body(value, 12, UIStyle.TEXT_DIM)
	row.add_child(value)

## Ô trang bị + kho. Bấm ô đã lắp = gỡ ra; bấm món trong kho = lắp vào.
func _build_equipment_section(parent: VBoxContainer, tower_node: Node3D) -> void:
	var equipment := _find_equipment_system()
	if equipment == null:
		return

	parent.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
	var title := Label.new()
	var slots: int = int(equipment.get("slots_per_tower"))
	var fitted: Array = equipment.call("equipped_on", tower_node)
	title.text = " Trang bị (%d/%d)" % [fitted.size(), slots]
	UIStyle.title(title, 12, UIStyle.GOLD)
	parent.add_child(title)

	for i in range(slots):
		var button := Button.new()
		if i < fitted.size():
			var data: Dictionary = equipment.call("item_data", str(fitted[i]))
			# Icon 32x32 neu co art; thieu file thi giu dau cham nhu cu.
			var tex := HudIcons.equipment(str(fitted[i]))
			if tex != null:
				button.icon = tex
				button.text = " %s" % str(data.get("name", fitted[i]))
			else:
				button.text = "● %s" % str(data.get("name", fitted[i]))
			button.tooltip_text = "%s\n\n(Bấm để gỡ ra kho)" % str(data.get("desc", ""))
			HudText.style_button_text(button, 11, Color(0.55, 0.9, 1.0))
			# `bind` chứ không bắt biến vòng lặp: closure GDScript giữ THAM CHIẾU
			# tới biến, mọi nút sẽ dùng giá trị `i` của vòng cuối cùng.
			button.pressed.connect(_on_equip_slot_pressed.bind(tower_node, i))
		else:
			button.text = "＋ ô trống"
			button.tooltip_text = "Chọn một món trong kho bên dưới."
			HudText.style_button_text(button, 11, UIStyle.TEXT_DIM)
			button.disabled = true
		parent.add_child(button)

	var stock: Array = equipment.call("inventory")
	if stock.is_empty():
		return
	var stock_title := Label.new()
	stock_title.text = "Kho (%d)" % stock.size()
	UIStyle.body(stock_title, 10, UIStyle.TEXT_DIM)
	parent.add_child(stock_title)

	var full: bool = fitted.size() >= slots
	for i in range(stock.size()):
		var data: Dictionary = equipment.call("item_data", str(stock[i]))
		# Hàng kho = [Lắp] + [Bán]. Trước đây chỉ có nút lắp, nên trang bị là thứ
		# DUY NHẤT không bán lại được (ô nguyên tố và di vật đều bán được) —
		# kho đầy 12 món là tắc, không có đường dọn.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		parent.add_child(row)

		var button := Button.new()
		var stock_tex := HudIcons.equipment(str(stock[i]))
		if stock_tex != null:
			button.icon = stock_tex
			button.text = " %s" % str(data.get("name", stock[i]))
		else:
			button.text = "▸ %s" % str(data.get("name", stock[i]))
		button.tooltip_text = str(data.get("desc", ""))
		button.disabled = full
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		HudText.style_button_text(button, 10, UIStyle.TEXT if not full else UIStyle.TEXT_DIM)
		button.pressed.connect(_on_equip_stock_pressed.bind(tower_node, i))
		row.add_child(button)

		var refund: int = int(round(float(data.get("cost", 0))
			* EquipmentSystem.SELL_REFUND_PCT))
		var sell := Button.new()
		sell.text = "⛁%d" % refund
		sell.tooltip_text = "Bán món này, hoàn %d vàng." % refund
		sell.custom_minimum_size = Vector2(44, 0)
		HudText.style_button_text(sell, 10, Color(1.0, 0.75, 0.4))
		sell.pressed.connect(_on_equip_sell_pressed.bind(tower_node, i))
		row.add_child(sell)

## Phần "ô nguyên tố" trong panel lãnh thổ: nguyên tố, cấp, hình thế, nút bán.
## Cấp và hình thế là hai thứ người chơi phải đọc được để bố trí bàn cờ — thiếu
## chúng thì hệ hình thế trở nên vô hình.
func _build_tile_element_section(parent: VBoxContainer, biome_key: String, pos: Vector2i) -> void:
	var tm := _find_territory_manager()
	if tm == null:
		return
	var element: String = str(tm.call("element_of_biome", biome_key))
	if not ElementTypes.is_valid(element):
		return

	parent.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
	var row := _make_stat_row(parent)
	var lbl := Label.new()
	lbl.text = "✦ Nguyên tố"
	UIStyle.body(lbl, 11, UIStyle.TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var value := Label.new()
	value.text = ElementTypes.display_name(element)
	UIStyle.glyph(value, 13, ElementTypes.color_of(element))
	row.add_child(value)

	if pos.x < -9000:
		return   # panel mở từ shop, không gắn với ô cụ thể

	var level: int = int(tm.call("get_tile_level", pos))
	_add_info_row(parent, "◈ Cấp ô", "Lv%d / 3" % level)
	var bonus: Dictionary = tm.call("get_element_bonus", pos)
	var mark_bonus := float(bonus.get("mark_duration_bonus", 0.0))
	var reaction_mult := float(bonus.get("reaction_mult", 1.0))
	var dmg_pct := float(bonus.get("tower_damage_pct", 0.0))
	# LUÔN in cả ba dòng, kể cả khi bằng 0. Trước đây chỉ in khi > ngưỡng, nên ô
	# Lv1 trông y hệt ô thường và người chơi kết luận "chồng ô chẳng được gì" —
	# trong khi Lv3 thật sự cho +15% sát thương (dòng này trước KHÔNG hề hiển thị).
	_add_info_row(parent, "⏱ Dấu kéo dài", "+%.0fs" % mark_bonus)
	_add_info_row(parent, "✷ Phản ứng", "×%.2f" % reaction_mult)
	_add_info_row(parent, "⚔ Tháp trên ô", "+%.0f%%" % (dmg_pct * 100.0))

	# Xem trước CẤP KẾ TIẾP: không có dòng này thì người chơi không có lý do nào
	# để chồng ô, vì phần thưởng chỉ hiện ra SAU khi đã tiêu tài nguyên.
	var max_lv: int = int(tm.get("MAX_TILE_LEVEL"))
	var next_box := Label.new()
	if level >= max_lv:
		next_box.text = "◈ Ô đã đạt cấp tối đa."
		UIStyle.body(next_box, 14, UIStyle.TEXT_DIM)
	else:
		var nb: Dictionary = tm.LEVEL_BONUS[level]   # LEVEL_BONUS[i] = cấp i+1
		next_box.text = "◈ Đặt thêm 1 ô %s lên đây → Lv%d: Dấu +%.0fs · Phản ứng ×%.2f · Tháp +%.0f%%" % [
			ElementTypes.display_name(element), level + 1,
			float(nb.get("mark_duration_bonus", 0.0)),
			float(nb.get("reaction_mult", 1.0)),
			float(nb.get("tower_damage_pct", 0.0)) * 100.0]
		UIStyle.body(next_box, 14, Color(0.70, 0.95, 0.65))
	next_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(next_box)

	var formations: Array = tm.call("get_formations_at", pos)
	if not formations.is_empty():
		var names: PackedStringArray = []
		for id in formations:
			names.append(FormationDetector.display_name(str(id)))
		var form_lbl := Label.new()
		form_lbl.text = "⬢ Hình thế: " + ", ".join(names)
		UIStyle.body(form_lbl, 10, Color(0.6, 0.9, 1.0))
		form_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(form_lbl)

	var sell := Button.new()
	sell.text = "Bán ô (+%d vàng)" % int(round(
		float(TerritoryManager.TILE_GOLD_VALUE * level) * TerritoryManager.SELL_REFUND_PCT))
	sell.tooltip_text = "Hoàn 60% giá trị. Dùng khi cần đổi hướng build."
	HudText.style_button_text(sell, 11, Color(1.0, 0.75, 0.4))
	sell.pressed.connect(_on_sell_tile_pressed.bind(pos))
	parent.add_child(sell)

## game_map, KHÔNG phải `get_parent()`.
##
## Component HUD được gắn bằng `X.attach(hud)` nên cha nó là HUD (CanvasLayer),
## không phải game_map. Ba hàm ở đây từng dùng `get_parent().get("...")` và luôn
## trả null ⇒ CẢ MỤC nguyên tố trong panel ô (cấp ô, Dấu kéo dài, phản ứng,
## thưởng tháp, xem trước cấp kế) VÀ nút bán ô đều chết câm. Người chơi xếp
## chồng ô lên cấp 3 mà panel không hiện gì khác — đúng lỗi vừa báo.
func _map() -> Node:
	if hud != null and hud.has_method("_find_game_map"):
		var m = hud.call("_find_game_map")
		if m != null and is_instance_valid(m):
			return m
	return get_parent()


func _find_territory_manager() -> Node:
	var map := _map()
	if map == null:
		return null
	var found: Variant = map.get("territory_manager")
	return found as Node if (found is Node and is_instance_valid(found)) else null

func _on_sell_tile_pressed(pos: Vector2i) -> void:
	var map := _map()
	var tm := _find_territory_manager()
	if tm == null:
		return
	var km: Variant = map.get("king_manager") if map else null
	tm.call("sell_tile_at", pos, km if km is KingManager else null)
	hide_tower_info()
	if map != null and map.has_method("update_ui"):
		map.call("update_ui")

func _find_equipment_system() -> Node:
	var map := _map()
	if map == null:
		return null
	var found: Variant = map.get("equipment_system")
	return found as Node if (found is Node and is_instance_valid(found)) else null

## Vẽ lại panel sau khi lắp/gỡ — đọc lại stats vì trang bị vừa đổi chỉ số.
func _refresh_tower_panel(tower_node: Node3D) -> void:
	if not is_instance_valid(tower_node):
		hide_tower_info()
		return
	var stats: Variant = tower_node.get("stats")
	if stats is TowerStats:
		show_tower_info(stats as TowerStats, _tower_info_biome, tower_node)

func _on_equip_slot_pressed(tower_node: Node3D, slot: int) -> void:
	var equipment := _find_equipment_system()
	if equipment != null:
		equipment.call("unequip", tower_node, slot)
	_refresh_tower_panel(tower_node)

func _on_equip_sell_pressed(tower_node: Node3D, index: int) -> void:
	var equipment := _find_equipment_system()
	if equipment != null:
		equipment.call("sell_from_inventory", index)
	_refresh_tower_panel(tower_node)

func _on_equip_stock_pressed(tower_node: Node3D, index: int) -> void:
	var equipment := _find_equipment_system()
	if equipment != null:
		equipment.call("equip_from_inventory", tower_node, index)
	_refresh_tower_panel(tower_node)

func _add_buffed_int_row(parent: VBoxContainer, label_text: String, base_val: int, bonus: int) -> void:
	var row := _make_stat_row(parent)
	var lbl = Label.new()
	lbl.text = label_text
	UIStyle.body(lbl, 11, UIStyle.TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val_lbl = Label.new()
	if bonus != 0:
		val_lbl.text = "%d" % (base_val + bonus)
		UIStyle.glyph(val_lbl, 13, UIStyle.TEXT)
		row.add_child(val_lbl)
		var bonus_lbl = Label.new()
		var sign_str = "+" if bonus > 0 else ""
		bonus_lbl.text = "(%s%d)" % [sign_str, bonus]
		UIStyle.body(bonus_lbl, 10, Color(0.3, 1.0, 0.4) if bonus > 0 else Color(1.0, 0.4, 0.3))
		row.add_child(bonus_lbl)
	else:
		val_lbl.text = str(base_val)
		UIStyle.body(val_lbl, 12, UIStyle.TEXT)
		row.add_child(val_lbl)

func _add_buffed_float_row(parent: VBoxContainer, label_text: String, base_val: float, bonus: float, suffix: String = "") -> void:
	var row := _make_stat_row(parent)
	var lbl = Label.new()
	lbl.text = label_text
	UIStyle.body(lbl, 11, UIStyle.TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val_lbl = Label.new()
	if abs(bonus) > 0.001:
		val_lbl.text = "%.2f%s" % [base_val + bonus, suffix]
		UIStyle.glyph(val_lbl, 13, UIStyle.TEXT)
		row.add_child(val_lbl)
		var bonus_lbl = Label.new()
		var sign_str = "+" if bonus > 0 else ""
		bonus_lbl.text = "(%s%.2f%s)" % [sign_str, bonus, suffix]
		UIStyle.body(bonus_lbl, 10, Color(0.3, 1.0, 0.4) if bonus > 0 else Color(1.0, 0.4, 0.3))
		row.add_child(bonus_lbl)
	else:
		val_lbl.text = "%.2f%s" % [base_val, suffix]
		UIStyle.body(val_lbl, 12, UIStyle.TEXT)
		row.add_child(val_lbl)

## `pos` = ô lưới đang mở (Vector2i(-9999,-9999) = không rõ). Có `pos` thì panel
## hiện thêm cấp ô, hình thế đang thành hình và nút bán.
func show_territory_info(biome_key: String, biome_data: Dictionary,
		pos: Vector2i = Vector2i(-9999, -9999)) -> void:
	if not _tower_info_panel:
		return
	_free_tower_info_icon()
	for child in _tower_info_panel.get_children():
		_tower_info_panel.remove_child(child)
		child.queue_free()
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tower_info_panel.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header: icon biome trong khung + tên
	var icon_path = "res://assets/ui/shop_icons/icon_%s.png" % biome_key
	if ResourceLoader.exists(icon_path):
		var icon_frame := PanelContainer.new()
		icon_frame.add_theme_stylebox_override("panel", UIStyle.rarity_frame("common"))
		icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UIStyle.pixel_filter(icon_frame)
		vbox.add_child(icon_frame)
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(icon_path) as Texture2D
		icon_rect.custom_minimum_size = Vector2(72, 72)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_frame.add_child(icon_rect)
		UIStyle.pop_in(icon_frame)
	var name_lbl = Label.new()
	name_lbl.text = biome_data.get("name", biome_key)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(name_lbl, 17, UIStyle.GOLD)
	vbox.add_child(name_lbl)
	var type_lbl = Label.new()
	type_lbl.text = "[Lãnh thổ]"
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(type_lbl, 10, Color(0.3, 0.85, 0.4))
	vbox.add_child(type_lbl)

	vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))

	# Buff effects
	# Buff ô nay là PHẦN TRĂM (xem TerritoryManager.BIOME_STATS) — hiển thị %,
	# không phải số cộng, nếu không panel nói một đằng chỉ số chạy một nẻo.
	var dmg_pct: float = float(biome_data.get("damage_pct", 0.0))
	var spd_pct: float = float(biome_data.get("speed_pct", 0.0))
	var dmg: int = int(biome_data.get("damage_bonus", 0))
	var spd: float = float(biome_data.get("attack_speed_reduction", 0.0))
	if dmg_pct > 0.0: _add_info_row(vbox, "⚔ Sát thương", "+%.0f%%" % (dmg_pct * 100.0))
	if spd_pct > 0.0: _add_info_row(vbox, " Hồi chiêu", "-%.0f%%" % (spd_pct * 100.0))
	var rng: int = biome_data.get("range_bonus", 0)
	if dmg != 0: _add_info_row(vbox, "⚔ Sát thương", "+%d" % dmg)
	if spd != 0.0: _add_info_row(vbox, " Cooldown", "-%.1fs" % spd)
	if rng != 0: _add_info_row(vbox, "◎ Tầm bắn", "+%d" % rng)

	_build_tile_element_section(vbox, biome_key, pos)

	vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))

	var hint = Label.new()
	hint.text = "Đặt tower lên ô này để nhận buff."
	UIStyle.body(hint, 10, UIStyle.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	_slide_tower_info(true)

## Panel cho một ô KHÔNG có tháp và KHÔNG phải ô lãnh thổ (ô trống, đường đi,
## ô Phước/Nguyền sinh lúc tạo bản đồ). Dữ liệu do `game_map._describe_cell`
## dựng sẵn nên HUD không cần biết gì về luật ô.
##
## Vì sao cần: ô Phước/Nguyền có rune riêng trên bàn nên trông y như ô bấm được,
## nhưng trước đây click vào chúng không hiện gì cả.
func show_cell_info(_pos: Vector2i, info: Dictionary) -> void:
	if not _tower_info_panel:
		return
	_free_tower_info_icon()
	for child in _tower_info_panel.get_children():
		_tower_info_panel.remove_child(child)
		child.queue_free()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tower_info_panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(info.get("title", "Ô"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(name_lbl, 28, UIStyle.GOLD)
	vbox.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = str(info.get("subtitle", ""))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(type_lbl, 14, UIStyle.TEXT_DIM)
	vbox.add_child(type_lbl)

	var rows: Array = info.get("rows", [])
	if not rows.is_empty():
		vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
		for r in rows:
			if r is Array and (r as Array).size() >= 2:
				_add_info_row(vbox, str(r[0]), str(r[1]))

	var hint_text := str(info.get("hint", ""))
	if not hint_text.is_empty():
		vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
		var hint := Label.new()
		hint.text = hint_text
		UIStyle.body(hint, 14, UIStyle.TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(hint)

	_tower_info_node = null
	_slide_tower_info(true)
	_resize_tower_panel.call_deferred()

func hide_tower_info() -> void:
	_tower_info_node = null
	if _tower_info_visible:
		_slide_tower_info(false)

func _slide_tower_info(visible_state: bool) -> void:
	if not _tower_info_panel:
		return
	if _tower_info_tween:
		_tower_info_tween.kill()
	_tower_info_tween = create_tween()
	_tower_info_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if visible_state:
		_tower_info_visible = true
		if is_instance_valid(_tower_info_icon):
			_tower_info_icon.set_active(true)
		_tower_info_tween.set_parallel(true)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_left", 0.0, 0.2)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_right", float(TOWER_INFO_WIDTH), 0.2)
	else:
		_tower_info_visible = false
		_tower_info_tween.set_parallel(true)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_left", float(-TOWER_INFO_WIDTH), 0.2)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_right", 0.0, 0.2)
		_tower_info_tween.set_parallel(false)
		# Panel đã trượt ra ngoài → ngừng render SubViewport để tiết kiệm GPU
		_tower_info_tween.tween_callback(func():
			if is_instance_valid(_tower_info_icon):
				_tower_info_icon.set_active(false))

## Hàng stat có nền lõm mảnh → bảng thông số trông như khắc vào panel.
func _make_stat_row(parent: VBoxContainer) -> HBoxContainer:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override(
		"panel", UIStyle.flat_inset(Color(0.0, 0.0, 0.0, 0.28), Color(0.0, 0.0, 0.0, 0.45), 2))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	return row

func _add_info_row(vbox: VBoxContainer, key: String, val: String) -> void:
	var row := _make_stat_row(vbox)
	var k = Label.new()
	k.text = key
	UIStyle.body(k, 11, UIStyle.TEXT_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v = Label.new()
	v.text = val
	UIStyle.body(v, 12, UIStyle.TEXT)
	row.add_child(v)

## Hàng sao. Sao CHỈ lên bằng cách ghép quân trùng — đặt một quân cùng loại lên
## ô đã có quân đó. Từng có nút "nâng sao bằng vàng" ở đây, đã gỡ.
func _build_star_row(parent: VBoxContainer, tower_node: Node3D) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var cur: int = int(tower_node.star) if "star" in tower_node else 1
	var stars := Label.new()
	stars.text = "★".repeat(cur) + "·".repeat(maxi(0, 3 - cur))
	UIStyle.title(stars, 28, UIStyle.GOLD)
	row.add_child(stars)

	var hint := Label.new()
	if cur >= 3:
		hint.text = "Sao tối đa"
		UIStyle.body(hint, 14, UIStyle.TEXT_DIM)
	else:
		hint.text = "Đặt thêm 1 %s lên ô này để lên ★%d" % [
			UIStyle.unit_name_vi(str(tower_node.stats.id)) if tower_node.stats else "quân cùng loại",
			cur + 1]
		UIStyle.body(hint, 14, UIStyle.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
