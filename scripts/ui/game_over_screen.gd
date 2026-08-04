# res://scripts/ui/game_over_screen.gd
extends Control

## Thư mục resource tháp — dùng để đổi stats.id thành tên hiển thị.
const TOWER_RES_FMT: String = "res://res/towers/%s.tres"
## Số dòng tối đa của bảng "Damage contribution".
const TOP_TOWER_COUNT: int = 5
## Màu thanh theo hạng: vàng · bạc · đồng · xanh dương · xanh lá.
const RANK_COLORS: Array[Color] = [
	Color(1.00, 0.84, 0.20, 1.0),
	Color(0.78, 0.80, 0.84, 1.0),
	Color(0.80, 0.52, 0.25, 1.0),
	Color(0.45, 0.72, 1.00, 1.0),
	Color(0.35, 0.85, 0.40, 1.0),
]

var _wave_label: Label
var _enemies_label: Label
var _gold_label: Label
var _meta_pts_label: Label
## Dòng phụ: combo cao nhất + bậc Ascension đã chơi.
var _extra_label: Label
## Vùng chứa các dòng đóng góp sát thương (dựng lại mỗi lần refresh).
var _damage_box: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_restore_normal_speed()
	_build_ui()
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_signal("run_ended"):
		gm.run_ended.connect(_on_run_ended)

## Rời map: bỏ pause + trả tốc độ về 1× để màn kết thúc không chạy nhanh/đứng.
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
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Panel đá nhuộm đỏ máu → tang tóc, có khối
	var frame = PanelContainer.new()
	frame.name = "DefeatFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -330
	frame.offset_top = -330
	frame.offset_right = 330
	frame.offset_bottom = 330
	frame.add_theme_stylebox_override("panel", UIStyle.panel_tinted("stone", UIStyle.BLOOD.darkened(0.35)))
	UIStyle.pixel_filter(frame)
	add_child(frame)
	UIStyle.pop_in(frame)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	frame.add_child(vbox)

	var banner_tex = load("res://assets/ui/defeat_banner.png") as Texture2D
	if banner_tex:
		var banner = TextureRect.new()
		banner.texture = banner_tex
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		banner.custom_minimum_size = Vector2(340, 56)
		vbox.add_child(banner)
		UIStyle.pop_in(banner, 0.05)

	var title = Label.new()
	title.text = "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title, 68, Color(0.9, 0.1, 0.1, 1))
	vbox.add_child(title)
	UIStyle.pop_in(title, 0.10)
	UIStyle.breathe(title, 1.035, 3.2)

	var subtitle = Label.new()
	subtitle.text = "The kingdom has fallen..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(subtitle, 20, Color(0.8, 0.8, 0.8, 1))
	vbox.add_child(subtitle)

	vbox.add_child(UIStyle.separator(UIStyle.BORDER_DIM))

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(stats_vbox)

	_wave_label = _make_stat_label("Reached wave: 0")
	stats_vbox.add_child(_wave_label)
	_enemies_label = _make_stat_label("Enemies killed: 0")
	stats_vbox.add_child(_enemies_label)
	_gold_label = _make_stat_label("Gold earned: 0")
	stats_vbox.add_child(_gold_label)
	_meta_pts_label = _make_stat_label("Meta points: 0 ★")
	UIStyle.glyph(_meta_pts_label, 20, Color(1.0, 0.84, 0.0, 1.0))
	stats_vbox.add_child(_meta_pts_label)

	_extra_label = Label.new()
	_extra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(_extra_label, 15, UIStyle.TEXT_DIM)
	stats_vbox.add_child(_extra_label)

	vbox.add_child(UIStyle.separator(UIStyle.BORDER_DIM))

	var dmg_title = Label.new()
	dmg_title.text = "⚔  DAMAGE CONTRIBUTION"
	dmg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(dmg_title, 17, UIStyle.GOLD)
	vbox.add_child(dmg_title)

	_damage_box = VBoxContainer.new()
	_damage_box.add_theme_constant_override("separation", 3)
	vbox.add_child(_damage_box)

	vbox.add_child(UIStyle.separator(UIStyle.BORDER_DIM))

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)

	var menu_btn = Button.new()
	menu_btn.text = "  Về Menu Chính"
	menu_btn.custom_minimum_size = Vector2(210, 52)
	UIStyle.apply_button(menu_btn, 18)
	menu_btn.pressed.connect(_go_to.bind("res://scenes/ui/main_menu.tscn"))
	btn_hbox.add_child(menu_btn)
	UIStyle.pop_in(menu_btn, 0.30)

	var play_again_btn = Button.new()
	play_again_btn.text = "⚔  Play Again"
	play_again_btn.custom_minimum_size = Vector2(210, 52)
	UIStyle.apply_button_accent(play_again_btn, UIStyle.RED, 18)
	play_again_btn.pressed.connect(_go_to.bind("res://scenes/ui/king_select.tscn"))
	btn_hbox.add_child(play_again_btn)
	UIStyle.pop_in(play_again_btn, 0.37)

	# Luôn hiện stats ngay khi load — run_ended có thể đã emit trước khi scene load
	_refresh_from_gm()

