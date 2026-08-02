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
	var c1: int = map.star_up_cost(t)
	ok(c1 > 0, "co gia nang sao ★1→★2", "%d vang" % c1)
	var g0: int = map.current_gold
	var d0: int = t.current_damage
	ok(map.try_star_up_with_gold(t), "nang sao thanh cong")
	ok(t.star == 2, "sao len 2", "star=%d" % t.star)
	ok(map.current_gold == g0 - c1, "tru dung so vang", "%d -> %d" % [g0, map.current_gold])
	ok(t.current_damage > d0, "sat thuong tang", "%d -> %d" % [d0, t.current_damage])
	var c2: int = map.star_up_cost(t)
	ok(c2 > c1, "bac ★2→★3 dat hon", "%d > %d" % [c2, c1])
	map.try_star_up_with_gold(t)
	ok(t.star == 3, "sao len 3")
	ok(map.star_up_cost(t) < 0, "★3 khong nang duoc nua")
	# Khong du vang thi khong nang
	map.current_gold = 0
	var t2 = null
	var c3 := Vector2i(-1,-1)
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var cc := Vector2i(x,y)
			if not gc.is_path_cell(cc) and not gc.grid_data.has(cc): c3 = cc; break
		if c3.x >= 0: break
	map.shop_manager.register_troop_purchase(st)
	map.tower_placer.start_build(st); map.tower_placer.place(c3); map.tower_placer.cancel_build()
	t2 = gc.grid_data.get(c3)
	if t2:
		ok(not map.try_star_up_with_gold(t2), "khong du vang thi khong nang duoc")
		ok(t2.star == 1, "sao giu nguyen")
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
