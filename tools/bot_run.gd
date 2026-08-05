extends SceneTree
# ==========================================================================
# BOT CHOI HET MOT VAN — do duong cong do kho tren GAME THAT.
#
#   godot --headless --script res://tools/bot_run.gd -- deck=xiangqi king=king_iron
#
# Bot khong "thong minh": no mua nhung gi mua duoc, dat vao o trong tot nhat
# theo BoardScore, roi bam START WAVE. Do la nguong SAN — nguoi choi that phai
# lam tot hon bot. Neu bot THANG de dang thi game qua de; neu bot khong bao gio
# song qua wave 9 thi cai gi do dang chan cung.
#
# In ra CSV mot dong moi wave de so sanh giua cac lan chay.
# ==========================================================================

const TIME_SCALE := 12.0          # ep tran danh chay nhanh
const MAX_WAVE_SECONDS := 900.0   # giay TRONG GAME; het thi bao stuck, khong treo

var map: Node = null
var gm: Node = null
var rows: Array[String] = []
var deck_id := ""
var king_id := "king_iron"
var seed_val := 0
var quiet := false
## Chien luoc mua DI VAT — day la thu can do:
##   off = khong mua di vat nao (nen tham chieu)
##   any = mua bat ky mon nao du tien (nguoi choi khong doc mo ta)
##   fit = CHI mua mon dang khop voi ban co (nguoi choi choi co chu dich)
## Neu `any` va `fit` thang bang nhau thi lua chon di vat dang VO NGHIA.
var relic_mode := "any"
## Bot CAM KET mot loi choi. Day moi la phep do dung: bot "fit" chi loc luc mua
## nhung van xay ban y het bot "any", nen tat nhien no thang bang nhau. Nguoi
## choi that chon di vat RỒI XAY BAN THEO NO.
##   lean    = giu ban MONG (<=6 quan), mua di vat an theo `few_pieces`
##   swarm   = nhoi toi da quan, an theo `many_pieces` / `pieces`
##   element = dồn het vao o nguyen to, an theo `veins`/`elements`/`vein_levels`
var build := ""
const BUILD_KEYS := {
	"lean":    ["few_pieces", "empty_squares", "deck_thin", "honed"],
	"swarm":   ["many_pieces", "pieces", "full_board", "pawns"],
	"element": ["many_veins", "veins", "vein_levels", "elements"],
}
## [so lan lot, tong sat thuong, so lan boss thoat] — Array vi lambda GDScript
## bat bien local theo GIA TRI, bien thuong se khong bao gio doi.
var _leaks: Array[int] = [0, 0, 0]


func _init() -> void:
	_parse_args()
	_run()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"deck": deck_id = kv[1]
			"king": king_id = kv[1]
			"seed": seed_val = int(kv[1])
			"quiet": quiet = kv[1] == "1"
			"relics": relic_mode = kv[1]
			"build": build = kv[1]


func say(s: String) -> void:
	if not quiet:
		print(s)


