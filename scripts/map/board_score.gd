# res://scripts/map/board_score.gd
#
# NỀN × BỘI — công thức chấm điểm của cả game.
#
# Vì sao phải có: trước đây sát thương là tổng của 13 lớp buff cộng dồn, nhân
# mùa, nhân sao, nhân ái lực, rồi kẹp trần. Không ai nhẩm nổi, kể cả người viết
# ra nó. Không nhẩm được thì không tối ưu được, mà không tối ưu được thì mọi hệ
# thống bên trên (thế cờ, ô nguyên tố, di vật) chỉ là số ngẫu nhiên nhảy múa.
#
# Balatro giải bài này bằng đúng HAI con số: Chip × Bội. Mọi vật phẩm trong game
# chỉ sửa một trong hai, hoặc sửa cách tính hai số đó. Đây là bản dịch sang cờ:
#
#     NỀN(ô)  = Σ sát-thương-mỗi-giây của mọi quân ĐANG PHỦ ô đó
#     BỘI(ô)  = tích các hệ số: thế cờ × cấp ô nguyên tố × di vật × luật Vua
#     ĐIỂM(ô) = NỀN × BỘI
#
# Và con số người chơi thật sự cần:
#
#     SÁT THƯƠNG LÊN MỘT ĐỊCH = Σ ĐIỂM(ô) / tốc_độ_địch   với ô ∈ đường đi
#
# Vì địch đi qua TỪNG ô đường với tốc độ v (ô/giây) nên nó đứng trong tầm mỗi ô
# đúng 1/v giây. Phép tính này đúng về vật lý, không phải hệ số bịa — nên con số
# hiện trên HUD so thẳng được với máu địch. Đó chính là "ngưỡng Blind" của
# Balatro: một CON SỐ để tối ưu tới, thay cho "sống sót" mơ hồ.
class_name BoardScore
extends Node

## Bội tối đa cho một ô. Không chặn thì thế cờ × ô Lv3 × di vật × phản ứng có
## thể nhân nhau tới ba chữ số và mọi cân bằng wave thành vô nghĩa.
## Đặt cao (không phải 4.0 như trần cũ) vì Balatro SỐNG nhờ việc bị phá vỡ —
## đây là lan can, không phải trần thiết kế.
const MAX_CELL_MULT: float = 60.0

## HỆ SỐ HIỆU DỤNG — đo được, không phải chọn cho đẹp.
##
## Công thức "DPS × thời gian có mục tiêu" luôn lạc quan hơn thực tế vì ba thứ
## nó không mô hình hoá được:
##   • nhiều quân cùng bắn một con địch → sát thương thừa đổ đi;
##   • đạn có thời gian bay, địch đã rời ô khi đạn tới;
##   • đầu và cuối wave rất ít địch trên bàn nên quân đứng không.
## Mô hình hoá cả ba thì công thức hết đọc được — mà đọc được mới là mục đích.
##
## Cách hiệu chỉnh: chạy bot qua nhiều wave, tìm hệ số sao cho **tỉ lệ 1.0 trùng
## đúng ranh giới sống/chết**. Đo được: bot giữ nguyên 20 máu qua wave 1-3 rồi
## thủng ở wave 4 (wave boss) → hệ số phải đưa wave 3 lên ~1.0 và wave 4 xuống
## dưới 1.0. Đó là con số dưới đây.
## PHẢI ĐO LẠI sau mỗi lần đổi nhịp wave, chỉ số quân hoặc số địch mỗi wave —
## nó là hằng số thực nghiệm, không phải hằng số thiết kế.
const EFFICIENCY: float = 0.55

var map: Node3D = null


static func attach(target: Node3D) -> BoardScore:
	var bs := BoardScore.new()
	bs.name = "BoardScore"
	bs.map = target
	target.add_child(bs)
	return bs


# ── Nền ─────────────────────────────────────────────────────────────────────

## Sát thương mỗi giây một quân đóng góp (đã tính số đạn và hồi chiêu).
static func tower_dps(t: Node) -> float:
	if not is_instance_valid(t) or t.get("stats") == null:
		return 0.0
	var cd: float = maxf(0.05, float(t.current_attack_speed))
	var shots: int = maxi(1, int(t.stats.projectile_count))
	return float(t.current_damage) * float(shots) / cd


