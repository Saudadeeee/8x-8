# res://scripts/enemies/enemy_stats.gd
extends Resource
class_name EnemyStats

@export_group("Identity")
@export var id: String = ""
## Tên hiển thị trong popup trinh sát / codex. Để rỗng thì lấy id viết hoa.
@export var display_name: String = ""
## Một dòng mô tả năng lực, hiện ở popup trinh sát. Để rỗng thì tra ABILITY_NOTES
## theo id (các loài cũ nằm trong bảng đó), không có nữa thì hiện "—".
@export var ability_note: String = ""

# ── LỊCH SPAWN (thêm địch mới KHÔNG phải sửa code) ────────────────────────────
# Để RỖNG = loài này do bảng mùa cứng trong wave_spawner quyết định (mọi loài có
# sẵn đều vậy, nên file .tres cũ không phải sửa gì).
# Điền vào = wave_spawner tự chèn loài này vào pool của các mùa được liệt kê.
# Nhờ vậy thêm một loài địch mới chỉ cần MỘT file .tres.
@export_group("Spawn")
## Mùa loài này xuất hiện. 0 = Xuân · 1 = Hạ · 2 = Thu · 3 = Đông.
@export var spawn_seasons: Array[int] = []
## Số bản sao thả vào pool mỗi mùa — càng lớn càng hay gặp.
@export var spawn_weight: int = 1

@export_group("Visuals")
@export var texture: Texture2D
@export var scale: Vector2 = Vector2(1, 1)

@export_group("Attributes")
@export var max_hp: int = 100
@export var speed: float = 40.0
@export var damage_to_base: int = 1
@export var gold_reward: int = 10

@export_group("Abilities")
## Giáp phẳng: mỗi đòn đánh bị trừ đi [armor] sát thương (tối thiểu còn 1).
@export var armor: int = 0
## Hồi máu mỗi giây (0 = không hồi). Không vượt quá max HP đã scale theo wave.
@export var regen_per_sec: float = 0.0
## Lượng máu hồi cho đồng minh xung quanh mỗi nhịp aura (0 = không có aura).
@export var heal_aura_amount: int = 0
## Bán kính aura hồi máu, tính bằng mét (1 tile = 1 m). 0 = không có aura.
@export var heal_aura_radius: float = 0.0

# ── ÁI LỰC NGUYÊN TỐ (futureplan §6.1) ────────────────────────────────────
# "Mỗi lối chơi khắc chế ít nhất 2 loại địch" — không có bảng này thì mọi
# nguyên tố tương đương nhau và việc chọn hệ chỉ còn là thẩm mỹ.
#
# Để RỖNG thì lấy mặc định theo `id` ở DEFAULT_AFFINITY bên dưới. Nhờ vậy các
# file .tres cũ không phải sửa gì, mà người viết nội dung vẫn ghi đè được.
@export_group("Element Affinity")
## Nguyên tố khắc chế con này — Dấu và phản ứng của nó mạnh hơn WEAK_MULT lần.
@export var weak_element: String = ""
## Nguyên tố khắc chế PHỤ. Có để mọi hệ đều khắc được ít nhất 2 loài (§6.1):
## 10 loài / 6 hệ không chia đều được nếu mỗi loài chỉ có một điểm yếu.
@export var weak_element_2: String = ""
## Nguyên tố bị con này kháng — yếu đi RESIST_MULT lần.
@export var resist_element: String = ""

const WEAK_MULT: float = 1.5
const RESIST_MULT: float = 0.6

