# res://scripts/entities/KingEntity.gd
# Node đại diện cho vua trong ván chơi.
# Xử lý Crown's Boon, King's Favor, và Royal Ability.
extends Node2D
class_name KingEntity

# --- SIGNALS ---
signal ability_used(king_id: String)
signal boon_activated()
signal boon_expired()
signal favor_applied(unit_type: String, buff: Dictionary)

# --- DỮ LIỆU ---
var stats: KingStats = null

# --- RUNTIME ---
var ability_cooldown_remaining: float = 0.0
var is_ability_ready: bool = true
var is_boon_active: bool = false
var boon_timer: float = 0.0
const BOON_DURATION: float = 5.0

func _ready() -> void:
	if stats:
		_apply_king_setup()

func _process(delta: float) -> void:
	# Cooldown kỹ năng vua
	if not is_ability_ready:
		ability_cooldown_remaining -= delta
		if ability_cooldown_remaining <= 0:
			is_ability_ready = true

	# Crown's Boon timer
	if is_boon_active:
		boon_timer -= delta
		if boon_timer <= 0:
			_deactivate_boon()

func _apply_king_setup() -> void:
	# TODO: Áp dụng King's Favor lên các quân phù hợp
	pass

# --- ROYAL ABILITY ---
func use_ability() -> bool:
	if not is_ability_ready:
		return false
	if not GameManagerSingleton.spend_decree(stats.ability_decree_cost):
		return false
	is_ability_ready = false
	ability_cooldown_remaining = stats.ability_cooldown
	# Thực thi kỹ năng qua script đính kèm
	if stats.ability_script:
		var ability = stats.ability_script.new()
		ability.execute(self)
	ability_used.emit(stats.id)
	return true

# --- CROWN'S BOON ---
func activate_boon() -> void:
	is_boon_active = true
	boon_timer = BOON_DURATION
	boon_activated.emit()
	# TODO: Áp dụng buff lên tất cả quân trên bàn cờ

func _deactivate_boon() -> void:
	is_boon_active = false
	boon_expired.emit()
	# TODO: Gỡ buff khỏi các quân

# --- KING'S FAVOR ---
func get_favor_buff(soldier_stats: SoldierStats) -> Dictionary:
	var buff = { "damage": 0.0, "speed": 0.0, "range": 0.0 }
	if not stats: return buff
	# Kiểm tra xem quân này có thuộc loại được vua buff không
	var soldier_type = SoldierStats.UnitClass.keys()[soldier_stats.unit_class]
	if soldier_type.to_lower() in stats.favored_unit_types:
		buff["damage"] = stats.favor_damage_bonus
		buff["speed"] = stats.favor_speed_bonus
		buff["range"] = stats.favor_range_bonus
	return buff
