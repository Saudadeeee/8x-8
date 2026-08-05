extends SceneTree
# (phần engine di vật tổng quát nằm ở cuối file — xem "ENGINE DI VAT")
# BATCH 3 — vat pham: thuoc / trang bi / di vat.
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

func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	if map == null: print("FATAL"); quit(); return
	var gc = map.grid_controller
	map.current_gold = 100000
	var pot = map.potion_system
	var eq  = map.equipment_system
	var rel = map.relic_system

	print("\n--- THUOC ---")
	ok(pot != null, "co PotionSystem")
	if pot:
		var ids: Array = pot.all_ids()
		ok(ids.size() >= 20, "catalog >= 20 thuoc", "%d" % ids.size())
		# Moi thuoc phai co du field va tra cuu duoc
		# Thuoc dung 3 kenh tai trong: `buff` (buff thap trong vung),
		# `strike` (sat thuong/Dau len dich), `special` (hieu ung dac biet).
		# Thieu ca ba = nem ra khong lam gi ca.
		var bad: Array[String] = []
		for pid in ids:
			var d: Dictionary = pot.get_potion_by_id(pid)
			if d.is_empty() or not d.has("name"):
				bad.append(str(pid) + "(thieu name)")
			elif not (d.has("buff") or d.has("strike") or d.has("special")):
				bad.append(str(pid) + "(khong co kenh tac dung)")
		ok(bad.is_empty(), "moi thuoc co name + it nhat 1 kenh tac dung", str(bad))
		var bag0: int = pot.free_slots()
		ok(pot.add_potion(ids[0]), "them thuoc vao tui")
		ok(pot.free_slots() == bag0 - 1, "tui giam 1 o")
		ok(pot.can_use(0), "o 0 dung duoc")
		var used: bool = pot.use_potion(0, Vector3(2, 0, 2))
		ok(used, "nem thuoc thanh cong")
		ok(pot.free_slots() == bag0, "dung xong tra lai o trong")
		# Tui day
		for i in range(10): pot.add_potion(ids[0])
		ok(pot.free_slots() == 0, "tui day thi khong nhet them")

	print("\n--- TRANG BI ---")
	ok(eq != null, "co EquipmentSystem")
	var tower = null
	if eq:
		var ids: Array[String] = eq.all_ids()
		ok(ids.size() >= 20, "catalog >= 20 mon", "%d" % ids.size())
		var bad: Array[String] = []
		for iid in ids:
			var d: Dictionary = eq.item_data(iid)
			if d.is_empty() or not d.has("name") or not d.has("effect"): bad.append(iid)
		ok(bad.is_empty(), "moi mon co name + effect", str(bad))
		# Dat 1 thap de lap do
		var st: TowerStats = load("res://res/towers/pawn.tres")
		map.shop_manager.register_troop_purchase(st)
		var c := _free_cell(gc)
		map.tower_placer.start_build(st); map.tower_placer.place(c); map.tower_placer.cancel_build()
		tower = gc.grid_data.get(c)
		ok(tower != null, "dat duoc thap de thu trang bi")
		if tower:
			var dmg0: int = tower.current_damage
			eq.add_item(ids[0])
			ok(eq.inventory().size() == 1, "them mon vao kho")
			ok(eq.free_slots(tower) >= 1, "thap con o trong", "%d" % eq.free_slots(tower))
			ok(eq.equip_from_inventory(tower, 0), "lap do len thap")
			ok(eq.equipped_on(tower).size() == 1, "thap dang deo 1 mon")
			ok(eq.inventory().is_empty(), "mon roi khoi kho khi lap")
			# Lap day roi lap them phai truot
			for i in range(5):
				eq.add_item(ids[1]); eq.equip_from_inventory(tower, 0)
			ok(eq.equipped_on(tower).size() <= eq.slots_per_tower,
				"khong vuot so o trang bi", "%d/%d" % [eq.equipped_on(tower).size(), eq.slots_per_tower])
			ok(eq.unequip(tower, 0), "thao do ve kho")
			var g0: int = map.current_gold
			var got: int = eq.sell_from_inventory(0)
			ok(got > 0, "ban do duoc vang", "+%d" % got)

	print("\n--- DI VAT ---")
	ok(rel != null, "co RelicSystem")
	if rel:
		var ids: Array[String] = rel.all_ids()
		ok(ids.size() >= 12, "catalog >= 12 di vat", "%d" % ids.size())
		var bad: Array[String] = []
		for rid in ids:
			var d: Dictionary = rel.relic_data(rid)
			if d.is_empty() or not d.has("name"): bad.append(rid)
		ok(bad.is_empty(), "moi di vat co name", str(bad))
		ok(rel.add_relic(ids[0]), "nhan di vat")
		ok(rel.has_relic(ids[0]), "so huu di vat vua nhan")
		ok(not rel.add_relic(ids[0]), "khong nhan trung mot di vat")
		# Nhet day 5 o
		for rid in ids:
			rel.add_relic(rid)
		ok(rel.owned().size() <= 5, "toi da 5 o di vat", "%d" % rel.owned().size())
		ok(rel.is_full(), "bao day dung")
		# Ban -> gia tri phai tra ve mac dinh
		var slots_before: int = eq.slots_per_tower if eq else 0
		var n0: int = rel.owned().size()
		rel.sell_relic(0)
		ok(rel.owned().size() == n0 - 1, "ban di vat giam 1 o")
		print("     tong hop di vat: ", rel.totals())

	print("\n--- TUONG TAC: DI VAT DOI SO O ---")
	if rel and eq:
		while rel.owned().size() > 0: rel.sell_relic(0)
		var base_slots: int = eq.slots_per_tower
		var anvil := ""
		for rid in rel.all_ids():
			var d: Dictionary = rel.relic_data(rid)
			if str(d).to_lower().find("equip_slot") >= 0: anvil = rid
		if anvil != "":
			rel.add_relic(anvil)
			ok(eq.slots_per_tower > base_slots, "di vat tang so o trang bi",
				"%d -> %d" % [base_slots, eq.slots_per_tower])
			rel.sell_relic(0)
			ok(eq.slots_per_tower == base_slots, "ban di vat -> so o ve mac dinh",
				"=%d" % eq.slots_per_tower)
		else:
			print("     (khong tim thay di vat tang o — bo qua)")

	print("\n--- ENGINE DI VAT TONG QUAT ---")
	# ~70 di vat di qua DUNG MOT bo may (relic_conditions.gd). Neu bo may nay
	# hong thi 70 mon chet cung luc — nen no phai duoc kiem ky hon bat ky mon
	# rieng le nao.
	var rs2 = map.relic_system
	ok(rs2._catalog.size() >= 90, "co it nhat 90 di vat", "%d" % rs2._catalog.size())

	# (1) MOI di vat phai giu duoc hieu ung sau khi qua `_sanitize`. Khoa la bi
	# loc TRANG va im lang — do la cach 8 di vat co tung chet ma khong ai biet.
	var empty_eff := ""
	for rid in rs2._catalog:
		var e: Dictionary = rs2._catalog[rid].get("effect", {})
		if e.is_empty():
			empty_eff += str(rid) + " "
	ok(empty_eff == "", "khong di vat nao bi loc mat sach hieu ung", empty_eff)

	# (2) Bo may dieu kien: moi ten trong bang nhan phai duoc `test()` hieu.
	# Ten la tra false, nghia la di vat vo hai — nhung neu MOT ten trong bang
	# nhan bi go khoi `test()` thi di vat do chet am tham.
	var facts := RelicConditions.facts(map)
	var unknown_cond := ""
	for cid in RelicConditions.COND_LABELS:
		# Goi duoc va khong nem loi la du; gia tri dung/sai tuy trang thai ban.
		var _v: bool = RelicConditions.test(str(cid), facts)
	for cnt in RelicConditions.COUNT_LABELS:
		if not facts.has(str(cnt)):
			unknown_cond += str(cnt) + " "
	ok(unknown_cond == "", "moi bo dem trong bang nhan deu co trong facts()",
		unknown_cond)

	# (3) Dieu kien phai TRA VE dung/sai theo trang thai THAT, khong hang so.
	var f_few := {"pieces": 3, "max_units": 10}
	var f_many := {"pieces": 18, "max_units": 20}
	ok(RelicConditions.test("few_pieces", f_few), "few_pieces dung khi it quan")
	ok(not RelicConditions.test("few_pieces", f_many), "few_pieces sai khi dong quan")
	ok(RelicConditions.test("many_pieces", f_many), "many_pieces dung khi dong quan")
	ok(RelicConditions.test("full_board", {"pieces": 10, "max_units": 10}),
		"full_board dung khi cham tran")
	ok(not RelicConditions.test("khong_ton_tai", f_few),
		"ten dieu kien LA tra false (di vat vo hai, khong lam hong van)")
	ok(is_zero_approx(RelicConditions.count("khong_ton_tai", f_few)),
		"ten bo dem LA tra 0")

	# (4) CONG DON: hai di vat cung dieu kien phai cong lai, khong de nhau.
	# Khong co cai nay thi mua mon thu hai lai thay suc manh dung yen.
	while rs2._owned.size() > 0:
		rs2.sell_relic(0)
	var cond_ids: Array[String] = []
	for rid in rs2._catalog:
		var e2: Dictionary = rs2._catalog[rid].get("effect", {})
		var cm2 = e2.get("cond_mult", {})
		if cm2 is Dictionary and (cm2 as Dictionary).has("few_pieces") \
				and float((cm2 as Dictionary)["few_pieces"]) > 0.0:
			cond_ids.append(str(rid))
	ok(cond_ids.size() >= 2, "co it nhat 2 di vat cung dung 'few_pieces'",
		"%d" % cond_ids.size())
	if cond_ids.size() >= 2:
		rs2.add_relic(cond_ids[0])
		var one: float = float((rs2.totals()["cond_mult"] as Dictionary).get("few_pieces", 0.0))
		rs2.add_relic(cond_ids[1])
		var two: float = float((rs2.totals()["cond_mult"] as Dictionary).get("few_pieces", 0.0))
		ok(two > one + 0.0001, "hai di vat cung dieu kien CONG DON, khong de nhau",
			"%.2f -> %.2f" % [one, two])
	while rs2._owned.size() > 0:
		rs2.sell_relic(0)

	# (5) MAT TRAI phai that: di vat danh doi co gia tri AM cho dieu kien xau.
	var has_malus := false
	for rid in rs2._catalog:
		var e3: Dictionary = rs2._catalog[rid].get("effect", {})
		var cm3 = e3.get("cond_mult", {})
		if cm3 is Dictionary:
			for k in (cm3 as Dictionary):
				if float((cm3 as Dictionary)[k]) < 0.0:
					has_malus = true
					break
		if has_malus: break
	ok(has_malus, "co di vat DANH DOI (mat trai am), khong chi toan mon cong them")

	print("\n== BATCH 3 FAIL=%d ==" % fail)
	quit()
