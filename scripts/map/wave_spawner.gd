# res://scripts/map/wave_spawner.gd
# Quản lý spawn enemy, mùa (Season), và thống kê wave.
# Được game_map.gd khởi tạo và làm con node.
extends Node

# --- SIGNALS ---
signal enemy_reached_base(damage: int)
signal enemy_defeated(gold: int)
signal wave_cleared

# --- CONSTANTS ---
const ENEMIES_PER_WAVE: int = 10
const ENEMIES_PER_WAVE_INCREMENT: int = 2
const ENEMY_HEALTH_SCALE_PER_WAVE: float = 0.12
const ENEMY_SPEED_SCALE_PER_WAVE: float = 0.03
const SHOP_EXTRA_ENEMY_COUNT: int = 3
const SHOP_EXTRA_HEALTH_MULTIPLIER: float = 0.25
const SHOP_EXTRA_SPEED_MULTIPLIER: float = 0.08
const SPAWN_INTERVAL: float = 0.8

const _ENEMY_DISPLAY_NAMES := {
	"orc": "Orc", "goblin": "Goblin", "skeleton": "Xương Cốt",
	"dark_knight": "Kỵ Sĩ Đen", "demon_imp": "Quỷ Con",
}

const SEASON_BUFFS := {
	0: {"name": "Mùa Xuân", "damage_mult": 1.0,  "speed_penalty": 0.0,  "desc": "Yên bình. Không ảnh hưởng chỉ số."},
	1: {"name": "Mùa Hè",   "damage_mult": 1.15, "speed_penalty": 0.0,  "desc": "+15% sát thương toàn bộ tháp."},
	2: {"name": "Mùa Thu",  "damage_mult": 1.0,  "speed_penalty": 0.15, "desc": "Không khí u ám: +0.15s cooldown tháp."},
	3: {"name": "Mùa Đông", "damage_mult": 0.9,  "speed_penalty": 0.2,  "desc": "Giá lạnh: -10% sát, +0.2s cooldown tháp."},
}

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

# --- REFS (set bởi game_map sau khi add_child) ---
var layer_grass: TileMapLayer = null
var _parent_node: Node = null  # game_map — dùng để add_child enemy

# --- STATE ---
var current_path_grid: Array[Vector2i] = []
var enemies_alive: int = 0
var enemies_spawned: int = 0
var _enemies_to_spawn: int = 0
var _wave_number: int = 1
var _active_shop_boost: bool = false

var _enemy_stats: Dictionary = {}
var _wave_spawn_timer: Timer = null
var _enemy_scene = preload("res://scenes/enemy/enemy.tscn")

# --- KHỞI TẠO ---
func _ready() -> void:
	_wave_spawn_timer = Timer.new()
	_wave_spawn_timer.wait_time = SPAWN_INTERVAL
	_wave_spawn_timer.one_shot = false
	_wave_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_wave_spawn_timer)
	_load_enemy_stats()

func setup(path: Array[Vector2i], grass: TileMapLayer, parent: Node) -> void:
	current_path_grid = path
	layer_grass = grass
	_parent_node = parent

# --- ĐIỀU KHIỂN WAVE ---
func start_wave(wave_num: int, enemy_count: int, shop_boost: bool) -> void:
	_wave_number = wave_num
	_enemies_to_spawn = enemy_count
	_active_shop_boost = shop_boost
	enemies_spawned = 0
	enemies_alive = 0
	_wave_spawn_timer.start()

func stop() -> void:
	_wave_spawn_timer.stop()

func get_enemies_to_spawn() -> int:
	return _enemies_to_spawn

# --- SEASON ---
func get_season(wave_num: int) -> Season:
	if wave_num <= 2:   return Season.SPRING
	elif wave_num <= 5: return Season.SUMMER
	elif wave_num <= 8: return Season.AUTUMN
	else:               return Season.WINTER

func get_season_name(wave_num: int) -> String:
	match get_season(wave_num):
		Season.SPRING: return "Mùa Xuân (Wild)"
		Season.SUMMER: return "Mùa Hè (Mixed)"
		Season.AUTUMN: return "Mùa Thu (Undead)"
		Season.WINTER: return "Mùa Đông (Hell)"
	return ""

func get_season_buff(wave_num: int) -> Dictionary:
	return SEASON_BUFFS.get(int(get_season(wave_num)), {})

# --- TÍNH SỐ ENEMY ---
func calculate_enemies_for_wave(wave: int, boost: bool = false) -> int:
	var base_count = ENEMIES_PER_WAVE + max(0, wave - 1) * ENEMIES_PER_WAVE_INCREMENT
	if boost:
		base_count += SHOP_EXTRA_ENEMY_COUNT
	return base_count

func get_health_multiplier(wave_num: int, shop_boost: bool = false) -> float:
	var m = 1.0 + float(max(wave_num - 1, 0)) * ENEMY_HEALTH_SCALE_PER_WAVE
	if shop_boost:
		m += SHOP_EXTRA_HEALTH_MULTIPLIER
	return m

func get_speed_multiplier(wave_num: int, shop_boost: bool = false) -> float:
	var m = 1.0 + float(max(wave_num - 1, 0)) * ENEMY_SPEED_SCALE_PER_WAVE
	if shop_boost:
		m += SHOP_EXTRA_SPEED_MULTIPLIER
	return m

# --- SPAWN ---
func _on_spawn_timer_timeout() -> void:
	if enemies_spawned < _enemies_to_spawn:
		_spawn_one()
	else:
		_wave_spawn_timer.stop()

func _spawn_one() -> void:
	spawn_enemy(true)

