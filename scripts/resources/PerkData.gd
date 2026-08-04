# res://scripts/resources/PerkData.gd
#
# MỘT ĐẶC QUYỀN (perk) — chọn 1 trong 3 sau mỗi wave. Mở được bằng Inspector.
# Lưu vào res://res/perks/<id>.tres; PerkSystem tự quét.
extends Resource
class_name PerkData

@export_group("Identity")
## snake_case, DUY NHẤT, trùng tên icon assets/ui/perks/<id>.png (48×48)
@export var id: String = ""
@export var name: String = ""
@export_multiline var desc: String = ""
## Bậc hiếm QUYẾT ĐỊNH WAVE SỚM NHẤT perk xuất hiện:
## thường 1 · hiếm 3 · sử thi 5 · huyền thoại 8.
## Đặt legendary cho một perk nhỏ thì cả run sẽ không ai thấy nó.
@export_enum("common", "rare", "epic", "legendary") var rarity: String = "common"
## Ký hiệu dự phòng khi chưa vẽ icon PNG. Dùng ký tự hình học, KHÔNG dùng emoji.
@export var icon: String = "◆"
## Cho phép nhặt nhiều lần (hiệu ứng cộng dồn).
@export var stackable: bool = false
## Chỉ hiện khi máu Vua ≥ giá trị này. 0 = không giới hạn.
@export_range(0, 100, 1) var requires_hp: int = 0
## Gắn perk với một loại quân — card sẽ hiện model 3D của quân đó.
@export var unit_id: String = ""

@export_group("Effect channel - fill in AT LEAST one group")
## {damage_bonus: % base, speed_bonus: giây trừ vào hồi chiêu, range_bonus: số ô}
@export var tower: Dictionary = {}
## {gold_per_kill, interest_cap, interest_rate}
@export var economy: Dictionary = {}
## Một lần duy nhất lúc nhặt: {hp_delta, gold_delta}
@export var instant: Dictionary = {}
## {per_wave_start, grant_mult} — Sắc Lệnh
@export var rd: Dictionary = {}
## Perk lối chơi nguyên tố — xem PerkSystem.EFFECT_CHANNELS["element"]
@export var element: Dictionary = {}

func to_dict() -> Dictionary:
	var d := {"id": id, "name": name, "desc": desc, "rarity": rarity, "icon": icon}
	if stackable:            d["stackable"] = true
	if requires_hp > 0:      d["requires_hp"] = requires_hp
	if not unit_id.is_empty(): d["unit_id"] = unit_id
	if not tower.is_empty():   d["tower"] = tower
	if not economy.is_empty(): d["economy"] = economy
	if not instant.is_empty(): d["instant"] = instant
	if not rd.is_empty():      d["rd"] = rd
	if not element.is_empty(): d["element"] = element
	return d
