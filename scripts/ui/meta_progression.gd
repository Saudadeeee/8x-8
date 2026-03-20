# res://scripts/ui/meta_progression.gd
# Meta Progression screen - built programmatically.
extends Control

var _meta: MetaProgress = null
var _meta_points_label: Label = null
var _upgrade_buttons: Array[Button] = []

# Meta upgrade definitions
const META_UPGRADES = [
	{"id": "starting_gold", "name": "Starting Gold (+50)", "cost": 50, "max_level": 5},
	{"id": "health_bonus", "name": "Health Bonus (+5)", "cost": 30, "max_level": 5},
	{"id": "decree_bonus", "name": "Decree Bonus (+10)", "cost": 40, "max_level": 5},
]

# All known kings for display
const KING_PATHS = [
	"res://res/kings/king_iron.tres",
	"res://res/kings/king_phantom.tres",
	"res://res/kings/king_flame.tres",
]

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
	bg.color = Color(0.08, 0.05, 0.12, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, 44)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.position = Vector2(20, 20)
	back_btn.pressed.connect(func(): _go_to("res://scenes/ui/main_menu.tscn"))
	add_child(back_btn)

	# Title
	var title = Label.new()
	title.text = "Meta Progression"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 90
	add_child(title)

	# Stats panel at top
	var stats_panel = PanelContainer.new()
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stats_panel.offset_top = 100
	stats_panel.offset_bottom = 170
	stats_panel.offset_left = 40
	stats_panel.offset_right = -40
	add_child(stats_panel)

	var stats_hbox = HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 50)
	stats_panel.add_child(stats_hbox)

	var stat_entries = [
		"Total Runs: %d" % _meta.total_runs,
		"Total Wins: %d" % _meta.total_wins,
		"Best Wave: %d" % _meta.best_wave_reached,
		"Meta Points: %d *" % _meta.meta_points,
	]
	for s in stat_entries:
		var lbl = Label.new()
		lbl.text = s
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		if "Meta Points" in s:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
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
	kings_title.text = "Unlocked Kings"
	kings_title.add_theme_font_size_override("font_size", 24)
	kings_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	left_vbox.add_child(kings_title)

	left_vbox.add_child(HSeparator.new())

	for king_path in KING_PATHS:
		if not ResourceLoader.exists(king_path):
			continue
		var king = load(king_path) as KingStats
		if not king:
			continue
		var is_unlocked = king.is_starter_king or king.id in _meta.unlocked_king_ids
		var card = _create_king_card(king, is_unlocked)
		left_vbox.add_child(card)

	# RIGHT: Meta Upgrades
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_scroll)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_scroll.add_child(right_vbox)

	var upgrades_title = Label.new()
	upgrades_title.text = "Meta Upgrades"
	upgrades_title.add_theme_font_size_override("font_size", 24)
	upgrades_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	right_vbox.add_child(upgrades_title)

	right_vbox.add_child(HSeparator.new())

	for upgrade_def in META_UPGRADES:
		var row = _create_upgrade_row(upgrade_def, right_vbox)
		right_vbox.add_child(row)

func _create_king_card(king: KingStats, is_unlocked: bool) -> Control:
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var id_label = Label.new()
	id_label.text = "[%s]" % king.id
	id_label.add_theme_font_size_override("font_size", 14)
	id_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	id_label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(id_label)

	var name_label = Label.new()
	name_label.text = king.king_name
	name_label.add_theme_font_size_override("font_size", 18)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	else:
		name_label.text += " (Locked)"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	hbox.add_child(name_label)

	if not is_unlocked:
		var cost_label = Label.new()
		cost_label.text = "Cost: %d pts" % king.unlock_cost
		cost_label.add_theme_font_size_override("font_size", 14)
		cost_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2, 1))
		hbox.add_child(cost_label)

		var unlock_btn = Button.new()
		unlock_btn.text = "Unlock"
		unlock_btn.custom_minimum_size = Vector2(90, 36)
		unlock_btn.add_theme_font_size_override("font_size", 14)
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
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	_refresh_currency_display()

func _create_upgrade_row(upgrade_def: Dictionary, _parent_vbox: VBoxContainer) -> Control:
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var current_level = _get_upgrade_level(upgrade_def["id"])
	var max_level = upgrade_def["max_level"]

	var name_lbl = Label.new()
	name_lbl.text = upgrade_def["name"]
	name_lbl.custom_minimum_size = Vector2(220, 0)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	hbox.add_child(name_lbl)

	var level_lbl = Label.new()
	level_lbl.text = "Lv %d/%d" % [current_level, max_level]
	level_lbl.custom_minimum_size = Vector2(80, 0)
	level_lbl.add_theme_font_size_override("font_size", 16)
	level_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	hbox.add_child(level_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "%d pts" % upgrade_def["cost"]
	cost_lbl.custom_minimum_size = Vector2(70, 0)
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	hbox.add_child(cost_lbl)

	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(100, 36)
	upgrade_btn.add_theme_font_size_override("font_size", 16)
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
	upgrade_btn.disabled = (new_level >= max_level) or (_meta.meta_points < cost)
	_refresh_currency_display()

func _refresh_currency_display() -> void:
	if is_instance_valid(_meta_points_label):
		_meta_points_label.text = "Meta Points: %d *" % _meta.meta_points
	for btn in _upgrade_buttons:
		if not is_instance_valid(btn):
			continue
		var btn_id: String = btn.get_meta("upgrade_id", "")
		var btn_cost: int = btn.get_meta("cost", 0)
		var btn_max: int = btn.get_meta("max_level", 0)
		var btn_level: int = _get_upgrade_level(btn_id)
		btn.disabled = (btn_level >= btn_max) or (_meta.meta_points < btn_cost)
