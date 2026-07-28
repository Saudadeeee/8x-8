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
	bg.color = Color(0.055, 0.038, 0.075, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var back_btn = Button.new()
	back_btn.text = "←  Back"
	back_btn.custom_minimum_size = Vector2(130, 46)
	back_btn.position = Vector2(20, 20)
	UIStyle.apply_button(back_btn, 17)
	back_btn.pressed.connect(_go_to.bind("res://scenes/ui/main_menu.tscn"))
	add_child(back_btn)
	UIStyle.slide_in(back_btn, Vector2(-160, 0), 0.3)

	var title = Label.new()
	title.text = "⚙  SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title, 48, UIStyle.GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 90
	add_child(title)
	UIStyle.pop_in(title)

	# Panel giấy da bọc form → khối nổi, không còn slider trôi trên nền phẳng
	var frame = PanelContainer.new()
	frame.name = "SettingsFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -330
	frame.offset_top = -210
	frame.offset_right = 330
	frame.offset_bottom = 210
	UIStyle.apply_panel(frame, "parchment")
	add_child(frame)
	UIStyle.pop_in(frame, 0.06)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	frame.add_child(vbox)

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
	UIStyle.body(fs_label, 18, Color(0.9, 0.9, 0.9, 1))
	fs_hbox.add_child(fs_label)

	var fs_check = CheckButton.new()
	fs_check.button_pressed = fs_val
	fs_check.add_theme_font_size_override("font_size", 18)
	fs_check.toggled.connect(func(v: bool):
		var s = _get_settings()
		if s: s.set_fullscreen(v))
	fs_hbox.add_child(fs_check)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	var save_btn = Button.new()
	save_btn.text = "  Save Settings"
	save_btn.custom_minimum_size = Vector2(220, 52)
	save_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.apply_button_accent(save_btn, UIStyle.GREEN, 18)
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)

	_saved_label = Label.new()
	_saved_label.text = "✓ Saved!"
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(_saved_label, 18, Color(0.2, 1.0, 0.2, 1))
	_saved_label.visible = false
	vbox.add_child(_saved_label)

func _add_slider_row(parent: VBoxContainer, label_text: String, initial_value: float, on_change: Callable) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	UIStyle.body(lbl, 18, Color(0.9, 0.9, 0.9, 1))
	hbox.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(300, 0)
	_style_slider(slider)
	hbox.add_child(slider)

	var pct_label = Label.new()
	pct_label.text = "%d%%" % int(initial_value * 100)
	pct_label.custom_minimum_size = Vector2(60, 0)
	UIStyle.glyph(pct_label, 18, UIStyle.GOLD)
	hbox.add_child(pct_label)

	slider.value_changed.connect(func(v: float):
		pct_label.text = "%d%%" % int(v * 100)
		on_change.call(v))

## Slider lõm (rãnh tối) + grabber vàng nổi — khớp ngôn ngữ khối của UI.
func _style_slider(slider: HSlider) -> void:
	if slider == null:
		return
	slider.add_theme_stylebox_override(
		"slider", UIStyle.flat_inset(Color(0.04, 0.04, 0.04, 0.95), Color(0, 0, 0, 0.8), 3))
	var grab := UIStyle.flat(UIStyle.BORDER_HI, UIStyle.GOLD, 3, 2)
	grab.content_margin_left = 0.0
	grab.content_margin_right = 0.0
	grab.content_margin_top = 0.0
	grab.content_margin_bottom = 0.0
	slider.add_theme_stylebox_override("grabber_area", grab)
	slider.add_theme_stylebox_override("grabber_area_highlight", UIStyle.flat(UIStyle.GOLD, UIStyle.TEXT, 3, 2))

func _on_save_pressed() -> void:
	var settings = _get_settings()
	if settings:
		settings.save_settings()
	_saved_label.visible = true
	UIStyle.pop_in(_saved_label)
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_saved_label):
		_saved_label.visible = false
