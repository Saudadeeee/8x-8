# res://scripts/enemy/boss.gd
# Rival King — BOSS của wave cuối. Kế thừa Enemy nên đi theo path, ăn đạn,
# dính slow/burn y như quái thường; mọi khác biệt nằm TRONG lớp con này
# (enemy.gd không bị sửa một dòng nào).
#
# Khác biệt chính:
#   • Máu khổng lồ (scale theo wave + Ascension do WaveSpawner truyền vào)
#   • 3 pha theo % máu (100–66 / 66–33 / 33–0): mỗi pha nhanh hơn, giáp mỏng hơn
#   • Kỹ năng riêng chạy theo timer, chỉ khi còn sống
#   • Chặn one-shot: một đòn không thể ăn quá MAX_SINGLE_HIT_PCT máu tối đa
#   • Không bao giờ bị phong elite
extends Enemy
class_name BossEnemy

# ── Signals ───────────────────────────────────────────────────────────────
## Boss vừa bước sang pha mới (1 → 2 → 3).
signal boss_phase_changed(phase: int)
## Boss bị hạ — phát TRƯỚC enemy_defeated của lớp cha.
signal boss_defeated

# ── Constants ─────────────────────────────────────────────────────────────
const BOSS_SCALE: float = 1.8            # model to hơn quái thường
const HP_BAR_SCALE: float = 1.5          # thanh máu 3D to theo
## Ngưỡng % máu để đổi pha.
const PHASE_2_THRESHOLD: float = 0.66
const PHASE_3_THRESHOLD: float = 0.33
## Một đòn không thể lấy quá 25% máu tối đa — boss luôn có đất diễn.
const MAX_SINGLE_HIT_PCT: float = 0.25

## Fallback khi stats không phải BossStats (vẫn chạy được, chỉ mất tuỳ biến).
const DEFAULT_PHASE_ARMOR: Array[int]     = [10, 6, 2]
const DEFAULT_PHASE_CD_SCALE: Array[float] = [1.0, 0.85, 0.7]
const DEFAULT_SPEED_BONUS: float = 0.12
const DEFAULT_SUMMON_IDS: Array[String]   = ["goblin", "orc", "bat"]

## Meta đánh dấu tháp đang dính băng — chặn chồng hiệu ứng.
const FROST_META: String = "boss_frost_active"

const RING_POINTS: int = 10               # số điểm burst vẽ vòng bán kính kỹ năng
const SUMMON_SCATTER: float = 0.3         # lệch vị trí ngẫu nhiên khi triệu hồi

# ── State ─────────────────────────────────────────────────────────────────
var _boss_stats: BossStats = null         # null nếu .tres chỉ là EnemyStats thường
var _stats_duplicated: bool = false       # chỉ duplicate() đúng một lần
var _phase: int = 0                       # 0 = chưa khởi tạo
var _base_speed: float = 0.0              # tốc độ gốc để tính bonus theo pha
var _ability_timer: float = 0.0
var _spawn_hp_mult: float = 1.0           # dùng lại cho quái được triệu hồi
var _spawn_spd_mult: float = 1.0

# ==========================================================================
# LIFECYCLE
# ==========================================================================

# LƯU Ý: chữ ký các hàm override dưới đây phải TRÙNG KHỚP tuyệt đối với
# enemy.gd (kể cả việc không khai báo kiểu trả về) — GDScript từ chối override
# khi chữ ký lệch.

func _ready():
	super._ready()
	add_to_group("bosses")

## Boss KHÔNG bao giờ bị phong elite — WaveSpawner có roll nhầm cũng vô hiệu.
func make_elite(_hp_mult: float = 3.0, _speed_mult: float = 0.85, _gold_mult: float = 2.5) -> void:
	return

