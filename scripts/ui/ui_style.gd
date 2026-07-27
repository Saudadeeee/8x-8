# res://scripts/ui/ui_style.gd
class_name UIStyle
extends Object

## Trung tâm hoá toàn bộ style + animation của UI game 8x-8.
## [br][br]
## Mục tiêu: UI có CHIỀU SÂU (bevel, shadow, khung khối) thay vì phẳng.
## Mọi script UI khác gọi qua đây, KHÔNG tự tạo StyleBox riêng nữa.
## [br][br]
## Toàn bộ hàm là [code]static[/code] — không cần instance.
## Texture 9-patch được guard bằng [method ResourceLoader.exists]; thiếu texture
## thì tự động fallback sang StyleBoxFlat vẽ bằng code (vẫn có khối + bóng).

# ── Palette dự án ─────────────────────────────────────────────────────────────
const EARTH        := Color(0.239, 0.169, 0.122, 1.0)  # #3d2b1f nâu đất
const STONE        := Color(0.290, 0.290, 0.290, 1.0)  # #4a4a4a xám đá
const BLOOD        := Color(0.545, 0.102, 0.102, 1.0)  # #8b1a1a đỏ máu
const BRASS        := Color(0.784, 0.627, 0.000, 1.0)  # #c8a000 vàng đồng
const MOSS         := Color(0.176, 0.290, 0.118, 1.0)  # #2d4a1e xanh rêu

# Dẫn xuất — dùng cho nền / chữ / viền
const BG_STONE     := Color(0.113, 0.109, 0.101, 0.965)
const BG_WOOD      := Color(0.098, 0.070, 0.050, 0.970)
const BG_PARCH     := Color(0.176, 0.141, 0.101, 0.980)
const BG_DARK      := Color(0.040, 0.035, 0.032, 0.980)
const BORDER_DIM   := Color(0.396, 0.325, 0.145, 1.0)
const BORDER_HI    := Color(0.784, 0.643, 0.196, 1.0)
const BORDER_STONE := Color(0.400, 0.396, 0.376, 1.0)

const GOLD         := Color(1.000, 0.840, 0.200, 1.0)
const TEXT         := Color(0.925, 0.902, 0.850, 1.0)
const TEXT_DIM     := Color(0.600, 0.560, 0.500, 1.0)
const GREEN        := Color(0.350, 0.850, 0.400, 1.0)
const RED          := Color(0.900, 0.250, 0.200, 1.0)
const BLUE         := Color(0.450, 0.720, 1.000, 1.0)
const ORANGE       := Color(1.000, 0.550, 0.100, 1.0)
const OUTLINE      := Color(0.031, 0.023, 0.019, 1.0)  # viền chữ tối → chữ nổi khối

# HUD trong trận dùng nền/viền tối và ấm hơn menu (đọc được trên bàn cờ 3D sáng).
# Để ở ĐÂY chứ không ở game_hud.gd: các component HUD (codex, boss bar, túi
# thuốc, thanh di vật…) là script riêng, cần cùng bảng màu mà KHÔNG được tham
# chiếu ngược lên GameHUD — tham chiếu vòng giữa hai class_name làm Godot
# không phân giải được kiểu.
const HUD_BG        := Color(0.070, 0.060, 0.050, 0.960)
const HUD_BG_DARK   := Color(0.040, 0.030, 0.030, 0.980)
const HUD_BORDER    := Color(0.550, 0.420, 0.120, 1.0)
const HUD_BORDER_HI := Color(0.880, 0.720, 0.200, 1.0)

## Cột King/di vật bên phải màn chơi. 160 làm "Iron Decree" bị cắt chữ.
const HUD_RIGHT_PANEL_WIDTH: int = 210

# ── Màu rarity ────────────────────────────────────────────────────────────────
const RARITY_COMMON    := Color(0.604, 0.627, 0.651, 1.0)  # #9aa0a6
const RARITY_RARE      := Color(0.290, 0.565, 0.850, 1.0)  # #4a90d9
const RARITY_EPIC      := Color(0.647, 0.353, 0.850, 1.0)  # #a55ad9
const RARITY_LEGENDARY := Color(0.878, 0.706, 0.125, 1.0)  # #e0b420

