# res://scripts/ui/game_hud.gd
extends CanvasLayer

signal tower_selected(tower_stats: TowerStats)
## Người chơi muốn ném bình ở ô túi `slot` — game_map bật vòng ngắm 3D.
signal potion_aim_requested(slot: int)
## Người chơi huỷ ngắm từ phía HUD (phím ESC / bấm lại đúng ô đang ngắm).
signal potion_aim_cancelled

@onready var tower_container = $Control/RightPanel/VBoxContainer/TowerContainer
@onready var label_health = $Control/VBoxContainer/LabelHealth
@onready var label_gold = $Control/VBoxContainer/LabelGold
@onready var label_decree = $Control/VBoxContainer/LabelRoyalDecree
@onready var label_favor = $Control/VBoxContainer/LabelKingFavor
@onready var label_territory = $Control/VBoxContainer/LabelTerritories
@onready var label_phase = $Control/VBoxContainer/LabelPhase
@onready var shop_panel = $Control/ShopPanel
@onready var shop_list = shop_panel.get_node("VBoxContainer/ShopList") as VBoxContainer
@onready var shop_next_wave_button = shop_panel.get_node("VBoxContainer/ButtonNextWave") as Button
@onready var shop_status_label = shop_panel.get_node("VBoxContainer/LabelStatus") as Label
@onready var meta_shop_button = shop_panel.get_node("VBoxContainer/ButtonOpenMetaShop") as Button

@onready var shop_popup = $Control/ShopPopup as PopupPanel
@onready var shop_popup_title = shop_popup.get_node("PanelContainer/VBoxContainer/LabelShopPopupTitle") as Label
@onready var shop_popup_message = shop_popup.get_node("PanelContainer/VBoxContainer/LabelShopPopupMessage") as Label
@onready var shop_popup_open_meta_button = shop_popup.get_node("PanelContainer/VBoxContainer/HBoxButtons/ButtonShopPopupOpen") as Button
@onready var shop_popup_close_button = shop_popup.get_node("PanelContainer/VBoxContainer/HBoxButtons/ButtonShopPopupClose") as Button

@onready var meta_shop_popup = $Control/MetaShopPopup as PopupPanel
@onready var meta_shop_list = meta_shop_popup.get_node("PanelContainer/VBoxContainer/MetaShopList") as VBoxContainer
@onready var meta_shop_status_label = meta_shop_popup.get_node("PanelContainer/VBoxContainer/LabelMetaStatus") as Label
@onready var meta_shop_close_button = meta_shop_popup.get_node("PanelContainer/VBoxContainer/HBoxMetaButtons/ButtonMetaShopClose") as Button

@onready var label_king_name = $Control/RightPanel/VBoxContainer/LabelKingName
@onready var label_ability_info = $Control/RightPanel/VBoxContainer/LabelAbilityInfo
@onready var btn_king_ability = $Control/RightPanel/VBoxContainer/ButtonKingAbility

var shop_manager: ShopPanelManager
var meta_shop_manager: MetaShopManager

# ── Territory section ─────────────────────────────────────────────────────────
var _territory_container: VBoxContainer = null

# ── Dismiss section ───────────────────────────────────────────────────────────
var _dismiss_container: VBoxContainer = null

# ── Tower info panel ──────────────────────────────────────────────────────────
# Thân ở scripts/ui/hud/hud_tower_panel.gd — HUD chỉ uỷ quyền (cuối file).
var _tower_panel: HudTowerPanel = null

# ── Prep countdown (large center-top display) ─────────────────────────────────
var _countdown_label: Label = null

# ── Wave banner (chữ lớn giữa màn hình khi wave bắt đầu) ──────────────────────
var _wave_banner: Label = null
var _wave_banner_tween: Tween = null

# ── Combo meter (chuỗi tiêu diệt liên tục — signal combo_changed) ─────────────
var _combo_panel: PanelContainer = null
var _combo_label: Label = null
var _combo_tween: Tween = null

# ── Gold flash (nháy xanh khi vàng tăng) ──────────────────────────────────────
var _last_gold_value: int = -1
var _gold_flash_tween: Tween = null

# ── Stats panel (khối đá bọc HP/Gold/RD ở góc trên-trái) ──────────────────────
## PanelContainer bọc VBoxContainer gốc trong .tscn — tạo bằng code để không
## phải sửa scene. Cũng là node được shake khi mất HP.
var _stats_holder: PanelContainer = null
var _stats_vbox: VBoxContainer = null
var _hp_bar: ProgressBar = null
var _rd_bar: ProgressBar = null
var _last_health_value: int = -1
var _max_health_seen: int = 1
var _wave_banner_panel: PanelContainer = null


## Ngưỡng đổi màu combo meter: mult → màu.
const COMBO_TIERS: Array = [
	{"mult": 1.50, "color": Color(1.00, 0.42, 0.12, 1.0)},   # đỏ cam
	{"mult": 1.25, "color": Color(1.00, 0.80, 0.18, 1.0)},   # vàng
	{"mult": 1.10, "color": Color(0.40, 0.88, 0.50, 1.0)},   # xanh
]

# ── Pause / ESC menu ──────────────────────────────────────────────────────────
var _pause_overlay: ColorRect = null
var _esc_menu: PanelContainer = null
var _settings_panel: PanelContainer = null
var _is_paused: bool = false

# ── Điều khiển tốc độ game (cụm nút góc dưới-phải) ────────────────────────────
## Panel + nút phải PROCESS_MODE_ALWAYS, nếu không sẽ bấm không được lúc pause.
var _speed_panel: PanelContainer = null
var _pause_btn: Button = null
## Button tương ứng từng mốc trong GameManager.SPEED_STEPS (1× / 2× / 3×).
var _speed_buttons: Array[Button] = []

## Mốc tốc độ dự phòng khi GameManagerSingleton vắng mặt.
const FALLBACK_SPEED_STEPS: Array[float] = [1.0, 2.0, 3.0]

# ── Boss bar + boss intro ─────────────────────────────────────────────────────
# Thân nằm ở scripts/ui/hud/hud_boss.gd — HUD chỉ uỷ quyền (cuối file).
var _boss: HudBoss = null

const BASE_TOWER_RESOURCES: Array[String] = [
	"res://res/towers/pawn.tres",
	"res://res/towers/knight.tres",
	"res://res/towers/rook.tres",
	"res://res/towers/bishop.tres",
	"res://res/towers/queen.tres",
	"res://res/towers/commander.tres",
	"res://res/towers/crossbowman.tres",
	"res://res/towers/warlock.tres",
	"res://res/towers/catapult.tres",
	"res://res/towers/dark_mage.tres",
]

# ── Màu sắc HUD ──────────────────────────────────────────────────────────────
# Bảng màu nằm ở UIStyle (nguồn DUY NHẤT) — dưới đây chỉ là bí danh giữ tên cũ
# để không phải sửa hàng trăm call site. Component HUD tách ra dùng thẳng UIStyle.
const C_BG        := UIStyle.HUD_BG          # nền panel chính
const C_BG_DARK   := UIStyle.HUD_BG_DARK     # nền đậm hơn
const C_BORDER    := UIStyle.HUD_BORDER      # viền vàng cổ
const C_BORDER_HI := UIStyle.HUD_BORDER_HI   # viền vàng sáng
const C_GOLD      := UIStyle.GOLD            # chữ vàng
const C_WHITE     := UIStyle.TEXT            # chữ trắng kem
const C_DIM       := UIStyle.TEXT_DIM        # chữ mờ
const C_GREEN     := UIStyle.GREEN           # giá trị tốt
const C_RED       := UIStyle.RED             # cảnh báo
const C_BLUE      := UIStyle.BLUE            # decree

# Màu theo loại shop item
const ITEM_COLOR := {
	"TROOP":     Color(0.30, 0.60, 1.00, 1.0),
	"UPGRADE":   Color(1.00, 0.70, 0.10, 1.0),
	"TERRITORY": Color(0.30, 0.80, 0.40, 1.0),
	"DISMISS":   Color(0.80, 0.30, 0.30, 1.0),
}

# ── Helpers StyleBox — wrapper mỏng quanh UIStyle ─────────────────────────────
# Giữ tên hàm cũ để không phải sửa hết call site, nhưng thân đã chuyển sang
# UIStyle nên mọi panel/nút giờ đều có bevel + shadow (khối 3D) thật.

## Panel có khối: viền đáy dày + shadow lệch. Vẫn trả StyleBoxFlat vì một số
## call site còn chỉnh trực tiếp border_color / border_width.
func _make_panel_style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	return UIStyle.flat(bg, border, radius)

## Panel dạng card trong list dọc — bóng nhẹ hơn để không đè lên card kế tiếp.
func _make_card_style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	return UIStyle.flat_card(bg, border, radius)

func _make_btn_style(bg: Color, border: Color, radius: int = 3) -> StyleBoxFlat:
	var s := UIStyle.flat(bg, border, radius, 3)
	s.content_margin_left   = 8.0
	s.content_margin_right  = 8.0
	s.content_margin_top    = 5.0
	s.content_margin_bottom = 5.0
	return s

func _style_label(lbl: Label, size: int, color: Color) -> void:
	UIStyle.body(lbl, size, color)

## Nút: dùng texture 9-patch nếu có, nhuộm theo accent, kèm hover-lift + SFX.
func _style_button(btn: Button, bg: Color, border: Color, text_color: Color, size: int = 13) -> void:
	if btn == null:
		return
	UIStyle.apply_button(btn, size, text_color)
	# Nhuộm lại theo accent gọi tới (giữ ý nghĩa màu cũ: xanh = xác nhận, đỏ = nguy hiểm)
	var normal := btn.get_theme_stylebox("normal")
	if normal is StyleBoxFlat:
		var fn := normal as StyleBoxFlat
		fn.bg_color = bg
		fn.border_color = border
	elif normal is StyleBoxTexture:
		(normal as StyleBoxTexture).modulate_color = border.lightened(0.30)
	var hover := btn.get_theme_stylebox("hover")
	if hover is StyleBoxFlat:
		var fh := hover as StyleBoxFlat
		fh.bg_color = bg.lightened(0.18)
		fh.border_color = border.lightened(0.25)
	elif hover is StyleBoxTexture:
		(hover as StyleBoxTexture).modulate_color = border.lightened(0.55)
	var pressed := btn.get_theme_stylebox("pressed")
	if pressed is StyleBoxFlat:
		var fp := pressed as StyleBoxFlat
		fp.bg_color = bg.darkened(0.22)
		fp.border_color = border

# ── Helpers SFX ───────────────────────────────────────────────────────────────
## Phát SFX qua autoload AudioManagerSingleton — an toàn khi autoload vắng mặt.
func _play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	UIStyle.play_sfx(sfx_name, volume_db, pitch_scale)

## Gắn tiếng ui_click. UIStyle.apply_button đã tự wire nên hàm này chỉ còn tác
## dụng cho button chưa qua apply_button — idempotent, không phát 2 tiếng.
func _wire_button_sfx(btn: Button) -> void:
	if btn == null or UIStyle.has_click_sfx(btn):
		return
	btn.set_meta("_ui_click_sfx", true)
	btn.pressed.connect(func(): _play_sfx("ui_click"))

# ── Inits ─────────────────────────────────────────────────────────────────────
func _ready():
	# CanvasLayer phải process ngay cả khi game paused để nhận input
	process_mode = Node.PROCESS_MODE_ALWAYS

	if shop_popup:
		shop_popup.hide()
	if meta_shop_popup:
		meta_shop_popup.hide()
	_wrap_stats_panel()
	_apply_hud_styles()
	_build_status_bars()
	shop_panel.visible = false
	if btn_king_ability:
		btn_king_ability.pressed.connect(_on_king_ability_pressed)
		_wire_button_sfx(btn_king_ability)
	_setup_shop()
	if meta_shop_button:
		meta_shop_button.visible = false
	_refresh_tower_buttons()
	_build_right_panel_extensions()
	_tower_panel = HudTowerPanel.attach(self)
	_build_pause_ui()
	_build_speed_controls()
	_boss = HudBoss.attach(self)
	_build_countdown_label()
	_build_wave_banner()
	_build_combo_meter()
	_potions = HudPotionBag.attach(self)
	_relics = HudRelicBar.attach(self)
	_connect_gameplay_signals()
	# Deferred: game_map tạo PhaseController trong _ready của nó (có thể chạy
	# SAU _ready của HUD) — kết nối trễ + retry để không phụ thuộc thứ tự.
	call_deferred("_connect_wave_banner_signal")