func load_enemy_data(health_multiplier: float = 1.0, speed_multiplier: float = 1.0):
	# QUAN TRỌNG: .tres được share giữa mọi instance. Boss chỉnh stats.armor theo
	# pha lúc runtime nên phải làm việc trên bản sao, nếu không sẽ ghi đè resource gốc.
	if stats and not _stats_duplicated:
		stats = stats.duplicate() as EnemyStats
		_stats_duplicated = true
	_boss_stats = stats as BossStats

	super.load_enemy_data(health_multiplier, speed_multiplier)

	_spawn_hp_mult  = health_multiplier
	_spawn_spd_mult = speed_multiplier
	_base_speed     = current_speed
	_phase          = 0
	_ability_timer  = _current_ability_cooldown()
	_apply_boss_scale()
	_enter_phase(1, false)   # đặt giáp P1, không phát hiệu ứng đổi pha

## Model + thanh máu to hơn quái thường.
func _apply_boss_scale() -> void:
	if visual:
		visual.scale = Vector3.ONE * BOSS_SCALE
	if _hp_bar_root and is_instance_valid(_hp_bar_root):
		_hp_bar_root.position.y = HP_BAR_HEIGHT * BOSS_SCALE
		_hp_bar_root.scale = Vector3.ONE * HP_BAR_SCALE
		_hp_bar_root.visible = true   # boss luôn hiện máu, kể cả khi còn đầy

func _process(delta):
	super._process(delta)
	if _is_dead:
		return
	_tick_ability(float(delta))

# ==========================================================================
# DAMAGE / PHASE
# ==========================================================================

## Chặn one-shot rồi mới đưa xuống lớp cha (giáp/flash/số sát thương giữ nguyên).
func take_damage(amount: int, kind: String = "hit"):
	if _is_dead:
		return
	var cap: int = maxi(1, int(round(float(_get_hp_cap()) * MAX_SINGLE_HIT_PCT)))
	super.take_damage(mini(amount, cap), kind)
	if not _is_dead:
		_update_phase()

func _update_phase() -> void:
	var ratio: float = float(current_hp) / float(maxi(1, _get_hp_cap()))
	var target_phase: int = 1
	if ratio <= PHASE_3_THRESHOLD:
		target_phase = 3
	elif ratio <= PHASE_2_THRESHOLD:
		target_phase = 2
	# Chỉ tiến, không lùi — boss hồi máu không được reset pha.
	if target_phase > _phase:
		_enter_phase(target_phase, true)

func _enter_phase(phase: int, announce: bool) -> void:
	_phase = phase
	if stats:
		stats.armor = _armor_for_phase(phase)
	_base_speed = _base_speed if _base_speed > 0.0 else current_speed
	current_speed = _base_speed * (1.0 + _speed_bonus_per_phase() * float(phase - 1))
	# Pha mới → kỹ năng nạp lại theo cooldown mới, tránh xả ngay lập tức
	_ability_timer = _current_ability_cooldown()
	boss_phase_changed.emit(phase)
	_on_phase_changed(phase)
	if announce:
		_play_phase_transition(phase)

## Hook cho hành vi riêng khi đổi pha. Hiện tại kỹ năng đã tự nhanh dần theo
## phase_cooldown_scale; giữ hàm này làm điểm mở rộng cho boss tương lai.
func _on_phase_changed(_phase_index: int) -> void:
	pass

func _play_phase_transition(phase: int) -> void:
	var parent := get_parent()
	if parent == null or not is_inside_tree():
		return
	var color := _accent_color()
	FX.spawn_burst(parent, global_position + Vector3(0.0, 0.9, 0.0), color, 34, 2.0)
	_ring_burst(1.4, color, 8)
	FX.damage_number(parent, global_position + Vector3(0.0, 2.2, 0.0),
		"PHA %d" % phase, color, 24)
	var am := get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("elite_spawn", -2.0)

