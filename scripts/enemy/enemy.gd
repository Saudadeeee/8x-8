# res://scripts/enemies/enemy.gd
extends Area3D
class_name Enemy

signal reached_base(damage: int)
signal enemy_defeated(gold: int)

@export var stats: EnemyStats

# Stats tốc độ trong .tres vẫn là px/s (16 px = 1 tile) — quy đổi sang m/s (1 tile = 1 m)
const PX_TO_M: float = 1.0 / 16.0
const WAYPOINT_THRESHOLD: float = 0.05
const MODEL_DIR := "res://assets/models/%s.gltf"

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
var path_points: Array[Vector3] = []
var current_point_index: int = 0

# ── Juice / feedback ──────────────────────────────────────────────────────
var _mesh_instances: Array[MeshInstance3D] = []   # material_override riêng per instance
var _flash_timer: float = 0.0
var _bob_time: float = 0.0
var _hp_bar_fg: MeshInstance3D = null
var _hp_bar_root: Node3D = null

const COLOR_FLASH := Color(2.5, 2.5, 2.5)   # >1 để cháy sáng
const COLOR_BURN  := Color(1.6, 0.7, 0.4)
const COLOR_SLOW  := Color(0.6, 0.8, 1.5)
const HP_BAR_WIDTH: float = 0.62

@onready var visual: Node3D = $Visual

func _ready():
	add_to_group("enemies")
	var col = get_node_or_null("CollisionShape3D")
	if col:
		col.visible = false
	if stats:
		load_enemy_data()

func load_enemy_data(health_multiplier: float = 1.0, speed_multiplier: float = 1.0):
	if not stats:
		push_error("Enemy không có stats!")
		return
	_build_visual()
	current_hp = max(1, int(round(stats.max_hp * health_multiplier)))
	current_speed = stats.speed * PX_TO_M * speed_multiplier
	_build_hp_bar()

## Load model 3D theo stats.id; fallback = Sprite3D billboard dùng texture 2D cũ.
func _build_visual() -> void:
	if not visual:
		return
	for child in visual.get_children():
		child.queue_free()

	_mesh_instances.clear()
	var model_path := MODEL_DIR % stats.id
	if ResourceLoader.exists(model_path):
		var scene := load(model_path) as PackedScene
		if scene:
			var model := scene.instantiate()
			visual.add_child(model)
			# Material của glTF share giữa mọi instance cùng loại —
			# duplicate để tint per-instance (flash/debuff) không lan sang con khác.
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				var src: Material = mi.get_active_material(0)
				if src:
					mi.material_override = src.duplicate()
					_mesh_instances.append(mi)
			return

	var billboard := Sprite3D.new()
	billboard.pixel_size = 0.03
	billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard.position = Vector3(0.0, 0.4, 0.0)
	if stats.texture:
		billboard.texture = stats.texture
		billboard.scale = Vector3(stats.scale.x, stats.scale.y, 1.0)
	visual.add_child(billboard)

## HP bar billboard — 2 quad (nền + máu), chỉ hiện khi mất máu.
func _build_hp_bar() -> void:
	if _hp_bar_root and is_instance_valid(_hp_bar_root):
		_hp_bar_root.queue_free()
	_hp_bar_root = Node3D.new()
	_hp_bar_root.name = "HpBar"
	add_child(_hp_bar_root)
	_hp_bar_root.position = Vector3(0.0, 1.25, 0.0)
	_hp_bar_root.visible = false

	var bg := MeshInstance3D.new()
	bg.mesh = _make_bar_quad(HP_BAR_WIDTH + 0.04, 0.1, Color(0.08, 0.05, 0.05, 0.85))
	_hp_bar_root.add_child(bg)

	_hp_bar_fg = MeshInstance3D.new()
	_hp_bar_fg.mesh = _make_bar_quad(HP_BAR_WIDTH, 0.06, Color(0.25, 0.9, 0.3, 0.95))
	_hp_bar_fg.position = Vector3(0.0, 0.0, 0.001)
	((_hp_bar_fg.mesh as QuadMesh).material as StandardMaterial3D).render_priority = 1
	_hp_bar_root.add_child(_hp_bar_fg)

