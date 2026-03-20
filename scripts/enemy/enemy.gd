# res://scripts/enemies/enemy.gd
extends Area2D
class_name Enemy

signal reached_base(damage: int)
signal enemy_defeated(gold: int)

@export var stats: EnemyStats 

# Biến Runtime (Chạy trong game)
var current_hp: int = 0
var current_speed: float = 0.0
var _is_dead: bool = false   # guard chống die() bị gọi nhiều lần

# Slow debuff
var _slow_amount: float = 0.0
var _slow_timer: float = 0.0

# Burn DoT
var _burn_dps: int = 0
var _burn_timer: float = 0.0
var _burn_tick: float = 1.0  # bắt đầu ở 1.0 → tick đầu tiên sau 1 giây

# Biến đường đi
var path_points: Array[Vector2] = []
var current_point_index: int = 0

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	add_to_group("enemies")
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.visible = false
	if stats:
		load_enemy_data()

func load_enemy_data(health_multiplier: float = 1.0, speed_multiplier: float = 1.0):
	if not stats:
		push_error("Enemy không có stats!")
		return
	if stats.texture:
		sprite.texture = stats.texture
		sprite.scale = stats.scale

	current_hp = max(1, int(round(stats.max_hp * health_multiplier)))
	current_speed = stats.speed * speed_multiplier

func apply_slow(amount: float, duration: float) -> void:
	_slow_amount = max(_slow_amount, amount)
	_slow_timer  = max(_slow_timer, duration)

func apply_burn(dps: int, duration: float) -> void:
	_burn_dps   = max(_burn_dps, dps)
	_burn_timer = max(_burn_timer, duration)

func _process(delta):
	if _is_dead: return
	if path_points.is_empty(): return

	# Xử lý slow
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_amount = 0.0

	# Xử lý burn DoT (tick mỗi 1 giây)
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick  -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 1.0
			take_damage(_burn_dps)

	var effective_speed = current_speed * (1.0 - _slow_amount)
	var target = path_points[current_point_index]

	position = position.move_toward(target, effective_speed * delta)
	
	if position.distance_to(target) < 1.0:
		current_point_index += 1
		if current_point_index >= path_points.size():
			reached_end()

func set_path(grid_path: Array[Vector2i], tile_map_layer: TileMapLayer):
	path_points.clear()
	for grid_pos in grid_path:
		path_points.append(tile_map_layer.map_to_local(grid_pos))
	
	if path_points.size() > 0:
		position = path_points[0]
		current_point_index = 1

func take_damage(amount: int):
	if _is_dead:
		return
	current_hp -= amount
	if current_hp <= 0:
		die()

func die():
	if _is_dead:
		return
	_is_dead = true
	enemy_defeated.emit(stats.gold_reward if stats else 0)
	queue_free()

func reached_end():
	if _is_dead:
		return
	_is_dead = true
	reached_base.emit(stats.damage_to_base if stats else 1)
	queue_free()
