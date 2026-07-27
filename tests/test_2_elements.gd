extends SceneTree
# BATCH 2 — he nguyen to: Dau, 10 phan ung, khac/khang, cap o, hinh the,
# synergy nguyen to, Bat Quai.
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
	var tm = map.territory_manager
	var km = map.king_manager
	map.current_gold = 100000

	print("\n--- NGUON SU THAT NGUYEN TO ---")
	var els: Array = ElementTypes.SPEC.keys()
	ok(els.size() == 6, "co 6 nguyen to", str(els))
	var have_biome := true
	for e in els:
		if tm.get_biome_for_element(e) == "": have_biome = false
	ok(have_biome, "moi nguyen to deu co o lanh tho tuong ung")

	print("\n--- BANG PHAN UNG ---")
	var ids: Array[String] = ReactionTable.all_ids()
	ok(ids.size() == 10, "co 10 phan ung", "%d" % ids.size())
	var last: Dictionary = ReactionTable.TABLE[ReactionTable.TABLE.size() - 1]
	ok((last.get("pair", []) as Array).has(ReactionTable.WILDCARD),
		"WILDCARD (Ket Tinh) dung CUOI bang", str(last.get("id")))
	var early_wild := false
	for k in range(ReactionTable.TABLE.size() - 1):
		if (ReactionTable.TABLE[k].get("pair", []) as Array).has(ReactionTable.WILDCARD):
			early_wild = true
	ok(not early_wild, "khong co WILDCARD nao dung truoc hang cuoi")
	# Moi cap trong bang phai tra ve dung phan ung do
	var lookup_ok := true
	var bad := ""
	for r in ReactionTable.TABLE:
		var pair: Array = r.get("pair", [])
		if pair.size() != 2: continue
		var a: String = str(pair[0]); var b: String = str(pair[1])
		if a == ReactionTable.WILDCARD or b == ReactionTable.WILDCARD: continue
		var f1: Dictionary = ReactionTable.find(a, b)
		var f2: Dictionary = ReactionTable.find(b, a)
		if f1.get("id") != r.get("id") or f2.get("id") != r.get("id"):
			lookup_ok = false; bad += "%s+%s " % [a, b]
	ok(lookup_ok, "tra cuu 2 chieu dung cho moi cap", bad)

	print("\n--- DAU TREN DICH ---")
	var wave = map.wave_spawner
	wave.spawn_enemy_at_start() if wave.has_method("spawn_enemy_at_start") else null
	await create_timer(0.2).timeout
	var enemies := get_nodes_in_group("enemies")
	if enemies.is_empty():
		# tu tao mot dich de test doc lap
		var e_scene: PackedScene = load("res://scenes/enemy/enemy.tscn")
		var en = e_scene.instantiate()
		en.stats = load("res://res/enemy/orc.tres")
		map.add_child(en)
		await process_frame
		enemies = [en]
	var en = enemies[0]
	var marks = en.get_node_or_null("ElementMarks")
	ok(marks != null, "dich co node ElementMarks")
	if marks:
		marks.clear_all()
		marks.implant("fire", 1)
		ok(marks.has_mark("fire"), "gan Dau Hoa")
		marks.implant("ice", 1)
		ok(marks.mark_count() <= marks.max_marks, "khong vuot tran Dau",
			"%d/%d" % [marks.mark_count(), marks.max_marks])
		# Dau thu 3 day Dau CU NHAT ra
		marks.clear_all()
		marks.implant("fire", 1); marks.implant("thunder", 1)
		var before: int = marks.mark_count()
		marks.implant("poison", 1)
		ok(marks.mark_count() == before, "Dau thu N+1 day Dau cu nhat ra",
			"%d" % marks.mark_count())

	print("\n--- KHAC / KHANG ---")
	var aff_all := true
	var no_weak: Array[String] = []
	for eid in EnemyStats.DEFAULT_AFFINITY.keys():
		var row: Array = EnemyStats.DEFAULT_AFFINITY[eid]
		if row.is_empty() or str(row[0]) == "": no_weak.append(eid)
	ok(no_weak.is_empty(), "moi loai dich deu co it nhat 1 diem yeu", str(no_weak))
	# Moi nguyen to phai khac che >= 2 loai
	var counts := {}
	for e in els: counts[e] = 0
	for eid in EnemyStats.DEFAULT_AFFINITY.keys():
		var row: Array = EnemyStats.DEFAULT_AFFINITY[eid]
		if row.size() > 0 and counts.has(str(row[0])): counts[str(row[0])] += 1
		if row.size() > 2 and counts.has(str(row[2])): counts[str(row[2])] += 1
	var weak_lo: Array[String] = []
	for e in els:
		if int(counts[e]) < 2: weak_lo.append("%s=%d" % [e, counts[e]])
	ok(weak_lo.is_empty(), "moi nguyen to khac che >= 2 loai", str(weak_lo))
	ok(EnemyStats.WEAK_MULT > 1.0 and EnemyStats.RESIST_MULT < 1.0, "he so khac/khang dung chieu",
		"x%.2f / x%.2f" % [EnemyStats.WEAK_MULT, EnemyStats.RESIST_MULT])

	print("\n--- CAP O + HINH THE ---")
	ok(TerritoryManager.LEVEL_BONUS.size() == 3, "co 3 cap o")
	var lv1: Dictionary = TerritoryManager.LEVEL_BONUS[0]
	var lv3: Dictionary = TerritoryManager.LEVEL_BONUS[2]
	ok(float(lv3.get("reaction_mult", 1.0)) > float(lv1.get("reaction_mult", 1.0)),
		"Lv3 khuech dai phan ung hon Lv1")
	# Dat 3 o Hoa lien hang -> Hang Long
	# Hang Long can 3 o LIEN TIEP — quet tim day 3 o trong lien nhau.
	var cells: Array[Vector2i] = []
	for y in range(gc.grid_height):
		var run: Array[Vector2i] = []
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if gc.is_path_cell(c) or gc.grid_data.has(c) or tm.has_biome_at(c):
				run.clear()
			else:
				run.append(c)
				if run.size() == 3: break
		if run.size() == 3:
			cells = run
			break
	ok(cells.size() == 3, "tim duoc 3 o trong lien tiep", str(cells))
	for c in cells:
		tm.add_stock("fire"); tm.select("fire"); tm.try_place(c, gc.grid_data, km)
	await process_frame
	var forms: Dictionary = tm.get_formation_counts() if tm.has_method("get_formation_counts") else {}
	print("     hinh the phat hien: ", forms)
	var bonus: Dictionary = tm.get_element_bonus(cells[0]) if cells.size() > 0 else {}
	print("     thuong o ", cells[0] if cells.size() > 0 else "-", ": ", bonus)
	ok(not bonus.is_empty(), "get_element_bonus tra ve du lieu")

	print("\n--- SYNERGY NGUYEN TO ---")
	var es = map.element_synergy if map.get("element_synergy") != null else null
	if es == null: es = map.get_node_or_null("ElementSynergy")
	ok(es != null, "co node ElementSynergy")
	if es:
		# Synergy nguyen to dem THAP dung tren o (Bat Quai moi dem O).
		# Dat 2 thap len 2 o Hoa vua tao -> phai cham nguong dau tien.
		var st2: TowerStats = load("res://res/towers/pawn.tres")
		var placer2 = map.tower_placer
		for i in range(mini(2, cells.size())):
			map.shop_manager.register_troop_purchase(st2)
			placer2.start_build(st2); placer2.place(cells[i]); placer2.cancel_build()
		await process_frame
		es.recount()
		var placed_towers := 0
		for c in cells:
			if gc.grid_data.has(c): placed_towers += 1
		print("     thap tren o Hoa: ", placed_towers, " | dem: ", es.counts,
			" | cap: ", es.levels)
		print("     tom tat: '", es.summary_text(), "'")
		ok(int(es.counts.get("fire", 0)) >= 2, "dem duoc >= 2 thap he Hoa")
		ok(int(es.levels.get("fire", 0)) >= 1, "cham nguong synergy Hoa cap 1")
		ok(es.summary_text() != "", "summary_text co noi dung")
		# Go mot thap -> tut nguong
		placer2.enter_dismiss_mode(); placer2.dismiss_at(cells[0])
		await process_frame
		es.recount()
		ok(int(es.levels.get("fire", 0)) == 0, "go thap -> synergy tat ngay",
			"cap=%d" % int(es.levels.get("fire", 0)))
		# Bat Quai dem O, chua du 6 nguyen to thi phai tat
		ok(not es.bagua_active, "chua du 6 nguyen to -> Bat Quai tat")

	print("\n== BATCH 2 FAIL=%d ==" % fail)
	quit()
