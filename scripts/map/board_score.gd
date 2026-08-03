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
				out.append({"name": "Vương Miện Gãy", "mult": 1.0 + variety * float(kinds)})
		# Cờ tàn: bàn càng thưa, mỗi quân càng mạnh.
		var endg := float(gm0.relic_endgame_mult)
		if endg > 0.0:
			var n_units: int = _towers().size()
			var empty: int = maxi(0, 20 - n_units)
			out.append({"name": "Cờ Tàn", "mult": 1.0 + endg * float(empty)})
		# Con Tốt Thí: mỗi Tốt trên bàn cộng Bội cho các quân KHÁC.
		var tithe := float(gm0.relic_pawn_tithe)
		if tithe > 0.0:
			var pawns := 0
			for t in _towers():
				if t.has_method("pattern_kind") and int(t.pattern_kind()) == ChessPattern.Kind.PAWN:
					pawns += 1
			if pawns > 0:
				out.append({"name": "Con Tốt Thí", "mult": 1.0 + tithe * float(pawns)})

	# 2. Cấp ô nguyên tố dưới chân
	var tm = map.get("territory_manager")
	if tm != null and tm.has_method("get_element_bonus"):
		var b: Dictionary = tm.get_element_bonus(cell)
		var rm := float(b.get("reaction_mult", 1.0))
		var dp := float(b.get("tower_damage_pct", 0.0))
		if rm > 1.001:
			out.append({"name": "Ô nguyên tố", "mult": rm})
		if dp > 0.001:
			out.append({"name": "Long mạch", "mult": 1.0 + dp})

	# 3. Di vật + luật Rival King (ghi vào GameManager, đọc một chỗ)
	var gm := map.get_node_or_null("/root/GameManagerSingleton")
	if gm != null:
		var gr := float(gm.global_reaction_mult)
		if gr > 1.001:
			out.append({"name": "Di vật", "mult": gr})
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
func tower_wave_damage(t: Node, enemy_count: int, speed: float, duration: float) -> float:
	var k := path_cells_covered(t)
	if k <= 0:
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
	# Bảng trinh sát chỉ liệt kê một mẫu; wave thật đông hơn. Quy về số địch thật.
	var real: int = int(ws.calculate_enemies_for_wave(wave)) if ws.has_method("calculate_enemies_for_wave") else listed
	if listed > 0 and real > listed:
		total *= float(real) / float(listed)
	# MÁU BOSS phải nằm trong ngưỡng. Bỏ sót thì đúng ở wave quan trọng nhất
	# con số lại nói dối — người chơi thấy "đủ" rồi thua ngay.
	if ws.has_method("is_boss_wave") and ws.is_boss_wave(wave):
		total += _boss_hp(ws, wave)
	return total


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

	var dmg := 0.0
	for t in _towers():
		dmg += tower_wave_damage(t, n, spd, dur)
	dmg *= EFFICIENCY
	var thr := wave_total_hp(wave)
	return {
		"damage": dmg,
		"threshold": thr,
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
