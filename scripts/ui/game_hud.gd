# res://scripts/ui/game_hud.gd
extends CanvasLayer

signal tower_selected(tower_stats: TowerStats)

@onready var tower_container = $Control/RightPanel/VBoxContainer/TowerContainer
@onready var label_health = $Control/VBoxContainer/LabelHealth
@onready var label_gold = $Control/VBoxContainer/LabelGold
@onready var label_decree = $Control/VBoxContainer/LabelRoyalDecree
@onready var label_favor = $Control/VBoxContainer/LabelKingFavor
@onready var label_territory = $Control/VBoxContainer/LabelTerritories
@onready var label_phase = $Control/VBoxContainer/LabelPhase
@onready var shop_panel = $Control/ShopPanel
@onready var shop_list = shop_panel.get_node("VBoxContainer/ShopList") as VBoxContainer
@onready var shop_next_wave_button = shop_panel.get_node("VBoxContainer/ButtonNextWave") as Button
@onready var shop_status_label = shop_panel.get_node("VBoxContainer/LabelStatus") as Label
@onready var meta_shop_button = shop_panel.get_node("VBoxContainer/ButtonOpenMetaShop") as Button

@onready var shop_popup = $Control/ShopPopup as PopupPanel
@onready var shop_popup_title = shop_popup.get_node("PanelContainer/VBoxContainer/LabelShopPopupTitle") as Label
@onready var shop_popup_message = shop_popup.get_node("PanelContainer/VBoxContainer/LabelShopPopupMessage") as Label
@onready var shop_popup_open_meta_button = shop_popup.get_node("PanelContainer/VBoxContainer/HBoxButtons/ButtonShopPopupOpen") as Button
@onready var shop_popup_close_button = shop_popup.get_node("PanelContainer/VBoxContainer/HBoxButtons/ButtonShopPopupClose") as Button

@onready var meta_shop_popup = $Control/MetaShopPopup as PopupPanel
@onready var meta_shop_list = meta_shop_popup.get_node("PanelContainer/VBoxContainer/MetaShopList") as VBoxContainer
@onready var meta_shop_status_label = meta_shop_popup.get_node("PanelContainer/VBoxContainer/LabelMetaStatus") as Label
@onready var meta_shop_close_button = meta_shop_popup.get_node("PanelContainer/VBoxContainer/HBoxMetaButtons/ButtonMetaShopClose") as Button

@onready var label_king_name = $Control/RightPanel/VBoxContainer/LabelKingName
@onready var label_ability_info = $Control/RightPanel/VBoxContainer/LabelAbilityInfo
@onready var btn_king_ability = $Control/RightPanel/VBoxContainer/ButtonKingAbility

var shop_manager: ShopPanelManager
var meta_shop_manager: MetaShopManager

# ── Territory section ─────────────────────────────────────────────────────────
var _territory_container: VBoxContainer = null

# ── Dismiss section ───────────────────────────────────────────────────────────
var _dismiss_container: VBoxContainer = null

# ── Tower info panel (slide-in left) ─────────────────────────────────────────
var _tower_info_panel: PanelContainer = null
var _tower_info_visible: bool = false
var _tower_info_tween: Tween = null

# ── Prep countdown (large center-top display) ─────────────────────────────────
var _countdown_label: Label = null

# ── Pause / ESC menu ──────────────────────────────────────────────────────────
var _pause_overlay: ColorRect = null
var _esc_menu: PanelContainer = null
var _settings_panel: PanelContainer = null
var _is_paused: bool = false

const BASE_TOWER_RESOURCES: Array[String] = [
	"res://res/towers/pawn.tres",
	"res://res/towers/knight.tres",
	"res://res/towers/rook.tres",
	"res://res/towers/bishop.tres",
	"res://res/towers/queen.tres",
	"res://res/towers/commander.tres",
	"res://res/towers/crossbowman.tres",
	"res://res/towers/warlock.tres",
	"res://res/towers/catapult.tres",
	"res://res/towers/dark_mage.tres",
]

# ── Màu sắc HUD ──────────────────────────────────────────────────────────────
const C_BG        := Color(0.07, 0.06, 0.05, 0.96)   # nền panel chính
const C_BG_DARK   := Color(0.04, 0.03, 0.03, 0.98)   # nền đậm hơn
const C_BORDER    := Color(0.55, 0.42, 0.12, 1.0)    # viền vàng cổ
const C_BORDER_HI := Color(0.88, 0.72, 0.20, 1.0)    # viền vàng sáng
const C_GOLD      := Color(1.00, 0.84, 0.20, 1.0)    # chữ vàng
const C_WHITE     := Color(0.92, 0.90, 0.85, 1.0)    # chữ trắng kem
const C_DIM       := Color(0.60, 0.56, 0.50, 1.0)    # chữ mờ
const C_GREEN     := Color(0.35, 0.85, 0.40, 1.0)    # giá trị tốt
const C_RED       := Color(0.90, 0.25, 0.20, 1.0)    # cảnh báo
const C_BLUE      := Color(0.45, 0.72, 1.00, 1.0)    # decree

# Màu theo loại shop item
const ITEM_COLOR := {
	"TROOP":     Color(0.30, 0.60, 1.00, 1.0),
	"UPGRADE":   Color(1.00, 0.70, 0.10, 1.0),
	"TERRITORY": Color(0.30, 0.80, 0.40, 1.0),
	"DISMISS":   Color(0.80, 0.30, 0.30, 1.0),
}

# ── Helpers StyleBox ──────────────────────────────────────────────────────────
func _make_panel_style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left   = 8
	s.content_margin_right  = 8
	s.content_margin_top    = 6
	s.content_margin_bottom = 6
	return s