## Phím đang gõ vào ô nhập liệu thì HUD KHÔNG được cướp — hiện chưa có LineEdit
## nào nhưng giữ guard để phím tắt không phá tính năng thêm sau này.
func _is_typing_in_text_field() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var focused := vp.gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_typing_in_text_field():
			return
		# Z/X/C = ném thuốc ở ô túi 1/2/3 (xử lý TRƯỚC pause/tốc độ để phím
		# thuốc không bị nhánh khác nuốt).
		var potion_slot: int = HudPotionBag.HOTKEYS.find(int(event.keycode))
		if potion_slot >= 0:
			if _potions: _potions.request_aim(potion_slot)
			get_viewport().set_input_as_handled()
			return
		# F1 = codex nguyên tố. Đặt sớm để nó mở/đóng được ở mọi trạng thái.
		if event.keycode == KEY_F1:
			toggle_codex()
			get_viewport().set_input_as_handled()
			return
		# ESC đóng codex trước khi tính tới menu tạm dừng.
		if event.keycode == KEY_ESCAPE and is_codex_open():
			toggle_codex()
			get_viewport().set_input_as_handled()
			return
		# ESC khi đang ngắm thuốc = huỷ ngắm, KHÔNG mở menu tạm dừng.
		if event.keycode == KEY_ESCAPE and is_potion_aiming():
			cancel_potion_aim()
			get_viewport().set_input_as_handled()
			return
		# Space = tạm dừng/tiếp tục; 1/2/3 = đặt tốc độ trực tiếp
		if event.keycode == KEY_SPACE:
			if _esc_menu and _esc_menu.visible:
				return
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			var step_index: int = event.keycode - KEY_1
			_apply_speed_index(step_index)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_P:
			if _esc_menu and _esc_menu.visible:
				return  # ESC menu đang mở, P không làm gì
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if _settings_panel and _settings_panel.visible:
				_settings_panel.visible = false
				get_viewport().set_input_as_handled()
			elif _esc_menu and _esc_menu.visible:
				_close_esc_menu()
				get_viewport().set_input_as_handled()
			else:
				_open_esc_menu()
				get_viewport().set_input_as_handled()

# ── Pause ─────────────────────────────────────────────────────────────────────
func _toggle_pause() -> void:
	if _is_paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	# Vòng ngắm thuốc cập nhật trong _process của game_map (đứng yên khi pause)
	# → thoát chế độ ngắm trước, tránh để lại vòng tròn và con trỏ chữ thập.
	if is_potion_aiming():
		cancel_potion_aim()
	_is_paused = true
	# Đi qua GameManager để mọi hệ khác đọc is_paused() thấy cùng một trạng thái.
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_method("set_paused"):
		gm.set_paused(true)
	else:
		get_tree().paused = true
	if _pause_overlay:
		_pause_overlay.visible = true
	_refresh_speed_controls()

func _resume_game() -> void:
	_is_paused = false
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_method("set_paused"):
		gm.set_paused(false)
	else:
		get_tree().paused = false
	if _pause_overlay:
		_pause_overlay.visible = false
	_refresh_speed_controls()
	_close_esc_menu()

func _open_esc_menu() -> void:
	if not _is_paused:
		_pause_game()
	if _esc_menu:
		_esc_menu.visible = true
		UIStyle.pop_in(_esc_menu)

func _close_esc_menu() -> void:
	if _esc_menu:
		_esc_menu.visible = false
	if _settings_panel:
		_settings_panel.visible = false
	# Chỉ resume nếu không còn menu nào mở
	if _is_paused:
		_resume_game()

# ── Điều khiển tốc độ game ────────────────────────────────────────────────────
## Cache mốc tốc độ đọc từ GameManager — chỉ dò một lần, tránh lấy constant map
## mỗi lần refresh.
var _speed_steps_cache: Array[float] = []
## Index nút tốc độ đang sáng (-1 = chưa xác định) — dùng để chỉ pulse khi đổi.
var _active_speed_index: int = -1

## Danh sách mốc tốc độ lấy từ GameManager.SPEED_STEPS.
## Constant KHÔNG nằm trong property list nên phải đọc qua script constant map;
## thiếu autoload / thiếu constant thì dùng FALLBACK_SPEED_STEPS.
func _speed_steps() -> Array[float]:
	if not _speed_steps_cache.is_empty():
		return _speed_steps_cache
	var typed: Array[float] = []
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm != null:
		var scr := gm.get_script() as Script
		if scr != null:
			var consts: Dictionary = scr.get_script_constant_map()
			var steps: Variant = consts.get("SPEED_STEPS", null)
			if steps is Array:
				for s in (steps as Array):
					if s is float or s is int:
						typed.append(float(s))
	if typed.is_empty():
		for s in FALLBACK_SPEED_STEPS:
			typed.append(s)
	_speed_steps_cache = typed
	return _speed_steps_cache

func _current_game_speed() -> float:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		var v = gm.get("game_speed")
		if v is float or v is int:
			return float(v)
	return Engine.time_scale

## Cụm nút góc dưới-phải: [⏸] [1×] [2×] [3×]. Đặt lệch trái 172 px để không
## chồng lên RightPanel (rộng 160 px, bám mép phải toàn chiều cao).
func _build_speed_controls() -> void:
	var root_ctrl := get_node_or_null("Control") as Control
	if root_ctrl == null:
		return
	_speed_panel = PanelContainer.new()
	_speed_panel.name = "SpeedControls"
	_speed_panel.anchor_left   = 1.0
	_speed_panel.anchor_right  = 1.0
	_speed_panel.anchor_top    = 1.0
	_speed_panel.anchor_bottom = 1.0
	_speed_panel.offset_left   = -390
	_speed_panel.offset_right  = -172
	_speed_panel.offset_top    = -64
	_speed_panel.offset_bottom = -14
	_speed_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_speed_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	# BẮT BUỘC: không có dòng này thì cụm nút chết cứng khi get_tree().paused
	_speed_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	UIStyle.apply_panel(_speed_panel, "stone")
	UIStyle.set_pad(_speed_panel, 5)
	root_ctrl.add_child(_speed_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_speed_panel.add_child(row)

	_pause_btn = _make_speed_button("⏸", "Tạm dừng / Tiếp tục  (Space)")
	_pause_btn.pressed.connect(_toggle_pause)
	row.add_child(_pause_btn)

	_speed_buttons.clear()
	var steps := _speed_steps()
	for i in steps.size():
		var speed_value: float = steps[i]
		var btn := _make_speed_button("%d×" % int(round(speed_value)),
			"Tốc độ %d×  (phím %d)" % [int(round(speed_value)), i + 1])
		# Click nút: cho phép nhảy vòng khi bấm đúng nút đang sáng
		btn.pressed.connect(_apply_speed_index.bind(i, true))
		row.add_child(btn)
		_speed_buttons.append(btn)

	_refresh_speed_controls()
	# pop_in (không phải slide_in): panel neo theo anchor, tween "position" sẽ
	# ghim nó về (0,0) khi layout chưa được sort xong.
	UIStyle.pop_in(_speed_panel, 0.10)

func _make_speed_button(txt: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.tooltip_text = tip
	btn.custom_minimum_size = Vector2(44, 38)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	# Không giữ focus → Space/1/2/3 không bị nút "nuốt" qua ui_accept
	btn.focus_mode = Control.FOCUS_NONE
	UIStyle.apply_button(btn, 15, C_WHITE)
	return btn

## Đặt tốc độ theo index trong SPEED_STEPS.
## [param allow_cycle] = true (click chuột): bấm đúng nút đang sáng thì nhảy
## vòng sang mốc kế tiếp — cụm nút vừa là chọn trực tiếp vừa là nút đổi vòng.
## Phím 1/2/3 truyền false để luôn đặt đúng mốc mình gõ.
func _apply_speed_index(index: int, allow_cycle: bool = false) -> void:
	var steps := _speed_steps()
	if index < 0 or index >= steps.size():
		return
	var gm = get_node_or_null("/root/GameManagerSingleton")
	var target: float = steps[index]
	var is_active: bool = is_equal_approx(_current_game_speed(), target)
	if gm and gm.has_method("set_game_speed"):
		if allow_cycle and is_active and gm.has_method("cycle_game_speed"):
			gm.cycle_game_speed()
		else:
			gm.set_game_speed(target)
	else:
		push_warning("game_hud: thiếu GameManagerSingleton — đặt Engine.time_scale trực tiếp.")
		Engine.time_scale = maxf(0.25, target)
	_refresh_speed_controls()

## Đồng bộ hiển thị: nút tốc độ đang chọn nhuộm vàng, còn lại xám; nút pause
## đổi glyph ⏸ ↔ ▶ theo get_tree().paused.
func _refresh_speed_controls() -> void:
	if is_instance_valid(_pause_btn):
		var paused: bool = _is_paused
		if is_inside_tree():
			paused = get_tree().paused
		_pause_btn.text = "▶" if paused else "⏸"
		if paused:
			UIStyle.apply_button_accent(_pause_btn, C_GREEN, 15)
		else:
			UIStyle.apply_button(_pause_btn, 15, C_WHITE)
	var steps := _speed_steps()
	var current := _current_game_speed()
	var new_active := -1
	for i in _speed_buttons.size():
		var btn := _speed_buttons[i]
		if not is_instance_valid(btn) or i >= steps.size():
			continue
		var active := is_equal_approx(current, steps[i])
		if active:
			new_active = i
			UIStyle.apply_button_accent(btn, C_GOLD, 16)
			# Chỉ pulse khi VỪA đổi mốc — refresh do pause/resume không nảy nút
			if _active_speed_index != i:
				UIStyle.pulse(btn, 1.14)
		else:
			UIStyle.apply_button(btn, 15, C_DIM)
	_active_speed_index = new_active

## GameManager đổi tốc độ từ nơi khác (perk, cutscene…) → HUD tự cập nhật.
func _on_game_speed_changed(_new_speed: float) -> void:
	_refresh_speed_controls()

# ── Build pause UI ────────────────────────────────────────────────────────────
func _build_countdown_label() -> void:
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_countdown_label = Label.new()
	_countdown_label.name = "PrepCountdownLabel"
	_countdown_label.anchor_left   = 0.5
	_countdown_label.anchor_right  = 0.5
	_countdown_label.anchor_top    = 0.0
	_countdown_label.anchor_bottom = 0.0
	_countdown_label.offset_left   = -80
	_countdown_label.offset_right  = 80
	_countdown_label.offset_top    = 54
	_countdown_label.offset_bottom = 150
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	UIStyle.title(_countdown_label, 78, C_GOLD)
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_label.visible = false
	root_ctrl.add_child(_countdown_label)

## Đếm ngược prep: số nhảy + pulse mỗi giây → tạo nhịp căng thẳng.
var _last_countdown_value: int = -1

func update_prep_countdown(seconds: int) -> void:
	if not _countdown_label:
		return
	if seconds <= 0:
		_countdown_label.visible = false
		_last_countdown_value = -1
		return
	_countdown_label.visible = true
	_countdown_label.text = str(seconds)
	# Đổi màu khi còn ít thời gian
	if seconds <= 3:
		_countdown_label.add_theme_color_override("font_color", C_RED)
	elif seconds <= 5:
		_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1.0))
	else:
		_countdown_label.add_theme_color_override("font_color", C_GOLD)
	if seconds != _last_countdown_value:
		_last_countdown_value = seconds
		UIStyle.pulse(_countdown_label, 1.22 if seconds <= 3 else 1.10)

# ── Wave Banner ───────────────────────────────────────────────────────────────
## Ribbon đá nhuộm đỏ máu + chữ vàng outline dày, thay chữ trơn giữa màn hình.
func _build_wave_banner() -> void:
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_wave_banner_panel = PanelContainer.new()
	_wave_banner_panel.name = "WaveBannerRibbon"
	_wave_banner_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_wave_banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_banner_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_wave_banner_panel.offset_left = -290
	_wave_banner_panel.offset_right = 290
	_wave_banner_panel.offset_top = -62
	_wave_banner_panel.offset_bottom = 62
	_wave_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_banner_panel.add_theme_stylebox_override(
		"panel", UIStyle.panel_tinted("stone", UIStyle.BLOOD))
	UIStyle.pixel_filter(_wave_banner_panel)
	_wave_banner_panel.visible = false
	root_ctrl.add_child(_wave_banner_panel)

	_wave_banner = Label.new()
	_wave_banner.name = "WaveBanner"
	_wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.title(_wave_banner, 58, C_GOLD)
	_wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_banner_panel.add_child(_wave_banner)

## HUD tự kết nối tới game_map.phase_controller.wave_started — retry vài lần
## vì PhaseController được game_map tạo bằng code, có thể chưa tồn tại.
func _connect_wave_banner_signal(retries: int = 5) -> void:
	var map_node = _find_game_map()
	var pc = map_node.get("phase_controller") if map_node else null
	if pc == null or not (pc is Node) or not pc.has_signal("wave_started"):
		if retries > 0 and is_inside_tree():
			get_tree().create_timer(0.5).timeout.connect(
				func(): _connect_wave_banner_signal(retries - 1))
		return
	if not pc.is_connected("wave_started", _on_wave_started_banner):
		pc.connect("wave_started", _on_wave_started_banner)

