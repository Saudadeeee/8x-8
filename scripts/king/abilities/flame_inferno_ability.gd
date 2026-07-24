# res://scripts/king/abilities/flame_inferno_ability.gd
# Flame Queen — "Royal Inferno":
#   Gây 50 sát thương lên toàn bộ địch + Queen x2 damage kèm burn trong 10 giây.
# (Sao chép đúng hành vi hardcoded cũ: KingAbilityExecutor._execute_flame_inferno)
class_name FlameInfernoAbility
extends KingAbility

const INFERNO_DAMAGE: int = 50


func execute(ctx: Dictionary) -> void:
	var executor: KingAbilityExecutor = ctx.get("executor")
	if executor == null:
		push_error("FlameInfernoAbility: thiếu 'executor' trong ctx!")
		return

	for enemy in executor.get_enemies():
		if enemy.has_method("take_damage"):
			enemy.take_damage(INFERNO_DAMAGE)

	for tower in executor.get_towers():
		if not tower.has_method("apply_boon_buff"):
			continue
		if not tower.get("stats") or tower.stats.id != "queen":
			continue
		tower.apply_boon_buff({
			"damage_bonus":           float(tower.stats.base_damage),
			"attack_speed_reduction": 0.0,
		})
		tower.set("boon_burn_override", true)

	executor.schedule_boon_expiry(KingAbilityExecutor.BOON_DURATION)
