# res://scripts/map/biome_library.gd
# SCHEMA CHUNG của hệ BIOME đa môi trường — mọi hệ thống khác (GridController render,
# BiomeEffects gameplay, HUD banner) đều đọc dữ liệu từ đây, KHÔNG tự định nghĩa lại.
#
# Mỗi VÙNG mở rộng của bản đồ được gán một biome id → board thành bản đồ chắp vá
# (patchwork): trung tâm là biome khởi đầu, mỗi lần mở rộng thêm một khí hậu khác.
#
# Toàn bộ là static/const — KHÔNG instance, KHÔNG state. Dictionary trả về từ
# get_spec() là READ-ONLY (const Dictionary của Godot 4) → chỉ đọc, không được ghi.
#
# ── KHOÁ BẮT BUỘC của mỗi spec ────────────────────────────────────────────────
#   name / desc          : chuỗi hiển thị (tiếng Việt) cho HUD banner
#   tex_prefix           : tiền tố file texture — xem tex_path()
#   tint_light / _dark / _road / _cliff / _cliff_top
#                        : màu đại diện. Dùng LÀM FALLBACK phẳng khi thiếu texture,
#                          đồng thời làm hệ số nhuộm khi phải mượn texture wasteland cũ.
#   skirt_props          : trọng số CHỌN MỘT (weighted pick) cho vành đất ngoài grid.
#                          Khoá phụ tuỳ chọn: "tall" = true → prop CAO, chỉ được mọc ở
#                          vành xa (dist >= 2) để không chắn camera nhìn vào board.
#   ground_props         : xác suất ĐỘC LẬP theo phần trăm (w/100) cho từng loại prop
#                          trên ô grid — mỗi entry roll riêng, có thể ra nhiều loại.
#                          Khoá phụ tuỳ chọn: "clump" (1-2 cụm), "smin"/"smax" (scale).
#   light_color / light_energy         : DirectionalLight3D
#   ambient_color / ambient_energy     : Environment ambient
#   fog_color / fog_density            : Environment fog
#   bg_color                           : Environment background
#   mod                  : hệ số gameplay cho BiomeEffects (xem MOD_KEYS).
#                          1.0 / 0 = trung tính (không ảnh hưởng).
class_name BiomeLibrary
extends Object

## Biome mặc định — cũng là biome "gốc" mà bộ texture `terrain_*` cũ mô tả.
const DEFAULT_ID: String = "wasteland"

## Thư mục texture địa hình.
const TEX_DIR: String = "res://assets/textures/terrain/"

## Các `kind` texture hợp lệ cho tex_path().
const TEX_KINDS: Array[String] = ["light", "dark", "road", "cliff_side", "cliff_top"]

## Bộ texture CŨ (trước khi có biome) — dùng làm fallback cho wasteland và làm
## "texture mượn" cho các biome chưa có asset riêng.
const LEGACY_TEX: Dictionary = {
	"light":      "terrain_light.png",
	"dark":       "terrain_dark.png",
	"road":       "terrain_road.png",
	"cliff_side": "cliff_side.png",
	"cliff_top":  "cliff_top.png",
}

## kind texture → khoá màu tương ứng trong spec.
const TINT_KEY_BY_KIND: Dictionary = {
	"light":      "tint_light",
	"dark":       "tint_dark",
	"road":       "tint_road",
	"cliff_side": "tint_cliff",
	"cliff_top":  "tint_cliff_top",
}

## Khoá hợp lệ của `mod` + giá trị trung tính. BiomeEffects nên đọc qua đây để
## không bao giờ nhận null khi một biome quên khai báo.
const MOD_KEYS: Dictionary = {
	"enemy_speed_mult": 1.0,
	"enemy_hp_mult":    1.0,
	"tower_dmg_pct":    0.0,
	"tower_spd_delta":  0.0,
	"gold_per_kill":    0,
	"burn_mult":        1.0,
}