const RARITY_COLORS := {
	"common":    RARITY_COMMON,
	"rare":      RARITY_RARE,
	"epic":      RARITY_EPIC,
	"legendary": RARITY_LEGENDARY,
}

const RARITY_NAMES_VI := {
	"common": "Thường", "rare": "Hiếm", "epic": "Sử Thi", "legendary": "Huyền Thoại",
}

# ── Đường dẫn texture 9-patch (có thể CHƯA tồn tại → fallback) ────────────────
const PANEL_DIR := "res://assets/ui/panels/"

## Cấu hình từng loại panel: file texture + biên 9-patch + màu fallback.
const PANEL_SPEC := {
	"stone":     {"file": "panel_stone.png",     "margin": 8,  "bg": BG_STONE, "border": BORDER_STONE},
	"wood":      {"file": "panel_wood.png",      "margin": 8,  "bg": BG_WOOD,  "border": BORDER_DIM},
	"parchment": {"file": "panel_parchment.png", "margin": 10, "bg": BG_PARCH, "border": BORDER_HI},
	"dark":      {"file": "",                    "margin": 0,  "bg": BG_DARK,  "border": BORDER_DIM},
}

const BTN_MARGIN := 6
const FRAME_MARGIN := 8
const BAR_MARGIN := 4

# Cache texture đã thử load — tránh gọi ResourceLoader.exists mỗi frame.
# Giá trị null nghĩa là "đã kiểm tra, không có".
static var _tex_cache: Dictionary = {}

# ── Texture helpers ───────────────────────────────────────────────────────────

## Load texture trong PANEL_DIR, trả null nếu không tồn tại (đã cache).
static func texture(file_name: String) -> Texture2D:
	if file_name == "":
		return null
	if _tex_cache.has(file_name):
		return _tex_cache[file_name]
	var path := PANEL_DIR + file_name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[file_name] = tex
	return tex

## Bật NEAREST filter — bắt buộc cho pixel art, tránh bị mờ khi stretch.
static func pixel_filter(ctrl: CanvasItem) -> void:
	if is_instance_valid(ctrl):
		ctrl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Tạo StyleBoxTexture 9-patch chuẩn (stretch cả 2 trục).
static func _tex_box(tex: Texture2D, margin: int, content_pad: int = -1) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.set_texture_margin_all(float(margin))
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	var pad := margin + 2 if content_pad < 0 else content_pad
	s.content_margin_left = float(pad)
	s.content_margin_right = float(pad)
	s.content_margin_top = float(pad)
	s.content_margin_bottom = float(pad)
	return s

# ── StyleBoxFlat có khối (fallback + dùng trực tiếp) ──────────────────────────

## Panel flat "3D": viền dày hơn ở đáy (bệ đá) + shadow lệch → ra khối.
## [param shadow] nhỏ lại khi dùng cho card trong list (tránh bóng đè nhau).
static func flat(bg: Color, border: Color, radius: int = 5, shadow: int = 7) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 4          # đáy dày → cảm giác bệ nổi
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	s.shadow_size = maxi(0, shadow)
	s.shadow_offset = Vector2(2.0, 5.0) if shadow > 0 else Vector2.ZERO
	s.content_margin_left = 9.0
	s.content_margin_right = 9.0
	s.content_margin_top = 7.0
	s.content_margin_bottom = 7.0
	return s