## "⚔ WAVE N ⚔" giữa màn hình: ribbon trượt từ trên xuống + pulse → giữ → fade.
func _on_wave_started_banner(wave_number: int, _enemy_count: int) -> void:
	if not _wave_banner or not _wave_banner_panel:
		return
	_play_sfx("wave_start")
	_wave_banner.text = "⚔  WAVE %d  ⚔" % wave_number
	var banner := _wave_banner_panel
	UIStyle.center_pivot(banner)
	if _wave_banner_tween:
		_wave_banner_tween.kill()
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.72, 0.72)
	var start_top := banner.offset_top
	var start_bottom := banner.offset_bottom
	banner.offset_top = start_top - 90.0
	banner.offset_bottom = start_bottom - 90.0
	_wave_banner_tween = create_tween()
	_wave_banner_tween.set_parallel(true)
	_wave_banner_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_wave_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.28)
	_wave_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.36)
	_wave_banner_tween.tween_property(banner, "offset_top", start_top, 0.34)
	_wave_banner_tween.tween_property(banner, "offset_bottom", start_bottom, 0.34)
	_wave_banner_tween.set_parallel(false)
	_wave_banner_tween.tween_callback(func(): UIStyle.pulse(banner, 1.07))
	_wave_banner_tween.tween_interval(1.25)
	_wave_banner_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_wave_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.40)
	_wave_banner_tween.tween_callback(func():
		if is_instance_valid(banner):
			banner.visible = false)

# ── Biome (hệ đa môi trường) ──────────────────────────────────────────────────
# Banner giữa màn hình khi vào vùng mới + chỉ báo thường trực trong stats panel.
# Mọi dữ liệu đọc qua GameManagerSingleton.biome_changed (guard has_signal) nên
# HUD hoạt động bình thường kể cả khi BiomeLibrary/BiomeEffects chưa tồn tại.

## Tên tiếng Việt dự phòng khi spec thiếu field `name` (hoặc chưa có
## BiomeLibrary) — HUD không bao giờ phải hiện id thô.
const BIOME_FALLBACK_NAMES := {
	"wasteland": "Hoang Thổ",
	"tundra":    "Băng Nguyên",
	"volcanic":  "Vùng Hỏa Diệm",
	"swamp":     "Đầm Lầy Độc",
	"verdant":   "Lục Địa Xanh",
}

# Banner treo SAT DINH man (duoi dai thong tin wave), KHONG o giua man: o giua no
# de len header shop va de len tieu de draft perk — hai thu deu can doc duoc.
const BIOME_BANNER_TOP:    float = -472.0
const BIOME_BANNER_BOTTOM: float = -378.0
const BIOME_BANNER_HOLD:   float = 1.30    # tổng thời lượng ≈ 2s kể cả in/out
const BIOME_TINT := Color(0.176, 0.290, 0.118, 1.0)   # xanh rêu (UIStyle.MOSS)

var _biome_banner_panel: PanelContainer = null
var _biome_banner_title: Label = null
var _biome_banner_desc:  Label = null
var _biome_banner_tween: Tween = null
var _biome_label: Label = null

func _ensure_biome_banner() -> void:
	if is_instance_valid(_biome_banner_panel):
		return
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_biome_banner_panel = PanelContainer.new()
	_biome_banner_panel.name = "BiomeBannerRibbon"
	_biome_banner_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_biome_banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_biome_banner_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_biome_banner_panel.offset_left   = -300
	_biome_banner_panel.offset_right  = 300
	_biome_banner_panel.offset_top    = BIOME_BANNER_TOP
	_biome_banner_panel.offset_bottom = BIOME_BANNER_BOTTOM
	_biome_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_banner_panel.add_theme_stylebox_override(
		"panel", UIStyle.panel_tinted("stone", BIOME_TINT))
	UIStyle.pixel_filter(_biome_banner_panel)
	_biome_banner_panel.visible = false
	root_ctrl.add_child(_biome_banner_panel)

	var vbox := VBoxContainer.new()
	vbox.name = "BiomeBannerBox"
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_banner_panel.add_child(vbox)

	_biome_banner_title = Label.new()
	_biome_banner_title.name = "BiomeBannerTitle"
	_biome_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_biome_banner_title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_biome_banner_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.title(_biome_banner_title, 40, C_GOLD)
	vbox.add_child(_biome_banner_title)

	_biome_banner_desc = Label.new()
	_biome_banner_desc.name = "BiomeBannerDesc"
	_biome_banner_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_biome_banner_desc.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_biome_banner_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_biome_banner_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.body(_biome_banner_desc, 14, C_WHITE)
	vbox.add_child(_biome_banner_desc)

## Banner "🌍 <tên vùng>" giữa màn hình ~2s khi bước vào vùng môi trường mới.
## Tên hàm CỐ ĐỊNH — hệ render biome gọi trực tiếp hàm này.
## Trượt từ trên xuống + pulse → giữ → fade, cùng ngôn ngữ với wave banner.
func show_biome_banner(biome_name: String, desc: String) -> void:
	_ensure_biome_banner()
	if not is_instance_valid(_biome_banner_panel):
		return
	var display_name := biome_name.strip_edges()
	if display_name == "":
		display_name = "Vùng Đất Vô Danh"
	_biome_banner_title.text = "🌍  %s" % display_name.to_upper()
	var subtitle := desc.strip_edges()
	_biome_banner_desc.text = subtitle
	_biome_banner_desc.visible = subtitle != ""
	_play_sfx("wave_start", -6.0)

	var banner := _biome_banner_panel
	UIStyle.center_pivot(banner)
	if _biome_banner_tween:
		_biome_banner_tween.kill()
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.78, 0.78)
	# Luôn khởi động từ offset CỐ ĐỊNH (không đọc offset hiện tại) — gọi lại
	# lúc tween cũ đang chạy cũng không làm banner trôi dần.
	banner.offset_top    = BIOME_BANNER_TOP - 70.0
	banner.offset_bottom = BIOME_BANNER_BOTTOM - 70.0
	_biome_banner_tween = create_tween()
	_biome_banner_tween.set_parallel(true)
	_biome_banner_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_biome_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.26)
	_biome_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.34)
	_biome_banner_tween.tween_property(banner, "offset_top", BIOME_BANNER_TOP, 0.32)
	_biome_banner_tween.tween_property(banner, "offset_bottom", BIOME_BANNER_BOTTOM, 0.32)
	_biome_banner_tween.set_parallel(false)
	_biome_banner_tween.tween_callback(func(): UIStyle.pulse(banner, 1.06))
	_biome_banner_tween.tween_interval(BIOME_BANNER_HOLD)
	_biome_banner_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_biome_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.38)
	_biome_banner_tween.tween_callback(func():
		if is_instance_valid(banner):
			banner.visible = false)

## Chỉ báo "🌍 <tên biome>" thường trực trong stats panel; tooltip liệt kê mod.
## Dùng _stats_vbox đã cache (VBoxContainer đã bị reparent vào StatsHolder).
func update_biome_indicator(biome_name: String, mod: Dictionary, desc: String = "") -> void:
	if not is_instance_valid(_biome_label):
		var stats_vbox := _stats_vbox
		if stats_vbox == null:
			stats_vbox = get_node_or_null("Control/VBoxContainer") as VBoxContainer
		if stats_vbox == null:
			push_warning("game_hud: không tìm được stats VBox cho chỉ báo biome.")
			return
		_biome_label = Label.new()
		_biome_label.name = "LabelBiome"
		UIStyle.body(_biome_label, 12, C_GREEN)
		_biome_label.mouse_filter = Control.MOUSE_FILTER_STOP
		stats_vbox.add_child(_biome_label)
	var display_name := biome_name.strip_edges()
	if display_name == "":
		display_name = "—"
	var new_text := "🌍 %s" % display_name
	var changed: bool = (_biome_label.text != new_text)
	_biome_label.text = new_text
	var lines: Array[String] = _biome_mod_lines(mod)
	var tooltip := "Vùng môi trường: %s" % display_name
	if desc.strip_edges() != "":
		tooltip += "\n%s" % desc.strip_edges()
	tooltip += "\n" + (" · ".join(lines) if not lines.is_empty() else "Không có ảnh hưởng đặc biệt.")
	_biome_label.tooltip_text = tooltip
	if changed:
		UIStyle.pulse(_biome_label, 1.18)

## Mod → danh sách mô tả ngắn tiếng Việt (bỏ qua giá trị trung tính).
func _biome_mod_lines(mod: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if mod.is_empty():
		return lines
	var enemy_speed := _biome_mod_num(mod, "enemy_speed_mult", 1.0)
	if not is_equal_approx(enemy_speed, 1.0):
		lines.append("Địch %s %d%%" % [
			"nhanh" if enemy_speed > 1.0 else "chậm",
			int(round(absf(enemy_speed - 1.0) * 100.0))])
	var enemy_hp := _biome_mod_num(mod, "enemy_hp_mult", 1.0)
	if not is_equal_approx(enemy_hp, 1.0):
		lines.append("Máu địch %s%d%%" % [
			"+" if enemy_hp > 1.0 else "-",
			int(round(absf(enemy_hp - 1.0) * 100.0))])
	var tower_dmg := _biome_mod_num(mod, "tower_dmg_pct", 0.0)
	if not is_zero_approx(tower_dmg):
		lines.append("Tháp %s%d%% sát thương" % [
			"+" if tower_dmg > 0.0 else "-",
			int(round(absf(tower_dmg) * 100.0))])
	var tower_spd := _biome_mod_num(mod, "tower_spd_delta", 0.0)
	if not is_zero_approx(tower_spd):
		lines.append("Tháp bắn %s %.2fs" % [
			"chậm" if tower_spd > 0.0 else "nhanh", absf(tower_spd)])
	var gold := int(round(_biome_mod_num(mod, "gold_per_kill", 0.0)))
	if gold != 0:
		lines.append("%+d vàng mỗi kill" % gold)
	var burn := _biome_mod_num(mod, "burn_mult", 1.0)
	if not is_equal_approx(burn, 1.0):
		lines.append("Thiêu đốt ×%.2f" % burn)
	return lines

## Đọc một hệ số từ mod — chấp nhận int/float, thiếu/sai kiểu thì lấy mặc định.
func _biome_mod_num(mod: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = mod.get(key, null)
	if value is float or value is int:
		return float(value)
	return fallback

## Tên hiển thị: ưu tiên spec.name, sau đó bảng dự phòng, cuối cùng là id thô.
func _biome_display_name(biome_id: String, spec: Dictionary) -> String:
	var spec_name: Variant = spec.get("name", "")
	if spec_name is String and (spec_name as String).strip_edges() != "":
		return str(spec_name)
	return str(BIOME_FALLBACK_NAMES.get(biome_id, biome_id))

func _on_biome_changed(biome_id: String, spec: Dictionary) -> void:
	var display_name := _biome_display_name(biome_id, spec)
	var desc := str(spec.get("desc", ""))
	var mod: Dictionary = {}
	var raw_mod: Variant = spec.get("mod", {})
	if raw_mod is Dictionary:
		mod = raw_mod
	# Mod đã chuẩn hoá/kẹp biên nằm ở GameManager — ưu tiên nó nếu có.
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		var applied: Variant = gm.get("active_biome_mod")
		if applied is Dictionary and not (applied as Dictionary).is_empty():
			mod = applied
	update_biome_indicator(display_name, mod, desc)

## Đồng bộ chỉ báo với state biome hiện tại của GameManager (dùng lúc khởi tạo).
func _refresh_biome_from_gm() -> void:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return
	var raw_id: Variant = gm.get("active_biome")
	if not (raw_id is String) or (raw_id as String) == "":
		return
	var raw_spec: Variant = gm.get("active_biome_spec")
	var spec: Dictionary = raw_spec if raw_spec is Dictionary else {}
	_on_biome_changed(raw_id as String, spec)

## Một dòng tóm tắt biome cho popup trinh sát — "" nếu không lấy được gì.
func _biome_intel_line(data: Dictionary) -> String:
	var display_name := str(data.get("biome_name", "")).strip_edges()
	var mod: Dictionary = {}
	var raw_mod: Variant = data.get("biome_mod", null)
	if raw_mod is Dictionary:
		mod = raw_mod
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		if display_name == "":
			var raw_spec: Variant = gm.get("active_biome_spec")
			var raw_id: Variant = gm.get("active_biome")
			var spec: Dictionary = raw_spec if raw_spec is Dictionary else {}
			var biome_id: String = raw_id if raw_id is String else ""
			display_name = _biome_display_name(biome_id, spec)
		if mod.is_empty():
			var applied: Variant = gm.get("active_biome_mod")
			if applied is Dictionary:
				mod = applied
	if display_name == "" or display_name == "—":
		return ""
	var lines: Array[String] = _biome_mod_lines(mod)
	if lines.is_empty():
		return "🌍 Vùng: %s" % display_name
	return "🌍 Vùng: %s  —  %s" % [display_name, " · ".join(lines)]

# ── Combo Meter ───────────────────────────────────────────────────────────────
func _build_combo_meter() -> void:
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_combo_panel = PanelContainer.new()
	_combo_panel.name = "ComboMeter"
	_combo_panel.anchor_left   = 0.5
	_combo_panel.anchor_right  = 0.5
	_combo_panel.anchor_top    = 0.0
	_combo_panel.anchor_bottom = 0.0
	_combo_panel.offset_left   = 150
	_combo_panel.offset_right  = 330
	_combo_panel.offset_top    = 8
	_combo_panel.offset_bottom = 50
	UIStyle.apply_panel(_combo_panel, "wood")
	_combo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_panel.visible = false
	root_ctrl.add_child(_combo_panel)
	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.title(_combo_label, 15, Color(1.0, 0.62, 0.20, 1.0))
	_combo_panel.add_child(_combo_label)

## Màu combo theo mốc nhân: 1.5+ đỏ cam · 1.25+ vàng · 1.1+ xanh · dưới đó xám.
func _combo_color(mult: float) -> Color:
	for tier in COMBO_TIERS:
		if mult >= float(tier["mult"]):
			var col: Color = tier["color"]
			return col
	return C_DIM

## Kết nối các signal gameplay từ GameManagerSingleton — guard has_signal vì
## signal có thể chưa tồn tại (agent khác thêm sau); thiếu thì bỏ qua yên lặng.
func _connect_gameplay_signals() -> void:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return
	if gm.has_signal("combo_changed") and not gm.is_connected("combo_changed", _on_combo_changed):
		gm.connect("combo_changed", _on_combo_changed)
	if gm.has_signal("run_ended") and not gm.is_connected("run_ended", _on_run_ended_sfx):
		gm.connect("run_ended", _on_run_ended_sfx)
	if gm.has_signal("biome_changed") and not gm.is_connected("biome_changed", _on_biome_changed):
		gm.connect("biome_changed", _on_biome_changed)
	if gm.has_signal("game_speed_changed") and not gm.is_connected("game_speed_changed", _on_game_speed_changed):
		gm.connect("game_speed_changed", _on_game_speed_changed)
	# Vào map mới luôn về 1× + bỏ pause treo từ scene trước
	if gm.has_method("reset_game_speed"):
		gm.reset_game_speed()
	_is_paused = false
	_refresh_speed_controls()
	# Biome có thể đã được áp TRƯỚC khi HUD kịp _ready → đọc state hiện tại một lần.
	_refresh_biome_from_gm()

## Hiện "Combo ×N" khi chuỗi ≥ 3, pulse mỗi lần đổi, fade khi đứt chuỗi.
func _on_combo_changed(count: int, mult: float) -> void:
	if not _combo_panel or not _combo_label:
		return
	if count < 3:
		if _combo_panel.visible:
			if _combo_tween:
				_combo_tween.kill()
			_combo_tween = create_tween()
			_combo_tween.tween_property(_combo_panel, "modulate:a", 0.0, 0.25)
			_combo_tween.tween_callback(func():
				if _combo_panel:
					_combo_panel.visible = false
					_combo_panel.modulate.a = 1.0)
		return
	var tier_color := _combo_color(mult)
	_combo_label.text = "🔥 Combo ×%d  (%.1f×)" % [count, mult]
	_combo_label.add_theme_color_override("font_color", tier_color)
	# Panel nhuộm theo mốc → cảm giác "nóng" dần lên
	_combo_panel.add_theme_stylebox_override(
		"panel", UIStyle.panel_tinted("wood", tier_color.darkened(0.45)))
	_combo_panel.visible = true
	_combo_panel.modulate.a = 1.0
	UIStyle.center_pivot(_combo_panel)
	if _combo_tween:
		_combo_tween.kill()
	_combo_panel.scale = Vector2(1.18, 1.18)
	_combo_tween = create_tween()
	_combo_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_combo_tween.tween_property(_combo_panel, "scale", Vector2.ONE, 0.22)

## SFX kết thúc run — chỉ phát âm thanh, KHÔNG đụng vào end screen (scene khác).
func _on_run_ended_sfx(is_victory: bool) -> void:
	_play_sfx("victory" if is_victory else "defeat")

func _build_pause_ui() -> void:
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return

	# Nền mờ toàn màn hình khi pause (P)
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0, 0, 0, 0.45)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.visible = false
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(_pause_overlay)

	var paused_lbl = Label.new()
	paused_lbl.text = "⏸  PAUSED"
	paused_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paused_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIStyle.title(paused_lbl, 52, Color(1, 1, 1, 0.78))
	paused_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(paused_lbl)

	# ESC menu panel
	_esc_menu = PanelContainer.new()
	_esc_menu.name = "EscMenu"
	_esc_menu.custom_minimum_size = Vector2(280, 0)
	_esc_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_esc_menu.offset_left  = -140
	_esc_menu.offset_right = 140
	_esc_menu.offset_top   = -150
	_esc_menu.offset_bottom = 150
	UIStyle.apply_panel(_esc_menu, "parchment")
	_esc_menu.visible = false
	_esc_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(_esc_menu)

	var menu_vbox = VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_theme_constant_override("separation", 10)
	_esc_menu.add_child(menu_vbox)

	var menu_title = Label.new()
	menu_title.text = "⚔  TẠM DỪNG"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(menu_title, 20, C_GOLD)
	menu_vbox.add_child(menu_title)

	menu_vbox.add_child(UIStyle.separator(C_BORDER))

	_add_menu_button(menu_vbox, "▶  Tiếp tục  (ESC)", func(): _close_esc_menu())
	_add_menu_button(menu_vbox, "⚙  Cài đặt", func(): _show_settings_panel())
	_add_menu_button(menu_vbox, "🏠  Menu chính", func(): _go_main_menu())
	_add_menu_button(menu_vbox, "✖  Thoát game", func(): get_tree().quit())

	# Settings inline panel
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.custom_minimum_size = Vector2(420, 0)
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_settings_panel.offset_left   = -210
	_settings_panel.offset_right  = 210
	_settings_panel.offset_top    = -200
	_settings_panel.offset_bottom = 200
	UIStyle.apply_panel(_settings_panel, "parchment")
	_settings_panel.visible = false
	_settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(_settings_panel)

	var sv = VBoxContainer.new()
	sv.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(sv)

	var stitle = Label.new()
	stitle.text = "⚙  CÀI ĐẶT"
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(stitle, 20, C_GOLD)
	sv.add_child(stitle)
	sv.add_child(UIStyle.separator(C_BORDER))

	var sm = get_node_or_null("/root/SettingsManagerSingleton")
	_add_settings_slider(sv, "Âm lượng Master", sm.master_volume if sm else 1.0, func(v: float):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_master_volume(v))
	_add_settings_slider(sv, "Âm nhạc", sm.music_volume if sm else 0.8, func(v: float):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_music_volume(v))
	_add_settings_slider(sv, "Hiệu ứng âm thanh", sm.sfx_volume if sm else 1.0, func(v: float):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_sfx_volume(v))

	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 12)
	sv.add_child(fs_row)
	var fs_lbl = Label.new()
	fs_lbl.text = "Toàn màn hình"
	fs_lbl.custom_minimum_size = Vector2(200, 0)
	UIStyle.body(fs_lbl, 14, C_WHITE)
	fs_row.add_child(fs_lbl)
	var fs_chk = CheckButton.new()
	fs_chk.button_pressed = sm.is_fullscreen if sm else false
	fs_chk.process_mode = Node.PROCESS_MODE_ALWAYS
	fs_chk.toggled.connect(func(v: bool):
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.set_fullscreen(v))
	fs_row.add_child(fs_chk)

	var save_btn = Button.new()
	save_btn.text = "💾  Lưu cài đặt"
	save_btn.custom_minimum_size = Vector2(180, 40)
	save_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	UIStyle.apply_button_accent(save_btn, C_GREEN, 14)
	save_btn.pressed.connect(func():
		var s = get_node_or_null("/root/SettingsManagerSingleton")
		if s: s.save_settings())
	sv.add_child(save_btn)

	_add_menu_button(sv, "← Quay lại", func(): _settings_panel.visible = false)

func _add_menu_button(parent: Control, txt: String, cb: Callable) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(230, 42)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	UIStyle.apply_button(btn, 15, C_WHITE)
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn

func _add_settings_slider(parent: VBoxContainer, lbl_text: String, init_val: float, cb: Callable) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var lbl = Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(180, 0)
	UIStyle.body(lbl, 13, C_WHITE)
	row.add_child(lbl)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = init_val
	slider.custom_minimum_size = Vector2(160, 0)
	slider.process_mode = Node.PROCESS_MODE_ALWAYS
	_style_slider(slider)
	row.add_child(slider)
	var pct = Label.new()
	pct.text = "%d%%" % int(init_val * 100)
	pct.custom_minimum_size = Vector2(42, 0)
	UIStyle.body(pct, 12, C_DIM)
	row.add_child(pct)
	slider.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v * 100)
		cb.call(v))

## Slider lõm (rãnh tối) + grabber vàng nổi — khớp ngôn ngữ khối của UI.
func _style_slider(slider: HSlider) -> void:
	if slider == null:
		return
	slider.add_theme_stylebox_override(
		"slider", UIStyle.flat_inset(Color(0.04, 0.04, 0.04, 0.95), Color(0, 0, 0, 0.8), 3))
	var grab := UIStyle.flat(C_BORDER_HI, C_GOLD, 3, 2)
	grab.content_margin_left = 0.0
	grab.content_margin_right = 0.0
	grab.content_margin_top = 0.0
	grab.content_margin_bottom = 0.0
	slider.add_theme_stylebox_override("grabber_area", grab)
	slider.add_theme_stylebox_override("grabber_area_highlight", UIStyle.flat(C_GOLD, C_WHITE, 3, 2))

func _show_settings_panel() -> void:
	if _settings_panel:
		_settings_panel.visible = true
		UIStyle.pop_in(_settings_panel)

