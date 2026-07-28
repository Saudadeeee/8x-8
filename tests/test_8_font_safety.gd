extends SceneTree
# BATCH 8 — font pixel tu ve phai phu MOI ky tu game dung.
#
# Loi nay VO HINH tren Windows: Godot tu muon font he thong khi font chinh thieu
# glyph, nen chu van hien. Export sang Linux/macOS moi lo ra o vuong rong.
# Test do bang HAI cach vi has_char() mot minh khong du:
#   1. has_char() — font co khai glyph khong
#   2. advance — ky tu co thuoc tinh Emoji_Presentation bi TextServer EP sang
#      font emoji he thong du font minh co glyph. Do duoc: rong 19px thay vi <=7.
var fail := 0
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1

func _scan(path: String, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null: return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var full := path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."): _scan(full, out)
		elif f.ends_with(".gd"):
			out.append(full)
		f = d.get_next()
	d.list_dir_end()

func _run() -> void:
	await process_frame
	var theme: Theme = load("res://assets/fonts/game_theme.tres")
	ok(theme != null, "co theme du an")
	var font: Font = theme.default_font if theme else null
	ok(font != null, "theme co font mac dinh", font.get_font_name() if font else "")
	if font == null:
		print("\n== BATCH 8 FAIL=%d ==" % fail); quit(); return

	ok(ProjectSettings.get_setting("gui/theme/custom", "") != "",
		"project.godot da tro toi theme",
		str(ProjectSettings.get_setting("gui/theme/custom", "")))

	# Tieng Viet
	var vn := "ăâđêôơưÀÁẢÃẠẰẮẲẴẶẦẤẨẪẬÈÉẺẼẸỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌỒỐỔỖỘỜỚỞỠỢÙÚỦŨỤỪỨỬỮỰỲÝỶỸỴĐ"
	vn += "àáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ"
	var vn_miss := ""
	for c in vn:
		if not font.has_char(c.unicode_at(0)): vn_miss += c
	ok(vn_miss == "", "font du dau tieng Viet (%d ky tu)" % vn.length(), vn_miss)

	# Quet moi ky tu ngoai ASCII trong chuoi cua .gd
	var files: Array = []
	_scan("res://scripts", files)
	var missing := {}
	var forced := {}
	for path in files:
		if path.ends_with("glyphs.gd"): continue
		var fa := FileAccess.open(path, FileAccess.READ)
		if fa == null: continue
		while not fa.eof_reached():
			var line := fa.get_line()
			if line.strip_edges().begins_with("#"): continue
			var in_str := false
			for i in line.length():
				var ch := line[i]
				if ch == '"':
					in_str = not in_str
					continue
				if not in_str: continue
				var cp := ch.unicode_at(0)
				if cp < 128: continue
				if not font.has_char(cp):
					missing[ch] = true
					continue
				# Ky tu font CO nhung bi ep sang font emoji he thong
				var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				if w > 9.0: forced[ch] = true
		fa.close()

	ok(missing.is_empty(), "khong ky tu nao font THIEU", str(missing.keys()))
	ok(forced.is_empty(),
		"khong ky tu nao bi EP sang font emoji he thong", str(forced.keys()))

	# PUA phai dung font minh
	var pua_bad := ""
	for cp in range(0xE001, 0xE011):
		var w: float = font.get_string_size(char(cp), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		if not font.has_char(cp) or w > 9.0: pua_bad += "U+%04X " % cp
	ok(pua_bad == "", "16 ky hieu PUA deu dung font minh", pua_bad)

	print("\n== BATCH 8 FAIL=%d ==" % fail)
	quit()