## Panel dùng cho card trong list dọc — bóng nhẹ, padding gọn.
static func flat_card(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var s := flat(bg, border, radius, 3)
	s.shadow_offset = Vector2(1.0, 2.0)
	s.content_margin_left = 7.0
	s.content_margin_right = 7.0
	s.content_margin_top = 5.0
	s.content_margin_bottom = 5.0
	return s

## Biến thể "lõm" — dùng cho nền thanh HP/RD, ô nhập, vùng list.
static func flat_inset(bg: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 1
	s.border_width_top = 2             # top dày → bóng trong (inner shadow)
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.set_corner_radius_all(radius)
	s.content_margin_left = 2.0
	s.content_margin_right = 2.0
	s.content_margin_top = 1.0
	s.content_margin_bottom = 1.0
	return s

# ── API panel ─────────────────────────────────────────────────────────────────

## Panel theo loại: "stone" | "wood" | "parchment" | "dark".
## Dùng StyleBoxTexture nếu asset 9-patch tồn tại, ngược lại StyleBoxFlat có khối.
static func panel(kind: String = "stone") -> StyleBox:
	# Ép kiểu tường minh qua biến local — tránh truyền Variant vào tham số có kiểu.
	var spec: Dictionary = PANEL_SPEC["stone"]
	if PANEL_SPEC.has(kind):
		spec = PANEL_SPEC[kind]
	var file_name: String = str(spec.get("file", ""))
	var tex := texture(file_name)
	if tex:
		return _tex_box(tex, int(spec.get("margin", 8)))
	var bg: Color = spec.get("bg", BG_STONE)
	var border: Color = spec.get("border", BORDER_DIM)
	return flat(bg, border, 5)

## Panel nhuộm màu (ví dụ ribbon wave banner = stone nhuộm đỏ).
static func panel_tinted(kind: String, tint: Color) -> StyleBox:
	var box := panel(kind)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = tint
	elif box is StyleBoxFlat:
		var f := box as StyleBoxFlat
		f.bg_color = f.bg_color.lerp(tint, 0.55)
		f.border_color = tint.lightened(0.15)
	return box

## Áp panel cho một PanelContainer (kèm NEAREST filter).
static func apply_panel(ctrl: Control, kind: String = "stone") -> void:
	if not is_instance_valid(ctrl):
		return
	ctrl.add_theme_stylebox_override("panel", panel(kind))
	pixel_filter(ctrl)

## Ép lại padding trong của stylebox "panel" — cần cho card trong panel hẹp
## (RightPanel chỉ 160 px), nếu không khung lồng khung sẽ ăn hết chiều ngang.
static func set_pad(ctrl: Control, pad: int) -> void:
	if not is_instance_valid(ctrl):
		return
	var box := ctrl.get_theme_stylebox("panel")
	if box == null:
		return
	box.content_margin_left = float(pad)
	box.content_margin_right = float(pad)
	box.content_margin_top = float(pad)
	box.content_margin_bottom = float(pad)

# ── API button ────────────────────────────────────────────────────────────────

## 4 state StyleBox cho Button: normal / hover / pressed / disabled.
static func button_styles() -> Dictionary:
	var tn := texture("btn_normal.png")
	var th := texture("btn_hover.png")
	var tp := texture("btn_pressed.png")
	if tn:
		var normal := _tex_box(tn, BTN_MARGIN, 8)
		var hover := _tex_box(th if th else tn, BTN_MARGIN, 8)
		var pressed := _tex_box(tp if tp else tn, BTN_MARGIN, 8)
		# Pressed: dịch nội dung 1px xuống-phải → cảm giác nút lún
		pressed.content_margin_top += 1.0
		pressed.content_margin_bottom -= 1.0
		pressed.content_margin_left += 1.0
		pressed.content_margin_right -= 1.0
		var disabled := _tex_box(tn, BTN_MARGIN, 8)
		disabled.modulate_color = Color(0.55, 0.55, 0.55, 0.55)
		return {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}

	# Fallback vẽ bằng code
	var base_bg := Color(0.176, 0.145, 0.098, 1.0)
	var n := _btn_flat(base_bg, BORDER_DIM, false)
	var h := _btn_flat(base_bg.lightened(0.16), BORDER_HI, false)
	var p := _btn_flat(base_bg.darkened(0.22), BORDER_DIM, true)
	var d := _btn_flat(Color(base_bg, 0.45), Color(BORDER_DIM, 0.30), false)
	d.shadow_size = 0
	return {"normal": n, "hover": h, "pressed": p, "disabled": d}

## Nút vát: normal có đáy dày + shadow; pressed đảo bevel (top dày) + lún 1px.
static func _btn_flat(bg: Color, border: Color, is_pressed: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_corner_radius_all(3)
	if is_pressed:
		s.border_width_left = 2
		s.border_width_top = 4
		s.border_width_right = 2
		s.border_width_bottom = 1
		s.shadow_size = 0
		s.content_margin_top = 9.0
		s.content_margin_bottom = 5.0
		s.content_margin_left = 11.0
		s.content_margin_right = 9.0
	else:
		s.border_width_left = 2
		s.border_width_top = 1
		s.border_width_right = 2
		s.border_width_bottom = 4
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		s.shadow_size = 4
		s.shadow_offset = Vector2(1.0, 3.0)
		s.content_margin_top = 7.0
		s.content_margin_bottom = 7.0
		s.content_margin_left = 10.0
		s.content_margin_right = 10.0
	return s

## Áp style + hover lift + SFX cho MỌI Button do code tạo.
## Gọi nhiều lần an toàn (idempotent nhờ meta flag).
static func apply_button(btn: Button, font_size: int = 14, text_color: Color = TEXT) -> void:
	if not is_instance_valid(btn):
		return
	var st := button_styles()
	btn.add_theme_stylebox_override("normal", st["normal"])
	btn.add_theme_stylebox_override("hover", st["hover"])
	btn.add_theme_stylebox_override("pressed", st["pressed"])
	btn.add_theme_stylebox_override("disabled", st["disabled"])
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color.lightened(0.22))
	btn.add_theme_color_override("font_pressed_color", text_color.darkened(0.18))
	btn.add_theme_color_override("font_disabled_color", Color(text_color, 0.38))
	btn.add_theme_color_override("font_outline_color", OUTLINE)
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pixel_filter(btn)
	hover_lift(btn, 1.035)
	_wire_click_sfx(btn)

## Nút nhấn mạnh (xác nhận / hành động chính) — nhuộm theo accent.
static func apply_button_accent(btn: Button, accent: Color, font_size: int = 14) -> void:
	apply_button(btn, font_size, accent.lightened(0.55))
	var normal := btn.get_theme_stylebox("normal")
	if normal is StyleBoxFlat:
		var f := normal as StyleBoxFlat
		f.bg_color = Color(accent.r * 0.24, accent.g * 0.24, accent.b * 0.24, 1.0)
		f.border_color = accent
	elif normal is StyleBoxTexture:
		(normal as StyleBoxTexture).modulate_color = accent.lightened(0.35)
	var hover := btn.get_theme_stylebox("hover")
	if hover is StyleBoxFlat:
		var f2 := hover as StyleBoxFlat
		f2.bg_color = Color(accent.r * 0.38, accent.g * 0.38, accent.b * 0.38, 1.0)
		f2.border_color = accent.lightened(0.25)
	elif hover is StyleBoxTexture:
		(hover as StyleBoxTexture).modulate_color = accent.lightened(0.6)

static func _wire_click_sfx(btn: Button) -> void:
	if has_click_sfx(btn):
		return
	btn.set_meta("_ui_click_sfx", true)
	btn.pressed.connect(func() -> void: play_sfx("ui_click"))

## Kiểm tra button đã được apply_button wire SFX chưa — cho call site cũ.
static func has_click_sfx(btn: Button) -> bool:
	return is_instance_valid(btn) and btn.has_meta("_ui_click_sfx")

## Đọc meta an toàn — has_meta trước, tránh phụ thuộc overload get_meta(default).
static func _meta(node: Object, key: String, fallback: Variant) -> Variant:
	if not is_instance_valid(node) or not node.has_meta(key):
		return fallback
	return node.get_meta(key)

# ── API bar (HP / Royal Decree) ───────────────────────────────────────────────

## {"bg": lõm, "fill": có highlight top giả gradient}.
static func bar_styles(fill_color: Color = RED) -> Dictionary:
	var tbg := texture("bar_bg.png")
	var tfill := texture("bar_fill.png")
	var bg_box: StyleBox
	var fill_box: StyleBox
	if tbg:
		bg_box = _tex_box(tbg, BAR_MARGIN, 1)
	else:
		bg_box = flat_inset(Color(0.043, 0.039, 0.035, 0.95), Color(0.0, 0.0, 0.0, 0.75), 3)
	if tfill:
		var ft := _tex_box(tfill, BAR_MARGIN, 0)
		ft.modulate_color = fill_color
		fill_box = ft
	else:
		var f := StyleBoxFlat.new()
		f.bg_color = fill_color
		f.border_color = fill_color.lightened(0.45)
		f.border_width_top = 2          # dải sáng trên → giả gradient bóng
		f.border_width_left = 0
		f.border_width_right = 0
		f.border_width_bottom = 0
		f.set_corner_radius_all(2)
		fill_box = f
	return {"bg": bg_box, "fill": fill_box}

## Tạo ProgressBar đã style sẵn (không hiện %).
static func make_bar(fill_color: Color, height: int = 8) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := bar_styles(fill_color)
	bar.add_theme_stylebox_override("background", st["bg"])
	bar.add_theme_stylebox_override("fill", st["fill"])
	# Seed meta để set_bar_color / tween_bar biết trạng thái hiện tại
	bar.set_meta("_ui_bar_color", fill_color)
	bar.set_meta("_ui_bar_target", bar.value)
	pixel_filter(bar)
	return bar

## Đổi màu fill của một bar đã tạo (ví dụ HP thấp → đỏ).
## Bỏ qua nếu màu không đổi — tránh tạo StyleBox mới mỗi frame.
static func set_bar_color(bar: ProgressBar, fill_color: Color) -> void:
	if not is_instance_valid(bar):
		return
	var prev: Color = _meta(bar, "_ui_bar_color", Color(0, 0, 0, 0))
	if prev.is_equal_approx(fill_color):
		return
	bar.set_meta("_ui_bar_color", fill_color)
	var st := bar_styles(fill_color)
	bar.add_theme_stylebox_override("fill", st["fill"])

## Tween giá trị bar mượt (0..1).
## Thay đổi quá nhỏ → set thẳng, KHÔNG tạo tween (update_labels được gọi rất
## thường xuyên; nếu tween mỗi lần thì bar không bao giờ chạy tới đích).
static func tween_bar(bar: ProgressBar, ratio: float, dur: float = 0.25) -> void:
	if not is_instance_valid(bar) or not bar.is_inside_tree():
		return
	var target: float = clampf(ratio, 0.0, 1.0)
	var pending: float = _meta(bar, "_ui_bar_target", bar.value)
	if absf(pending - target) < 0.015:
		return
	bar.set_meta("_ui_bar_target", target)
	if absf(bar.value - target) < 0.02:
		bar.value = target
		return
	var t := _fresh_tween(bar, "_ui_bar_tween")
	if t == null:
		bar.value = target
		return
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(bar, "value", target, dur)

# ── API khung rarity ──────────────────────────────────────────────────────────

## Khung viền theo rarity: "common" | "rare" | "epic" | "legendary".
static func rarity_frame(rarity: String) -> StyleBox:
	var col: Color = RARITY_COLORS.get(rarity, RARITY_COMMON)
	var tex := texture("frame_gold.png")
	if tex:
		var s := _tex_box(tex, FRAME_MARGIN, FRAME_MARGIN + 1)
		s.modulate_color = col
		return s
	var f := StyleBoxFlat.new()
	f.bg_color = Color(col.r * 0.13, col.g * 0.13, col.b * 0.13, 0.96)
	f.border_color = col
	f.set_border_width_all(3)
	f.border_width_bottom = 5
	f.set_corner_radius_all(6)
	f.shadow_color = Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.42)
	f.shadow_size = 8
	f.shadow_offset = Vector2(0.0, 4.0)
	f.content_margin_left = 6.0
	f.content_margin_right = 6.0
	f.content_margin_top = 6.0
	f.content_margin_bottom = 6.0
	return f

## Màu accent của rarity (dùng cho chữ / nút bên trong card).
static func rarity_color(rarity: String) -> Color:
	if RARITY_COLORS.has(rarity):
		var col: Color = RARITY_COLORS[rarity]
		return col
	return RARITY_COMMON

## Suy ra rarity từ giá trị giá (dùng cho shop item không có field rarity).
static func rarity_from_cost(cost: float, is_premium: bool = false) -> String:
	if is_premium:
		if cost >= 18.0:
			return "legendary"
		if cost >= 9.0:
			return "epic"
		return "rare"
	if cost >= 26.0:
		return "legendary"
	if cost >= 16.0:
		return "epic"
	if cost >= 8.0:
		return "rare"
	return "common"

# ── Typography ────────────────────────────────────────────────────────────────

## Chữ tiêu đề: to, outline dày + shadow → nổi khối trên nền 3D.
static func title(label: Label, size: int, color: Color = GOLD) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(4, int(size / 7.0)))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)

