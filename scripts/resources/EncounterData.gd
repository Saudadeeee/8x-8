# res://scripts/resources/EncounterData.gd
# Dữ liệu cho các sự kiện ngẫu nhiên giữa các wave (Random Encounter).
extends Resource
class_name EncounterData

enum EncounterType { REWARD, RISK, MIXED, SHOP_SPECIAL, STORY }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

# --- NHẬN DIỆN ---
@export_group("Identity")
@export var id: String = "encounter_default"
@export var title: String = "Tên Sự Kiện"
@export_multiline var flavor_text: String = "Mô tả sự kiện, tạo không khí..."
@export var encounter_icon: Texture2D
@export var encounter_type: EncounterType = EncounterType.MIXED
@export var rarity: Rarity = Rarity.COMMON

# --- CÁC LỰA CHỌN ---
# Mỗi sự kiện có từ 2-3 lựa chọn, mỗi lựa chọn có hậu quả khác nhau
@export_group("Choices")
@export var choices: Array[Resource] = []   # Array của EncounterChoice resources

# --- ĐIỀU KIỆN XUẤT HIỆN ---
@export_group("Spawn Conditions")
@export var min_wave: int = 1               # Xuất hiện từ wave nào trở đi
@export var required_king_id: String = ""   # Nếu rỗng = xuất hiện với mọi vua
@export var weight: float = 1.0            # Trọng số xuất hiện (càng cao càng dễ ra)