func _go_main_menu() -> void:
	get_tree().paused = false
	_is_paused = false
	# Rời map: trả tốc độ về 1× để menu / scene sau không chạy nhanh bất thường
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_method("reset_game_speed"):
		gm.reset_game_speed()
	else:
		Engine.time_scale = 1.0
	var sm = get_node_or_null("/root/SceneManagerSingleton")
	if sm and sm.has_method("go_to_scene"):
		sm.go_to_scene("res://scenes/ui/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

## VBoxContainer stats trong .tscn là con trực tiếp của Control (không có panel)
## → UI trông phẳng. Bọc nó vào một PanelContainer đá bằng code (không sửa scene).
## Chạy TRƯỚC _apply_hud_styles. Các @onready label vẫn hợp lệ vì chúng chỉ đổi
## cha ở cấp trên chúng.
func _wrap_stats_panel() -> void:
	var root_ctrl := get_node_or_null("Control") as Control
	if root_ctrl == null:
		return
	var vb := root_ctrl.get_node_or_null("VBoxContainer") as VBoxContainer
	if vb == null:
		return
	_stats_vbox = vb
	if vb.get_parent() is PanelContainer:
		_stats_holder = vb.get_parent() as PanelContainer
		return

	_stats_holder = PanelContainer.new()
	_stats_holder.name = "StatsHolder"
	_stats_holder.custom_minimum_size = Vector2(196, 0)
	_stats_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var idx := vb.get_index()
	root_ctrl.remove_child(vb)
	_stats_holder.add_child(vb)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vb.add_theme_constant_override("separation", 4)
	root_ctrl.add_child(_stats_holder)
	root_ctrl.move_child(_stats_holder, idx)
	_stats_holder.custom_minimum_size = Vector2(RESOURCE_PANEL_WIDTH, 0)
	_stats_holder.position = Vector2(14, 12)
	# Chốt vị trí gốc cho shake để không bị lệch nếu shake xảy ra giữa slide_in
	_stats_holder.set_meta("_ui_shake_base", _stats_holder.position)
	UIStyle.apply_panel(_stats_holder, "wood")   # cùng chất liệu với cột King và shop
	UIStyle.slide_in(_stats_holder, Vector2(-220, 0), 0.34)

## Thêm ProgressBar lõm cho HP và Royal Decree (trước đây chỉ là số trơn).
func _build_status_bars() -> void:
	if _stats_vbox == null:
		return
	if _hp_bar == null and label_health != null:
		_hp_bar = UIStyle.make_bar(C_RED, 7)
		_hp_bar.name = "HealthBar"
		_stats_vbox.add_child(_hp_bar)
		_stats_vbox.move_child(_hp_bar, label_health.get_index() + 1)
	if _rd_bar == null and label_decree != null:
		_rd_bar = UIStyle.make_bar(C_BLUE, 7)
		_rd_bar.name = "DecreeBar"
		_stats_vbox.add_child(_rd_bar)
		_stats_vbox.move_child(_rd_bar, label_decree.get_index() + 1)
	# Xếp ngang + dải chip: gọi SAU khi bar tồn tại, vì hàng tài nguyên nhận
	# chính hai bar đó làm con.
	_build_resource_row()
	_build_chip_row()

func _apply_hud_styles() -> void:
	# ── Stats panel (trái trên) ──────────────────────────────────────────
	if _stats_holder:
		UIStyle.apply_panel(_stats_holder, "wood")   # cùng chất liệu với cột King và shop
	# Số HP/Gold/RD là "huy hiệu" → glyph outline dày; dòng phụ dùng body
	if label_health: UIStyle.glyph(label_health, 17, C_RED)
	if label_gold:   UIStyle.glyph(label_gold, 17, C_GOLD)
	if label_decree: UIStyle.glyph(label_decree, 15, C_BLUE)
	if label_favor:  UIStyle.body(label_favor, 12, Color(0.80, 0.70, 1.00, 1.0))
	if label_territory: UIStyle.body(label_territory, 12, C_GREEN)
	if label_phase:  UIStyle.body(label_phase, 12, C_DIM)

	# ── Right panel (King + kho quân) ─────────────────────────────────────
	var right_panel = get_node_or_null("Control/RightPanel")
	if right_panel is PanelContainer:
		UIStyle.apply_panel(right_panel, "wood")
		_fix_right_panel(right_panel as PanelContainer)
	# Header label trên RightPanel
	var rp_vbox = get_node_or_null("Control/RightPanel/VBoxContainer")
	if rp_vbox:
		rp_vbox.add_theme_constant_override("separation", 6)
		var header = rp_vbox.get_node_or_null("HeaderDeploy")
		if header is Label:
			UIStyle.title(header, 14, C_GOLD)

	# ── Shop panel ────────────────────────────────────────────────────────
	if shop_panel is PanelContainer:
		# "wood" chứ không "stone": shop là bảng hàng, cùng chất liệu với cột King
		# và túi thuốc. Hộp xám phẳng cũ trông như panel debug.
		UIStyle.apply_panel(shop_panel, "wood")
		UIStyle.set_pad(shop_panel, 10)
		_fix_shop_panel()
	if shop_status_label:
		UIStyle.body(shop_status_label, 12, C_DIM)
		shop_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shop_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var shop_vbox_node = shop_panel.get_node_or_null("VBoxContainer") if shop_panel else null
	if shop_vbox_node is VBoxContainer:
		(shop_vbox_node as VBoxContainer).add_theme_constant_override("separation", 8)

	# ── Next Wave button ──────────────────────────────────────────────────
	if shop_next_wave_button:
		UIStyle.apply_button_accent(shop_next_wave_button, C_GREEN, 15)
		shop_next_wave_button.text = "▶  NEXT WAVE"

	# ── Meta shop button ──────────────────────────────────────────────────
	if meta_shop_button:
		UIStyle.apply_button_accent(meta_shop_button, C_BLUE, 13)

	# ── King ability section ──────────────────────────────────────────
	if label_king_name:
		UIStyle.title(label_king_name, 14, C_GOLD)
		label_king_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_ability_info:
		UIStyle.body(label_ability_info, 10, C_DIM)
		label_ability_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if btn_king_ability:
		UIStyle.apply_button_accent(btn_king_ability, C_BLUE, 12)

	# ── Popup panel (shop popup / meta shop popup) ────────────────────────
	for popup_path in ["Control/ShopPopup/PanelContainer", "Control/MetaShopPopup/PanelContainer"]:
		var pc = get_node_or_null(popup_path)
		if pc is PanelContainer:
			UIStyle.apply_panel(pc, "parchment")
	if shop_popup_title:
		UIStyle.title(shop_popup_title, 20, C_GOLD)
		shop_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if shop_popup_message:
		UIStyle.body(shop_popup_message, 13, C_WHITE)
		shop_popup_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_popup_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if shop_popup_open_meta_button:
		UIStyle.apply_button_accent(shop_popup_open_meta_button, C_BLUE, 13)
	if shop_popup_close_button:
		UIStyle.apply_button(shop_popup_close_button, 13)
	if meta_shop_status_label:
		UIStyle.body(meta_shop_status_label, 12, C_DIM)
	if meta_shop_close_button:
		UIStyle.apply_button(meta_shop_close_button, 13)
	var meta_title = get_node_or_null("Control/MetaShopPopup/PanelContainer/VBoxContainer/LabelMetaShopTitle")
	if meta_title is Label:
		UIStyle.title(meta_title, 20, C_GOLD)
		(meta_title as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var meta_desc = get_node_or_null("Control/MetaShopPopup/PanelContainer/VBoxContainer/LabelMetaShopDescription")
	if meta_desc is Label:
		UIStyle.body(meta_desc, 12, C_DIM)

	# ── Shop title label ──────────────────────────────────────────────────
	var shop_title = shop_panel.get_node_or_null("VBoxContainer/LabelShopTitle") if shop_panel else null
	if shop_title is Label:
		UIStyle.title(shop_title, 20, C_GOLD)
		(shop_title as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(shop_title as Label).text = "⚒  CỬA HÀNG HOÀNG GIA"
		_frame_shop_header(shop_title as Label)

func _on_tower_button_pressed(stats: TowerStats):
	_play_sfx("ui_click")
	tower_selected.emit(stats)

# ── Shop panel visibility ──────────────────────────────────────────────────────
func show_shop_panel() -> void:
	if shop_panel:
		shop_panel.visible = true
		UIStyle.pop_in(shop_panel)
		# Card trong list "bày ra" lần lượt sau khi panel hiện
		var idx := 0
		for card in shop_list.get_children():
			if card is Control:
				UIStyle.pop_in(card as Control, 0.10 + idx * 0.04)
				idx += 1

func hide_shop_panel() -> void:
	if shop_panel:
		shop_panel.visible = false

# ── King ability ───────────────────────────────────────────────────────────────
func update_king_info(king_stats, king_mgr) -> void:
	if not king_stats:
		return
	if label_king_name:
		label_king_name.text = king_stats.king_name
	if label_ability_info:
		var cost_text = "%.0f RD" % king_stats.ability_decree_cost
		label_ability_info.text = "%s\n%s" % [king_stats.ability_name, cost_text]
	if btn_king_ability:
		var on_cooldown = king_mgr != null and king_mgr.has_method("is_ability_ready") and not king_mgr.is_ability_ready()
		var can_afford = king_mgr != null and king_mgr.can_afford(king_stats.ability_decree_cost)
		btn_king_ability.disabled = not can_afford or on_cooldown
		if on_cooldown and king_mgr.get("_ability_cooldown_remaining") != null:
			var cd = king_mgr._ability_cooldown_remaining
			btn_king_ability.text = "⏳ %.0fs" % cd
		else:
			# KHONG cat chuoi: `.left(10)` bien "Iron Decree" thanh "Iron Decre".
			# Cot phai rong 210px, font 12 du cho ten day du.
			btn_king_ability.text = "⚡ %s" % king_stats.ability_name

func _on_king_ability_pressed() -> void:
	var map_node = _find_game_map()
	if not map_node:
		return
	var km = map_node.get_node_or_null("KingManager")
	if km and km.has_method("use_ability"):
		var success = km.use_ability()
		if success:
			# execute_king_ability() is called via ability_activated signal → game_map._on_king_ability_activated
			_flash_ability_button()

func _flash_ability_button() -> void:
	if not btn_king_ability:
		return
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(btn_king_ability, "modulate", Color(1.5, 1.2, 0.3, 1.0), 0.15)
	tween.tween_property(btn_king_ability, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

# ── Shop setup ────────────────────────────────────────────────────────────────
func _setup_shop():
	var map_node = _find_game_map()
	if not map_node:
		return
	var manager = map_node.get_node_or_null("ShopManager") as ShopPanelManager
	if not manager:
		return
	shop_manager = manager

	var next_wave_callable = Callable(self, "_on_shop_next_wave_pressed")
	if not shop_next_wave_button.is_connected("pressed", next_wave_callable):
		shop_next_wave_button.pressed.connect(next_wave_callable)
		_wire_button_sfx(shop_next_wave_button)

	var hide_popup_callable = Callable(self, "hide_shop_popup")
	if not shop_popup_close_button.is_connected("pressed", hide_popup_callable):
		shop_popup_close_button.pressed.connect(hide_popup_callable)
		_wire_button_sfx(shop_popup_close_button)

	var open_meta_callable = Callable(self, "open_meta_shop")
	if not shop_popup_open_meta_button.is_connected("pressed", open_meta_callable):
		shop_popup_open_meta_button.pressed.connect(open_meta_callable)
		_wire_button_sfx(shop_popup_open_meta_button)

	var purchased_callable = Callable(self, "_on_shop_item_purchased")
	if not manager.shop_item_purchased.is_connected(purchased_callable):
		manager.shop_item_purchased.connect(purchased_callable)
	var failed_callable = Callable(self, "_on_shop_purchase_failed")
	if not manager.shop_purchase_failed.is_connected(failed_callable):
		manager.shop_purchase_failed.connect(failed_callable)
	var stock_callable = Callable(self, "_on_shop_unit_stock_changed")
	if not manager.unit_stock_changed.is_connected(stock_callable):
		manager.unit_stock_changed.connect(stock_callable)
	var offers_callable = Callable(self, "_on_shop_offers_refreshed")
	if not manager.shop_offers_refreshed.is_connected(offers_callable):
		manager.shop_offers_refreshed.connect(offers_callable)

	shop_status_label.text = ""

	# Inject gold label + roll button into shop panel VBox (above the list)
	var shop_vbox = shop_panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if shop_vbox:
		_inject_shop_header(shop_vbox)

	_refresh_shop_offers(manager.get_items())

func _on_shop_offers_refreshed(items: Array[ShopItemData]) -> void:
	_refresh_shop_offers(items)

func _refresh_shop_offers(items: Array[ShopItemData]) -> void:
	# remove_child TRƯỚC queue_free: _exit_tree của ModelIcon chạy ngay, giải phóng
	# hạn mức icon 3D để card mới vẫn được dùng model (queue_free chỉ chạy cuối frame).
	for child in shop_list.get_children():
		shop_list.remove_child(child)
		child.queue_free()
	if not items:
		return
	var i := 0
	for item in items:
		var card := _create_shop_item_card(item)
		shop_list.add_child(card)
		# Stagger pop-in → card "bày ra" lần lượt thay vì hiện cùng lúc
		UIStyle.pop_in(card, i * 0.04)
		i += 1
	# So the hang doi moi lan roll -> tinh lai chieu cao panel.
	_resize_shop_panel.call_deferred()

# ── Shop item card ────────────────────────────────────────────────────────────
## Card shop: khung rarity (ngoài) + panel gỗ (trong) + ModelIcon 3D xoay.
## Rarity suy từ giá — item càng đắt khung càng "xịn".
func _create_shop_item_card(item: ShopItemData) -> Control:
	var type_name = ShopItemData.ItemType.keys()[item.item_type] if item.item_type < ShopItemData.ItemType.size() else "TROOP"
	var accent = ITEM_COLOR.get(type_name, C_GOLD)
	var rarity := UIStyle.rarity_from_cost(item.cost, item.use_royal_decree)

	# Padding gọn (3/4 px) — ShopPanel chỉ cao 480 px, khung lồng khung mà để
	# padding mặc định thì chỉ vừa ~4 card.
	var boxes := UIStyle.framed_card(rarity, "wood", 3, 4)
	var container: PanelContainer = boxes[0]
	var inner: PanelContainer = boxes[1]
	container.custom_minimum_size = Vector2(0, 62)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	inner.add_child(hbox)

	# Icon: ưu tiên model 3D (ModelIcon tự fallback về texture 2D nếu thiếu .gltf
	# hoặc đã vượt trần MAX_LIVE_3D icon 3D cùng lúc)
	var model_id := _shop_item_model_id(item)
	if model_id != "":
		var icon := ModelIcon.new()
		icon.name = "ShopModelIcon"
		icon.set_icon_size(46)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon)
		icon.setup_by_id(model_id, item.icon)
	elif item.icon:
		var tex = TextureRect.new()
		tex.texture = item.icon
		tex.custom_minimum_size = Vector2(44, 44)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tex)

	# Text vbox
	var tvbox = VBoxContainer.new()
	tvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tvbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tvbox.add_theme_constant_override("separation", 2)
	hbox.add_child(tvbox)

	var name_lbl = Label.new()
	name_lbl.text = item.display_name
	UIStyle.body(name_lbl, 13, UIStyle.rarity_color(rarity).lightened(0.42))
	name_lbl.clip_text = true
	tvbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	var desc_short = item.description.substr(0, 48) + ("..." if item.description.length() > 48 else "")
	desc_lbl.text = desc_short
	UIStyle.body(desc_lbl, 10, C_DIM)
	tvbox.add_child(desc_lbl)

	# Cost + type tag
	var bottom_hbox = HBoxContainer.new()
	tvbox.add_child(bottom_hbox)

	var type_lbl = Label.new()
	type_lbl.text = "[%s]" % type_name.left(3)
	UIStyle.body(type_lbl, 10, accent)
	bottom_hbox.add_child(type_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	var cost_lbl = Label.new()
	if item.cost <= 0.0:
		cost_lbl.text = "FREE"
		UIStyle.glyph(cost_lbl, 13, C_GREEN)
	elif item.use_royal_decree:
		cost_lbl.text = "⚡ %.1f" % item.cost
		UIStyle.glyph(cost_lbl, 13, C_BLUE)
	else:
		cost_lbl.text = "◆ %.0f" % item.cost
		UIStyle.glyph(cost_lbl, 13, C_GOLD)
	bottom_hbox.add_child(cost_lbl)

	# Click → buy
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			UIStyle.flash_node(container)
			_on_shop_button_pressed(item.id)
	)
	UIStyle.make_click_target(container)  # cả mặt card ăn click, không chỉ viền
	UIStyle.hover_lift(container, 1.045)
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.tooltip_text = "%s\n[%s]%s" % [
		item.description,
		UIStyle.RARITY_NAMES_VI.get(rarity, rarity),
		("\nBuff: " + item.territory_buff_summary) if item.territory_buff_summary != "" else "",
	]
	return container

## Suy ra id model 3D cho một shop item (chỉ TROOP có model đơn vị).
func _shop_item_model_id(item: ShopItemData) -> String:
	if item.tower_stats != null and item.tower_stats.id != "":
		return item.tower_stats.id
	return ""

# ── Tower buttons ─────────────────────────────────────────────────────────────
func _refresh_tower_buttons():
	for child in tower_container.get_children():
		child.queue_free()
	if not shop_manager:
		return
	var stock_snapshot: Dictionary = shop_manager.get_unit_stock_items()
	for stats_id in stock_snapshot.keys():
		var amount: int = stock_snapshot[stats_id]
		if amount <= 0:
			continue
		var stats = shop_manager.get_tower_stats_by_id(stats_id)
		if stats:
			_create_tower_card(stats, amount)

## Card đơn vị trong kho (panel phải). Dùng icon 2D — các card này sống suốt ván
## nên KHÔNG tạo ModelIcon ở đây (bảo vệ hiệu năng SubViewport).
func _create_tower_card(stats: TowerStats, stock_count: int = 0) -> void:
	var is_limited = stock_count > 0
	var rarity := "rare" if is_limited else "common"

	# RightPanel chỉ rộng 160 px → padding phải rất gọn (2/3 px)
	var boxes := UIStyle.framed_card(rarity, "wood", 2, 3)
	var container: PanelContainer = boxes[0]
	var inner: PanelContainer = boxes[1]
	container.custom_minimum_size = Vector2(0, 50)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	inner.add_child(hbox)

	# Icon — fallback: load từ assets/towers/{id}.png nếu texture chưa set
	if stats.texture == null:
		var fallback = "res://assets/towers/%s.png" % stats.id
		if ResourceLoader.exists(fallback):
			stats.texture = load(fallback)
	if stats.texture:
		var tex = TextureRect.new()
		tex.texture = stats.texture
		tex.custom_minimum_size = Vector2(34, 34)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tex)

	# Info vbox
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = stats.name
	UIStyle.body(name_lbl, 13, UIStyle.rarity_color(rarity).lightened(0.45))
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var stats_row = HBoxContainer.new()
	vbox.add_child(stats_row)

	var decree_lbl = Label.new()
	decree_lbl.text = "⚡ %.0f" % stats.decree_cost
	UIStyle.glyph(decree_lbl, 12, C_BLUE)
	stats_row.add_child(decree_lbl)

	if is_limited:
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_row.add_child(spacer)
		var stock_lbl = Label.new()
		stock_lbl.text = "×%d" % stock_count
		UIStyle.glyph(stock_lbl, 12, C_GREEN)
		stats_row.add_child(stock_lbl)

	# Hover/click handling
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			UIStyle.flash_node(container)
			_on_tower_button_pressed(stats)
	)
	UIStyle.make_click_target(container)
	UIStyle.hover_lift(container, 1.05)
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.tooltip_text = "%s\nATK:%d  SPD:%.2fs  RNG:%d\nDeploy: %.0f RD" % [
		stats.description, stats.base_damage, stats.attack_speed, stats.attack_range, stats.decree_cost
	]
	tower_container.add_child(container)
	UIStyle.pop_in(container, 0.02 * tower_container.get_child_count())

