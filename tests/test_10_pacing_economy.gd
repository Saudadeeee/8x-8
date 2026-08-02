extends SceneTree
# BATCH 10 — nang sao bang VANG (sink kinh te) + kiem nhip cham.
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
	var gc = map.grid_controller
	map.current_gold = 5000
	var st: TowerStats = load("res://res/towers/pawn.tres")
	map.shop_manager.register_troop_purchase(st)
	var c := Vector2i(-1,-1)
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var cc := Vector2i(x,y)
			if not gc.is_path_cell(cc) and not gc.grid_data.has(cc): c = cc; break
		if c.x >= 0: break
	map.tower_placer.start_build(st); map.tower_placer.place(c); map.tower_placer.cancel_build()
	var t = gc.grid_data.get(c)
	ok(t != null, "dat duoc thap")
	if t == null: quit(); return
	# Nang sao bang VANG da bi go — sao chi len bang ghep quan trung.
	# Kiem NGUOC: duong vang phai bien mat han, khong con ton tai duoi dang nao.
	ok(not map.has_method("star_up_cost"),
		"khong con API nang sao bang vang (star_up_cost)")
	ok(not map.has_method("try_star_up_with_gold"),
		"khong con API nang sao bang vang (try_star_up_with_gold)")

	# ...nhung GHEP QUAN TRUNG van phai len sao binh thuong
	var d0: int = t.current_damage
	map.shop_manager.register_troop_purchase(st)
	map.tower_placer.start_build(st); map.tower_placer.place(c); map.tower_placer.cancel_build()
	var merged = gc.grid_data.get(c)
	ok(merged != null and int(merged.star) == 2, "dat quan trung len o -> ★2",
		"star=%d" % (int(merged.star) if merged else -1))
	ok(merged != null and merged.current_damage > d0, "★2 manh hon ★1",
		"%d -> %d" % [d0, merged.current_damage if merged else -1])
	# (khong kiem vang o day: vang tra luc MUA trong shop, dat tu kho la mien phi)

	map.shop_manager.register_troop_purchase(st)
	map.tower_placer.start_build(st); map.tower_placer.place(c); map.tower_placer.cancel_build()
	ok(int(gc.grid_data.get(c).star) == 3, "ghep lan nua -> ★3")

	print("
--- KINH TE SIET LAI ---")
	# Do bang bot tieu sach vang qua 15 wave. Ban cu: vang khoi dau 100, Vua Thep
	# 8 Tot, tran lai 15 -> ton kho leo toi 5894 vang o wave 15 va HP dung yen 20
	# suot 14 wave roi roi thang. Ban nay: dinh 790, HP bat dau tut tu wave 10.
	var gm_script: GDScript = load("res://scripts/managers/GameManager.gd")
	var start_gold: int = int(gm_script.get("STARTING_GOLD"))
	var int_cap: int = int(gm_script.get("DEFAULT_INTEREST_CAP"))
	ok(start_gold <= 70, "vang khoi dau <= 70", "%d" % start_gold)
	ok(int_cap <= 8, "tran lai <= 8 (lai tra tien cho viec KHONG tieu)", "%d" % int_cap)

	var d := DirAccess.open("res://res/kings/")
	var army_bad := ""
	for f in d.get_files():
		var cn := f.trim_suffix(".remap")
		if not cn.ends_with(".tres"): continue
		var k := load("res://res/kings/" + cn) as KingStats
		if k == null: continue
		var total := 0
		for q in k.starting_unit_quantities: total += int(q)
		if total > 5:
			army_bad += "%s co %d quan " % [k.id, total]
	ok(army_bad == "", "khong vua nao khoi dau qua 5 quan", army_bad)

	var gold_bad := ""
	var de := DirAccess.open("res://res/enemy/")
	for f in de.get_files():
		var cn2 := f.trim_suffix(".remap")
		if not cn2.ends_with(".tres"): continue
		var es := load("res://res/enemy/" + cn2) as EnemyStats
		if es == null: continue
		if es.gold_reward >= 100: continue        # boss: thuong moc, khong phai thu nhap deu
		if es.gold_reward > 20:
			gold_bad += "%s=%d " % [es.id, es.gold_reward]
	ok(gold_bad == "", "khong dich thuong nao cho qua 20 vang", gold_bad)

	print("
--- NHIP CHAM ---")
	var ws = map.wave_spawner
	# Toc do dich phai nam trong dai DOC DUOC: nhanh nhat <= 4 o/giay. Truoc khi
	# cham lai, doi co 6.88 o/s — bang ngang ban 8 o trong 1.2 giay.
	var fastest := 0.0
	var fastest_id := ""
	for f in DirAccess.get_files_at("res://res/enemy"):
		if not f.ends_with(".tres"): continue
		var st2 = load("res://res/enemy/" + f)
		if st2 == null: continue
		var tps: float = st2.speed / 16.0
		if tps > fastest:
			fastest = tps
			fastest_id = st2.id
	ok(fastest <= 4.0, "dich nhanh nhat <= 4 o/giay", "%s %.2f o/s" % [fastest_id, fastest])
	ok(ws.SPAWN_INTERVAL >= 1.2, "nhip spawn gian ra", "%.1fs" % ws.SPAWN_INTERVAL)
	ok(ws.ENEMIES_PER_WAVE >= 12, "wave dong hon de bu toc do cham", "%d con" % ws.ENEMIES_PER_WAVE)
	var bullet = load("res://scenes/projectile/projectile.tscn").instantiate()
	ok(bullet.speed <= 12.0, "dan bay du cham de nhin thay", "%.1f o/s" % bullet.speed)
	bullet.queue_free()

	print("
== BATCH 10 FAIL=%d ==" % fail)
	quit()