## Chữ thường: outline mảnh cho dễ đọc trên texture panel.
static func body(label: Label, size: int, color: Color = TEXT) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 3)

## Icon dạng ký tự (♥ ◆ ⚡) — outline dày để trông như huy hiệu nổi.
static func glyph(label: Label, size: int, color: Color) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)

# ── SFX ───────────────────────────────────────────────────────────────────────

## Phát SFX qua autoload AudioManagerSingleton — an toàn khi autoload vắng mặt.
static func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root := (loop as SceneTree).root
	if root == null:
		return
	var am := root.get_node_or_null("AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_name, volume_db, pitch_scale)

# ── Tween helpers ─────────────────────────────────────────────────────────────

## Tạo tween mới, kill tween cũ cùng key lưu trong meta của node.
## Trả null nếu node không hợp lệ / chưa vào tree.
static func _fresh_tween(node: Node, key: String) -> Tween:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	# get_meta(key, null) VẪN báo lỗi khi thiếu key (default null == Variant() trong Godot)
	# → phải has_meta trước.
	if node.has_meta(key):
		var prev = node.get_meta(key)
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()
	var t := node.create_tween()
	node.set_meta(key, t)
	return t

## Đặt pivot về tâm — BẮT BUỘC trước mọi tween scale, nếu không sẽ lệch góc.
## Đồng thời nối [signal Control.resized] để pivot tự đúng khi container sort xong.
static func center_pivot(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size / 2.0
	if bool(_meta(node, "_ui_pivot_wired", false)):
		return
	node.set_meta("_ui_pivot_wired", true)
	node.resized.connect(func() -> void:
		if is_instance_valid(node):
			node.pivot_offset = node.size / 2.0)

# ── Animation ─────────────────────────────────────────────────────────────────

## Card/panel xuất hiện: scale 0.85→1 + fade, TRANS_BACK. delay để stagger.
static func pop_in(node: Control, delay: float = 0.0) -> void:
	if not is_instance_valid(node):
		return
	node.modulate.a = 0.0
	node.scale = Vector2(0.85, 0.85)
	center_pivot(node)
	var t := _fresh_tween(node, "_ui_pop_tween")
	if t == null:
		node.modulate.a = 1.0
		node.scale = Vector2.ONE
		return
	t.set_parallel(true)
	# Pivot phải được set lại đúng lúc bắt đầu chạy (sau khi container sort xong)
	var recenter := func() -> void:
		if is_instance_valid(node):
			node.pivot_offset = node.size / 2.0
	t.tween_callback(recenter).set_delay(delay)
	t.tween_property(node, "modulate:a", 1.0, 0.24) \
		.set_delay(delay).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.34) \
		.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Trượt vào từ offset [param from] về vị trí hiện tại (node KHÔNG trong container).
static func slide_in(node: Control, from: Vector2, dur: float = 0.28) -> void:
	if not is_instance_valid(node):
		return
	# Con của Container: vị trí do Container quyết định. Lúc gọi (thường trong _ready)
	# container CHƯA sort nên node.position vẫn (0,0) → tween sẽ GHIM node ở (0,0),
	# gây đè lên các phần tử khác. Với con của Container chỉ fade + scale.
	if node.get_parent() is Container:
		pop_in(node)
		return
	var target: Vector2 = node.get_meta("_ui_slide_target", node.position)
	node.set_meta("_ui_slide_target", target)
	node.position = target + from
	node.modulate.a = 0.0
	var t := _fresh_tween(node, "_ui_slide_tween")
	if t == null:
		node.position = target
		node.modulate.a = 1.0
		return
	t.set_parallel(true)
	t.tween_property(node, "position", target, dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "modulate:a", 1.0, dur * 0.7).set_ease(Tween.EASE_OUT)

## Phình nhẹ rồi về — dùng khi giá trị tăng / nhấn mạnh.
static func pulse(node: Control, strength: float = 1.12) -> void:
	if not is_instance_valid(node):
		return
	center_pivot(node)
	var t := _fresh_tween(node, "_ui_pulse_tween")
	if t == null:
		return
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "scale", Vector2(strength, strength), 0.09)
	t.tween_property(node, "scale", Vector2.ONE, 0.20)

