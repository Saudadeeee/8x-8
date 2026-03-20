# res://scripts/ui/settings_screen.gd
extends Control

var _saved_label: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _go_to(path: String) -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm:
		sm.go_to_scene(path)
	else:
		get_tree().change_scene_to_file(path)

func _get_settings():
	return get_node_or_null("/root/SettingsManagerSingleton")

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
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 90
	add_child(title)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(600, 400)
	vbox.offset_left = -300
	vbox.offset_top = -200
	vbox.offset_right = 300
	vbox.offset_bottom = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	var settings = _get_settings()
	var master_val = settings.master_volume if settings else 1.0
	var music_val = settings.music_volume if settings else 0.8
	var sfx_val = settings.sfx_volume if settings else 1.0
	var fs_val = settings.is_fullscreen if settings else false

	_add_slider_row(vbox, "Master Volume", master_val, func(v: float):
		var s = _get_settings()
		if s: s.set_master_volume(v))

	_add_slider_row(vbox, "Music Volume", music_val, func(v: float):
		var s = _get_settings()
		if s: s.set_music_volume(v))

	_add_slider_row(vbox, "SFX Volume", sfx_val, func(v: float):
		var s = _get_settings()
		if s: s.set_sfx_volume(v))

	var fs_hbox = HBoxContainer.new()
	fs_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(fs_hbox)

	var fs_label = Label.new()
	fs_label.text = "Fullscreen"
	fs_label.custom_minimum_size = Vector2(180, 0)
	fs_label.add_theme_font_size_override("font_size", 18)
	fs_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	fs_hbox.add_child(fs_label)

	var fs_check = CheckButton.new()
	fs_check.button_pressed = fs_val
	fs_check.add_theme_font_size_override("font_size", 18)
	fs_check.toggled.connect(func(v: bool):
		var s = _get_settings()
		if s: s.set_fullscreen(v))
	fs_hbox.add_child(fs_check)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var save_btn = Button.new()
	save_btn.text = "Save Settings"
	save_btn.custom_minimum_size = Vector2(200, 50)
	save_btn.add_theme_font_size_override("font_size", 18)
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)

	_saved_label = Label.new()
	_saved_label.text = "Saved!"
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_saved_label.add_theme_font_size_override("font_size", 18)
	_saved_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2, 1))
	_saved_label.visible = false
	vbox.add_child(_saved_label)

func _add_slider_row(parent: VBoxContainer, label_text: String, initial_value: float, on_change: Callable) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	hbox.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(300, 0)
	hbox.add_child(slider)

	var pct_label = Label.new()
	pct_label.text = "%d%%" % int(initial_value * 100)
	pct_label.custom_minimum_size = Vector2(60, 0)
	pct_label.add_theme_font_size_override("font_size", 18)
	pct_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	hbox.add_child(pct_label)

	slider.value_changed.connect(func(v: float):
		pct_label.text = "%d%%" % int(v * 100)
		on_change.call(v))

func _on_save_pressed() -> void:
	var settings = _get_settings()
	if settings:
		settings.save_settings()
	_saved_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_saved_label):
		_saved_label.visible = false
