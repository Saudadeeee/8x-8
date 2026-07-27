# res://scripts/managers/GameManager.gd
# Quản lý trạng thái tổng thể của một ván chơi (run).
# Là Autoload/Singleton để mọi script có thể truy cập.
extends Node
class_name GameManager

# --- TRẠNG THÁI GAME ---
enum GameState {
	MAIN_MENU,      # Đang ở menu chính
	KING_SELECT,    # Đang chọn vua
	PREPARING,      # Giữa các wave (đặt quân, mua đồ)
	WAVE_ACTIVE,    # Đang có wave quái tấn công
	ENCOUNTER,      # Đang xử lý Random Encounter
	SHOP,           # Đang ở màn hình Shop
	GAME_OVER,      # Thua
	VICTORY         # Thắng (nếu có điểm kết thúc)
}

# --- SIGNALS ---
signal state_changed(new_state: GameState)
signal health_changed(new_health: int)
signal gold_changed(new_gold: int)
signal decree_changed(new_decree: float)
signal run_ended(is_victory: bool)
signal encounter_triggered(encounter)
signal combo_changed(count: int, mult: float)
## Vùng môi trường (biome) của bản đồ vừa đổi — spec là dict {name, desc, mod}
## lấy từ BiomeLibrary (có thể rỗng nếu library chưa tồn tại).
signal biome_changed(biome_id: String, spec: Dictionary)
## Tốc độ chạy game vừa đổi (1× / 2× / 3×). HUD nghe để tô sáng nút đang chọn.
signal game_speed_changed(new_speed: float)

# --- DỮ LIỆU VAN CHƠI HIỆN TẠI (Runtime) ---
var current_state: GameState = GameState.MAIN_MENU
var selected_king: KingStats = null
var meta_progress: MetaProgress = null

# Chỉ số hiện tại
var current_health: int = 20
var current_gold: int = 100
var current_decree: float = 10.0
var current_decree_max: float = 100.0
var current_wave: int = 0
var current_grid_size: Vector2i = Vector2i(8, 8)

# Thống kê trong ván
var run_enemies_killed: int = 0
var run_gold_earned: int = 0
var run_meta_points_earned: int = 0
## Chuỗi combo dài nhất đạt được trong ván (bảng thống kê cuối run đọc).
var run_best_combo: int = 0
## Tổng sát thương từng loại tháp gây ra trong ván: stats.id (String) → damage (int).
## tower.gd gọi record_tower_damage() để cộng dồn; reset trong start_run.
var run_tower_damage: Dictionary = {}

# --- ĐIỀU KHIỂN TỐC ĐỘ GAME (QoL) ---
## Các mốc tốc độ cho nút 1×/2×/3× trên HUD.
const SPEED_STEPS: Array[float] = [1.0, 2.0, 3.0]
const DEFAULT_GAME_SPEED: float = 1.0
## Chặn dưới > 0 — Engine.time_scale = 0 sẽ đóng băng CẢ tween UI và
## SceneTreeTimer, gây kẹt game. Tạm dừng LUÔN dùng get_tree().paused.
const MIN_GAME_SPEED: float = 0.25
const MAX_GAME_SPEED: float = 4.0

var game_speed: float = DEFAULT_GAME_SPEED

# --- ASCENSION (bậc độ khó — giá trị chơi lại) ---
const MAX_ASCENSION: int = 5

## Bậc độ khó của ván hiện tại (0 = thường). king_select gán trước start_run.
var ascension_level: int = 0

# --- PERK STATE (per-run, được PerkSystem ghi — reset trong start_run) ---
const DEFAULT_INTEREST_CAP: int = 15
const DEFAULT_INTEREST_RATE: float = 0.10

var active_perks: Array[String] = []          # mirror id perk đã chọn (nguồn: PerkSystem.owned)
var perk_gold_per_kill: int = 0               # vàng cộng thêm mỗi kill ("Thuế Máu")
var perk_interest_cap: int = DEFAULT_INTEREST_CAP    # trần lãi cuối wave ("Ngân Khố")
var perk_interest_rate: float = DEFAULT_INTEREST_RATE # lãi suất cuối wave ("Hầm Vàng")
var perk_decree_grant_mult: float = 1.0       # hệ số RD nhận khi thắng wave ("Quyền Uy")
var perk_rd_per_wave_start: float = 0.0       # RD cộng khi wave bắt đầu ("Sắc Lệnh Khẩn")

# Perk gắn với LỐI CHƠI nguyên tố (futureplan §3.4). Mặc định = không đổi luật.
var perk_tile_discount: float = 0.0           # "Địa Chủ" — ô nguyên tố rẻ hơn
var perk_equip_discount: float = 0.0          # "Thợ Rèn Lang Thang" — trang bị rẻ hơn
var perk_element_damage: Dictionary = {}      # nguyên tố → % DoT cộng thêm ("Hoả Sư")
var perk_freeze_bonus: float = 0.0            # "Hàn Băng Quyết" — Đóng Băng lâu hơn (giây)
var perk_conduct_extra: int = 0               # "Lôi Đình" — Dẫn Điện lan thêm mục tiêu
var perk_water_spread: bool = false           # "Thuỷ Mạch" — Dấu Thuỷ tự lan 1 địch kề
var perk_poison_max_stacks: int = 0           # "Độc Sư" — trần tầng Độc mới (0 = mặc định)
var perk_potion_per_reactions: int = 0        # "Nhà Giả Kim" — mỗi N phản ứng tặng 1 thuốc
var perk_no_element_damage: float = 0.0       # "Thuần Vật Lý" — tháp KHÔNG đứng ô nguyên tố

# --- BIOME STATE (per-run — BiomeEffects ghi, reset trong start_run) ---
# Nguồn sự thật cho hiệu ứng khí hậu toàn bản đồ. enemy.gd đọc 2 hệ số dưới
# lúc load_enemy_data (quái ĐÃ spawn không đổi), game_map lấy vàng/kill qua
# get_perk_gold_per_kill(), enemy.gd nhân biome_burn_mult vào DoT.
const DEFAULT_BIOME_ID: String = "wasteland"

var active_biome: String = DEFAULT_BIOME_ID
var active_biome_spec: Dictionary = {}   # {name, desc, mod} — rỗng nếu thiếu BiomeLibrary
var active_biome_mod: Dictionary = {}    # mod đã chuẩn hoá đang áp (cho HUD tooltip)
var biome_enemy_speed_mult: float = 1.0
var biome_enemy_hp_mult: float = 1.0
var biome_gold_per_kill: int = 0
var biome_burn_mult: float = 1.0

# --- CRIT (per-run — perk tương lai có thể nâng qua 2 field này) ---
const DEFAULT_CRIT_CHANCE: float = 0.05
const DEFAULT_CRIT_MULT:   float = 2.0

var crit_chance: float = DEFAULT_CRIT_CHANCE  # xác suất chí mạng mỗi viên đạn
var crit_mult:   float = DEFAULT_CRIT_MULT    # hệ số sát thương khi chí mạng

# --- NGUYÊN TỐ (per-run) ---
## Nhân vàng của phản ứng Kết Tinh. Synergy Thổ ×6 "Địa Chấn" đẩy 15 → 40 vàng.
var crystal_gold_mult: float = 1.0
## Nhân sát thương MỌI phản ứng — di vật "Sách Giả Kim". Tháp đọc qua reaction_power_mult,
## field này là nguồn toàn cục để tháp mới đặt cũng thừa hưởng.
var global_reaction_mult: float = 1.0

# --- DI VẬT (RelicSystem GHI ĐÈ toàn bộ mỗi lần đổi sở hữu — đừng cộng dồn tay) ---
var relic_max_marks: int = ElementTypes.DEFAULT_MAX_MARKS  # Bánh Xe Nguyên Tố
var relic_no_consume_chance: float = 0.0     # Lò Phản Ứng
var relic_marked_damage_taken: float = 0.0   # Vòng Cổ Thợ Săn
var relic_tile_discount: float = 0.0         # Địa Chất Sư
var relic_vein_spread: bool = false          # Long Mạch Sống
var relic_elite_always_drop: bool = false    # Bản Đồ Kho Báu
var relic_all_elements_pct: float = 0.0      # Trái Tim Nguyên Sơ

# --- SYNERGY NGUYÊN TỐ (ElementSynergy GHI ĐÈ mỗi lần đếm lại) ---
# Mốc ×6 của mỗi nguyên tố đổi LUẬT chứ không cộng chỉ số. Mặc định = tắt.
var syn_fire_spread: float = 0.0        # Biển Lửa — bán kính lan Dấu Hoả (m)
var syn_ice_no_freeze_cd: bool = false  # Băng Vĩnh Cửu — bỏ cooldown ẩn Đóng Băng
var syn_thunder_targets: int = 0        # Bão Sét — trần mục tiêu Dẫn Điện
var syn_poison_stacks: int = 0          # Đại Dịch — trần tầng Độc
var syn_water_spawn_mark: bool = false  # Thuỷ Triều — địch spawn mang sẵn Dấu Thuỷ
var bagua_active: bool = false          # đủ 6 nguyên tố trên bàn → mở Nguyên Sơ

# --- KILL COMBO (chuỗi hạ địch trong cửa sổ COMBO_WINDOW giây) ---
const COMBO_WINDOW: float = 2.5

var combo_count:  int   = 0
var _combo_timer: float = 0.0

func _ready() -> void:
	meta_progress = MetaProgress.load_or_create()

func _process(delta: float) -> void:
	# RD không regen tự động — chỉ nhận khi thắng wave
	_tick_combo(delta)

# --- KHỞI ĐỘNG VÁN CHƠI ---
func start_run(king: KingStats) -> void:
	selected_king = king
	current_health = king.base_health
	current_gold = 100
	current_decree = king.base_royal_decree
	current_decree_max = king.decree_max
	current_wave = 0
	run_enemies_killed = 0
	run_gold_earned = 0
	run_meta_points_earned = 0
	run_best_combo = 0
	run_tower_damage = {}
	crystal_gold_mult = 1.0
	global_reaction_mult = 1.0
	relic_max_marks = ElementTypes.DEFAULT_MAX_MARKS
	relic_no_consume_chance = 0.0
	relic_marked_damage_taken = 0.0
	relic_tile_discount = 0.0
	relic_vein_spread = false
	relic_elite_always_drop = false
	relic_all_elements_pct = 0.0
	syn_fire_spread = 0.0
	syn_ice_no_freeze_cd = false
	syn_thunder_targets = 0
	syn_poison_stacks = 0
	syn_water_spawn_mark = false
	bagua_active = false
	current_grid_size = Vector2i(8, 8)
	# Ván mới luôn bắt đầu ở 1× và KHÔNG bị pause treo từ ván trước
	reset_game_speed()
	reset_perk_state()
	reset_combat_modifiers()
	reset_biome_state()
	# Áp dụng Meta Upgrades đã mua
	if meta_progress:
		for upgrade in meta_progress.meta_upgrades:
			var uid = upgrade.get("id", "")
			var level: int = upgrade.get("level", 0)
			if level <= 0:
				continue
			match uid:
				"starting_gold":
					current_gold += level * 50
				"health_bonus":
					current_health += level * 5
				"decree_bonus":
					current_decree_max += level * 10
	# Ascension trừ vàng khởi đầu — áp SAU meta upgrade, không cho âm
	current_gold = maxi(0, current_gold + asc_start_gold_delta())
	change_state(GameState.PREPARING)

# --- TỐC ĐỘ GAME / TẠM DỪNG ---
## Đặt tốc độ chạy game. Giá trị bị kẹp trong [MIN_GAME_SPEED, MAX_GAME_SPEED]
## nên KHÔNG bao giờ đặt Engine.time_scale = 0 (dùng toggle_pause để dừng).
func set_game_speed(v: float) -> void:
	var target: float = clampf(v, MIN_GAME_SPEED, MAX_GAME_SPEED)
	if is_equal_approx(target, game_speed) and is_equal_approx(Engine.time_scale, target):
		return
	game_speed = target
	Engine.time_scale = target
	game_speed_changed.emit(game_speed)

