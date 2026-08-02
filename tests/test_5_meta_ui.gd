extends SceneTree
# BATCH 5 — perk / King / encounter / meta-save / moi man UI load duoc.
var fail := 0
var _pending = null
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1

func _run() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")

	print("\n--- MOI MAN UI LOAD DUOC ---")
	for f in ["main_menu", "king_select", "game_hud", "encounter_screen",
			  "game_over_screen", "victory_screen", "meta_progression", "settings_screen"]:
		var p := "res://scenes/ui/%s.tscn" % f
		var packed: PackedScene = load(p)
		if packed == null:
			ok(false, "load %s" % f); continue
		var inst = packed.instantiate()
		if inst == null:
			ok(false, "instantiate %s" % f); continue
		root.add_child(inst)
		await process_frame
		ok(is_instance_valid(inst), "man %s dung duoc" % f)
		inst.queue_free()
		await process_frame

	print("\n--- KING ---")
	var kings := ["king_iron", "king_phantom", "king_flame",
		"king_storm", "king_frost", "king_merchant"]
	for k in kings:
		var p := "res://res/kings/%s.tres" % k
		ok(ResourceLoader.exists(p), "co %s.tres" % k)

	# Man chon vua QUET thu muc, khong doc danh sach cung — them vua chi can tha
	# mot .tres vao res/kings/. Khang dinh nay chan viec ai do quay lai liet ke
	# cung: them file moi ma man hinh khong thay thi vua do coi nhu khong ton tai.
	var scanned: Array = load("res://scripts/ui/king_select.gd").call("_load_all_kings")
	var scanned_ids := {}
	for k in scanned:
		scanned_ids[k.id] = k
	var scan_missing := ""
	for k in kings:
		if not scanned_ids.has(k):
			scan_missing += k + " "
	ok(scan_missing == "", "man chon vua quet du %d vua tu thu muc" % kings.size(),
		scan_missing)

	# Moi vua phai co ability_script CHAY DUOC. Thieu script thi executor roi ve
	# nhanh hardcoded theo king_id — vua moi khong co nhanh do nen chieu se im
	# lang khong lam gi, va khong ai thay vi game van chay binh thuong.
	var ab_bad := ""
	for kid in scanned_ids:
		var ks: KingStats = scanned_ids[kid]
		if ks.ability_script == null:
			ab_bad += "%s thieu script " % kid
			continue
		var inst: Object = ks.ability_script.new()
		if inst == null or not inst.has_method("execute"):
			ab_bad += "%s script khong co execute() " % kid
	ok(ab_bad == "", "moi vua co ability_script dung duoc", ab_bad)

	# Chan dung RIENG cho tung vua. Truoc day ca 6 vua render cung mot model
	# king.gltf nen nhin khong phan biet duoc ai voi ai — them vua moi cung vo
	# nghia ve mat hinh anh. Trung anh giua hai vua cung tinh la loi.
	var por_bad := ""
	var seen_por := {}
	for kid in scanned_ids:
		var ks2: KingStats = scanned_ids[kid]
		if ks2.portrait == null:
			por_bad += "%s thieu chan dung " % kid
			continue
		var rp := ks2.portrait.resource_path
		if seen_por.has(rp):
			por_bad += "%s dung chung anh voi %s " % [kid, seen_por[rp]]
		seen_por[rp] = kid
	ok(por_bad == "", "moi vua co chan dung rieng", por_bad)
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	if map == null: print("FATAL"); quit(); return
	var km = map.king_manager
	map.current_gold = 100000
	gm.encounter_triggered.connect(func(e): _pending = e)   # _pending la bien THANH VIEN nen gan duoc

	var rd0: float = km.get_current_royal_decree()
	km.grant_wave_clear_decree()
	ok(km.get_current_royal_decree() > rd0, "het wave duoc cong Sac Lenh",
		"%.1f -> %.1f" % [rd0, km.get_current_royal_decree()])
	km.add_royal_decree(9999.0)
	var cap: float = km.decree_cap
	ok(cap > 0.0 and km.get_current_royal_decree() <= cap, "Sac Lenh co tran",
		"%.1f/%.1f" % [km.get_current_royal_decree(), cap])
	ok(km.can_afford(1.0), "can_afford dung khi du tien")
	var before: float = km.get_current_royal_decree()
	ok(km.spend_royal_decree(5.0), "tieu Sac Lenh")
	ok(abs(km.get_current_royal_decree() - (before - 5.0)) < 0.01, "tru dung so")
	ok(not km.spend_royal_decree(99999.0), "khong tieu qua so co")

	print("\n--- KING ABILITY ---")
	km.add_royal_decree(500.0)
	var ready: bool = km.is_ability_ready()
	print("     ability ready = ", ready)
	# Luong that: km.use_ability() -> signal ability_activated ->
	# game_map._on_king_ability_activated -> KingAbilityExecutor.execute()
	var exec_node = map.king_ability_executor
	ok(exec_node != null, "co KingAbilityExecutor")
	# BAY: lambda GDScript bat bien local theo GIA TRI — gan vao String local
	# trong lambda KHONG ra duoc ngoai. Phai dung Array (object, bat theo tham chieu).
	var executed: Array[String] = []
	if exec_node:
		exec_node.ability_executed.connect(func(kid: String): executed.append(kid))
	ok(km.use_ability(), "kich hoat ky nang Vua")
	await process_frame
	ok(not executed.is_empty(), "executor thuc su chay", str(executed))
	ok(not km.is_ability_ready(), "ky nang vao hoi chieu sau khi dung")
	# Ca 3 Vua deu phai chay duoc ky nang (goi thang executor de bo qua hoi chieu)
	for kid in ["king_iron", "king_phantom", "king_flame"]:
		gm.selected_king = load("res://res/kings/%s.tres" % kid)
		executed.clear()
		if exec_node: exec_node.execute()
		await process_frame
		ok(executed.has(kid), "ky nang cua %s chay duoc" % kid, str(executed))

	print("\n--- PERK ---")
	var ps = map.perk_system
	ok(ps != null, "co PerkSystem")
	if ps:
		var by_rarity := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
		for p in ps._all_perks:
			var r := str(p.get("rarity", "?"))
			if by_rarity.has(r): by_rarity[r] += 1
		print("     pool: ", by_rarity)
		ok(int(by_rarity["common"]) >= 3, "du perk thuong cho wave dau")
		ok(int(by_rarity["legendary"]) >= 1, "co perk huyen thoai")
		# Moi perk phai co kenh tac dung
		var dead: Array[String] = []
		for p in ps._all_perks:
			var has_ch := false
			for ch in ps.EFFECT_CHANNELS.keys():
				if p.has(ch): has_ch = true
			if not has_ch: dead.append(str(p.get("id")))
		ok(dead.is_empty(), "moi perk co it nhat 1 kenh tac dung", str(dead))
		# Chon perk -> phai vao danh sach so huu
		ps.set_wave(1)
		var d: Array = ps.roll_draft()
		ok(d.size() == 3, "draft ra 3 la", "%d" % d.size())
		var pid := str(d[0].get("id", ""))
		ok(ps.pick(pid), "chon duoc perk")
		ok(ps.owned.has(pid), "perk vao danh sach so huu")
		# Perk `stackable` CO THE chon lai — chi perk thuong moi bi chan.
		var stackable: bool = bool(d[0].get("stackable", false))
		if stackable:
			ok(ps.pick(pid), "perk stackable chon lai duoc", pid)
		else:
			ok(not ps.pick(pid), "perk khong stackable thi khong chon lai duoc", pid)
		# Perk tang sat thuong phai that su vao thap
		var st: TowerStats = load("res://res/towers/pawn.tres")
		map.shop_manager.register_troop_purchase(st)
		var gc = map.grid_controller
		var c := Vector2i(-1, -1)
		for y in range(gc.grid_height):
			for x in range(gc.grid_width):
				var cc := Vector2i(x, y)
				if not gc.is_path_cell(cc) and not gc.grid_data.has(cc): c = cc; break
			if c.x >= 0: break
		map.tower_placer.start_build(st); map.tower_placer.place(c); map.tower_placer.cancel_build()
		var tw = gc.grid_data.get(c)
		if tw:
			var dmg0: int = tw.current_damage
			var found := ""
			for p in ps._all_perks:
				var t: Dictionary = p.get("tower", {})
				if t.has("damage_bonus") and float(t["damage_bonus"]) > 0 and not ps.owned.has(p.get("id")):
					found = str(p.get("id")); break
			if found != "":
				ps.pick(found)
				await process_frame
				ok(tw.current_damage > dmg0, "perk sat thuong THUC SU vao thap",
					"%d -> %d (%s)" % [dmg0, tw.current_damage, found])
			else: print("     (khong con perk damage chua so huu)")

	print("\n--- ENCOUNTER ---")
	var em = map.encounter_manager
	ok(em != null, "co EncounterManager")
	if em:
		var n: int = em.all_encounters.size()
		print("     so encounter: ", n)
		ok(n >= 9, "co >= 9 encounter", "%d" % n)
		var bad: Array[String] = []
		for e in em.all_encounters:
			if e == null or e.choices.is_empty(): bad.append(str(e))
		ok(bad.is_empty(), "moi encounter co it nhat 1 lua chon", str(bad))
		# Encounter loc theo gm.current_wave; truoc wave dau no = 0 nen khong
		# encounter nao du dieu kien. Thuc te encounter chi trigger tu wave 3.
		gm.current_wave = 3
		ok(em._get_available_encounters().size() >= 9, "wave 3 co >= 9 encounter kha dung",
			"%d" % em._get_available_encounters().size())
		em.trigger_random_encounter()
		await process_frame
		ok(_pending != null, "trigger_random_encounter phat signal")
		if _pending != null:
			em.resolve_choice(_pending.choices[0])
			await process_frame
			ok(true, "resolve_choice chay khong crash")

	print("\n--- META SAVE ---")
	ok(gm.meta_progress != null, "co meta_progress")
	if gm.meta_progress:
		var runs0: int = gm.meta_progress.total_runs
		gm._update_meta_on_run_end(false)
		ok(gm.meta_progress.total_runs == runs0 + 1, "ket thuc run tang bo dem",
			"%d -> %d" % [runs0, gm.meta_progress.total_runs])
		var err := ResourceSaver.save(gm.meta_progress, "user://meta_progress.tres")
		ok(err == OK, "luu meta thanh cong", "err=%d" % err)
		var reloaded = load("user://meta_progress.tres")
		ok(reloaded != null and reloaded.total_runs == gm.meta_progress.total_runs,
			"doc lai meta dung so lieu")

	print("\n--- SAVE HONG PHAI TU PHUC HOI ---")
	# Mat dien giua luc ghi save de lai file cut. Truoc day load_or_create() tra
	# null va toan bo tien trinh meta chet cam vinh vien (khong crash nen khong
	# ai biet). Nay phai luon tra ve mot MetaProgress dung duoc.
	var MP = load("res://scripts/resources/MetaProgress.gd")
	var bad_cases: Array[String] = [
		"rac khong phai resource",
		"",
		"[gd_resource type=\"Resource\" format=3]",
	]
	for bad_text in bad_cases:
		var bf := FileAccess.open(MP.SAVE_PATH, FileAccess.WRITE)
		bf.store_string(bad_text)
		bf.close()
		var got = MP.load_or_create()
		ok(got != null and got is MetaProgress,
			"save hong -> van tra ve MetaProgress dung duoc", str(got))
	# Ghi lai save sach de khong de rac cho lan chay sau
	var fresh = MP.new()
	fresh.save()
	ok(ResourceLoader.exists(MP.SAVE_PATH), "ghi lai duoc save sach sau khi hong")


	print("\n== BATCH 5 FAIL=%d ==" % fail)
	quit()
