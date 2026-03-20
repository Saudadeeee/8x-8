# res://scripts/towers/tower.gd
extends Node2D

@export var stats: TowerStats

const TILE_SIZE       = 16.0
const SHOW_RANGE_DEBUG: bool = false

@onready var visual:           Sprite2D          = $Visual
@onready var range_area:       Area2D            = $RangeArea
@onready var collision_shape:  CollisionShape2D  = $RangeArea/CollisionShape2D

var projectile_scene = preload("res://scenes/projectile/projectile.tscn")

# ── Computed stats (recalculated from base + all buff layers) ──────────────
var current_damage:       int   = 0
var current_attack_speed: float = 1.0
var current_range:        int   = 0

# ── Buff layer system ─────────────────────────────────────────────────────
# Adding a new buff source = add one enum value + one call to _set_buff_layer().
enum BuffLayer { UPGRADE, BIOME, FAVOR, BOON, AURA, SYNERGY }

var _dmg_bonus: Dictionary = {}  # BuffLayer → float (absolute bonus to base_damage)
var _spd_bonus: Dictionary = {}  # BuffLayer → float (seconds to subtract from attack_speed)
var _rng_bonus: Dictionary = {}  # BuffLayer → int   (tiles to add to attack_range)

# Season is kept separate: damage is a multiplier (not additive), speed is a penalty
var season_damage_mult:  float = 1.0
var season_speed_penalty: float = 0.0

# King Flame ability — temporary burn projectile override (read/written by game_map.gd)
var boon_burn_override: bool = false

# ── Combat state ──────────────────────────────────────────────────────────
var targets_in_range: Array[Enemy] = []
var current_target:   Enemy        = null
var can_shoot:        bool         = true
var cooldown_timer:   Timer

# ==========================================================================
# LIFECYCLE
# ==========================================================================

func _ready() -> void:
	add_to_group("towers")
	z_index = 2

	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	collision_shape.visible = false

	range_area.area_entered.connect(_on_area_entered)
	range_area.area_exited.connect(_on_area_exited)

	if stats:
		load_tower_data()

func _process(_delta) -> void:
	targets_in_range = targets_in_range.filter(func(e): return is_instance_valid(e))
	if not is_instance_valid(current_target):
		update_target()
	if current_target and can_shoot:
		shoot()

func load_tower_data() -> void:
	if stats.texture == null:
		var fallback = "res://assets/towers/%s.png" % stats.id
		if ResourceLoader.exists(fallback):
			stats.texture = load(fallback)
	if stats.texture:
		visual.texture = stats.texture
	recalculate_stats()
	update_range_visual()

# ==========================================================================
# BUFF SYSTEM
# ==========================================================================

## Core recalculate — always sum from base + all active buff layers.
func recalculate_stats() -> void:
	if not stats:
		return
	var total_dmg: float = stats.base_damage
	var total_spd: float = 0.0
	var total_rng: int   = 0
	for v in _dmg_bonus.values(): total_dmg += v
	for v in _spd_bonus.values(): total_spd += v
	for v in _rng_bonus.values(): total_rng += v
	current_damage       = int(total_dmg * season_damage_mult)
	current_attack_speed = max(0.1, stats.attack_speed - total_spd + season_speed_penalty)
	current_range        = stats.attack_range + total_rng

## Internal: write all three axes for one layer and recalculate.
func _set_buff_layer(layer: BuffLayer, dmg: float = 0.0, spd: float = 0.0, rng: int = 0) -> void:
	_dmg_bonus[layer] = dmg
	_spd_bonus[layer] = spd
	_rng_bonus[layer] = rng
	recalculate_stats()
	update_range_visual()

## Internal: remove a layer entirely and recalculate.
func _clear_buff_layer(layer: BuffLayer) -> void:
	_dmg_bonus.erase(layer)
	_spd_bonus.erase(layer)
	_rng_bonus.erase(layer)
	recalculate_stats()
	update_range_visual()

# ── Public buff API (same external signatures, cleaner internals) ──────────

func apply_upgrade(upgrade_data: Dictionary) -> void:
	if not upgrade_data:
		return
	_set_buff_layer(BuffLayer.UPGRADE,
		upgrade_data.get("damage_bonus", 0.0),
		upgrade_data.get("attack_speed_reduction", 0.0))

