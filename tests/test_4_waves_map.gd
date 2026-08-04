extends SceneTree
# BATCH 4 — wave / boss / elite / mo rong ban do + rebase.
var fail := 0
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1

func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	if map == null: print("FATAL"); quit(); return
	var gc = map.grid_controller
	var ws = map.wave_spawner
	var tm = map.territory_manager
	var km = map.king_manager
	map.current_gold = 100000

	print("\n--- SCALING THEO WAVE ---")
	# `get_health_multiplier` KHONG con la duong cong do kho — no la he so NAN
	# tong mau wave ve `target_wave_hp`. Wave boss chi co 6 linh nen he so cua no
	# to gap ba wave thuong, do la DUNG. Bat bien that nam o TONG MAU.
	var prev := 0.0
	var bad := ""
	var jump_bad := ""
	var last_ratio := 0.0
	for w in range(1, PhaseController.MAX_WAVES + 1):
		var tot: float = ws.target_wave_hp(w)
		if tot <= prev:
			bad += "w%d(%.0f<=%.0f) " % [w, tot, prev]
		# Khong wave nao duoc nhay gap doi: do chinh la "vach da" ma duong cong
		# nay sinh ra de xoa. Ban cu do duoc ×2.13 giua wave 8 va 10.
		if prev > 0.0 and tot / prev > 1.85:
			jump_bad += "w%d(x%.2f) " % [w, tot / prev]
		prev = tot
		last_ratio = tot
	ok(bad == "", "tong mau wave tang dan qua CA 12 wave", bad)
	ok(jump_bad == "", "khong wave nao nhay > 1.85x (khong con vach da)", jump_bad)
	ok(ws.target_wave_hp(12) > ws.target_wave_hp(11),
		"wave CUOI la dinh, khong phai cho trung",
		"%.0f > %.0f" % [ws.target_wave_hp(12), ws.target_wave_hp(11)])
	# Mau Rival King co duong cong RIENG (sat thuong don-muc-tieu tang ~x1.25/wave
	# con mau wave tang x1.26 — buoc chung thi boss bo xa nguoi choi).
	var b_prev := 0.0
	var b_bad := ""
	for bw in ws.BOSS_WAVES:
		var bhp: float = float(ws._pick_boss_stats(int(bw)).max_hp) \
			* ws.get_boss_health_multiplier(int(bw))
		if bhp <= b_prev:
			b_bad += "w%d(%.0f<=%.0f) " % [int(bw), bhp, b_prev]
		b_prev = bhp
	ok(b_bad == "", "mau Rival King tang dan qua 3 wave boss", b_bad)
	ok(ws.get_speed_multiplier(10) > ws.get_speed_multiplier(1), "toc do dich tang dan")
	# Chon hai wave THUONG de so — wave boss dem rieng (BOSS_WAVE_MINION_COUNT).
	var w_a := 2
	var w_b := 8
	while ws.is_boss_wave(w_a): w_a += 1
	while ws.is_boss_wave(w_b) or w_b <= w_a: w_b += 1
	ok(ws.calculate_enemies_for_wave(w_b) > ws.calculate_enemies_for_wave(w_a),
		"so dich tang dan (wave boss dem rieng)",
		"w%d=%d < w%d=%d" % [w_a, ws.calculate_enemies_for_wave(w_a),
			w_b, ws.calculate_enemies_for_wave(w_b)])

	print("\n--- DO KHO DOC DUOC (chong tai phat 3 loi da do bang bot) ---")
	# (1) Nguong hien thi cua wave BOSS tung cao gap ~3 lan su that: wave_total_hp
	# chi nan so dich theo MOT chieu (`real > listed`), ma wave boss co 6 ho ve
	# trong khi be loai liet ke ~20 dong.
	var bs2 = map.board_score
	var bwv: int = int(ws.BOSS_WAVES[0])
	var listed := 0
	for row in ws.get_wave_enemy_preview(bwv):
		listed += int((row as Dictionary).get("count", 0))
	ok(listed > ws.calculate_enemies_for_wave(bwv),
		"be loai wave boss liet ke NHIEU hon so ho ve that (dieu kien cua loi cu)",
		"liet ke %d, that %d" % [listed, ws.calculate_enemies_for_wave(bwv)])
	ok(bs2.wave_total_hp(bwv) < ws.target_wave_hp(bwv) * 2.0,
		"nguong wave boss KHONG phong to theo so dong liet ke",
		"%.0f vs muc tieu %.0f" % [bs2.wave_total_hp(bwv), ws.target_wave_hp(bwv)])

	# (2) Giap tru PHANG moi phat (san 1). Mo hinh cu bo qua han nen no hua "du
	# suc ha boss" truoc mot Rival King giap 10.
	var stt: TowerStats = load("res://res/towers/pawn.tres")
	map.shop_manager.register_troop_purchase(stt)
	var placed: Node = null
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var cc := Vector2i(x, y)
			if gc.is_path_cell(cc) or gc.grid_data.has(cc):
				continue
			map.tower_placer.start_build(stt)
			map.tower_placer.place(cc)
			map.tower_placer.cancel_build()
			placed = gc.grid_data.get(cc)
			break
		if placed != null: break
	ok(placed != null, "dat duoc quan de do mo hinh giap")
	if placed != null:
		var raw: float = BoardScore.tower_dps(placed)
		var arm: float = BoardScore.tower_dps_vs_armor(placed, 10.0)
		ok(arm < raw, "giap lam TUT dps trong mo hinh", "%.1f -> %.1f" % [raw, arm])
		ok(BoardScore.tower_dps_vs_armor(placed, 99999.0) > 0.0,
			"giap khong the dua dps ve 0 (san 1 sat thuong moi phat)")

	# (3) Rival King di cung ho ve, ma thap nham con VAO TAM TRUOC chu khong nham
	# boss. Mo hinh cu tinh nhu the boss la muc tieu duy nhat -> bao ti le 5.17
	# trong khi boss di thang toi King va nguoi choi THUA NGAY.
	# Kiem Y DINH chu khong kiem con so: `_boss_focus` gop HAI he so nguoc chieu
	# (ho ve hut hoa luc di, phan ung/DoT cong them vao) nen tri tuyet doi cua no
	# la mot hang so DO DUOC, se doi. Cai khong duoc doi la CHIEU: them ho ve thi
	# hoa luc don vao boss phai GIAM.
	ok(BoardScore.BOSS_ESCORT_OVERLAP > 0.0,
		"mo hinh co tinh viec ho ve hut hoa luc khoi boss")
	var f6: float = BoardScore.BOSS_EXTRA_SOURCES / (1.0 + 6.0 * BoardScore.BOSS_ESCORT_OVERLAP)
	var f12: float = BoardScore.BOSS_EXTRA_SOURCES / (1.0 + 12.0 * BoardScore.BOSS_ESCORT_OVERLAP)
	ok(f12 < f6, "cang nhieu ho ve, hoa luc don vao boss cang it",
		"6 ho ve %.2f -> 12 ho ve %.2f" % [f6, f12])

	# (4) Mau Vua phai chiu duoc NHIEU lan lot, neu khong do kho thanh nhi phan:
	# mat 0 mau suot ca van roi chet sach trong dung mot wave.
	var worst := 0
	for f in DirAccess.open("res://res/enemy/").get_files():
		var cn := f.trim_suffix(".remap")
		if not cn.ends_with(".tres"): continue
		var es := load("res://res/enemy/" + cn) as EnemyStats
		if es: worst = maxi(worst, int(es.damage_to_base))
	var kbad := ""
	for f2 in DirAccess.open("res://res/kings/").get_files():
		var cn2 := f2.trim_suffix(".remap")
		if not cn2.ends_with(".tres"): continue
		var k2 := load("res://res/kings/" + cn2) as KingStats
		if k2 and k2.base_health < worst * 6:
			kbad += "%s(%d) " % [k2.id, k2.base_health]
	ok(kbad == "", "moi Vua chiu duoc >= 6 lan lot cua con nang nhat (dmg %d)" % worst, kbad)

	print("\n--- MUA ---")
	var seasons := {}
	for w in range(1, 13): seasons[ws.get_season(w)] = true
	ok(seasons.size() == 4, "du 4 mua trong 12 wave", "%d" % seasons.size())
	var pool_empty: Array[int] = []
	for w in range(1, 13):
		if ws._get_season_enemy_pool(w).is_empty(): pool_empty.append(w)
	ok(pool_empty.is_empty(), "moi wave deu co pool dich", str(pool_empty))

	print("\n--- BOSS ---")
	# BA wave boss: 7 / 14 / 20 — moi lan mot Rival King khac nhau.
	ok(ws.BOSS_WAVES.size() == 3, "co 3 wave boss", str(ws.BOSS_WAVES))
	for bw in ws.BOSS_WAVES:
		ok(ws.is_boss_wave(bw), "wave %d la wave boss" % bw)
	# Wave khong nam trong BOSS_WAVES thi khong duoc la boss — tim mot wave nhu vay
	# thay vi ghim so 9, vi BOSS_WAVES doi theo do dai van.
	var non_boss := 1
	while ws.is_boss_wave(non_boss): non_boss += 1
	ok(not ws.is_boss_wave(non_boss), "wave %d khong phai boss" % non_boss)
	# Moi wave boss phai ra mot vua KHAC NHAU, khong duoc trung
	var seen_kings := {}
	for bw in ws.BOSS_WAVES:
		ws._wave_number = bw
		var st = ws._pick_boss_stats()
		if st: seen_kings[st.id] = true
	ok(seen_kings.size() == ws.BOSS_WAVES.size(),
		"moi wave boss ra mot Rival King khac nhau", str(seen_kings.keys()))
	ok(not ws.is_boss_pending(), "chua vao wave boss thi khong pending")
	var boss_bad: Array[String] = []
	for bid in ws.BOSS_IDS:
		var path: String = ws.BOSS_STATS_PATH % bid
		if not ResourceLoader.exists(path): boss_bad.append(bid)
		else:
			var bs = load(path)
			if bs == null or bs.display_name == "": boss_bad.append(bid + "(thieu ten)")
	ok(boss_bad.is_empty(), "moi boss co .tres + ten hien thi", str(boss_bad))
	ok(ws.get_boss_health_multiplier(ws.BOSS_WAVES[0]) > 1.0, "boss co he so mau rieng",
		"x%.1f" % ws.get_boss_health_multiplier(ws.BOSS_WAVES[0]))
	ok(PhaseController.MAX_WAVES >= ws.BOSS_WAVES.back(),
		"MAX_WAVES du dai cho wave boss cuoi",
		"%d >= %d" % [PhaseController.MAX_WAVES, ws.BOSS_WAVES.back()])

	print("\n--- ASCENSION ---")
	var asc0: float = ws.get_ascension_multiplier()
	gm.ascension_level = 3
	var asc3: float = ws.get_ascension_multiplier()
	ok(asc3 > asc0, "ascension tang do kho", "%.2f -> %.2f" % [asc0, asc3])
	gm.ascension_level = 0

	print("\n--- MO RONG BAN DO ---")
	var w0: int = gc.grid_width
	var h0: int = gc.grid_height
	var path0: int = gc.current_path_grid.size()
	# Lambda GDScript bat bien local theo GIA TRI — phai dung Array de nhan ket qua.
	var rebase_log: Array[Vector2i] = []
	gc.map_rebased.connect(func(d: Vector2i): rebase_log.append(d))
	# Duong mo rong duoc phep DE LEN o lanh tho: TerritoryManager don mesh va
	# hoan kho qua signal nay. Phai tinh den, khong thi test flaky.
	var overwritten: Array[Vector2i] = []
	if gc.has_signal("territory_overwritten_on_expand"):
		gc.territory_overwritten_on_expand.connect(
			func(cells: Array[Vector2i]): overwritten.append_array(cells))
	# Dat 1 thap + 1 o de kiem tra du lieu con dung sau rebase
	var st: TowerStats = load("res://res/towers/pawn.tres")
	map.shop_manager.register_troop_purchase(st)
	var mark_cell := Vector2i(-1, -1)
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if not gc.is_path_cell(c) and not gc.grid_data.has(c):
				mark_cell = c; break
		if mark_cell.x >= 0: break
	map.tower_placer.start_build(st); map.tower_placer.place(mark_cell); map.tower_placer.cancel_build()
	var tower_ref = gc.grid_data.get(mark_cell)
	tm.add_stock("ice"); tm.select("ice")
	var tile_cell := Vector2i(-1, -1)
	# Tranh o vua dat thap — o do co the khong nhan duoc lanh tho.
	for c in tm.get_placeable_tiles(gc.grid_data, "ice"):
		if c != mark_cell:
			tile_cell = c; break
	var tile_placed := false
	if tile_cell.x >= 0:
		tile_placed = tm.try_place(tile_cell, gc.grid_data, km)
	ok(tile_placed, "dat duoc o lanh tho de kiem tra rebase", str(tile_cell))

	gc.expand()
	await process_frame
	ok(gc.grid_width > w0 or gc.grid_height > h0, "ban do to ra",
		"%dx%d -> %dx%d" % [w0, h0, gc.grid_width, gc.grid_height])
	ok(gc.current_path_grid.size() > path0, "duong quai dai them",
		"%d -> %d" % [path0, gc.current_path_grid.size()])
	ok(gc.grid_width <= gc.MAX_AXIS and gc.grid_height <= gc.MAX_AXIS,
		"khong vuot MAX_AXIS", "%d" % gc.MAX_AXIS)
	# Toa do phai duoc rebase: khong o nao am
	var neg := 0
	for c in gc.grid_data.keys():
		if c.x < 0 or c.y < 0: neg += 1
	ok(neg == 0, "khong co o toa do am sau rebase", "%d o am" % neg)
	# Thap cu phai con song va van nam trong grid_data
	# grid_data co the chua ca String (marker o dac biet) lan Node — so sanh
	# truc tiep String voi Object la loi kieu, phai loc truoc.
	var still := false
	for c in gc.grid_data.keys():
		var v: Variant = gc.grid_data[c]
		if v is Node and v == tower_ref: still = true
	var rebased: Vector2i = rebase_log[0] if not rebase_log.is_empty() else Vector2i.ZERO
	ok(is_instance_valid(tower_ref) and still, "thap cu con nguyen sau mo rong",
		"rebase delta=%s" % str(rebased))
	# O lanh tho phai theo kip rebase
	if tile_placed:
		var moved := tile_cell + rebased
		var was_overwritten := overwritten.has(tile_cell) or overwritten.has(moved)
		ok(tm.has_biome_at(moved) or was_overwritten,
			"o lanh tho theo kip rebase (hoac bi duong moi de len hop le)",
			"%s + %s = %s | de len=%s" % [str(tile_cell), str(rebased), str(moved),
				str(was_overwritten)])
	# Duong quai phai lien tuc (moi buoc ke nhau)
	var broken := 0
	for i in range(1, gc.current_path_grid.size()):
		var d: Vector2i = gc.current_path_grid[i] - gc.current_path_grid[i-1]
		if abs(d.x) + abs(d.y) != 1: broken += 1
	ok(broken == 0, "duong quai lien tuc tung buoc", "%d cho dut" % broken)

	print("\n--- MO RONG NHIEU LAN ---")
	var okall := true
	for i in range(4):
		print("     mo rong lan %d (%dx%d)..." % [i + 2, gc.grid_width, gc.grid_height])
		gc.expand()
		await process_frame
		for c in gc.grid_data.keys():
			if c.x < 0 or c.y < 0: okall = false
	ok(okall, "5 lan mo rong lien tiep khong sinh toa do am",
		"%dx%d" % [gc.grid_width, gc.grid_height])
	var broken2 := 0
	for i in range(1, gc.current_path_grid.size()):
		var d: Vector2i = gc.current_path_grid[i] - gc.current_path_grid[i-1]
		if abs(d.x) + abs(d.y) != 1: broken2 += 1
	ok(broken2 == 0, "duong quai van lien tuc sau 5 lan", "%d cho dut" % broken2)

	print("\n== BATCH 4 FAIL=%d ==" % fail)
	quit()