## Rung ngang — dùng khi mất HP. Vị trí gốc lưu trong meta để rung lồng nhau an toàn.
static func shake(node: Control, amount: float = 6.0) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	# Container quản vị trí con → lắc position sẽ bị Container ghi đè / đè layout.
	if node.get_parent() is Container:
		pulse(node, 1.06)
		return
	var base: Vector2 = node.get_meta("_ui_shake_base", node.position)
	node.set_meta("_ui_shake_base", base)
	var t := _fresh_tween(node, "_ui_shake_tween")
	if t == null:
		return
	var steps := [
		Vector2(amount, 0.0), Vector2(-amount * 0.78, 0.0),
		Vector2(amount * 0.5, 0.0), Vector2(-amount * 0.28, 0.0),
	]
	for offset in steps:
		t.tween_property(node, "position", base + offset, 0.045)
	t.tween_property(node, "position", base, 0.055)

## Biến `root` thành MỘT vùng click liền khối.
##
## VÌ SAO CẦN: mọi Control mặc định `MOUSE_FILTER_STOP`, nên PanelContainer /
## TextureRect / SubViewportContainer nằm bên trong một card sẽ NUỐT click trước
## khi nó tới `root.gui_input`. Kết quả: chỉ dải viền mỏng quanh card là bấm
## được, người chơi phải căn chuột rất khó. Gọi hàm này SAU khi dựng xong nội
## dung card thì toàn bộ bề mặt card ăn click.
##
## Giữ nguyên các node thật sự cần chuột riêng: nút bấm, thanh trượt, ô nhập,
## vùng cuộn (cần lăn chuột). Node mới thêm vào card sau này cũng phải gọi lại.
static func make_click_target(root: Control) -> void:
	if root == null:
		return
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in root.get_children():
		_click_through(child)