func die():
	if _is_dead:
		return
	boss_defeated.emit()
	var parent := get_parent()
	if parent and is_inside_tree():
		var color := _accent_color()
		FX.spawn_burst(parent, global_position + Vector3(0.0, 0.9, 0.0), color, 54, 2.6)
		FX.spawn_burst(parent, global_position + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.92, 0.55), 34, 1.8)
		_ring_burst(2.0, Color(1.0, 0.88, 0.4), RING_POINTS)
		FX.damage_number(parent, global_position + Vector3(0.0, 2.4, 0.0),
			"%s GỤC NGÃ!" % _display_name(), Color(1.0, 0.9, 0.35), 26)
	var am := get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("victory", -3.0)
	super.die()

# ==========================================================================
# ABILITY
# ==========================================================================

func _tick_ability(delta: float) -> void:
	if _boss_stats == null or _boss_stats.ability_id == "":
		return
	_ability_timer -= delta
	if _ability_timer > 0.0:
		return
	_ability_timer = _current_ability_cooldown()
	_cast_ability()

func _cast_ability() -> void:
	# Guard kép: timer có thể chạy đúng frame boss vừa chết.
	if _is_dead or not is_instance_valid(self) or not is_inside_tree():
		return
	if _boss_stats == null:
		return
	match _boss_stats.ability_id:
		"summon_beasts": _cast_summon_beasts()
		"lava_breath":   _cast_lava_breath()
		"eternal_frost": _cast_eternal_frost()
		_:
			push_warning("BossEnemy: ability_id không hợp lệ '%s'" % _boss_stats.ability_id)

func _announce_ability() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var label: String = _boss_stats.ability_name if _boss_stats and _boss_stats.ability_name != "" else "KỸ NĂNG"
	FX.damage_number(parent, global_position + Vector3(0.0, 2.0, 0.0),
		"✦ %s" % label, _accent_color(), 20)

# ── Vua Hoang Dã: Triệu Hồi Bầy Thú ───────────────────────────────────────

func _cast_summon_beasts() -> void:
	var cells := _remaining_path_cells()
	if cells.size() < 2:
		return   # boss sát chân King — không đủ đường cho quái mới đi
	var ids: Array[String] = _boss_stats.summon_ids if not _boss_stats.summon_ids.is_empty() \
		else DEFAULT_SUMMON_IDS
	var spawner := _find_wave_spawner()
	var count: int = maxi(1, _boss_stats.summon_count)
	var spawned: int = 0
	for i in count:
		var enemy_id: String = ids[i % ids.size()]
		var ok: bool = false
		if spawner and spawner.has_method("spawn_summon"):
			ok = bool(spawner.call("spawn_summon", enemy_id, cells, _spawn_hp_mult, _spawn_spd_mult))
		else:
			ok = _spawn_summon_fallback(enemy_id, cells)
		if ok:
			spawned += 1
	if spawned <= 0:
		return
	_announce_ability()
	_ring_burst(0.9, _accent_color(), 8)

## Đường đi còn lại tính từ ô boss đang đứng — quái triệu hồi nối tiếp lộ trình.
func _remaining_path_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.append(GridUtil.world_to_cell(global_position))
	for i in range(current_point_index, path_points.size()):
		var cell: Vector2i = GridUtil.world_to_cell(path_points[i])
		if cells[cells.size() - 1] != cell:
			cells.append(cell)
	return cells

## Chỉ dùng khi không tìm thấy WaveSpawner (spawn debug). Quái sinh ra không được
## đếm vào wave và không sinh vàng — chấp nhận được cho nhánh dự phòng này.
func _spawn_summon_fallback(enemy_id: String, cells: Array[Vector2i]) -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var stats_path := "res://res/enemy/%s.tres" % enemy_id
	if not ResourceLoader.exists(stats_path):
		push_warning("BossEnemy: không tìm thấy stats cho quái triệu hồi '%s'" % enemy_id)
		return false
	var summon_stats := load(stats_path) as EnemyStats
	if summon_stats == null:
		return false
	var scene := load("res://scenes/enemy/enemy.tscn") as PackedScene
	if scene == null:
		return false
	var minion = scene.instantiate()
	minion.stats = summon_stats
	parent.add_child(minion)
	if minion.has_method("load_enemy_data"):
		minion.load_enemy_data(_spawn_hp_mult, _spawn_spd_mult)
	if minion.has_method("set_path"):
		minion.set_path(cells)
	minion.position += Vector3(randf_range(-SUMMON_SCATTER, SUMMON_SCATTER), 0.0,
		randf_range(-SUMMON_SCATTER, SUMMON_SCATTER))
	push_warning("BossEnemy: triệu hồi ở chế độ dự phòng — quái không được WaveSpawner theo dõi.")
	return true

