# res://scripts/ui/hud/hud_text.gd
#
# Helper chữ nghĩa dùng chung giữa các component HUD (túi thuốc, thanh di vật,
# panel tháp). Trước đây nằm rải trong game_hud.gd nên component tách ra không
# gọi lại được.
class_name HudText
extends Object

## Nhãn viết tắt cho ô vật phẩm chưa có icon: lấy chữ cái đầu mỗi từ, tối đa 4.
## "Bình Lửa Nhỏ" → "BLN". Một từ thì cắt 4 ký tự đầu.
static func short_label(data: Dictionary) -> String:
	var full: String = str(data.get("name", data.get("id", "?")))
	var initials: String = ""
	for word in full.split(" ", false):
		if word.length() > 0:
			initials += word.substr(0, 1)
	if initials.length() >= 2:
		return initials.to_upper().substr(0, 4)
	return full.to_upper().substr(0, 4)

## Cỡ + màu chữ cho Button, kèm màu trạng thái disabled/hover suy ra từ màu gốc.
static func style_button_text(button: Button, size: int, color: Color) -> void:
	if button == null:
		return
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_disabled_color", Color(color, 0.45))
	button.add_theme_color_override("font_hover_color", color.lightened(0.25))
