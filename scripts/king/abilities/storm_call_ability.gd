# res://scripts/king/abilities/storm_call_ability.gd
# Vua Bao To — "Thien Loi Tran":
#   Gan Dau LOI len TOAN BO dich + gay sat thuong nho.
#
# Vi sao gan Dau chu khong phai chi gay sat thuong: he nguyen to la co che
# chu dao cua game, ma ba vua goc khong ai cham vao no. Vua nay bien mot lan
# bam nut thanh mot loat phan ung day chuyen — dat tren o Hoa thi ra Qua Tai,
# tren o Thuy thi ra Dan Dien. Gia tri cua chieu phu thuoc vao bo cuc o nguyen
# to nguoi choi da dung, dung voi tinh than "nguyen to den tu O".
class_name StormCallAbility
extends KingAbility

const SHOCK_DAMAGE: int = 24
## Dau keo dai hon binh thuong — day la chieu cuoi cua ca mot vua, phai du
## thoi gian de thap kip kich phan ung.
const MARK_DURATION_BONUS: float = 3.0


func execute(ctx: Dictionary) -> void:
	var executor: KingAbilityExecutor = ctx.get("executor")
	if executor == null:
		push_error("StormCallAbility: thiếu 'executor' trong ctx!")
		return

	for enemy in executor.get_enemies():
		if enemy.has_method("take_damage"):
			enemy.take_damage(SHOCK_DAMAGE)
		if enemy.has_method("apply_element"):
			enemy.apply_element("thunder", null, 1.0, MARK_DURATION_BONUS)