# ── Vua Địa Ngục: Hơi Thở Dung Nham ───────────────────────────────────────

func _cast_lava_breath() -> void:
	var towers := _towers_in_radius(_boss_stats.ability_radius)
	if towers.is_empty():
		return
	_announce_ability()
	_ring_burst(_boss_stats.ability_radius, Color(1.0, 0.45, 0.15), RING_POINTS)
	var duration: float = maxf(0.2, _boss_stats.disable_duration)
	# KHÔNG khoá quân đang bị luật Rival King làm câm — hai cơ chế khoá chồng
	# nhau thì người chơi mất phần lớn đội hình trong vài giây và không có cách
	# nào phòng bị. Luật Vua đã là hình phạt, boss không nên phạt lần hai.
	var kr := get_node_or_null("/root/GameMap/KingRules")
	for tower in towers:
		if kr != null and tower.has_method("pattern_kind") 				and bool(kr.call("silences", int(tower.pattern_kind()))):
			continue
		_disable_tower(tower, duration)

## Vô hiệu hoá tháp mà KHÔNG sửa tower.gd:
## đặt can_shoot = false rồi khởi động chính cooldown_timer của tháp với thời
## gian mong muốn. Timer đó đã connect sẵn _on_cooldown_timeout() → tháp tự bật
## lại sau `duration`. Không await, không giữ state, boss chết giữa chừng cũng
## không kẹt tháp vĩnh viễn.
func _disable_tower(tower: Node, duration: float) -> void:
	if not is_instance_valid(tower):
		return
	var timer: Variant = tower.get("cooldown_timer")
	if not (timer is Timer) or not is_instance_valid(timer):
		return   # tháp không theo hợp đồng quen thuộc → không đụng vào
	tower.set("can_shoot", false)
	(timer as Timer).start(duration)
	var parent := get_parent()
	if parent and tower is Node3D:
		var pos: Vector3 = (tower as Node3D).global_position
		FX.spawn_burst(parent, pos + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.4, 0.12), 12, 0.8)
		FX.damage_number(parent, pos + Vector3(0.0, 1.1, 0.0), "TÊ LIỆT", Color(1.0, 0.5, 0.2), 15)

# ── Vua Băng Giá: Giá Băng Vĩnh Cửu ───────────────────────────────────────

func _cast_eternal_frost() -> void:
	var radius: float = _boss_stats.ability_radius
	var towers := _towers_in_radius(radius)
	var heal_amount: int = int(round(float(_get_hp_cap()) * maxf(0.0, _boss_stats.self_heal_pct)))
	if towers.is_empty() and heal_amount <= 0:
		return
	_announce_ability()
	_ring_burst(radius, Color(0.55, 0.85, 1.0), RING_POINTS)
	for tower in towers:
		_frost_tower(tower, _boss_stats.slow_cooldown_add, maxf(0.2, _boss_stats.slow_duration))
	if heal_amount > 0:
		heal(heal_amount)

