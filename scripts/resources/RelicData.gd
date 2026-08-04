# res://scripts/resources/RelicData.gd
#
# MỘT DI VẬT — hiệu lực CẢ RUN, tối đa 5 ô. Mở được bằng Inspector.
# Lưu vào res://res/relics/<id>.tres; RelicSystem tự quét.
extends Resource
class_name RelicData

@export_group("Identity")
## snake_case, DUY NHẤT, trùng tên icon assets/ui/relics/<id>.png
@export var id: String = ""
@export var name: String = ""
@export_multiline var desc: String = ""
@export_enum("common", "rare", "epic", "legendary") var rarity: String = "epic"

@export_group("Cost")
@export_range(0, 999, 10) var cost: int = 200

@export_group("Effect")
## RelicSystem._apply_all() tính lại từ đầu mỗi lần đổi, rồi GHI ĐÈ vào
## GameManager. Nghĩa là bán một món là giá trị tự về mặc định.
@export var effect: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "desc": desc,
		"rarity": rarity, "cost": cost, "effect": effect,
	}
