extends SceneTree
# BATCH 1 — vong lap loi: dat thap / ghep sao / sa thai / overcharge /
# mua du loai hang trong shop / dat-nang cap-ban o lanh tho.
var fail := 0
func _init() -> void: _run()

func ok(cond: bool, label: String, extra: String = "") -> void:
	if cond: print("  OK   ", label, ("  " + extra) if extra != "" else "")
	else:
		print("  FAIL ", label, "  ", extra); fail += 1

func _free_cell(gc, taken: Array) -> Vector2i:
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if gc.is_path_cell(c) or gc.grid_data.has(c) or taken.has(c): continue
			return c
	return Vector2i(-1, -1)

func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	if map == null: print("FATAL: khong load duoc game_map"); quit(); return
	var gc = map.grid_controller
	var placer = map.tower_placer
	var sm = map.shop_manager
	var tm = map.territory_manager
	var km = map.king_manager
	map.current_gold = 100000
	km.royal_decree = 500.0

	var st: TowerStats = load("res://res/towers/pawn.tres")

	print("\n--- DAT THAP ---")
	sm.register_troop_purchase(st)
	var c1 := _free_cell(gc, [])
	placer.start_build(st); placer.place(c1); placer.cancel_build()
	ok(gc.grid_data.has(c1), "dat thap tai %s" % str(c1))
	var t1 = gc.grid_data.get(c1)
	ok(t1 != null and t1.is_in_group("towers"), "thap nam trong group 'towers'")
	ok(t1 != null and t1.get_node_or_null("PickArea") != null, "thap co PickArea (click 3D)")

	print("\n--- GHEP SAO ---")
	sm.register_troop_purchase(st)
	ok(placer.can_merge_at(c1, st), "can_merge_at o cung loai = true")
	var star0: int = t1.star
	placer.start_build(st); placer.place(c1); placer.cancel_build()
	ok(t1.star == star0 + 1, "sao 1 -> 2", "star=%d" % t1.star)
	var dmg2: int = t1.current_damage
	sm.register_troop_purchase(st)
	placer.start_build(st); placer.place(c1); placer.cancel_build()
	ok(t1.star == 3, "sao 2 -> 3", "star=%d" % t1.star)
	ok(t1.current_damage > dmg2, "sao 3 manh hon sao 2", "%d > %d" % [t1.current_damage, dmg2])
	sm.register_troop_purchase(st)
	ok(not placer.can_merge_at(c1, st), "sao 3 khong ghep them duoc")

	print("\n--- OVERCHARGE ---")
	var cd_before: float = t1.current_attack_speed
	var gold_before: int = map.current_gold
	# Overcharge KHONG sua current_attack_speed — no nhan vao luc
	# cooldown_timer.start(). Kiem tra dung cho: co dat co + he so < 1.
	t1.overcharge(5.0)
	ok(t1.is_overcharged(), "overcharge bat co")
	ok(t1.OVERCHARGE_COOLDOWN_MULT < 1.0, "he so overcharge < 1",
		"x%.2f" % t1.OVERCHARGE_COOLDOWN_MULT)
	ok(t1.current_attack_speed == cd_before, "overcharge KHONG ghi de base cooldown")

	print("\n--- SA THAI ---")
	var c2 := _free_cell(gc, [])
	sm.register_troop_purchase(st)
	placer.start_build(st); placer.place(c2); placer.cancel_build()
	ok(gc.grid_data.has(c2), "dat thap thu hai tai %s" % str(c2))
	var g0: int = map.current_gold
	placer.enter_dismiss_mode()
	placer.dismiss_at(c2)
	await process_frame
	ok(not gc.grid_data.has(c2), "sa thai xoa thap khoi grid")
	ok(map.current_gold > g0, "sa thai hoan vang", "+%d" % (map.current_gold - g0))

	print("\n--- O LANH THO ---")
	tm.add_stock("fire")
	ok(tm.get_stock("fire") >= 1, "them kho o Mach Hoa")
	var c3 := _free_cell(gc, [])
	tm.select("fire")
	ok(tm.is_placing(), "vao che do dat o")
	var placed: bool = tm.try_place(c3, gc.grid_data, km)
	ok(placed, "dat o tai %s" % str(c3))
	ok(tm.get_element_at(c3) == "fire", "o tra ve nguyen to fire", tm.get_element_at(c3))
	ok(tm.get_tile_level(c3) == 1, "o moi = Lv1", "lv=%d" % tm.get_tile_level(c3))
	tm.add_stock("fire"); tm.select("fire")
	tm.try_place(c3, gc.grid_data, km)
	ok(tm.get_tile_level(c3) == 2, "dat de len chinh no -> Lv2", "lv=%d" % tm.get_tile_level(c3))
	var g1: int = map.current_gold
	var refund: int = tm.sell_tile_at(c3, km)
	ok(refund > 0, "ban o hoan vang", "+%d" % refund)
	ok(not tm.has_biome_at(c3), "ban xong o bien mat")

	print("\n--- SHOP: DU LOAI HANG ---")
	var kinds := {}
	for i in range(40):
		sm.refresh_shop(true)
		for o in sm.get_items():
			kinds[ShopItemData.ItemType.keys()[o.item_type]] = true
	print("     loai gap sau 40 lan roll: ", kinds.keys())
	for want in ["TROOP", "TERRITORY", "EQUIPMENT"]:
		ok(kinds.has(want), "shop co ban %s" % want)
	var troop_ok := true
	for i in range(60):
		sm.refresh_shop(true)
		var has_troop := false
		for o in sm.get_items():
			if o.item_type == ShopItemData.ItemType.TROOP: has_troop = true
		if not has_troop: troop_ok = false
	ok(troop_ok, "60 lan roll deu co it nhat 1 quan")

	print("\n--- GIA XAO SHOP ---")
	sm.reset_reroll_cost()
	var c_0: int = sm.get_reroll_cost()
	sm.refresh_shop(false)
	var c_1: int = sm.get_reroll_cost()
	ok(c_1 > c_0, "xao lan 2 dat hon", "%d -> %d" % [c_0, c_1])
	for i in range(20): sm.refresh_shop(false)
	ok(sm.get_reroll_cost() <= 40, "gia xao co tran 40", "=%d" % sm.get_reroll_cost())
	sm.reset_reroll_cost()
	ok(sm.get_reroll_cost() == c_0, "phien shop moi reset gia xao")

	print("\n== BATCH 1 FAIL=%d ==" % fail)
	quit()
