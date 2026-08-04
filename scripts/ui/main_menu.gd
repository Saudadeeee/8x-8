# res://scripts/ui/main_menu.gd
extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Về menu từ một ván đang pause / chạy 3× → trả về trạng thái chuẩn
	_restore_normal_speed()
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

## Bậc Ascension cao nhất đã mở khoá — 0 nghĩa là chưa mở bậc nào.
func _highest_ascension() -> int:
	var meta := MetaProgress.load_or_create()
	if meta == null:
		return 0
	var unlocked: Variant = meta.get("ascension_unlocked")
	if unlocked is int or unlocked is float:
		return maxi(0, int(unlocked))
	return 0

func _go_to(path: String) -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm:
		sm.go_to_scene(path)
	else:
		get_tree().change_scene_to_file(path)

## Nút cổ: ưu tiên 9-patch mới trong assets/ui/panels/ (qua UIStyle); nếu chưa có
## thì dùng bộ button_*.png cũ; cuối cùng fallback StyleBoxFlat vát của UIStyle.
func _apply_ancient_button_style(btn: Button) -> void:
	UIStyle.apply_button(btn, 22, UIStyle.GOLD)
	# Nếu asset mới chưa tồn tại nhưng bộ cũ có → dùng bộ cũ cho đúng art direction
	if UIStyle.texture("btn_normal.png") != null:
		return
	var legacy := {
		"normal": "res://assets/ui/button_normal.png",
		"hover": "res://assets/ui/button_hover.png",
		"pressed": "res://assets/ui/button_pressed.png",
	}
	for state in legacy.keys():
		var path: String = legacy[state]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.set_texture_margin_all(8.0)
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		s.content_margin_left = 12.0
		s.content_margin_right = 12.0
		s.content_margin_top = 10.0
		s.content_margin_bottom = 10.0
		if state == "pressed":
			s.content_margin_top += 1.0
			s.content_margin_bottom -= 1.0
		btn.add_theme_stylebox_override(state, s)

func _build_ui() -> void:
	# Nền tối dần từ tâm (2 lớp) → tạo cảm giác sâu thay vì màu phẳng
	# Nền: gradient dọc thay cho màu phẳng. Trước đây là hai ColorRect trơn nên
	# menu trông như trang lỗi hơn là màn hình game.
	var bg = TextureRect.new()
	bg.texture = _make_menu_backdrop()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var vignette = ColorRect.new()
	vignette.color = Color(0.0, 0.0, 0.0, 0.35)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# Panel đá bọc toàn bộ menu → khối nổi trên nền
	var frame = PanelContainer.new()
	frame.name = "MenuFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.offset_left = -230
	frame.offset_top = -330
	frame.offset_right = 230
	frame.offset_bottom = 330
	UIStyle.apply_panel(frame, "stone")
	add_child(frame)

	var root_vbox = VBoxContainer.new()
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_theme_constant_override("separation", 12)
	frame.add_child(root_vbox)

	var title_tex = load("res://assets/ui/title_banner.png") as Texture2D
	if title_tex:
		var title_img = TextureRect.new()
		title_img.texture = title_tex
		title_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		title_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		title_img.custom_minimum_size = Vector2(360, 96)
		root_vbox.add_child(title_img)
		UIStyle.pop_in(title_img)
		UIStyle.breathe(title_img, 1.03, 3.0)
	else:
		var title = Label.new()
		title.text = "8×8"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.title(title, 84, UIStyle.GOLD)
		root_vbox.add_child(title)
		UIStyle.pop_in(title)
		UIStyle.breathe(title, 1.04, 3.0)

	var subtitle = Label.new()
	subtitle.text = "Chess Tower Defense · Roguelike"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(subtitle, 18, Color(0.8, 0.72, 0.5, 1))
	root_vbox.add_child(subtitle)
	UIStyle.pop_in(subtitle, 0.08)

	# Huy hiệu Ascension — chỉ hiện khi người chơi đã mở khoá ít nhất A1
	var highest_asc := _highest_ascension()
	if highest_asc > 0:
		var asc_label = Label.new()
		asc_label.text = "☠  Highest Ascension: A%d" % highest_asc
		asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.body(asc_label, 15, Color(1.0, 0.62, 0.30, 1.0))
		root_vbox.add_child(asc_label)
		UIStyle.pop_in(asc_label, 0.10)

	root_vbox.add_child(UIStyle.separator(UIStyle.BORDER_DIM))

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	root_vbox.add_child(spacer)

	var stagger := 0.14

	# Kiểm tra nếu đang có run đang chạy → hiện nút Continue
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.get("selected_king") != null:
		var continue_btn = Button.new()
		continue_btn.text = "▶  Continue"
		continue_btn.custom_minimum_size = Vector2(300, 60)
		_apply_ancient_button_style(continue_btn)
		continue_btn.pressed.connect(_go_to.bind("res://scenes/map/game_map.tscn"))
		root_vbox.add_child(continue_btn)
		UIStyle.pop_in(continue_btn, stagger)
		stagger += 0.07

	var buttons = [
		["⚔  New Run", "res://scenes/ui/king_select.tscn"],
		["★  Progress", "res://scenes/ui/meta_progression.tscn"],
		["⚙  Settings", "res://scenes/ui/settings_screen.tscn"],
		["✖  Quit", "quit"],
	]

	for entry in buttons:
		var btn = Button.new()
		btn.text = entry[0]
		btn.custom_minimum_size = Vector2(300, 60)
		_apply_ancient_button_style(btn)
		var target = entry[1]
		if target == "quit":
			btn.pressed.connect(func(): get_tree().quit())
		else:
			btn.pressed.connect(_go_to.bind(target))
		root_vbox.add_child(btn)
		UIStyle.pop_in(btn, stagger)
		stagger += 0.07

	var version_label = Label.new()
	version_label.text = "v0.1 Early Access"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(version_label, 14, Color(0.6, 0.6, 0.6, 1))
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	version_label.offset_top = -40
	add_child(version_label)

## Nền menu: gradient dọc từ nâu đất sang gần đen, cộng một dải sáng mờ ở giữa
## để tiêu đề nổi lên. Sinh bằng GradientTexture2D nên không tốn asset.
func _make_menu_backdrop() -> Texture2D:
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(0.129, 0.086, 0.055))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(0.031, 0.023, 0.019))
	grad.add_point(0.42, Color(0.180, 0.125, 0.078))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 8
	tex.height = 256
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex
