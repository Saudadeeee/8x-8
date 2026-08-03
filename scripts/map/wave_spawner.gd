# res://scripts/map/wave_spawner.gd
# Quản lý spawn enemy, mùa (Season), và thống kê wave.
# Được game_map.gd khởi tạo và làm con node.
extends Node
class_name WaveSpawner

# --- SIGNALS ---
signal enemy_reached_base(damage: int)
signal enemy_defeated(gold: int)
signal wave_cleared
## Rival King vừa ra sân — game_map nối HUD (thanh máu boss / banner intro).
signal boss_spawned(boss: Node)
## Rival King chạm tới King của người chơi → thua ngay (game_map xử lý).
signal boss_escaped

# --- CONSTANTS ---
# Wave DONG HON de bu cho viec dich di cham (do thuc te: giam toc do 45% lam
# HP nguoi choi LEO tu 19 len 34 giua van vi thap co nhieu thoi gian ban hon).
# Game TD nhip cham bu bang SO LUONG chu khong bang toc do — Bloons cung vay.
## Quy mô wave đã hạ theo BÀN 8×8 + TRẦN QUÂN. Bảng cũ (14 +3/wave, 20 wave,
## 850 địch) được cân cho bàn nở tới 24×24 và số tháp không giới hạn — đo được
## 106 tháp ở wave 14. Với 8-20 quân trên 64 ô thì cùng số địch đó là bất khả.
## 10 chứ không 8: đo được bot đạt tỉ lệ 1.3-3.2 ở bốn wave đầu — không có sức
## ép thì bốn wave đầu chỉ là thủ tục bấm nút.
const ENEMIES_PER_WAVE: int = 10
const ENEMIES_PER_WAVE_INCREMENT: int = 2
## Máu địch tăng theo CẤP SỐ NHÂN, không phải cộng tuyến tính.
## Lý do: sức mạnh người chơi vốn nhân dồn (★ ×3.2 · synergy +30% · perk · cấp ô
## · trang bị), nên +12% tuyến tính mỗi wave bị bỏ xa — đo thực tế cho thấy máu
## Vua đứng yên từ wave 6 trở đi, hết hoàn toàn áp lực.
## 1.15^(w-1): wave 5 ×1.75 · wave 10 ×3.52 · wave 12 ×4.65.
## 1.13 chứ không 1.18: ván chỉ còn 12 wave, mà 1.18^11 = ×6.2 là vách đá.
const ENEMY_HEALTH_GROWTH: float = 1.13
## Giữ lại hằng cũ cho tương thích (không còn dùng trong công thức máu).
const ENEMY_HEALTH_SCALE_PER_WAVE: float = 0.12
const ENEMY_SPEED_SCALE_PER_WAVE: float = 0.03
const SHOP_EXTRA_ENEMY_COUNT: int = 3
const SHOP_EXTRA_HEALTH_MULTIPLIER: float = 0.25
const SHOP_EXTRA_SPEED_MULTIPLIER: float = 0.08
# Nhip spawn GIAN RA cho hop tiet tau cham (tham chieu Bloons TD: dich phai
# den thanh DONG DOC DUOC, khong phai mot cuc do vao mot luc). 0.8s khien ca
# wave don lai thanh mot dam; 1.5s cho nguoi choi kip nhin tung con.
const SPAWN_INTERVAL: float = 1.5

# Elite: từ wave 3, mỗi enemy spawn có 10% cơ hội thành elite (HP ×3, vàng ×2.5)
const ELITE_MIN_WAVE: int = 3
const ELITE_CHANCE: float = 0.10

# --- BOSS (Rival King) ---
## Các wave có BOSS. Mở rộng bằng cách thêm số wave vào mảng này.
# BA wave boss — GDD hứa "đánh bại TẤT CẢ Rival King", trước đây chỉ có một.
# Khoảng cách 6-7 wave để người chơi kịp dựng lại đội hình giữa hai lần.
## Ván ngắn lại còn 12 wave (~15 phút). Roguelike cần THUA NHANH để học nhanh;
## 20 wave × 850 địch là 40 phút mới biết ván hỏng.
const BOSS_WAVES: Array[int] = [5, 9, 12]
## Wave boss thay đàn quái thường bằng một nhóm hộ vệ nhỏ.
const BOSS_WAVE_MINION_COUNT: int = 6
## Ba Rival King — chọn ngẫu nhiên một cho mỗi wave boss.
const BOSS_IDS: Array[String] = ["boss_wild", "boss_hell", "boss_frost"]

## Độ dài ván — mirror `PhaseController.MAX_WAVES`. Spawner không giữ tham chiếu
## tới phase controller nên đọc hằng ở đây; đổi một chỗ phải đổi cả hai.
const MAX_WAVES_HINT: int = 12

## Tỉ lệ địch mùa TRƯỚC còn sót lại trong pool mùa hiện tại — làm mềm bậc thang
## ở mỗi lần chuyển mùa. 0 = chuyển đột ngột như bản cũ.
const SEASON_BLEND: float = 0.55
const BOSS_STATS_PATH: String = "res://res/enemy/%s.tres"
const BOSS_SCENE_PATH: String = "res://scenes/enemy/boss.tscn"
## Mỗi cấp Ascension (nếu GameManager có) cộng thêm % máu cho boss.
const ASCENSION_HP_PER_LEVEL: float = 0.35
## Tên field Ascension được dò trên GameManagerSingleton (theo thứ tự ưu tiên).
const ASCENSION_FIELDS: Array[String] = ["ascension_level", "ascension", "ascension_tier"]

const _ENEMY_DISPLAY_NAMES := {
	"orc": "Orc", "goblin": "Goblin", "skeleton": "Xương Cốt",
	"dark_knight": "Kỵ Sĩ Đen", "demon_imp": "Quỷ Con",
	"troll": "Troll", "wraith": "Oán Hồn", "shaman": "Pháp Sư Tà Thuật",
	"golem": "Golem Đá", "bat": "Dơi Quỷ",
}

const SEASON_BUFFS := {
	# `desc` chỉ còn mô tả LOÀI ĐỊCH của mùa, không hứa buff chỉ số nữa —
	# `get_season_buff` trả rỗng khi FeatureFlags.SEASONS_ENABLED = false.
	0: {"name": "Mùa Xuân", "damage_mult": 1.0,  "speed_penalty": 0.0,  "desc": "Địch nhẹ, nhanh: Dơi Quỷ và Goblin."},
	1: {"name": "Mùa Hè",   "damage_mult": 1.15, "speed_penalty": 0.0,  "desc": "Orc và Skeleton — đông và đều."},
	2: {"name": "Mùa Thu",  "damage_mult": 1.0,  "speed_penalty": 0.15, "desc": "Dark Knight và Demon Imp — dày máu hơn."},
	3: {"name": "Mùa Đông", "damage_mult": 0.9,  "speed_penalty": 0.2,  "desc": "Loài cứng nhất: Troll, Golem, Dark Knight."},
}

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

# --- REFS (set bởi game_map sau khi add_child) ---
var _parent_node: Node = null  # game_map — dùng để add_child enemy

# --- STATE ---
var current_path_grid: Array[Vector2i] = []
var enemies_alive: int = 0
var enemies_spawned: int = 0
var _enemies_to_spawn: int = 0
var _wave_number: int = 1
var _active_shop_boost: bool = false

## Boss của wave hiện tại đã bị HẠ chưa (điều kiện thắng của wave cuối).
var boss_defeated_this_wave: bool = false
## Boss đã chạm King và biến mất (không bị hạ) — vẫn phải cho wave kết thúc,
## nếu không wave sẽ treo vĩnh viễn.
var boss_escaped_this_wave: bool = false
## Boss đang sống trên sân (null nếu chưa spawn / đã rời sân).
var current_boss: Node = null
var _is_boss_wave: bool = false

var _enemy_stats: Dictionary = {}
var _wave_spawn_timer: Timer = null
var _enemy_scene = preload("res://scenes/enemy/enemy.tscn")
## Nạp LƯỜI: preload() sẽ làm hỏng cả script nếu boss.tscn chưa được import,
## kéo theo toàn bộ hệ spawn. load() lúc cần thì chỉ mất wave boss.
var _boss_scene: PackedScene = null

# --- KHỞI TẠO ---
func _ready() -> void:
	_wave_spawn_timer = Timer.new()
	_wave_spawn_timer.wait_time = SPAWN_INTERVAL
	_wave_spawn_timer.one_shot = false
	_wave_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_wave_spawn_timer)
	_load_enemy_stats()

func setup(path: Array[Vector2i], parent: Node) -> void:
	current_path_grid = path
	_parent_node = parent

# --- ĐIỀU KHIỂN WAVE ---
func start_wave(wave_num: int, enemy_count: int, shop_boost: bool) -> void:
	_wave_number = wave_num
	_active_shop_boost = shop_boost
	enemies_spawned = 0
	enemies_alive = 0

	# Reset state boss cho wave mới
	_is_boss_wave           = is_boss_wave(wave_num)
	boss_defeated_this_wave = false
	boss_escaped_this_wave  = false
	current_boss            = null

	# Wave boss: 1 Rival King + một nhóm hộ vệ nhỏ thay cho cả đàn quái
	_enemies_to_spawn = BOSS_WAVE_MINION_COUNT if _is_boss_wave else enemy_count
	_wave_spawn_timer.start()
	if _is_boss_wave:
		_spawn_boss()

func stop() -> void:
	_wave_spawn_timer.stop()

func get_enemies_to_spawn() -> int:
	return _enemies_to_spawn

# --- SEASON ---
## Mốc mùa chia theo TỈ LỆ độ dài ván, không phải số wave cứng.
##
## Bảng cũ (≤2 / ≤5 / ≤8 / còn lại) được viết cho ván 20 wave. Với ván 12 wave
## thì Mùa Thu ập tới ngay wave 6 và ngưỡng nhảy 1507 → 4454 trong một bước —
## đo được, và nó cao hơn cả wave boss ngay trước đó.
func get_season(wave_num: int) -> Season:
	var total: float = float(maxi(4, MAX_WAVES_HINT))
	var t: float = float(maxi(1, wave_num)) / total
	if t <= 0.25:   return Season.SPRING
	elif t <= 0.50: return Season.SUMMER
	elif t <= 0.78: return Season.AUTUMN
	else:           return Season.WINTER

func get_season_name(wave_num: int) -> String:
	match get_season(wave_num):
		Season.SPRING: return "Mùa Xuân (Wild)"
		Season.SUMMER: return "Mùa Hè (Mixed)"
		Season.AUTUMN: return "Mùa Thu (Undead)"
		Season.WINTER: return "Mùa Đông (Hell)"
	return ""

func get_season_buff(wave_num: int) -> Dictionary:
	# Mùa đã TẮT (FeatureFlags.SEASONS_ENABLED): nó sửa chỉ số tháp bằng một hệ
	# số VÔ HÌNH không xuất hiện trong bảng Nền × Bội. Tên mùa GIỮ LẠI làm nhãn
	# tiến trình (Xuân/Hạ/Thu/Đông) và vẫn quyết định loài địch nào spawn — đó là
	# phần đọc được; chỉ phần buff ngầm bị tắt.
	if not FeatureFlags.SEASONS_ENABLED:
		return {"desc": "Không ảnh hưởng chỉ số."}
	return SEASON_BUFFS.get(int(get_season(wave_num)), {})

# --- TÍNH SỐ ENEMY ---
func calculate_enemies_for_wave(wave: int, boost: bool = false) -> int:
	if is_boss_wave(wave):
		return BOSS_WAVE_MINION_COUNT   # boss đếm riêng, không nằm trong con số này
	var base_count = ENEMIES_PER_WAVE + max(0, wave - 1) * ENEMIES_PER_WAVE_INCREMENT
	if boost:
		base_count += SHOP_EXTRA_ENEMY_COUNT
	return base_count

func get_health_multiplier(wave_num: int, shop_boost: bool = false) -> float:
	var m = pow(ENEMY_HEALTH_GROWTH, float(max(wave_num - 1, 0)))
	if shop_boost:
		m += SHOP_EXTRA_HEALTH_MULTIPLIER
	return m * _ascension_mult("asc_enemy_hp_mult")

func get_speed_multiplier(wave_num: int, shop_boost: bool = false) -> float:
	var m = 1.0 + float(max(wave_num - 1, 0)) * ENEMY_SPEED_SCALE_PER_WAVE
	if shop_boost:
		m += SHOP_EXTRA_SPEED_MULTIPLIER
	return m * _ascension_mult("asc_enemy_speed_mult")

## Hệ số độ khó Ascension (A0 = 1.0). GameManager mới có các hàm này nên phải guard.
func _ascension_mult(method_name: String) -> float:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_method(method_name):
		return maxf(0.1, float(gm.call(method_name)))
	return 1.0

# --- SPAWN ---
func _on_spawn_timer_timeout() -> void:
	if enemies_spawned < _enemies_to_spawn:
		_spawn_one()
	else:
		_wave_spawn_timer.stop()

func _spawn_one() -> void:
	spawn_enemy(true)

func spawn_enemy(from_wave: bool = false) -> bool:
	if current_path_grid.is_empty():
		push_warning("WaveSpawner: Chưa có đường đi!")
		return false
	if not _parent_node:
		push_error("WaveSpawner: _parent_node chưa được set!")
		return false

	var pool = _get_season_enemy_pool(_wave_number)
	if pool.is_empty():
		push_error("WaveSpawner: Enemy pool rỗng — kiểm tra res/enemy/")
		return false

	var chosen_stats: EnemyStats = pool[randi() % pool.size()]
	if chosen_stats == null:
		push_error("WaveSpawner: Enemy stats null trong pool")
		return false

	var new_enemy = _enemy_scene.instantiate()
	new_enemy.stats = chosen_stats
	_parent_node.add_child(new_enemy)

	new_enemy.reached_base.connect(_on_enemy_reached_base)
	new_enemy.enemy_defeated.connect(_on_enemy_defeated)

	var hp_mult = get_health_multiplier(_wave_number, _active_shop_boost)
	var spd_mult = get_speed_multiplier(_wave_number, _active_shop_boost)
	if new_enemy.has_method("load_enemy_data"):
		new_enemy.load_enemy_data(hp_mult, spd_mult)
	if new_enemy.has_method("set_path"):
		new_enemy.set_path(current_path_grid)

	# Roll elite — sau load_enemy_data để nhân trên HP đã scale theo wave
	if _wave_number >= ELITE_MIN_WAVE and randf() < ELITE_CHANCE \
			and new_enemy.has_method("make_elite"):
		new_enemy.make_elite()
		var am = get_node_or_null("/root/AudioManagerSingleton")
		if am and am.has_method("play_sfx"):
			am.play_sfx("elite_spawn", -4.0)

	enemies_alive += 1
	if from_wave:
		enemies_spawned += 1
	return true

# --- BOSS ---

## Wave này có Rival King không? (tra bảng — dùng được cả trước khi wave bắt đầu)
func is_boss_wave(wave_num: int) -> bool:
	return BOSS_WAVES.has(wave_num)

## Wave ĐANG chạy còn "nợ" một Rival King chưa giải quyết không?
## Phản ánh trạng thái THỰC TẾ: boss spawn hỏng → trả false, không treo wave.
func is_boss_pending() -> bool:
	return _is_boss_wave and not (boss_defeated_this_wave or boss_escaped_this_wave)

## Máu boss = scale theo wave × hệ số Ascension (nếu GameManager có field đó).
func get_boss_health_multiplier(wave_num: int) -> float:
	return get_health_multiplier(wave_num, false) * get_ascension_multiplier()

## Đọc cấp Ascension một cách phòng thủ — GameManager chưa có field thì trả 1.0.
func get_ascension_multiplier() -> float:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return 1.0
	for field in ASCENSION_FIELDS:
		var value: Variant = gm.get(field)
		if value is int or value is float:
			return 1.0 + maxf(0.0, float(value)) * ASCENSION_HP_PER_LEVEL
	return 1.0

