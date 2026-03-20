# res://scripts/entities/SoldierEntity.gd
# Node quân cờ trong game. Kế thừa từ tower.gd hiện tại nhưng mở rộng thêm.
extends Node2D
class_name SoldierEntity

# --- SIGNALS ---
signal soldier_ready(soldier: SoldierEntity)
signal buff_applied(buff_type: String, value: float)

# --- DỮ LIỆU ---
var stats: SoldierStats = null
var grid_position: Vector2i = Vector2i.ZERO

# --- BUFF STACK (Từ nhiều nguồn khác nhau) ---
# Mỗi buff: { "source": "synergy/territory/king/boon", "damage": 0.0, "speed": 0.0, ... }
var active_buffs: Array[Dictionary] = []

# --- CHỈ SỐ TÍNH TOÁN CUỐI (Sau khi áp buff) ---
var final_damage: int = 0
var final_attack_speed: float = 1.0
var final_range: float = 0.0
var final_crit_chance: float = 0.0

# --- COMBAT ---
var targets_in_range: Array[Node] = []
var current_target: Node = null
var can_attack: bool = true

@onready var visual: Sprite2D = $Visual
@onready var range_area: Area2D = $RangeArea
var attack_timer: Timer

func _ready() -> void:
	add_to_group("soldiers")
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_ready)
	add_child(attack_timer)

	if stats:
		_initialize()

func _initialize() -> void:
	if visual and stats.texture:
		visual.texture = stats.texture
	recalculate_final_stats()
	_update_range_collider()

func _process(_delta: float) -> void:
	targets_in_range = targets_in_range.filter(func(e): return is_instance_valid(e))
	if not is_instance_valid(current_target):
		_pick_target()
	if current_target and can_attack:
		_attack()

# --- TÍNH CHỈ SỐ CUỐI ---
func recalculate_final_stats() -> void:
	if not stats: return
	var damage_mult = 1.0
	var speed_mult = 1.0
	var range_mult = 1.0

	for buff in active_buffs:
		damage_mult += buff.get("damage", 0.0)
		speed_mult += buff.get("speed", 0.0)
		range_mult += buff.get("range", 0.0)

	final_damage = int(stats.base_damage * damage_mult)
	final_attack_speed = stats.attack_speed / speed_mult  # Chia = nhanh hơn
	final_range = stats.attack_range * range_mult
	final_crit_chance = stats.crit_chance

	_update_range_collider()

# --- BUFF ---
func add_buff(source: String, buff_data: Dictionary) -> void:
	# Xóa buff cũ cùng nguồn (nếu có) trước khi thêm mới
	remove_buff(source)
	buff_data["source"] = source
	active_buffs.append(buff_data)
	recalculate_final_stats()
	buff_applied.emit(source, buff_data.get("damage", 0.0))

func remove_buff(source: String) -> void:
	active_buffs = active_buffs.filter(func(b): return b.get("source", "") != source)
	recalculate_final_stats()

# --- COMBAT ---
func _pick_target() -> void:
	if targets_in_range.size() > 0:
		current_target = targets_in_range[0]
	else:
		current_target = null

func _attack() -> void:
	can_attack = false
	# TODO: Tạo projectile, xử lý crit
	var is_crit = randf() < final_crit_chance
	var damage = final_damage * (stats.crit_multiplier if is_crit else 1.0)
	# TODO: Spawn projectile với damage này
	attack_timer.start(final_attack_speed)

func _on_attack_ready() -> void:
	can_attack = true

func _update_range_collider() -> void:
	# TODO: Cập nhật CollisionShape2D theo final_range
	pass
