# res://scripts/ui/king_select.gd
extends Control

const KING_PATHS: Array[String] = [
	"res://res/kings/king_iron.tres",
	"res://res/kings/king_phantom.tres",
	"res://res/kings/king_flame.tres",
]

## Trần Ascension của game — mirror GameManager.MAX_ASCENSION (đọc lại từ
## GameManager khi autoload có mặt, hằng này chỉ là fallback).
const MAX_ASCENSION_FALLBACK: int = 5
## Hệ số Ascension — mirror công thức asc_* trong GameManager, chỉ dùng để MÔ TẢ.
const ASC_HP_PER_LEVEL: float = 0.15
const ASC_SPEED_PER_LEVEL: float = 0.04
const ASC_GOLD_PER_LEVEL: int = -10
const ASC_REWARD_PER_LEVEL: float = 0.25

var _selected_king: KingStats = null
var _meta: MetaProgress = null
var _start_btn: Button = null
## Bậc Ascension đang chọn cho ván sắp tới.
var _ascension_level: int = 0
var _asc_value_label: Label = null
var _asc_desc_label: Label = null
var _asc_prev_btn: Button = null
var _asc_next_btn: Button = null
var _detail_name: Label
var _detail_lore: Label
var _detail_ability: Label
var _detail_favor: Label
var _detail_stats: Label
var _detail_locked: Label
## ModelIcon 3D lớn ở panel chi tiết (dùng king.gltf).
var _detail_icon: ModelIcon = null

const KING_MODEL_PATH := "res://assets/models/king.gltf"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Vào lại từ một ván đang pause / chạy 3× → trả về trạng thái chuẩn
	_restore_normal_speed()
	_meta = MetaProgress.load_or_create()
	_build_ui()

## Bỏ pause + trả Engine.time_scale về 1× (không bao giờ đặt 0).
func _restore_normal_speed() -> void:
	var tree := get_tree()
	if tree:
		tree.paused = false
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_method("reset_game_speed"):
		gm.reset_game_speed()
	else:
		Engine.time_scale = 1.0

func _go_to(path: String) -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm:
		sm.go_to_scene(path)
	else:
		get_tree().change_scene_to_file(path)

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
	title.text = "♛  CHOOSE YOUR KING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title, 48, UIStyle.GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 90
	add_child(title)
	UIStyle.pop_in(title)

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

	var card_index := 0
	for king in kings_loaded:
		var is_unlocked = king.is_starter_king or king.id in _meta.unlocked_king_ids
		var card := _create_king_card_button(king, is_unlocked)
		king_vbox.add_child(card)
		UIStyle.pop_in(card, 0.08 + card_index * 0.07)
		card_index += 1

	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.6
	UIStyle.apply_panel(right_panel, "parchment")
	main_hbox.add_child(right_panel)
	UIStyle.slide_in(right_panel, Vector2(90, 0), 0.34)

	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 12)
	right_panel.add_child(detail_vbox)

	# Model 3D của King trong khung vàng — điểm nhấn của màn chọn tướng
	var icon_frame = PanelContainer.new()
	icon_frame.add_theme_stylebox_override("panel", UIStyle.rarity_frame("legendary"))
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.pixel_filter(icon_frame)
	detail_vbox.add_child(icon_frame)
	_detail_icon = ModelIcon.new()
	_detail_icon.name = "KingModelIcon"
	_detail_icon.set_icon_size(150)
	icon_frame.add_child(_detail_icon)
	_detail_icon.setup(KING_MODEL_PATH)
	UIStyle.pop_in(icon_frame, 0.12)

	_detail_name = Label.new()
	_detail_name.text = "Select a King"
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(_detail_name, 32, UIStyle.GOLD)
	detail_vbox.add_child(_detail_name)

	detail_vbox.add_child(UIStyle.separator(UIStyle.BORDER_HI))

	_detail_lore = Label.new()
	_detail_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_detail_lore, 16, Color(0.85, 0.85, 0.85, 1))
	detail_vbox.add_child(_detail_lore)

	_detail_stats = Label.new()
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_detail_stats, 15, Color(0.7, 0.9, 1.0, 1))
	detail_vbox.add_child(_detail_stats)

	_detail_favor = Label.new()
	_detail_favor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_detail_favor, 15, Color(0.8, 0.7, 1.0, 1))
	detail_vbox.add_child(_detail_favor)

	detail_vbox.add_child(UIStyle.separator(UIStyle.BORDER_HI))

	_detail_ability = Label.new()
	_detail_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_detail_ability, 15, Color(0.9, 0.8, 0.4, 1))
	detail_vbox.add_child(_detail_ability)

	_detail_locked = Label.new()
	_detail_locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(_detail_locked, 18, Color(0.9, 0.3, 0.3, 1))
	detail_vbox.add_child(_detail_locked)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_vbox.add_child(spacer)

	_build_ascension_row(detail_vbox)

	_start_btn = Button.new()
	_start_btn.text = "⚔  START RUN"
	_start_btn.custom_minimum_size = Vector2(260, 62)
	_start_btn.disabled = true
	UIStyle.apply_button_accent(_start_btn, UIStyle.GREEN, 22)
	_start_btn.pressed.connect(_on_start_pressed)
	detail_vbox.add_child(_start_btn)

	for king in kings_loaded:
		var is_unlocked = king.is_starter_king or king.id in _meta.unlocked_king_ids
		if is_unlocked:
			_select_king(king)
			break

