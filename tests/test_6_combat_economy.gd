extends SceneTree
# BATCH 6 — chiến đấu + kinh tế + máy trạng thái pha.
# Phủ đúng vùng game_map.gd sắp được tách nhỏ: buff stacking, đạn, pha,
# thua/thắng, vàng/lãi/combo.
var fail := 0
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1

func _free_cell(gc) -> Vector2i:
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if not gc.is_path_cell(c) and not gc.grid_data.has(c): return c
	return Vector2i(-1, -1)

func _place(map, gc, st) -> Node3D:
	map.shop_manager.register_troop_purchase(st)
	var c := _free_cell(gc)
	map.tower_placer.start_build(st)
	map.tower_placer.place(c)
	map.tower_placer.cancel_build()
	return gc.grid_data.get(c)

func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	# Huong dan nhap mon tu hien o van dau va TAM DUNG game — dem nguoc chuan bi
	# se khong chay. Danh dau da xem de test do dung may trang thai pha.
	if gm.meta_progress: gm.meta_progress.seen_tutorial = true
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	if map == null: print("FATAL"); quit(); return
	var gc = map.grid_controller
	map.current_gold = 100000
	map.king_manager.royal_decree = 500.0
	var st: TowerStats = load("res://res/towers/pawn.tres")

	print("\n--- BUFF STACKING ---")
	var t = _place(map, gc, st)
	ok(t != null, "dat duoc thap de thu buff")
	if t:
		# So voi gia tri HIEN TAI chu khong phai stats.base_damage: thap co the
		# dang dung tren o Phuoc/Nguyen hoac an buff Vua, nen base != current.
		var base_dmg: int = t.current_damage
		ok(base_dmg >= st.base_damage, "sat thuong >= base trong .tres",
			"%d >= %d" % [base_dmg, st.base_damage])
		# Cong don NHIEU lop, moi lop la CONG (khong nhan)
		t._set_buff_layer(t.BuffLayer.PERK, 10.0, 0.0, 0)
		var d1: int = t.current_damage
		t._set_buff_layer(t.BuffLayer.EQUIP, 10.0, 0.0, 0)
		var d2: int = t.current_damage
		ok(d2 - d1 == 10, "lop buff thu hai cong THEM dung 10", "%d -> %d" % [d1, d2])
		# Ghi de cung mot lop = THAY THE, khong cong don
		t._set_buff_layer(t.BuffLayer.EQUIP, 10.0, 0.0, 0)
		ok(t.current_damage == d2, "ghi de cung lop = thay the, khong cong don")
		# Go lop
		t._clear_buff_layer(t.BuffLayer.PERK)
		t._clear_buff_layer(t.BuffLayer.EQUIP)
		ok(t.current_damage == base_dmg, "go het lop -> ve base", "%d" % t.current_damage)

		print("\n--- TRAN CONG DON ---")
		# Tam ban khong duoc vuot MAX_EFFECTIVE_RANGE du cong bao nhieu lop
		t._set_buff_layer(t.BuffLayer.PERK, 0.0, 0.0, 20)
		ok(t.current_range <= t.MAX_EFFECTIVE_RANGE, "tam ban bi chan boi MAX_EFFECTIVE_RANGE",
			"%d <= %d" % [t.current_range, t.MAX_EFFECTIVE_RANGE])
		t._clear_buff_layer(t.BuffLayer.PERK)
		# San hoi chieu theo TI LE base, khong phai hang so
		t._set_buff_layer(t.BuffLayer.PERK, 0.0, 99.0, 0)
		var floor_cd: float = st.attack_speed * t.MIN_COOLDOWN_RATIO
		ok(t.current_attack_speed >= floor_cd - 0.001, "hoi chieu co san theo ti le base",
			"%.3f >= %.3f" % [t.current_attack_speed, floor_cd])
		t._clear_buff_layer(t.BuffLayer.PERK)

		print("\n--- SAO LA PHEP NHAN ---")
		# PHAI goi set_star(): gan thang `t.star` khong cap nhat star_damage_mult
		# nen sao se khong co tac dung nao.
		var d_star1: int = t.current_damage
		t.set_star(2)
		var d_star2: int = t.current_damage
		t.set_star(3)
		var d_star3: int = t.current_damage
		ok(d_star2 > d_star1 and d_star3 > d_star2, "sao tang sat thuong",
			"%d -> %d -> %d" % [d_star1, d_star2, d_star3])
		# KHONG do ti le tren current_damage: no la int() cat cut, so nho (13)
		# thi sai so lam tron lam ti le lech han. Kiem thang he so — do moi la
		# hop dong that; current_damage = (base + moi lop) * season * star_mult.
		ok(abs(t.star_damage_mult - t.STAR_DAMAGE_MULT[2]) < 0.001,
			"star_damage_mult khop bang tai sao 3", "%.2f" % t.star_damage_mult)
		t.set_star(2)
		ok(abs(t.star_damage_mult - t.STAR_DAMAGE_MULT[1]) < 0.001,
			"star_damage_mult khop bang tai sao 2", "%.2f" % t.star_damage_mult)
		t.set_star(3)
		# Vuot tran sao thi kep lai, khong tang vo han
		t.set_star(99)
		ok(t.star == t.MAX_STAR, "set_star kep o MAX_STAR", "%d" % t.star)
		# Recalculate NHIEU LAN khong duoc nhan chong
		t.recalculate_stats(); t.recalculate_stats(); t.recalculate_stats()
		ok(t.current_damage == d_star3, "recalculate nhieu lan khong nhan chong",
			"%d" % t.current_damage)
		t.set_star(1)

	print("\n--- DAN (PROJECTILE) ---")
	var e_scene: PackedScene = load("res://scenes/enemy/enemy.tscn")
	var en = e_scene.instantiate()
	en.stats = load("res://res/enemy/orc.tres")
	map.add_child(en)
	await process_frame
	var hp0: int = en.current_hp
	en.take_damage(10)
	ok(en.current_hp == hp0 - 10, "dich nhan sat thuong", "%d -> %d" % [hp0, en.current_hp])
	# Giap tru phang, toi thieu con 1
	var golem = e_scene.instantiate()
	golem.stats = load("res://res/enemy/golem.tres")
	map.add_child(golem)
	await process_frame
	var g0: int = golem.current_hp
	golem.take_damage(1)
	ok(g0 - golem.current_hp == 1, "giap khong the chan het — toi thieu con 1 dmg",
		"mat %d" % (g0 - golem.current_hp))
	var g1: int = golem.current_hp
	golem.take_damage(100)
	var lost: int = g1 - golem.current_hp
	ok(lost == 100 - golem.stats.armor, "giap tru phang dung so",
		"100 - %d = %d" % [golem.stats.armor, lost])
	en.queue_free(); golem.queue_free()

	print("\n--- MAY TRANG THAI PHA ---")
	var pc = map.phase_controller
	ok(pc != null, "co PhaseController")
	if pc:
		ok(pc.current_phase == PhaseController.GamePhase.PREPARE, "bat dau o pha CHUAN BI",
			str(PhaseController.GamePhase.keys()[pc.current_phase]))
		# Pha chuan bi KHONG con dem nguoc — wave chi chay khi nguoi choi bam nut.
		# Bam khi chua xac nhan trinh sat phai bi tu choi.
		ok(not pc.request_start_wave(), "chua xac nhan trinh sat thi khong bat dau duoc")
		map.confirm_wave_ready()
		await process_frame
		ok(pc.can_start_wave(), "sau xac nhan thi nut bat dau sang")
		# Cho vai frame: pha KHONG duoc tu chuyen (bang chung la dem nguoc da bo)
		for _i in 30:
			await process_frame
		ok(pc.current_phase == PhaseController.GamePhase.PREPARE,
			"khong bam thi pha CHUAN BI khong tu het gio",
			str(PhaseController.GamePhase.keys()[pc.current_phase]))
		ok(pc.request_start_wave(), "bam nut -> vao wave")
		await process_frame
		ok(pc.current_phase == PhaseController.GamePhase.WAVE, "bam nut -> pha WAVE",
			str(PhaseController.GamePhase.keys()[pc.current_phase]))
		ok(pc.wave_number >= 1, "so wave >= 1", "%d" % pc.wave_number)

	print("\n--- KINH TE ---")
	ok(gm.get_interest_rate() > 0.0, "co lai suat cuoi wave", "%.2f" % gm.get_interest_rate())
	ok(gm.get_interest_cap() > 0, "lai co tran", "%d" % gm.get_interest_cap())
	# Chi mang va combo da TAT bang co (FeatureFlags). Kiem NGUOC: chung phai
	# thuc su im lang, khong duoc con ro ri vao sat thuong hay vao vang — bang
	# nguong Nen x Boi hua mot con so chinh xac, ngau nhien lam hong loi hua do.
	ok(not FeatureFlags.CRIT_ENABLED, "chi mang da tat")
	ok(not FeatureFlags.KILL_COMBO_ENABLED, "combo ha guc da tat")
	var m0: float = gm.get_combo_mult()
	for i in range(12): gm.register_kill()
	ok(is_equal_approx(gm.get_combo_mult(), m0),
		"combo da tat thi he so vang KHONG doi", "%.2f" % gm.get_combo_mult())
	ok(gm.combo_count == 0, "combo da tat thi khong dem kill", "%d" % gm.combo_count)

	print("\n--- THUA ---")
	var ended: Array = []
	if gm.has_signal("run_ended"):
		gm.run_ended.connect(func(v): ended.append(v))
	map.current_health = 1
	map._on_enemy_reached_base(99)
	await process_frame
	ok(map.current_health <= 0, "mau Vua ve 0 khi dich lot qua", "%d" % map.current_health)
	ok(not ended.is_empty(), "phat signal run_ended khi thua", str(ended))

	print("\n== BATCH 6 FAIL=%d ==" % fail)
	quit()
