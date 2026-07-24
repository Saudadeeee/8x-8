# res://scripts/king/abilities/phantom_veil_ability.gd
# Phantom King — "Shadow Veil":
#   Reset cooldown toàn bộ tháp + làm chậm toàn bộ địch 50% trong 5 giây.
# (Sao chép đúng hành vi hardcoded cũ: KingAbilityExecutor._execute_phantom_veil)
class_name PhantomVeilAbility
extends KingAbility

const SLOW_AMOUNT: float = 0.5
const SLOW_DURATION: float = 5.0


func execute(ctx: Dictionary) -> void:
	var executor: KingAbilityExecutor = ctx.get("executor")
	if executor == null:
		push_error("PhantomVeilAbility: thiếu 'executor' trong ctx!")
		return

	for tower in executor.get_towers():
		if tower.has_method("reset_cooldown"):
			tower.reset_cooldown()

	for enemy in executor.get_enemies():
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(SLOW_AMOUNT, SLOW_DURATION)
