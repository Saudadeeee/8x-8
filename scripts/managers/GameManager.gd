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

func _ready() -> void:
	meta_progress = MetaProgress.load_or_create()

func _process(delta: float) -> void:
	# Hồi Decree theo thời gian khi đang trong ván
	if current_state == GameState.PREPARING or current_state == GameState.WAVE_ACTIVE:
		_regen_decree(delta)

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
	current_grid_size = Vector2i(8, 8)
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
	change_state(GameState.PREPARING)

# --- ĐỔI TRẠNG THÁI ---
func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

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

func force_game_over() -> void:
	_trigger_game_over()

func _trigger_victory() -> void:
	change_state(GameState.VICTORY)
	_update_meta_on_run_end(true)
	run_ended.emit(true)
	call_deferred("_deferred_goto_victory")

func _deferred_goto_victory() -> void:
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm and sm.has_method("go_to_scene"):
		sm.go_to_scene("res://scenes/ui/victory_screen.tscn")

func force_victory() -> void:
	_trigger_victory()

func trigger_encounter(encounter) -> void:
	change_state(GameState.ENCOUNTER)
	encounter_triggered.emit(encounter)

# --- META PROGRESSION ---
func _update_meta_on_run_end(is_victory: bool) -> void:
	if not meta_progress: return
	meta_progress.total_runs += 1
	if is_victory:
		meta_progress.total_wins += 1
	meta_progress.total_enemies_killed += run_enemies_killed
	meta_progress.total_gold_earned += run_gold_earned
	if current_wave > meta_progress.best_wave_reached:
		meta_progress.best_wave_reached = current_wave
	# Cộng meta points dựa trên performance
	meta_progress.meta_points += _calculate_meta_points()
	meta_progress.save()

func _calculate_meta_points() -> int:
	var base_pts = current_wave * 10 + run_enemies_killed
	var gold_bonus: int = int(run_gold_earned * 0.05)
	var victory_bonus = 0
	if current_state == GameState.VICTORY:
		victory_bonus = 50
	run_meta_points_earned = base_pts + gold_bonus + victory_bonus
	return run_meta_points_earned
