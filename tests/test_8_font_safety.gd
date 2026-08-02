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

	# ── Ba bien the font: 1x / 2x / 3x ────────────────────────────────────
	# Font bitmap khong co gian. Ba co la BA file atlas rieng. Hai kieu hong
	# da that su gap khi lam:
	#   • dong goi moi ban 1x  -> Godot bo qua font_size, ca game mot co chu;
	#   • de Godot tu phong    -> chu nhoe VA advance tra ve 18 cho MOI ky tu
	#                             (ke ca 'a'), nen moi bo cuc tinh theo be rong
	#                             chu deu lech ma khong ai thay.
	# Hai khang dinh duoi bat dung hai kieu do.
	var variants := {
		14: "res://assets/fonts/pixel_font.tres",
		28: "res://assets/fonts/pixel_font_2x.tres",
		42: "res://assets/fonts/pixel_font_3x.tres",
	}
	var bad_h := ""
	var bad_adv := ""
	var bad_cover := ""
	for sz in variants:
		var path: String = variants[sz]
		if not ResourceLoader.exists(path):
			bad_h += "thieu %s " % path
			continue
		var vf: Font = load(path)
		if absf(vf.get_height(sz) - float(sz)) > 0.5:
			bad_h += "%s cao %.0f != %d " % [path, vf.get_height(sz), sz]
		# advance phai TI LE voi co; 18-cho-moi-co la dau hieu font bi phong
		var adv: float = vf.get_string_size("a", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		if adv < float(sz) * 0.25 or adv > float(sz) * 0.75:
			bad_adv += "%s advance 'a'=%.0f o co %d " % [path, adv, sz]
		# ban phong phai phu DU glyph nhu ban goc, khong duoc rung ky tu
		for cp in [0x2605, 0xE001, 0x1EA3, 0x111]:
			if not vf.has_char(cp):
				bad_cover += "%s thieu U+%04X " % [path, cp]

	ok(bad_h == "", "ba bien the font co dung chieu cao 14/28/42", bad_h)
	ok(bad_adv == "", "advance ti le theo co (khong phai font bi phong)", bad_adv)
	ok(bad_cover == "", "ban @2x/@3x phu du glyph nhu ban goc", bad_cover)

	# UIStyle phai chon dung file cho tung co
	var pick_bad := ""
	for want in [14, 28, 42]:
		var got := UIStyle.font_for(want)
		if got == null or absf(got.get_height(want) - float(want)) > 0.5:
			pick_bad += "co %d chon sai " % want
	ok(pick_bad == "", "UIStyle.font_for() chon dung font theo co", pick_bad)

	print("\n== BATCH 8 FAIL=%d ==" % fail)
	quit()