func spawn_enemy(from_wave: bool = false) -> bool:
	if current_path_grid.is_empty():
		push_warning("WaveSpawner: Chưa có đường đi!")
		return false
	if not _parent_node:
		push_error("WaveSpawner: _parent_node chưa được set!")
		return false

	var pool = _get_season_enemy_pool(_wave_number)
	if pool.is_empty():
		push_error("WaveSpawner: Enemy pool rỗng — kiểm tra res/enemy/")
		return false

	var chosen_stats: EnemyStats = pool[randi() % pool.size()]
	if chosen_stats == null:
		push_error("WaveSpawner: Enemy stats null trong pool")
		return false

	var new_enemy = _enemy_scene.instantiate()
	new_enemy.stats = chosen_stats
	_parent_node.add_child(new_enemy)

	new_enemy.reached_base.connect(_on_enemy_reached_base)
	new_enemy.enemy_defeated.connect(_on_enemy_defeated)

	var hp_mult = get_health_multiplier(_wave_number, _active_shop_boost)
	var spd_mult = get_speed_multiplier(_wave_number, _active_shop_boost)
	if new_enemy.has_method("load_enemy_data"):
		new_enemy.load_enemy_data(hp_mult, spd_mult)
	if new_enemy.has_method("set_path"):
		new_enemy.set_path(current_path_grid, layer_grass)

	enemies_alive += 1
	if from_wave:
		enemies_spawned += 1
	return true

# --- SIGNAL HANDLERS ---
func _on_enemy_reached_base(damage: int) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemy_reached_base.emit(damage)
	_check_wave_cleared()

func _on_enemy_defeated(gold: int) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemy_defeated.emit(gold)
	_check_wave_cleared()

func _check_wave_cleared() -> void:
	if enemies_spawned >= _enemies_to_spawn and enemies_alive <= 0:
		wave_cleared.emit()

# --- ENEMY POOL ---
func _get_enemy(id: String) -> EnemyStats:
	return _enemy_stats.get(id, _enemy_stats.get("orc"))

func _get_season_enemy_pool(wave_num: int) -> Array:
	var pool: Array = []
	match get_season(wave_num):
		Season.SPRING:
			for i in 3: pool.append(_get_enemy("goblin"))
			for i in 2: pool.append(_get_enemy("orc"))
		Season.SUMMER:
			for i in 2: pool.append(_get_enemy("orc"))
			for i in 2: pool.append(_get_enemy("goblin"))
			pool.append(_get_enemy("skeleton"))
		Season.AUTUMN:
			for i in 2: pool.append(_get_enemy("skeleton"))
			pool.append(_get_enemy("dark_knight"))
			pool.append(_get_enemy("demon_imp"))
			pool.append(_get_enemy("orc"))
		Season.WINTER:
			for i in 2: pool.append(_get_enemy("dark_knight"))
			for i in 2: pool.append(_get_enemy("demon_imp"))
			pool.append(_get_enemy("skeleton"))
	return pool

func _load_enemy_stats() -> void:
	_enemy_stats.clear()
	var dir = DirAccess.open("res://res/enemy/")
	if not dir:
		push_error("WaveSpawner: Không thể mở res://res/enemy/")
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var stats = load("res://res/enemy/" + file) as EnemyStats
			if stats and stats.id != "":
				_enemy_stats[stats.id] = stats
		file = dir.get_next()
	dir.list_dir_end()

# --- WAVE INTEL ---
func get_wave_intel_text(wave_num: int) -> String:
	var pool = _get_season_enemy_pool(wave_num)
	var counts: Dictionary = {}
	for s: EnemyStats in pool:
		if not s: continue
		counts[s.id] = counts.get(s.id, 0) + 1
	var parts: Array[String] = []
	for enemy_id in counts.keys():
		var display: String = _ENEMY_DISPLAY_NAMES.get(enemy_id, enemy_id.capitalize())
		parts.append("%s×%d" % [display, counts[enemy_id]])
	var total = calculate_enemies_for_wave(wave_num)
	var sbuff: Dictionary = get_season_buff(wave_num)
	var season_effect: String = sbuff.get("desc", "")
	return "Wave %d (%s) — %d địch: %s  |  %s" % [wave_num, get_season_name(wave_num), total, ", ".join(parts), season_effect]

func build_wave_intel_data(wave_num: int) -> Dictionary:
	var pool = _get_season_enemy_pool(wave_num)
	var counts: Dictionary = {}
	var first_seen: Dictionary = {}
	for s: EnemyStats in pool:
		if not s: continue
		counts[s.id] = counts.get(s.id, 0) + 1
		if not first_seen.has(s.id):
			first_seen[s.id] = s
	var hp_mult = get_health_multiplier(wave_num)
	var spd_mult = get_speed_multiplier(wave_num)
	var enemy_list: Array = []
	for enemy_id in counts.keys():
		var stats: EnemyStats = first_seen[enemy_id]
		enemy_list.append({
			"id": enemy_id,
			"display": _ENEMY_DISPLAY_NAMES.get(enemy_id, enemy_id.capitalize()),
			"count": counts[enemy_id],
			"hp": int(stats.max_hp * hp_mult),
			"speed": int(stats.speed * spd_mult),
			"damage": stats.damage_to_base,
			"gold": stats.gold_reward,
		})
	var sbuff: Dictionary = get_season_buff(wave_num)
	return {
		"wave": wave_num,
		"total": calculate_enemies_for_wave(wave_num),
		"season_name": get_season_name(wave_num),
		"season_desc": sbuff.get("desc", ""),
		"enemies": enemy_list,
	}
