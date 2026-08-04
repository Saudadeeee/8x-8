# res://scripts/ui/meta_progression.gd
# Meta Progression screen - built programmatically.
extends Control

var _meta: MetaProgress = null
var _meta_points_label: Label = null
var _upgrade_buttons: Array[Button] = []

# ── Nâng cấp meta ────────────────────────────────────────────────────────────
# Chia theo TRỤC BUILD chứ không phải một danh sách chỉ số chung. Bản cũ chỉ có
# ba mục (vàng / máu / Sắc Lệnh) nên mọi ván meta đều đi cùng một đường; các hệ
# nguyên tố, hình thế và ghép sao — vốn là phần sâu nhất của game — không có
# nhánh tiến trình nào chạm tới.
#
# `group` chỉ để xếp nhóm khi hiển thị. `id` phải khớp nhánh match trong
# GameManager.start_run() — thêm id mới mà quên nhánh đó thì nâng cấp mua được
# nhưng không làm gì (đúng lớp lỗi "tính năng chết âm thầm" hay gặp ở dự án này).
const META_UPGRADES = [
	# Kinh tế
	{"id": "starting_gold",   "group": "Economy",    "name": "Deep Purse (+30 starting gold)", "cost": 45, "max_level": 5},
	{"id": "interest_cap",    "group": "Economy",    "name": "Deep Vault (+2 interest cap)",     "cost": 55, "max_level": 4},
	{"id": "gold_per_kill",   "group": "Economy",    "name": "Blood Tax (+1 gold per kill)",    "cost": 70, "max_level": 3},
	# Sinh tồn
	{"id": "health_bonus",    "group": "Survival",   "name": "Bastion (+4 King HP)",         "cost": 35, "max_level": 5},
	{"id": "start_territory", "group": "Survival",   "name": "Fiefdom (+1 starting vein)", "cost": 60, "max_level": 3},
	# Sắc Lệnh
	{"id": "decree_bonus",    "group": "Decree",   "name": "Great Seal (+10 Decree cap)", "cost": 40, "max_level": 5},
	{"id": "decree_start",    "group": "Decree",   "name": "Standing Edict (+8 starting Decree)", "cost": 45, "max_level": 4},
	{"id": "decree_per_wave", "group": "Decree",   "name": "Urgent Decree (+1 Decree per wave)", "cost": 65, "max_level": 3},
	# Nguyên tố
	{"id": "reaction_power",  "group": "Element",  "name": "Resonance (+6% reaction damage)", "cost": 75, "max_level": 4},
	{"id": "mark_slots",      "group": "Element",  "name": "Deep Etching (+1 Mark capacity)",     "cost": 110, "max_level": 1},
	{"id": "tile_discount",   "group": "Element",  "name": "Landlord (veins 8% cheaper)",    "cost": 60, "max_level": 3},
	# Đội hình
	{"id": "tower_damage",    "group": "Formation",   "name": "Weaponsmith (+4% damage, all pieces)", "cost": 80, "max_level": 4},
	{"id": "tower_speed",     "group": "Formation",   "name": "Drilling (+3% attack speed, all pieces)",   "cost": 80, "max_level": 4},
	{"id": "equip_discount",  "group": "Formation",   "name": "Familiar Smith (equipment 10% cheaper)", "cost": 55, "max_level": 3},
]

## Thư mục vua — quét thay vì liệt kê cứng (giống màn chọn vua).
const KING_DIR := "res://res/kings/"

## Bộ Khai Cuộc — phần meta "mở LỐI CHƠI mới", khác hẳn nâng cấp cộng chỉ số.
## Nó không làm người chơi mạnh hơn, nó cho một cách chơi khác. Mỗi bộ gắn với
## một loại cờ và mang theo luật riêng của loại đó.
func _build_deck_section(parent: VBoxContainer) -> void:
	var head := Label.new()
	head.text = "◆  STARTING SETS"
	UIStyle.title(head, 28, UIStyle.GOLD)
	parent.add_child(head)

	var hint := Label.new()
	hint.text = "Each set draws on a different chess tradition and brings that tradition's rule."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(hint, 14, UIStyle.TEXT_DIM)
	parent.add_child(hint)

	for data in ArmyDeck.all_decks():
		var owned: bool = int(data.unlock_cost) <= 0 			or _meta.unlocked_deck_ids.has(str(data.id))
		var picked: bool = str(_meta.selected_deck_id) == str(data.id)
		var pieces := PackedStringArray()
		for k in data.deck:
			pieces.append("%s×%d" % [UIStyle.unit_name_vi(str(k)), int(data.deck[k])])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		if owned:
			btn.text = "%s %s  [%s]