func _make_btn_style(bg: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left   = 6
	s.content_margin_right  = 6
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	return s

func _style_label(lbl: Label, size: int, color: Color) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

func _style_button(btn: Button, bg: Color, border: Color, text_color: Color, size: int = 13) -> void:
	btn.add_theme_stylebox_override("normal",   _make_btn_style(bg, border))
	btn.add_theme_stylebox_override("hover",    _make_btn_style(bg.lightened(0.12), border.lightened(0.2)))
	btn.add_theme_stylebox_override("pressed",  _make_btn_style(bg.darkened(0.15), border))
	btn.add_theme_stylebox_override("disabled", _make_btn_style(Color(bg, 0.5), Color(border, 0.3)))
	btn.add_theme_color_override("font_color",          text_color)
	btn.add_theme_color_override("font_hover_color",    text_color.lightened(0.15))
	btn.add_theme_color_override("font_pressed_color",  text_color.darkened(0.15))
	btn.add_theme_color_override("font_disabled_color", Color(text_color, 0.4))
	btn.add_theme_font_size_override("font_size", size)

# ── Inits ─────────────────────────────────────────────────────────────────────
func _ready():
	# CanvasLayer phải process ngay cả khi game paused để nhận input
	process_mode = Node.PROCESS_MODE_ALWAYS

	if shop_popup:
		shop_popup.hide()
	if meta_shop_popup:
		meta_shop_popup.hide()
	_apply_hud_styles()
	shop_panel.visible = false
	if btn_king_ability:
		btn_king_ability.pressed.connect(_on_king_ability_pressed)
	_setup_shop()
	if meta_shop_button:
		meta_shop_button.visible = false
	_refresh_tower_buttons()
	_build_right_panel_extensions()
	_build_tower_info_panel()
	_build_pause_ui()
	_build_countdown_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			if _esc_menu and _esc_menu.visible:
				return  # ESC menu đang mở, P không làm gì
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if _settings_panel and _settings_panel.visible:
				_settings_panel.visible = false
				get_viewport().set_input_as_handled()
			elif _esc_menu and _esc_menu.visible:
				_close_esc_menu()
				get_viewport().set_input_as_handled()
			else:
				_open_esc_menu()
				get_viewport().set_input_as_handled()

# ── Pause ─────────────────────────────────────────────────────────────────────
func _toggle_pause() -> void:
	if _is_paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	_is_paused = true
	get_tree().paused = true
	if _pause_overlay:
		_pause_overlay.visible = true

func _resume_game() -> void:
	_is_paused = false
	get_tree().paused = false
	if _pause_overlay:
		_pause_overlay.visible = false
	_close_esc_menu()

func _open_esc_menu() -> void:
	if not _is_paused:
		_pause_game()
	if _esc_menu:
		_esc_menu.visible = true

func _close_esc_menu() -> void:
	if _esc_menu:
		_esc_menu.visible = false
	if _settings_panel:
		_settings_panel.visible = false
	# Chỉ resume nếu không còn menu nào mở
	if _is_paused:
		_resume_game()

# ── Build pause UI ────────────────────────────────────────────────────────────
func _build_countdown_label() -> void:
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_countdown_label = Label.new()
	_countdown_label.name = "PrepCountdownLabel"
	_countdown_label.anchor_left   = 0.5
	_countdown_label.anchor_right  = 0.5
	_countdown_label.anchor_top    = 0.0
	_countdown_label.anchor_bottom = 0.0
	_countdown_label.offset_left   = -80
	_countdown_label.offset_right  = 80
	_countdown_label.offset_top    = 54
	_countdown_label.offset_bottom = 150
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 72)
	_countdown_label.add_theme_color_override("font_color", C_GOLD)
	_countdown_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_countdown_label.add_theme_constant_override("shadow_offset_x", 2)
	_countdown_label.add_theme_constant_override("shadow_offset_y", 2)
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_label.visible = false
	root_ctrl.add_child(_countdown_label)

func update_prep_countdown(seconds: int) -> void:
	if not _countdown_label:
		return
	if seconds <= 0:
		_countdown_label.visible = false
		return
	_countdown_label.visible = true
	_countdown_label.text = str(seconds)
	# Đổi màu khi còn ít thời gian
	if seconds <= 3:
		_countdown_label.add_theme_color_override("font_color", C_RED)
	elif seconds <= 5:
		_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1.0))
	else:
		_countdown_label.add_theme_color_override("font_color", C_GOLD)

func _build_pause_ui() -> void:
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return

	# Nền mờ toàn màn hình khi pause (P)
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0, 0, 0, 0.45)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(_pause_overlay)

	var paused_lbl = Label.new()
	paused_lbl.text = "⏸  PAUSED"
	paused_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paused_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paused_lbl.add_theme_font_size_override("font_size", 48)
	paused_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	paused_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(paused_lbl)

	# ESC menu panel
	_esc_menu = PanelContainer.new()
	_esc_menu.name = "EscMenu"
	_esc_menu.custom_minimum_size = Vector2(260, 0)
	_esc_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_esc_menu.offset_left  = -130
	_esc_menu.offset_right = 130
	_esc_menu.offset_top   = -140
	_esc_menu.offset_bottom = 140
	_esc_menu.add_theme_stylebox_override("panel", _make_panel_style(C_BG_DARK, C_BORDER_HI, 6))
	_esc_menu.visible = false
	_esc_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(_esc_menu)

	var menu_vbox = VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_theme_constant_override("separation", 10)
	_esc_menu.add_child(menu_vbox)

	var menu_title = Label.new()
	menu_title.text = "— Menu —"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 18)
	menu_title.add_theme_color_override("font_color", C_GOLD)
	menu_vbox.add_child(menu_title)

	var sep = HSeparator.new()
	menu_vbox.add_child(sep)

	_add_menu_button(menu_vbox, "▶  Tiếp tục  (ESC)", func(): _close_esc_menu())
	_add_menu_button(menu_vbox, "⚙  Cài đặt", func(): _show_settings_panel())
	_add_menu_button(menu_vbox, "🏠  Menu chính", func(): _go_main_menu())
	_add_menu_button(menu_vbox, "✖  Thoát game", func(): get_tree().quit())

	# Settings inline panel
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.custom_minimum_size = Vector2(420, 0)
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_settings_panel.offset_left   = -210
	_settings_panel.offset_right  = 210
	_settings_panel.offset_top    = -200
	_settings_panel.offset_bottom = 200
	_settings_panel.add_theme_stylebox_override("panel", _make_panel_style(C_BG_DARK, C_BORDER_HI, 6))
	_settings_panel.visible = false
	_settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(_settings_panel)

	var sv = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(sv)

	var stitle = Label.new()
	stitle.text = "Cài đặt"
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 18)
	stitle.add_theme_color_override("font_color", C_GOLD)
	sv.add_child(stitle)

	var sm = get_node_or_null("/root/SettingsManagerSingleton")
	_add_settings_slider(sv, "Âm lượng Master", sm.master_volume if sm else 1.0, func(v: float):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_master_volume(v))
	_add_settings_slider(sv, "Âm nhạc", sm.music_volume if sm else 0.8, func(v: float):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_music_volume(v))
	_add_settings_slider(sv, "Hiệu ứng âm thanh", sm.sfx_volume if sm else 1.0, func(v: float):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_sfx_volume(v))

	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	sv.add_child(fs_row)
	var fs_lbl = Label.new()
	fs_lbl.text = "Toàn màn hình"
	fs_lbl.custom_minimum_size = Vector2(200, 0)
	fs_lbl.add_theme_font_size_override("font_size", 14)
	fs_lbl.add_theme_color_override("font_color", C_WHITE)
	fs_row.add_child(fs_lbl)
	var fs_chk = CheckButton.new()
	fs_chk.button_pressed = sm.is_fullscreen if sm else false
	fs_chk.process_mode = Node.PROCESS_MODE_ALWAYS
	fs_chk.toggled.connect(func(v: bool):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_fullscreen(v))
	fs_row.add_child(fs_chk)

	var save_btn = Button.new()
	save_btn.text = "Lưu cài đặt"
	save_btn.custom_minimum_size = Vector2(160, 36)
	save_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(save_btn, Color(0.1, 0.3, 0.1, 1), C_GREEN, C_GREEN, 13)
	save_btn.pressed.connect(func():
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.save_settings())
	sv.add_child(save_btn)

	_add_menu_button(sv, "← Quay lại", func(): _settings_panel.visible = false)

