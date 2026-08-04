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
	ok(ChessPattern.covers(K.KNIGHT, o, Vector2i(6, 5), 1), "Ma nhay chu L")
	ok(not ChessPattern.covers(K.KNIGHT, o, Vector2i(5, 5), 1), "Ma KHONG danh o ke")
	# TAM = SO VONG: tam 1 la mot vong (8 o chu L), tam 2 la hai vong (16 o).
	ok(ChessPattern.cells(K.KNIGHT, o, 1).size() == 8, "Ma tam 1 phu dung 8 o")
	ok(ChessPattern.cells(K.KNIGHT, o, 2).size() == 16, "Ma tam 2 phu 16 o (hai vong)")
	# Tot: 4 o cheo ke
	ok(ChessPattern.cells(K.PAWN, o, 1).size() == 4, "Tot tam 1 phu dung 4 o")
	ok(ChessPattern.cells(K.PAWN, o, 3).size() == 12, "Tot tam 3 phu 12 o (ba vong)")
	# Cong thanh: co tam TOI THIEU
	ok(not ChessPattern.covers(K.SIEGE, o, Vector2i(5, 4), 5),
		"Cong thanh KHONG danh duoc sat minh")
	ok(ChessPattern.covers(K.SIEGE, o, Vector2i(7, 4), 5), "Cong thanh danh xa duoc")

	# CHAN: quan cua minh cat duong truot. Day la rang buoc tao ra cau do xep hinh.
	var blocked := {Vector2i(4, 5): true}
	ok(not ChessPattern.covers(K.ROOK, o, Vector2i(4, 7), 5, blocked),
		"quan dung chan cat duong truot cua Xe")
	ok(ChessPattern.covers(K.KNIGHT, o, Vector2i(6, 5), 1, blocked),
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

	# MOI lan tu choi dat quan phai NOI RA LY DO. `push_warning` chi ra console —
	# voi nguoi choi thi cu click bien mat khong dau vet, va trieu chung giong
	# het "game hong". Ba ngo cut im lang da co: thieu Sac Lenh, het kho, va o
	# da co quan khac loai. Lambda GDScript bat bien local theo GIA TRI nen phai
	# dung Array (object, bat theo tham chieu).
	var said: Array[String] = []
	map.tower_placer.place_rejected.connect(func(r: String): said.append(r))
	# DON BAN truoc: phan test tren vua rai day quan toi tran, ma tran BAN TRUOC
	# hai nhanh can kiem => test se xanh vi ly do sai.
	for cell in gc.grid_data.keys():
		var vv = gc.grid_data[cell]
		if vv is Node3D and is_instance_valid(vv):
			gc.grid_data.erase(cell)
			vv.queue_free()
	await process_frame
	await process_frame
	Tower.bump_layout(self)
	var free_cell := Vector2i(-1, -1)
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if not gc.is_path_cell(c) and not (gc.grid_data.get(c) is Node):
				free_cell = c
				break
		if free_cell.x >= 0: break

	# (a) het kho: dung stats KHONG co trong kho
	said.clear()
	var ghost_stats: TowerStats = load("res://res/towers/queen.tres")
	map.shop_manager.register_troop_purchase(ghost_stats)
	map.shop_manager.consume_unit_stock(ghost_stats.id)   # dang ky roi rut sach
	if map.king_manager: map.king_manager.add_royal_decree(99.0)
	map.tower_placer.start_build(ghost_stats)
	if free_cell.x >= 0: map.tower_placer.place(free_cell)
	map.tower_placer.cancel_build()
	ok(said.size() > 0 and said[0].to_lower().contains("reserve"),
		"het quan trong kho -> BAO DUNG ly do",
		said[0] if said.size() > 0 else "(im lang)")

	# (b) thieu Sac Lenh
	said.clear()
	if map.king_manager:
		map.king_manager.royal_decree = 0.0
		map.shop_manager.register_troop_purchase(ghost_stats)
		map.tower_placer.start_build(ghost_stats)
		if free_cell.x >= 0: map.tower_placer.place(free_cell)
		map.tower_placer.cancel_build()
		ok(said.size() > 0 and said[0].to_lower().contains("decree"),
			"thieu Sac Lenh -> BAO DUNG ly do",
			said[0] if said.size() > 0 else "(im lang)")
		map.king_manager.add_royal_decree(99.0)

	# Dat lai vai quan: phan Nen x Boi ngay duoi do sat thuong cua doi hinh,
	# ban trong thi no bang 0 va assert do that bai vi ly do khong lien quan.
	for _i in 4:
		var c2 := Vector2i(-1, -1)
		for y in range(gc.grid_height):
			for x in range(gc.grid_width):
				var cc := Vector2i(x, y)
				if not gc.is_path_cell(cc) and not (gc.grid_data.get(cc) is Node):
					c2 = cc
					break
			if c2.x >= 0: break
		if c2.x < 0: break
		map.shop_manager.register_troop_purchase(pawn)
		map.tower_placer.start_build(pawn)
		map.tower_placer.place(c2)
		map.tower_placer.cancel_build()
		await process_frame

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
	for kw in ["chess rules", "formation", "your set", "start wave"]:
		if not tut_low.contains(kw):
			tut_missing += kw + " "
	ok(tut_missing == "", "tutorial nhac du cac tru moi", tut_missing)
	ok(not tut_src.contains("mở rộng thêm một hướng"),
		"tutorial khong con day mo rong ban do (da bo)")

	print("
--- DI VAT CHAM VAO CONG THUC ---")
	# Lop noi dung kieu Joker: moi mon sua CACH TINH, khong chi cong mot con so.
	# Kiem tung mon phai LAM DOI gi do — mot lan da dinh: `_sanitize` loc trang
	# khoa hieu ung, 6 khoa moi bi VUT im lang nen ca 8 di vat mua duoc, hien mo
	# ta day du, ma khong lam gi ca.
	var rs = map.relic_system
	ok(rs != null, "co he di vat")
	var chess_relics: Array[String] = []
	for rid in rs.all_ids():
		if str(rid).begins_with("chess_"):
			chess_relics.append(str(rid))
	ok(chess_relics.size() >= 6, "co it nhat 6 di vat cham cong thuc",
		"%d mon" % chess_relics.size())

	# Moi khoa hieu ung phai nam trong danh sach trang, neu khong no bi vut.
	var key_missing := ""
	for k in ["formation_mult_bonus", "variety_mult", "endgame_mult",
			"knight_reach", "pierce_count", "pawn_tithe"]:
		if not RelicSystem.EFFECT_KEYS.has(k):
			key_missing += k + " "
	ok(key_missing == "", "moi khoa moi nam trong EFFECT_KEYS", key_missing)

	# ...va effect sau khi sanitize phai KHONG RONG
	var empty_eff := ""
	for rid in chess_relics:
		var eff: Dictionary = rs.relic_data(rid).get("effect", {})
		if eff.is_empty():
			empty_eff += rid + " "
	ok(empty_eff == "", "khong di vat nao bi vut sach hieu ung", empty_eff)

	# XUYEN QUAN la THANG DO, khong phai cong tac.
	# Do duoc: chan lam mat 0% tam phu voi 4 quan nhung 49% voi 22 quan; xuyen 1
	# lay lai phan lon, xuyen 2 chi them ~7%, vo han hon xuyen 2 khong dang ke.
	# Mot di vat "xuyen het" vi vay vua vo dung luc dau vua khong co bac nao —
	# no XOA luat chan thay vi NOI, ma luat chan chinh la cau do dat quan.
	var blk := {Vector2i(4, 5): true, Vector2i(4, 6): true}
	ok(not ChessPattern.covers(ChessPattern.Kind.ROOK, Vector2i(4, 4), Vector2i(4, 7), 5, blk, 0),
		"xuyen 0: bi chan (luat co chuan)")
	ok(not ChessPattern.covers(ChessPattern.Kind.ROOK, Vector2i(4, 4), Vector2i(4, 7), 5, blk, 1),
		"xuyen 1: van bi chan boi quan THU HAI")
	ok(ChessPattern.covers(ChessPattern.Kind.ROOK, Vector2i(4, 4), Vector2i(4, 7), 5, blk, 2),
		"xuyen 2: qua duoc ca hai quan")
	# O co quan dung KHONG duoc tinh la phu — dich khong dung do duoc.
	var pierced := ChessPattern.cells(ChessPattern.Kind.ROOK, Vector2i(4, 4), 5, blk, 2)
	ok(not pierced.has(Vector2i(4, 5)) and not pierced.has(Vector2i(4, 6)),
		"o co quan dung khong nam trong tam phu du da xuyen qua")
	# Va KHONG con di vat nao xoa hai luat chan
	var d3 := DirAccess.open("res://res/relics/")
	var absolute := ""
	for f in d3.get_files():
		var cn3 := f.trim_suffix(".remap")
		if not cn3.ends_with(".tres"): continue
		var rdd = load("res://res/relics/" + cn3)
		if rdd == null: continue
		var e3: Dictionary = rdd.effect if "effect" in rdd else {}
		if e3.has("ignore_block"):
			absolute += str(rdd.id) + " "
		if int(e3.get("pierce_count", 0)) > 3:
			absolute += str(rdd.id) + "(xuyen qua nhieu) "
	ok(absolute == "", "khong di vat nao XOA han luat chan", absolute)
	# Knight_reach: vong chu L xa phai la 8 o KHAC voi 8 o goc
	var near := ChessPattern.KNIGHT_STEPS
	var far := ChessPattern.KNIGHT_FAR
	ok(far.size() == 8, "co 8 buoc nhay chu L xa")
	var overlap := 0
	for st2 in far:
		if near.has(st2): overlap += 1
	ok(overlap == 0, "buoc xa khong trung buoc gan", "%d trung" % overlap)

	print("
--- LOI DA SUA (chong tai phat) ---")
	# 1. O lanh tho khoi dau: `initialize` tung duyet `grid_data.keys()`, ma dict
	#    do CHI chua o duong va o co quan — o trong khong bao gio la khoa. Nen
	#    `KingStats.starting_territory_count` la so CHET tu commit dau tien: moi
	#    vua khai 3-5 o ma thuc te nhan 0. Game van chay nen khong ai thay.
	var tm = map.territory_manager
	var king_now: KingStats = gm.selected_king
	var want_tiles: int = int(king_now.starting_territory_count) if king_now else 0
	ok(tm.owned_tiles.size() >= want_tiles,
		"o lanh tho khoi dau duoc cap DUNG so vua khai",
		"%d/%d" % [tm.owned_tiles.size(), want_tiles])
	ok(tm.biome_tiles.size() == tm.owned_tiles.size(),
		"moi o so huu deu co nguyen to")

	# 2. Hai signal tung emit ma KHONG AI NGHE — cham tran quan thi im lang,
	#    panel bo quan khong tu cap nhat. Ca hai deu la loi trai nghiem cam.
	ok(map.tower_placer.place_rejected.get_connections().size() > 0,
		"place_rejected co nguoi nghe (cham tran quan phai bao ly do)")
	ok(map.army_deck.deck_changed.get_connections().size() > 0,
		"deck_changed co nguoi nghe (panel bo tu cap nhat)")

	# 3. Wave boss phai tinh CA CON BOSS vao nhom dich. Bo quen thi cong suat
	#    tut 83% o dung wave boss — do duoc 9490 -> 1657 giua wave 8 va 9.
	var ws2 = map.wave_spawner
	var boss_w: int = int(WaveSpawner.BOSS_WAVES[0])
	var groups: Array = bs.enemy_groups(boss_w)
	var slowest := 99.0
	for g in groups:
		if g is Dictionary:
			slowest = minf(slowest, float((g as Dictionary).get("speed", 99.0)))
	ok(groups.size() >= 2, "wave boss co nhieu hon mot nhom dich",
		"%d nhom" % groups.size())
	ok(slowest < 1.2, "nhom cham nhat la con boss (no o tren ban rat lau)",
		"%.2f o/giay" % slowest)

	# 4. Wave boss: thua boss la thua NGAY (boss_escaped), khong lien quan mau Vua.
	#    Nen nguong phai co nhanh so RIENG con boss.
	ok(bs.damage_to_boss(boss_w) >= 0.0, "tinh duoc sat thuong len rieng boss")
	ok(bs._boss_hp_only(boss_w) > 0.0, "doc duoc mau rieng cua boss",
		"%.0f" % bs._boss_hp_only(boss_w))

	print("
--- NUOC DI MUON TU CAC LOAI CO KHAC ---")
	var o2 := Vector2i(4, 4)
	# PHAO (co tuong) — luat DAO NGUOC: phai co DUNG MOT quan lam ngoi.
	# Ca game day "quan minh chan duong la xau"; Phao lat nguoc lai.
	ok(not ChessPattern.covers(K.CANNON, o2, Vector2i(4,7), 5, {}),
		"Phao KHONG ban duoc khi khong co ngoi")
	var scr := {Vector2i(4,5): true}
	ok(ChessPattern.covers(K.CANNON, o2, Vector2i(4,7), 5, scr),
		"Phao ban duoc khi co DUNG 1 ngoi")
	ok(not ChessPattern.covers(K.CANNON, o2, Vector2i(4,5), 5, scr),
		"Phao KHONG ban duoc chinh o co ngoi")
	ok(not ChessPattern.covers(K.CANNON, o2, Vector2i(4,7), 5,
		{Vector2i(4,5): true, Vector2i(4,6): true}), "hai ngoi thi Phao tac")
	ok(ChessPattern.cells(K.CANNON, o2, 5, {}).size() == 0,
		"Phao tren ban trong phu 0 o")
	# HUONG XA (shogi) — mot huong
	ok(ChessPattern.covers(K.LANCE, o2, Vector2i(4,7), 7, {}), "Huong Xa ban xuoi")
	ok(not ChessPattern.covers(K.LANCE, o2, Vector2i(4,1), 7, {}), "Huong Xa KHONG ban nguoc")
	# KIM TUONG (shogi) — 6 o bat doi xung
	ok(ChessPattern.cells(K.GOLD, o2, 1, {}).size() == 6, "Kim Tuong tam 1 phu dung 6 o")
	ok(not ChessPattern.covers(K.GOLD, o2, Vector2i(5,3), 1, {}), "Kim Tuong KHONG danh cheo sau")
	# TUONG co tuong — cheo dung 2 o, CAN TAM
	ok(ChessPattern.covers(K.XIANG, o2, Vector2i(6,6), 5, {}), "Tuong Dien nhay cheo 2 o")
	ok(not ChessPattern.covers(K.XIANG, o2, Vector2i(6,6), 5, {Vector2i(5,5): true}),
		"Tuong Dien bi CAN TAM")

	print("
--- DI VAT DOI LUAT ---")
	var rs2 = map.relic_system
	var rule_relics: Array[String] = []
	for rid2 in rs2.all_ids():
		if str(rid2).begins_with("rl_"):
			rule_relics.append(str(rid2))
	ok(rule_relics.size() >= 8, "co it nhat 8 di vat doi luat",
		"%d mon" % rule_relics.size())
	var empty2 := ""
	for rid3 in rule_relics:
		if (rs2.relic_data(rid3).get("effect", {}) as Dictionary).is_empty():
			empty2 += rid3 + " "
	ok(empty2 == "", "khong di vat doi luat nao bi _sanitize vut sach", empty2)
	# -1 la "khong doi"; 0 KHONG duoc dung lam co tat vi 0 = Kind.ROOK hop le
	ok(gm.relic_pawn_pattern == -1 or gm.relic_pawn_pattern >= 0,
		"relic_pawn_pattern dung -1 lam 'khong doi'")

	print("
--- BO KHAI CUOC ---")
	var decks := ArmyDeck.all_decks()
	ok(decks.size() >= 5, "co it nhat 5 Bo Khai Cuoc", "%d bo" % decks.size())
	var deck_bad := ""
	var origins := {}
	for dk in decks:
		if dk.deck.is_empty():
			deck_bad += str(dk.id) + "(rong) "
		var tot := 0
		for kk in dk.deck: tot += int(dk.deck[kk])
		if tot < 4:
			deck_bad += str(dk.id) + "(qua it quan) "
		origins[str(dk.origin)] = true
	ok(deck_bad == "", "moi bo co du quan", deck_bad)
	ok(origins.size() >= 3, "cac bo trai it nhat 3 loai co",
		", ".join(PackedStringArray(origins.keys())))
	# Luat cua bo phai dung CHUNG khoa voi di vat — neu khong phai viet he thu hai
	var rule_bad := ""
	for dk2 in decks:
		for rk in dk2.rule:
			if not RelicSystem.EFFECT_KEYS.has(str(rk)):
				rule_bad += "%s:%s " % [dk2.id, rk]
	ok(rule_bad == "", "luat cua Bo Khai Cuoc dung chung khoa voi EFFECT_KEYS", rule_bad)

	print("
--- SAN SAT THUONG ---")
	# Nhieu nguon co the AM (trang bi danh doi, khi hau, di vat nhan doi mat trai).
	# Khong co san thi quai duoc HOI MAU khi bi ban — do duoc -9 voi 2 Repeater.
	var any_t = null
	for c4 in gc.grid_data.keys():
		var v4 = gc.grid_data[c4]
		if v4 is Node3D and is_instance_valid(v4): any_t = v4; break
	if any_t != null:
		ok(any_t.current_damage >= 1, "sat thuong luon >= 1",
			"%d" % any_t.current_damage)

	print("
--- TAM BAN PHAI CO TAC DUNG VOI MOI NUOC DI ---")
	# Nuoc NHAY von la tap o CO DINH nen `max_range` khong anh huong gi — do duoc
	# Ma/Tot/Vua/KimTuong/TuongDien phu y het nhau o tam 3, 4 va 6. Nghia la MOI
	# nguon "+1 tam ban" (perk, trang bi, o Bang, ★3, Hang Long) la SO CHET voi
	# sau tren muoi ba nuoc di. Nguoi choi nhat duoc ma khong thay khac biet gi.
	# Nay: tam = SO VONG, moi +1 mo dung mot vong.
	var no_effect := ""
	for kind3 in [K.ROOK, K.BISHOP, K.QUEEN, K.KNIGHT, K.PAWN, K.KING,
			K.SIEGE, K.GOLD, K.XIANG]:
		var blk3 := {}
		var n1: int = ChessPattern.cells(kind3, Vector2i(4, 4), 2, blk3).size()
		var n2: int = ChessPattern.cells(kind3, Vector2i(4, 4), 3, blk3).size()
		if n2 <= n1:
			no_effect += "%d " % kind3
	ok(no_effect == "", "moi nuoc di deu phu NHIEU HON khi +1 tam", no_effect)

	# cells() va covers() phai KHOP TUYET DOI — hai diem vao, mot su that.
	var blk4 := {Vector2i(5, 5): true}
	var mismatch2 := ""
	for kind4 in [K.ROOK, K.BISHOP, K.QUEEN, K.KNIGHT, K.PAWN, K.KING,
			K.CANNON, K.LANCE, K.GOLD, K.XIANG]:
		for r4 in [1, 2, 4]:
			var look := {}
			for c5 in ChessPattern.cells(kind4, Vector2i(4, 4), r4, blk4):
				look[c5] = true
			for yy in range(-6, 7):
				for xx in range(-6, 7):
					var tgt := Vector2i(4, 4) + Vector2i(xx, yy)
					if look.has(tgt) != ChessPattern.covers(kind4, Vector2i(4, 4), tgt, r4, blk4):
						mismatch2 += "k%d r%d %s " % [kind4, r4, str(tgt)]
	ok(mismatch2 == "", "cells() va covers() khop nhau moi nuoc di / moi tam",
		mismatch2.substr(0, 120))

	print("
--- PANEL O NGUYEN TO PHAI HIEN CAP O ---")
	# Component HUD gan bang `X.attach(hud)` nen cha no la HUD, KHONG phai
	# game_map. `_find_territory_manager` tung dung `get_parent()` va luon tra
	# null ⇒ ca muc nguyen to trong panel o (cap o, Dau keo dai, phan ung, thuong
	# thap, xem truoc cap ke) VA nut ban o deu chet cam. Nguoi choi xep chong o
	# len cap 3 ma panel khong hien gi khac.
	var tp = hud.get("_tower_panel")
	ok(tp != null, "co panel thap")
	if tp != null and tp.has_method("_find_territory_manager"):
		ok(tp.call("_find_territory_manager") != null,
			"panel tim duoc TerritoryManager (khong dung get_parent)")
	ok(map.get("coverage_overlay") != null, "co lop to sang tam phu")

	print("\n--- PANEL NOI DUOC VI SAO QUAN KHONG BAN ---")
	# "0 squares (0 on path)" la mot ngo cut: nguoi choi thay con so nhung khong
	# biet nguyen nhan lan cach sua. Nang nhat la PHAO (co tuong) — luat "phai co
	# DUNG mot quan lam ngoi" khong ai doan ra, ma trieu chung lai giong het mot
	# quan bi hong. Panel phai TU noi ra.
	if tp != null and tp.has_method("_coverage_diagnosis"):
		var d_cannon: String = str(tp.call("_coverage_diagnosis", null,
			ChessPattern.Kind.CANNON, 0, 0))
		ok(d_cannon.to_lower().contains("screen"),
			"Phao phu 0 o -> panel giai thich luat NGOI", d_cannon.substr(0, 60))
		var d_siege: String = str(tp.call("_coverage_diagnosis", null,
			ChessPattern.Kind.SIEGE, 0, 0))
		ok(d_siege.to_lower().contains("adjacent"),
			"May ban da phu 0 o -> panel noi ro no khong danh duoc o ke")
		var d_off: String = str(tp.call("_coverage_diagnosis", null,
			ChessPattern.Kind.ROOK, 7, 0))
		ok(d_off.to_lower().contains("path"),
			"Phu 7 o nhung KHONG o nao tren duong -> panel bao phai doi cho")
		ok(str(tp.call("_coverage_diagnosis", null, ChessPattern.Kind.KING, 4, 2)) == "",
			"quan dang ban binh thuong thi KHONG hien canh bao")

	print("\n--- CLICK PHAI TRUNG O DANG TRO (loi 'khong dat duoc quan') ---")
	# Hop click cua quan (PickArea) cao 1.5m, camera nghieng -50 do => tren man
	# hinh no phu luon HAI O phia truoc quan. Do duoc: quan o (2,2), tro chuot
	# vao GIUA o trong (2,1) va (2,0) thi PickUtil deu tra ve (2,2). Cu click do
	# roi vao nhanh "o da co quan" va bi bo qua IM LANG.
	# => Che do DAT phai giai toa do bang MAT DAT (GridUtil), khong phai PickUtil.
	var cam := root.get_camera_3d()
	ok(cam != null, "co camera de kiem chieu toa do")
	if cam != null:
		# Tim mot quan bat ky dang dung tren ban
		var anchor := Vector2i(-1, -1)
		for cell in map.grid_controller.grid_data.keys():
			if map.grid_controller.grid_data.get(cell) is Node3D:
				anchor = cell
				break
		if anchor.x >= 0:
			var wrong := 0
			var right := 0
			for dy in [-2, -1, 1, 2]:
				var probe: Vector2i = anchor + Vector2i(0, dy)
				if not map.grid_controller.is_in_bounds(probe):
					continue
				var scr2: Vector2 = cam.unproject_position(GridUtil.cell_to_world(probe))
				if GridUtil.mouse_to_cell(cam, scr2) == probe:
					right += 1
				else:
					wrong += 1
			ok(wrong == 0,
				"tro giua o thi MAT DAT tra dung o do (che do dat dung cach nay)",
				"dung %d, sai %d" % [right, wrong])

	print("\n--- BOI PHAI LA THAT, KHONG CHI LA SO TREN HUD ---")
	# Loi da do duoc: dat hai Xe cung hang thanh Tran Phao lam BOI tren HUD nhay
	# 1.00 -> 2.00 trong khi `tower.current_damage` dung nguyen 34. Ca cau do xep
	# quan — thu ma ban 8x8 khoa cung + tran so quan sinh ra de ep nguoi choi
	# giai — duoc thuong dung BANG KHONG.
	var gc2 = map.grid_controller
	map.current_gold = 99000
	# Xe ton 2.0 Sac Lenh moi con; cac phan test tren da tieu sach.
	if map.king_manager: map.king_manager.add_royal_decree(999.0)
	# DON BAN truoc: phan test tran so quan o tren da rai day Tot, nen `place()`
	# se bi tran chan va `grid_data.get()` tra null. Phai xoa CA entry trong
	# grid_data chu khong chi queue_free node.
	for cell in gc2.grid_data.keys():
		var v = gc2.grid_data[cell]
		if v is Node3D and is_instance_valid(v):
			gc2.grid_data.erase(cell)
			v.queue_free()
	await process_frame
	await process_frame
	Tower.bump_layout(self)
	map.chess_formations.recount()
	var rk: TowerStats = load("res://res/towers/rook.tres")
	var ca := Vector2i(-1, -1)
	var cb := Vector2i(-1, -1)
	for y in range(gc2.grid_height):
		var free_cells: Array[Vector2i] = []
		for x in range(gc2.grid_width):
			var cc := Vector2i(x, y)
			if not gc2.is_path_cell(cc) and not gc2.grid_data.has(cc):
				free_cells.append(cc)
		if free_cells.size() >= 2:
			ca = free_cells[0]
			cb = free_cells[free_cells.size() - 1]
			break
	ok(ca.x >= 0, "tim duoc hai o trong cung mot hang de dung Tran Phao")
	if ca.x >= 0:
		map.shop_manager.register_troop_purchase(rk)
		map.tower_placer.start_build(rk); map.tower_placer.place(ca)
		map.tower_placer.cancel_build()
		var r1 = gc2.grid_data.get(ca)
		await process_frame
		var d_solo: int = int(r1.current_damage)

		map.shop_manager.register_troop_purchase(rk)
		map.tower_placer.start_build(rk); map.tower_placer.place(cb)
		map.tower_placer.cancel_build()
		await process_frame
		var d_pair: int = int(r1.current_damage)
		ok(map.chess_formations.counts().has("battery"), "hai Xe cung hang = Tran Phao")
		ok(d_pair > d_solo, "the co lam tang SAT THUONG THAT, khong chi doi so tren HUD",
			"%d -> %d" % [d_solo, d_pair])
		ok(map.board_score.combat_mult(ca) > 1.0,
			"combat_mult() phan anh the co", "%.2f" % map.board_score.combat_mult(ca))

		# Goi lai nhieu lan KHONG duoc nhan chong (giong star_damage_mult, no la
		# he so DAN XUAT chu khong cong don).
		for _i in 5:
			r1.recalculate_stats()
			r1.refresh_formation_mult()
		ok(int(r1.current_damage) == d_pair, "goi lai nhieu lan khong nhan chong",
			"%d vs %d" % [int(r1.current_damage), d_pair])

		# Du bao KHONG duoc dem hai lan: `tower_dps()` da gom the co vao
		# `current_damage`, nen trung binh tren duong di phai dung `residual_mult`.
		ok(map.board_score.residual_mult(ca) <= map.board_score.cell_mult(ca) + 0.001,
			"residual_mult la MOT PHAN cua cell_mult")
		ok(is_equal_approx(map.board_score.cell_mult(ca),
			map.board_score.combat_mult(ca) * map.board_score.residual_mult(ca)),
			"cell_mult = combat_mult x residual_mult (khong hut, khong trung)",
			"%.3f vs %.3f" % [map.board_score.cell_mult(ca),
				map.board_score.combat_mult(ca) * map.board_score.residual_mult(ca)])

		# Go mot Xe -> the co TAN -> sat thuong ve nhu cu. `queue_free()` de node
		# nam trong cay toi cuoi frame, ma `tower_dismissed` xu ly DONG BO ngay
		# luc do => lan dem lai van thay con vua bi go. Truoc day loi nay chi lam
		# sai so tren HUD; tu khi BOI vao sat thuong that thi no ghim x2 VINH VIEN.
		map.tower_placer.add_dismiss_stock(3)
		map.tower_placer.enter_dismiss_mode()
		map.tower_placer.dismiss_at(cb)
		await process_frame
		ok(not map.chess_formations.counts().has("battery"),
			"go mot Xe thi Tran Phao TAN ngay (khong ke node dang queue_free)")
		ok(int(r1.current_damage) == d_solo, "sat thuong tut ve nhu cu sau khi the co tan",
			"%d vs %d" % [int(r1.current_damage), d_solo])

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