## Nhảy sang mốc tốc độ kế tiếp trong SPEED_STEPS (vòng lại từ đầu).
## Trả về tốc độ mới để call site cập nhật UI ngay.
func cycle_game_speed() -> float:
	var idx: int = -1
	for i in SPEED_STEPS.size():
		if is_equal_approx(SPEED_STEPS[i], game_speed):
			idx = i
			break
	var next_idx: int = 0 if idx < 0 else (idx + 1) % SPEED_STEPS.size()
	set_game_speed(SPEED_STEPS[next_idx])
	return game_speed

## Trả tốc độ + trạng thái pause về mặc định. Gọi khi bắt đầu ván mới hoặc
## khi rời map về menu (tránh mang 3×/paused sang scene khác).
func reset_game_speed() -> void:
	set_paused(false)
	set_game_speed(DEFAULT_GAME_SPEED)

func is_paused() -> bool:
	var tree := get_tree()
	return tree != null and tree.paused

func set_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = paused

## Đảo trạng thái tạm dừng — trả về trạng thái SAU khi đảo.
func toggle_pause() -> bool:
	var new_state := not is_paused()
	set_paused(new_state)
	return new_state

# --- ASCENSION ---
## Đặt bậc độ khó cho ván sắp tới (kẹp trong [0, MAX_ASCENSION]).
func set_ascension(n: int) -> void:
	ascension_level = clampi(n, 0, MAX_ASCENSION)

## Bậc cao nhất người chơi được phép chọn (đã mở khoá qua thắng ván).
func max_selectable_ascension() -> int:
	if meta_progress == null:
		return 0
	return clampi(int(meta_progress.ascension_unlocked), 0, MAX_ASCENSION)

## Hệ số máu quái theo Ascension — hệ khác (wave_spawner/enemy) đọc rồi tự nhân.
func asc_enemy_hp_mult() -> float:
	return 1.0 + 0.15 * float(ascension_level)

## Hệ số tốc độ quái theo Ascension.
func asc_enemy_speed_mult() -> float:
	return 1.0 + 0.04 * float(ascension_level)

## Vàng khởi đầu bị trừ theo Ascension (giá trị ÂM hoặc 0).
func asc_start_gold_delta() -> int:
	return -10 * ascension_level

## Hệ số meta point thưởng cuối ván theo Ascension.
func asc_reward_mult() -> float:
	return 1.0 + 0.25 * float(ascension_level)

# --- ĐỔI TRẠNG THÁI ---
func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

# --- PERKS (per-run) ---
func reset_perk_state() -> void:
	active_perks.clear()
	perk_gold_per_kill = 0
	perk_interest_cap = DEFAULT_INTEREST_CAP
	perk_interest_rate = DEFAULT_INTEREST_RATE
	perk_decree_grant_mult = 1.0
	perk_rd_per_wave_start = 0.0
	perk_tile_discount = 0.0
	perk_equip_discount = 0.0
	perk_element_damage = {}
	perk_freeze_bonus = 0.0
	perk_conduct_extra = 0
	perk_water_spread = false
	perk_poison_max_stacks = 0
	perk_potion_per_reactions = 0
	perk_no_element_damage = 0.0

func get_interest_cap() -> int:
	return perk_interest_cap

func get_interest_rate() -> float:
	return perk_interest_rate

## Vàng thưởng thêm mỗi kill. Gộp cả perk ("Thuế Máu") lẫn biome hiện tại —
## game_map._on_enemy_defeated chỉ gọi getter này nên không cần biết về biome.
func get_perk_gold_per_kill() -> int:
	return perk_gold_per_kill + biome_gold_per_kill

# --- BIOME (per-run) ---
## Trả mọi hiệu ứng khí hậu về trung tính. Gọi trong start_run và khi rời map.
func reset_biome_state() -> void:
	active_biome = DEFAULT_BIOME_ID
	active_biome_spec = {}
	active_biome_mod = {}
	biome_enemy_speed_mult = 1.0
	biome_enemy_hp_mult = 1.0
	biome_gold_per_kill = 0
	biome_burn_mult = 1.0