func _add_menu_button(parent: Control, txt: String, cb: Callable) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(220, 38)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_button(btn, C_BG, C_BORDER, C_WHITE, 14)
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn

func _add_settings_slider(parent: VBoxContainer, lbl_text: String, init_val: float, cb: Callable) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var lbl = Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_WHITE)
	row.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = init_val
	slider.custom_minimum_size = Vector2(160, 0)
	slider.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(slider)
	var pct = Label.new()
	pct.text = "%d%%" % int(init_val * 100)
	pct.custom_minimum_size = Vector2(42, 0)
	pct.add_theme_font_size_override("font_size", 12)
	pct.add_theme_color_override("font_color", C_DIM)
	row.add_child(pct)
	slider.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v * 100)
		cb.call(v))

func _show_settings_panel() -> void:
	if _settings_panel:
		_settings_panel.visible = true

func _go_main_menu() -> void:
	get_tree().paused = false
	_is_paused = false
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm and sm.has_method("go_to_scene"):
		sm.go_to_scene("res://scenes/ui/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _apply_hud_styles() -> void:
	# ── Stats panel (trái trên) ──────────────────────────────────────────
	var stats_vbox = get_node_or_null("Control/VBoxContainer")
	if stats_vbox:
		var stat_panel = stats_vbox.get_parent()
		if stat_panel is PanelContainer:
			stat_panel.add_theme_stylebox_override("panel", _make_panel_style(C_BG_DARK, C_BORDER, 4))
		# Labels
		for lbl in [label_health, label_gold, label_decree, label_favor, label_territory, label_phase]:
			if lbl: _style_label(lbl, 13, C_WHITE)
		if label_health: label_health.add_theme_color_override("font_color", C_RED)
		if label_gold:   label_gold.add_theme_color_override("font_color", C_GOLD)
		if label_decree: label_decree.add_theme_color_override("font_color", C_BLUE)
		if label_phase:  label_phase.add_theme_color_override("font_color", C_DIM)

	# ── Right panel (deploy units) ────────────────────────────────────────
	var right_panel = get_node_or_null("Control/RightPanel")
	if right_panel and right_panel is PanelContainer:
		right_panel.add_theme_stylebox_override("panel", _make_panel_style(C_BG_DARK, C_BORDER_HI, 4))
	# Header label trên RightPanel
	var rp_vbox = get_node_or_null("Control/RightPanel/VBoxContainer")
	if rp_vbox:
		var header = rp_vbox.get_node_or_null("HeaderDeploy")
		if header is Label:
			_style_label(header, 14, C_GOLD)

	# ── Shop panel ────────────────────────────────────────────────────────
	if shop_panel and shop_panel is PanelContainer:
		shop_panel.add_theme_stylebox_override("panel", _make_panel_style(C_BG_DARK, C_BORDER, 4))
	if shop_status_label:
		_style_label(shop_status_label, 12, C_DIM)
		shop_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ── Next Wave button ──────────────────────────────────────────────────
	if shop_next_wave_button:
		_style_button(shop_next_wave_button, Color(0.12, 0.35, 0.12, 1), C_GREEN, C_GREEN, 14)
		shop_next_wave_button.text = "▶  NEXT WAVE"

	# ── King ability section ──────────────────────────────────────────
	if label_king_name:
		_style_label(label_king_name, 12, C_GOLD)
		label_king_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_ability_info:
		_style_label(label_ability_info, 10, C_DIM)
	if btn_king_ability:
		_style_button(btn_king_ability, Color(0.10, 0.10, 0.25, 1), C_BLUE, C_BLUE, 11)

	# ── Shop title label ──────────────────────────────────────────────────
	var shop_title = shop_panel.get_node_or_null("VBoxContainer/LabelShopTitle") if shop_panel else null
	if shop_title is Label:
		_style_label(shop_title, 14, C_GOLD)

func _on_tower_button_pressed(stats: TowerStats):
	tower_selected.emit(stats)

# ── Shop panel visibility ──────────────────────────────────────────────────────
func show_shop_panel() -> void:
	if shop_panel:
		shop_panel.visible = true

func hide_shop_panel() -> void:
	if shop_panel:
		shop_panel.visible = false

# ── King ability ───────────────────────────────────────────────────────────────
func update_king_info(king_stats, king_mgr) -> void:
	if not king_stats:
		return
	if label_king_name:
		label_king_name.text = king_stats.king_name
	if label_ability_info:
		var cost_text = "%.0f RD" % king_stats.ability_decree_cost
		label_ability_info.text = "%s\n%s" % [king_stats.ability_name, cost_text]
	if btn_king_ability:
		var on_cooldown = king_mgr != null and king_mgr.has_method("is_ability_ready") and not king_mgr.is_ability_ready()
		var can_afford = king_mgr != null and king_mgr.can_afford(king_stats.ability_decree_cost)
		btn_king_ability.disabled = not can_afford or on_cooldown
		if on_cooldown and king_mgr.get("_ability_cooldown_remaining") != null:
			var cd = king_mgr._ability_cooldown_remaining
			btn_king_ability.text = "⏳ %.0fs" % cd
		else:
			btn_king_ability.text = "⚡ %s" % king_stats.ability_name.left(10)

func _on_king_ability_pressed() -> void:
	var map_node = _find_game_map()
	if not map_node:
		return
	var km = map_node.get_node_or_null("KingManager")
	if km and km.has_method("use_ability"):
		var success = km.use_ability()
		if success:
			# execute_king_ability() is called via ability_activated signal → game_map._on_king_ability_activated
			_flash_ability_button()

func _flash_ability_button() -> void:
	if not btn_king_ability:
		return
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(btn_king_ability, "modulate", Color(1.5, 1.2, 0.3, 1.0), 0.15)
	tween.tween_property(btn_king_ability, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

# ── Shop setup ────────────────────────────────────────────────────────────────
func _setup_shop():
	var map_node = _find_game_map()
	if not map_node:
		return
	var manager = map_node.get_node_or_null("ShopManager") as ShopPanelManager
	if not manager:
		return
	shop_manager = manager

	var next_wave_callable = Callable(self, "_on_shop_next_wave_pressed")
	if not shop_next_wave_button.is_connected("pressed", next_wave_callable):
		shop_next_wave_button.pressed.connect(next_wave_callable)

	var hide_popup_callable = Callable(self, "hide_shop_popup")
	if not shop_popup_close_button.is_connected("pressed", hide_popup_callable):
		shop_popup_close_button.pressed.connect(hide_popup_callable)

	var open_meta_callable = Callable(self, "open_meta_shop")
	if not shop_popup_open_meta_button.is_connected("pressed", open_meta_callable):
		shop_popup_open_meta_button.pressed.connect(open_meta_callable)

	var purchased_callable = Callable(self, "_on_shop_item_purchased")
	if not manager.shop_item_purchased.is_connected(purchased_callable):
		manager.shop_item_purchased.connect(purchased_callable)
	var failed_callable = Callable(self, "_on_shop_purchase_failed")
	if not manager.shop_purchase_failed.is_connected(failed_callable):
		manager.shop_purchase_failed.connect(failed_callable)
	var stock_callable = Callable(self, "_on_shop_unit_stock_changed")
	if not manager.unit_stock_changed.is_connected(stock_callable):
		manager.unit_stock_changed.connect(stock_callable)
	var offers_callable = Callable(self, "_on_shop_offers_refreshed")
	if not manager.shop_offers_refreshed.is_connected(offers_callable):
		manager.shop_offers_refreshed.connect(offers_callable)

	shop_status_label.text = ""

	# Inject gold label + roll button into shop panel VBox (above the list)
	var shop_vbox = shop_panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if shop_vbox:
		_inject_shop_header(shop_vbox)

	_refresh_shop_offers(manager.get_items())

func _on_shop_offers_refreshed(items: Array[ShopItemData]) -> void:
	_refresh_shop_offers(items)

func _refresh_shop_offers(items: Array[ShopItemData]) -> void:
	for child in shop_list.get_children():
		child.queue_free()
	if not items:
		return
	for item in items:
		shop_list.add_child(_create_shop_item_card(item))

# ── Shop item card ────────────────────────────────────────────────────────────
func _create_shop_item_card(item: ShopItemData) -> Control:
	var type_name = ShopItemData.ItemType.keys()[item.item_type] if item.item_type < ShopItemData.ItemType.size() else "TROOP"
	var accent = ITEM_COLOR.get(type_name, C_GOLD)

	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 58)
	var card_style = _make_panel_style(C_BG, accent.darkened(0.55), 3)
	card_style.border_color = accent.darkened(0.2)
	container.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	container.add_child(hbox)

	# Icon
	if item.icon:
		var tex = TextureRect.new()
		tex.texture = item.icon
		tex.custom_minimum_size = Vector2(36, 36)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tex)

	# Text vbox
	var tvbox = VBoxContainer.new()
	tvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tvbox.add_theme_constant_override("separation", 2)
	hbox.add_child(tvbox)

	var name_lbl = Label.new()
	name_lbl.text = item.display_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", C_WHITE)
	name_lbl.clip_text = true
	tvbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	var desc_short = item.description.substr(0, 48) + ("..." if item.description.length() > 48 else "")
	desc_lbl.text = desc_short
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", C_DIM)
	tvbox.add_child(desc_lbl)

	# Cost + type tag
	var bottom_hbox = HBoxContainer.new()
	tvbox.add_child(bottom_hbox)

	var type_lbl = Label.new()
	type_lbl.text = "[%s]" % type_name.left(3)
	type_lbl.add_theme_font_size_override("font_size", 10)
	type_lbl.add_theme_color_override("font_color", accent)
	bottom_hbox.add_child(type_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	var cost_lbl = Label.new()
	if item.cost <= 0.0:
		cost_lbl.text = "FREE"
		cost_lbl.add_theme_color_override("font_color", C_GREEN)
	elif item.use_royal_decree:
		cost_lbl.text = "%.1f RD" % item.cost
		cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	else:
		cost_lbl.text = "%.0f G" % item.cost
		cost_lbl.add_theme_color_override("font_color", C_GOLD)
	cost_lbl.add_theme_font_size_override("font_size", 12)
	bottom_hbox.add_child(cost_lbl)

	# Click → buy
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_shop_button_pressed(item.id)
	)
	container.mouse_entered.connect(func():
		var hs = _make_panel_style(C_BG.lightened(0.08), accent.lightened(0.15), 3)
		container.add_theme_stylebox_override("panel", hs)
	)
	container.mouse_exited.connect(func():
		container.add_theme_stylebox_override("panel", card_style)
	)
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.tooltip_text = item.description + (("\nBuff: " + item.territory_buff_summary) if item.territory_buff_summary != "" else "")
	return container