func apply_biome_buff(biome_data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.BIOME,
		float(biome_data.get("damage_bonus", 0)),
		biome_data.get("attack_speed_reduction", 0.0),
		int(biome_data.get("range_bonus", 0)))

func apply_king_favor_buff(buff_data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.FAVOR,
		buff_data.get("damage_bonus", 0.0),
		buff_data.get("attack_speed_reduction", 0.0))

func apply_boon_buff(buff_data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.BOON,
		buff_data.get("damage_bonus", 0.0),
		buff_data.get("attack_speed_reduction", 0.0))

func remove_boon_buff() -> void:
	boon_burn_override = false
	_clear_buff_layer(BuffLayer.BOON)

func apply_aura_buff(buff_data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.AURA,
		buff_data.get("damage_bonus", 0.0),
		buff_data.get("attack_speed_reduction", 0.0),
		int(buff_data.get("range_bonus", 0)))

func clear_aura_buff() -> void:
	_clear_buff_layer(BuffLayer.AURA)

func reset_cooldown() -> void:
	if cooldown_timer:
		cooldown_timer.stop()
	can_shoot = true

func apply_synergy_buff(buff_data: Dictionary) -> void:
	if not stats:
		return
	# Synergy bonus is expressed as percentage of base — convert to absolute here.
	_set_buff_layer(BuffLayer.SYNERGY,
		stats.base_damage  * buff_data.get("damage_bonus", 0.0),
		stats.attack_speed * buff_data.get("speed_bonus",  0.0),
		int(buff_data.get("range_bonus", 0.0)))

func apply_season_buff(damage_mult: float, speed_penalty: float) -> void:
	season_damage_mult   = damage_mult
	season_speed_penalty = speed_penalty
	recalculate_stats()
	update_range_visual()

func update_range_visual() -> void:
	if not stats:
		return
	if not (collision_shape.shape is CircleShape2D):
		collision_shape.shape = CircleShape2D.new()
	var range_to_use = current_range if current_range > 0 else stats.attack_range
	collision_shape.shape.radius = range_to_use * TILE_SIZE + (TILE_SIZE / 2.0)
	queue_redraw()

# ==========================================================================
# COMBAT
# ==========================================================================

func update_target() -> void:
	targets_in_range = targets_in_range.filter(func(e): return is_instance_valid(e))
	current_target = targets_in_range[0] if targets_in_range.size() > 0 else null

func shoot() -> void:
	can_shoot = false
	var count = stats.projectile_count if stats else 1
	var used_targets: Array = []

	for i in count:
		var tgt: Enemy = null
		for candidate in targets_in_range:
			if is_instance_valid(candidate) and not used_targets.has(candidate):
				tgt = candidate
				break
		if tgt == null:
			tgt = current_target
		if not is_instance_valid(tgt):
			break
		used_targets.append(tgt)
		_fire_projectile(tgt)

	cooldown_timer.start(current_attack_speed)

func _fire_projectile(tgt: Enemy) -> void:
	if not projectile_scene or not is_instance_valid(tgt):
		return
	var bullet = projectile_scene.instantiate()
	bullet.global_position = global_position
	bullet.target = tgt
	bullet.damage = current_damage
	if stats:
		if stats.projectile_texture:
			bullet.texture_data = stats.projectile_texture
		bullet.slow_amount   = stats.slow_amount
		bullet.slow_duration = stats.slow_duration
		bullet.splash_radius = stats.splash_radius
		bullet.burn_dps      = stats.burn_dps
		bullet.burn_duration = stats.burn_duration
	# King Flame ability: grant burn on projectiles even if tower doesn't normally burn
	if boon_burn_override and bullet.burn_dps == 0:
		bullet.burn_dps      = 5
		bullet.burn_duration = 3.0
	get_parent().add_child(bullet)
	bullet.add_to_group("projectiles")

func _on_cooldown_timeout() -> void:
	can_shoot = true

# ==========================================================================
# COLLISION
# ==========================================================================

func _on_area_entered(area) -> void:
	if area is Enemy:
		targets_in_range.append(area)
		if current_target == null:
			current_target = area

func _on_area_exited(area) -> void:
	if area is Enemy:
		targets_in_range.erase(area)
		if current_target == area:
			current_target = null

func _draw() -> void:
	if not SHOW_RANGE_DEBUG:
		return
	if collision_shape.shape is CircleShape2D:
		draw_circle(Vector2.ZERO, collision_shape.shape.radius, Color(0, 1, 0, 0.2))
