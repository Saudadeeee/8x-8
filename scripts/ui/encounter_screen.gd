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
	_bg = UIStyle.dim_overlay(0.85)
	add_child(_bg)

	# Center panel — giấy da có khối
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 520)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -310
	_panel.offset_top = -260
	_panel.offset_right = 310
	_panel.offset_bottom = 260
	UIStyle.apply_panel(_panel, "parchment")
	add_child(_panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(panel_vbox)

	# Icon trong khung rarity (đổi màu khung theo rarity ở show_encounter)
	var icon_frame = PanelContainer.new()
	icon_frame.name = "IconFrame"
	icon_frame.add_theme_stylebox_override("panel", UIStyle.rarity_frame("common"))
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.pixel_filter(icon_frame)
	panel_vbox.add_child(icon_frame)

	_icon_rect = ColorRect.new()
	_icon_rect.color = Color(0, 0, 0, 0)
	_icon_rect.custom_minimum_size = Vector2(88, 88)
	icon_frame.add_child(_icon_rect)

	var icon_tex = TextureRect.new()
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_tex.name = "IconTexture"
	_icon_rect.add_child(icon_tex)

	# Title
	_title_label = Label.new()
	_title_label.text = "Event"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(_title_label, 32, UIStyle.GOLD)
	panel_vbox.add_child(_title_label)

	# Flavor text
	_flavor_label = Label.new()
	_flavor_label.text = ""
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_flavor_label, 16, Color(0.88, 0.86, 0.80, 1))
	_flavor_label.custom_minimum_size = Vector2(500, 0)
	panel_vbox.add_child(_flavor_label)

	# Rarity
	_rarity_label = Label.new()
	_rarity_label.text = "COMMON"
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(_rarity_label, 14, UIStyle.RARITY_COMMON)
	panel_vbox.add_child(_rarity_label)

	panel_vbox.add_child(UIStyle.separator(UIStyle.BORDER_HI))

	# Choices container
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(_choices_container)

	# Skip button
	_skip_button = Button.new()
	_skip_button.text = "✖  Skip"
	_skip_button.custom_minimum_size = Vector2(180, 44)
	_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.apply_button(_skip_button, 16)
	_skip_button.pressed.connect(_on_skip_pressed)
	panel_vbox.add_child(_skip_button)

func show_encounter(encounter) -> void:
	if not encounter:
		return

	_title_label.text = encounter.title
	_flavor_label.text = encounter.flavor_text

	# Rarity: chữ + khung icon đổi màu theo độ hiếm
	var rarity_key := "common"
	match encounter.rarity:
		0: # COMMON
			_rarity_label.text = "◆ COMMON"
			rarity_key = "common"
		1: # UNCOMMON
			_rarity_label.text = "◆ UNCOMMON"
			rarity_key = "rare"
		2: # RARE
			_rarity_label.text = "◆ RARE"
			rarity_key = "epic"
		3: # LEGENDARY
			_rarity_label.text = "◆ LEGENDARY"
			rarity_key = "legendary"
	_rarity_label.add_theme_color_override("font_color", UIStyle.rarity_color(rarity_key))
	var icon_frame := _panel.find_child("IconFrame", true, false) as PanelContainer
	if icon_frame:
		icon_frame.add_theme_stylebox_override("panel", UIStyle.rarity_frame(rarity_key))

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

	var choice_index := 0
	for choice_res in encounter.choices:
		var choice = choice_res
		if not choice:
			continue
		var btn = Button.new()
		btn.text = choice.choice_text
		if choice.outcome_preview != "":
			btn.tooltip_text = choice.outcome_preview
		btn.custom_minimum_size = Vector2(500, 52)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UIStyle.apply_button(btn, 16)
		btn.pressed.connect(func(): _on_choice_pressed(choice))
		_choices_container.add_child(btn)
		UIStyle.pop_in(btn, 0.14 + choice_index * 0.06)
		choice_index += 1

	visible = true
	UIStyle.pop_in(_panel)
	UIStyle.pulse(_title_label, 1.08)

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
