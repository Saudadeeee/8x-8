# res://scripts/map/king_ability_executor.gd
# Thực thi Royal Ability và quản lý Boon buff timer.
# Được game_map.gd khởi tạo và làm con node.
# Ưu tiên data-driven: KingStats.ability_script (script con của KingAbility).
# Nếu vua không có ability_script hợp lệ → fallback hardcoded match (hành vi cũ).
extends Node
class_name KingAbilityExecutor

# --- SIGNALS ---
signal ability_executed(king_id: String)
signal boon_expired

# --- CONSTANTS ---
const BOON_DURATION: float = 10.0

# --- REFS (set bởi game_map sau add_child) ---
var king_manager: KingManager = null
var _game_manager = null

func setup(km: KingManager, gm: Node) -> void:
	king_manager   = km
	_game_manager  = gm

# --- PUBLIC API ---
func execute() -> void:
	var king_id := ""
	var king_stats: KingStats = null
	if _game_manager and _game_manager.selected_king:
		king_stats = _game_manager.selected_king
		king_id = king_stats.id

	# 1) Data-driven: load + chạy KingStats.ability_script
	if _execute_from_script(king_stats):
		ability_executed.emit(king_id)
		return

	# 2) Fallback hardcoded — chỉ chạy khi thiếu/hỏng ability_script
	push_warning("KingAbilityExecutor: '%s' không có ability_script hợp lệ — dùng fallback hardcoded." \
		% (king_id if king_id != "" else "unknown"))
	match king_id:
		"king_iron":    _execute_iron_decree()
		"king_phantom": _execute_phantom_veil()
		"king_flame":   _execute_flame_inferno()
		_:              _execute_generic_boon()

	ability_executed.emit(king_id)

# --- DATA-DRIVEN PATH ---

## Thử instantiate + chạy ability từ KingStats.ability_script.
## Trả về true nếu đã thực thi thành công.
func _execute_from_script(king_stats: KingStats) -> bool:
	if not king_stats or king_stats.ability_script == null:
		return false
	var ability_script_ref: Script = king_stats.ability_script
	if not ability_script_ref.can_instantiate():
		push_error("KingAbilityExecutor: ability_script của '%s' không thể instantiate." % king_stats.id)
		return false
	var ability = ability_script_ref.new()
	if not (ability is KingAbility) and not ability.has_method("execute"):
		push_error("KingAbilityExecutor: ability_script của '%s' thiếu execute(ctx)." % king_stats.id)
		return false
	ability.execute(build_context())
	return true

## Context truyền cho KingAbility.execute()
func build_context() -> Dictionary:
	return {
		"tree":         get_tree(),
		"executor":     self,
		"king_manager": king_manager,
		"game_manager": _game_manager,
	}

# --- GROUP-BASED TARGETING HELPERS (dùng chung cho ability scripts) ---

## Toàn bộ tháp còn hợp lệ trên bàn cờ (group "towers")
func get_towers() -> Array:
	var result: Array = []
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower):
			result.append(tower)
	return result

## Toàn bộ địch còn hợp lệ trên bàn cờ (group "enemies")
func get_enemies() -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			result.append(enemy)
	return result

## Hẹn giờ gỡ Boon buff sau duration giây — ability scripts gọi qua ctx["executor"]
func schedule_boon_expiry(duration: float = BOON_DURATION) -> void:
	get_tree().create_timer(duration).timeout.connect(_on_boon_expired)

# --- FALLBACK ABILITY IMPLEMENTATIONS (hardcoded — giữ nguyên hành vi cũ) ---

func _execute_iron_decree() -> void:
	# +30 Royal Decree ngay lập tức + Pawn +50% tốc độ 8s
	if king_manager:
		king_manager.add_royal_decree(30.0)
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.has_method("apply_boon_buff"):
			continue
		if not tower.get("stats") or tower.stats.id != "pawn":
			continue
		tower.apply_boon_buff({
			"damage_bonus":           0.0,
			"attack_speed_reduction": tower.stats.attack_speed * 0.5
		})
	get_tree().create_timer(8.0).timeout.connect(_on_boon_expired)

func _execute_phantom_veil() -> void:
	# Reset cooldown tất cả towers + Slow địch 50% trong 5s
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("reset_cooldown"):
			tower.reset_cooldown()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
			enemy.apply_slow(0.5, 5.0)

func _execute_flame_inferno() -> void:
	# 50 dmg tất cả địch + Queen double damage + burn 10s
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(50)
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.has_method("apply_boon_buff"):
			continue
		if not tower.get("stats") or tower.stats.id != "queen":
			continue
		tower.apply_boon_buff({
			"damage_bonus":           float(tower.stats.base_damage),
			"attack_speed_reduction": 0.0
		})
		tower.set("boon_burn_override", true)
	get_tree().create_timer(BOON_DURATION).timeout.connect(_on_boon_expired)

func _execute_generic_boon() -> void:
	# Fallback cho king chưa define
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("apply_boon_buff"):
			tower.apply_boon_buff({"damage_bonus": 8.0, "attack_speed_reduction": 0.3})
	get_tree().create_timer(BOON_DURATION).timeout.connect(_on_boon_expired)

func _on_boon_expired() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.has_method("remove_boon_buff"):
			continue
		tower.remove_boon_buff()
		if tower.get("boon_burn_override") != null:
			tower.set("boon_burn_override", false)
	boon_expired.emit()