func _spawn_boss() -> void:
	if current_path_grid.is_empty() or _parent_node == null:
		push_warning("WaveSpawner: không spawn được boss — thiếu path hoặc parent node.")
		_is_boss_wave = false
		return
	var boss_stats := _pick_boss_stats()
	if boss_stats == null:
		push_warning("WaveSpawner: không tìm thấy BossStats nào — wave boss chạy như wave thường.")
		_is_boss_wave = false
		return
	if not _ensure_boss_scene():
		_is_boss_wave = false
		return

	var boss = _boss_scene.instantiate()
	boss.stats = boss_stats
	_parent_node.add_child(boss)

	boss.reached_base.connect(_on_boss_reached_base)
	boss.enemy_defeated.connect(_on_enemy_defeated)
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)

	# Boss KHÔNG bao giờ đi qua make_elite() — máu đã tự scale theo wave/Ascension.
	if boss.has_method("load_enemy_data"):
		boss.load_enemy_data(get_boss_health_multiplier(_wave_number),
			get_speed_multiplier(_wave_number, false))
	if boss.has_method("set_path"):
		boss.set_path(current_path_grid)

	enemies_alive += 1   # boss được tính vào wave → wave_cleared chờ boss chết
	current_boss = boss

	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("elite_spawn", -1.0)
	boss_spawned.emit(boss)

## Nạp boss.tscn lần đầu cần dùng. Thiếu file → cảnh báo và bỏ qua wave boss,
## phần còn lại của spawner vẫn chạy bình thường.
func _ensure_boss_scene() -> bool:
	if _boss_scene != null:
		return true
	if not ResourceLoader.exists(BOSS_SCENE_PATH):
		push_warning("WaveSpawner: thiếu %s — bỏ qua boss." % BOSS_SCENE_PATH)
		return false
	_boss_scene = load(BOSS_SCENE_PATH) as PackedScene
	if _boss_scene == null:
		push_warning("WaveSpawner: %s không phải PackedScene hợp lệ." % BOSS_SCENE_PATH)
		return false
	return true

## Chọn Rival King theo THỨ TỰ wave boss, không random — mục tiêu của ván là
## hạ ĐỦ CẢ BA, nên bốc ngẫu nhiên sẽ có ván gặp trùng một vua hai lần.
func _pick_boss_stats() -> EnemyStats:
	var idx: int = BOSS_WAVES.find(_wave_number)
	if idx < 0:
		idx = 0
	var boss_id: String = BOSS_IDS[idx % BOSS_IDS.size()]
	var stats: EnemyStats = _enemy_stats.get(boss_id)
	if stats == null:
		var path := BOSS_STATS_PATH % boss_id
		if ResourceLoader.exists(path):
			stats = load(path) as EnemyStats
	if stats == null:
		# Vua này hỏng file → lấy bất kỳ vua nào còn nạp được, thà đánh nhầm
		# vua còn hơn wave boss không có boss.
		for fallback_id in BOSS_IDS:
			var alt: EnemyStats = _enemy_stats.get(fallback_id)
			if alt:
				return alt
	return stats

## Đây là wave boss thứ mấy (1-based). HUD và phần thưởng dùng để hiển thị
## "Rival King 2/3".
func boss_index_of_wave(wave_num: int) -> int:
	return BOSS_WAVES.find(wave_num) + 1

func total_rival_kings() -> int:
	return BOSS_WAVES.size()

## Boss triệu hồi quái giữa trận. Quái được đếm vào `enemies_alive` (phải dọn hết
## mới clear wave) nhưng KHÔNG cộng vào `enemies_spawned` — nếu không wave sẽ
## kết thúc sớm vì tưởng đã spawn đủ.
func spawn_summon(enemy_id: String, cells: Array[Vector2i],
		hp_mult: float = 1.0, spd_mult: float = 1.0) -> bool:
	if _parent_node == null or cells.size() < 2:
		return false
	var stats: EnemyStats = _enemy_stats.get(enemy_id)
	if stats == null:
		push_warning("WaveSpawner.spawn_summon: không có enemy id '%s'" % enemy_id)
		return false

	var minion = _enemy_scene.instantiate()
	minion.stats = stats
	_parent_node.add_child(minion)
	minion.reached_base.connect(_on_enemy_reached_base)
	minion.enemy_defeated.connect(_on_enemy_defeated)
	if minion.has_method("load_enemy_data"):
		minion.load_enemy_data(hp_mult, spd_mult)
	if minion.has_method("set_path"):
		minion.set_path(cells)
	# Tản nhẹ để 3 con triệu hồi cùng lúc không chồng khít lên nhau
	minion.position += Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	enemies_alive += 1
	return true

# --- SIGNAL HANDLERS ---
func _on_enemy_reached_base(damage: int) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemy_reached_base.emit(damage)
	_check_wave_cleared()