## Bảng mặc định theo id. Mỗi nguyên tố khắc ĐÚNG 2-3 loài, và mỗi loài đều có
## một đường ra — không loài nào miễn nhiễm hoàn toàn với mọi hệ.
## Hàng: [khắc chính, kháng, (khắc phụ — tuỳ chọn)].
## Phân bố được cân để MỖI nguyên tố khắc chế ít nhất 2 loài: 10 loài / 6 hệ không
## chia đều nổi nếu mỗi loài chỉ có một điểm yếu, nên ba loài "cứng" có hai.
## Ghi chú năng lực hiện trong popup trinh sát wave và trong codex.
## Ở ĐÂY cùng chỗ với DEFAULT_AFFINITY: thêm một loài địch mới thì mọi
## thứ UI cần biết về nó nằm trong CÙNG một file.
const ABILITY_NOTES := {
	"orc":        "Đòn đánh mạnh",
	"goblin":     "Di chuyển rất nhanh",
	"skeleton":   "Kháng chậm, Undead",
	"dark_knight":"Máu cao, khó hạ",
	"demon_imp":  "Tốc độ cao, thiêu đốt",
	"troll":      "Hồi 8 HP/giây — dồn hỏa lực",
	"wraith":     "Cực nhanh, máu giấy",
	"shaman":     "Hồi máu địch xung quanh — hạ trước",
	"golem":      "Giáp 6: đòn nhẹ gần như vô dụng",
	"bat":        "Bầy đàn yếu, bay nhanh",
}

const DEFAULT_AFFINITY: Dictionary = {
	# id            khắc         kháng      khắc phụ
	"orc":         ["fire",     "earth"],
	"goblin":      ["fire",     "poison"],
	"skeleton":    ["earth",    "poison"],            # xương: đập vỡ được, độc vô dụng
	"dark_knight": ["thunder",  "ice",     "water"],  # giáp dày: sét xuyên, nước làm gỉ
	"demon_imp":   ["water",    "fire"],              # quỷ lửa
	"troll":       ["poison",   "earth",   "ice"],    # hồi máu: độc chặn hồi, lạnh làm chậm hồi
	"wraith":      ["ice",      "earth"],             # phi vật thể: đá không chạm tới
	"shaman":      ["poison",   "water"],
	"golem":       ["thunder",  "fire",    "earth"],  # đá: sét xuyên giáp, đá phá đá
	"bat":         ["thunder",  "poison"],            # bầy đàn: sét lan
}

## Hệ số sát thương nguyên tố `element` gây lên loài này.
## 1.0 = bình thường · 1.5 = bị khắc · 0.6 = kháng.
func element_multiplier(element: String) -> float:
	if element.is_empty():
		return 1.0
	var weak := weak_element
	var resist := resist_element
	if weak.is_empty() and resist.is_empty():
		var row: Variant = DEFAULT_AFFINITY.get(id)
		if row is Array and (row as Array).size() >= 2:
			weak = str(row[0])
			resist = str(row[1])
	if element == weak or element == _weak_2():
		return WEAK_MULT
	if element == resist:
		return RESIST_MULT
	return 1.0

func _weak_2() -> String:
	if not weak_element_2.is_empty():
		return weak_element_2
	var row: Variant = DEFAULT_AFFINITY.get(id)
	return str(row[2]) if (row is Array and (row as Array).size() >= 3) else ""

## Mọi nguyên tố khắc chế loài này (1 hoặc 2 phần tử).
func weaknesses() -> Array[String]:
	var out: Array[String] = []
	var first := weakness()
	if not first.is_empty():
		out.append(first)
	var second := _weak_2()
	if not second.is_empty() and second != first:
		out.append(second)
	return out

## Nguyên tố khắc chế loài này (đã tính cả bảng mặc định). "" nếu không có.
func weakness() -> String:
	if not weak_element.is_empty():
		return weak_element
	var row: Variant = DEFAULT_AFFINITY.get(id)
	return str(row[0]) if (row is Array and (row as Array).size() >= 1) else ""

## Nguyên tố loài này kháng. "" nếu không có.
func resistance() -> String:
	if not resist_element.is_empty():
		return resist_element
	var row: Variant = DEFAULT_AFFINITY.get(id)
	return str(row[1]) if (row is Array and (row as Array).size() >= 2) else ""