## DPS thực lên một mục tiêu CÓ GIÁP. Giáp trừ PHẲNG mỗi phát (sàn 1), nên nó
## trừng phạt quân bắn nhanh - sát thương nhỏ nặng hơn hẳn quân bắn chậm - nặng
## đòn: Rival King giáp 10 nuốt 83% sát thương của một con Tốt (12 → 2) nhưng
## chỉ 12% của Ballista (85 → 75).
##
## `tower_dps` bỏ qua hoàn toàn điều này. Với đàn lính thường thì EFFICIENCY hấp
## thụ được sai số, nhưng với Rival King thì không: đo được mô hình báo tỉ lệ
## 1.24 ("vừa đủ hạ") trong khi bàn thật để boss chạm King ⇒ THUA NGAY. Con số
## dưới màn hình nói dối đúng vào ba wave quan trọng nhất ván.
static func tower_dps_vs_armor(t: Node, armor: float) -> float:
	if not is_instance_valid(t) or t.get("stats") == null:
		return 0.0
	var cd: float = maxf(0.05, float(t.current_attack_speed))
	var shots: int = maxi(1, int(t.stats.projectile_count))
	var per_shot: float = maxf(1.0, float(t.current_damage) - maxf(0.0, armor))
	return per_shot * float(shots) / cd


## NỀN của một ô = tổng DPS của mọi quân phủ ô đó.
func cell_base(cell: Vector2i) -> float:
	var total := 0.0
	for t in _towers():
		if t.has_method("covers_cell") and t.covers_cell(cell):
			total += tower_dps(t)
	return total


# ── Bội ─────────────────────────────────────────────────────────────────────

## BỘI của một ô — tích mọi nguồn khuếch đại đang áp lên ô đó.
## Trả về ≥ 1.0; ô không có gì đặc biệt thì đúng bằng 1.0.
func cell_mult(cell: Vector2i) -> float:
	var m := 1.0
	for entry in mult_breakdown(cell):
		m *= float(entry.get("mult", 1.0))
	return minf(m, MAX_CELL_MULT)


