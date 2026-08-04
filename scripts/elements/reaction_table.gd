# res://scripts/elements/reaction_table.gd
# Bảng phản ứng nguyên tố + phần thực thi (futureplan.md §1.2).
#
# Toàn static, không giữ trạng thái per-enemy (trạng thái nằm ở meta của địch).
# Cố ý KHÔNG tham chiếu class `Enemy`: chuỗi enemy.gd → ElementMarks → ReactionTable
# sẽ thành cyclic reference. Mọi truy cập chéo dùng duck typing + guard.
class_name ReactionTable
extends Object

# ── Đồng hồ hệ nguyên tố ──────────────────────────────────────────────────────
# Đồng hồ ĐẶT Ở ĐÂY (không phải ở ElementMarks) để cắt vòng phụ thuộc:
# ElementMarks BẮT BUỘC gọi ReactionTable (find/trigger), nên chiều ngược lại
# phải sạch tuyệt đối, nếu không GDScript báo cyclic reference lúc parse.
# ElementMarks._process đẩy đồng hồ; ElementMarks.now() và enemy.gd chỉ đọc lại.
#
# KHÔNG dùng Time.get_ticks_msec(): đồng hồ hệ thống vẫn chạy khi game pause
# (`get_tree().paused`) và không co giãn theo `Engine.time_scale` (nút tăng tốc)
# → Dấu sẽ hết hạn và Đóng Băng sẽ tan ngay trong lúc dừng game.
static var _clock: float = 0.0
static var _clock_frame: int = -1

## Mốc thời gian game hiện tại (giây) của hệ nguyên tố.
static func now() -> float:
	return _clock