func _make_bar_quad(w: float, h: float, col: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = col
	quad.material = mat
	return quad

func _update_hp_bar() -> void:
	if not _hp_bar_fg or not stats:
		return
	var ratio: float = clampf(float(current_hp) / float(max(1, stats.max_hp)), 0.0, 1.0)
	_hp_bar_root.visible = ratio < 1.0
	_hp_bar_fg.scale.x = maxf(ratio, 0.01)
	# Billboard quad: scale từ giữa — không cần offset, đủ đọc ở cỡ này
	var mat := (_hp_bar_fg.mesh as QuadMesh).material as StandardMaterial3D
	mat.albedo_color = Color(0.9, 0.25, 0.2, 0.95) if ratio < 0.35 \
		else (Color(0.95, 0.75, 0.2, 0.95) if ratio < 0.7 else Color(0.25, 0.9, 0.3, 0.95))

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

	_face_direction(target)
	position = position.move_toward(target, effective_speed * delta)

	# Bob khi di chuyển — nhún theo tốc độ thực tế
	_bob_time += delta * effective_speed * 9.0
	if visual:
		visual.position.y = absf(sin(_bob_time)) * 0.07
		visual.rotation.z = sin(_bob_time) * 0.05

	_update_tint(delta)

	if position.distance_to(target) < WAYPOINT_THRESHOLD:
		current_point_index += 1
		if current_point_index >= path_points.size():
			reached_end()

## Tint model theo trạng thái: flash trúng đòn > burn > slow > bình thường.
func _update_tint(delta: float) -> void:
	if _mesh_instances.is_empty():
		return
	if _flash_timer > 0.0:
		_flash_timer -= delta
	var tint := Color.WHITE
	if _flash_timer > 0.0:
		tint = COLOR_FLASH
	elif _burn_timer > 0.0:
		tint = COLOR_BURN.lerp(Color.WHITE, 0.5 + 0.5 * sin(_bob_time * 2.0))
	elif _slow_timer > 0.0:
		tint = COLOR_SLOW
	for mi in _mesh_instances:
		if is_instance_valid(mi) and mi.material_override is BaseMaterial3D:
			(mi.material_override as BaseMaterial3D).albedo_color = tint

## Xoay mặt theo hướng di chuyển (guard vector 0 / colinear với UP).
func _face_direction(target: Vector3) -> void:
	var dir := target - position
	dir.y = 0.0
	if dir.length_squared() < 0.000001:
		return
	look_at(global_position + dir, Vector3.UP)

func set_path(grid_path: Array[Vector2i]):
	path_points.clear()
	for grid_pos in grid_path:
		path_points.append(GridUtil.cell_to_world(grid_pos))

	if path_points.size() > 0:
		position = path_points[0]
		current_point_index = 1

func take_damage(amount: int):
	if _is_dead:
		return
	current_hp -= amount
	_flash_timer = 0.12
	_update_hp_bar()
	if current_hp <= 0:
		die()

func die():
	if _is_dead:
		return
	_is_dead = true
	enemy_defeated.emit(stats.gold_reward if stats else 0)

	# Hiệu ứng chết: burst + squash rồi mới free
	var burst_color := Color(0.5, 0.85, 0.3)
	if stats and stats.id == "skeleton":
		burst_color = Color(0.9, 0.88, 0.8)
	elif stats and stats.id == "dark_knight":
		burst_color = Color(0.3, 0.28, 0.38)
	elif stats and stats.id == "demon_imp":
		burst_color = Color(0.85, 0.3, 0.35)
	FX.spawn_burst(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), burst_color, 14, 1.0)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	remove_from_group("enemies")   # xác chết không còn là target
	if _hp_bar_root:
		_hp_bar_root.visible = false
	if visual and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
	else:
		queue_free()

func reached_end():
	if _is_dead:
		return
	_is_dead = true
	FX.spawn_burst(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Color(0.95, 0.2, 0.2), 10, 0.8)
	reached_base.emit(stats.damage_to_base if stats else 1)
	queue_free()