# ── Tower buttons ─────────────────────────────────────────────────────────────
func _refresh_tower_buttons():
	for child in tower_container.get_children():
		child.queue_free()
	if not shop_manager:
		return
	var stock_snapshot: Dictionary = shop_manager.get_unit_stock_items()
	for stats_id in stock_snapshot.keys():
		var amount: int = stock_snapshot[stats_id]
		if amount <= 0:
			continue
		var stats = shop_manager.get_tower_stats_by_id(stats_id)
		if stats:
			_create_tower_card(stats, amount)

func _create_tower_card(stats: TowerStats, stock_count: int = 0) -> void:
	var is_limited = stock_count > 0
	var border_col = C_BORDER_HI if is_limited else C_BORDER

	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 52)
	var card_style = _make_panel_style(C_BG, border_col, 3)
	container.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	container.add_child(hbox)

	# Icon — fallback: load từ assets/towers/{id}.png nếu texture chưa set
	if stats.texture == null:
		var fallback = "res://assets/towers/%s.png" % stats.id
		if ResourceLoader.exists(fallback):
			stats.texture = load(fallback)
	if stats.texture:
		var tex = TextureRect.new()
		tex.texture = stats.texture
		tex.custom_minimum_size = Vector2(32, 32)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tex)

	# Info vbox
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = stats.name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", C_WHITE)
	vbox.add_child(name_lbl)

	var stats_row = HBoxContainer.new()
	vbox.add_child(stats_row)

	var decree_lbl = Label.new()
	decree_lbl.text = "%.0f RD" % stats.decree_cost
	decree_lbl.add_theme_font_size_override("font_size", 11)
	decree_lbl.add_theme_color_override("font_color", C_BLUE)
	stats_row.add_child(decree_lbl)

	if is_limited:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_row.add_child(spacer)
		var stock_lbl = Label.new()
		stock_lbl.text = "x%d" % stock_count
		stock_lbl.add_theme_font_size_override("font_size", 11)
		stock_lbl.add_theme_color_override("font_color", C_GREEN)
		stats_row.add_child(stock_lbl)

	# Hover/click handling
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_tower_button_pressed(stats)
	)
	container.mouse_entered.connect(func():
		var hs = _make_panel_style(C_BG.lightened(0.1), border_col.lightened(0.25), 3)
		container.add_theme_stylebox_override("panel", hs)
	)
	container.mouse_exited.connect(func():
		container.add_theme_stylebox_override("panel", card_style)
	)
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.tooltip_text = "%s\nATK:%d  SPD:%.2fs  RNG:%d\nDeploy: %.0f RD" % [
		stats.description, stats.base_damage, stats.attack_speed, stats.attack_range, stats.decree_cost
	]
	tower_container.add_child(container)

func _get_current_tower_paths() -> Array[String]:
	var result = BASE_TOWER_RESOURCES.duplicate()
	if meta_shop_manager:
		for path in meta_shop_manager.get_unlocked_tower_paths():
			if not result.has(path):
				result.append(path)
	return result