## Đẩy đồng hồ đúng MỘT LẦN mỗi frame dù có bao nhiêu địch cùng gọi.
static func advance_clock(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _clock_frame:
		return
	_clock_frame = frame
	_clock += delta

# ── Trần & ngân sách ──────────────────────────────────────────────────────────
## TRẦN CỨNG hệ số sát thương phản ứng — chồng bao nhiêu buff cũng không vượt 400%.
const DAMAGE_MULT_CAP: float = 4.0
## Sát thương nền khi không đọc được `current_damage` của tháp nguồn.
const FALLBACK_DAMAGE: float = 20.0
## Tối đa số phản ứng được THỰC THI trong một frame — chặn bão phản ứng khi wave đông.
const MAX_REACTIONS_PER_FRAME: int = 8

static var _budget_frame: int = -1
static var _budget_used: int = 0

# ── Meta key đặt lên địch ─────────────────────────────────────────────────────
const META_FROZEN_UNTIL: String = "_frozen_until"
const META_FREEZE_CD_UNTIL: String = "_freeze_cd_until"

const FREEZE_DURATION: float = 2.0
const FREEZE_COOLDOWN: float = 6.0   # cooldown ẩn mỗi con — thiếu nó là khoá cứng vĩnh viễn
const MELT_ARMOR_SHRED: float = 4.0
const CONDUCT_RADIUS: float = 2.5
const CONDUCT_MAX_TARGETS: int = 4
const OVERLOAD_RADIUS: float = 2.2
const OVERLOAD_KNOCKBACK: float = 0.6
const CONTAGION_RADIUS: float = 3.0
const SUPERCONDUCT_RADIUS: float = 2.0
const SUPERCONDUCT_ARMOR: int = 8
const SUPERCONDUCT_DURATION: float = 6.0
const TOXIC_BURN_RADIUS: float = 1.8
const TOXIC_BURN_SPREAD: int = 2
const CRYSTAL_GOLD: int = 15
const QUAKE_STUN: float = 1.0
const CRACK_SLOW: float = 0.4
const CRACK_DURATION: float = 8.0

# ── Nguyên Sơ (mở bằng hình thế Bát Quái — futureplan §2.3) ───────────────────
# KHÔNG phải một cặp Dấu mới: bàn cờ chỉ có 6 nguyên tố nên mọi cặp đã có chủ.
# Thay vào đó Nguyên Sơ là bậc THĂNG CẤP của phản ứng thường — đủ 6 nguyên tố
# trên bàn thì mỗi lần nổ có xác suất bùng thành vụ nổ nguyên sơ diện rộng.
# Cách này thưởng cho việc sưu tầm đủ 6 ô mà không cần người chơi ép đúng cặp Dấu.
const PRIMAL_CHANCE: float = 0.2
const PRIMAL_MULT: float = 4.0     # = DAMAGE_MULT_CAP, trần tuyệt đối của hệ
const PRIMAL_RADIUS: float = 3.0
const PRIMAL_COLOR := Color(1.0, 0.95, 0.75)

## Ký tự đại diện trong `pair` — khớp với BẤT KỲ nguyên tố nào khác.
## Chỉ Kết Tinh dùng, và nó nằm CUỐI bảng nên mọi cặp Thổ cụ thể (Chấn Địa)
## được tra trước; wildcard chỉ là lưới hứng.
const WILDCARD: String = "*"

## Mười phản ứng. `pair` không phân biệt thứ tự. THỨ TỰ TRONG BẢNG LÀ ĐỘ ƯU TIÊN.
const TABLE: Array[Dictionary] = [
	{
		"id": "vaporize", "name": "Vaporize",
		"pair": [ElementTypes.FIRE, ElementTypes.WATER],
		"damage_mult": 2.5, "color": Color(1.0, 0.78, 0.48),
	},
	{
		"id": "melt", "name": "Melt",
		"pair": [ElementTypes.FIRE, ElementTypes.ICE],
		"damage_mult": 2.0, "color": Color(1.0, 0.45, 0.22),
	},
	{
		"id": "freeze", "name": "Freeze",
		"pair": [ElementTypes.ICE, ElementTypes.WATER],
		"damage_mult": 0.0, "color": Color(0.62, 0.9, 1.0),
	},
	{
		"id": "conduct", "name": "Conduct",
		"pair": [ElementTypes.THUNDER, ElementTypes.WATER],
		"damage_mult": 0.6, "color": Color(0.8, 0.5, 1.0),
	},
	{
		"id": "overload", "name": "Overload",
		"pair": [ElementTypes.THUNDER, ElementTypes.FIRE],
		"damage_mult": 1.8, "color": Color(1.0, 0.85, 0.3),
	},
	{
		"id": "contagion", "name": "Contagion",
		"pair": [ElementTypes.WATER, ElementTypes.POISON],
		"damage_mult": 0.0, "color": Color(0.5, 1.0, 0.4),
	},
	{
		"id": "superconduct", "name": "Superconduct",
		"pair": [ElementTypes.THUNDER, ElementTypes.ICE],
		"damage_mult": 0.5, "color": Color(0.55, 0.7, 1.0),
	},
	{
		"id": "toxic_burn", "name": "Toxic Burn",
		"pair": [ElementTypes.FIRE, ElementTypes.POISON],
		"damage_mult": 0.0, "color": Color(0.75, 0.95, 0.2),
	},
	{
		"id": "quake", "name": "Quake",
		"pair": [ElementTypes.EARTH, ElementTypes.THUNDER],
		"damage_mult": 1.2, "color": Color(0.85, 0.65, 0.35),
	},
	# PHẢI đứng cuối: wildcard Thổ + bất kỳ. Mọi cặp Thổ cụ thể ở trên thắng.
	{
		"id": "crystallize", "name": "Crystallize",
		"pair": [ElementTypes.EARTH, WILDCARD],
		"damage_mult": 0.8, "color": Color(1.0, 0.85, 0.35),
	},
]

# ── Vết nứt (Chấn Địa) ────────────────────────────────────────────────────────
# Ô lưới → mốc hết hạn. Địch đi qua bị chậm CRACK_SLOW.
# Static nên PHẢI được `reset()` khi đổi map/run, nếu không ô cũ còn hiệu lực.
static var _cracks: Dictionary = {}

# ── Tra bảng ──────────────────────────────────────────────────────────────────

## Tìm phản ứng của cặp Dấu (không phân biệt thứ tự). Trả `{}` nếu cặp này trơ.
static func find(a: String, b: String) -> Dictionary:
	if a.is_empty() or b.is_empty() or a == b:
		return {}
	for reaction in TABLE:
		var pair: Array = reaction.get("pair", [])
		if pair.size() != 2:
			continue
		if _pair_matches(pair, a, b):
			return reaction
	return {}

## Cặp khớp không phân biệt thứ tự, có hỗ trợ WILDCARD ở một vế.
static func _pair_matches(pair: Array, a: String, b: String) -> bool:
	var p0 := str(pair[0])
	var p1 := str(pair[1])
	if _slot_matches(p0, a) and _slot_matches(p1, b):
		return true
	return _slot_matches(p0, b) and _slot_matches(p1, a)

static func _slot_matches(slot: String, element: String) -> bool:
	return slot == WILDCARD or slot == element

## Danh sách id phản ứng (cho UI codex sau này).
static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for reaction in TABLE:
		out.append(str(reaction.get("id", "")))
	return out

# ── Thực thi ──────────────────────────────────────────────────────────────────

## Nổ một phản ứng lên `enemy`. `source` là tháp đã bắn ra Dấu kích hoạt.
## `context` (tuỳ chọn) mang thông tin Dấu vừa bị tiêu thụ — xem ElementMarks._fire_reaction.
static func trigger(reaction: Dictionary, enemy: Node, source: Node, context: Dictionary = {}) -> void:
	if reaction.is_empty() or not _is_live(enemy):
		return
	if not _consume_budget():
		return   # quá ngân sách frame — Dấu đã bị tiêu thụ, phản ứng bỏ qua

	reaction_count += 1
	_refund_nearby_cooldowns(enemy, source)

	# Bát Quái: thăng cấp TRƯỚC khi chạy phản ứng gốc. Thăng cấp rồi thì bỏ hẳn
	# phản ứng gốc — nếu chạy cả hai, một lần nổ ăn hai lần sát thương.
	if _try_primal(enemy, source):
		return

	var id := str(reaction.get("id", ""))
	match id:
		"vaporize":
			_vaporize(reaction, enemy, source)
		"melt":
			_melt(reaction, enemy, source)
		"freeze":
			_freeze(reaction, enemy, source)
		"conduct":
			_conduct(reaction, enemy, source)
		"overload":
			_overload(reaction, enemy, source)
		"contagion":
			_contagion(reaction, enemy, source, context)
		"superconduct":
			_superconduct(reaction, enemy, source)
		"toxic_burn":
			_toxic_burn(reaction, enemy, source, context)
		"quake":
			_quake(reaction, enemy, source)
		"crystallize":
			_crystallize(reaction, enemy, source)
		_:
			push_warning("ReactionTable: phản ứng chưa có phần thực thi: '%s'" % id)

# ── Sáu phản ứng ──────────────────────────────────────────────────────────────

## Bốc Hơi — 250% sát thương, ĐƠN mục tiêu.
static func _vaporize(reaction: Dictionary, enemy: Node, source: Node) -> void:
	var damage := _reaction_damage(reaction, source)
	var pos := _pos(enemy)
	FX.reaction_burst(_fx_parent(enemy), pos, "vaporize")
	_label(enemy, reaction, damage)
	_hit_reaction(enemy, damage, reaction)

## Tan Chảy — 200% sát thương + xoá sạch giáp 4 giây.
## Xoá giáp TRƯỚC rồi mới đánh → chính đòn kích hoạt cũng ăn trọn, đúng vai "phá giáp".
static func _melt(reaction: Dictionary, enemy: Node, source: Node) -> void:
	var damage := _reaction_damage(reaction, source)
	var pos := _pos(enemy)
	FX.reaction_burst(_fx_parent(enemy), pos, "melt")
	# `call()` chứ không gọi thẳng: `enemy` khai kiểu Node (khai kiểu Enemy = cyclic reference).
	if enemy.has_method("shred_armor"):
		enemy.call("shred_armor", MELT_ARMOR_SHRED)
	_label(enemy, reaction, damage)
	_hit_reaction(enemy, damage, reaction)

## Đóng Băng — đứng yên 2 giây, cooldown ẩn 6 giây MỖI CON.
## Không có cooldown thì một dòng Dấu Băng/Thuỷ đều đặn sẽ khoá cứng địch vĩnh viễn.
static func _freeze(reaction: Dictionary, enemy: Node, _source: Node) -> void:
	var t := now()
	var pos := _pos(enemy)
	# Synergy Băng ×6 "Eternal Ice" bỏ hẳn cooldown ẩn — đây CHÍNH LÀ phần
	# thưởng cho lối chơi Vĩnh Đông, và là ngoại lệ DUY NHẤT của luật cooldown.
	var eternal_ice := _perk_bool("syn_ice_no_freeze_cd")
	if not eternal_ice and enemy.has_meta(META_FREEZE_CD_UNTIL) 			and float(enemy.get_meta(META_FREEZE_CD_UNTIL)) > t:
		# Đang hồi — chỉ nháy hiệu ứng nhỏ để người chơi hiểu vì sao không đóng băng.
		FX.spawn_burst(_fx_parent(enemy), pos + Vector3(0.0, 0.4, 0.0), Color(0.6, 0.85, 1.0), 5, 0.4)
		return
	# Perk "Deep Freeze" kéo dài thời gian đứng yên, KHÔNG đụng cooldown ẩn —
	# nếu cooldown cũng giãn theo thì perk tự vô hiệu hoá chính nó.
	enemy.set_meta(META_FROZEN_UNTIL, t + FREEZE_DURATION + _perk_float("perk_freeze_bonus"))
	enemy.set_meta(META_FREEZE_CD_UNTIL, t + FREEZE_COOLDOWN)
	FX.reaction_burst(_fx_parent(enemy), pos, "freeze")
	_label(enemy, reaction, -1)
	# Không gây sát thương — giá trị của Đóng Băng nằm ở 2 giây kiểm soát cứng.

## Dẫn Điện — lan tối đa 4 địch trong 2.5m (tính cả mục tiêu chính), mỗi con 60%.
static func _conduct(reaction: Dictionary, enemy: Node, source: Node) -> void:
	var damage := _reaction_damage(reaction, source)
	var origin := _pos(enemy)
	var parent := _fx_parent(enemy)
	FX.reaction_burst(parent, origin, "conduct")
	_label(enemy, reaction, damage)

	# Trần mục tiêu = max(nền + perk Lôi Đình, synergy Bão Sét). Lấy MAX chứ không
	# cộng: hai nguồn đều là "trần", cộng lại sẽ vọt lên 10+ và xoá sổ mọi wave.
	var conduct_targets: int = maxi(
		CONDUCT_MAX_TARGETS + int(_perk_float("perk_conduct_extra")),
		int(_perk_float("syn_thunder_targets")))
	for node in _closest(_nearby(enemy, _radius(CONDUCT_RADIUS, source), true), origin, conduct_targets):
		if node == enemy:
			_hit_reaction(enemy, damage, reaction)
			continue
		FX.spawn_burst(parent, _pos(node) + Vector3(0.0, 0.4, 0.0), Color(0.8, 0.5, 1.0), 8, 0.6)
		_hit_reaction(node, damage, reaction, "burn")

## Quá Tải — nổ 2.2m, 180% sát thương, đẩy lùi 0.6m dọc đường đi.
static func _overload(reaction: Dictionary, enemy: Node, source: Node) -> void:
	var damage := _reaction_damage(reaction, source)
	var origin := _pos(enemy)
	FX.reaction_burst(_fx_parent(enemy), origin, "overload")
	_label(enemy, reaction, damage)

	for node in _nearby(enemy, _radius(OVERLOAD_RADIUS, source), true):
		_knockback(node, OVERLOAD_KNOCKBACK)
		# Mục tiêu chính dùng kind "reaction" (nhãn tên phản ứng đã vẽ ở trên),
		# các con dính nổ dùng "burn" để hiện số nhỏ.
		_hit_reaction(node, damage, reaction, "reaction" if node == enemy else "burn")

## Lan Truyền — Độc lây sang mọi địch trong 3m, GIỮ NGUYÊN số tầng.
## Dùng `implant` (bỏ qua kiểm tra phản ứng) để không nổ dây chuyền vô hạn.
static func _contagion(reaction: Dictionary, enemy: Node, source: Node, context: Dictionary) -> void:
	var origin := _pos(enemy)
	var stacks: int = maxi(1, int(context.get("poison_stacks", 1)))
	FX.reaction_burst(_fx_parent(enemy), origin, "contagion")
	_label(enemy, reaction, -1)

	var spread := 0
	for node in _nearby(enemy, _radius(CONTAGION_RADIUS, source), false):
		if not _implant_poison(node, stacks, source):
			continue
		spread += 1
		FX.spawn_burst(_fx_parent(enemy), _pos(node) + Vector3(0.0, 0.4, 0.0),
			ElementTypes.color_of(ElementTypes.POISON), 6, 0.5)
	if spread == 0:
		# Không có ai xung quanh — trả Độc lại cho chính nó để phản ứng không "mất trắng".
		_implant_poison(enemy, stacks, source)

## Siêu Dẫn — 50% sát thương lên mục tiêu + trừ thẳng 8 giáp MỌI địch trong 2m, 6 giây.
## Trừ giáp phẳng (khác Tan Chảy xoá sạch) nên vẫn có giá trị chồng lên nhau:
## Tan Chảy dồn một mục tiêu, Siêu Dẫn mở giáp cả cụm cho đội hình vật lý dọn.
static func _superconduct(reaction: Dictionary, enemy: Node, source: Node) -> void:
	var damage := _reaction_damage(reaction, source)
	var origin := _pos(enemy)
	var parent := _fx_parent(enemy)
	FX.reaction_burst(parent, origin, "superconduct")
	_label(enemy, reaction, damage)

	for node in _nearby(enemy, _radius(SUPERCONDUCT_RADIUS, source), true):
		if node.has_method("reduce_armor"):
			node.call("reduce_armor", SUPERCONDUCT_ARMOR, SUPERCONDUCT_DURATION)
		if node == enemy:
			_hit_reaction(node, damage, reaction)
		else:
			FX.spawn_burst(parent, _pos(node) + Vector3(0.0, 0.4, 0.0),
				Color(0.55, 0.7, 1.0), 6, 0.5)

## Cháy Độc — nhân đôi tầng Độc trên mục tiêu rồi cấy sang 2 địch kề gần nhất.
## Không gây sát thương tức thì: giá trị nằm ở DoT dày lên và nhân bản ra xung quanh.
static func _toxic_burn(reaction: Dictionary, enemy: Node, source: Node, context: Dictionary) -> void:
	var stacks: int = maxi(1, int(context.get("poison_stacks", 1)))
	var doubled: int = stacks * 2
	var parent := _fx_parent(enemy)
	FX.reaction_burst(parent, _pos(enemy), "toxic_burn")
	_label(enemy, reaction, -1)

	_implant_poison(enemy, doubled, source)
	for node in _closest(_nearby(enemy, _radius(TOXIC_BURN_RADIUS, source), false), _pos(enemy), TOXIC_BURN_SPREAD):
		if not _implant_poison(node, doubled, source):
			continue
		FX.spawn_burst(parent, _pos(node) + Vector3(0.0, 0.4, 0.0),
			ElementTypes.color_of(ElementTypes.POISON), 6, 0.5)

## Chấn Địa — 120% sát thương + choáng 1s + biến ô đang đứng thành VẾT NỨT 8 giây.
## Vết nứt là điều khiển địa hình: nó nằm trên đường đi nên mọi con sau đều dính,
## khác Đóng Băng (chỉ khoá đúng một con).
static func _quake(reaction: Dictionary, enemy: Node, source: Node) -> void:
	var damage := _reaction_damage(reaction, source)
	var origin := _pos(enemy)
	var parent := _fx_parent(enemy)
	FX.reaction_burst(parent, origin, "quake")
	_label(enemy, reaction, damage)

	# Choáng dùng CHUNG meta với Đóng Băng nhưng KHÔNG đụng cooldown đóng băng —
	# hai nguồn kiểm soát khác nhau, chia cooldown sẽ vô hiệu hoá lẫn nhau.
	var until := now() + QUAKE_STUN
	if not enemy.has_meta(META_FROZEN_UNTIL) or float(enemy.get_meta(META_FROZEN_UNTIL)) < until:
		enemy.set_meta(META_FROZEN_UNTIL, until)

	_add_crack(GridUtil.world_to_cell(origin), parent)
	_hit_reaction(enemy, damage, reaction)

## Kết Tinh — Thổ + bất kỳ: 80% sát thương + rơi tinh thể +15 vàng (tự nhặt).
## Không sinh entity nhặt tay: bàn cờ 24×24 với wave đông thì nhặt tay là tra tấn.
static func _crystallize(reaction: Dictionary, enemy: Node, source: Node) -> void:
	var damage := _reaction_damage(reaction, source)
	var origin := _pos(enemy)
	var parent := _fx_parent(enemy)
	FX.reaction_burst(parent, origin, "crystallize")
	_label(enemy, reaction, damage)
	_hit_reaction(enemy, damage, reaction)

	var gold := CRYSTAL_GOLD
	var gm := _game_manager(parent)
	if gm != null and gm.has_method("add_gold"):
		gold = int(round(float(gold) * _crystal_mult(gm)))
		gm.call("add_gold", gold)
		if parent != null and parent.is_inside_tree():
			FX.damage_number(parent, origin + Vector3(0.0, 1.7, 0.0),
				"+%d ⛁" % gold, Color(1.0, 0.85, 0.35), 20)
	_try_crystal_shard(enemy, origin)

## 5% mỗi lần Kết Tinh: rơi thẳng một ô nguyên tố Lv1 vào kho (futureplan §2.4).
## Đây là nguồn ô DUY NHẤT không tốn tiền và không phụ thuộc shop — nó thưởng
## cho việc chủ động dựng bố cục Thổ, chứ không phải may mắn thuần tuý.
const CRYSTAL_SHARD_CHANCE: float = 0.05

static func _try_crystal_shard(enemy: Node, origin: Vector3) -> void:
	if randf() >= CRYSTAL_SHARD_CHANCE or not is_instance_valid(enemy):
		return
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var map: Node = (loop as SceneTree).root.get_node_or_null("GameMap")
	if map == null:
		return
	var tm: Variant = map.get("territory_manager")
	if not (tm is Node) or not (tm as Node).has_method("add_stock"):
		return
	var element: String = ElementTypes.ALL[randi() % ElementTypes.ALL.size()]
	var biome: String = TerritoryManager.biome_of_element(element)
	if biome.is_empty():
		return
	(tm as Node).call("add_stock", biome)
	var parent := _fx_parent(enemy)
	if parent != null and parent.is_inside_tree():
		FX.damage_number(parent, origin + Vector3(0.0, 2.1, 0.0),
			"◈ %s shard!" % ElementTypes.display_name(element),
			ElementTypes.color_of(element), 22)

## Hệ số vàng Kết Tinh — synergy Thổ ×6 "Seismic" nâng 15 → 40 vàng.
static func _crystal_mult(gm: Object) -> float:
	var value: Variant = gm.get("crystal_gold_mult")
	if value is int or value is float:
		return maxf(0.0, float(value))
	return 1.0

static func _game_manager(from: Node) -> Object:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_node_or_null("/root/GameManagerSingleton")

# ── Vết nứt ───────────────────────────────────────────────────────────────────

## Hệ số chậm của vết nứt tại ô này (0.0 = không có). Địch gọi mỗi frame → giữ rẻ.
static func crack_slow_at(cell: Vector2i) -> float:
	if _cracks.is_empty():
		return 0.0
	var expires: Variant = _cracks.get(cell)
	if expires == null:
		return 0.0
	if float(expires) <= now():
		_cracks.erase(cell)
		return 0.0
	return CRACK_SLOW

## Xoá mọi vết nứt. game_map gọi khi vào map mới và sau khi rebase toạ độ —
## `_cracks` là static nên nếu không dọn, ô của run trước còn làm chậm địch run sau.
static func clear_cracks() -> void:
	_cracks.clear()

## Dọn toàn bộ trạng thái static của hệ nguyên tố (đồng hồ giữ nguyên — nó đơn điệu tăng).
static func reset() -> void:
	clear_cracks()
	reaction_count = 0
	_budget_frame = -1
	_budget_used = 0

static func _add_crack(cell: Vector2i, parent: Node) -> void:
	var fresh := not _cracks.has(cell)
	_cracks[cell] = now() + CRACK_DURATION
	if fresh:
		_spawn_crack_visual(cell, parent)

## Quad tối tại ô. y = 0.056: trên mesh lãnh thổ (0.052), dưới overlay build (0.06)
## → không z-fight với cả hai.
static func _spawn_crack_visual(cell: Vector2i, parent: Node) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.12, 0.08, 0.05, 0.75)
	var quad := MeshInstance3D.new()
	quad.mesh = plane
	quad.material_override = mat
	var center := GridUtil.cell_to_world(cell)
	quad.position = Vector3(center.x, 0.056, center.z)
	parent.add_child(quad)

	# Tween chứ không Timer: tween của SceneTree co giãn theo time_scale nên
	# vết nứt biến mất ĐÚNG lúc hết hiệu lực kể cả khi bấm tăng tốc.
	var tween := quad.create_tween()
	tween.tween_interval(CRACK_DURATION - 0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(quad.queue_free)

## Đọc một field perk_* dạng số từ GameManager. 0.0 khi thiếu singleton/field —
## mọi bên gọi đều coi 0 là "perk chưa sở hữu".
static func _perk_float(field: String) -> float:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return 0.0
	var gm: Node = (loop as SceneTree).root.get_node_or_null("GameManagerSingleton")
	if gm == null:
		return 0.0
	var value: Variant = gm.get(field)
	return float(value) if (value is int or value is float) else 0.0

## Đọc một field cờ bool từ GameManager.
static func _perk_bool(field: String) -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var gm: Node = (loop as SceneTree).root.get_node_or_null("GameManagerSingleton")
	return gm != null and bool(gm.get(field))

# ── Đếm phản ứng (perk "Alchemist's Craft") ─────────────────────────────────────────
## Tổng số phản ứng đã nổ trong run. game_map đọc để phát thuốc mỗi N lần.
static var reaction_count: int = 0

## Bán kính hiệu lực của một phản ứng, cộng thêm "Storm Eye" của tháp nguồn.
static func _radius(base: float, source: Node) -> float:
	if not is_instance_valid(source):
		return base
	var bonus: Variant = source.get("equip_reaction_radius_bonus")
	if bonus is int or bonus is float:
		return base + maxf(0.0, float(bonus))
	return base

## Đồng Hồ Ngược — mọi tháp mang trang bị này và ở gần vụ nổ được rút hồi chiêu.
## Quét theo group "towers" (thường < 50 node) chứ không physics query.
const COOLDOWN_REFUND_RADIUS: float = 3.0

static func _refund_nearby_cooldowns(enemy: Node, _source: Node) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var origin := _pos(enemy)
	var radius_sq := COOLDOWN_REFUND_RADIUS * COOLDOWN_REFUND_RADIUS
	for tower in enemy.get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not (tower is Node3D):
			continue
		var refund: Variant = tower.get("equip_cooldown_refund")
		if not (refund is int or refund is float) or float(refund) <= 0.0:
			continue
		if (tower as Node3D).global_position.distance_squared_to(origin) > radius_sq:
			continue
		if tower.has_method("refund_cooldown"):
			tower.call("refund_cooldown", float(refund))

## Nguyên Sơ — vụ nổ 400% trong 3m. Trả true nếu đã thăng cấp (bên gọi bỏ phản ứng gốc).
static func _try_primal(enemy: Node, source: Node) -> bool:
	if not _perk_bool("bagua_active") or randf() >= PRIMAL_CHANCE:
		return false

	var damage := maxi(1, int(round(minf(PRIMAL_MULT * _power_mult(source), DAMAGE_MULT_CAP)
		* _source_damage(source))))
	var origin := _pos(enemy)
	var parent := _fx_parent(enemy)
	FX.reaction_burst(parent, origin, "primal")
	var label: Dictionary = {"name": "NGUYÊN SƠ", "color": PRIMAL_COLOR}
	_label(enemy, label, damage)

	for node in _nearby(enemy, _radius(PRIMAL_RADIUS, source), true):
		_hit(node, damage, "reaction" if node == enemy else "burn")
	return true

# ── Tính sát thương ───────────────────────────────────────────────────────────

## Sát thương một mục tiêu = min(hệ_số × reaction_power_mult, TRẦN 4.0) × dmg đòn kích hoạt.
static func _reaction_damage(reaction: Dictionary, source: Node) -> int:
	var base_mult := float(reaction.get("damage_mult", 0.0))
	if base_mult <= 0.0:
		return 0
	var mult := minf(base_mult * _power_mult(source), DAMAGE_MULT_CAP)
	return maxi(1, int(round(mult * _source_damage(source))))

## "Sát thương đòn kích hoạt" = `current_damage` của tháp nguồn, fallback 20.
static func _source_damage(source: Node) -> float:
	if is_instance_valid(source):
		var value: Variant = source.get("current_damage")
		if value is int or value is float:
			var damage := float(value)
			if damage > 0.0:
				return damage
	return FALLBACK_DAMAGE

## Hệ số khuếch đại phản ứng của tháp (trang bị "Resonance Ring", thuốc "Tinh Chất").
static func _power_mult(source: Node) -> float:
	if is_instance_valid(source):
		var value: Variant = source.get("reaction_power_mult")
		if value is int or value is float:
			return maxf(0.0, float(value))
	return 1.0

# ── Tiện ích ──────────────────────────────────────────────────────────────────

static func _consume_budget() -> bool:
	var frame := Engine.get_process_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_budget_used = 0
	if _budget_used >= MAX_REACTIONS_PER_FRAME:
		return false
	_budget_used += 1
	return true

static func _is_live(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return false
	return not bool(node.get("_is_dead"))

static func _pos(node: Node) -> Vector3:
	if node is Node3D and is_instance_valid(node):
		return (node as Node3D).global_position
	return Vector3.ZERO

## FX phải add vào PARENT của địch, không phải vào địch — địch chết là hiệu ứng biến mất.
static func _fx_parent(enemy: Node) -> Node:
	if not is_instance_valid(enemy):
		return null
	return enemy.get_parent()

static func _hit(node: Node, damage: int, kind: String = "reaction") -> void:
	if damage <= 0 or not _is_live(node) or not node.has_method("take_damage"):
		return
	node.call("take_damage", damage, kind)

## Sát thương phản ứng có tính khắc/kháng của loài. Lấy hệ số TỐT NHẤT trong cặp
## Dấu: phản ứng là sản phẩm của cả hai, chỉ cần một vế khắc là đủ ăn thưởng —
## nếu lấy trung bình thì mọi phản ứng lai đều nhạt và bảng ái lực thành vô nghĩa.
static func _hit_reaction(node: Node, damage: int, reaction: Dictionary,
		kind: String = "reaction") -> void:
	if damage <= 0 or not _is_live(node):
		return
	_hit(node, int(round(damage * _affinity_mult(node, reaction))), kind)

static func _affinity_mult(node: Node, reaction: Dictionary) -> float:
	if not node.has_method("element_multiplier"):
		return 1.0
	var best := 0.0
	for slot in reaction.get("pair", []):
		var element := str(slot)
		if element == WILDCARD or element.is_empty():
			continue
		best = maxf(best, float(node.call("element_multiplier", element)))
	return best if best > 0.0 else 1.0

## Nhãn tên phản ứng. `damage < 0` → chỉ hiện tên (phản ứng không gây sát thương).
static func _label(enemy: Node, reaction: Dictionary, damage: int) -> void:
	var parent := _fx_parent(enemy)
	if parent == null or not parent.is_inside_tree():
		return
	var title := str(reaction.get("name", "?"))
	var text := title if damage < 0 else "%s %d!" % [title, damage]
	var color: Color = reaction.get("color", Color.WHITE)
	var jitter := Vector3(randf_range(-0.2, 0.2), 1.45, randf_range(-0.2, 0.2))
	FX.damage_number(parent, _pos(enemy) + jitter, text, color, 22)

## Địch còn sống trong bán kính (mét). Duyệt group thay vì physics query:
## rẻ hơn, không phụ thuộc collision layer/mask.
static func _nearby(origin: Node, radius: float, include_self: bool) -> Array:
	var out: Array = []
	if not is_instance_valid(origin) or not origin.is_inside_tree():
		return out
	var center := _pos(origin)
	var radius_sq := radius * radius
	for node in origin.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		if node == origin:
			if include_self and _is_live(node):
				out.append(node)
			continue
		if not _is_live(node) or not node.has_method("take_damage"):
			continue
		if (node as Node3D).global_position.distance_squared_to(center) <= radius_sq:
			out.append(node)
	return out

## Lấy `limit` phần tử gần `center` nhất bằng chọn-dần (O(limit×N), N nhỏ).
## Cố ý KHÔNG dùng `sort_custom` + lambda: lambda trong hàm static của GDScript
## không bắt được self và dễ sinh Callable sai ngữ cảnh.
static func _closest(pool: Array, center: Vector3, limit: int) -> Array:
	var out: Array = []
	var rest := pool.duplicate()
	while out.size() < limit and not rest.is_empty():
		var best := 0
		var best_dist := INF
		for i in range(rest.size()):
			var dist := _pos(rest[i]).distance_squared_to(center)
			if dist < best_dist:
				best_dist = dist
				best = i
		out.append(rest[best])
		rest.remove_at(best)
	return out

## Cấy Dấu Độc vào component Dấu của một con địch. Duck typing có chủ đích:
## khai báo kiểu ElementMarks ở đây sẽ tạo cyclic reference (xem ghi chú đầu file).
## Dùng `implant` chứ không `apply` — lây lan KHÔNG được tự kích phản ứng dây chuyền.
static func _implant_poison(node: Node, stacks: int, source: Node) -> bool:
	if not is_instance_valid(node):
		return false
	var value: Variant = node.get("marks")
	if not (value is Node) or not is_instance_valid(value):
		return false
	var marks := value as Node
	if not marks.has_method("implant"):
		return false
	marks.call("implant", ElementTypes.POISON, stacks, source)
	return true

## Đẩy lùi dọc đường đi: dịch về phía waypoint TRƯỚC ĐÓ và kẹp tại đó.
## `move_toward` không bao giờ vượt quá đích → địch luôn nằm trong đoạn path hiện tại,
## không bị văng ra khỏi đường (dịch theo vector tự do sẽ làm hỏng pathing).
static func _knockback(node: Node, distance: float) -> void:
	if not _is_live(node) or not (node is Node3D):
		return
	var points: Variant = node.get("path_points")
	if not (points is Array) or (points as Array).is_empty():
		return
	var path: Array = points
	var index: Variant = node.get("current_point_index")
	var previous_index: int = clampi((int(index) if index != null else 1) - 1, 0, path.size() - 1)
	var previous: Vector3 = path[previous_index]
	var spatial := node as Node3D
	spatial.position = spatial.position.move_toward(previous, distance)