func _run() -> void:
	await process_frame
	if seed_val != 0:
		seed(seed_val)
	gm = root.get_node("/root/GameManagerSingleton")
	if gm.meta_progress:
		gm.meta_progress.seen_tutorial = true
		if deck_id != "":
			gm.meta_progress.selected_deck_id = deck_id
	gm.start_run(load("res://res/kings/%s.tres" % king_id))
	change_scene_to_file("res://scenes/map/game_map.tscn")
	await process_frame
	await process_frame
	map = root.get_node_or_null("/root/GameMap")
	if map == null:
		print("BOT_ERROR khong dung duoc game_map")
		quit(1)
		return

	# Dem so lan dich lot qua + tong sat thuong, de phan biet "thua vi ro ri dan"
	# voi "thua vi mot su kien" (boss thoat = thua ngay).
	map.wave_spawner.enemy_reached_base.connect(func(d: int) -> void:
		_leaks[0] += 1
		_leaks[1] += d)
	map.wave_spawner.boss_escaped.connect(func() -> void: _leaks[2] += 1)
	Engine.time_scale = TIME_SCALE
	var deck_name := "standard"
	if map.army_deck and map.army_deck.active_deck_id != "":
		deck_name = map.army_deck.active_deck_id
	say("BOT deck=%s king=%s" % [deck_name, king_id])
	say("wave,hp,gold,units,ratio,rd,hp_mat")

	var max_waves: int = PhaseController.MAX_WAVES
	var result := "?"
	var last_wave := 0
	for w in range(1, max_waves + 1):
		last_wave = w
		await _shop_turn()
		var hp_before: int = gm.current_health
		var line := _snapshot(w)
		if not await _fight():
			say(line + ",TIMEOUT")
			result = "TIMEOUT wave %d" % w
			break
		line += ",%d,lot=%d/%ddmg%s" % [hp_before - gm.current_health,
			_leaks[0], _leaks[1], (" BOSS_THOAT" if _leaks[2] > 0 else "")]
		_leaks = [0, 0, _leaks[2]]
		rows.append(line)
		say(line)
		if gm.current_state == gm.GameState.VICTORY:
			result = "THANG"
			break
		if gm.current_health <= 0 or map.get("_game_over_triggered") == true:
			result = "THUA wave %d" % w
			break
		if w >= max_waves:
			result = "THANG"
			break
		map.request_next_wave_phase()
		await process_frame

	Engine.time_scale = 1.0
	print("BOT_RESULT %s hp=%d wave=%d deck=%s"
		% [result, gm.current_health, last_wave, deck_name])
	quit(0)


## Di vat nay co KHOP voi ban co hien tai khong.
##
## Cham diem bang chinh cac dieu kien cua no: cong khi dieu kien dang DUNG, tru
## khi mat trai dang bat. Day la thu nguoi choi lam khi doc mo ta — bot "fit"
## mo phong nguoi choi co chu dich, bot "any" mo phong nguoi bam bua.
func _relic_fits(item) -> bool:
	var rs = map.get("relic_system")
	if rs == null or item.get("catalog_id") == null:
		return true
	var data: Dictionary = rs.relic_data(str(item.catalog_id))
	var eff: Dictionary = data.get("effect", {})
	if eff.is_empty():
		return true
	RelicConditions.invalidate()
	var facts := RelicConditions.facts(map)
	var score := 0.0
	var has_gate := false
	var cm = eff.get("cond_mult", {})
	if cm is Dictionary:
		for cid in (cm as Dictionary):
			has_gate = true
			if RelicConditions.test(str(cid), facts):
				score += float((cm as Dictionary)[cid])
	var pm = eff.get("per_mult", {})
	if pm is Dictionary:
		for kid in (pm as Dictionary):
			has_gate = true
			score += RelicConditions.count(str(kid), facts) * float((pm as Dictionary)[kid])
	if not has_gate:
		return true       # mon khong dung engine (thuoc, phan ung...) — cu mua
	if build != "":
		# Cham theo LOI CHOI da chon, khong theo ban co luc nay: di vat mua o
		# wave 5 phai duoc danh gia bang bo cuc ma minh SE xay, khong phai bo cuc
		# dang co. Do dung la thu nguoi choi lam khi doc mo ta.
		var want: Array = BUILD_KEYS.get(build, [])
		var hit := 0.0
		for cid in (cm as Dictionary) if cm is Dictionary else {}:
			if want.has(str(cid)) and float((cm as Dictionary)[cid]) > 0.0:
				hit += float((cm as Dictionary)[cid])
		for kid in (pm as Dictionary) if pm is Dictionary else {}:
			if want.has(str(kid)):
				hit += float((pm as Dictionary)[kid]) * 8.0
		# De o di vat TRONG con te hon la lap mot mon khong khop: nguoi choi that
		# se lap day roi ban di sau. Khong co dong nay thi bot "fit" thua bot
		# "any" chi vi no mua it mon hon — do la loi cua CONG CU DO, khong phai
		# ket luan ve can bang.
		var rs_n: int = (rs.get("_owned") as Array).size() if rs.get("_owned") is Array else 0
		if hit >= 0.30:
			return true
		return rs_n < 2 and score >= 0.20
	return score >= 0.25  # duoi nguong nay thi no gan nhu khong lam gi


