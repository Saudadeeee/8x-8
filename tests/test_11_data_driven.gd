extends SceneTree
# BATCH 11 — noi dung phai TAO DUOC BANG KEO THA, khong dung toi GDScript.
#
# Moi khang dinh o day chot mot duong da duoc go khoi code. Neu ai do them lai
# mot bang cung thi test nay do ngay.
var fail := 0
func _init() -> void: _run()
func ok(c: bool, l: String, e: String = "") -> void:
	if c: print("  OK   ", l, ("  " + e) if e != "" else "")
	else: print("  FAIL ", l, "  ", e); fail += 1

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return ""
	var s := f.get_as_text(); f.close(); return s

func _run() -> void:
	await process_frame

	print("\n--- SYNERGY: dinh nghia nam trong .tres ---")
	var files := DirAccess.get_files_at("res://res/synergies")
	var n := 0
	for f in files:
		if f.ends_with(".tres"): n += 1
	ok(n >= 14, "co file synergy tren dia", "%d file" % n)
	var sm := SynergyManager.new()
	root.add_child(sm)
	await process_frame
	ok(sm.synergy_definitions.size() >= 14, "SynergyManager nap tu dia",
		"%d dinh nghia" % sm.synergy_definitions.size())
	var d := load("res://res/synergies/pawn.tres") as SynergyDefinition
	ok(d != null and d.thresholds.size() > 0, "noi dung .tres doc duoc")

	print("\n--- THAP: nhanh synergy MOI khong can sua enum ---")
	var st := TowerStats.new()
	st.type = TowerStats.UnitType.PAWN
	st.synergy_tag = "nhanh_moi_hoan_toan"
	ok(st.get_synergy_tag() == "nhanh_moi_hoan_toan",
		"synergy_tag chuoi thang enum", st.get_synergy_tag())
	var st2 := TowerStats.new()
	st2.type = TowerStats.UnitType.ROOK
	ok(st2.get_synergy_tag() == "rook", "de rong van suy tu enum (tuong thich nguoc)")
	# Synergy theo LOAI QUAN da TAT bang co — ChessFormations thay the.
	# Van kiem `get_synergy_tag()` o tren: co the bat lai bat cu luc nao.
	var probe := Node.new(); root.add_child(probe)
	sm.on_tower_placed(probe, st)
	ok(not FeatureFlags.UNIT_SYNERGY_ENABLED, "synergy loai quan da tat")
	ok(sm.active_synergies.is_empty(),
		"da tat thi khong dem synergy nao", str(sm.active_synergies.keys()))

	print("\n--- DICH: lich mua nam trong .tres, khong con bang cung ---")
	var src := _read("res://scripts/map/wave_spawner.gd")
	var hard := src.count("_get_enemy(\"")
	ok(hard <= 3, "gan het loi goi _get_enemy cung da bi go", "%d lan con lai" % hard)
	var ws := WaveSpawner.new()
	root.add_child(ws)
	await process_frame
	var seasons_ok := true
	var detail := ""
	for w in [1, 4, 7, 10]:
		var pool: Array = ws._get_season_enemy_pool(w)
		if pool.is_empty(): seasons_ok = false
		detail += "w%d=%d " % [w, pool.size()]
	ok(seasons_ok, "moi mua deu co pool sinh tu du lieu", detail)

	# Moi loai dich (tru boss) phai TU KHAI lich spawn trong .tres cua no
	var missing := ""
	for f in DirAccess.get_files_at("res://res/enemy"):
		if not f.ends_with(".tres") or f.begins_with("boss_"): continue
		var es = load("res://res/enemy/" + f) as EnemyStats
		if es == null: continue
		if es.spawn_seasons.is_empty(): missing += es.id + " "
	ok(missing == "", "moi loai dich tu khai spawn_seasons trong .tres", missing)

	# Ai luc nguyen to cung phai nam trong .tres
	var no_aff := ""
	for f in DirAccess.get_files_at("res://res/enemy"):
		if not f.ends_with(".tres") or f.begins_with("boss_"): continue
		var es = load("res://res/enemy/" + f) as EnemyStats
		if es == null: continue
		if es.weak_element == "": no_aff += es.id + " "
	ok(no_aff == "", "moi loai dich tu khai diem yeu trong .tres", no_aff)

	print("
--- VAT PHAM: mo duoc bang Inspector (.tres) ---")
	# Bon thu muc .tres la NGUON CHINH. JSON va bang cung trong .gd chi con la
	# tuong thich nguoc / luoi an toan.
	var counts := {
		"potions": 20, "equipment": 20, "relics": 12, "perks": 25,
	}
	for folder in counts:
		var cnt := 0
		for f in DirAccess.get_files_at("res://res/" + folder):
			if f.trim_suffix(".remap").ends_with(".tres"): cnt += 1
		ok(cnt >= int(counts[folder]), "res/%s co du file .tres" % folder,
			"%d file" % cnt)

	var ps := PotionSystem.new(); root.add_child(ps)
	var es := EquipmentSystem.new(); root.add_child(es)
	var rs := RelicSystem.new(); root.add_child(rs)
	var pk := PerkSystem.new(); root.add_child(pk)
	await process_frame
	pk._initialize_perk_pool()
	ok(ps.all_ids().size() >= 20, "he thuoc nap du", "%d" % ps.all_ids().size())
	ok(es.all_ids().size() >= 20, "he trang bi nap du", "%d" % es.all_ids().size())
	ok(rs.all_ids().size() >= 12, "he di vat nap du", "%d" % rs.all_ids().size())
	ok(pk._all_perks.size() >= 25, "he perk nap du", "%d" % pk._all_perks.size())

	# Moi Resource phai co to_dict() — thieu thi ContentLoader bo qua yen lang
	for cls_path in ["res://res/potions", "res://res/equipment",
			"res://res/relics", "res://res/perks"]:
		var res_files := DirAccess.get_files_at(cls_path)
		if res_files.is_empty(): continue
		var first := load(cls_path + "/" + res_files[0].trim_suffix(".remap"))
		ok(first != null and first.has_method("to_dict"),
			"%s: Resource co to_dict()" % cls_path.get_file())

	print("
--- THEM MON MOI CHI BANG MOT FILE ---")
	var nr := RelicData.new()
	nr.id = "zz_kiem_tra"
	nr.name = "Di Vat Kiem Tra"
	nr.desc = "Sinh trong test."
	nr.rarity = "rare"
	nr.cost = 150
	nr.effect = {"reaction_mult": 1.1}
	var save_err := ResourceSaver.save(nr, "res://res/relics/zz_kiem_tra.tres")
	ok(save_err == OK, "luu duoc .tres moi")
	var rs2 := RelicSystem.new(); root.add_child(rs2)
	await process_frame
	ok(rs2.all_ids().has("zz_kiem_tra"),
		"mon moi vao catalog ma KHONG dung toi code")
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("res://res/relics/zz_kiem_tra.tres"))

	print("
== BATCH 11 FAIL=%d ==" % fail)
	quit()