func _make_stat_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(lbl, 18, Color(0.9, 0.9, 0.9, 1))
	return lbl

## Số liệu tổng kết dùng số đếm chạy — cảm giác "cộng điểm" cuối ván.
func show_stats(wave: int, enemies: int, gold: int, meta_pts: int) -> void:
	UIStyle.count_to(_wave_label, 0, wave, "Reached wave: %d", 0.55)
	UIStyle.count_to(_enemies_label, 0, enemies, "Enemies killed: %d", 0.75)
	UIStyle.count_to(_gold_label, 0, gold, "Gold earned: %d", 0.9)
	UIStyle.count_to(_meta_pts_label, 0, meta_pts, "Meta points: %d ★", 1.05)

# ── Bảng đóng góp sát thương ──────────────────────────────────────────────────

## Đổi stats.id → tên hiển thị. Ưu tiên field `name` trong res/towers/<id>.tres,
## thiếu file thì dùng chính id (viết hoa chữ đầu).
func _tower_display_name(id: String) -> String:
	if id == "":
		return "?"
	var path: String = TOWER_RES_FMT % id
	if ResourceLoader.exists(path):
		var res := load(path)
		if res != null:
			var raw: Variant = res.get("name")
			if raw is String and String(raw) != "":
				return String(raw)
	return id.capitalize()

## Dựng lại danh sách top tháp. [param rows] là mảng {id, damage} giảm dần.
func _fill_damage_rows(rows: Array) -> void:
	if not is_instance_valid(_damage_box):
		return
	# remove_child TRƯỚC queue_free — nếu không, hàng cũ còn nằm trong tree tới
	# hết frame làm layout nhảy gấp đôi số dòng.
	for child in _damage_box.get_children():
		_damage_box.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "— No damage recorded yet —"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.body(empty_lbl, 14, UIStyle.TEXT_DIM)
		_damage_box.add_child(empty_lbl)
		return
	var max_damage: int = maxi(1, int(rows[0].get("damage", 1)))
	var rank := 0
	for row in rows:
		if not (row is Dictionary):
			continue
		var id: String = str((row as Dictionary).get("id", ""))
		var damage: int = int((row as Dictionary).get("damage", 0))
		_add_damage_row(rank, id, damage, max_damage)
		rank += 1

func _add_damage_row(rank: int, id: String, damage: int, max_damage: int) -> void:
	var color: Color = RANK_COLORS[mini(rank, RANK_COLORS.size() - 1)]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_damage_box.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = "%d. %s" % [rank + 1, _tower_display_name(id)]
	name_lbl.custom_minimum_size = Vector2(170, 0)
	name_lbl.clip_text = true
	UIStyle.body(name_lbl, 15, color)
	row.add_child(name_lbl)

	var bar := UIStyle.make_bar(color, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.value = 0.0
	bar.set_meta("_ui_bar_target", 0.0)
	row.add_child(bar)

	var dmg_lbl := Label.new()
	dmg_lbl.text = "0"
	dmg_lbl.custom_minimum_size = Vector2(84, 0)
	dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.body(dmg_lbl, 15, UIStyle.TEXT)
	row.add_child(dmg_lbl)

	# Tween sau khi container sort xong → bar/label đã có kích thước đúng
	var ratio: float = clampf(float(damage) / float(maxi(1, max_damage)), 0.0, 1.0)
	var delay: float = 0.12 * float(rank)
	var tree := get_tree()
	if tree == null:
		bar.value = ratio
		dmg_lbl.text = str(damage)
		return
	tree.create_timer(delay, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(bar):
			UIStyle.tween_bar(bar, ratio, 0.7)
		if is_instance_valid(dmg_lbl):
			UIStyle.count_to(dmg_lbl, 0, damage, "%d", 0.7))

## Đọc toàn bộ số liệu cuối ván từ GameManager (guard từng field/hàm).
func _refresh_from_gm() -> void:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return
	show_stats(
		int(gm.current_wave),
		int(gm.run_enemies_killed),
		int(gm.run_gold_earned),
		int(gm.run_meta_points_earned)
	)
	var parts: Array[String] = []
	var best_combo: Variant = gm.get("run_best_combo")
	if best_combo is int or best_combo is float:
		parts.append("Best combo: %d" % int(best_combo))
	var asc: Variant = gm.get("ascension_level")
	if asc is int or asc is float:
		parts.append("Ascension: A%d" % int(asc))
	if is_instance_valid(_extra_label):
		_extra_label.text = "  ·  ".join(parts)
	var rows: Array = []
	if gm.has_method("top_towers"):
		rows = gm.top_towers(TOP_TOWER_COUNT)
	_fill_damage_rows(rows)

func _on_run_ended(is_victory: bool) -> void:
	if not is_victory:
		_refresh_from_gm()