func _get_current_tower_paths() -> Array[String]:
	var result = BASE_TOWER_RESOURCES.duplicate()
	if meta_shop_manager:
		for path in meta_shop_manager.get_unlocked_tower_paths():
			if not result.has(path):
				result.append(path)
	return result

# ── Territory / Right panel extensions ────────────────────────────────────────
const BIOME_NAMES := {
	"fire": "Hỏa Địa", "swamp": "Đầm Lầy", "ice": "Băng Nguyên",
	"forest": "Rừng Rậm", "desert": "Sa Mạc", "thunder": "Lôi Vực",
}

func _build_right_panel_extensions() -> void:
	var rp_vbox = get_node_or_null("Control/RightPanel/VBoxContainer")
	if not rp_vbox:
		return

	# --- Territory stock ---
	rp_vbox.add_child(UIStyle.separator(C_BORDER))
	var ter_header = Label.new()
	ter_header.text = "▣  LÃNH THỔ"
	UIStyle.title(ter_header, 13, C_GOLD)
	ter_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_vbox.add_child(ter_header)
	_territory_container = VBoxContainer.new()
	_territory_container.add_theme_constant_override("separation", 5)
	rp_vbox.add_child(_territory_container)

	# --- Dismiss stock ---
	rp_vbox.add_child(UIStyle.separator(C_BORDER))
	var dis_header = Label.new()
	dis_header.text = "🗡  GIẢI TÁN"
	UIStyle.title(dis_header, 13, C_GOLD)
	dis_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rp_vbox.add_child(dis_header)
	_dismiss_container = VBoxContainer.new()
	_dismiss_container.add_theme_constant_override("separation", 5)
	rp_vbox.add_child(_dismiss_container)
	refresh_dismiss_stock(0)

func refresh_territories(_biome_counts: Dictionary) -> void:
	pass  # Hiển thị trực tiếp trên bàn cờ qua visual 3D

func refresh_territory_stock(stock: Dictionary) -> void:
	if not _territory_container:
		return
	for child in _territory_container.get_children():
		child.queue_free()
	var has_any = false
	for biome_key in stock.keys():
		var count: int = stock.get(biome_key, 0)
		if count <= 0:
			continue
		has_any = true
		_create_territory_card(biome_key, count)
	if not has_any:
		var empty_lbl = Label.new()
		empty_lbl.text = "—"
		UIStyle.body(empty_lbl, 11, C_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_territory_container.add_child(empty_lbl)

func _create_territory_card(biome_key: String, count: int) -> void:
	var biome_name: String = BIOME_NAMES.get(biome_key, biome_key)
	var accent = Color(0.30, 0.80, 0.40, 1.0)  # xanh lá — territory

	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(0, 50)
	var card_style = _make_card_style(UIStyle.BG_WOOD, accent.darkened(0.25), 4)
	container.add_theme_stylebox_override("panel", card_style)
	UIStyle.pixel_filter(container)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	container.add_child(hbox)

	# Icon từ territory sprite
	var tex: Texture2D = null
	var tex_path = "res://assets/tiles/territory_%s.png" % biome_key
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path) as Texture2D
	else:
		var img = Image.load_from_file(ProjectSettings.globalize_path(tex_path))
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex:
		var icon = TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(32, 32)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon)

	# Tên + số lượng
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = biome_name
	UIStyle.body(name_lbl, 12, C_WHITE)
	vbox.add_child(name_lbl)

	var count_lbl = Label.new()
	count_lbl.text = "×%d còn lại" % count
	UIStyle.body(count_lbl, 10, C_GREEN)
	vbox.add_child(count_lbl)

	# Click → chọn territory này để đặt
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_play_sfx("ui_click")
			var map_node = _find_game_map()
			if map_node and map_node.has_method("select_territory"):
				map_node.select_territory(biome_key)
	)
	UIStyle.make_click_target(container)
	UIStyle.hover_lift(container, 1.05)
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.tooltip_text = "Click để đặt %s lên bản đồ" % biome_name
	_territory_container.add_child(container)
	UIStyle.pop_in(container, 0.03 * _territory_container.get_child_count())

func refresh_dismiss_stock(count: int) -> void:
	if not _dismiss_container:
		return
	for child in _dismiss_container.get_children():
		child.queue_free()
	if count <= 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "—"
		UIStyle.body(empty_lbl, 11, C_DIM)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dismiss_container.add_child(empty_lbl)
		return
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 50)
	var red_accent = Color(0.85, 0.2, 0.2, 1.0)
	card.add_theme_stylebox_override("panel", _make_card_style(UIStyle.BG_WOOD, red_accent.darkened(0.2), 4))
	UIStyle.pixel_filter(card)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)
	var icon_lbl = Label.new()
	icon_lbl.text = "🗡"
	UIStyle.glyph(icon_lbl, 26, red_accent.lightened(0.3))
	icon_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_lbl)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)
	var name_lbl = Label.new()
	name_lbl.text = "Giải Tán"
	UIStyle.body(name_lbl, 12, C_WHITE)
	vbox.add_child(name_lbl)
	var count_lbl = Label.new()
	count_lbl.text = "×%d lượt" % count
	UIStyle.body(count_lbl, 10, red_accent.lightened(0.25))
	vbox.add_child(count_lbl)
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_play_sfx("ui_click")
			UIStyle.flash_node(card)
			var map_node = _find_game_map()
			if map_node and map_node.has_method("enter_dismiss_mode"):
				map_node.enter_dismiss_mode()
	)
	UIStyle.make_click_target(card)
	UIStyle.hover_lift(card, 1.05)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "Click để chọn tháp cần giải tán (hoàn 50% vàng)"
	_dismiss_container.add_child(card)
	UIStyle.pop_in(card)

# ── Purchases ─────────────────────────────────────────────────────────────────
func _on_shop_button_pressed(item_id: String) -> void:
	_play_sfx("ui_click")
	var map_node = _find_game_map()
	if not map_node:
		return
	if map_node.has_method("attempt_shop_purchase"):
		map_node.attempt_shop_purchase(item_id)

func _on_shop_next_wave_pressed() -> void:
	var map_node = _find_game_map()
	if not map_node:
		return
	if map_node.has_method("request_next_wave_phase"):
		map_node.request_next_wave_phase()

func _on_shop_item_purchased(item_data: ShopItemData) -> void:
	shop_status_label.text = "Mua: %s" % item_data.display_name
	shop_status_label.add_theme_color_override("font_color", C_GREEN)

func _on_shop_unit_stock_changed(_stats_id: String, _amount: int) -> void:
	_refresh_tower_buttons()

func _on_shop_purchase_failed(_item_id: String, reason: String) -> void:
	shop_status_label.text = reason
	shop_status_label.add_theme_color_override("font_color", C_RED)

# ── Popups ────────────────────────────────────────────────────────────────────
func show_shop_popup(title: String = "Shop Phase", message: String = "Shop time! Reinforce your forces.") -> void:
	if shop_popup:
		shop_popup_title.text = title
		shop_popup_message.text = message
		shop_popup.popup_centered_ratio(0.35)
		var pc := shop_popup.get_node_or_null("PanelContainer") as Control
		if pc:
			UIStyle.pop_in(pc)

func hide_shop_popup() -> void:
	if shop_popup:
		shop_popup.hide()

func open_meta_shop() -> void:
	if not meta_shop_manager:
		_setup_meta_shop()
	if meta_shop_popup:
		_refresh_meta_shop_list()
		meta_shop_popup.popup_centered_ratio(0.35)
		var pc := meta_shop_popup.get_node_or_null("PanelContainer") as Control
		if pc:
			UIStyle.pop_in(pc)

func _hide_meta_shop() -> void:
	if meta_shop_popup and meta_shop_popup.is_visible():
		meta_shop_popup.hide()

func _setup_meta_shop() -> void:
	var map_node = _find_game_map()
	if not map_node:
		return
	var manager = map_node.get_node_or_null("MetaShopManager") as MetaShopManager
	if not manager:
		return
	meta_shop_manager = manager

	var close_meta_callable = Callable(self, "_hide_meta_shop")
	if not meta_shop_close_button.is_connected("pressed", close_meta_callable):
		meta_shop_close_button.pressed.connect(close_meta_callable)
		_wire_button_sfx(meta_shop_close_button)

	var purchased_callable = Callable(self, "_on_meta_item_purchased")
	if not manager.meta_item_purchased.is_connected(purchased_callable):
		manager.meta_item_purchased.connect(purchased_callable)

	meta_shop_status_label.text = ""
	_refresh_meta_shop_list()

func _refresh_meta_shop_list() -> void:
	if not meta_shop_manager:
		return
	for child in meta_shop_list.get_children():
		child.queue_free()
	var row_index := 0
	for item in meta_shop_manager.get_all_meta_items():
		var is_unlocked = meta_shop_manager.is_item_unlocked(item)
		var rarity := "common" if is_unlocked else UIStyle.rarity_from_cost(item.cost, true)
		var boxes := UIStyle.framed_card(rarity, "wood", 3, 4)
		var container: PanelContainer = boxes[0]
		var inner: PanelContainer = boxes[1]
		container.custom_minimum_size = Vector2(0, 54)
		if is_unlocked:
			container.modulate = Color(0.62, 0.62, 0.62, 1.0)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		inner.add_child(hbox)

		if item.icon:
			var tex = TextureRect.new()
			tex.texture = item.icon
			tex.custom_minimum_size = Vector2(34, 34)
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tex.modulate = Color(1, 1, 1, 0.5 if is_unlocked else 1.0)
			hbox.add_child(tex)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(vbox)

		var n = Label.new()
		n.text = item.display_name + ("  ✓" if is_unlocked else "")
		UIStyle.body(n, 13, C_DIM if is_unlocked else UIStyle.rarity_color(rarity).lightened(0.4))
		vbox.add_child(n)

		if not is_unlocked:
			var cost_lbl = Label.new()
			cost_lbl.text = "⚡ %.0f" % item.cost
			UIStyle.glyph(cost_lbl, 13, C_BLUE)
			vbox.add_child(cost_lbl)

		if not is_unlocked:
			container.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					UIStyle.flash_node(container)
					_on_meta_shop_button_pressed(item.id)
			)
			UIStyle.make_click_target(container)
			UIStyle.hover_lift(container, 1.035)
			container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		meta_shop_list.add_child(container)
		UIStyle.pop_in(container, row_index * 0.035)
		row_index += 1

