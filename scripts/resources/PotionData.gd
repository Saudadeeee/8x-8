# res://scripts/resources/PotionData.gd
#
# MỘT BÌNH THUỐC — mở được bằng Inspector, không cần chạm code hay JSON.
#
# Tạo mới: chuột phải trong FileSystem → New Resource → PotionData, lưu vào
# res://res/potions/<id>.tres. PotionSystem tự quét thư mục đó.
extends Resource
class_name PotionData

@export_group("Identity")
## snake_case, DUY NHẤT, và trùng tên file icon assets/ui/potions/<id>.png
@export var id: String = ""
@export var name: String = ""
@export_multiline var desc: String = ""
## common · rare · epic · legendary — quyết định độ hiếm khi rơi ra
@export_enum("common", "rare", "epic", "legendary") var rarity: String = "common"

@export_group("Throw area")
## "allies" = buff tháp trong vùng · "enemies" = đánh địch trong vùng ·
## "self" = tác dụng thẳng lên Vua, không cần ngắm
@export_enum("allies", "enemies", "self") var target: String = "allies"
## Bán kính vùng, tính bằng ô (1 ô = 1 m)
@export_range(0.5, 8.0, 0.5) var radius: float = 2.5
## Thời gian hiệu lực (giây). 0 = tác dụng tức thì.
@export_range(0.0, 60.0, 0.5) var duration: float = 12.0

@export_group("Effect - fill in AT LEAST one group")
## Buff cho tháp trong vùng. VD {"damage_pct": 0.4} hoặc {"speed_bonus": 0.35}
@export var buff: Dictionary = {}
## Đánh/gắn Dấu lên địch trong vùng. VD {"damage": 120} hoặc {"element": "fire"}
@export var strike: Dictionary = {}
## TÊN hiệu ứng đặc biệt do code xử lý riêng (là CHUỖI, không phải dict).
## Hiện có: "heal_king" · "king_shield" · "time_sand".
## Thêm tên mới thì phải thêm nhánh xử lý trong potion_system.
@export var special: String = ""

## Đổi sang dict để các hệ cũ dùng nguyên si — tránh phải sửa toàn bộ nơi đọc.
func to_dict() -> Dictionary:
	var d := {
		"id": id, "name": name, "desc": desc, "rarity": rarity,
		"target": target, "radius": radius, "duration": duration,
	}
	if not buff.is_empty():    d["buff"] = buff
	if not strike.is_empty():  d["strike"] = strike
	if not special.is_empty(): d["special"] = special
	return d
