# res://scripts/ui/king_select.gd
extends Control

const KING_PATHS: Array[String] = [
	"res://res/kings/king_iron.tres",
	"res://res/kings/king_phantom.tres",
	"res://res/kings/king_flame.tres",
]

var _selected_king: KingStats = null
var _meta: MetaProgress = null
var _start_btn: Button = null
var _detail_name: Label
var _detail_lore: Label
var _detail_ability: Label
var _detail_favor: Label
var _detail_stats: Label
var _detail_locked: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_meta = MetaProgress.load_or_create()
	_build_ui()

func _go_to(path: String) -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm:
		sm.go_to_scene(path)
	else:
		get_tree().change_scene_to_file(path)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.12, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var back_btn = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(120, 44)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.position = Vector2(20, 20)
	back_btn.pressed.connect(_go_to.bind("res://scenes/ui/main_menu.tscn"))
	add_child(back_btn)

	var title = Label.new()
	title.text = "Choose Your King"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 90
	add_child(title)

	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_top = 100
	main_hbox.offset_left = 20
	main_hbox.offset_right = -20
	main_hbox.offset_bottom = -80
	main_hbox.add_theme_constant_override("separation", 20)
	add_child(main_hbox)

	var left_scroll = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.4
	main_hbox.add_child(left_scroll)

	var king_vbox = VBoxContainer.new()
	king_vbox.add_theme_constant_override("separation", 12)
	left_scroll.add_child(king_vbox)

	var kings_loaded: Array[KingStats] = []
	for path in KING_PATHS:
		if ResourceLoader.exists(path):
			var k = load(path) as KingStats
			if k:
				kings_loaded.append(k)

	if kings_loaded.is_empty():
		var placeholder_king = KingStats.new()
		placeholder_king.id = "king_iron"
		placeholder_king.king_name = "Iron King"
		placeholder_king.lore = "A steadfast ruler of steel and discipline."
		placeholder_king.base_health = 20
		placeholder_king.base_royal_decree = 15.0
		placeholder_king.decree_regen_rate = 1.5
		placeholder_king.decree_max = 100.0
		placeholder_king.ability_name = "Iron Decree"
		placeholder_king.ability_description = "Restore 30 Decree and boost Pawns."
		placeholder_king.is_starter_king = true
		placeholder_king.unlock_cost = 0
		kings_loaded.append(placeholder_king)

	for king in kings_loaded:
		var is_unlocked = king.is_starter_king or king.id in _meta.unlocked_king_ids
		king_vbox.add_child(_create_king_card_button(king, is_unlocked))

	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.6
	main_hbox.add_child(right_panel)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 14)
	right_panel.add_child(detail_vbox)

	_detail_name = Label.new()
	_detail_name.text = "Select a King"
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.add_theme_font_size_override("font_size", 32)
	_detail_name.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	detail_vbox.add_child(_detail_name)

	detail_vbox.add_child(HSeparator.new())

	_detail_lore = Label.new()
	_detail_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_lore.add_theme_font_size_override("font_size", 16)
	_detail_lore.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	detail_vbox.add_child(_detail_lore)

	_detail_stats = Label.new()
	_detail_stats.add_theme_font_size_override("font_size", 16)
	_detail_stats.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1))
	detail_vbox.add_child(_detail_stats)

	_detail_favor = Label.new()
	_detail_favor.add_theme_font_size_override("font_size", 16)
	_detail_favor.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0, 1))
	detail_vbox.add_child(_detail_favor)

	detail_vbox.add_child(HSeparator.new())

	_detail_ability = Label.new()
	_detail_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_ability.add_theme_font_size_override("font_size", 15)
	_detail_ability.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1))
	detail_vbox.add_child(_detail_ability)

	_detail_locked = Label.new()
	_detail_locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_locked.add_theme_font_size_override("font_size", 18)
	_detail_locked.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	detail_vbox.add_child(_detail_locked)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(spacer)

	_start_btn = Button.new()
	_start_btn.text = "Start Run"
	_start_btn.custom_minimum_size = Vector2(250, 60)
	_start_btn.add_theme_font_size_override("font_size", 22)
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start_pressed)
	detail_vbox.add_child(_start_btn)

	for king in kings_loaded:
		var is_unlocked = king.is_starter_king or king.id in _meta.unlocked_king_ids
		if is_unlocked:
			_select_king(king)
			break

func _create_king_card_button(king: KingStats, is_unlocked: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	if is_unlocked:
		btn.text = "[K] %s" % king.king_name
	else:
		btn.text = "[LOCKED] %s  (%d pts)" % [king.king_name, king.unlock_cost]
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6, 1)
	btn.pressed.connect(_select_king.bind(king))
	return btn

func _select_king(king: KingStats) -> void:
	_selected_king = king
	var is_unlocked = king.is_starter_king or king.id in _meta.unlocked_king_ids
	_detail_name.text = king.king_name
	_detail_lore.text = king.lore
	_detail_stats.text = "HP: %d  |  Decree: %.0f/%.0f  |  Regen: %.1f/s  |  Territories: %d" % [
		king.base_health, king.base_royal_decree, king.decree_max,
		king.decree_regen_rate, king.starting_territory_count
	]
	_detail_favor.text = "Favored: %s  |  Dmg +%.0f%%  Spd +%.0f%%  Rng +%.0f%%" % [
		", ".join(king.favored_unit_types) if king.favored_unit_types.size() > 0 else "None",
		king.favor_damage_bonus * 100, king.favor_speed_bonus * 100, king.favor_range_bonus * 100
	]
	_detail_ability.text = "[%s]\n%s\n(Cooldown: %.0fs | Cost: %.0f Decree)" % [
		king.ability_name, king.ability_description,
		king.ability_cooldown, king.ability_decree_cost
	]
	if is_unlocked:
		_detail_locked.text = ""
		_start_btn.disabled = false
	else:
		_detail_locked.text = "LOCKED - Costs %d Meta Points to unlock" % king.unlock_cost
		_start_btn.disabled = true

func _on_start_pressed() -> void:
	if not _selected_king:
		return
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		gm.start_run(_selected_king)
	_go_to("res://scenes/map/game_map.tscn")