# ── BẢNG 5 BIOME ─────────────────────────────────────────────────────────────
const ALL: Dictionary = {
	# Baseline: đúng như bản đồ hiện tại, mod hoàn toàn trung tính.
	"wasteland": {
		"name": "Wasteland", "desc": "Cracked, barren ground. It favours nothing and hinders nothing.",
		"tex_prefix": "wasteland",
		"tint_light": Color("b8a88a"), "tint_dark": Color("4a3f35"), "tint_road": Color("6b5a3e"),
		"tint_cliff": Color("4a3a2c"), "tint_cliff_top": Color("3f4a2e"),
		"skirt_props": [
			{"id": "tree_pine", "w": 40, "tall": true},
			{"id": "tree_dead", "w": 22, "tall": true},
			{"id": "bush",      "w": 15},
			{"id": "stump",     "w": 13},
			{"id": "rock",      "w": 10},
			{"id": "grass_tuft","w":  8},
		],
		"ground_props": [
			{"id": "grass_tuft", "w": 40, "clump": true},
			{"id": "rock",       "w": 14},
			{"id": "bush",       "w":  7, "smin": 0.60, "smax": 0.85},
		],
		"light_color": Color(1, 0.94, 0.82), "light_energy": 1.15,
		"ambient_color": Color(0.8, 0.76, 0.72), "ambient_energy": 0.6,
		"fog_color": Color(0.22, 0.17, 0.13), "fog_density": 0.008,
		"bg_color": Color(0.10, 0.07, 0.086),
		"mod": {"enemy_speed_mult": 1.0, "enemy_hp_mult": 1.0, "tower_dmg_pct": 0.0,
				"tower_spd_delta": 0.0, "gold_per_kill": 0, "burn_mult": 1.0},
	},

	# Băng giá: địch lết chậm, nhưng tháp cũng cóng tay (chu kỳ bắn dài thêm).
	"tundra": {
		"name": "Tundra", "desc": "The cold drags at the enemy's feet - and at your archers' hands.",
		"tex_prefix": "tundra",
		"tint_light": Color("dfe9f2"), "tint_dark": Color("8fa6bd"), "tint_road": Color("9aa8b5"),
		"tint_cliff": Color("5b6b7d"), "tint_cliff_top": Color("cfe0ee"),
		"skirt_props": [
			{"id": "frozen_tree", "w": 34, "tall": true},
			{"id": "ice_spike",   "w": 26, "tall": true},
			{"id": "snow_rock",   "w": 22},
			{"id": "stump",       "w": 12},
			{"id": "rock",        "w":  6},
		],
		"ground_props": [
			{"id": "snow_rock",  "w": 26},
			{"id": "ice_spike",  "w": 12, "smin": 0.45, "smax": 0.70},
			{"id": "grass_tuft", "w":  8, "clump": true, "smin": 0.50, "smax": 0.75},
		],
		"light_color": Color(0.82, 0.90, 1.0), "light_energy": 1.05,
		"ambient_color": Color(0.78, 0.86, 0.96), "ambient_energy": 0.85,
		"fog_color": Color(0.72, 0.80, 0.88), "fog_density": 0.011,
		"bg_color": Color(0.14, 0.18, 0.24),
		"mod": {"enemy_speed_mult": 0.85, "enemy_hp_mult": 1.0, "tower_dmg_pct": 0.0,
				"tower_spd_delta": 0.08, "gold_per_kill": 0, "burn_mult": 1.0},
	},

	# Núi lửa: sát thương và thiêu đốt mạnh hơn, nhưng địch cũng hăng hơn.
	"volcanic": {
		"name": "Volcanic", "desc": "Hot ash feeds the fire: your hits burn brighter, and the enemy fights harder.",
		"tex_prefix": "volcanic",
		"tint_light": Color("6b4038"), "tint_dark": Color("2a1a18"), "tint_road": Color("46281f"),
		"tint_cliff": Color("2c1c18"), "tint_cliff_top": Color("6e2a18"),
		"skirt_props": [
			{"id": "obelisk",        "w": 24, "tall": true},
			{"id": "charred_stump",  "w": 26, "tall": true},
			{"id": "lava_rock",      "w": 30},
			{"id": "rock",           "w": 14},
			{"id": "tree_dead",      "w":  6, "tall": true},
		],
		"ground_props": [
			{"id": "lava_rock",     "w": 30},
			{"id": "rock",          "w": 14},
			{"id": "charred_stump", "w":  6, "smin": 0.50, "smax": 0.75},
		],
		"light_color": Color(1.0, 0.68, 0.48), "light_energy": 1.25,
		"ambient_color": Color(0.72, 0.44, 0.34), "ambient_energy": 0.55,
		"fog_color": Color(0.30, 0.10, 0.07), "fog_density": 0.012,
		"bg_color": Color(0.09, 0.035, 0.03),
		"mod": {"enemy_speed_mult": 1.08, "enemy_hp_mult": 1.0, "tower_dmg_pct": 0.10,
				"tower_spd_delta": 0.0, "gold_per_kill": 0, "burn_mult": 1.5},
	},

	# Đầm lầy: bùn níu địch rất chậm, nhưng ẩm mốc làm vũ khí cùn đi.
	"swamp": {
		"name": "Swamp", "desc": "Mud clings to every step - and steel rusts in the damp.",
		"tex_prefix": "swamp",
		"tint_light": Color("6d7a45"), "tint_dark": Color("32402a"), "tint_road": Color("4a4630"),
		"tint_cliff": Color("2f3a2a"), "tint_cliff_top": Color("465a30"),
		"skirt_props": [
			{"id": "tree_dead", "w": 28, "tall": true},
			{"id": "reed",      "w": 30},
			{"id": "mushroom",  "w": 18},
			{"id": "stump",     "w": 16},
			{"id": "bush",      "w":  8},
		],
		"ground_props": [
			{"id": "reed",     "w": 34, "clump": true},
			{"id": "mushroom", "w": 16, "smin": 0.55, "smax": 0.85},
			{"id": "stump",    "w":  6, "smin": 0.50, "smax": 0.75},
		],
		"light_color": Color(0.78, 0.88, 0.72), "light_energy": 0.95,
		"ambient_color": Color(0.52, 0.62, 0.48), "ambient_energy": 0.70,
		"fog_color": Color(0.16, 0.24, 0.16), "fog_density": 0.013,
		"bg_color": Color(0.06, 0.10, 0.07),
		"mod": {"enemy_speed_mult": 0.80, "enemy_hp_mult": 1.0, "tower_dmg_pct": -0.08,
				"tower_spd_delta": 0.0, "gold_per_kill": 0, "burn_mult": 1.0},
	},

	# Rừng thẳm: chiến lợi phẩm dồi dào, đổi lại quái vật ở đây dai hơn.
	"verdant": {
		"name": "Verdant", "desc": "Rich land: more gold comes in, and the beasts are hardier.",
		"tex_prefix": "verdant",
		"tint_light": Color("8fbf5a"), "tint_dark": Color("3e6b2c"), "tint_road": Color("7a6a3c"),
		"tint_cliff": Color("46402c"), "tint_cliff_top": Color("4f7a2c"),
		"skirt_props": [
			{"id": "jungle_tree", "w": 36, "tall": true},
			{"id": "tree_pine",   "w": 24, "tall": true},
			{"id": "bush",        "w": 18},
			{"id": "mushroom",    "w": 12},
			{"id": "grass_tuft",  "w": 10},
		],
		"ground_props": [
			{"id": "grass_tuft", "w": 52, "clump": true},
			{"id": "bush",       "w": 16, "smin": 0.60, "smax": 0.85},
			{"id": "mushroom",   "w": 10, "smin": 0.55, "smax": 0.80},
		],
		"light_color": Color(0.96, 1.0, 0.86), "light_energy": 1.20,
		"ambient_color": Color(0.72, 0.86, 0.66), "ambient_energy": 0.75,
		"fog_color": Color(0.16, 0.26, 0.15), "fog_density": 0.006,
		"bg_color": Color(0.07, 0.11, 0.08),
		"mod": {"enemy_speed_mult": 1.0, "enemy_hp_mult": 1.08, "tower_dmg_pct": 0.0,
				"tower_spd_delta": 0.0, "gold_per_kill": 1, "burn_mult": 1.0},
	},
}