## Mua het nhung gi mua duoc, dat het quan trong kho.
func _shop_turn() -> void:
	# Mua: uu tien quan co, roi den o nguyen to, roi vat pham.
	for _pass in range(3):
		var offers: Array = map.shop_manager.get_active_offers()
		var bought := false
		for it in offers:
			if it == null:
				continue
			var cost := int(map.shop_manager.effective_cost(it))
			if it.use_royal_decree:
				if map.king_manager == null or map.king_manager.royal_decree < cost:
					continue
			elif map.current_gold < cost:
				continue
			map.attempt_shop_purchase(it.id)
			bought = true
			await process_frame
		if not bought:
			break
	# Dat het quan trong kho.
	await _place_all()
	# Dat het o nguyen to trong kho (giup do gia tri he nguyen to).
	await _place_all_tiles()
	map.confirm_wave_ready()
	await process_frame


func _place_all() -> void:
	var guard := 0
	while guard < 40:
		guard += 1
		var stock: Dictionary = map.shop_manager.get_unit_stock_items()
		var pick := ""
		for k in stock.keys():
			if int(stock[k]) > 0:
				pick = String(k)
				break
		if pick == "":
			return
		var st: TowerStats = map.shop_manager.get_tower_stats_by_id(pick)
		if st == null:
			return
		# Build "lean" CO CHU DICH giu ban mong — do la cai gia phai tra de an
		# duoc nhung di vat keyed vao `few_pieces`.
		if build == "lean" and map.unit_count() >= 6:
			return
		var cell := _best_cell(st)
		if cell.x < 0:
			return
		map.tower_placer.start_build(st)
		map.tower_placer.place(cell)
		map.tower_placer.cancel_build()
		await process_frame


func _place_all_tiles() -> void:
	if map.territory_manager == null:
		return
	var guard := 0
	while guard < 30:
		guard += 1
		var stock: Dictionary = map.territory_manager.get_all_stock()
		var key := ""
		for k in stock.keys():
			if int(stock[k]) > 0:
				key = String(k)
				break
		if key == "":
			return
		var gc = map.grid_controller
		var spots: Array[Vector2i] = map.territory_manager.get_placeable_tiles(gc.grid_data, key)
		if spots.is_empty():
			return
		map.select_territory(key)
		map.territory_manager.try_place(spots[0], gc.grid_data, map.king_manager)
		map.territory_manager.cancel()
		await process_frame


## O trong phu duoc NHIEU o duong nhat — do la thuoc do duy nhat quan trong.
func _best_cell(st: TowerStats) -> Vector2i:
	var gc = map.grid_controller
	var best := Vector2i(-1, -1)
	var best_score := -1
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if not _free(c):
				continue
			var s := _coverage_score(c, st)
			if s > best_score:
				best_score = s
				best = c
	return best


## `is_buildable` chi kiem trong-bien + khong-phai-duong; no KHONG kiem o da co
## quan. Bot phai tu kiem, neu khong no don het vao MOT o roi ghep sao lien tuc.
func _free(c: Vector2i) -> bool:
	if not map.tower_placer.is_buildable(c):
		return false
	var v = map.grid_controller.grid_data.get(c)
	return not (v is Node)


func _coverage_score(cell: Vector2i, st: TowerStats) -> int:
	var gc = map.grid_controller
	var kind: int = int(st.attack_pattern) if st.get("attack_pattern") != null else 0
	var rng: int = int(st.attack_range)
	var cells: Array = ChessPattern.cells(kind, cell, rng, {})
	var n := 0
	for c in cells:
		if gc.is_path_cell(c):
			n += 1
	return n


func _best_empty_cell() -> Vector2i:
	var gc = map.grid_controller
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var c := Vector2i(x, y)
			if _free(c):
				return c
	return Vector2i(-1, -1)