## Card King: khung vàng (legendary) nếu đã mở, khung xám (common) nếu chưa.
## Vẫn trả về Button để giữ nguyên API/logic cũ (pressed → _select_king).
func _create_king_card_button(king: KingStats, is_unlocked: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 84)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rarity := "legendary" if is_unlocked else "common"
	UIStyle.apply_button(btn, 19, UIStyle.rarity_color(rarity).lightened(0.45))
	# Khung rarity thay cho stylebox nút thường → card có viền khối rõ ràng
	btn.add_theme_stylebox_override("normal", UIStyle.rarity_frame(rarity))
	var hover_box := UIStyle.rarity_frame(rarity)
	if hover_box is StyleBoxFlat:
		var f := hover_box as StyleBoxFlat
		f.bg_color = f.bg_color.lightened(0.12)
		f.border_color = f.border_color.lightened(0.28)
	elif hover_box is StyleBoxTexture:
		(hover_box as StyleBoxTexture).modulate_color = UIStyle.rarity_color(rarity).lightened(0.4)
	btn.add_theme_stylebox_override("hover", hover_box)
	btn.add_theme_stylebox_override("pressed", UIStyle.rarity_frame(rarity))
	btn.add_theme_stylebox_override("disabled", UIStyle.rarity_frame("common"))
	if is_unlocked:
		btn.text = "♛  %s" % king.king_name
	else:
		btn.text = "  %s  (%d pts)" % [king.king_name, king.unlock_cost]
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
		_detail_locked.text = " LOCKED — cần %d Meta Points" % king.unlock_cost
		_start_btn.disabled = true
	# Nhấn mạnh việc đổi tướng: tên pulse + model quay lại từ đầu
	UIStyle.pulse(_detail_name, 1.10)
	if is_instance_valid(_detail_icon):
		UIStyle.pulse(_detail_icon, 1.08)

# ── Ascension (bậc độ khó) ────────────────────────────────────────────────────

## Bậc cao nhất được phép chọn — ưu tiên hỏi GameManager, fallback đọc MetaProgress.
func _max_ascension() -> int:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_method("max_selectable_ascension"):
		return maxi(0, int(gm.max_selectable_ascension()))
	if _meta:
		var unlocked: Variant = _meta.get("ascension_unlocked")
		if unlocked is int or unlocked is float:
			return clampi(int(unlocked), 0, MAX_ASCENSION_FALLBACK)
	return 0

## Hàng chọn Ascension: [◀]  A0  [▶] + dòng mô tả hệ số.
func _build_ascension_row(parent: VBoxContainer) -> void:
	parent.add_child(UIStyle.separator(UIStyle.BORDER_HI))

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	_asc_prev_btn = Button.new()
	_asc_prev_btn.text = "◀"
	_asc_prev_btn.custom_minimum_size = Vector2(48, 40)
	UIStyle.apply_button(_asc_prev_btn, 18, UIStyle.TEXT)
	_asc_prev_btn.pressed.connect(_shift_ascension.bind(-1))
	row.add_child(_asc_prev_btn)

	_asc_value_label = Label.new()
	_asc_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_asc_value_label.custom_minimum_size = Vector2(150, 0)
	UIStyle.title(_asc_value_label, 24, UIStyle.GOLD)
	row.add_child(_asc_value_label)

	_asc_next_btn = Button.new()
	_asc_next_btn.text = "▶"
	_asc_next_btn.custom_minimum_size = Vector2(48, 40)
	UIStyle.apply_button(_asc_next_btn, 18, UIStyle.TEXT)
	_asc_next_btn.pressed.connect(_shift_ascension.bind(1))
	row.add_child(_asc_next_btn)

	_asc_desc_label = Label.new()
	_asc_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_asc_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(_asc_desc_label, 13, Color(1.0, 0.72, 0.45, 1.0))
	parent.add_child(_asc_desc_label)

	_ascension_level = clampi(_ascension_level, 0, _max_ascension())
	_refresh_ascension_ui()

func _shift_ascension(delta: int) -> void:
	var new_level: int = clampi(_ascension_level + delta, 0, _max_ascension())
	if new_level == _ascension_level:
		return
	_ascension_level = new_level
	_refresh_ascension_ui()
	if is_instance_valid(_asc_value_label):
		UIStyle.pulse(_asc_value_label, 1.16)

func _refresh_ascension_ui() -> void:
	var cap := _max_ascension()
	if is_instance_valid(_asc_value_label):
		_asc_value_label.text = "Ascension A%d" % _ascension_level
	if is_instance_valid(_asc_prev_btn):
		_asc_prev_btn.disabled = _ascension_level <= 0
	if is_instance_valid(_asc_next_btn):
		_asc_next_btn.disabled = _ascension_level >= cap
	if not is_instance_valid(_asc_desc_label):
		return
	if _ascension_level <= 0:
		if cap <= 0:
			_asc_desc_label.text = "Độ khó thường. Thắng một ván để mở khoá A1."
		else:
			_asc_desc_label.text = "Độ khó thường  ·  đã mở tới A%d" % cap
		return
	_asc_desc_label.text = "Máu địch +%d%%  ·  Tốc độ địch +%d%%  ·  Vàng khởi đầu %d  ·  Thưởng meta +%d%%" % [
		int(round(ASC_HP_PER_LEVEL * 100.0 * _ascension_level)),
		int(round(ASC_SPEED_PER_LEVEL * 100.0 * _ascension_level)),
		ASC_GOLD_PER_LEVEL * _ascension_level,
		int(round(ASC_REWARD_PER_LEVEL * 100.0 * _ascension_level)),
	]

func _on_start_pressed() -> void:
	if not _selected_king:
		return
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		# set_ascension PHẢI chạy trước start_run — start_run áp trừ vàng khởi đầu
		if gm.has_method("set_ascension"):
			gm.set_ascension(_ascension_level)
		gm.start_run(_selected_king)
	_go_to("res://scenes/map/game_map.tscn")