func _on_enemy_defeated(gold: int) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	enemy_defeated.emit(gold)
	_check_wave_cleared()

## Boss bị hạ — phát TRƯỚC enemy_defeated nên cờ đã đúng khi _check_wave_cleared chạy.
func _on_boss_defeated() -> void:
	boss_defeated_this_wave = true
	current_boss = null

## Boss chạm King = THUA ngay. Rival King đặt chân tới ngai vàng thì vương quốc sụp,
## không thể tính là thắng chỉ vì boss rời sân. Cờ escaped vẫn bật để wave không treo
## trong trường hợp game_over không kịp xử lý (ví dụ HP bị buff cực cao khi test).
func _on_boss_reached_base(damage: int) -> void:
	boss_escaped_this_wave = true
	current_boss = null
	_on_enemy_reached_base(damage)
	boss_escaped.emit()

func _check_wave_cleared() -> void:
	# Wave boss: hết quái thường KHÔNG đủ — Rival King phải rời sân trước.
	if _is_boss_wave and not (boss_defeated_this_wave or boss_escaped_this_wave):
		return
	if enemies_spawned >= _enemies_to_spawn and enemies_alive <= 0:
		wave_cleared.emit()

# --- ENEMY POOL ---
func _get_enemy(id: String) -> EnemyStats:
	return _enemy_stats.get(id, _enemy_stats.get("orc"))

## Pool địch của một mùa. HOÀN TOÀN đọc từ dữ liệu: mỗi `.tres` tự khai
## `spawn_seasons` + `spawn_weight` của nó.
##
## Trước đây đây là một bảng CỨNG 23 dòng `_get_enemy("goblin")` — thêm một loài
## địch phải sửa GDScript. Nay thả file .tres là xong, không đụng code.
## `tools/migrate_enemy_data.py` đã ghi lịch cũ vào chính các file đó nên tần
## suất giữ nguyên y hệt bảng cứng.
func _get_season_enemy_pool(wave_num: int) -> Array:
	var pool: Array = []
	var season := get_season(wave_num)
	_append_data_driven_enemies(pool, season)
	# TRỘN VỚI MÙA TRƯỚC. Đổi pool đột ngột làm tổng máu wave nhảy bậc thang —
	# đo được 657 → 1507 chỉ trong một wave, tức người chơi đang thắng bỗng thua
	# mà không làm gì sai. Giữ một phần mùa cũ thì dốc thoải và người chơi có một
	# wave để kịp phản ứng.
	if int(season) > 0:
		var prev: Array = []
		_append_data_driven_enemies(prev, season - 1)
		var keep: int = int(round(float(prev.size()) * SEASON_BLEND))
		for i in keep:
			pool.append(prev[i % prev.size()])
	if pool.is_empty():
		# Không loài nào khai mùa này — thà cho orc ra còn hơn wave rỗng.
		var fallback: EnemyStats = _get_enemy("orc")
		if fallback:
			for i in 4:
				pool.append(fallback)
	return pool

## Chèn các loài KHAI BÁO LỊCH SPAWN TRONG .tres của chính nó. Nhờ đây thêm một
## loài địch mới chỉ cần thả file .tres vào res/enemy/ — không phải sửa bảng mùa
## cứng ở trên. Loài để `spawn_seasons` rỗng thì bảng cứng vẫn là nguồn duy nhất,
## nên mọi loài có sẵn giữ nguyên tần suất.
func _append_data_driven_enemies(pool: Array, season: int) -> void:
	for stats: EnemyStats in _enemy_stats.values():
		if stats == null or stats.spawn_seasons.is_empty():
			continue
		if not stats.spawn_seasons.has(season):
			continue
		for i in maxi(1, stats.spawn_weight):
			pool.append(stats)

func _load_enemy_stats() -> void:
	_enemy_stats.clear()
	var dir = DirAccess.open("res://res/enemy/")
	if not dir:
		push_error("WaveSpawner: Không thể mở res://res/enemy/")
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var stats = load("res://res/enemy/" + file) as EnemyStats
			if stats and stats.id != "":
				_enemy_stats[stats.id] = stats
		file = dir.get_next()
	dir.list_dir_end()