# ── Territory / Right panel extensions ────────────────────────────────────────
const BIOME_NAMES := {
	"fire": "Hỏa Địa", "swamp": "Đầm Lầy", "ice": "Băng Nguyên",
	"forest": "Rừng Rậm", "desert": "Sa Mạc", "thunder": "Lôi Vực",
}

func _build_right_panel_extensions() -> void:
	var rp_vbox = get_node_or_null("Control/RightPanel/VBoxContainer")
	if not rp_vbox:
		return

	# --- Territory stock ---
	rp_vbox.add_child(HSeparator.new())
	var ter_header = Label.new()
	ter_header.text = "Lãnh thổ trong kho"
	_style_label(ter_header, 12, C_GOLD)
	ter_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_vbox.add_child(ter_header)
	_territory_container = VBoxContainer.new()
	_territory_container.add_theme_constant_override("separation", 4)
	rp_vbox.add_child(_territory_container)

	# --- Dismiss stock ---
	rp_vbox.add_child(HSeparator.new())
	var dis_header = Label.new()
	dis_header.text = "Lệnh Giải Tán"
	_style_label(dis_header, 12, C_GOLD)
	dis_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_vbox.add_child(dis_header)
	_dismiss_container = VBoxContainer.new()
	_dismiss_container.add_theme_constant_override("separation", 4)
	rp_vbox.add_child(_dismiss_container)
	refresh_dismiss_stock(0)

func refresh_territories(_biome_counts: Dictionary) -> void:
	pass  # Hiển thị trực tiếp trên bàn cờ qua Sprite2D

func refresh_territory_stock(stock: Dictionary) -> void:
	if not _territory_container:
		return
	for child in _territory_container.get_children():
		child.queue_free()
	var has_any = false
	for biome_key in stock.keys():
		var count: int = stock.get(biome_key, 0)
		if count <= 0:
			continue
		has_any = true
		_create_territory_card(biome_key, count)
	if not has_any:
		var empty_lbl = Label.new()
		empty_lbl.text = "—"
		_style_label(empty_lbl, 11, C_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_territory_container.add_child(empty_lbl)

func _create_territory_card(biome_key: String, count: int) -> void:
	var biome_name: String = BIOME_NAMES.get(biome_key, biome_key)
	var accent = Color(0.30, 0.80, 0.40, 1.0)  # xanh lá — territory

	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 48)
	var card_style = _make_panel_style(C_BG, accent.darkened(0.3), 3)
	container.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	container.add_child(hbox)

	# Icon từ territory sprite
	var tex: Texture2D = null
	var tex_path = "res://assets/tiles/territory_%s.png" % biome_key
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path) as Texture2D
	else:
		var img = Image.load_from_file(ProjectSettings.globalize_path(tex_path))
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex:
		var icon = TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon)

	# Tên + số lượng
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = biome_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", C_WHITE)
	vbox.add_child(name_lbl)

	var count_lbl = Label.new()
	count_lbl.text = "x%d còn lại" % count
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", C_GREEN)
	vbox.add_child(count_lbl)

	# Click → chọn territory này để đặt
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var map_node = _find_game_map()
			if map_node and map_node.has_method("select_territory"):
				map_node.select_territory(biome_key)
	)
	container.mouse_entered.connect(func():
		var hs = _make_panel_style(C_BG.lightened(0.1), accent.lightened(0.2), 3)
		container.add_theme_stylebox_override("panel", hs)
	)
	container.mouse_exited.connect(func():
		container.add_theme_stylebox_override("panel", card_style)
	)
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.tooltip_text = "Click để đặt %s lên bản đồ" % biome_name
	_territory_container.add_child(container)

func refresh_dismiss_stock(count: int) -> void:
	if not _dismiss_container:
		return
	for child in _dismiss_container.get_children():
		child.queue_free()
	if count <= 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "—"
		_style_label(empty_lbl, 11, C_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dismiss_container.add_child(empty_lbl)
		return
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 48)
	var red_accent = Color(0.85, 0.2, 0.2, 1.0)
	card.add_theme_stylebox_override("panel", _make_panel_style(C_BG, red_accent.darkened(0.3), 3))
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)
	var icon_lbl = Label.new()
	icon_lbl.text = "🗡"
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_lbl)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	var name_lbl = Label.new()
	name_lbl.text = "Giải Tán"
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", C_WHITE)
	vbox.add_child(name_lbl)
	var count_lbl = Label.new()
	count_lbl.text = "x%d lượt" % count
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", red_accent)
	vbox.add_child(count_lbl)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var map_node = _find_game_map()
			if map_node and map_node.has_method("enter_dismiss_mode"):
				map_node.enter_dismiss_mode()
	)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "Click để chọn tháp cần giải tán (hoàn 50% vàng)"
	_dismiss_container.add_child(card)

# ── Tower info panel (slide-in from left) ─────────────────────────────────────
const TOWER_INFO_WIDTH := 220

func _build_tower_info_panel() -> void:
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_tower_info_panel = PanelContainer.new()
	_tower_info_panel.name = "TowerInfoPanel"
	_tower_info_panel.anchor_left   = 0.0
	_tower_info_panel.anchor_right  = 0.0
	_tower_info_panel.anchor_top    = 0.0
	_tower_info_panel.anchor_bottom = 1.0
	_tower_info_panel.offset_left   = -TOWER_INFO_WIDTH
	_tower_info_panel.offset_right  = 0
	_tower_info_panel.add_theme_stylebox_override("panel", _make_panel_style(C_BG_DARK, C_BORDER_HI, 0))
	root_ctrl.add_child(_tower_info_panel)

