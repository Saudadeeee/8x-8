extends SceneTree
# Dung lai pixel_font*.tres + game_theme.tres tu file .fnt moi nhat.
# PHAI chay lai sau moi lan `python tools/make_font.py`, neu khong Godot van
# dung ban .tres cu (no la snapshot, khong tu doc lai .fnt).
#
# BA FONT CHU KHONG PHAI MOT FONT BA CO — vi sao:
#   Font bitmap khong co giai duoc. Neu chi dong goi ban 1x thi:
#     • khong khai `fixed_size` -> Godot BO QUA `font_size`, moi chu trong game
#       ve ra cung mot co, toan bo phan cap tieu de/than bai bien mat;
#     • khai `fixed_size` + de Godot tu phong -> chu NHOE (do duoc 11 mau khac
#       nhau o co 28 thay vi dung 1) VA so do glyph hong: moi ky tu deu bao
#       advance 18, ke ca chu 'a', nen bo cuc tinh theo be rong chu deu lech.
#   Da thu ca cach nhoi them cache co 28/42 vao cung MOT FontFile bang
#   `set_glyph_*` — ve ra sac net that nhung `get_string_size` tra ve rac, nen bo.
#   Cach dang dung: ba file .fnt doc lap (`make_font.py` sinh ban @2x/@3x bang
#   cach NHAN toa do, khong noi suy), moi ban nap qua `load_bitmap_font` —
#   duong da duoc kiem chung. `UIStyle.font_for()` chon font theo co yeu cau.

const VARIANTS := [
	{"suffix": "", "out": "pixel_font.tres"},
	{"suffix": "@2x", "out": "pixel_font_2x.tres"},
	{"suffix": "@3x", "out": "pixel_font_3x.tres"},
]


func _init() -> void:
	var base: FontFile = null
	var made := 0
	for v in VARIANTS:
		var f := _build(str(v["suffix"]))
		if f == null:
			print("LOI: khong nap duoc ban '%s'" % v["suffix"])
			quit(1)
			return
		if base == null:
			base = f
		var e := ResourceSaver.save(f, "res://assets/fonts/%s" % v["out"])
		if e != OK:
			print("LOI ghi %s: %d" % [v["out"], e])
			quit(1)
			return
		made += 1

	# Theme mac dinh dung ban 1x — chu than bai chiem da so man hinh.
	var th := Theme.new()
	th.default_font = base
	th.default_font_size = 14
	var e2 := ResourceSaver.save(th, "res://assets/fonts/game_theme.tres")
	print("font da ghi=%d  game_theme.tres=%d" % [made, e2])
	quit(0 if e2 == OK else 1)


func _build(suffix: String) -> FontFile:
	var path := "res://assets/fonts/pixel_8x8%s.fnt" % suffix
	if not FileAccess.file_exists(path):
		push_error("thieu %s — chay `python tools/make_font.py` truoc" % path)
		return null
	var f := FontFile.new()
	if f.load_bitmap_font(path) != OK:
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f
