# res://scripts/managers/feature_flags.gd
#
# CỜ BẬT/TẮT HỆ THỐNG — công cụ để CẮT mà không xoá.
#
# Bản này chuyển sang mô hình Balatro: một công thức `Nền × Bội`, bàn 8×8 chật,
# nước đi quân cờ. Bài kiểm duy nhất cho mọi hệ thống là:
#
#     "Nó có vào được công thức Nền × Bội không?"
#
# Hệ nào không vào được thì tắt ở đây. KHÔNG XOÁ CODE: mỗi hệ đều tốn hàng tuần
# để viết và đều còn test phủ; xoá xong mới nhận ra mình cần lại thì đắt gấp
# nhiều lần. Tắt cờ, chơi 5 ván, rồi mới quyết định xoá thật.
#
# Toàn static — đọc được từ mọi nơi, không cần autoload mới.
class_name FeatureFlags
extends Object

# ── TẮT: không vào được công thức ───────────────────────────────────────────

## 4 mùa áp buff/debuff toàn cục theo wave.
## Tắt vì: trùng vai với khí hậu biome, và nó sửa chỉ số tháp bằng một hệ số
## VÔ HÌNH không xuất hiện ở đâu trong bảng Nền × Bội — người chơi thấy con số
## nhảy mà không biết vì sao.
const SEASONS_ENABLED: bool = false

## Khí hậu biome (enemy_speed_mult, tower_dmg_pct… theo vùng).
## Tắt vì: cùng lý do trên. Biome GIỮ LẠI phần hình ảnh — bàn cờ vẫn đổi cảnh,
## chỉ không còn sửa chỉ số ngầm.
const BIOME_CLIMATE_ENABLED: bool = false

## Synergy theo LOẠI QUÂN (2/4/6 cùng loại → buff).
## Tắt vì: thế cờ (ChessFormations) đã là trục "xếp quân cho đúng", và nó nhìn
## là thấy. Hai trục cùng thưởng cho việc xếp quân thì trục nào cũng mờ đi.
const UNIT_SYNERGY_ENABLED: bool = false

## Ô Phước / Ô Nguyền sinh ngẫu nhiên lúc tạo bản đồ.
## Tắt vì: ±20% phẳng, không tương tác với nước đi, không tương tác với thế cờ.
const SPECIAL_TILES_ENABLED: bool = false

## Chí mạng ngẫu nhiên.
## Tắt vì: Balatro không có tính ngẫu nhiên trong lúc chấm điểm — bạn tính ra
## đúng con số bạn sẽ ăn. Crit làm "sát thương lên một địch" thành số kỳ vọng
## mờ ảo, phá đúng thứ quý nhất của bảng ngưỡng.
const CRIT_ENABLED: bool = false

## Combo hạ gục liên tiếp → nhân vàng.
## Tắt vì: thưởng cho tốc độ giết, không thưởng cho bố cục. Nhiễu số.
const KILL_COMBO_ENABLED: bool = false

## Mở rộng bản đồ 4 hướng.
## Tắt vì: ô bàn cờ là tài nguyên khan hiếm TRUNG TÂM của thiết kế mới.
## (Cờ thật nằm ở `game_map.EXPAND_EVERY_N_WAVES = 0`; hằng này để tra cứu.)
const MAP_EXPANSION_ENABLED: bool = false


# ── GIỮ: vào được công thức ─────────────────────────────────────────────────

## Ô nguyên tố → NỀN (sát thương) và một phần BỘI (reaction_mult). Giữ.
const ELEMENT_TILES_ENABLED: bool = true
## Phản ứng nguyên tố → nguồn BỘI thứ hai. Giữ.
const REACTIONS_ENABLED: bool = true
## Di vật → đúng vai Joker của Balatro. Giữ.
const RELICS_ENABLED: bool = true
## Perk draft → đúng vai Tag. Giữ.
const PERKS_ENABLED: bool = true


## Bảng tra cho công cụ kiểm và cho sách tra cứu trong game.
const ALL := {
	"seasons": SEASONS_ENABLED,
	"biome_climate": BIOME_CLIMATE_ENABLED,
	"unit_synergy": UNIT_SYNERGY_ENABLED,
	"special_tiles": SPECIAL_TILES_ENABLED,
	"crit": CRIT_ENABLED,
	"kill_combo": KILL_COMBO_ENABLED,
	"map_expansion": MAP_EXPANSION_ENABLED,
	"element_tiles": ELEMENT_TILES_ENABLED,
	"reactions": REACTIONS_ENABLED,
	"relics": RELICS_ENABLED,
	"perks": PERKS_ENABLED,
}


static func enabled(key: String) -> bool:
	return bool(ALL.get(key, true))