func show_tower_info(stats: TowerStats, biome_key: String = "", tower_node: Node2D = null) -> void:
	if not _tower_info_panel:
		return
	for child in _tower_info_panel.get_children():
		child.queue_free()
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tower_info_panel.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header: icon + name
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	var icon_tex = stats.texture if stats.texture else stats.projectile_texture
	if icon_tex:
		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(icon_rect)
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_vbox)
	var name_lbl = Label.new()
	name_lbl.text = stats.name
	_style_label(name_lbl, 14, C_GOLD)
	name_lbl.clip_text = true
	name_vbox.add_child(name_lbl)
	if stats.faction != "":
		var faction_lbl = Label.new()
		faction_lbl.text = "[%s]" % stats.faction
		_style_label(faction_lbl, 10, C_DIM)
		name_vbox.add_child(faction_lbl)

	vbox.add_child(HSeparator.new())

	# Real-time stats if tower_node provided, otherwise base stats
	if tower_node and is_instance_valid(tower_node):
		var cur_dmg: int = tower_node.get("current_damage") if tower_node.get("current_damage") != null else stats.base_damage
		var cur_spd: float = tower_node.get("current_attack_speed") if tower_node.get("current_attack_speed") != null else stats.attack_speed
		var cur_rng: int = tower_node.get("current_range") if tower_node.get("current_range") != null else stats.attack_range
		var dmg_bonus: int = cur_dmg - stats.base_damage
		var spd_bonus: float = stats.attack_speed - cur_spd
		var rng_bonus: int = cur_rng - stats.attack_range
		_add_buffed_int_row(vbox, "⚔ Sát thương", stats.base_damage, dmg_bonus)
		_add_buffed_float_row(vbox, "⚡ Tốc đánh", stats.attack_speed, -spd_bonus, "s")
		_add_buffed_int_row(vbox, "◎ Tầm bắn", stats.attack_range, rng_bonus)
	else:
		_add_info_row(vbox, "⚔ Sát thương", str(stats.base_damage))
		_add_info_row(vbox, "⚡ Tốc đánh", "%.2fs" % stats.attack_speed)
		_add_info_row(vbox, "◎ Tầm bắn", str(stats.attack_range))

	# Special effects
	if stats.slow_amount > 0.0:
		_add_info_row(vbox, "❄ Làm chậm", "%.0f%% × %.1fs" % [stats.slow_amount * 100, stats.slow_duration])
	if stats.burn_dps > 0:
		_add_info_row(vbox, "🔥 Thiêu đốt", "%d DPS × %.1fs" % [stats.burn_dps, stats.burn_duration])
	if stats.splash_radius > 0.0:
		_add_info_row(vbox, "💥 AoE Splash", "%.0fpx" % stats.splash_radius)
	if stats.projectile_count > 1:
		_add_info_row(vbox, "🎯 Số đạn", "×%d" % stats.projectile_count)

	# Territory buff on tile
	if biome_key != "":
		vbox.add_child(HSeparator.new())
		var biome_display := {
			"fire": "🔥 Hỏa Địa (+6 ATK)", "swamp": "🌿 Đầm Lầy (-0.2s CD)",
			"ice": "❄️ Băng Nguyên (+2 RNG)", "forest": "🌲 Rừng Rậm (+3 ATK +1 RNG)",
			"desert": "☀️ Sa Mạc (+4 ATK -0.1s)", "thunder": "⚡ Lôi Vực (+3 ATK +1 RNG)",
		}
		var ter_lbl = Label.new()
		ter_lbl.text = biome_display.get(biome_key, biome_key)
		_style_label(ter_lbl, 10, Color(0.3, 0.85, 0.4))
		ter_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(ter_lbl)

	# Description
	if stats.description != "":
		vbox.add_child(HSeparator.new())
		var desc = Label.new()
		desc.text = stats.description
		_style_label(desc, 10, C_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	_slide_tower_info(true)

func _add_buffed_int_row(parent: VBoxContainer, label_text: String, base_val: int, bonus: int) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var lbl = Label.new()
	lbl.text = label_text
	_style_label(lbl, 11, C_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val_lbl = Label.new()
	if bonus != 0:
		val_lbl.text = "%d" % (base_val + bonus)
		_style_label(val_lbl, 11, C_WHITE)
		row.add_child(val_lbl)
		var bonus_lbl = Label.new()
		var sign_str = "+" if bonus > 0 else ""
		bonus_lbl.text = "(%s%d)" % [sign_str, bonus]
		_style_label(bonus_lbl, 10, Color(0.3, 1.0, 0.4) if bonus > 0 else Color(1.0, 0.4, 0.3))
		row.add_child(bonus_lbl)
	else:
		val_lbl.text = str(base_val)
		_style_label(val_lbl, 11, C_WHITE)
		row.add_child(val_lbl)

func _add_buffed_float_row(parent: VBoxContainer, label_text: String, base_val: float, bonus: float, suffix: String = "") -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var lbl = Label.new()
	lbl.text = label_text
	_style_label(lbl, 11, C_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var val_lbl = Label.new()
	if abs(bonus) > 0.001:
		val_lbl.text = "%.2f%s" % [base_val + bonus, suffix]
		_style_label(val_lbl, 11, C_WHITE)
		row.add_child(val_lbl)
		var bonus_lbl = Label.new()
		var sign_str = "+" if bonus > 0 else ""
		bonus_lbl.text = "(%s%.2f%s)" % [sign_str, bonus, suffix]
		_style_label(bonus_lbl, 10, Color(0.3, 1.0, 0.4) if bonus > 0 else Color(1.0, 0.4, 0.3))
		row.add_child(bonus_lbl)
	else:
		val_lbl.text = "%.2f%s" % [base_val, suffix]
		_style_label(val_lbl, 11, C_WHITE)
		row.add_child(val_lbl)

func show_territory_info(biome_key: String, biome_data: Dictionary) -> void:
	if not _tower_info_panel:
		return
	for child in _tower_info_panel.get_children():
		child.queue_free()
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tower_info_panel.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Header icon + tên biome
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	var icon_path = "res://assets/ui/shop_icons/icon_%s.png" % biome_key
	if ResourceLoader.exists(icon_path):
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(icon_path) as Texture2D
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(icon_rect)
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_vbox)
	var name_lbl = Label.new()
	name_lbl.text = biome_data.get("name", biome_key)
	_style_label(name_lbl, 14, C_GOLD)
	name_vbox.add_child(name_lbl)
	var type_lbl = Label.new()
	type_lbl.text = "[Lãnh thổ]"
	_style_label(type_lbl, 10, Color(0.3, 0.85, 0.4))
	name_vbox.add_child(type_lbl)

	vbox.add_child(HSeparator.new())

	# Buff effects
	var dmg: int = biome_data.get("damage_bonus", 0)
	var spd: float = biome_data.get("attack_speed_reduction", 0.0)
	var rng: int = biome_data.get("range_bonus", 0)
	if dmg != 0: _add_info_row(vbox, "⚔ Sát thương", "+%d" % dmg)
	if spd != 0.0: _add_info_row(vbox, "⚡ Cooldown", "-%.1fs" % spd)
	if rng != 0: _add_info_row(vbox, "◎ Tầm bắn", "+%d" % rng)

	vbox.add_child(HSeparator.new())

	var hint = Label.new()
	hint.text = "Đặt tower lên ô này để nhận buff."
	_style_label(hint, 10, C_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	_slide_tower_info(true)

func hide_tower_info() -> void:
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
		_tower_info_tween.set_parallel(true)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_left", 0.0, 0.2)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_right", float(TOWER_INFO_WIDTH), 0.2)
	else:
		_tower_info_visible = false
		_tower_info_tween.set_parallel(true)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_left", float(-TOWER_INFO_WIDTH), 0.2)
		_tower_info_tween.tween_property(_tower_info_panel, "offset_right", 0.0, 0.2)

func _add_info_row(vbox: VBoxContainer, key: String, val: String) -> void:
	var row = HBoxContainer.new()
	vbox.add_child(row)
	var k = Label.new()
	k.text = key
	_style_label(k, 11, C_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v = Label.new()
	v.text = val
	_style_label(v, 11, C_WHITE)
	row.add_child(v)

# ── Purchases ─────────────────────────────────────────────────────────────────
func _on_shop_button_pressed(item_id: String) -> void:
	var map_node = _find_game_map()
	if not map_node:
		return
	if map_node.has_method("attempt_shop_purchase"):
		map_node.attempt_shop_purchase(item_id)

func _on_shop_next_wave_pressed() -> void:
	var map_node = _find_game_map()
	if not map_node:
		return
	if map_node.has_method("request_next_wave_phase"):
		map_node.request_next_wave_phase()

func _on_shop_item_purchased(item_data: ShopItemData) -> void:
	shop_status_label.text = "Mua: %s" % item_data.display_name
	shop_status_label.add_theme_color_override("font_color", C_GREEN)

func _on_shop_unit_stock_changed(_stats_id: String, _amount: int) -> void:
	_refresh_tower_buttons()

func _on_shop_purchase_failed(_item_id: String, reason: String) -> void:
	shop_status_label.text = reason
	shop_status_label.add_theme_color_override("font_color", C_RED)

# ── Popups ────────────────────────────────────────────────────────────────────
func show_shop_popup(title: String = "Shop Phase", message: String = "Shop time! Reinforce your forces.") -> void:
	if shop_popup:
		shop_popup_title.text = title
		shop_popup_message.text = message
		shop_popup.popup_centered_ratio(0.35)

func hide_shop_popup() -> void:
	if shop_popup:
		shop_popup.hide()

func open_meta_shop() -> void:
	if not meta_shop_manager:
		_setup_meta_shop()
	if meta_shop_popup:
		_refresh_meta_shop_list()
		meta_shop_popup.popup_centered_ratio(0.35)

func _hide_meta_shop() -> void:
	if meta_shop_popup and meta_shop_popup.is_visible():
		meta_shop_popup.hide()

func _setup_meta_shop() -> void:
	var map_node = _find_game_map()
	if not map_node:
		return
	var manager = map_node.get_node_or_null("MetaShopManager") as MetaShopManager
	if not manager:
		return
	meta_shop_manager = manager

	var close_meta_callable = Callable(self, "_hide_meta_shop")
	if not meta_shop_close_button.is_connected("pressed", close_meta_callable):
		meta_shop_close_button.pressed.connect(close_meta_callable)

	var purchased_callable = Callable(self, "_on_meta_item_purchased")
	if not manager.meta_item_purchased.is_connected(purchased_callable):
		manager.meta_item_purchased.connect(purchased_callable)

	meta_shop_status_label.text = ""
	_refresh_meta_shop_list()

func _refresh_meta_shop_list() -> void:
	if not meta_shop_manager:
		return
	for child in meta_shop_list.get_children():
		child.queue_free()
	for item in meta_shop_manager.get_all_meta_items():
		var is_unlocked = meta_shop_manager.is_item_unlocked(item)
		var container = PanelContainer.new()
		container.custom_minimum_size = Vector2(0, 52)
		var bg = C_BG_DARK if is_unlocked else C_BG
		var bd = C_DIM if is_unlocked else C_BORDER
		container.add_theme_stylebox_override("panel", _make_panel_style(bg, bd, 3))

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		container.add_child(hbox)

		if item.icon:
			var tex = TextureRect.new()
			tex.texture = item.icon
			tex.custom_minimum_size = Vector2(28, 28)
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tex.modulate = Color(1,1,1, 0.4 if is_unlocked else 1.0)
			hbox.add_child(tex)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)

		var n = Label.new()
		n.text = item.display_name + (" [Đã mua]" if is_unlocked else "")
		n.add_theme_font_size_override("font_size", 12)
		n.add_theme_color_override("font_color", C_DIM if is_unlocked else C_WHITE)
		vbox.add_child(n)

		if not is_unlocked:
			var cost_lbl = Label.new()
			cost_lbl.text = "%.0f RD" % item.cost
			cost_lbl.add_theme_font_size_override("font_size", 11)
			cost_lbl.add_theme_color_override("font_color", C_BLUE)
			vbox.add_child(cost_lbl)

		if not is_unlocked:
			container.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_on_meta_shop_button_pressed(item.id)
			)
			container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		meta_shop_list.add_child(container)

func _on_meta_shop_button_pressed(item_id: String) -> void:
	if not meta_shop_manager:
		return
	var map_node = _find_game_map()
	if not map_node:
		return
	var king = map_node.get_node_or_null("KingManager") as KingManager
	if not king:
		return
	var success = meta_shop_manager.attempt_purchase(item_id, king)
	if not success:
		meta_shop_status_label.text = "Không đủ Royal Decree hoặc đã mua"

func _on_meta_item_purchased(item: MetaShopItemData) -> void:
	meta_shop_status_label.text = "Unlocked: %s" % item.display_name
	_refresh_meta_shop_list()
	_refresh_tower_buttons()

# ── Utilities ─────────────────────────────────────────────────────────────────
func _find_game_map() -> Node2D:
	var scene = get_tree().get_current_scene()
	if scene:
		var found = _search_for_game_map(scene)
		if found:
			return found
	return _search_for_game_map(get_tree().get_root())

func _search_for_game_map(node: Node) -> Node2D:
	if not node:
		return null
	if node.name == "GameMap" and node is Node2D:
		return node
	for child in node.get_children():
		var found = _search_for_game_map(child)
		if found:
			return found
	return null

# ── Labels update ─────────────────────────────────────────────────────────────
func update_labels(health: int, gold: int, royal_decree: float = 0.0, favor_summary: String = "", territory_summary: String = "", phase_text: String = "", can_continue_wave: bool = false):
	if not is_node_ready():
		await ready
	label_health.text  = "♥  %d" % health
	label_gold.text    = "◆  %d" % gold
	var rd = round(royal_decree * 10.0) / 10.0
	label_decree.text  = "⚡ %.1f RD" % rd
	label_favor.text   = "✦ %s" % (favor_summary if favor_summary != "" else "—")
	label_territory.text = "▣ %s" % (territory_summary if territory_summary != "" else "—")
	label_phase.text   = phase_text if phase_text != "" else "—"
	shop_next_wave_button.disabled = not can_continue_wave
	update_shop_gold(gold)
	update_shop_royal_decree(royal_decree)

func show_game_over():
	pass

# ── Enemy Intel (wave preview during prep phase) ───────────────────────────────
var _intel_panel: PanelContainer = null
var _intel_label: Label = null

func _ensure_intel_panel() -> void:
	if _intel_panel:
		return
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_intel_panel = PanelContainer.new()
	_intel_panel.name = "IntelPanel"
	_intel_panel.anchor_left   = 0.0
	_intel_panel.anchor_right  = 1.0
	_intel_panel.anchor_top    = 0.0
	_intel_panel.anchor_bottom = 0.0
	_intel_panel.offset_top    = 4
	_intel_panel.offset_bottom = 48
	_intel_panel.offset_left   = 160
	_intel_panel.offset_right  = -160
	_intel_panel.add_theme_stylebox_override("panel", _make_panel_style(C_BG_DARK, C_BORDER, 4))
	_intel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_intel_panel)
	_intel_label = Label.new()
	_intel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_intel_label, 12, C_WHITE)
	_intel_panel.add_child(_intel_label)

