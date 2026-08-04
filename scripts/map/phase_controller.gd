# res://scripts/map/phase_controller.gd
# Quản lý state machine PREPARE → WAVE → SHOP và đếm ngược phase.
# Được game_map.gd khởi tạo và làm con node.
extends Node
class_name PhaseController

# --- SIGNALS ---
signal phase_changed(phase: GamePhase)
signal prep_countdown_updated(seconds: int)
## Nút "START WAVE" nên sáng hay không. Phát khi vào pha chuẩn bị (false) và
## khi người chơi xác nhận xong trinh sát (true).
signal prep_ready_changed(ready: bool)
signal wave_started(wave_number: int, enemy_count: int)
signal shop_phase_entered(wave_number: int, interest_gold: int)
signal season_buffs_apply_requested(wave_number: int)
signal shop_panel_show_requested
signal phase_message_changed(text: String)

# --- ENUMS / CONSTANTS ---
enum GamePhase { PREPARE, WAVE, SHOP }

# 20 wave = ba chặng, mỗi chặng kết bằng một Rival King (wave 7, 14, 20).
# Trước đây 10 wave / một boss — chưa tới một phần ba lời hứa trong GDD.
## Ván ~15 phút. Roguelike cần THUA NHANH để học nhanh.
const MAX_WAVES:     int   = 12
## Giữ lại làm hằng tương thích: pha chuẩn bị không còn đếm ngược nữa
## (xem `request_start_wave`). 0 nghĩa là "không giới hạn thời gian".
const PREP_DURATION: float = 0.0

# --- STATE ---
var current_phase:          GamePhase = GamePhase.PREPARE
var wave_number:            int   = 1
var prep_countdown:         float = PREP_DURATION
var _wave_confirmed:        bool  = false
var upcoming_shop_boost:    bool  = false
var active_shop_boost:      bool  = false
var _shop_shown_this_phase: bool  = false
var phase_message:          String = ""

# --- REFS (set bởi game_map) ---
var wave_spawner   = null
var shop_manager   = null
var _game_manager  = null
var _grid_controller              = null
var _gold_getter: Callable      # game_map cung cấp: returns current_gold: int

func setup(ws, sm, gm, gc, gold_getter: Callable) -> void:
	wave_spawner     = ws
	shop_manager     = sm
	_game_manager    = gm
	_grid_controller = gc
	_gold_getter     = gold_getter

# --- LIFECYCLE ---

func _process(delta: float) -> void:
	match current_phase:
		GamePhase.PREPARE: _tick_prepare(delta)
		GamePhase.WAVE:    _tick_wave()
		GamePhase.SHOP:    pass

# --- PUBLIC API ---

func start_prep_phase() -> void:
	current_phase   = GamePhase.PREPARE
	prep_countdown  = 0.0
	_wave_confirmed = false
	phase_changed.emit(current_phase)
	prep_ready_changed.emit(false)
	_set_phase_message("Read the wave intel, then confirm to begin preparing...")

	if wave_spawner:
		_emit_wave_intel()

func confirm_wave_ready() -> void:
	if current_phase != GamePhase.PREPARE or _wave_confirmed:
		return
	_wave_confirmed = true
	_set_phase_message("When your board is ready, press START WAVE | %s"
		% (wave_spawner.get_wave_intel_text(wave_number) if wave_spawner else ""))
	prep_ready_changed.emit(true)


## Người chơi bấm nút bắt đầu wave. Trả false nếu chưa tới lúc (chưa xác nhận
## trinh sát, hoặc đang ở pha khác) — nơi gọi dùng để bật/tắt nút.
##
## Vì sao KHÔNG còn đếm ngược: pha chuẩn bị trước đây tự hết giờ sau 30 giây và
## tự vào wave. Đặt tháp đúng lúc đồng hồ về 0 sinh lỗi tranh chấp trạng thái, và
## quan trọng hơn — nó biến quyết định bố trí thành cuộc đua bấm nhanh. Bỏ đồng
## hồ thì người chơi có bao nhiêu thời gian tuỳ ý để tính bố cục, đúng kiểu
## tower defense cổ điển (Bloons TD: xây thoải mái rồi bấm play).
func request_start_wave() -> bool:
	if current_phase != GamePhase.PREPARE or not _wave_confirmed:
		return false
	_start_wave_phase()
	return true


## Đang ở pha chuẩn bị và đã xác nhận trinh sát → nút bắt đầu wave phải sáng.
func can_start_wave() -> bool:
	return current_phase == GamePhase.PREPARE and _wave_confirmed

## Wave cuối chỉ được tính là thắng khi Rival King đã rời sân (bị hạ hoặc lọt
## qua King). Spawner cũ không có khái niệm boss → giữ nguyên hành vi cũ.
func _is_boss_resolved() -> bool:
	if wave_spawner == null:
		return true
	# is_boss_pending() phản ánh trạng thái thực tế: boss spawn hỏng cũng trả false
	# nên wave cuối không bao giờ bị treo.
	if wave_spawner.has_method("is_boss_pending"):
		return not wave_spawner.is_boss_pending()
	return true   # spawner không biết khái niệm boss → giữ nguyên hành vi cũ