%s" % [
				"▶" if picked else "  ", data.display_name, data.origin, ", ".join(pieces)]
		else:
			btn.text = "  %s  [%s]  —  %d pts
%s" % [
				data.display_name, data.origin, int(data.unlock_cost), ", ".join(pieces)]
			btn.disabled = _meta.meta_points < int(data.unlock_cost)
		UIStyle.apply_button(btn, 14,
			UIStyle.GOLD if picked else (UIStyle.TEXT if owned else UIStyle.TEXT_DIM))
		btn.pressed.connect(_on_deck_pressed.bind(str(data.id), int(data.unlock_cost), owned))
		parent.add_child(btn)

	parent.add_child(UIStyle.separator(UIStyle.BORDER_HI))


func _on_deck_pressed(deck_id: String, cost: int, owned: bool) -> void:
	if owned:
		_meta.selected_deck_id = deck_id
	else:
		if _meta.meta_points < cost:
			return
		_meta.meta_points -= cost
		if not _meta.unlocked_deck_ids.has(deck_id):
			_meta.unlocked_deck_ids.append(deck_id)
		_meta.selected_deck_id = deck_id
	_meta.save()
	_go_to("res://scenes/ui/meta_progression.tscn")



func _go_to(path: String) -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm:
		sm.go_to_scene(path)
	else:
		get_tree().change_scene_to_file(path)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_meta = MetaProgress.load_or_create()
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.055, 0.038, 0.075, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "←  Back"
	back_btn.custom_minimum_size = Vector2(130, 46)
	back_btn.position = Vector2(20, 20)
	UIStyle.apply_button(back_btn, 17)
	back_btn.pressed.connect(func(): _go_to("res://scenes/ui/main_menu.tscn"))
	add_child(back_btn)
	UIStyle.slide_in(back_btn, Vector2(-160, 0), 0.3)

	# Title
	var title = Label.new()
	title.text = "★  PROGRESS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title, 48, UIStyle.GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 90
	add_child(title)
	UIStyle.pop_in(title)

	# Stats panel at top
	var stats_panel = PanelContainer.new()
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stats_panel.offset_top = 100
	stats_panel.offset_bottom = 176
	stats_panel.offset_left = 40
	stats_panel.offset_right = -40
	UIStyle.apply_panel(stats_panel, "stone")
	add_child(stats_panel)
	UIStyle.slide_in(stats_panel, Vector2(0, -110), 0.34)

	var stats_hbox = HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 50)
	stats_panel.add_child(stats_hbox)

	var stat_entries = [
		"Total Runs: %d" % _meta.total_runs,
		"Total Wins: %d" % _meta.total_wins,
		"Best Wave: %d" % _meta.best_wave_reached,
		"Meta points: %d ★" % _meta.meta_points,
	]
	for s in stat_entries:
		var lbl = Label.new()
		lbl.text = s
		UIStyle.body(lbl, 18, Color(0.9, 0.9, 0.9, 1))
		if "Meta Points" in s:
			UIStyle.glyph(lbl, 20, Color(1.0, 0.84, 0.0, 1.0))
			lbl.set_meta("pts", _meta.meta_points)   # mốc cho count_to lần sau
			_meta_points_label = lbl
		stats_hbox.add_child(lbl)

	# Main HBox - left and right columns
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_top = 180
	main_hbox.offset_left = 40
	main_hbox.offset_right = -40
	main_hbox.offset_bottom = -20
	main_hbox.add_theme_constant_override("separation", 20)
	add_child(main_hbox)

	# LEFT: Unlocked Kings
	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_scroll)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 12)
	left_scroll.add_child(left_vbox)

	var kings_title = Label.new()
	kings_title.text = "♛  KINGS UNLOCKED"
	UIStyle.title(kings_title, 24, UIStyle.GOLD)
	left_vbox.add_child(kings_title)

	left_vbox.add_child(UIStyle.separator(UIStyle.BORDER_DIM))

	_build_deck_section(left_vbox)

	var king_index := 0
	# Quét thư mục: thêm vua = thả một .tres, không phải sửa mảng ở đây.
	var king_paths: Array[String] = []
	var kd := DirAccess.open(KING_DIR)
	if kd != null:
		var names: Array[String] = []
		for f in kd.get_files():
			var cn := f.trim_suffix(".remap")
			if cn.ends_with(".tres"):
				names.append(cn)
		names.sort()
		for n in names:
			king_paths.append(KING_DIR + n)
	for king_path in king_paths:
		if not ResourceLoader.exists(king_path):
			continue
		var king = load(king_path) as KingStats
		if not king:
			continue
		var is_unlocked = king.is_starter_king or king.id in _meta.unlocked_king_ids
		var card = _create_king_card(king, is_unlocked)
		left_vbox.add_child(card)
		UIStyle.pop_in(card, 0.10 + king_index * 0.05)
		king_index += 1

	# RIGHT: Meta Upgrades
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_scroll)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_scroll.add_child(right_vbox)

	var upgrades_title = Label.new()
	upgrades_title.text = "⚒  PERMANENT UPGRADES"
	UIStyle.title(upgrades_title, 24, UIStyle.GOLD)
	right_vbox.add_child(upgrades_title)

	right_vbox.add_child(UIStyle.separator(UIStyle.BORDER_DIM))

	var up_index := 0
	for upgrade_def in META_UPGRADES:
		var row = _create_upgrade_row(upgrade_def, right_vbox)
		right_vbox.add_child(row)
		UIStyle.pop_in(row, 0.14 + up_index * 0.05)
		up_index += 1

