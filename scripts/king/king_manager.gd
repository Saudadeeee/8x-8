extends Node
class_name KingManager

const KING_DATA_RESOURCE := preload("res://scripts/king/king_data.gd")

signal royal_decree_changed(amount: float)
signal king_changed(new_king: KingData)
## Phát ra khi King dùng kỹ năng thành công — game_map kết nối để thực thi hiệu ứng
signal ability_activated(ability_name: String, king_stats: KingStats)
signal ability_cooldown_changed(remaining: float)

@export var kings: Array[KingData] = []
@export var default_decree_cap: float = 120.0

var current_king: KingData
var royal_decree: float = 0.0
var decree_cap: float = default_decree_cap
var territory_map: Dictionary = {}
var favor_tracker: Dictionary = {}
var _king_stats_ref: KingStats = null   # KingStats đã chọn từ King Select
var _ability_cooldown_remaining: float = 0.0

func _ready() -> void:
	_ensure_sample_kings()
	if kings.size() > 0:
		set_current_king(kings[0])
	else:
		push_warning("KingManager: No kings were provided.")
	set_process(true)

func _process(delta: float) -> void:
	if current_king == null:
		return
	var regen_amount = current_king.decree_regen * delta
	if regen_amount > 0.0:
		var next_amount = clamp(royal_decree + regen_amount, 0.0, decree_cap)
		if !is_equal_approx(next_amount, royal_decree):
			royal_decree = next_amount
			royal_decree_changed.emit(royal_decree)
	if _ability_cooldown_remaining > 0.0:
		_ability_cooldown_remaining = max(0.0, _ability_cooldown_remaining - delta)
		ability_cooldown_changed.emit(_ability_cooldown_remaining)

func set_current_king(king: KingData) -> void:
	if king == null:
		return
	current_king = king
	decree_cap = max(king.max_royal_decree, default_decree_cap)
	royal_decree = clamp(king.starting_royal_decree, 0.0, decree_cap)
	territory_map.clear()
	_initialize_favor()
	king_changed.emit(king)
	royal_decree_changed.emit(royal_decree)

