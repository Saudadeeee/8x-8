# res://scripts/resources/BossStats.gd
# Chỉ số của một Rival King (BOSS). Kế thừa EnemyStats nên mọi hệ thống cũ
# (WaveSpawner._load_enemy_stats, Enemy._build_visual, giáp/regen/aura...) vẫn
# đọc được như một EnemyStats bình thường.
extends EnemyStats
class_name BossStats

@export_group("Boss Identity")
# `display_name` kế thừa từ EnemyStats (mọi loài địch đều có tên hiển thị) —
# KHÔNG khai lại ở đây, Godot cấm trùng tên field giữa lớp con và lớp cha.
## Danh hiệu phụ hiện dưới tên trong banner intro.
@export var title: String = ""
## Màu chủ đạo dùng cho FX (đổi pha, chết, vòng kỹ năng).
@export var accent_color: Color = Color(1.0, 0.45, 0.2)

@export_group("Boss Phases")
## Giáp phẳng theo pha (index 0 = P1 → index 2 = P3). Giảm dần để cuối trận
## đánh nhanh hơn. Thiếu phần tử → dùng phần tử cuối cùng.
@export var phase_armor: Array[int] = [12, 7, 2]
## Mỗi pha vượt qua cộng thêm bao nhiêu % tốc độ so với tốc độ gốc.
@export var phase_speed_bonus: float = 0.12
## Hệ số nhân cooldown kỹ năng theo pha — pha sau đánh dồn dập hơn.
@export var phase_cooldown_scale: Array[float] = [1.0, 0.85, 0.7]

@export_group("Boss Ability")
## Định danh kỹ năng: "summon_beasts" | "lava_breath" | "eternal_frost" | "" (không có).
@export var ability_id: String = ""
## Tên kỹ năng hiển thị khi thi triển.
@export var ability_name: String = ""
## Giây giữa hai lần thi triển (ở pha 1).
@export var ability_cooldown: float = 8.0
## Bán kính tác động, tính bằng mét (1 tile = 1 m).
@export var ability_radius: float = 2.5

@export_subgroup("Summon")
## Danh sách id enemy được triệu hồi (lặp vòng nếu ít hơn summon_count).
@export var summon_ids: Array[String] = []
## Số quái mỗi lần triệu hồi.
@export var summon_count: int = 3

@export_subgroup("Tower Control")
## Số giây tháp bị vô hiệu hoá hoàn toàn (lava_breath).
@export var disable_duration: float = 3.0
## Số giây cooldown cộng thêm cho tháp trong vùng (eternal_frost).
@export var slow_cooldown_add: float = 0.25
## Thời gian hiệu lực của hiệu ứng làm chậm tháp (eternal_frost).
@export var slow_duration: float = 4.0

@export_subgroup("Self Sustain")
## % máu tối đa boss tự hồi mỗi lần thi triển kỹ năng (0.03 = 3%).
@export var self_heal_pct: float = 0.0
