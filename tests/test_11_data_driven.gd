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
	var probe := Node.new(); root.add_child(probe)
	sm.on_tower_placed(probe, st)
	ok(sm.active_synergies.has("nhanh_moi_hoan_toan"),
		"dem duoc nhanh khai bang chuoi", str(sm.active_synergies.keys()))

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

	print("\n== BATCH 11 FAIL=%d ==" % fail)
	quit()