func show_wave_intel(text: String) -> void:
	_ensure_intel_panel()
	if _intel_label:
		_intel_label.text = text
	if _intel_panel:
		_intel_panel.visible = true

func hide_wave_intel() -> void:
	if _intel_panel:
		_intel_panel.visible = false

# ── Shop header (gold + RD display + action buttons) ──────────────────────────
var _shop_gold_label: Label = null
var _shop_rd_label:   Label = null

func _inject_shop_header(shop_vbox: VBoxContainer) -> void:
	if shop_vbox.get_node_or_null("ShopStatsRow"):
		return

	# --- Stats row: Gold + RD (đặt ở TOP) ---
	var stats_row = HBoxContainer.new()
	stats_row.name = "ShopStatsRow"
	stats_row.add_theme_constant_override("separation", 8)

	var gold_icon = Label.new()
	gold_icon.text = "◆"
	gold_icon.add_theme_font_size_override("font_size", 14)
	gold_icon.add_theme_color_override("font_color", C_GOLD)
	stats_row.add_child(gold_icon)

	_shop_gold_label = Label.new()
	_shop_gold_label.name = "ShopGoldLabel"
	_shop_gold_label.text = "0"
	_style_label(_shop_gold_label, 14, C_GOLD)
	stats_row.add_child(_shop_gold_label)

	var sep_lbl = Label.new()
	sep_lbl.text = "  |"
	_style_label(sep_lbl, 14, C_DIM)
	stats_row.add_child(sep_lbl)

	var rd_icon = Label.new()
	rd_icon.text = "⚡"
	rd_icon.add_theme_font_size_override("font_size", 14)
	rd_icon.add_theme_color_override("font_color", C_BLUE)
	stats_row.add_child(rd_icon)

	_shop_rd_label = Label.new()
	_shop_rd_label.name = "ShopRDLabel"
	_shop_rd_label.text = "0.0 RD"
	_style_label(_shop_rd_label, 14, C_BLUE)
	_shop_rd_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(_shop_rd_label)

	# Thêm stats_row ở đầu (vị trí 0)
	shop_vbox.add_child(stats_row)
	shop_vbox.move_child(stats_row, 0)

	# --- Action row: Roll (trái) — đặt ở CUỐI (dưới danh sách items) ---
	var action_row = HBoxContainer.new()
	action_row.name = "ShopActionRow"
	action_row.add_theme_constant_override("separation", 6)

	var roll_cost_lbl = Label.new()
	roll_cost_lbl.text = "2G"
	_style_label(roll_cost_lbl, 11, C_DIM)
	action_row.add_child(roll_cost_lbl)

	var roll_btn = Button.new()
	roll_btn.name = "RollButton"
	roll_btn.text = "🎲 Roll"
	roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_btn.custom_minimum_size = Vector2(0, 34)
	_style_button(roll_btn, Color(0.10, 0.16, 0.28, 1.0), C_BLUE, C_BLUE, 13)
	roll_btn.pressed.connect(_on_roll_button_pressed)
	action_row.add_child(roll_btn)

	# Thêm action_row ở cuối (dưới items)
	shop_vbox.add_child(action_row)

