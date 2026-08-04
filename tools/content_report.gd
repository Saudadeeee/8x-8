extends SceneTree
# Bang kiem ke NOI DUNG — dem qua chinh he thong nap cua game (ContentLoader,
# bang cung, FeatureFlags) chu khong doc file tho. Doc file tho dem sai: .tres
# BO QUA field trung gia tri mac dinh, nen `rarity`/`cost` khong hien ra trong
# file van co gia tri that.
#
#   godot --headless --script res://tools/content_report.gd

func _init() -> void: _r()

func _line(t: String) -> void: print(t)

func _r() -> void:
	await process_frame
	var gm = root.get_node("/root/GameManagerSingleton")
	if gm.meta_progress: gm.meta_progress.seen_tutorial = true
	gm.start_run(load("res://res/kings/king_iron.tres"))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame; await process_frame
	var map = root.get_node_or_null("/root/GameMap")
	var ws = map.wave_spawner

	_line("\n=== QUAN CO ===")
	var by_kind := {}
	var d := DirAccess.open("res://res/towers/")
	var n_tower := 0
	for f in d.get_files():
		var cn := f.trim_suffix(".remap")
		if not cn.ends_with(".tres") or cn.begins_with("_"): continue
		var st := load("res://res/towers/" + cn) as TowerStats
		if st == null: continue
		n_tower += 1
		var k := ChessPattern.label(int(st.attack_pattern))
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	_line("tong: %d quan / %d nuoc di khai bao" % [n_tower, by_kind.size()])
	for k in by_kind: _line("  %-46s %d" % [k, by_kind[k]])
	_line("nuoc di CO TRONG ENGINE: %d" % ChessPattern.Kind.size())
	var unused: Array[String] = []
	for k in ChessPattern.Kind.values():
		if not by_kind.has(ChessPattern.label(int(k))):
			unused.append(ChessPattern.label(int(k)))
	if not unused.is_empty():
		_line("  nuoc di KHONG quan nao dung: %s" % ", ".join(unused))

	_line("\n=== DICH ===")
	var n_e := 0; var n_boss := 0
	for f in DirAccess.open("res://res/enemy/").get_files():
		var cn := f.trim_suffix(".remap")
		if not cn.ends_with(".tres"): continue
		if cn.begins_with("boss_"): n_boss += 1
		else: n_e += 1
	_line("linh thuong: %d | Rival King: %d" % [n_e, n_boss])
	_line("wave boss: %s / tong %d wave" % [str(ws.BOSS_WAVES), PhaseController.MAX_WAVES])

	_line("\n=== VAT PHAM (qua he thong nap that) ===")
	var rs = map.get("relic_system")
	var es = map.get("equipment_system")
	var ps = map.get("potion_system")
	if rs: _line("di vat  : %d" % rs._catalog.size())
	if es: _line("trang bi: %d" % es._catalog.size())
	if ps: _line("thuoc   : %d" % (ps.get("_all_potions") as Array).size())
	if rs:
		var by_r := {}
		var rule_keys := ["rook_as_cannon", "pawn_pattern", "star3_pattern", "knight_reach",
			"pierce_count", "equip_share", "tile_spread", "vein_spread", "plain_tile_mult",
			"surround_mult", "endgame_mult", "variety_mult", "pawn_tithe", "max_marks",
			"no_consume_chance", "elite_always_drop", "equip_stack_mult"]
		var n_rule := 0
		for id in rs._catalog:
			var e: Dictionary = rs._catalog[id]
			var r := str(e.get("rarity", "?"))
			by_r[r] = int(by_r.get(r, 0)) + 1
			for k in rule_keys:
				if (e.get("effect", {}) as Dictionary).has(k):
					n_rule += 1
					break
		_line("  di vat DOI LUAT: %d | cong chi so: %d" % [n_rule, rs._catalog.size() - n_rule])
		_line("  theo bac: %s" % str(by_r))
		_line("  khoa hieu ung duoc CHAP NHAN (EFFECT_KEYS): %d" % rs.EFFECT_KEYS.size())

	_line("\n=== PERK ===")
	var pk = map.get("perk_system")
	if pk:
		var pool = pk.get("_all_perks")
		if pool is Array:
			var by_rar := {}
			for p in pool:
				var r := str((p as Dictionary).get("rarity", "?"))
				by_rar[r] = int(by_rar.get(r, 0)) + 1
			_line("tong: %d | theo bac: %s" % [(pool as Array).size(), str(by_rar)])
		_line("mo khoa theo wave: %s | rut %d la moi lan draft"
			% [str(pk.RARITY_UNLOCK_WAVE), pk.DRAFT_SIZE])

	_line("\n=== THE CO (dò theo HINH HOC QUAN) ===")
	_line("tong: %d" % ChessFormations.SPEC.size())
	for id in ChessFormations.SPEC:
		var sp: Dictionary = ChessFormations.SPEC[id]
		_line("  %-14s x%-5s %s" % [id, str(sp.get("mult", 1.0)), str(sp.get("name", ""))])

	_line("\n=== HINH THE O NGUYEN TO (dò theo O) ===")
	_line("tong: %d — %s" % [FormationDetector.ALL_IDS.size(), str(FormationDetector.ALL_IDS)])

	_line("\n=== HE NGUYEN TO ===")
	_line("nguyen to: %d — %s" % [ElementTypes.SPEC.size(), str(ElementTypes.SPEC.keys())])
	_line("phan ung  : %d" % ReactionTable.TABLE.size())
	_line("cap o     : %d" % TerritoryManager.LEVEL_BONUS.size())

	_line("\n=== VUA / BO KHAI CUOC / LUAT RIVAL KING ===")
	var nk := 0
	for f in DirAccess.open("res://res/kings/").get_files():
		if f.trim_suffix(".remap").ends_with(".tres"): nk += 1
	var nd := 0
	for f in DirAccess.open("res://res/decks/").get_files():
		if f.trim_suffix(".remap").ends_with(".tres"): nd += 1
	_line("Vua choi duoc: %d | Bo khai cuoc: %d | Luat Rival King: %d"
		% [nk, nd, KingRules.RULES.size()])
	for id in KingRules.RULES:
		var r: Dictionary = KingRules.RULES[id]
		_line("  %-14s %-18s [%s]" % [id, str(r.get("name", "")), str(r.get("kind", ""))])

	_line("\n=== SYNERGY / ENCOUNTER / META ===")
	var ns := 0
	for f in DirAccess.open("res://res/synergies/").get_files():
		if f.trim_suffix(".remap").ends_with(".tres"): ns += 1
	_line("synergy loai quan: %d  (DA TAT: %s)" % [ns, str(not FeatureFlags.UNIT_SYNERGY_ENABLED)])
	var em = map.get("encounter_manager")
	if em and em.get("all_encounters") is Array:
		_line("encounter: %d" % (em.get("all_encounters") as Array).size())
	var gmm = load("res://scripts/managers/GameManager.gd")
	var mu = gmm.get("META_UPGRADES")
	if mu is Dictionary: _line("nang cap meta: %d truc" % (mu as Dictionary).size())

	_line("\n=== HE DA TAT BANG CO ===")
	var off: Array[String] = []
	var on: Array[String] = []
	for k in FeatureFlags.ALL:
		if bool(FeatureFlags.ALL[k]): on.append(str(k))
		else: off.append(str(k))
	_line("BAT (%d): %s" % [on.size(), ", ".join(on)])
	_line("TAT (%d): %s" % [off.size(), ", ".join(off)])

	_line("\n=== DUONG CONG DO KHO ===")
	var s := ""
	for w in range(1, PhaseController.MAX_WAVES + 1):
		s += "%d:%.0f " % [w, ws.target_wave_hp(w)]
	_line("mau muc tieu moi wave: " + s)
	_line("ban %dx%d | tran quan %d (+%.1f/wave, tran %d)"
		% [map.grid_controller.grid_width, map.grid_controller.grid_height,
		   map.MAX_UNITS_BASE, map.MAX_UNITS_PER_WAVE, map.MAX_UNITS_CAP])
	quit()