func _on_meta_shop_button_pressed(item_id: String) -> void:
	_play_sfx("ui_click")
	if not meta_shop_manager:
		return
	var map_node = _find_game_map()
	if not map_node:
		return
	var king = map_node.get_node_or_null("KingManager") as KingManager
	if not king:
		return
	var success = meta_shop_manager.attempt_purchase(item_id, king)
	if not success:
		meta_shop_status_label.text = "Không đủ Royal Decree hoặc đã mua"

func _on_meta_item_purchased(item: MetaShopItemData) -> void:
	meta_shop_status_label.text = "Unlocked: %s" % item.display_name
	_refresh_meta_shop_list()
	_refresh_tower_buttons()

# ── Utilities ─────────────────────────────────────────────────────────────────
func _find_game_map() -> Node3D:
	var scene = get_tree().get_current_scene()
	if scene:
		var found = _search_for_game_map(scene)
		if found:
			return found
	return _search_for_game_map(get_tree().get_root())

func _search_for_game_map(node: Node) -> Node3D:
	if not node:
		return null
	if node.name == "GameMap" and node is Node3D:
		return node
	for child in node.get_children():
		var found = _search_for_game_map(child)
		if found:
			return found
	return null

# ── Labels update ─────────────────────────────────────────────────────────────
func update_labels(health: int, gold: int, royal_decree: float = 0.0, favor_summary: String = "", territory_summary: String = "", phase_text: String = "", can_continue_wave: bool = false):
	if not is_node_ready():
		await ready

	# ── HP: số đếm chạy + shake/nháy đỏ khi mất máu ──────────────────────
	_max_health_seen = maxi(_max_health_seen, maxi(health, _king_base_health()))
	if _last_health_value < 0:
		label_health.text = "♥  %d" % health
	else:
		UIStyle.count_to(label_health, _last_health_value, health, "♥  %d")
		if health < _last_health_value:
			UIStyle.flash_color(label_health, Color(1.0, 0.35, 0.30), C_RED, 0.10)
			if _stats_holder:
				UIStyle.shake(_stats_holder, 7.0)
		elif health > _last_health_value:
			UIStyle.flash_color(label_health, C_GREEN, C_RED, 0.12)
	_last_health_value = health
	if _hp_bar:
		var hp_ratio: float = float(health) / float(maxi(1, _max_health_seen))
		UIStyle.tween_bar(_hp_bar, hp_ratio)
		# Bar đổi màu khi nguy kịch
		UIStyle.set_bar_color(_hp_bar, C_RED if hp_ratio > 0.3 else Color(1.0, 0.32, 0.10))

	# ── Gold: số đếm chạy + nháy xanh khi tăng ───────────────────────────
	if _last_gold_value < 0:
		label_gold.text = "◆  %d" % gold
	else:
		UIStyle.count_to(label_gold, _last_gold_value, gold, "◆  %d")
		if gold > _last_gold_value:
			_flash_gold_label()
	_last_gold_value = gold

	# ── Royal Decree: số + bar ───────────────────────────────────────────
	var rd = round(royal_decree * 10.0) / 10.0
	label_decree.text  = "⚡ %.1f RD" % rd
	if _rd_bar:
		UIStyle.tween_bar(_rd_bar, royal_decree / maxf(1.0, _decree_max()))

	# Hai chuỗi này TRƯỚC ĐÂY in nguyên si thành một dòng dài đọc như log debug.
	# Nay tách thành chip; hai Label gốc ẩn đi nhưng giữ lại để @onready và mọi
	# đoạn code cũ tham chiếu chúng không gãy.
	label_favor.visible = false
	label_territory.visible = false
	_refresh_status_chips(favor_summary, territory_summary)
	label_phase.text   = phase_text if phase_text != "" else "—"
	shop_next_wave_button.disabled = not can_continue_wave
	update_shop_gold(gold)
	update_shop_royal_decree(royal_decree)

## HP tối đa của King hiện tại — dùng làm mốc cho HP bar. Guard mọi tầng.
func _king_base_health() -> int:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return 1
	var king = gm.get("selected_king")
	if king == null:
		return 1
	var base = king.get("base_health")
	return int(base) if base != null else 1

## Trần Royal Decree hiện tại — mốc cho RD bar.
func _decree_max() -> float:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return 100.0
	var cap = gm.get("current_decree_max")
	return maxf(1.0, float(cap)) if cap != null else 100.0

## Nháy xanh label vàng rồi lerp về màu vàng gốc — feedback kiếm được tiền.
func _flash_gold_label() -> void:
	if not label_gold:
		return
	if _gold_flash_tween:
		_gold_flash_tween.kill()
	UIStyle.flash_color(label_gold, C_GREEN, C_GOLD, 0.15)
	UIStyle.pulse(label_gold, 1.16)

## Lerp màu label vàng từ xanh (flash) về màu vàng gốc — callback tween_method.
## Giữ lại cho tương thích: UIStyle.flash_color đã đảm nhiệm việc này.
func _set_gold_label_blend(t: float) -> void:
	if label_gold:
		label_gold.add_theme_color_override("font_color", C_GREEN.lerp(C_GOLD, t))

func show_game_over():
	pass

# ── Enemy Intel (wave preview during prep phase) ───────────────────────────────
var _intel_panel: PanelContainer = null
var _intel_label: Label = null

func _ensure_intel_panel() -> void:
	if _intel_panel:
		return
	var root_ctrl = get_node_or_null("Control")
	if not root_ctrl:
		return
	_intel_panel = PanelContainer.new()
	_intel_panel.name = "IntelPanel"
	_intel_panel.anchor_left   = 0.0
	_intel_panel.anchor_right  = 1.0
	_intel_panel.anchor_top    = 0.0
	_intel_panel.anchor_bottom = 0.0
	_intel_panel.offset_top    = 4
	_intel_panel.offset_bottom = 48
	# Dải thông tin wave chạy ngang đỉnh màn. Mép trái PHẢI nằm sau bảng tài
	# nguyên (rộng RESOURCE_PANEL_WIDTH, đặt tại x = 14), nếu không nó đè lên và
	# nuốt mất số Vàng / Sắc Lệnh — trông như hai ô đó bị mất.
	_intel_panel.offset_left   = 14 + RESOURCE_PANEL_WIDTH + 26
	_intel_panel.offset_right  = -180
	UIStyle.apply_panel(_intel_panel, "wood")
	_intel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(_intel_panel)
	_intel_label = Label.new()
	_intel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.body(_intel_label, 12, C_WHITE)
	_intel_panel.add_child(_intel_label)

func show_wave_intel(text: String) -> void:
	_ensure_intel_panel()
	if _intel_label:
		_intel_label.text = text
	if _intel_panel:
		var was_hidden := not _intel_panel.visible
		_intel_panel.visible = true
		if was_hidden:
			UIStyle.pop_in(_intel_panel)

func hide_wave_intel() -> void:
	if _intel_panel:
		_intel_panel.visible = false

# ── Shop header (gold + RD display + action buttons) ──────────────────────────
var _shop_gold_label: Label = null
var _shop_rd_label:   Label = null

func _inject_shop_header(shop_vbox: VBoxContainer) -> void:
	if shop_vbox.get_node_or_null("ShopStatsRow"):
		return

	# --- Stats row: Gold + RD (đặt ở TOP) ---
	var stats_row = HBoxContainer.new()
	stats_row.name = "ShopStatsRow"
	stats_row.add_theme_constant_override("separation", 8)

	var gold_icon = Label.new()
	gold_icon.text = "◆"
	UIStyle.glyph(gold_icon, 18, C_GOLD)
	stats_row.add_child(gold_icon)

	_shop_gold_label = Label.new()
	_shop_gold_label.name = "ShopGoldLabel"
	_shop_gold_label.text = "0"
	UIStyle.glyph(_shop_gold_label, 17, C_GOLD)
	stats_row.add_child(_shop_gold_label)

	var sep_lbl = Label.new()
	sep_lbl.text = "  |"
	UIStyle.body(sep_lbl, 15, C_DIM)
	stats_row.add_child(sep_lbl)

	var rd_icon = Label.new()
	rd_icon.text = "⚡"
	UIStyle.glyph(rd_icon, 18, C_BLUE)
	stats_row.add_child(rd_icon)

	_shop_rd_label = Label.new()
	_shop_rd_label.name = "ShopRDLabel"
	_shop_rd_label.text = "0.0 RD"
	UIStyle.glyph(_shop_rd_label, 17, C_BLUE)
	_shop_rd_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(_shop_rd_label)

	# Thêm stats_row ở đầu (vị trí 0)
	shop_vbox.add_child(stats_row)
	shop_vbox.move_child(stats_row, 0)

	# --- Action row: Roll (trái) — đặt ở CUỐI (dưới danh sách items) ---
	var action_row = HBoxContainer.new()
	action_row.name = "ShopActionRow"
	action_row.add_theme_constant_override("separation", 6)

	var roll_cost_lbl = Label.new()
	roll_cost_lbl.text = "◆2"
	UIStyle.body(roll_cost_lbl, 12, C_DIM)
	action_row.add_child(roll_cost_lbl)

	var roll_btn = Button.new()
	roll_btn.name = "RollButton"
	roll_btn.text = "🎲 Roll"
	roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_btn.custom_minimum_size = Vector2(0, 38)
	UIStyle.apply_button_accent(roll_btn, C_BLUE, 14)
	roll_btn.pressed.connect(_on_roll_button_pressed)
	action_row.add_child(roll_btn)

	# Thêm action_row ở cuối (dưới items)
	shop_vbox.add_child(action_row)

func _on_roll_button_pressed() -> void:
	var map_node = _find_game_map()
	if map_node and map_node.has_method("attempt_shop_reroll"):
		map_node.attempt_shop_reroll()

## Vàng trong shop cũng dùng số đếm chạy để đồng bộ cảm giác với HUD chính.
var _last_shop_gold: int = -1

func update_shop_gold(gold: int) -> void:
	if not _shop_gold_label:
		return
	if _last_shop_gold < 0 or not shop_panel.visible:
		_shop_gold_label.text = str(gold)
	else:
		UIStyle.count_to(_shop_gold_label, _last_shop_gold, gold, "%d")
		if gold > _last_shop_gold:
			UIStyle.pulse(_shop_gold_label, 1.18)
	_last_shop_gold = gold

func update_shop_royal_decree(value: float) -> void:
	if _shop_rd_label:
		_shop_rd_label.text = "%.1f RD" % value

## Nhãn "★ Perks: N" trong stats panel (do update_perk_list dựng lười).
var _perk_counter_label: Label = null

## Counter nhỏ "★ Perks: N" trong stats panel — tooltip liệt kê tên perk đã chọn.
## Dùng _stats_vbox (đã cache) vì VBoxContainer đã bị reparent vào StatsHolder,
## đường dẫn "Control/VBoxContainer" KHÔNG còn hợp lệ.
func update_perk_list(names: Array) -> void:
	if not is_instance_valid(_perk_counter_label):
		var stats_vbox := _stats_vbox
		if stats_vbox == null:
			stats_vbox = get_node_or_null("Control/VBoxContainer") as VBoxContainer
		if stats_vbox == null:
			push_warning("game_hud: không tìm được stats VBox cho perk counter.")
			return
		_perk_counter_label = Label.new()
		_perk_counter_label.name = "LabelPerks"
		UIStyle.glyph(_perk_counter_label, 14, UIStyle.RARITY_EPIC)
		_perk_counter_label.mouse_filter = Control.MOUSE_FILTER_STOP
		stats_vbox.add_child(_perk_counter_label)
	var old_count := 0
	if _perk_counter_label.has_meta("perk_count"):
		old_count = int(_perk_counter_label.get_meta("perk_count"))
	_perk_counter_label.set_meta("perk_count", names.size())
	_perk_counter_label.text = "★ Perks: %d" % names.size()
	if names.size() > old_count:
		UIStyle.pulse(_perk_counter_label, 1.25)
	if names.is_empty():
		_perk_counter_label.tooltip_text = ""
		return
	var lines: Array[String] = []
	for perk_name in names:
		lines.append("• %s" % str(perk_name))
	_perk_counter_label.tooltip_text = "Đặc quyền đã chọn:\n" + "\n".join(lines)

# CHROME HUD — thanh tài nguyên + dải chip trạng thái
# ==============================================================================
# TRƯỚC: ba con số HP/vàng/RD xếp dọc trong một hộp đá hẹp 196px, bên dưới là
# MỘT DÒNG CHỮ DỒN CỤC kiểu "pawn ×1.0, rook ×1.0 | Mạch Hoả ×2 | Synergy: ...
# | Chuẩn bị 30s | Rừng Thẳm". Đọc như log debug, không phải HUD game.
#
# SAU: một thanh ngang — HP (có thanh máu) · Vàng · Sắc Lệnh (có thanh) — rồi
# một dải CHIP riêng cho từng mẩu trạng thái. Mỗi mẩu có nền và màu riêng nên
# liếc là thấy, không phải đọc cả câu.

const CHIP_BG := Color(0.09, 0.08, 0.07, 0.80)
const RESOURCE_PANEL_WIDTH: int = 430

var _chip_row: HFlowContainer = null

