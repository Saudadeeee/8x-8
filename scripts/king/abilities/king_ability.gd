# res://scripts/king/abilities/king_ability.gd
# Lớp cơ sở cho Royal Ability (data-driven).
# KingStats.ability_script trỏ tới một script con của class này —
# KingAbilityExecutor sẽ instantiate và gọi execute(ctx) khi vua dùng kỹ năng.
#
# ctx (Dictionary) do KingAbilityExecutor.build_context() cung cấp:
#   "tree"         : SceneTree           — truy cập trực tiếp node groups nếu cần
#   "executor"     : KingAbilityExecutor — helper: get_towers() / get_enemies() / schedule_boon_expiry()
#   "king_manager" : KingManager         — Royal Decree, favor
#   "game_manager" : GameManager         — state, selected_king, gold/hp
class_name KingAbility
extends RefCounted


## Override ở script con — thực thi hiệu ứng kỹ năng của vua.
func execute(_ctx: Dictionary) -> void:
	push_warning("KingAbility.execute() chưa được override!")
