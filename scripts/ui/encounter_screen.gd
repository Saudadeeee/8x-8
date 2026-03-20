# res://scripts/ui/encounter_screen.gd
# Encounter overlay - shown when GameManager enters ENCOUNTER state.
extends CanvasLayer

var _panel: PanelContainer
var _icon_rect: ColorRect
var _title_label: Label
var _flavor_label: Label
var _rarity_label: Label
var _choices_container: VBoxContainer
var _skip_button: Button
var _bg: ColorRect

func _ready() -> void:
	layer = 10
	visible = false
	_build_ui()

	# Connect to GameManager state changes
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		if gm.has_signal("state_changed"):
			gm.state_changed.connect(_on_game_state_changed)
		if gm.has_signal("encounter_triggered"):
			gm.encounter_triggered.connect(_on_encounter_triggered)

func _build_ui() -> void:
	# Semi-transparent background
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.85)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Center panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(600, 500)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -300
	_panel.offset_top = -250
	_panel.offset_right = 300
	_panel.offset_bottom = 250
	add_child(_panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(panel_vbox)

	# Icon placeholder
	var icon_hbox = HBoxContainer.new()
	icon_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_vbox.add_child(icon_hbox)

	_icon_rect = ColorRect.new()
	_icon_rect.color = Color(0, 0, 0, 0)
	_icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_hbox.add_child(_icon_rect)

	var icon_tex = TextureRect.new()
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_tex.name = "IconTexture"
	_icon_rect.add_child(icon_tex)

	# Title
	_title_label = Label.new()
	_title_label.text = "Encounter"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	panel_vbox.add_child(_title_label)

	# Flavor text
	_flavor_label = Label.new()
	_flavor_label.text = ""
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.add_theme_font_size_override("font_size", 16)
	_flavor_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	_flavor_label.custom_minimum_size = Vector2(500, 0)
	panel_vbox.add_child(_flavor_label)

	# Rarity
	_rarity_label = Label.new()
	_rarity_label.text = "COMMON"
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_label.add_theme_font_size_override("font_size", 14)
	panel_vbox.add_child(_rarity_label)

	# Separator
	var sep = HSeparator.new()
	panel_vbox.add_child(sep)

	# Choices container
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(_choices_container)

	# Skip button
	_skip_button = Button.new()
	_skip_button.text = "Skip / Close"
	_skip_button.custom_minimum_size = Vector2(160, 40)
	_skip_button.add_theme_font_size_override("font_size", 16)
	_skip_button.pressed.connect(_on_skip_pressed)
	panel_vbox.add_child(_skip_button)

func show_encounter(encounter) -> void:
	if not encounter:
		return

	_title_label.text = encounter.title
	_flavor_label.text = encounter.flavor_text

	# Rarity color
	match encounter.rarity:
		0: # COMMON
			_rarity_label.text = "COMMON"
			_rarity_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		1: # UNCOMMON
			_rarity_label.text = "UNCOMMON"
			_rarity_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2, 1))
		2: # RARE
			_rarity_label.text = "RARE"
			_rarity_label.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0, 1))
		3: # LEGENDARY
			_rarity_label.text = "LEGENDARY"
			_rarity_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1))

	# Icon texture based on type
	var icon_paths = {
		0: "res://assets/ui/encounter_treasure.png",   # REWARD
		1: "res://assets/ui/encounter_battle.png",     # RISK
		2: "res://assets/ui/encounter_curse.png",      # MIXED
	}
	var icon_path = icon_paths.get(encounter.encounter_type, "res://assets/ui/encounter_event.png")
	var icon_node = _icon_rect.get_node_or_null("IconTexture") as TextureRect
	if icon_node:
		var tex = load(icon_path) as Texture2D
		if tex:
			icon_node.texture = tex

	# Build choice buttons
	for child in _choices_container.get_children():
		child.queue_free()

	for choice_res in encounter.choices:
		var choice = choice_res
		if not choice:
			continue
		var btn = Button.new()
		btn.text = choice.choice_text
		if choice.outcome_preview != "":
			btn.tooltip_text = choice.outcome_preview
		btn.custom_minimum_size = Vector2(500, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): _on_choice_pressed(choice))
		_choices_container.add_child(btn)

	visible = true

func _on_choice_pressed(choice) -> void:
	if not visible:
		return  # Tránh double-fire nếu button bị nhấn 2 lần hoặc cùng frame
	visible = false
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if not gm:
		return
	# Chỉ áp dụng hiệu ứng khi đang ở ENCOUNTER state
	if gm.current_state != gm.GameState.ENCOUNTER:
		return
	if choice.gold_delta > 0:
		gm.add_gold(choice.gold_delta)
	elif choice.gold_delta < 0:
		gm.spend_gold(abs(choice.gold_delta))
	if choice.health_delta < 0:
		gm.take_damage(abs(choice.health_delta))
	elif choice.health_delta > 0:
		gm.current_health += choice.health_delta
		gm.health_changed.emit(gm.current_health)
	if choice.decree_delta != 0.0:
		gm.current_decree_max = max(1.0, gm.current_decree_max + choice.decree_delta)
		gm.decree_changed.emit(gm.current_decree)
	# Chỉ chuyển sang PREPARING nếu player chưa chết (tránh race với GAME_OVER)
	if gm.current_state != gm.GameState.GAME_OVER:
		gm.call_deferred("change_state", gm.GameState.PREPARING)

func _on_skip_pressed() -> void:
	if not visible:
		return
	visible = false
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.current_state == gm.GameState.ENCOUNTER:
		gm.call_deferred("change_state", gm.GameState.PREPARING)

func _on_game_state_changed(new_state: int) -> void:
	# Ẩn encounter screen khi rời khỏi ENCOUNTER state
	if new_state != GameManager.GameState.ENCOUNTER:
		if visible:
			visible = false

func _on_encounter_triggered(encounter) -> void:
	show_encounter(encounter)