static func _click_through(node: Node) -> void:
	if node is BaseButton or node is Range or node is LineEdit \
			or node is TextEdit or node is ScrollContainer:
		return   # tự xử lý chuột — đụng vào là hỏng chức năng của chúng
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_click_through(child)

## Nhấc nhẹ khi hover: scale + shadow to hơn + SFX. Tự guard tránh nối 2 lần.
static func hover_lift(node: Control, strength: float = 1.04) -> void:
	if not is_instance_valid(node):
		return
	if node.get_meta("_ui_hover_wired", false):
		return
	node.set_meta("_ui_hover_wired", true)
	node.mouse_entered.connect(func() -> void:
		if not is_instance_valid(node) or node.get_meta("_ui_hover_locked", false):
			return
		play_sfx("ui_hover", -8.0)
		_scale_to(node, Vector2(strength, strength))
		_bump_shadow(node, true))
	node.mouse_exited.connect(func() -> void:
		if not is_instance_valid(node) or node.get_meta("_ui_hover_locked", false):
			return
		_scale_to(node, Vector2.ONE)
		_bump_shadow(node, false))

## Khoá/mở hiệu ứng hover (dùng khi card đang chạy animation chọn).
static func set_hover_locked(node: Control, locked: bool) -> void:
	if is_instance_valid(node):
		node.set_meta("_ui_hover_locked", locked)

