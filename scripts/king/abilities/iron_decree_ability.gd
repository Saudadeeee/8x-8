# res://scripts/king/abilities/iron_decree_ability.gd
# Iron King — "Iron Decree":
#   +30 Royal Decree ngay lập tức + toàn bộ Pawn +50% tốc độ tấn công trong 8 giây.
# (Sao chép đúng hành vi hardcoded cũ: KingAbilityExecutor._execute_iron_decree)
class_name IronDecreeAbility
extends KingAbility

const DECREE_GRANT: float = 30.0
const PAWN_SPEED_RATIO: float = 0.5
const BUFF_DURATION: float = 8.0


func execute(ctx: Dictionary) -> void:
	var executor: KingAbilityExecutor = ctx.get("executor")
	if executor == null:
		push_error("IronDecreeAbility: thiếu 'executor' trong ctx!")
		return

	var km: KingManager = ctx.get("king_manager")
	if km:
		km.add_royal_decree(DECREE_GRANT)

	for tower in executor.get_towers():
		if not tower.has_method("apply_boon_buff"):
			continue
		if not tower.get("stats") or tower.stats.id != "pawn":
			continue
		tower.apply_boon_buff({
			"damage_bonus":           0.0,
			"attack_speed_reduction": tower.stats.attack_speed * PAWN_SPEED_RATIO,
		})

	executor.schedule_boon_expiry(BUFF_DURATION)