## Gọi sau khi wave_cleared signal đến.
func enter_shop_phase() -> void:
	if current_phase == GamePhase.SHOP:
		return
	if wave_number >= MAX_WAVES:
		# Hết giờ / hết quái thường KHÔNG còn tự thắng — phải hạ Rival King.
		if not _is_boss_resolved():
			_set_phase_message("☠ The Rival King still stands - bring him down to unite the kingdom!")
			return
		if _game_manager:
			_game_manager.force_victory()
		return

	if wave_spawner:
		wave_spawner.stop()
	if _game_manager:
		_game_manager.current_wave = wave_number

	current_phase          = GamePhase.SHOP
	active_shop_boost      = false
	upcoming_shop_boost    = false
	_shop_shown_this_phase = false

	# Tính lãi gold: mặc định 10% capped 15 — perk kinh tế nâng rate/cap qua GameManager
	var gold: int   = _gold_getter.call() if _gold_getter.is_valid() else 0
	var rate: float = 0.10
	var cap: int    = 15
	if _game_manager and _game_manager.has_method("get_interest_rate"):
		rate = _game_manager.get_interest_rate()
	if _game_manager and _game_manager.has_method("get_interest_cap"):
		cap = _game_manager.get_interest_cap()
	var interest: int = min(int(gold * rate), cap)
	var interest_msg := " | Interest: +%d gold" % interest if interest > 0 else ""

	if shop_manager:
		shop_manager.update_wave(wave_number)
		shop_manager.refresh_shop(true)

	_set_phase_message("Wave %d complete!%s Buy pieces, then press NEXT WAVE." % [wave_number, interest_msg])
	phase_changed.emit(current_phase)
	shop_phase_entered.emit(wave_number, interest)

## Gọi sau khi encounter resolved — hiện shop panel.
func show_shop_after_encounter() -> void:
	if current_phase != GamePhase.SHOP or _shop_shown_this_phase:
		return
	_shop_shown_this_phase = true
	shop_panel_show_requested.emit()

## Gọi khi player bấm Next Wave.
## game_map gọi expand rồi gọi start_prep_phase().
func request_next_wave() -> void:
	if current_phase != GamePhase.SHOP:
		return
	wave_number += 1

# --- INTERNAL PHASE TICKS ---

## Pha chuẩn bị KHÔNG còn tự hết giờ — wave chỉ bắt đầu khi người chơi bấm nút.
## Giữ hàm để máy trạng thái vẫn có đủ ba nhánh và để hiển thị nhắc nhở.
func _tick_prepare(_delta: float) -> void:
	pass

func _start_wave_phase() -> void:
	# Tắt nút bắt đầu wave ở MỌI đường vào pha wave, không chỉ đường bấm nút.
	prep_ready_changed.emit(false)
	current_phase       = GamePhase.WAVE
	active_shop_boost   = upcoming_shop_boost
	upcoming_shop_boost = false
	phase_changed.emit(current_phase)
	season_buffs_apply_requested.emit(wave_number)

	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("wave_start", -3.0)

	if wave_spawner and _grid_controller:
		wave_spawner.setup(_grid_controller.current_path_grid, get_parent())
		var enemy_count: int = wave_spawner.calculate_enemies_for_wave(wave_number, active_shop_boost)
		wave_spawner.start_wave(wave_number, enemy_count, active_shop_boost)
		_set_phase_message("%s | Wave %d — Spawning %d enemies" % [
			wave_spawner.get_season_name(wave_number), wave_number, enemy_count,
		])
		wave_started.emit(wave_number, enemy_count)

func _tick_wave() -> void:
	if not wave_spawner:
		return
	var s_name:   String = wave_spawner.get_season_name(wave_number)
	var spawned:  int    = wave_spawner.enemies_spawned
	var to_spawn: int    = wave_spawner.get_enemies_to_spawn()
	var alive:    int    = wave_spawner.enemies_alive
	var status:   String = "%s | Wave %d — %d/%d | Active %d" % [s_name, wave_number, spawned, to_spawn, alive]
	if active_shop_boost:
		status += " (Reinforced)"
	# Wave boss: nhắc người chơi mục tiêu thật sự là Rival King
	if wave_spawner.has_method("is_boss_wave") and wave_spawner.is_boss_wave(wave_number):
		var boss: Variant = wave_spawner.get("current_boss")
		if boss != null and is_instance_valid(boss):
			status = "☠ BOSS | " + status
	_set_phase_message(status)

func _emit_wave_intel() -> void:
	# game_map lắng nghe phase_changed và đọc wave_spawner trực tiếp để cập nhật HUD
	pass

func _set_phase_message(text: String) -> void:
	if phase_message != text:
		phase_message = text
		phase_message_changed.emit(text)
