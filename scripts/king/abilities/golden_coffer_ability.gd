# res://scripts/king/abilities/golden_coffer_ability.gd
# Vua Thuong Hoi — "Kim Kho":
#   Nhan vang tuc thi theo wave dang choi + reset gia xao shop ve day.
#
# Day la chieu KINH TE — khong gay mot diem sat thuong nao. Ly do ton tai:
# ba vua goc deu quy doi Sac Lenh thanh sat thuong, nen Sac Lenh chi co mot
# cong dung. Vua nay bien Sac Lenh thanh LUOT XAO, tuc la doi tai nguyen lay
# quyen chon hang — mot truc quyet dinh khac han.
#
# Vang thuong theo wave chu khong phai hang so: hang so thi manh vo doi o
# wave 1 va vo dung o wave 15.
class_name GoldenCofferAbility
extends KingAbility

const GOLD_BASE: int = 60
const GOLD_PER_WAVE: int = 22


func execute(ctx: Dictionary) -> void:
	var gm: Node = ctx.get("game_manager")
	if gm == null:
		push_error("GoldenCofferAbility: thiếu 'game_manager' trong ctx!")
		return

	var wave: int = int(gm.get("current_wave")) if gm.get("current_wave") != null else 1
	var reward: int = GOLD_BASE + GOLD_PER_WAVE * maxi(0, wave - 1)
	if gm.has_method("add_gold"):
		gm.add_gold(reward)

	# Tra gia xao ve day. Gia xao tang +6 moi lan trong cung mot phien, nen o
	# cuoi phien mot luot xao co the ton 40 vang — reset la thu hai cua chieu.
	var tree: SceneTree = ctx.get("tree")
	if tree == null:
		return
	for node in tree.get_nodes_in_group("shop_managers"):
		if is_instance_valid(node) and node.has_method("reset_reroll_cost"):
			node.reset_reroll_cost()