func _snapshot(w: int) -> String:
	var ratio := 0.0
	if map.has_method("board_summary"):
		var bs: Dictionary = map.board_summary()
		ratio = float(bs.get("ratio", 0.0))
	var rd := 0.0
	if map.king_manager:
		rd = map.king_manager.royal_decree
	# Wave boss: in RIENG ti le sat thuong len boss. Do la dieu kien thang thuc
	# su cua wave do — boss cham King la THUA NGAY, khong phai mat vai mau.
	# Do GIA TRI THAT cua di vat: so mon dang so huu + phan Boi chung dong gop.
	var rl_n := 0
	var rl_mult := 1.0
	var rs_p = map.get("relic_system")
	if rs_p != null and rs_p.get("_owned") is Array:
		rl_n = (rs_p.get("_owned") as Array).size()
	var gm_p = root.get_node_or_null("/root/GameManagerSingleton")
	if gm_p != null:
		RelicConditions.invalidate()
		var fx := RelicConditions.facts(map)
		var b := 0.0
		var cmv = gm_p.get("relic_cond_mult")
		if cmv is Dictionary:
			for cid in (cmv as Dictionary):
				if RelicConditions.test(str(cid), fx):
					b += float((cmv as Dictionary)[cid])
		var pmv = gm_p.get("relic_per_mult")
		if pmv is Dictionary:
			for kid in (pmv as Dictionary):
				b += RelicConditions.count(str(kid), fx) * float((pmv as Dictionary)[kid])
		rl_mult = 1.0 + b
	var bstr := ",divat=%d/x%.2f" % [rl_n, rl_mult]
	var bs2 = map.board_score
	if bs2 != null:
		# Do sat thuong don-muc-tieu o MOI wave (dung wave boss gan nhat lam mau)
		# de thay xu huong: no co lon len theo doi hinh khong?
		var probe: int = 5
		for bw in map.wave_spawner.BOSS_WAVES:
			if int(bw) <= w:
				probe = int(bw)
		var bdmg: float = bs2.damage_to_boss(probe)
		var bhp: float = bs2._boss_hp_only(w) if map.wave_spawner.is_boss_wave(w) else 0.0
		bstr += ",dmg1t=%.0f" % bdmg
		if bhp > 1.0:
			bstr += ",BOSS %.0f/%.0f=%.2f" % [bs2.damage_to_boss(w), bhp, bs2.damage_to_boss(w) / bhp]
	return "%d,%d,%d,%d,%.2f,%.1f%s" % [
		w, gm.current_health, map.current_gold, map.unit_count(), ratio, rd, bstr]


func _fight() -> bool:
	if not map.request_start_wave():
		print("BOT_ERROR khong bam duoc START WAVE o wave nay")
		return false
	# Ngan sach tinh bang GIAY TRONG GAME, khong phai so frame: headless chay
	# frame rong rat nhanh nen 150k frame co the chi la vai chuc giay game.
	var t := 0.0
	while t < MAX_WAVE_SECONDS:
		t += get_root().get_process_delta_time() * Engine.time_scale
		await process_frame
		if gm.current_health <= 0 or map.get("_game_over_triggered") == true:
			return true
		if map.phase_controller.current_phase != PhaseController.GamePhase.WAVE:
			return true
		# THANG di qua `force_victory()` va pha VAN o WAVE (enter_shop_phase
		# `return` ngay sau khi bao thang). Khong kiem cho nay thi bot ngoi doi
		# het ngan sach roi bao "TIMEOUT" cho mot van da THANG.
		if gm.current_state == gm.GameState.VICTORY:
			return true
	var alive := get_nodes_in_group("enemies")
	var names: Array[String] = []
	for e in alive:
		if is_instance_valid(e):
			names.append(str(e.name))
	print("BOT_STUCK wave khong ket thuc sau %.0fs game — con %d dich: %s"
		% [t, alive.size(), ", ".join(names)])
	return false