func _on_roll_button_pressed() -> void:
	var map_node = _find_game_map()
	if map_node and map_node.has_method("attempt_shop_reroll"):
		map_node.attempt_shop_reroll()

func update_shop_gold(gold: int) -> void:
	if _shop_gold_label:
		_shop_gold_label.text = str(gold)

func update_shop_royal_decree(value: float) -> void:
	if _shop_rd_label:
		_shop_rd_label.text = "%.1f RD" % value

# ── Wave Intel Popup ───────────────────────────────────────────────────────────
const ENEMY_ABILITY_NOTES := {
	"orc":        "Đòn đánh mạnh",
	"goblin":     "Di chuyển rất nhanh",
	"skeleton":   "Kháng chậm, Undead",
	"dark_knight":"Máu cao, khó hạ",
	"demon_imp":  "Tốc độ cao, thiêu đốt",
}

var _intel_popup: PopupPanel = null

func show_wave_intel_popup(data: Dictionary) -> void:
	if _intel_popup and is_instance_valid(_intel_popup):
		_intel_popup.queue_free()
	_intel_popup = PopupPanel.new()
	_intel_popup.name = "WaveIntelPopup"
	_intel_popup.exclusive = false

	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	root_ctrl.add_child(_intel_popup)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_intel_popup.add_child(vbox)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = "⚔  Trinh Sát — Wave %d" % data.get("wave", 0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title_lbl, 18, C_GOLD)
	vbox.add_child(title_lbl)

	# Season
	var season_lbl = Label.new()
	season_lbl.text = "%s  |  %s" % [data.get("season_name", ""), data.get("season_desc", "")]
	season_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(season_lbl, 12, Color(0.8, 0.9, 1.0, 1.0))
	season_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(season_lbl)

	vbox.add_child(HSeparator.new())

	# Header row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)
	for col_text in ["Quân địch", "SL", "HP", "Tốc độ", "Dmg", "Năng lực"]:
		var h = Label.new()
		h.text = col_text
		h.add_theme_font_size_override("font_size", 11)
		h.add_theme_color_override("font_color", C_DIM)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(h)

	vbox.add_child(HSeparator.new())

	# Enemy rows
	var enemies: Array = data.get("enemies", [])
	for e in enemies:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var cols = [
			e.get("display", "?"),
			"×%d" % e.get("count", 0),
			str(e.get("hp", 0)),
			"%d px/s" % e.get("speed", 0),
			"-%d HP" % e.get("damage", 1),
			ENEMY_ABILITY_NOTES.get(e.get("id", ""), "—"),
		]
		var col_colors = [C_WHITE, C_GREEN, Color(1.0, 0.4, 0.4), Color(0.4, 0.9, 1.0), C_RED, C_DIM]
		for i in cols.size():
			var lbl = Label.new()
			lbl.text = cols[i]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", col_colors[i])
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)

	vbox.add_child(HSeparator.new())

	# Total
	var total_lbl = Label.new()
	total_lbl.text = "Tổng: %d địch phải tiêu diệt" % data.get("total", 0)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(total_lbl, 13, C_WHITE)
	vbox.add_child(total_lbl)

	# Close button — xác nhận bắt đầu countdown
	var close_btn = Button.new()
	close_btn.text = "⚔  Sẵn sàng chiến đấu!"
	close_btn.custom_minimum_size = Vector2(240, 42)
	_style_button(close_btn, Color(0.15, 0.08, 0.08, 1.0), C_RED, C_WHITE, 14)
	close_btn.pressed.connect(func():
		_intel_popup.hide()
		var map = _find_game_map()
		if map and map.has_method("confirm_wave_ready"):
			map.confirm_wave_ready()
	)
	vbox.add_child(close_btn)

	# Nếu player đóng popup bằng cách khác, cũng confirm
	_intel_popup.popup_hide.connect(func():
		var map = _find_game_map()
		if map and map.has_method("confirm_wave_ready"):
			map.confirm_wave_ready()
	, CONNECT_ONE_SHOT)

	_intel_popup.min_size = Vector2i(560, 0)
	_intel_popup.popup_centered()