## Card King: khung vàng (legendary) khi đã mở, khung xám (common) khi chưa.
func _create_king_card(king: KingStats, is_unlocked: bool) -> Control:
	var rarity := "legendary" if is_unlocked else "common"
	var boxes := UIStyle.framed_card(rarity, "wood", 4, 6)
	var panel: PanelContainer = boxes[0]
	var inner: PanelContainer = boxes[1]
	panel.custom_minimum_size = Vector2(0, 60)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	inner.add_child(hbox)

	var id_label = Label.new()
	id_label.text = "[%s]" % king.id
	UIStyle.body(id_label, 14, Color(0.6, 0.6, 0.6, 1))
	id_label.custom_minimum_size = Vector2(120, 0)
	id_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(id_label)

	var name_label = Label.new()
	name_label.text = king.king_name
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_unlocked:
		UIStyle.title(name_label, 18, Color(1.0, 0.84, 0.0, 1.0))
	else:
		name_label.text += " "
		UIStyle.body(name_label, 18, Color(0.5, 0.5, 0.5, 1))
	hbox.add_child(name_label)

	if not is_unlocked:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)

		var cost_label = Label.new()
		cost_label.text = "%d ★" % king.unlock_cost
		UIStyle.glyph(cost_label, 15, Color(0.95, 0.75, 0.25, 1))
		cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(cost_label)

		var unlock_btn = Button.new()
		unlock_btn.text = "Unlock"
		unlock_btn.custom_minimum_size = Vector2(100, 38)
		unlock_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UIStyle.apply_button_accent(unlock_btn, UIStyle.GREEN, 14)
		unlock_btn.disabled = _meta.meta_points < king.unlock_cost
		unlock_btn.pressed.connect(func(): _on_unlock_king_pressed(king, unlock_btn, name_label))
		hbox.add_child(unlock_btn)

	return panel

func _on_unlock_king_pressed(king: KingStats, btn: Button, name_lbl: Label) -> void:
	if _meta.meta_points < king.unlock_cost:
		return
	_meta.meta_points -= king.unlock_cost
	_meta.unlocked_king_ids.append(king.id)
	_meta.save()
	btn.queue_free()
	name_lbl.text = king.king_name
	UIStyle.title(name_lbl, 18, Color(1.0, 0.84, 0.0, 1.0))
	# Card đổi sang khung vàng ngay khi mở khoá
	var card := name_lbl.get_parent()
	while card != null and not (card is PanelContainer and card.get_parent() is VBoxContainer):
		card = card.get_parent()
	if card is PanelContainer:
		(card as PanelContainer).add_theme_stylebox_override("panel", UIStyle.rarity_frame("legendary"))
		UIStyle.flash_node(card as Control, 2)
	_refresh_currency_display()

