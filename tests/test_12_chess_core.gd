extends SceneTree
# BATCH 12 — TRUC MOI: nuoc di quan co, the co, Nen x Boi, bo quan, luat Vua.
#
# Day la bo test cua thiet ke Balatro-hoa. Moi khang dinh o day bao ve mot y
# dinh thiet ke chu khong phai mot chi tiet ky thuat:
#   • quan phai danh theo LUAT CO (khong phai ban kinh) — neu khong thi vi tri
#     dat quan lai tro thanh vo nghia nhu ban cu;
#   • o ban co phai KHAN HIEM — do duoc bot rai 106 thap ma chua het cho;
#   • cong thuc phai la MOT so so voi MOT so, va ti le 1.0 phai la ranh gioi.
var fail := 0
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1


func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	if gm.meta_progress: gm.meta_progress.seen_tutorial = true
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	if map == null:
		print("FATAL: khong dung duoc game_map"); quit(); return
	for _i in 25:
		await process_frame
	var gc = map.grid_controller

	print("\n--- NUOC DI QUAN CO ---")
	var K = ChessPattern.Kind
	var o := Vector2i(4, 4)

	# Xe: chi doc hang/cot, khong cheo
	ok(ChessPattern.covers(K.ROOK, o, Vector2i(4, 7), 5), "Xe voi doc cot")
	ok(ChessPattern.covers(K.ROOK, o, Vector2i(7, 4), 5), "Xe voi doc hang")
	ok(not ChessPattern.covers(K.ROOK, o, Vector2i(6, 6), 5), "Xe KHONG voi cheo")
	# Tuong: nguoc lai
	ok(ChessPattern.covers(K.BISHOP, o, Vector2i(6, 6), 5), "Tuong voi cheo")
	ok(not ChessPattern.covers(K.BISHOP, o, Vector2i(4, 6), 5), "Tuong KHONG voi doc")
	# Ma: dung 8 o chu L, va KHONG bi chan
	ok(ChessPattern.covers(K.KNIGHT, o, Vector2i(6, 5), 5), "Ma nhay chu L")
	ok(not ChessPattern.covers(K.KNIGHT, o, Vector2i(5, 5), 5), "Ma KHONG danh o ke")
	ok(ChessPattern.cells(K.KNIGHT, o, 5).size() == 8, "Ma phu dung 8 o")
	# Tot: 4 o cheo ke
	ok(ChessPattern.cells(K.PAWN, o, 5).size() == 4, "Tot phu dung 4 o")
	# Cong thanh: co tam TOI THIEU
	ok(not ChessPattern.covers(K.SIEGE, o, Vector2i(5, 4), 5),
		"Cong thanh KHONG danh duoc sat minh")
	ok(ChessPattern.covers(K.SIEGE, o, Vector2i(7, 4), 5), "Cong thanh danh xa duoc")

	# CHAN: quan cua minh cat duong truot. Day la rang buoc tao ra cau do xep hinh.
	var blocked := {Vector2i(4, 5): true}
	ok(not ChessPattern.covers(K.ROOK, o, Vector2i(4, 7), 5, blocked),
		"quan dung chan cat duong truot cua Xe")
	ok(ChessPattern.covers(K.KNIGHT, o, Vector2i(6, 5), 5, blocked),
		"nhung KHONG chan duoc Ma (Ma nhay qua)")

	print("\n--- MOI QUAN PHAI KHAI NUOC DI ---")
	var d := DirAccess.open("res://res/towers/")
	var no_pattern := ""
	var radial := 0
	for f in d.get_files():
		var cn := f.trim_suffix(".remap")
		if not cn.ends_with(".tres"): continue
		var st := load("res://res/towers/" + cn) as TowerStats
		if st == null: continue
		if not ("attack_pattern" in st):
			no_pattern += st.id + " "
		elif int(st.attack_pattern) == K.RADIAL:
			radial += 1
	ok(no_pattern == "", "moi quan co field attack_pattern", no_pattern)
	ok(radial == 0, "khong quan nao con dung ban kinh (RADIAL)", "%d quan" % radial)

	print("\n--- BAN CO KHAN HIEM ---")
	ok(gc.grid_width == 8 and gc.grid_height == 8, "ban khoa o 8x8",
		"%dx%d" % [gc.grid_width, gc.grid_height])
	ok(map.EXPAND_EVERY_N_WAVES == 0, "khong con mo rong ban do")
	var cap: int = map.max_units()
	ok(cap > 0 and cap < 64, "co tran so quan va tran nho hon so o", "%d/64" % cap)

	# Ep dat qua tran: phai bi tu choi
	var pawn: TowerStats = load("res://res/towers/pawn.tres")
	var placed := 0
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if gc.is_path_cell(c) or gc.grid_data.has(c): continue
			map.shop_manager.register_troop_purchase(pawn)
			map.tower_placer.start_build(pawn)
			map.tower_placer.place(c)
			map.tower_placer.cancel_build()
			if gc.grid_data.get(c) != null: placed += 1
	await process_frame
	var on_board: int = get_nodes_in_group("towers").size()
	ok(on_board <= map.max_units(), "tran so quan duoc THI HANH",
		"%d <= %d" % [on_board, map.max_units()])

	print("\n--- NEN x BOI ---")
	var s: Dictionary = map.board_summary()
	ok(not s.is_empty(), "co bang Nen x Boi")
	ok(float(s.get("threshold", 0.0)) > 0.0, "nguong wave la MOT CON SO",
		"%.0f" % float(s.get("threshold", 0.0)))
	ok(float(s.get("damage", 0.0)) > 0.0, "doi hinh co sat thuong > 0",
		"%.0f" % float(s.get("damage", 0.0)))
	ok(s.has("ratio") and s.has("ok"), "co ti le va co cho biet du hay thieu",
		"ti le=%.2f du=%s" % [float(s.get("ratio", 0)), str(s.get("ok"))])

	# Quan KHONG phu o duong nao thi khong dong gop — day la y dinh thiet ke,
	# khong phai loi: vi tri phai co gia tri.
	var bs = map.board_score
	var far_dmg := 0.0
	for t in get_nodes_in_group("towers"):
		if bs.path_cells_covered(t) == 0:
			far_dmg += bs.tower_wave_damage(t, 10, 2.0, 15.0)
	ok(is_zero_approx(far_dmg), "quan khong phu o duong nao thi gay 0 sat thuong")

	print("\n--- THE CO ---")
	var cf = map.chess_formations
	ok(cf != null, "co he the co")
	# Dat 2 Xe cung cot -> Tran Phao
	# Don ban: phai xoa CA entry trong grid_data, khong chi queue_free node —
	# bo sot thi vong lap sau doc phai instance da giai phong va nem loi runtime.
	for cell in gc.grid_data.keys():
		var v = gc.grid_data[cell]
		if v is Node3D and is_instance_valid(v):
			gc.grid_data.erase(cell)
			v.queue_free()
	await process_frame
	await process_frame
	Tower.bump_layout(self)
	var rook: TowerStats = load("res://res/towers/rook.tres")
	var col_cells: Array[Vector2i] = []
	for y in range(gc.grid_height):
		var c := Vector2i(0, y)
		if not gc.is_path_cell(c) and not gc.grid_data.has(c):
			col_cells.append(c)
		if col_cells.size() >= 2: break
	if col_cells.size() >= 2:
		for c in col_cells:
			map.shop_manager.register_troop_purchase(rook)
			map.tower_placer.start_build(rook)
			map.tower_placer.place(c)
			map.tower_placer.cancel_build()
		await process_frame
		await process_frame
		cf.recount()
		ok(cf.counts().has("battery"), "hai Xe cung cot -> Tran Phao",
			str(cf.counts()))
		var boost: float = cf.mult_at(col_cells[0])
		ok(boost > 1.0, "the co lam tang BOI tai o do", "x%.2f" % boost)

	print("\n--- BO QUAN ---")
	var deck = map.army_deck
	ok(deck != null, "co bo quan")
	var n0: int = deck.size()
	ok(n0 > 0, "bo co quan", "%d" % n0)
	var before_rook: float = deck.draw_chance("rook")
	# Xoa bot Tot -> ti le rut Xe phai TANG. Day la nuoc di chien thuat sau nhat
	# cua mo hinh nay; khong dung thi "loai quan khoi bo" thanh vo nghia.
	var thinned := false
	for _i in 3:
		if deck.remove_unit("pawn", 1): thinned = true
	if thinned:
		ok(deck.draw_chance("rook") > before_rook,
			"loai quan khoi bo lam TANG ti le rut quan con lai",
			"%.0f%% -> %.0f%%" % [before_rook * 100.0, deck.draw_chance("rook") * 100.0])
	ok(not deck.remove_unit("nonexistent_unit", 1), "khong xoa duoc quan khong co")
	var st_before: int = deck.star_of("rook")
	ok(deck.upgrade_star("rook") and deck.star_of("rook") == st_before + 1,
		"nang sao vinh vien cho mot loai quan")
	# San: khong tu khoa duoc
	var guard := 0
	while deck.size() > deck.MIN_DECK_SIZE and guard < 60:
		guard += 1
		var ids: Array = deck.counts().keys()
		if ids.is_empty() or not deck.remove_unit(str(ids[0]), 1): break
	ok(deck.size() >= deck.MIN_DECK_SIZE, "co SAN bo quan, khong tu khoa duoc",
		"%d >= %d" % [deck.size(), deck.MIN_DECK_SIZE])

	print("\n--- LUAT RIVAL KING ---")
	var kr = map.king_rules
	ok(kr != null, "co he luat Rival King")
	kr.clear()
	ok(not kr.is_active(), "ngoai wave boss thi khong co luat")
	kr.activate_for_boss(0)
	ok(kr.is_active() and kr.rule_name() != "", "wave boss bat mot luat",
		kr.rule_name())
	# Moi luat phai LAM GI DO — im lang la loi "tinh nang chet" quen thuoc.
	var dead_rules := ""
	for i in KingRules.ORDER.size():
		kr.activate_for_boss(i)
		var touched := false
		for pk in [K.ROOK, K.BISHOP, K.QUEEN, K.KNIGHT, K.PAWN]:
			if kr.silences(pk): touched = true
		for c in [Vector2i(0, 0), Vector2i(7, 7)]:
			if not is_equal_approx(kr.cell_mult(c), 1.0): touched = true
		if kr.no_stack() or kr.extra_places() > 0 \
				or not is_equal_approx(kr.enemy_speed_mult(), 1.0):
			touched = true
		if not touched:
			dead_rules += str(KingRules.ORDER[i]) + " "
	ok(dead_rules == "", "moi luat Rival King deu co tac dung that", dead_rules)
	kr.clear()

	print("
--- UI PHAI DOC DUOC CONG THUC ---")
	# Cong thuc chi co gia tri khi NHIN THAY duoc. Balatro song nho viec hien tung
	# la cong bao nhieu Chip, tung Joker nhan bao nhieu — thieu lop hien thi thi
	# "Nen x Boi" chi la mot con so vo nghia.
	var hud = map.get_node_or_null("HUD")
	ok(hud != null, "co HUD")
	for m in ["update_board_score", "show_cell_tooltip", "hide_cell_tooltip",
			"toggle_deck_panel", "show_king_rule", "set_start_wave_button_visible"]:
		ok(hud.has_method(m), "HUD co %s()" % m)

	# Tooltip phai tra ve DU ca hai nua: tung nguon NEN va tung nguon BOI.
	var tip_cell := Vector2i(-1, -1)
	for c in gc.current_path_grid:
		if bs.cell_base(c) > 0.01:
			tip_cell = c
			break
	if tip_cell.x >= 0:
		var info: Dictionary = map.cell_score_info(tip_cell)
		ok(info.has("base") and info.has("mult") and info.has("score"),
			"tooltip co du Nen / Boi / Diem")
		ok((info.get("base_rows", []) as Array).size() > 0,
			"tooltip liet ke duoc tung quan gop vao NEN")
		ok(bool(info.get("on_path", false)), "o duong duoc danh dau la o duong")

	ok(map.get("chess_formation_overlay") != null, "co overlay to sang the co")

	# Tutorial phai day GAME HIEN TAI, khong phai game da bo.
	var tut_src := FileAccess.get_file_as_string("res://scripts/ui/tutorial_overlay.gd")
	var tut_missing := ""
	# So khong phan biet hoa thuong: the tutorial viet "nuoc di thật" o giua cau.
	var tut_low := tut_src.to_lower()
	for kw in ["nước đi", "thế cờ", "bộ quân", "bắt đầu wave"]:
		if not tut_low.contains(kw):
			tut_missing += kw + " "
	ok(tut_missing == "", "tutorial nhac du cac tru moi", tut_missing)
	ok(not tut_src.contains("mở rộng thêm một hướng"),
		"tutorial khong con day mo rong ban do (da bo)")

	print("\n--- HE DA CAT ---")
	ok(not FeatureFlags.SEASONS_ENABLED, "mua da tat")
	ok(not FeatureFlags.BIOME_CLIMATE_ENABLED, "khi hau biome da tat")
	ok(not FeatureFlags.UNIT_SYNERGY_ENABLED, "synergy loai quan da tat")
	ok(not FeatureFlags.SPECIAL_TILES_ENABLED, "o Phuoc/Nguyen da tat")
	# ...nhung cac he VAO DUOC cong thuc phai con song
	ok(FeatureFlags.ELEMENT_TILES_ENABLED, "o nguyen to VAN BAT (no cho NEN)")
	ok(FeatureFlags.RELICS_ENABLED, "di vat VAN BAT (no la Joker)")

	print("\n== BATCH 12 FAIL=%d ==" % fail)
	quit()
