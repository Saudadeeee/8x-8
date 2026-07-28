extends SceneTree
# Dung lai pixel_font.tres + game_theme.tres tu file .fnt moi nhat.
# PHAI chay lai sau moi lan `python tools/make_font.py`, neu khong Godot van
# dung ban .tres cu (no la snapshot, khong tu doc lai .fnt).
func _init() -> void:
	var f := FontFile.new()
	var err := f.load_bitmap_font("res://assets/fonts/pixel_8x8.fnt")
	if err != OK:
		print("LOI nap .fnt: ", err); quit(1); return
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var e1 := ResourceSaver.save(f, "res://assets/fonts/pixel_font.tres")
	var th := Theme.new()
	th.default_font = f
	th.default_font_size = 14
	var e2 := ResourceSaver.save(th, "res://assets/fonts/game_theme.tres")
	print("pixel_font.tres=%d  game_theme.tres=%d  glyph=%d" % [e1, e2, 0])
	quit(0 if (e1 == OK and e2 == OK) else 1)