func spend_royal_decree(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if royal_decree >= cost:
		royal_decree -= cost
		royal_decree_changed.emit(royal_decree)
		return true
	return false

func can_afford(cost: float) -> bool:
	return royal_decree >= cost

func add_royal_decree(amount: float) -> void:
	if amount <= 0.0:
		return
	royal_decree = clamp(royal_decree + amount, 0.0, decree_cap)
	royal_decree_changed.emit(royal_decree)

func use_ability() -> bool:
	if not _king_stats_ref:
		return false
	if _ability_cooldown_remaining > 0.0:
		push_warning("KingManager: Kỹ năng đang hồi chiêu! Còn %.1fs" % _ability_cooldown_remaining)
		return false
	var cost := _king_stats_ref.ability_decree_cost
	if not can_afford(cost):
		push_warning("KingManager: Không đủ RD — cần %.1f, hiện có %.1f" % [cost, royal_decree])
		return false
	spend_royal_decree(cost)
	_ability_cooldown_remaining = _king_stats_ref.ability_cooldown
	ability_cooldown_changed.emit(_ability_cooldown_remaining)
	ability_activated.emit(_king_stats_ref.ability_name, _king_stats_ref)
	return true

func is_ability_ready() -> bool:
	return _ability_cooldown_remaining <= 0.0

func register_territories(positions: Array[Vector2i], tile_type: String) -> void:
	if current_king == null:
		return
	for pos in positions:
		territory_map[pos] = {
			"tile_type": tile_type,
			"king": current_king.display_name
		}

func get_territory_count() -> int:
	return territory_map.size()

func format_favor_summary() -> String:
	if favor_tracker.is_empty():
		return "None"
	var tokens: Array[String] = []
	for tag in favor_tracker.keys():
		tokens.append("%s ×%.1f" % [tag, favor_tracker[tag]])
	return ", ".join(tokens)

func get_territory_summary() -> String:
	if territory_map.is_empty():
		return "None"
	var tokens: Array[String] = []
	for entry in territory_map.values():
		if entry.has("tile_type"):
			tokens.append(entry["tile_type"])
	return ", ".join(tokens)

func adjust_favor(tag: String, delta: float = 1.0) -> void:
	if tag == "":
		return
	var current_value = favor_tracker.get(tag, 0.0)
	favor_tracker[tag] = clamp(current_value + delta, 0.0, 999.0)

func get_current_royal_decree() -> float:
	return royal_decree

func get_current_king_name() -> String:
	return current_king.display_name if current_king else ""

func _initialize_favor() -> void:
	favor_tracker.clear()
	if current_king == null:
		return
	for tag in current_king.king_favor_targets:
		favor_tracker[tag] = 1.0

# --- Khởi tạo từ KingStats (kết nối với King Select) ---
func initialize_from_king_stats(king_stats: KingStats) -> void:
	if not king_stats:
		return
	_king_stats_ref = king_stats
	var kd = KING_DATA_RESOURCE.new() as KingData
	kd.id = king_stats.id
	kd.display_name = king_stats.king_name
	kd.description = king_stats.lore
	kd.starting_royal_decree = king_stats.base_royal_decree
	kd.max_royal_decree = king_stats.decree_max
	kd.decree_regen = king_stats.decree_regen_rate
	kd.king_favor_targets = king_stats.favored_unit_types.duplicate()
	if kings.is_empty():
		kings.append(kd)
	else:
		kings[0] = kd
	set_current_king(kd)

# --- Áp dụng King's Favor lên tháp vừa được đặt ---
func apply_favor_to_tower(tower: Node) -> void:
	if not _king_stats_ref or not current_king or not tower:
		return
	if not tower.has_method("apply_king_favor_buff") or not tower.get("stats"):
		return
	var stats: TowerStats = tower.stats
	if not stats:
		return
	var unit_type_name = TowerStats.UnitType.keys()[stats.type].to_lower()
	var is_favored = false
	for fav_tag in current_king.king_favor_targets:
		if fav_tag.to_lower() in stats.name.to_lower() or fav_tag.to_lower() == unit_type_name:
			is_favored = true
			break
	if is_favored:
		tower.apply_king_favor_buff({
			"damage_bonus": _king_stats_ref.favor_damage_bonus * float(stats.base_damage),
			"attack_speed_reduction": _king_stats_ref.favor_speed_bonus * stats.attack_speed
		})

func _ensure_sample_kings() -> void:
	if kings.size() > 0:
		return
	kings = [
		_build_sample_king("royal_phalanx", "Lord Ares", "Favours disciplined foot troops.", ["Foot", "Shield"], ["Plains", "Castle"], 25.0, 160.0, 1.5),
		_build_sample_king("midnight_watch", "Queen Nocturne", "Excels at ranged and debuff artillery.", ["Ranged", "Mystic"], ["Sanctuary", "Night Zone"], 18.0, 140.0, 2.0)
	]

func _build_sample_king(id: String, display_name_text: String, description: String, favor_tags: Array[String], territory_types: Array[String], start_decree: float, max_decree: float, regen: float) -> KingData:
	var king = KING_DATA_RESOURCE.new() as KingData
	king.id = id
	king.display_name = display_name_text
	king.description = description
	king.king_favor_targets = favor_tags.duplicate()
	king.territory_preferences = territory_types.duplicate()
	king.starting_royal_decree = start_decree
	king.max_royal_decree = max_decree
	king.decree_regen = regen
	king.synergy_tags = favor_tags.duplicate()
	var sample_unique_units: Array[String] = ["Foot Sergeant", "Crystal Archer"]
	king.unique_units = sample_unique_units
	king.territory_bonus = {"damage": 0.1, "regen": 0.05}
	return king
