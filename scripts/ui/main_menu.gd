# res://scripts/ui/main_menu.gd
extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _go_to(path: String) -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm:
		sm.go_to_scene(path)
	else:
		get_tree().change_scene_to_file(path)

func _apply_ancient_button_style(btn: Button) -> void:
	var tex_n = load("res://assets/ui/button_normal.png") as Texture2D
	var tex_h = load("res://assets/ui/button_hover.png") as Texture2D
	var tex_p = load("res://assets/ui/button_pressed.png") as Texture2D
	if tex_n:
		var s = StyleBoxTexture.new()
		s.texture = tex_n
		s.texture_margin_left = 8; s.texture_margin_right = 8
		s.texture_margin_top = 6; s.texture_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", s)
	if tex_h:
		var s = StyleBoxTexture.new()
		s.texture = tex_h
		s.texture_margin_left = 8; s.texture_margin_right = 8
		s.texture_margin_top = 6; s.texture_margin_bottom = 6
		btn.add_theme_stylebox_override("hover", s)
	if tex_p:
		var s = StyleBoxTexture.new()
		s.texture = tex_p
		s.texture_margin_left = 8; s.texture_margin_right = 8
		s.texture_margin_top = 6; s.texture_margin_bottom = 6
		btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.6))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.6, 0.0))

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.02, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root_vbox.custom_minimum_size = Vector2(400, 600)
	root_vbox.offset_left = -200
	root_vbox.offset_top = -300
	root_vbox.offset_right = 200
	root_vbox.offset_bottom = 300
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_theme_constant_override("separation", 12)
	add_child(root_vbox)

	var title_tex = load("res://assets/ui/title_banner.png") as Texture2D
	if title_tex:
		var title_img = TextureRect.new()
		title_img.texture = title_tex
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.custom_minimum_size = Vector2(320, 80)
		root_vbox.add_child(title_img)
	else:
		var title = Label.new()
		title.text = "8x8"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 72)
		title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
		root_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Chess Tower Defense Roguelike"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.72, 0.5, 1))
	root_vbox.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	root_vbox.add_child(spacer)

	# Kiểm tra nếu đang có run đang chạy → hiện nút Continue
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.get("selected_king") != null:
		var continue_btn = Button.new()
		continue_btn.text = "▶  Continue"
		continue_btn.custom_minimum_size = Vector2(280, 60)
		continue_btn.add_theme_font_size_override("font_size", 20)
		_apply_ancient_button_style(continue_btn)
		continue_btn.pressed.connect(_go_to.bind("res://test.tscn"))
		root_vbox.add_child(continue_btn)

	var buttons = [
		["New Game", "res://scenes/ui/king_select.tscn"],
		["Meta Progression", "res://scenes/ui/meta_progression.tscn"],
		["Settings", "res://scenes/ui/settings_screen.tscn"],
		["Quit", "quit"],
	]

	for entry in buttons:
		var btn = Button.new()
		btn.text = entry[0]
		btn.custom_minimum_size = Vector2(280, 60)
		btn.add_theme_font_size_override("font_size", 20)
		_apply_ancient_button_style(btn)
		var target = entry[1]
		if target == "quit":
			btn.pressed.connect(func(): get_tree().quit())
		else:
			btn.pressed.connect(_go_to.bind(target))
		root_vbox.add_child(btn)

	var version_label = Label.new()
	version_label.text = "v0.1 Early Access"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	version_label.offset_top = -40
	add_child(version_label)
