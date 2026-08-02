# res://scripts/king/abilities/glacier_halt_ability.gd
# Vua Bang Ha — "Vinh Dong":
#   Lam cham NANG toan bo dich + gan Dau BANG len tat ca.
#
# Day la chieu PHONG THU, khac han ba vua goc (deu la chieu sat thuong hoac
# buff tan cong). Cong dung: cuu mot wave sap tran, hoac dong bang mot dam
# dich ngay tren o Hoa de an mot loat Tan Chay.
#
# Khong dung "dong bang cung" (stun) vi ReactionTable da co Dong Bang rieng va
# no co cooldown an; chong hai nguon dong bang len nhau se lam luat kho doan.
# Lam cham 80% da du cam giac "ca chien truong dung hinh".
class_name GlacierHaltAbility
extends KingAbility

const SLOW_AMOUNT: float = 0.80
const SLOW_DURATION: float = 6.0
const MARK_DURATION_BONUS: float = 2.5


func execute(ctx: Dictionary) -> void:
	var executor: KingAbilityExecutor = ctx.get("executor")
	if executor == null:
		push_error("GlacierHaltAbility: thiếu 'executor' trong ctx!")
		return

	for enemy in executor.get_enemies():
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(SLOW_AMOUNT, SLOW_DURATION)
		if enemy.has_method("apply_element"):
			enemy.apply_element("ice", null, 1.0, MARK_DURATION_BONUS)
