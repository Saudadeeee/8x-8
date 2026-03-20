# res://scripts/managers/WaveManager.gd
# DEPRECATED — Chức năng đã được chuyển sang scripts/map/wave_spawner.gd
# File này không còn được sử dụng và có thể xóa an toàn.
extends Node
class_name WaveManager

# --- SIGNALS ---
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Node)
signal all_waves_cleared()

# --- THAM CHIẾU ---
@export var enemy_container: Node2D         # Node chứa các enemy
@export var path_layer: TileMapLayer        # Để enemy biết đường đi
@export var wave_data_list: Array[Resource] = [] # Danh sách WaveData

# --- RUNTIME ---
var current_wave_index: int = -1
var active_enemies: Array[Node] = []
var is_wave_active: bool = false
var spawn_timer: Timer

## Đường đi của enemy trên grid (phải được set từ game_map trước khi start_next_wave)
@export var current_path_grid: Array[Vector2i] = []

var _spawn_queue: Array = []          # Array[EnemyStats] — hàng đợi spawn
var _current_spawn_interval: float = 0.8

var _enemy_scene: PackedScene = preload("res://scenes/enemy/enemy.tscn")

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

# --- KHỞI ĐỘNG WAVE ---
func start_next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= wave_data_list.size():
		all_waves_cleared.emit()
		return

	var wave_data: WaveData = wave_data_list[current_wave_index] as WaveData
	is_wave_active = true
	active_enemies.clear()
	wave_started.emit(wave_data.wave_number)
	_spawn_wave(wave_data)

func _spawn_wave(wave_data: WaveData) -> void:
	_spawn_queue.clear()
	_current_spawn_interval = wave_data.spawn_interval if wave_data.spawn_interval > 0.0 else 0.8

	# Xây hàng đợi từ spawn_groups
	for group in wave_data.spawn_groups:
		var stats: EnemyStats = group.get("stats") as EnemyStats
		var count: int = group.get("count", 1)
		var delay: float = group.get("delay", 0.0)
		if not stats:
			continue
		for i in range(count):
			_spawn_queue.append({ "stats": stats, "delay": delay })

	_spawn_queue.shuffle()

	if _spawn_queue.is_empty():
		_check_wave_complete()
		return

	_schedule_next_spawn()

func _schedule_next_spawn() -> void:
	if _spawn_queue.is_empty():
		return
	var next: Dictionary = _spawn_queue[0]
	var wait: float = max(_current_spawn_interval, next.get("delay", 0.0))
	spawn_timer.wait_time = wait
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if _spawn_queue.is_empty():
		return
	var entry: Dictionary = _spawn_queue.pop_front()
	_spawn_enemy(entry.get("stats") as EnemyStats)
	if not _spawn_queue.is_empty():
		_schedule_next_spawn()

func _spawn_enemy(stats: EnemyStats) -> void:
	if not stats:
		push_warning("WaveManager: enemy stats null, bỏ qua.")
		return
	if not enemy_container:
		push_error("WaveManager: enemy_container chưa được set!")
		return
	if current_path_grid.is_empty():
		push_error("WaveManager: current_path_grid rỗng — set path trước khi spawn!")
		return

	var enemy: Node = _enemy_scene.instantiate()
	enemy.stats = stats
	enemy_container.add_child(enemy)

	if enemy.has_method("load_enemy_data"):
		enemy.load_enemy_data()

	if enemy.has_method("set_path") and path_layer:
		enemy.set_path(current_path_grid, path_layer)

	register_enemy(enemy)
	enemy_spawned.emit(enemy)

# --- THEO DÕI ENEMY ---
func register_enemy(enemy: Node) -> void:
	active_enemies.append(enemy)
	if enemy.has_signal("enemy_defeated"):
		enemy.enemy_defeated.connect(_on_enemy_defeated.bind(enemy))
	if enemy.has_signal("reached_base"):
		enemy.reached_base.connect(_on_enemy_reached_base.bind(enemy))

func _on_enemy_defeated(gold: int, enemy: Node) -> void:
	active_enemies.erase(enemy)
	GameManagerSingleton.add_gold(gold)
	GameManagerSingleton.run_enemies_killed += 1
	_check_wave_complete()

func _on_enemy_reached_base(damage: int, enemy: Node) -> void:
	active_enemies.erase(enemy)
	GameManagerSingleton.take_damage(damage)
	_check_wave_complete()

func _check_wave_complete() -> void:
	if active_enemies.is_empty() and is_wave_active:
		is_wave_active = false
		var wave_data: WaveData = wave_data_list[current_wave_index] as WaveData
		wave_completed.emit(wave_data.wave_number)
		GameManagerSingleton.add_gold(wave_data.gold_reward)
		# Kiểm tra có Encounter không
		if wave_data.has_encounter:
			GameManagerSingleton.change_state(GameManagerSingleton.GameState.ENCOUNTER)
		else:
			GameManagerSingleton.change_state(GameManagerSingleton.GameState.PREPARING)