# --- WAVE INTEL ---
func get_wave_intel_text(wave_num: int) -> String:
	var pool = _get_season_enemy_pool(wave_num)
	var counts: Dictionary = {}
	for s: EnemyStats in pool:
		if not s: continue
		counts[s.id] = counts.get(s.id, 0) + 1
	var parts: Array[String] = []
	for enemy_id in counts.keys():
		var display: String = enemy_display_name(enemy_id)
		parts.append("%s×%d" % [display, counts[enemy_id]])
	var total = calculate_enemies_for_wave(wave_num)
	var sbuff: Dictionary = get_season_buff(wave_num)
	var season_effect: String = sbuff.get("desc", "")
	if is_boss_wave(wave_num):
		return "☠ WAVE BOSS %d (%s) — Một RIVAL KING xuất trận cùng %d hộ vệ: %s  |  %s" % [
			wave_num, get_season_name(wave_num), total, ", ".join(parts), season_effect,
		]
	return "Wave %d (%s) — %d địch: %s  |  %s" % [wave_num, get_season_name(wave_num), total, ", ".join(parts), season_effect]

## Danh sách địch của một wave, tốc độ quy về Ô/GIÂY (dữ liệu .tres giữ px).
## BoardScore dùng để tính ngưỡng — nó cần cùng đơn vị với bàn cờ.
func get_wave_enemy_preview(wave_num: int) -> Array:
	var data := build_wave_intel_data(wave_num)
	var rows: Array = []
	for e in data.get("enemies", []):
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		rows.append({
			"id": d.get("id", ""),
			"display": d.get("display", ""),
			"count": int(d.get("count", 0)),
			"hp": int(d.get("hp", 0)),
			"speed": float(d.get("speed", 16)) / 16.0,
		})
	return rows


func build_wave_intel_data(wave_num: int) -> Dictionary:
	var pool = _get_season_enemy_pool(wave_num)
	var counts: Dictionary = {}
	var first_seen: Dictionary = {}
	for s: EnemyStats in pool:
		if not s: continue
		counts[s.id] = counts.get(s.id, 0) + 1
		if not first_seen.has(s.id):
			first_seen[s.id] = s
	var hp_mult = get_health_multiplier(wave_num)
	var spd_mult = get_speed_multiplier(wave_num)
	var enemy_list: Array = []
	for enemy_id in counts.keys():
		var stats: EnemyStats = first_seen[enemy_id]
		enemy_list.append({
			"id": enemy_id,
			"display": enemy_display_name(enemy_id),
			"count": counts[enemy_id],
			"hp": int(stats.max_hp * hp_mult),
			"speed": int(stats.speed * spd_mult),
			"damage": stats.damage_to_base,
			"gold": stats.gold_reward,
		})
	var sbuff: Dictionary = get_season_buff(wave_num)
	return {
		"wave": wave_num,
		"total": calculate_enemies_for_wave(wave_num),
		"season_name": get_season_name(wave_num),
		"season_desc": sbuff.get("desc", ""),
		"enemies": enemy_list,
		# Danh tính boss được giữ bí mật tới lúc spawn — trinh sát chỉ báo có boss.
		"is_boss_wave": is_boss_wave(wave_num),
		"boss_hint": "☠ RIVAL KING xuất trận — hạ hắn mới thắng!" if is_boss_wave(wave_num) else "",
	}

## Tên hiển thị của một loài: ưu tiên field `display_name` trong .tres, rồi tới
## bảng tên cũ, cuối cùng là id viết hoa. Loài mới chỉ cần điền .tres.
func enemy_display_name(enemy_id: String) -> String:
	var stats: EnemyStats = _enemy_stats.get(enemy_id)
	if stats != null and stats.display_name != "":
		return stats.display_name
	return _ENEMY_DISPLAY_NAMES.get(enemy_id, enemy_id.capitalize())

## Ghi chú năng lực: field trong .tres trước, rồi bảng ABILITY_NOTES, cuối là "—".
func enemy_ability_note(enemy_id: String) -> String:
	var stats: EnemyStats = _enemy_stats.get(enemy_id)
	if stats != null and stats.ability_note != "":
		return stats.ability_note
	return str(EnemyStats.ABILITY_NOTES.get(enemy_id, "—"))
