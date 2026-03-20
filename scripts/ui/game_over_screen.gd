# res://scripts/ui/game_over_screen.gd
extends Control

var _wave_label: Label
var _enemies_label: Label
var _gold_label: Label
var _meta_pts_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		if gm.has_signal("run_ended"):
			gm.run_ended.connect(_on_run_ended)
		# Luôn hiện stats ngay khi load — run_ended có thể đã emit trước khi scene load
		_show_from_gm(gm)

func _go_to(path: String) -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm:
		sm.go_to_scene(path)
	else:
		get_tree().change_scene_to_file(path)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(500, 500)
	vbox.offset_left = -250
	vbox.offset_top = -250
	vbox.offset_right = 250
	vbox.offset_bottom = 250
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var banner_tex = load("res://assets/ui/defeat_banner.png") as Texture2D
	if banner_tex:
		var banner = TextureRect.new()
		banner.texture = banner_tex
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.custom_minimum_size = Vector2(320, 64)
		vbox.add_child(banner)

	var title = Label.new()
	title.text = "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 1))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Your kingdom has fallen..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(stats_vbox)

	_wave_label = _make_stat_label("Wave Reached: 0")
	stats_vbox.add_child(_wave_label)
	_enemies_label = _make_stat_label("Enemies Defeated: 0")
	stats_vbox.add_child(_enemies_label)
	_gold_label = _make_stat_label("Gold Earned: 0")
	stats_vbox.add_child(_gold_label)
	_meta_pts_label = _make_stat_label("Meta Points Earned: 0")
	_meta_pts_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	stats_vbox.add_child(_meta_pts_label)

	vbox.add_child(HSeparator.new())

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)

	var menu_btn = Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(200, 55)
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(_go_to.bind("res://scenes/ui/main_menu.tscn"))
	btn_hbox.add_child(menu_btn)

	var play_again_btn = Button.new()
	play_again_btn.text = "Play Again"
	play_again_btn.custom_minimum_size = Vector2(200, 55)
	play_again_btn.add_theme_font_size_override("font_size", 18)
	play_again_btn.pressed.connect(_go_to.bind("res://scenes/ui/king_select.tscn"))
	btn_hbox.add_child(play_again_btn)

func _make_stat_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	return lbl

func show_stats(wave: int, enemies: int, gold: int, meta_pts: int) -> void:
	_wave_label.text = "Wave Reached: %d" % wave
	_enemies_label.text = "Enemies Defeated: %d" % enemies
	_gold_label.text = "Gold Earned: %d" % gold
	_meta_pts_label.text = "Meta Points Earned: %d" % meta_pts

func _show_from_gm(gm: Node) -> void:
	show_stats(
		gm.current_wave,
		gm.run_enemies_killed,
		gm.run_gold_earned,
		gm.run_meta_points_earned
	)

func _on_run_ended(is_victory: bool) -> void:
	if not is_victory:
		var gm = get_node_or_null("/root/GameManagerSingleton")
		if gm:
			_show_from_gm(gm)