## Từng dòng góp vào BỘI, kèm tên — đây là thứ hiện trong tooltip khi rê chuột.
## Balatro cho thấy từng Joker nhân bao nhiêu; hiệu ứng hiển thị đó CHÍNH LÀ game.
func mult_breakdown(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	var gm0 := map.get_node_or_null("/root/GameManagerSingleton")

	# 1. Thế cờ đang phủ ô này (+ thưởng di vật cộng vào MỌI thế)
	var cf := map.get_node_or_null("ChessFormations")
	var fbonus := 0.0
	if gm0 != null:
		fbonus = maxf(0.0, float(gm0.relic_formation_mult_bonus))
	if cf and cf.has_method("mult_at"):
		for e in cf.call("formations_at", cell):
			if e is Dictionary and fbonus > 0.0:
				var d0: Dictionary = e
				d0["mult"] = float(d0.get("mult", 1.0)) + fbonus
				out.append(d0)
			else:
				out.append(e)

	# 1b. Di vật kiểu Joker — sửa CÁCH TÍNH, không chỉ cộng một con số.
	if gm0 != null and cf != null:
		# Đa dạng: thưởng theo số LOẠI thế khác nhau đang có trên bàn.
		var variety := float(gm0.relic_variety_mult)
		if variety > 0.0:
			var kinds: int = (cf.call("counts") as Dictionary).size()
			if kinds > 0:
				out.append({"name": "Broken Crown", "mult": 1.0 + variety * float(kinds)})
		# Cờ tàn: bàn càng thưa, mỗi quân càng mạnh.
		var endg := float(gm0.relic_endgame_mult)
		if endg > 0.0:
			var n_units: int = _towers().size()
			var empty: int = maxi(0, 20 - n_units)
			out.append({"name": "Endgame", "mult": 1.0 + endg * float(empty)})
		# Con Tốt Thí: mỗi Tốt trên bàn cộng Bội cho các quân KHÁC.
		var tithe := float(gm0.relic_pawn_tithe)
		if tithe > 0.0:
			var pawns := 0
			for t in _towers():
				if t.has_method("pattern_kind") and int(t.pattern_kind()) == ChessPattern.Kind.PAWN:
					pawns += 1
			if pawns > 0:
				out.append({"name": "Sacrificial Pawn", "mult": 1.0 + tithe * float(pawns)})

	# 2. Cấp ô nguyên tố dưới chân
	var tm = map.get("territory_manager")
	var has_element := false
	if tm != null and tm.has_method("has_biome_at"):
		has_element = bool(tm.has_biome_at(cell))
		# Di vật "Ley Line": ô nguyên tố lan sang 4 ô kề. Ô lan KHÔNG có mesh
		# riêng — nó chỉ tồn tại trong công thức, nên chỉ tính ở đây.
		if not has_element and gm0 != null and bool(gm0.relic_tile_spread):
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if bool(tm.has_biome_at(cell + dir)):
					out.append({"name": "Long Mạch lan", "mult": 1.15})
					has_element = true
					break
	if tm != null and tm.has_method("get_element_bonus"):
		var b: Dictionary = tm.get_element_bonus(cell)
		var rm := float(b.get("reaction_mult", 1.0))
		var dp := float(b.get("tower_damage_pct", 0.0))
		if rm > 1.001:
			out.append({"name": "Element vein", "mult": rm})
		if dp > 0.001:
			out.append({"name": "Long mạch", "mult": 1.0 + dp})

	# 3. Di vật + luật Rival King (ghi vào GameManager, đọc một chỗ)
	var gm := map.get_node_or_null("/root/GameManagerSingleton")
	if gm != null:
		var gr := float(gm.global_reaction_mult)
		if gr > 1.001:
			out.append({"name": "Di vật", "mult": gr})
		# Di vật "Barren Ground": thưởng cho ô KHÔNG có nguyên tố — mở lối chơi phản
		# nguyên tố, thứ mà bản cũ không có đường nào đi.
		var plain := float(gm.relic_plain_tile_mult)
		if plain > 0.0 and not has_element:
			out.append({"name": "Barren Ground", "mult": 1.0 + plain})
		# Di vật "Encirclement" (cờ vây): ô bị ≥3 quân kề bao vây.
		var surr := float(gm.relic_surround_mult)
		if surr > 0.0:
			var neighbours := 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					for t in _towers():
						if t.has_method("home_cell") and t.home_cell() == cell + Vector2i(dx, dy):
							neighbours += 1
							break
			if neighbours >= 3:
				out.append({"name": "Encirclement", "mult": 1.0 + surr * float(neighbours)})
		var rule := map.get_node_or_null("KingRules")
		if rule and rule.has_method("cell_mult"):
			var rv := float(rule.call("cell_mult", cell))
			if not is_equal_approx(rv, 1.0):
				out.append({"name": str(rule.call("rule_name")), "mult": rv})
	return out


# ── Con số người chơi nhìn ──────────────────────────────────────────────────

## Số ô ĐƯỜNG ĐI mà một quân phủ. Quân không phủ ô đường nào thì không bắn —
## đây là con số quyết định giá trị của một vị trí.
func path_cells_covered(t: Node) -> int:
	if not t.has_method("covers_cell"):
		return 0
	var n := 0
	for c in _path_cells():
		if t.covers_cell(c):
			n += 1
	return n


## BỘI trung bình trên các ô đường mà quân này phủ.
func avg_mult_on_path(t: Node) -> float:
	var total := 0.0
	var n := 0
	for c in _path_cells():
		if t.covers_cell(c):
			total += cell_mult(c)
			n += 1
	return (total / float(n)) if n > 0 else 1.0


## Sát thương một quân gây ra trong CẢ WAVE.
##
## Điểm mấu chốt — và là chỗ bản đầu tính sai gấp ~3 lần: một quân KHÔNG bắn
## suốt wave. Nó chỉ bắn khi có địch đang ĐỨNG trên ô nó phủ. Mỗi con địch đi
## qua vùng phủ của nó đúng `k / v` giây (k ô phủ, v ô/giây), nên với n con địch
## thì tổng thời gian nó có mục tiêu là `n × k / v` — kẹp bởi thời lượng wave.
##
##     SÁT THƯƠNG(quân) = DPS × BỘI_trung_bình × min(thời_lượng, n × k / v)
##
## Công thức này tự đúng ở cả hai đầu: quân phủ ít ô thì thời gian bắn ngắn,
## quân phủ nhiều ô thì bị chặn bởi thời lượng wave. Bản cũ dùng
## "Σ điểm ô / tốc độ × số địch" nên báo dư 4× mà quái vẫn lọt qua.
## Thời gian một quân CÓ MỤC TIÊU trong wave, tính theo từng NHÓM địch.
##
## Mỗi nhóm `{count, speed}` đóng góp `count × k / speed` giây. Tính theo nhóm
## chứ không lấy một tốc độ chung là bắt buộc: wave boss có 6 lính nhanh cộng
## MỘT con boss rất chậm ở trên bàn ~25 giây. Dùng số lính làm `n` thì công suất
## tụt 83% ở đúng wave boss — đo được 9490 → 1657 giữa wave 8 và 9.
func active_seconds(t: Node, groups: Array, duration: float) -> float:
	var k := path_cells_covered(t)
	if k <= 0:
		return 0.0
	var total := 0.0
	for g in groups:
		if not (g is Dictionary):
			continue
		var d: Dictionary = g
		var v: float = maxf(0.05, float(d.get("speed", 1.0)))
		total += float(d.get("count", 0)) * float(k) / v
	return minf(duration, total)


func tower_wave_damage(t: Node, enemy_count: int, speed: float, duration: float) -> float:
	var k := path_cells_covered(t)
	if k <= 0:
		return 0.0
	if _silenced(t):
		return 0.0
	# Quân bị Rival King khoá nước đi thì đóng góp 0. Phải tính ở đây, nếu không
	# bảng ngưỡng nói "đủ" trong khi nửa đội hình đứng im — đúng kiểu lời hứa sai
	# mà cả thiết kế này sinh ra để tránh.
	var kr := map.get_node_or_null("KingRules")
	if kr and t.has_method("pattern_kind") 			and bool(kr.call("silences", int(t.pattern_kind()))):
		return 0.0
	var v: float = maxf(0.05, speed)
	var active: float = minf(duration, float(enemy_count) * float(k) / v)
	return tower_dps(t) * avg_mult_on_path(t) * active


## Sát thương gây lên MỘT con địch đi trọn đường — dùng cho tooltip từng ô.
func damage_per_enemy(speed: float = 1.0) -> float:
	var v: float = maxf(0.05, speed)
	var total := 0.0
	for cell in _path_cells():
		total += cell_base(cell) * cell_mult(cell)
	return total / v


## Tổng máu CẢ WAVE — ngưỡng thật sự phải vượt.
func wave_total_hp(wave: int) -> float:
	var ws = map.get("wave_spawner")
	if ws == null or not ws.has_method("get_wave_enemy_preview"):
		return 0.0
	var total := 0.0
	var listed := 0
	for row in ws.get_wave_enemy_preview(wave):
		if row is Dictionary:
			var d: Dictionary = row
			total += float(d.get("hp", 0)) * float(d.get("count", 0))
			listed += int(d.get("count", 0))
	# Bảng trinh sát chỉ liệt kê một MẪU của bể loài; wave thật có số địch khác.
	# Quy về số thật theo CẢ HAI chiều — bản cũ chỉ nắn khi `real > listed`, mà
	# wave boss chỉ có 6 hộ vệ trong khi bể liệt kê ~20 dòng ⇒ ngưỡng hiện ra cao
	# gấp ~3 lần sự thật, đúng ở ba wave quan trọng nhất ván. `enemy_groups()`
	# ngay bên dưới vốn đã nắn hai chiều nên hai hàm còn mâu thuẫn với nhau.
	var real: int = int(ws.calculate_enemies_for_wave(wave)) if ws.has_method("calculate_enemies_for_wave") else listed
	if listed > 0 and real > 0:
		total *= float(real) / float(listed)
	# MÁU BOSS phải nằm trong ngưỡng. Bỏ sót thì đúng ở wave quan trọng nhất
	# con số lại nói dối — người chơi thấy "đủ" rồi thua ngay.
	if ws.has_method("is_boss_wave") and ws.is_boss_wave(wave):
		total += _boss_hp(ws, wave)
	return total


## Quân có bị Rival King khoá nước đi không.
func _silenced(t: Node) -> bool:
	var kr := map.get_node_or_null("KingRules")
	return kr != null and t.has_method("pattern_kind") 		and bool(kr.call("silences", int(t.pattern_kind())))


## Các nhóm địch của một wave: [{count, speed}]. Wave boss KÈM con boss —
## nó chậm nên ở trong tầm rất lâu, bỏ quên là đánh giá thấp cả wave.
func enemy_groups(wave: int) -> Array:
	var out: Array = []
	var ws = map.get("wave_spawner")
	if ws == null:
		return out
	if ws.has_method("get_wave_enemy_preview"):
		var listed := 0
		for row in ws.get_wave_enemy_preview(wave):
			if row is Dictionary:
				listed += int((row as Dictionary).get("count", 0))
		var real: int = int(ws.calculate_enemies_for_wave(wave)) 			if ws.has_method("calculate_enemies_for_wave") else listed
		var scale: float = (float(real) / float(listed)) if listed > 0 else 1.0
		for row in ws.get_wave_enemy_preview(wave):
			if row is Dictionary:
				var d: Dictionary = row
				out.append({
					"count": float(d.get("count", 0)) * scale,
					"speed": float(d.get("speed", 1.0)),
				})
	if ws.has_method("is_boss_wave") and ws.is_boss_wave(wave):
		var bspd := _boss_speed(ws, wave)
		if bspd > 0.0:
			out.append({"count": 1.0, "speed": bspd})
	return out


## Tốc độ Rival King (ô/giây); 0 nếu không phải wave boss.
func _boss_speed(ws: Node, wave: int) -> float:
	var bs := _boss_stats(ws, wave)
	return (float(bs.speed) / 16.0) if bs != null else 0.0


func _boss_stats(ws: Node, wave: int) -> EnemyStats:
	var ids = ws.get("BOSS_IDS")
	var order = ws.get("BOSS_WAVES")
	if not (ids is Array) or not (order is Array):
		return null
	var idx: int = (order as Array).find(wave)
	if idx < 0 or (ids as Array).is_empty():
		return null
	var path := "res://res/enemy/%s.tres" % str((ids as Array)[idx % (ids as Array).size()])
	if not ResourceLoader.exists(path):
		return null
	return load(path) as EnemyStats


func _is_boss_wave(wave: int) -> bool:
	var ws = map.get("wave_spawner")
	return ws != null and ws.has_method("is_boss_wave") and ws.is_boss_wave(wave)


## Máu RIÊNG con boss (không tính hộ vệ).
func _boss_hp_only(wave: int) -> float:
	var ws = map.get("wave_spawner")
	if ws == null:
		return 0.0
	var bs := _boss_stats(ws, wave)
	if bs == null or not ws.has_method("get_boss_health_multiplier"):
		return 0.0
	return float(bs.max_hp) * float(ws.get_boss_health_multiplier(wave))


## Sát thương đội hình gây lên RIÊNG con boss trong lúc nó đi hết đường.
## Boss đi một mình qua từng ô, nên mỗi quân bắn nó đúng `k / v_boss` giây.
func damage_to_boss(wave: int) -> float:
	var ws = map.get("wave_spawner")
	if ws == null:
		return 0.0
	var v := _boss_speed(ws, wave)
	if v <= 0.0:
		return 0.0
	var groups: Array = [{"count": 1.0, "speed": v}]
	var walk: float = float(_path_cells().size()) / v
	var armor: float = _boss_avg_armor(ws, wave)
	var total := 0.0
	for t in _towers():
		if _silenced(t):
			continue
		total += tower_dps_vs_armor(t, armor) * avg_mult_on_path(t) \
			* active_seconds(t, groups, walk)
	return total * EFFICIENCY * _boss_focus(ws)


## Phần thời gian tháp thực sự BẮN VÀO Rival King.
##
## Hắn không đi một mình: wave boss có `BOSS_WAVE_MINION_COUNT` hộ vệ đi cùng,
## và tháp nhắm mục tiêu ĐẦU TIÊN vào tầm chứ không nhắm boss. Mô hình cũ tính
## như thể boss là mục tiêu duy nhất trên bàn.
##
## Sai số này không nhỏ — đo trên bàn thật ở wave 12: mô hình báo tỉ lệ 5.17
## ("hạ boss thừa 5 lần") trong khi boss đi thẳng tới King và người chơi THUA
## NGAY. Cả wave chỉ lọt 2 con / 8 sát thương, tức đàn lính không phải vấn đề:
## thua đúng vì con số ở giữa màn hình nói dối vào khoảnh khắc quyết định ván.
##
## `BOSS_ESCORT_OVERLAP` = phần hộ vệ trung bình còn sống và CÙNG NẰM trong tầm
## với boss (không phải toàn bộ 6 con cùng lúc).
const BOSS_ESCORT_OVERLAP: float = 0.8

func _boss_focus(ws: Node) -> float:
	var escorts := 6.0
	var n = ws.get("BOSS_WAVE_MINION_COUNT")
	if n is int or n is float:
		escorts = float(n)
	return 1.0 / (1.0 + maxf(0.0, escorts) * BOSS_ESCORT_OVERLAP)


## Giáp TRUNG BÌNH của Rival King qua cả trận — hắn đi qua 3 pha và giáp tụt dần
## (`phase_armor`), nên lấy giáp pha 1 là bi quan, lấy pha 3 là lạc quan.
func _boss_avg_armor(ws: Node, wave: int) -> float:
	var bs := _boss_stats(ws, wave)
	if bs == null:
		return 0.0
	var pa = bs.get("phase_armor")
	if pa is Array and not (pa as Array).is_empty():
		var s := 0.0
		for a in (pa as Array):
			s += float(a)
		return s / float((pa as Array).size())
	return float(bs.armor) if bs.get("armor") != null else 0.0


## Máu Rival King của wave boss (0 nếu không phải wave boss).
func _boss_hp(ws: Node, wave: int) -> float:
	if not ws.has_method("get_boss_health_multiplier"):
		return 0.0
	var ids = ws.get("BOSS_IDS")
	var order = ws.get("BOSS_WAVES")
	if not (ids is Array) or not (order is Array):
		return 0.0
	var idx: int = (order as Array).find(wave)
	if idx < 0 or (ids as Array).is_empty():
		return 0.0
	var bid: String = str((ids as Array)[idx % (ids as Array).size()])
	var path := "res://res/enemy/%s.tres" % bid
	if not ResourceLoader.exists(path):
		return 0.0
	var bs := load(path) as EnemyStats
	if bs == null:
		return 0.0
	return float(bs.max_hp) * float(ws.get_boss_health_multiplier(wave))


## Tốc độ con địch NHANH NHẤT wave — nó ở trong tầm ít nhất nên khó giết nhất.
func wave_fastest_speed(wave: int) -> float:
	var ws = map.get("wave_spawner")
	if ws == null or not ws.has_method("get_wave_enemy_preview"):
		return 1.0
	var fastest := 0.5
	for row in ws.get_wave_enemy_preview(wave):
		if row is Dictionary:
			fastest = maxf(fastest, float((row as Dictionary).get("speed", 1.0)))
	return fastest


## Thời lượng ước tính của một wave (giây) — số địch × nhịp spawn.
func wave_duration(wave: int) -> float:
	var ws = map.get("wave_spawner")
	if ws == null or not ws.has_method("calculate_enemies_for_wave"):
		return 20.0
	var n: int = int(ws.calculate_enemies_for_wave(wave))
	var iv: float = float(ws.get("SPAWN_INTERVAL")) if ws.get("SPAWN_INTERVAL") != null else 1.5
	var dur: float = maxf(5.0, float(n) * iv)
	# WAVE BOSS: `calculate_enemies_for_wave` chỉ trả 6 lính hộ vệ nên thời lượng
	# tính ra ~9 giây, trong khi Rival King đi trọn đường mất ~30 giây. Thiếu chỗ
	# này thì ngưỡng wave boss nói dối nặng nhất — đúng wave quan trọng nhất.
	if ws.has_method("is_boss_wave") and ws.is_boss_wave(wave):
		dur = maxf(dur, _boss_walk_time(ws, wave))
	return dur


## Thời gian Rival King đi hết đường (giây).
func _boss_walk_time(ws: Node, wave: int) -> float:
	var ids = ws.get("BOSS_IDS")
	var order = ws.get("BOSS_WAVES")
	if not (ids is Array) or not (order is Array):
		return 0.0
	var idx: int = (order as Array).find(wave)
	if idx < 0 or (ids as Array).is_empty():
		return 0.0
	var path := "res://res/enemy/%s.tres" % str((ids as Array)[idx % (ids as Array).size()])
	if not ResourceLoader.exists(path):
		return 0.0
	var bs := load(path) as EnemyStats
	if bs == null:
		return 0.0
	# .tres giữ tốc độ theo px; 16 px = 1 ô.
	var v: float = maxf(0.05, float(bs.speed) / 16.0)
	return float(_path_cells().size()) / v


## Tóm tắt cho HUD — MỘT con số so với MỘT con số, đúng kiểu ngưỡng Blind.
##   damage    : tổng sát thương đội hình phát ra trong cả wave
##   threshold : tổng máu cả wave
## `ratio` < 1 → biết trước sẽ thủng → quay lại sửa bố cục.
func summary(wave: int) -> Dictionary:
	var spd := wave_fastest_speed(wave)
	var dur := wave_duration(wave)
	var ws = map.get("wave_spawner")
	var n: int = int(ws.calculate_enemies_for_wave(wave)) if ws and ws.has_method("calculate_enemies_for_wave") else 1

	# Nhóm địch thật của wave (kèm CON BOSS nếu là wave boss).
	var groups := enemy_groups(wave)
	var dmg := 0.0
	for t in _towers():
		if _silenced(t):
			continue
		dmg += tower_dps(t) * avg_mult_on_path(t) * active_seconds(t, groups, dur)
	dmg *= EFFICIENCY
	var thr := wave_total_hp(wave)

	# ── WAVE BOSS: điều kiện thua là RIÊNG ────────────────────────────────
	# Boss chạm Vua = THUA NGAY (`boss_escaped`), không liên quan máu Vua còn
	# bao nhiêu. Nên ở wave boss, "tổng sát thương ≥ tổng máu wave" KHÔNG phải
	# điều kiện sống sót — đo được tỉ lệ 1.03 mà vẫn thua sạch.
	# Ràng buộc thật: giết được con boss TRONG lúc nó đi hết đường hay không.
	# Lấy tỉ lệ NGẶT HƠN trong hai cái làm con số hiển thị.
	var boss_note := ""
	if _is_boss_wave(wave):
		var bhp := _boss_hp_only(wave)
		var bdmg := damage_to_boss(wave)
		if bhp > 0.01:
			var boss_ratio: float = bdmg / bhp
			var wave_ratio: float = (dmg / thr) if thr > 0.01 else 999.0
			if boss_ratio < wave_ratio:
				# Boss là chỗ nghẽn ⇒ hiển thị chính phép so đó.
				return {
					"damage": bdmg, "threshold": bhp,
					"per_enemy": damage_per_enemy(spd), "speed": spd,
					"duration": dur, "ratio": boss_ratio,
					"ok": bdmg >= bhp, "boss": true,
					"note": "Damage to the Rival King alone / his HP",
				}
			boss_note = "Enough to kill the Rival King (×%.1f) - his guards are the bottleneck" % boss_ratio

	return {
		"damage": dmg,
		"threshold": thr,
		"note": boss_note,
		"per_enemy": damage_per_enemy(spd),
		"speed": spd,
		"duration": dur,
		"ratio": (dmg / thr) if thr > 0.01 else 999.0,
		"ok": thr <= 0.01 or dmg >= thr,
	}


## Từng dòng góp vào NỀN của một ô — nửa còn lại của tooltip.
func base_breakdown(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in _towers():
		if t.has_method("covers_cell") and t.covers_cell(cell):
			out.append({
				"name": UIStyle.unit_name_vi(str(t.stats.id)) if t.stats else "?",
				"cell": t.home_cell() if t.has_method("home_cell") else Vector2i.ZERO,
				"dps": tower_dps(t),
			})
	return out


func _towers() -> Array:
	if map == null or not map.is_inside_tree():
		return []
	return map.get_tree().get_nodes_in_group("towers")


func _path_cells() -> Array:
	var gc = map.get("grid_controller")
	if gc == null:
		return []
	var p = gc.get("current_path_grid")
	return p if p is Array else []
