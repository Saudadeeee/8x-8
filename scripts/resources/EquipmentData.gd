# res://scripts/resources/EquipmentData.gd
#
# MỘT MÓN TRANG BỊ gắn lên tháp — mở được bằng Inspector.
# Lưu vào res://res/equipment/<id>.tres; EquipmentSystem tự quét.
extends Resource
class_name EquipmentData

@export_group("Nhận dạng")
## snake_case, DUY NHẤT, trùng tên icon assets/ui/equipment/<id>.png
@export var id: String = ""
@export var name: String = ""
@export_multiline var desc: String = ""
@export_enum("common", "rare", "epic", "legendary") var rarity: String = "common"
## weapon = vũ khí · accessory = phụ kiện · base = nền tảng.
## Chỉ để phân loại hiển thị; không giới hạn ô lắp.
@export_enum("weapon", "accessory", "base") var slot: String = "weapon"

@export_group("Giá")
## Giá VÀNG trong catalog. Shop quy đổi sang Sắc Lệnh khi bày bán.
@export_range(0, 999, 5) var cost: int = 80

@export_group("Tác dụng")
## Khoá phải nằm trong EquipmentSystem.EFFECT_KEYS và phải có nơi ĐỌC giá trị —
## khai khoá lạ thì món này không làm gì cả.
@export var effect: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "desc": desc, "rarity": rarity,
		"slot": slot, "cost": cost, "effect": effect,
	}
