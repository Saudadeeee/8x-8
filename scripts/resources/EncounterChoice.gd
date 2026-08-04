# res://scripts/resources/EncounterChoice.gd
# Một lựa chọn trong sự kiện Random Encounter.
extends Resource
class_name EncounterChoice

# --- NỘI DUNG ---
@export var choice_text: String = "Choice..."
@export_multiline var outcome_preview: String = "Possible outcome..." # Hint cho người chơi

# --- HẬU QUẢ ---
@export_group("Outcomes")
@export var gold_delta: int = 0             # +/- vàng
@export var health_delta: int = 0          # +/- máu căn cứ
@export var decree_delta: float = 0.0      # +/- Decree tối đa
@export var add_soldier: Resource = null   # Thêm 1 quân vào army (SoldierStats)
@export var remove_soldier_tag: String = ""# Xóa 1 quân có tag này khỏi army
@export var add_territory: Resource = null # Thêm 1 lãnh thổ

# --- Ô NGUYÊN TỐ (futureplan §2.4: "Encounter — đổi HP/vàng lấy ô cấp cao") ---
## Số ô nguyên tố được tặng. Đặt chồng lên nhau để nâng cấp: 2 ô = Lv2, 3 ô = Lv3.
@export var element_tiles: int = 0
## Nguyên tố của số ô trên. Ba giá trị đặc biệt:
##   "dominant" — nguyên tố người chơi đang đầu tư nhiều nhất (phần thưởng đi SÂU)
##   "random"   — nguyên tố ngẫu nhiên (phần thưởng đi RỘNG)
##   "fire"/"ice"/… — chỉ đích danh
@export var element_tile_kind: String = "dominant"
@export var trigger_script: Script        # Logic phức tạp hơn dùng script