## Xếp lại HP / Vàng / RD thành MỘT HÀNG NGANG. Reparent chính các Label có sẵn
## (không tạo mới) nên mọi tham chiếu @onready và hiệu ứng đếm số vẫn nguyên.
func _build_resource_row() -> void:
	if _stats_vbox == null or label_health == null:
		return
	if _stats_vbox.has_node("ResourceRow"):
		return

	var row := HBoxContainer.new()
	row.name = "ResourceRow"
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_vbox.add_child(row)
	_stats_vbox.move_child(row, 0)

	# HP: số + thanh máu, chiếm phần rộng nhất (thông tin sống còn).
	# Chia bề rộng TƯỜNG MINH. Để cả ba cột cùng EXPAND_FILL thì thanh máu (có
	# min width riêng) nuốt hết chỗ và hai cột kia bị đẩy ra ngoài panel.
	var hp_col := VBoxContainer.new()
	hp_col.add_theme_constant_override("separation", 2)
	hp_col.custom_minimum_size = Vector2(168, 0)
	hp_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hp_col)
	_move_into(label_health, hp_col)
	if _hp_bar: _move_into(_hp_bar, hp_col)

	row.add_child(_v_divider())

	# Vàng: chỉ một con số, không cần thanh.
	var gold_col := VBoxContainer.new()
	gold_col.add_theme_constant_override("separation", 2)
	gold_col.custom_minimum_size = Vector2(96, 0)
	gold_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gold_col)
	_move_into(label_gold, gold_col)

	row.add_child(_v_divider())

	var rd_col := VBoxContainer.new()
	rd_col.add_theme_constant_override("separation", 2)
	rd_col.custom_minimum_size = Vector2(118, 0)
	rd_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rd_col)

	# Ba con số này KHÔNG được cắt cụt — "◆ 6" thay vì "◆ 640" là mất thông tin.
	for lbl in [label_health, label_gold, label_decree]:
		if lbl != null and is_instance_valid(lbl):
			lbl.clip_text = false
			lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_move_into(label_decree, rd_col)
	if _rd_bar: _move_into(_rd_bar, rd_col)

func _move_into(node: Control, parent: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	var old := node.get_parent()
	if old != null:
		old.remove_child(node)
	parent.add_child(node)

func _v_divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.10)
	line.custom_minimum_size = Vector2(1, 26)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

## Dải chip nằm dưới thanh tài nguyên. Mỗi mẩu trạng thái một chip riêng.
func _build_chip_row() -> void:
	if _stats_vbox == null or _chip_row != null:
		return
	_chip_row = HFlowContainer.new()
	_chip_row.name = "StatusChips"
	_chip_row.add_theme_constant_override("h_separation", 5)
	_chip_row.add_theme_constant_override("v_separation", 4)
	_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_vbox.add_child(_chip_row)
	# Ngay dưới hàng tài nguyên, TRÊN dòng phase.
	if label_phase != null and label_phase.get_parent() == _stats_vbox:
		_stats_vbox.move_child(_chip_row, label_phase.get_index())

## Dựng lại dải chip từ hai chuỗi tóm tắt. game_map vẫn ghép chuỗi bằng " | "
## như cũ — tách ở đây để KHÔNG phải đổi chữ ký update_labels và mọi bên gọi.
func _refresh_status_chips(favor: String, territory: String) -> void:
	if _chip_row == null:
		return
	# remove_child TRƯỚC queue_free: `queue_free` chỉ xoá ở CUỐI frame, mà
	# update_ui() được gọi nhiều lần trong một frame ⇒ chip cũ và chip mới cùng
	# tồn tại, minimum size của panel phình lên và không bao giờ co lại
	# (StatsHolder không nằm trong container nên không ai ép nó nhỏ lại).
	for child in _chip_row.get_children():
		_chip_row.remove_child(child)
		child.queue_free()

	for part in _split_summary(favor):
		_add_chip("♛ " + part, Color(0.82, 0.72, 1.00))
	for part in _split_summary(territory):
		_add_chip(part, _chip_color(part))

	# StatsHolder KHÔNG nằm trong container nào (con trực tiếp của Control), nên
	# Godot không bao giờ tự thu nhỏ nó — nó giữ mãi kích thước lớn nhất từng có.
	# Số chip đổi mỗi wave ⇒ phải ép co lại, nếu không panel phình ra thành một
	# mảng xám to đùng che góc màn hình.
	if _stats_holder != null and is_instance_valid(_stats_holder):
		_stats_holder.reset_size.call_deferred()

func _split_summary(text: String) -> Array[String]:
	var out: Array[String] = []
	if text.strip_edges() in ["", "—", "None"]:
		return out
	for raw in text.split("|", false):
		var part := raw.strip_edges()
		if part != "" and part != "—" and part != "None":
			out.append(part)
	return out

## Màu chip suy từ nội dung — người chơi nhận ra nhóm thông tin bằng MÀU trước
## khi kịp đọc chữ.
func _chip_color(part: String) -> Color:
	if part.begins_with("✦"):
		return Color(1.00, 0.72, 0.30)     # synergy nguyên tố
	if part.begins_with("["):
		return Color(1.00, 0.95, 0.60)     # mốc ×6 đã mở
	if part.begins_with("Synergy"):
		return Color(0.55, 0.85, 1.00)     # synergy loại quân
	return C_GREEN                          # ô lãnh thổ

func _add_chip(text: String, color: Color) -> void:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel",
		UIStyle.flat_inset(CHIP_BG, Color(color, 0.45), 4))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.body(lbl, 11, color)
	chip.add_child(lbl)
	_chip_row.add_child(chip)


# ── Cột King bên phải ─────────────────────────────────────────────────────
# .tscn neo panel này CAO HẾT MÀN HÌNH (anchor_bottom = 1) trong khi nội dung
# chỉ vài dòng ⇒ một dải gỗ rỗng chạy suốt từ trên xuống dưới. Tệ hơn, bề rộng
# 160px làm "Iron Decree" bị cắt cụt thành "Iron Decre".
# Sửa: bám mép TRÊN, cao theo nội dung, rộng 210px, và cho chữ tự xuống dòng.
const RIGHT_PANEL_WIDTH := UIStyle.HUD_RIGHT_PANEL_WIDTH

func _fix_right_panel(panel: PanelContainer) -> void:
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_top = 12.0
	panel.offset_bottom = 12.0
	panel.offset_left = -float(RIGHT_PANEL_WIDTH) - 12.0
	panel.offset_right = -12.0
	panel.custom_minimum_size = Vector2(RIGHT_PANEL_WIDTH, 0)
	UIStyle.set_pad(panel, 8)

	# Nhãn dài phải xuống dòng thay vì bị cắt cụt.
	for lbl in [label_king_name, label_ability_info]:
		if lbl != null and is_instance_valid(lbl):
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.clip_text = false
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label_king_name != null:
		UIStyle.title(label_king_name, 16, C_GOLD)
	if label_ability_info != null:
		UIStyle.body(label_ability_info, 11, C_DIM)
	if btn_king_ability != null:
		btn_king_ability.custom_minimum_size = Vector2(0, 34)


## Bọc tiêu đề shop trong một dải nền tối — tách phần đầu bảng khỏi danh sách
## hàng, giống mọi game TD có cửa hàng. Chỉ bọc một lần.
func _frame_shop_header(title: Label) -> void:
	var parent := title.get_parent()
	if parent == null or parent.name == "ShopHeader":
		return
	var header := PanelContainer.new()
	header.name = "ShopHeader"
	header.add_theme_stylebox_override("panel",
		UIStyle.flat_inset(Color(0.06, 0.05, 0.04, 0.85), Color(C_GOLD, 0.45), 5))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var idx := title.get_index()
	parent.remove_child(title)
	header.add_child(title)
	parent.add_child(header)
	parent.move_child(header, idx)


# ── Kich thuoc panel shop ─────────────────────────────────────────────────
# .tscn cho panel 420x480. Noi dung that = header + 4 the hang (62px moi the)
# + trang thai + 2 nut => vuot 480 va THE DAU TIEN bi cat mat.
# Nang chieu cao va cho danh sach cuon duoc de so luong hang doi khong lam vo bo cuc.
const SHOP_PANEL_W: int = 430
## Kep chieu cao: du thap de khong tran man hinh, du cao de 4 the hang + nut
## deu nam tron. Chieu cao THAT lay theo noi dung nen quay it hang khong de lai
## mot mang go rong o giua panel.
const SHOP_PANEL_H_MIN: int = 360
const SHOP_PANEL_H_MAX: int = 760

func _fix_shop_panel() -> void:
	if shop_panel == null or not is_instance_valid(shop_panel):
		return
	shop_panel.custom_minimum_size = Vector2(SHOP_PANEL_W, 0)
	if shop_list != null and is_instance_valid(shop_list):
		shop_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_resize_shop_panel.call_deferred()

## Panel shop khong nam trong container nao nen khong tu co lai — phai tinh
## chieu cao tu noi dung sau moi lan roll quay hang.
func _resize_shop_panel() -> void:
	if shop_panel == null or not is_instance_valid(shop_panel):
		return
	var want: float = clampf(shop_panel.get_combined_minimum_size().y,
		float(SHOP_PANEL_H_MIN), float(SHOP_PANEL_H_MAX))
	shop_panel.offset_left   = -SHOP_PANEL_W / 2.0
	shop_panel.offset_right  =  SHOP_PANEL_W / 2.0
	shop_panel.offset_top    = -want / 2.0
	shop_panel.offset_bottom =  want / 2.0

# ── Codex nguyên tố ───────────────────────────────────────────────────────────
# Thân nằm ở scripts/ui/hud/hud_codex.gd; ở đây chỉ còn cửa vào.

var _codex: HudCodex = null

func toggle_codex() -> void:
	if _codex == null or not is_instance_valid(_codex):
		_codex = HudCodex.attach(self)
	_codex.toggle_codex()

func is_codex_open() -> bool:
	return _codex != null and is_instance_valid(_codex) and _codex.is_open()

# ── Boss (uỷ quyền sang HudBoss) ──────────────────────────────────────────────

func show_boss_bar(boss_name: String, max_hp: int) -> void:
	if _boss: _boss.show_boss_bar(boss_name, max_hp)

func update_boss_bar(hp: int, phase: int = 1) -> void:
	if _boss: _boss.update_boss_bar(hp, phase)

func hide_boss_bar() -> void:
	if _boss: _boss.hide_boss_bar()

func show_boss_intro(name: String, title: String) -> void:
	if _boss: _boss.show_boss_intro(name, title)

## Bật/tắt nhãn đếm ngược chuẩn bị. HudBoss gọi vào: thanh máu boss dùng chung
## dải y với nhãn này nên phải tắt cho khỏi chồng chữ.
func set_prep_countdown_visible(state: bool) -> void:
	if is_instance_valid(_countdown_label):
		_countdown_label.visible = state

# ── Túi thuốc + thanh di vật (uỷ quyền) ───────────────────────────────────────
# Thân ở scripts/ui/hud/hud_potion_bag.gd và hud_relic_bar.gd. Phím tắt vẫn bắt
# ở _unhandled_input của HUD, hai signal potion_aim_* vẫn phát TỪ HUD — game_map
# không phải đổi gì.

var _potions: HudPotionBag = null
var _relics:  HudRelicBar  = null

func refresh_potion_bag(bag: Array) -> void:
	if _potions: _potions.refresh_potion_bag(bag)

func set_potion_aiming(active: bool, radius: float) -> void:
	if _potions: _potions.set_potion_aiming(active, radius)

func is_potion_aiming() -> bool:
	return _potions != null and _potions.is_aiming()

func cancel_potion_aim() -> void:
	if _potions: _potions.cancel_aim()

func refresh_relics(ids: Array) -> void:
	if _relics: _relics.refresh_relics(ids)

# ── Draft perk + popup trinh sát (uỷ quyền) ───────────────────────────────────
# Thân ở scripts/ui/hud/hud_perk_draft.gd và hud_wave_intel.gd.

var _perk_draft: HudPerkDraft = null
var _wave_intel: HudWaveIntel = null

func show_perk_draft(perks: Array, on_pick: Callable) -> void:
	if _perk_draft == null or not is_instance_valid(_perk_draft):
		_perk_draft = HudPerkDraft.attach(self)
	_perk_draft.show_perk_draft(perks, on_pick)

func hide_perk_draft() -> void:
	if _perk_draft: _perk_draft.hide_perk_draft()

func show_wave_intel_popup(data: Dictionary) -> void:
	if _wave_intel == null or not is_instance_valid(_wave_intel):
		_wave_intel = HudWaveIntel.attach(self)
	_wave_intel.show_wave_intel_popup(data)

# ── Panel thông tin tháp / ô (uỷ quyền sang HudTowerPanel) ────────────────────

func show_tower_info(stats: TowerStats, biome_key: String = "", tower_node: Node3D = null) -> void:
	if _tower_panel: _tower_panel.show_tower_info(stats, biome_key, tower_node)

func show_territory_info(biome_key: String, biome_data: Dictionary, pos: Vector2i = Vector2i(-1, -1)) -> void:
	if _tower_panel: _tower_panel.show_territory_info(biome_key, biome_data, pos)

func hide_tower_info() -> void:
	if _tower_panel: _tower_panel.hide_tower_info()