## Tháp trong vùng băng bị cộng cooldown tạm thời.
## Khôi phục được giao cho CHÍNH THÁP (Callable trỏ vào tower, không phải boss)
## nên vẫn chạy đúng hạn kể cả khi boss đã chết trước đó; tháp bị free thì Godot
## tự ngắt kết nối.
func _frost_tower(tower: Node, cooldown_add: float, duration: float) -> void:
	if not is_instance_valid(tower) or tower.has_meta(FROST_META):
		return
	if not tower.has_method("apply_season_buff"):
		return
	var base_penalty: Variant = tower.get("season_speed_penalty")
	var damage_mult:  Variant = tower.get("season_damage_mult")
	if not (base_penalty is float) or not (damage_mult is float):
		return
	var tree := get_tree()
	if tree == null:
		return
	tower.set_meta(FROST_META, true)
	tower.call("apply_season_buff", damage_mult, float(base_penalty) + cooldown_add)
	var restore_timer := tree.create_timer(duration)
	restore_timer.timeout.connect(Callable(tower, "apply_season_buff").bind(damage_mult, base_penalty))
	restore_timer.timeout.connect(Callable(tower, "remove_meta").bind(FROST_META))
	var parent := get_parent()
	if parent and tower is Node3D:
		var pos: Vector3 = (tower as Node3D).global_position
		FX.spawn_burst(parent, pos + Vector3(0.0, 0.5, 0.0), Color(0.6, 0.88, 1.0), 10, 0.7)
		FX.damage_number(parent, pos + Vector3(0.0, 1.1, 0.0), "ĐÓNG BĂNG", Color(0.6, 0.9, 1.0), 15)

# ==========================================================================
# HELPERS
# ==========================================================================

func _towers_in_radius(radius: float) -> Array:
	var result: Array = []
	if not is_inside_tree():
		return result
	var r2: float = radius * radius
	for node in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		if global_position.distance_squared_to((node as Node3D).global_position) <= r2:
			result.append(node)
	return result

## Vẽ vòng tròn bán kính bằng vài burst nhỏ — không cần mesh/scene riêng.
func _ring_burst(radius: float, color: Color, points: int) -> void:
	var parent := get_parent()
	if parent == null or points <= 0:
		return
	for i in points:
		var angle: float = TAU * float(i) / float(points)
		var offset := Vector3(cos(angle) * radius, 0.12, sin(angle) * radius)
		FX.spawn_burst(parent, global_position + offset, color, 4, 0.45)

func _find_wave_spawner() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	var spawner: Variant = parent.get("wave_spawner")
	if spawner is Node and is_instance_valid(spawner):
		return spawner as Node
	return parent.get_node_or_null("WaveSpawner")

func _armor_for_phase(phase: int) -> int:
	var table: Array[int] = DEFAULT_PHASE_ARMOR
	if _boss_stats and not _boss_stats.phase_armor.is_empty():
		table = _boss_stats.phase_armor
	return table[clampi(phase - 1, 0, table.size() - 1)]

func _speed_bonus_per_phase() -> float:
	if _boss_stats:
		return _boss_stats.phase_speed_bonus
	return DEFAULT_SPEED_BONUS

func _current_ability_cooldown() -> float:
	if _boss_stats == null:
		return 999.0
	var table: Array[float] = DEFAULT_PHASE_CD_SCALE
	if not _boss_stats.phase_cooldown_scale.is_empty():
		table = _boss_stats.phase_cooldown_scale
	var scale_factor: float = table[clampi(maxi(_phase, 1) - 1, 0, table.size() - 1)]
	return maxf(0.5, _boss_stats.ability_cooldown * scale_factor)

func _accent_color() -> Color:
	return _boss_stats.accent_color if _boss_stats else Color(1.0, 0.45, 0.2)

func _display_name() -> String:
	if _boss_stats and _boss_stats.display_name != "":
		return _boss_stats.display_name
	return stats.id.capitalize() if stats else "Rival King"

# ── Public API (game_map / HUD đọc) ───────────────────────────────────────

func get_display_name() -> String:
	return _display_name()

func get_title() -> String:
	return _boss_stats.title if _boss_stats else ""

func get_phase() -> int:
	return maxi(_phase, 1)

func get_max_hp() -> int:
	return _get_hp_cap()

func get_accent_color() -> Color:
	return _accent_color()