# ── API ───────────────────────────────────────────────────────────────────────

## Spec của biome. Id lạ/rỗng → fallback về wasteland (không bao giờ trả rỗng).
## LƯU Ý: Dictionary trả về là READ-ONLY — chỉ đọc.
static func get_spec(id: String) -> Dictionary:
	if ALL.has(id):
		return ALL[id]
	if id != "":
		push_warning("BiomeLibrary: biome id không hợp lệ '%s' — dùng '%s'." % [id, DEFAULT_ID])
	return ALL[DEFAULT_ID]

## Danh sách id theo đúng thứ tự khai báo.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for key in ALL.keys():
		out.append(key as String)
	return out

## Id ngẫu nhiên, tránh những id trong `exclude` (thường là biome vùng vừa sinh)
## để hai vùng kề nhau không trùng khí hậu. Hết lựa chọn thì bỏ qua exclude.
static func random_id(exclude: Array = []) -> String:
	var pool: Array[String] = []
	for id in ALL.keys():
		if not exclude.has(id):
			pool.append(id as String)
	if pool.is_empty():
		pool = ids()
	return pool[randi() % pool.size()]

## Đường dẫn texture của (biome, kind). kind ∈ TEX_KINDS.
## Wasteland: nếu file theo prefix chưa tồn tại thì trả về bộ texture CŨ
## (terrain_light/dark/road, cliff_side/cliff_top) để giữ tương thích ngược.
## Caller LUÔN phải guard ResourceLoader.exists() trên kết quả.
static func tex_path(id: String, kind: String) -> String:
	if not TINT_KEY_BY_KIND.has(kind):
		push_warning("BiomeLibrary.tex_path: kind không hợp lệ '%s'." % kind)
		return ""
	var spec: Dictionary = get_spec(id)
	var prefix: String = str(spec.get("tex_prefix", DEFAULT_ID))
	var path: String = "%s%s_%s.png" % [TEX_DIR, prefix, kind]
	if prefix == DEFAULT_ID and not ResourceLoader.exists(path):
		return TEX_DIR + str(LEGACY_TEX.get(kind, ""))
	return path

## Màu đại diện của (biome, kind) — dùng làm fallback phẳng hoặc hệ số nhuộm.
static func tint_of(id: String, kind: String) -> Color:
	var key: String = str(TINT_KEY_BY_KIND.get(kind, "tint_light"))
	return get_spec(id).get(key, Color.WHITE)

## Giá trị `mod` của biome, đã điền đủ mọi khoá trong MOD_KEYS.
## Trả về Dictionary MỚI (ghi được) — an toàn cho BiomeEffects dùng tự do.
static func mod_of(id: String) -> Dictionary:
	var raw: Dictionary = get_spec(id).get("mod", {})
	var out: Dictionary = {}
	for key in MOD_KEYS.keys():
		out[key] = raw.get(key, MOD_KEYS[key])
	return out