## Scale mượt về target — kill tween scale cũ để không giật.
static func _scale_to(node: Control, target: Vector2) -> void:
	center_pivot(node)
	var t := _fresh_tween(node, "_ui_scale_tween")
	if t == null:
		return
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(node, "scale", target, 0.12)

## Tăng/giảm shadow của stylebox "panel" khi hover — chỉ khi là StyleBoxFlat.
static func _bump_shadow(node: Control, up: bool) -> void:
	var box := node.get_theme_stylebox("panel")
	if not (box is StyleBoxFlat):
		return
	var f := box as StyleBoxFlat
	var base_size: int = int(node.get_meta("_ui_shadow_base", f.shadow_size))
	node.set_meta("_ui_shadow_base", base_size)
	f.shadow_size = base_size + 6 if up else base_size
	f.shadow_offset = Vector2(2.0, 8.0) if up else Vector2(2.0, 5.0)

## Số đếm chạy từ [param from] tới [param to] — tạo cảm giác phản hồi.
static func count_to(label: Label, from: int, to: int, fmt: String = "%d", dur: float = 0.32) -> void:
	if not is_instance_valid(label):
		return
	if from == to or not label.is_inside_tree():
		label.text = fmt % to
		return
	var t := _fresh_tween(label, "_ui_count_tween")
	if t == null:
		label.text = fmt % to
		return
	var setter := func(v: float) -> void:
		if is_instance_valid(label):
			label.text = fmt % int(round(v))
	var finisher := func() -> void:
		if is_instance_valid(label):
			label.text = fmt % to
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_method(setter, float(from), float(to), dur)
	t.tween_callback(finisher)