## BiomeEffects gọi khi áp biome mới — GÁN (không cộng dồn) rồi phát signal.
func set_active_biome(biome_id: String, spec: Dictionary, mod: Dictionary) -> void:
	active_biome = biome_id if biome_id != "" else DEFAULT_BIOME_ID
	active_biome_spec = spec
	active_biome_mod = mod
	biome_enemy_speed_mult = _biome_num(active_biome_mod, "enemy_speed_mult", 1.0)
	biome_enemy_hp_mult    = _biome_num(active_biome_mod, "enemy_hp_mult",    1.0)
	biome_burn_mult        = _biome_num(active_biome_mod, "burn_mult",        1.0)
	biome_gold_per_kill    = int(round(_biome_num(active_biome_mod, "gold_per_kill", 0.0)))
	biome_changed.emit(active_biome, active_biome_spec)

## Đọc một hệ số từ mod — chấp nhận int/float, thiếu/sai kiểu thì lấy mặc định.
func _biome_num(mod: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = mod.get(key, null)
	if value is float or value is int:
		return float(value)
	return fallback

# --- CRIT + KILL COMBO ---
func reset_combat_modifiers() -> void:
	crit_chance = DEFAULT_CRIT_CHANCE
	crit_mult   = DEFAULT_CRIT_MULT
	combo_count  = 0
	_combo_timer = 0.0
	combo_changed.emit(0, 1.0)

## Hệ số vàng theo bậc combo hiện tại.
func get_combo_mult() -> float:
	if combo_count >= 20: return 1.5
	if combo_count >= 10: return 1.25
	if combo_count >= 5:  return 1.1
	return 1.0

## Ghi nhận 1 kill vào chuỗi combo — reset cửa sổ, trả về hệ số vàng hiện tại.
func register_kill() -> float:
	var old_mult := get_combo_mult()
	combo_count += 1
	run_best_combo = maxi(run_best_combo, combo_count)
	_combo_timer = COMBO_WINDOW
	var mult := get_combo_mult()
	combo_changed.emit(combo_count, mult)
	# SFX chỉ khi LÊN bậc combo — tránh spam mỗi kill
	if mult > old_mult:
		var am = get_node_or_null("/root/AudioManagerSingleton")
		if am and am.has_method("play_sfx"):
			am.play_sfx("gold", -10.0)
	return mult

func _tick_combo(delta: float) -> void:
	if _combo_timer <= 0.0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0 and combo_count > 0:
		combo_count = 0
		combo_changed.emit(0, 1.0)

# --- ROYAL DECREE (MANA) ---
func _regen_decree(delta: float) -> void:
	if not selected_king: return
	var new_decree = current_decree + selected_king.decree_regen_rate * delta
	current_decree = min(new_decree, current_decree_max)
	decree_changed.emit(current_decree)

func spend_decree(amount: float) -> bool:
	if current_decree < amount:
		return false
	current_decree -= amount
	decree_changed.emit(current_decree)
	return true

# --- VÀNG ---
func add_gold(amount: int) -> void:
	current_gold += amount
	run_gold_earned += amount
	gold_changed.emit(current_gold)

func spend_gold(amount: int) -> bool:
	if current_gold < amount:
		return false
	current_gold -= amount
	gold_changed.emit(current_gold)
	return true

# --- MÁU ---
func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		_trigger_game_over()

func _trigger_game_over() -> void:
	change_state(GameState.GAME_OVER)
	_update_meta_on_run_end(false)
	run_ended.emit(false)
	call_deferred("_deferred_goto_game_over")

func _deferred_goto_game_over() -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm and sm.has_method("go_to_scene"):
		sm.go_to_scene("res://scenes/ui/game_over_screen.tscn")
	else:
		push_warning("GameManager: SceneManagerSingleton không tồn tại — đổi scene trực tiếp.")
		get_tree().change_scene_to_file("res://scenes/ui/game_over_screen.tscn")

func force_game_over() -> void:
	_trigger_game_over()

func _trigger_victory() -> void:
	# force_victory() được gọi từ PhaseController.enter_shop_phase() khi wave cuối
	# vừa được clear — hàm đó return sớm TRƯỚC khi gán current_wave = wave_number,
	# nên phải cộng bù wave cuối vào đây để stats/meta ghi nhận đúng (wave 10 thay vì 9).
	current_wave += 1
	change_state(GameState.VICTORY)
	_update_meta_on_run_end(true)
	run_ended.emit(true)
	call_deferred("_deferred_goto_victory")

func _deferred_goto_victory() -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm and sm.has_method("go_to_scene"):
		sm.go_to_scene("res://scenes/ui/victory_screen.tscn")
		# victory_screen chỉ nghe run_ended trong _ready (không tự đọc stats như
		# game_over_screen) — signal đã emit TRƯỚC khi scene load nên phát lại
		# sau khi chuyển cảnh xong để màn hình hiển thị đúng thống kê.
		if sm.has_signal("transition_finished"):
			await sm.transition_finished
			run_ended.emit(true)
	else:
		push_warning("GameManager: SceneManagerSingleton không tồn tại — đổi scene trực tiếp.")
		get_tree().change_scene_to_file("res://scenes/ui/victory_screen.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		run_ended.emit(true)

func force_victory() -> void:
	_trigger_victory()

func trigger_encounter(encounter) -> void:
	change_state(GameState.ENCOUNTER)
	encounter_triggered.emit(encounter)

# --- THỐNG KÊ SÁT THƯƠNG THEO THÁP ---
## Cộng dồn sát thương một loại tháp gây ra. tower.gd gọi mỗi lần đánh trúng.
## [param id] là TowerStats.id; giá trị <= 0 hoặc id rỗng bị bỏ qua.
func record_tower_damage(id: String, amount: int) -> void:
	if id == "" or amount <= 0:
		return
	run_tower_damage[id] = int(run_tower_damage.get(id, 0)) + amount

## Top [param n] tháp gây sát thương nhiều nhất — mảng [{id, damage}] giảm dần.
func top_towers(n: int = 5) -> Array:
	var rows: Array = []
	for id in run_tower_damage.keys():
		rows.append({"id": str(id), "damage": int(run_tower_damage[id])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["damage"]) > int(b["damage"]))
	if n > 0 and rows.size() > n:
		rows.resize(n)
	return rows

# --- META PROGRESSION ---
func _update_meta_on_run_end(is_victory: bool) -> void:
	if not meta_progress: return
	meta_progress.total_runs += 1
	if is_victory:
		meta_progress.total_wins += 1
		_record_ascension_clear()
	meta_progress.total_enemies_killed += run_enemies_killed
	meta_progress.total_gold_earned += run_gold_earned
	if current_wave > meta_progress.best_wave_reached:
		meta_progress.best_wave_reached = current_wave
	# Cộng meta points dựa trên performance
	meta_progress.meta_points += _calculate_meta_points()
	meta_progress.save()

## Ghi nhận thắng ván ở bậc Ascension hiện tại: mở khoá bậc kế tiếp (tối đa
## MAX_ASCENSION) và lưu bậc đã clear. Không tự save — _update_meta_on_run_end
## gọi meta_progress.save() ngay sau đó.
func _record_ascension_clear() -> void:
	if meta_progress == null:
		return
	var next_level: int = mini(ascension_level + 1, MAX_ASCENSION)
	if next_level > int(meta_progress.ascension_unlocked):
		meta_progress.ascension_unlocked = next_level
	if not meta_progress.ascension_cleared.has(ascension_level):
		meta_progress.ascension_cleared.append(ascension_level)

func _calculate_meta_points() -> int:
	var base_pts = current_wave * 10 + run_enemies_killed
	var gold_bonus: int = int(run_gold_earned * 0.05)
	var victory_bonus = 0
	if current_state == GameState.VICTORY:
		victory_bonus = 50
	# Ascension càng cao thưởng càng nhiều — động lực chơi lại
	run_meta_points_earned = int(round(float(base_pts + gold_bonus + victory_bonus) * asc_reward_mult()))
	return run_meta_points_earned