func _create_upgrade_row(upgrade_def: Dictionary, _parent_vbox: VBoxContainer) -> Control:
	var boxes := UIStyle.framed_card("rare", "wood", 4, 6)
	var panel: PanelContainer = boxes[0]
	var inner: PanelContainer = boxes[1]
	panel.custom_minimum_size = Vector2(0, 60)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	inner.add_child(hbox)

	var current_level = _get_upgrade_level(upgrade_def["id"])
	var max_level = upgrade_def["max_level"]

	var name_lbl = Label.new()
	name_lbl.text = upgrade_def["name"]
	name_lbl.custom_minimum_size = Vector2(220, 0)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIStyle.body(name_lbl, 17, Color(0.9, 0.9, 0.9, 1))
	hbox.add_child(name_lbl)

	var level_lbl = Label.new()
	level_lbl.text = "Lv %d/%d" % [current_level, max_level]
	level_lbl.custom_minimum_size = Vector2(84, 0)
	level_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIStyle.glyph(level_lbl, 16, Color(0.7, 0.95, 0.7, 1))
	hbox.add_child(level_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "%d ★" % upgrade_def["cost"]
	cost_lbl.custom_minimum_size = Vector2(74, 0)
	cost_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIStyle.glyph(cost_lbl, 16, Color(1.0, 0.84, 0.0, 1.0))
	hbox.add_child(cost_lbl)

	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(108, 38)
	upgrade_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIStyle.apply_button_accent(upgrade_btn, UIStyle.BLUE, 15)
	upgrade_btn.disabled = (current_level >= max_level) or (_meta.meta_points < upgrade_def["cost"])
	upgrade_btn.set_meta("upgrade_id", upgrade_def["id"])
	upgrade_btn.set_meta("cost", upgrade_def["cost"])
	upgrade_btn.set_meta("max_level", upgrade_def["max_level"])
	upgrade_btn.pressed.connect(func(): _on_upgrade_pressed(upgrade_def, level_lbl, cost_lbl, upgrade_btn))
	hbox.add_child(upgrade_btn)
	_upgrade_buttons.append(upgrade_btn)

	return panel

func _get_upgrade_level(upgrade_id: String) -> int:
	for entry in _meta.meta_upgrades:
		if entry.get("id", "") == upgrade_id:
			return entry.get("level", 0)
	return 0

func _set_upgrade_level(upgrade_id: String, new_level: int) -> void:
	for i in range(_meta.meta_upgrades.size()):
		if _meta.meta_upgrades[i].get("id", "") == upgrade_id:
			_meta.meta_upgrades[i]["level"] = new_level
			return
	_meta.meta_upgrades.append({"id": upgrade_id, "level": new_level})

func _on_upgrade_pressed(upgrade_def: Dictionary, level_lbl: Label, _cost_lbl: Label, upgrade_btn: Button) -> void:
	var uid = upgrade_def["id"]
	var cost = upgrade_def["cost"]
	var max_level = upgrade_def["max_level"]
	var current_level = _get_upgrade_level(uid)

	if current_level >= max_level:
		return
	if _meta.meta_points < cost:
		return

	_meta.meta_points -= cost
	var new_level = current_level + 1
	_set_upgrade_level(uid, new_level)
	_meta.save()

	level_lbl.text = "Lv %d/%d" % [new_level, max_level]
	UIStyle.pulse(level_lbl, 1.28)
	UIStyle.flash_node(upgrade_btn)
	upgrade_btn.disabled = (new_level >= max_level) or (_meta.meta_points < cost)
	_refresh_currency_display()

func _refresh_currency_display() -> void:
	if is_instance_valid(_meta_points_label):
		var old_pts := 0
		if _meta_points_label.has_meta("pts"):
			old_pts = int(_meta_points_label.get_meta("pts"))
		_meta_points_label.set_meta("pts", _meta.meta_points)
		if old_pts > 0:
			UIStyle.count_to(_meta_points_label, old_pts, _meta.meta_points, "Meta points: %d ★")
		else:
			_meta_points_label.text = "Meta points: %d ★" % _meta.meta_points
	for btn in _upgrade_buttons:
		if not is_instance_valid(btn):
			continue
		var btn_id: String = btn.get_meta("upgrade_id", "")
		var btn_cost: int = btn.get_meta("cost", 0)
		var btn_max: int = btn.get_meta("max_level", 0)
		var btn_level: int = _get_upgrade_level(btn_id)
		btn.disabled = (btn_level >= btn_max) or (_meta.meta_points < btn_cost)