## Nháy màu chữ rồi lerp về màu gốc — feedback tăng/giảm giá trị.
static func flash_color(label: Label, flash: Color, back_to: Color, hold: float = 0.14) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", flash)
	var t := _fresh_tween(label, "_ui_flash_tween")
	if t == null:
		label.add_theme_color_override("font_color", back_to)
		return
	var blend := func(v: float) -> void:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", flash.lerp(back_to, v))
	t.tween_interval(hold)
	t.tween_method(blend, 0.0, 1.0, 0.35)

## Nháy sáng toàn node (modulate) — dùng khi chọn perk / kích ability.
static func flash_node(node: Control, times: int = 1, peak: Color = Color(1.8, 1.7, 1.3, 1.0)) -> void:
	if not is_instance_valid(node):
		return
	var t := _fresh_tween(node, "_ui_flash_node_tween")
	if t == null:
		return
	t.set_loops(maxi(1, times))
	t.tween_property(node, "modulate", peak, 0.08)
	t.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)

## Phập phồng chậm vô hạn — dùng cho tiêu đề main menu.
static func breathe(node: Control, strength: float = 1.035, period: float = 2.4) -> void:
	if not is_instance_valid(node):
		return
	center_pivot(node)
	var t := _fresh_tween(node, "_ui_breathe_tween")
	if t == null:
		return
	t.set_loops()
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2(strength, strength), period * 0.5)
	t.tween_property(node, "scale", Vector2.ONE, period * 0.5)

# ── Tiện ích layout ───────────────────────────────────────────────────────────

## Bọc nội dung trong khung rarity: trả về PanelContainer ngoài (khung)
## đã chứa PanelContainer trong (thân panel). Dùng cho card shop / perk.
## [param outer_pad] / [param inner_pad] < 0 = giữ padding mặc định của stylebox.
static func framed_card(rarity: String, inner_kind: String = "wood", outer_pad: int = -1, inner_pad: int = -1) -> Array[PanelContainer]:
	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel", rarity_frame(rarity))
	pixel_filter(outer)
	if outer_pad >= 0:
		set_pad(outer, outer_pad)
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", panel(inner_kind))
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pixel_filter(inner)
	if inner_pad >= 0:
		set_pad(inner, inner_pad)
	outer.add_child(inner)
	var result: Array[PanelContainer] = [outer, inner]
	return result

## HSeparator mảnh có màu — thay separator mặc định nhạt nhoà.
static func separator(color: Color = BORDER_DIM, thickness: int = 2) -> HSeparator:
	var sep := HSeparator.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	sep.add_theme_stylebox_override("separator", box)
	sep.add_theme_constant_override("separation", thickness + 4)
	return sep

## Overlay tối phủ full-rect — dùng làm nền popup (chặn input).
static func dim_overlay(alpha: float = 0.55) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect
