# res://scripts/map/game_map.gd
# Orchestrator gameplay — khởi tạo và nối dây các component.
# Mọi logic cụ thể đã được tách vào component riêng:
#   GridController    — grid_data, map generation/expand
#   TowerPlacer       — placement, dismiss, upgrade, commander aura
#   PhaseController   — PREPARE→WAVE→SHOP state machine
#   KingAbilityExecutor — Royal Ability execution + boon timer
#   MapOverlayDrawer  — tất cả overlay 3D (quad/Label3D)
extends Node3D

# ── Node Refs ──────────────────────────────────────────────────────────────
@onready var board_root:    Node3D          = $BoardRoot
@onready var king_manager:  KingManager     = $KingManager
@onready var shop_manager:  ShopPanelManager = $ShopManager

## Nền × Bội — công thức chấm điểm của game (xem board_score.gd).
var board_score: BoardScore = null
## Thế cờ theo hình học quân (Trận Pháo, Giao Hoả, Song Mã…).
var chess_formations: ChessFormations = null
## Luật riêng của Rival King đang đối đầu.
var king_rules: KingRules = null
## Bộ quân của người chơi — shop rút quân từ đây (xem army_deck.gd).
var army_deck: ArmyDeck = null
## Tô sáng thế cờ đang thành hình trên bàn.
var chess_formation_overlay: ChessFormationOverlay = null
## Tô sáng tầm phủ của quân đang được chọn.
var coverage_overlay: CoverageOverlay = null

# Các class dưới đây có class_name riêng, không cần preload thủ công.

# ── Component Instances ──────────────────────────────────────────────────────
var wave_spawner:         WaveSpawner    = null
var territory_manager:    TerritoryManager = null
var synergy_manager:      SynergyManager     = null
var encounter_manager:    EncounterManager   = null
var grid_controller:      GridController     = null
var tower_placer:         TowerPlacer        = null
var phase_controller:     PhaseController    = null
var king_ability_executor: KingAbilityExecutor = null
var overlay_drawer:       MapOverlayDrawer   = null
var path_arrows:          PathArrows         = null
var perk_system:          PerkSystem         = null
var potion_system:        PotionSystem       = null
var equipment_system:     EquipmentSystem    = null
var relic_system:         RelicSystem        = null
var element_synergy:      ElementSynergy     = null
var formation_overlay:    FormationOverlay   = null
## Hạn mức hồi máu từ "Kiếm Hút Máu" trong wave hiện tại (reset mỗi wave).
var _lifesteal_this_wave: int = 0
const LIFESTEAL_CAP_PER_WAVE: int = 3
## Hệ hiệu ứng gameplay của biome — script tuỳ chọn, có thì nạp, không có thì bỏ qua.
## Kiểu Node (không phải BiomeEffects) để game vẫn chạy khi file chưa tồn tại.
var biome_effects:        Node               = null

# Wave đã offer perk draft — tránh offer 2 lần trong cùng shop phase
var _perk_draft_offered_wave: int = -1

# ── Player Stats ────────────────────────────────────────────────────────────
@export_group("Player Stats")
@export var current_health: int = 20
@export var current_gold:   int = 100

@export_group("UI References")
@export var label_health: Label
@export var label_gold:   Label

# ── Misc ────────────────────────────────────────────────────────────────────
const OVERCHARGE_COST: int = 30   # vàng cho 1 lần Overcharge tháp (right-click)
## Thưởng thêm khi hạ Rival King (ngoài gold_reward thường của boss).
const BOSS_BONUS_GOLD: int = 100
## Bản đồ chỉ mở rộng mỗi N wave (không phải mỗi wave).
## Với N = 3 → mở rộng trước wave 4, 7, 10.
## BÀN CỜ KHOÁ Ở 8×8 CẢ VÁN — 0 nghĩa là không bao giờ mở rộng.
##
## Đây là thay đổi thiết kế QUAN TRỌNG NHẤT của bản này. Bàn cũ nở mỗi 3 wave
## lên tới 24×24 = 576 ô; đo được bot rải 106 tháp mà CHƯA LẦN NÀO hết chỗ.
## Khi chỗ đặt không khan hiếm thì "đặt quân nào ở đâu" không còn là quyết định
## — và đó chính là quyết định mà cả hệ nước đi, thế cờ, ô nguyên tố được xây
## để phục vụ. Bloons giữ bản đồ cố định, TFT giữ trần 8-10 quân; cả hai đều ép
## khan hiếm lên tài nguyên VỊ TRÍ. Bản này làm như vậy.
##
## Mã mở rộng (map_generator.generate_extension_to_region, rebase, 4 hướng) vẫn
## còn nguyên và vẫn được test — chỉ là không được gọi. Bật lại = đặt lại 3.
const EXPAND_EVERY_N_WAVES: int = 0

## Trần số quân trên bàn. Tăng theo wave nên vẫn có cảm giác lớn mạnh, nhưng
## không bao giờ đủ để lấp kín 64 ô — luôn phải chọn.
const MAX_UNITS_BASE: int = 10
const MAX_UNITS_PER_WAVE: float = 0.9
const MAX_UNITS_CAP: int = 20

## Script hiệu ứng gameplay của biome (do hệ khác cung cấp). API kỳ vọng:
## setup(map) -> void, apply_biome(biome_id: String) -> void.
const BIOME_EFFECTS_PATH: String = "res://scripts/map/biome_effects.gd"
## Thời gian chuyển cảnh ánh sáng/sương khi bản đồ đổi khí hậu.
const BIOME_TWEEN_TIME: float = 1.2

# ── Thuốc (túi 3 ô, ném theo vùng — futureplan §3.1) ───────────────────────
## Xác suất một Elite rơi thuốc khi bị hạ.
const ELITE_POTION_DROP_CHANCE: float = 0.15
## Số bình nhận được khi hạ Rival King.
const BOSS_POTION_DROPS: int = 2
## Bình tặng lúc bắt đầu run để người chơi biết hệ thống tồn tại ("" = không tặng).
const STARTING_POTION_ID: String = "bom_lua"

## Ô túi đang ngắm (-1 = không ở chế độ ngắm).
## Thời gian còn lại của "Khiên Vương Triều" (giây, đếm theo delta nên tôn trọng
## tốc độ game và tự dừng khi pause).

var _game_manager: GameManager = null
var _was_e_pressed: bool = false
var _game_over_triggered: bool = false
## Rival King đang trên sân — dùng để bơm HP vào thanh máu boss của HUD.
## Thân xử lý boss ở scripts/map/boss_controller.gd.
var boss_controller: BossController = null
## Tween đang chạy cho môi trường — kill trước khi bắt đầu tween mới để không giằng nhau.
var _biome_env_tween: Tween = null

# ==========================================================================
# LIFECYCLE
# ==========================================================================

func _exit_tree() -> void:
	if _game_manager and _game_manager.state_changed.is_connected(_on_gm_state_changed):
		_game_manager.state_changed.disconnect(_on_gm_state_changed)

func _ready() -> void:
	get_tree().debug_collisions_hint = false
	get_tree().debug_navigation_hint = false

	_game_manager = get_node_or_null("/root/GameManagerSingleton")

	# Trạng thái static của hệ nguyên tố sống xuyên scene → dọn khi vào map mới,
	# nếu không vết nứt của run trước vẫn làm chậm địch run này.
	ReactionTable.reset()

	# ── HUD + Camera ──────────────────────────────────────────────────────
	if not get_node_or_null("HUD"):
		var hud_inst := (preload("res://scenes/ui/game_hud.tscn") as PackedScene).instantiate()
		hud_inst.name = "HUD"
		add_child(hud_inst)
	if not get_node_or_null("CameraRig"):
		var cam       := preload("res://scripts/mechanic/camera/camera_controller.gd").new()
		cam.name = "CameraRig"
		add_child(cam)

	# ── Build preview ghost (Sprite3D billboard trong world space) ────────
	var preview_sprite := Sprite3D.new()
	preview_sprite.pixel_size     = 0.03
	preview_sprite.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
	preview_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	preview_sprite.modulate       = Color(1, 1, 1, 0.5)
	preview_sprite.visible        = false
	add_child(preview_sprite)

	# ── WaveSpawner ───────────────────────────────────────────────────────
	wave_spawner = WaveSpawner.new()
	wave_spawner.name = "WaveSpawner"
	add_child(wave_spawner)
	boss_controller = BossController.attach(self)
	wave_spawner.enemy_reached_base.connect(_on_enemy_reached_base)
	wave_spawner.enemy_defeated.connect(_on_enemy_defeated)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)
	if wave_spawner.has_signal("boss_spawned"):
		wave_spawner.boss_spawned.connect(_on_boss_spawned)
	if wave_spawner.has_signal("boss_escaped"):
		wave_spawner.boss_escaped.connect(_on_boss_escaped)

	# ── TerritoryManager ──────────────────────────────────────────────────
	territory_manager = TerritoryManager.new()
	territory_manager.name = "TerritoryManager"
	add_child(territory_manager)
	territory_manager.territory_placed.connect(_on_territory_placed)
	territory_manager.territories_changed.connect(_on_territories_changed)
	territory_manager.stock_changed.connect(_on_territory_stock_changed)

	# ── SynergyManager ────────────────────────────────────────────────────
	synergy_manager = SynergyManager.new()
	synergy_manager.name = "SynergyManager"
	add_child(synergy_manager)
	synergy_manager.buffs_updated.connect(_on_synergy_buffs_updated)

	# ── EncounterManager ──────────────────────────────────────────────────
	encounter_manager = EncounterManager.new()
	encounter_manager.name = "EncounterManager"
	add_child(encounter_manager)
	encounter_manager.encounter_resolved.connect(_on_encounter_resolved)

	# ── PerkSystem ────────────────────────────────────────────────────────
	perk_system = PerkSystem.new()
	perk_system.name = "PerkSystem"
	add_child(perk_system)
	perk_system.perk_picked.connect(_on_perk_picked)
	perk_system.set_dominant_element_provider(_dominant_element)

	# ── PotionSystem ──────────────────────────────────────────────────────
	potion_system = PotionSystem.new()
	potion_system.name = "PotionSystem"
	add_child(potion_system)
	potion_controller = PotionController.attach(self)
	potion_system.bag_changed.connect(potion_controller._on_potion_bag_changed)

	# ── EquipmentSystem + RelicSystem ─────────────────────────────────────
	# Tạo TRƯỚC TowerPlacer: placer đọc `equipment_system` của game_map khi bán tháp.
	equipment_system = EquipmentSystem.new()
	equipment_system.name = "EquipmentSystem"
	add_child(equipment_system)

	relic_system = RelicSystem.new()
	relic_system.name = "RelicSystem"
	add_child(relic_system)
	relic_system.setup(equipment_system, potion_system)
	relic_system.relics_changed.connect(potion_controller._on_relics_changed)

	element_synergy = ElementSynergy.new()
	element_synergy.name = "ElementSynergy"
	add_child(element_synergy)
	element_synergy.element_synergy_changed.connect(_on_element_synergy_changed)
	# setup() sau khi territory_manager đã tồn tại — nó là nguồn đếm Bát Quái.
	element_synergy.setup(territory_manager)

	# Nền × Bội + thế cờ theo hình học quân. Hai hệ này là trục chính của thiết
	# kế mới; hệ ô nguyên tố bên dưới trở thành nguồn NỀN và một phần BỘI.
	army_deck = ArmyDeck.new()
	army_deck.name = "ArmyDeck"
	add_child(army_deck)
	# Panel bộ quân đang mở phải cập nhật ngay khi bộ đổi (mua thao tác lên bộ,
	# rút quân) — không nối thì nó hiện số cũ và người chơi tưởng mua hụt.
	army_deck.deck_changed.connect(_on_deck_changed)
	_apply_deck_modifiers()
	if shop_manager:
		shop_manager.army_deck = army_deck

	board_score = BoardScore.attach(self)
	chess_formations = ChessFormations.attach(self)
	chess_formations.formations_changed.connect(_on_chess_formations_changed)
	king_rules = KingRules.attach(self)
	chess_formation_overlay = ChessFormationOverlay.attach(self, chess_formations)
	coverage_overlay = CoverageOverlay.attach(self)

	formation_overlay = FormationOverlay.new()
	formation_overlay.name = "FormationOverlay"
	add_child(formation_overlay)
	formation_overlay.setup(territory_manager)

	# ── GridController ────────────────────────────────────────────────────
	grid_controller = GridController.new()
	grid_controller.name = "GridController"
	add_child(grid_controller)
	grid_controller.setup(board_root, MapGenerator.new())
	grid_controller.map_chunk_created.connect(_on_map_chunk_created)
	grid_controller.map_expanded.connect(_on_map_expanded)
	grid_controller.map_rebased.connect(_on_map_rebased)
	grid_controller.tower_refunded_on_expand.connect(func(g): current_gold += g)
	grid_controller.tower_removed_on_expand.connect(_on_tower_removed_on_expand)
	grid_controller.territory_overwritten_on_expand.connect(_on_territory_overwritten)
	grid_controller.biome_region_added.connect(_on_biome_region_added)
	grid_controller.free_tiles_granted.connect(_on_free_tiles_granted)
	# Ô lãnh thổ đã mua phải được đường mở rộng tránh ra (như ô có tháp)
	grid_controller.protected_cells_provider = func(): return territory_manager.owned_tiles

	# ── TowerPlacer ───────────────────────────────────────────────────────
	tower_placer = TowerPlacer.new()
	tower_placer.name = "TowerPlacer"
	add_child(tower_placer)
	tower_placer.setup(
		king_manager, territory_manager,
		synergy_manager, shop_manager,
		grid_controller.grid_data,   # reference — stays in sync
		grid_controller,
		preview_sprite)
	tower_placer.tower_placed.connect(func(_p, _t): update_ui())
	tower_placer.tower_placed.connect(_on_tower_placed_apply_perks)
	tower_placer.tower_placed.connect(_on_tower_placed_apply_tile_buff)
	# Chạm trần quân mà im lặng thì người chơi tưởng game hỏng — nối lý do ra HUD.
	tower_placer.place_rejected.connect(_on_place_rejected)
	tower_placer.tower_placed.connect(func(_p, _t): _recount_element_synergy())
	tower_placer.tower_dismissed.connect(func(_p, _r): _recount_element_synergy())
	tower_placer.tower_dismissed.connect(func(_p, refund): current_gold += refund; update_ui())
	tower_placer.dismiss_stock_changed.connect(func(s): _refresh_hud_dismiss_stock(s))
	# Props địa hình (cỏ/đá/bụi) trên ô bị tháp chiếm → ẩn; dismiss thì trả lại
	if grid_controller.has_method("clear_props_at"):
		tower_placer.tower_placed.connect(func(p, _t): grid_controller.clear_props_at(p))
	if grid_controller.has_method("restore_props_at"):
		tower_placer.tower_dismissed.connect(func(p, _r): grid_controller.restore_props_at(p))

	# ── PhaseController ───────────────────────────────────────────────────
	phase_controller = PhaseController.new()
	phase_controller.name = "PhaseController"
	add_child(phase_controller)
	phase_controller.setup(
		wave_spawner, shop_manager, _game_manager,
		grid_controller,
		func(): return current_gold)
	phase_controller.phase_changed.connect(_on_phase_changed)
	phase_controller.wave_started.connect(_on_wave_started_grant_perk_rd)
	phase_controller.prep_countdown_updated.connect(_on_prep_countdown_updated)
	phase_controller.prep_ready_changed.connect(_on_prep_ready_changed)
	phase_controller.shop_phase_entered.connect(_on_shop_phase_entered)
	phase_controller.season_buffs_apply_requested.connect(_on_season_buffs_apply_requested)
	phase_controller.shop_panel_show_requested.connect(_on_shop_panel_show_requested)
	phase_controller.phase_message_changed.connect(func(_t): update_ui())

	# ── KingAbilityExecutor ───────────────────────────────────────────────
	king_ability_executor = KingAbilityExecutor.new()
	king_ability_executor.name = "KingAbilityExecutor"
	add_child(king_ability_executor)
	king_ability_executor.setup(king_manager, _game_manager)

	# ── MapOverlayDrawer ──────────────────────────────────────────────────
	overlay_drawer = MapOverlayDrawer.new()
	overlay_drawer.name = "MapOverlayDrawer"
	add_child(overlay_drawer)
	overlay_drawer.setup(territory_manager, tower_placer, grid_controller)

	# ── PathArrows ────────────────────────────────────────────────────────
	# Mũi tên vàng chỉ hướng địch đi. Tách riêng khỏi overlay_drawer vì cái đó
	# rebuild theo ô đang hover, còn đường đi chỉ đổi vài lần mỗi ván.
	path_arrows = PathArrows.attach(self, grid_controller)

	# ── Signal connections ────────────────────────────────────────────────
	var hud := get_node_or_null("HUD")
	if hud and hud.has_signal("tower_selected"):
		hud.tower_selected.connect(_on_tower_selected)
	# Túi thuốc: HUD lo hiển thị + phím tắt, game_map lo vòng ngắm 3D và thi triển.
	if hud and hud.has_signal("potion_aim_requested"):
		hud.potion_aim_requested.connect(potion_controller._on_potion_aim_requested)
	if hud and hud.has_signal("potion_aim_cancelled"):
		hud.potion_aim_cancelled.connect(potion_controller._on_potion_aim_cancelled)

	if king_manager:
		king_manager.royal_decree_changed.connect(func(_v): update_ui())
		king_manager.ability_activated.connect(_on_king_ability_activated)
		king_manager.ability_cooldown_changed.connect(func(_v): update_ui())

	if shop_manager:
		shop_manager.shop_item_purchased.connect(_on_shop_item_purchased)
		if shop_manager.has_method("setup_item_systems"):
			shop_manager.setup_item_systems(equipment_system, relic_system)
			shop_manager.set_pity_element_provider(_dominant_element)
			shop_manager.refresh_shop(true)   # roll lại để quầy có ngay trang bị

	if _game_manager and _game_manager.has_signal("state_changed"):
		_game_manager.state_changed.connect(_on_gm_state_changed)

	# ── EncounterScreen overlay ────────────────────────────────────────────
	var enc_path := "res://scenes/ui/encounter_screen.tscn"
	if not get_tree().get_root().find_child("EncounterScreen", true, false) and ResourceLoader.exists(enc_path):
		get_tree().get_root().add_child.call_deferred(load(enc_path).instantiate())

	# ── Biome ─────────────────────────────────────────────────────────────
	# Cả hai phải xong TRƯỚC create_new_chunk() — signal biome_region_added của
	# chunk đầu phát ngay trong đó. Đặt sau mọi component để setup(self) thấy
	# grid_controller / tower_placer đã sẵn sàng.
	_setup_biome_effects()
	_duplicate_environment()

	# ── Init game ─────────────────────────────────────────────────────────
	_initialize_from_game_manager()
	territory_manager.setup(grid_controller, self)
	grid_controller.create_new_chunk()   # emits map_chunk_created → _on_map_chunk_created

	var territory_count := 4
	if _game_manager and _game_manager.selected_king:
		territory_count = _game_manager.selected_king.starting_territory_count
	# Meta "Đất phong" cộng thêm ô lãnh thổ đầu ván.
	if _game_manager:
		territory_count += maxi(0, int(_game_manager.meta_bonus_territories))
	territory_manager.initialize(territory_count, grid_controller.grid_data, king_manager, int(grid_controller.grid_height / 2.0))

	_maybe_show_tutorial()
	phase_controller.start_prep_phase()
	_center_camera_on_board()
	if potion_controller: potion_controller._grant_starting_potions()
	update_ui()

	# Nhạc nền — gọi 1 lần khi game_map sẵn sàng
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_music"):
		am.play_music()

func _process(delta: float) -> void:
	# Debug: SHIFT+E spawn địch. Phải kèm Shift vì E trần đã là phím ném thuốc ô 3.
	var e_pressed := Input.is_key_pressed(KEY_E) and Input.is_key_pressed(KEY_SHIFT)
	if e_pressed and not _was_e_pressed and wave_spawner:
		wave_spawner.spawn_enemy()
	_was_e_pressed = e_pressed

	if boss_controller: boss_controller.tick()
	if potion_controller: potion_controller.tick(delta)

	# Preview update
	var mouse_pos := get_viewport().get_mouse_position()
	if tower_placer:
		tower_placer.update_preview(mouse_pos)
	if territory_manager and territory_manager.is_placing():
		var camera := get_viewport().get_camera_3d()
		if camera:
			# PickUtil chứ không GridUtil: đặt ô nguyên tố DƯỚI CHÂN tháp có sẵn là
			# thao tác hợp lệ, mà click đã dùng PickUtil — để preview dùng ray-plane
			# thì ô sáng và ô nhận click lệch nhau đúng một ô.
			var cell := PickUtil.mouse_to_cell(camera, mouse_pos)
			territory_manager.update_preview(cell, grid_controller.grid_data)
	_update_cell_tooltip(mouse_pos)


## Tooltip Nền × Bội theo ô đang rê chuột.
##
## Đây là thứ khiến công thức ĐỌC ĐƯỢC. Balatro cho thấy từng lá cộng bao nhiêu
## Chip và từng Joker nhân bao nhiêu — hiệu ứng hiển thị đó CHÍNH LÀ game, không
## phải phần trang trí. Chỉ hiện con số tổng thì người chơi biết mình yếu mà
## không biết sửa chỗ nào.
var _tooltip_cell: Vector2i = Vector2i(-9999, -9999)

func _update_cell_tooltip(mouse_pos: Vector2) -> void:
	var hud := get_node_or_null("HUD")
	if hud == null or not hud.has_method("show_cell_tooltip"):
		return
	if board_score == null or not is_instance_valid(board_score):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var cell := PickUtil.mouse_to_cell(camera, mouse_pos)
	if not grid_controller.is_in_bounds(cell):
		if _tooltip_cell.x > -9000:
			_tooltip_cell = Vector2i(-9999, -9999)
			hud.hide_cell_tooltip()
		return
	# Chỉ dựng lại khi ĐỔI ô: tooltip gọi cell_base/cell_mult vốn quét mọi tháp,
	# dựng mỗi frame là phí vô ích.
	if cell == _tooltip_cell:
		return
	_tooltip_cell = cell
	hud.show_cell_tooltip(cell, cell_score_info(cell), mouse_pos)


## Toàn bộ dữ liệu Nền × Bội của một ô — HUD chỉ việc bày ra.
func cell_score_info(cell: Vector2i) -> Dictionary:
	if board_score == null or not is_instance_valid(board_score):
		return {}
	var base: float = board_score.cell_base(cell)
	var mult: float = board_score.cell_mult(cell)
	return {
		"cell": cell,
		"base": base,
		"mult": mult,
		"score": base * mult,
		"on_path": grid_controller.is_path_cell(cell),
		"base_rows": board_score.base_breakdown(cell),
		"mult_rows": board_score.mult_breakdown(cell),
	}

# ==========================================================================
# INPUT
# ==========================================================================

func _unhandled_input(event: InputEvent) -> void:
	# ── Ngắm thuốc: nhánh ƯU TIÊN CAO NHẤT ────────────────────────────────
	# Chèn TRƯỚC mọi nhánh cũ (overcharge/territory/dismiss/build/merge ★) để
	# lúc đang ngắm thì không nhánh nào khác chạm được vào click.
	if potion_controller != null and potion_controller.is_aiming():
		if _handle_potion_aim_input(event):
			return

	# Right-click: khi KHÔNG ở mode nào → thử Overcharge tháp; ngược lại giữ hành vi cancel cũ
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mode_active: bool = tower_placer.is_in_build_mode() \
			or tower_placer.is_in_dismiss_mode() \
			or (territory_manager != null and territory_manager.is_placing())
		if not mode_active and _try_overcharge_at_mouse():
			return
		tower_placer.cancel_build()
		var hud := get_node_or_null("HUD")
		if hud and hud.has_method("hide_tower_info"):
			hud.hide_tower_info()
		return

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# PickUtil chứ không GridUtil: click vào THÂN tháp phải chọn đúng tháp đó,
	# không phải ô phía sau nó (xem ghi chú trong pick_util.gd).
	var grid_pos := PickUtil.mouse_to_cell(camera, get_viewport().get_mouse_position())
	var gc: GridController = grid_controller
	if not gc.is_in_bounds(grid_pos):
		return

	# Territory placement
	if territory_manager and territory_manager.is_placing():
		territory_manager.try_place(grid_pos, gc.grid_data, king_manager)
		return

	# Dismiss mode
	if tower_placer.is_in_dismiss_mode():
		tower_placer.dismiss_at(grid_pos)
		return

	# Click info (no build mode)
	if not tower_placer.is_in_build_mode():
		var entry = gc.grid_data.get(grid_pos)
		var hud := get_node_or_null("HUD")
		if entry is Node3D and is_instance_valid(entry) and entry.get("stats"):
			if hud and hud.has_method("show_tower_info"):
				var biome: String = territory_manager.get_biome_at(grid_pos) if territory_manager else ""
				hud.show_tower_info(entry.stats, biome, entry)
			# Tô đúng ô quân này với tới. "Tầm bắn 5" không nói lên gì với mô
			# hình nước đi — Xe, Mã và Tốt cùng tầm 5 phủ ba hình khác hẳn nhau.
			if coverage_overlay:
				coverage_overlay.show_for(entry)
		elif territory_manager and territory_manager.has_biome_at(grid_pos):
			if coverage_overlay:
				coverage_overlay.hide_all()
			if hud and hud.has_method("show_territory_info"):
				var bk: String = territory_manager.get_biome_at(grid_pos)
				hud.show_territory_info(bk, TerritoryManager.BIOME_STATS.get(bk, {}), grid_pos)
		else:
			if coverage_overlay:
				coverage_overlay.hide_all()
			# MỌI ô phải xem được chỉ số. Trước đây chỉ ô có tháp và ô lãnh thổ
			# mới mở panel; ô Phước/Nguyền sinh lúc tạo map (grid_controller.
			# special_tiles) rơi vào nhánh này nên click vào không hiện gì —
			# chúng có rune riêng trên bàn nên trông y như ô đặc biệt bấm được.
			if hud and hud.has_method("show_cell_info"):
				hud.show_cell_info(grid_pos, _describe_cell(grid_pos))
			elif hud and hud.has_method("hide_tower_info"):
				hud.hide_tower_info()
			# Click magic — vòng ma thuật nhỏ khi click đất trống, phản hồi cho mọi click
			var ground := GridUtil.mouse_to_ground(camera, get_viewport().get_mouse_position())
			FX.spawn_click_ring(self, ground)
			var am = get_node_or_null("/root/AudioManagerSingleton")
			if am and am.has_method("play_sfx"):
				am.play_sfx("click_magic", -6.0)
		return

	# Build mode: place tower (PREPARE/SHOP only)
	if phase_controller.current_phase == PhaseController.GamePhase.WAVE:
		return
	# Ô trống → đặt mới. Ô đã có tháp CÙNG LOẠI chưa đủ sao → hợp nhất (★).
	if not tower_placer.is_buildable(grid_pos):
		return
	var occupied: bool = gc.grid_data.get(grid_pos) is Node3D
	var mergeable: bool = occupied and tower_placer.has_method("can_merge_at") \
		and tower_placer.can_merge_at(grid_pos, tower_placer.current_building_stats)
	if not occupied or mergeable:
		tower_placer.place(grid_pos)

## Right-click lên tháp của mình (không ở mode nào) → Overcharge 30 vàng.
## Trả về true nếu click đã được "tiêu thụ" (trúng ô có tháp) — kể cả khi thiếu vàng.
func _try_overcharge_at_mouse() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or grid_controller == null:
		return false
	# Overcharge nhắm vào THÁP → dùng PickUtil, nếu không phải click đúng chân tháp.
	var cell := PickUtil.mouse_to_cell(camera, get_viewport().get_mouse_position())
	if not grid_controller.is_in_bounds(cell):
		return false
	var entry = grid_controller.grid_data.get(cell)
	if not (entry is Node3D) or not is_instance_valid(entry) or not entry.has_method("overcharge"):
		return false
	if entry.has_method("is_overcharged") and entry.is_overcharged():
		return true   # đang active — nuốt click, không cancel/đóng panel
	if current_gold < OVERCHARGE_COST:
		phase_controller.phase_message = "⚠ Không đủ vàng Overcharge! Cần %d G" % OVERCHARGE_COST
		update_ui()
		return true
	current_gold -= OVERCHARGE_COST
	entry.overcharge()
	update_ui()
	return true

# ==========================================================================
# PUBLIC API (gọi từ HUD)
# ==========================================================================

func confirm_wave_ready() -> void:
	phase_controller.confirm_wave_ready()

## HUD gọi khi người chơi bấm "BẮT ĐẦU WAVE". Pha chuẩn bị không còn đếm ngược
## nên đây là ĐƯỜNG DUY NHẤT vào wave — bố trí bao lâu tuỳ người chơi.
func request_start_wave() -> bool:
	if _game_over_triggered:
		return false
	return phase_controller.request_start_wave()

func request_next_wave_phase() -> void:
	if _game_over_triggered:
		return
	# request_next_wave() tăng wave_number TRƯỚC → wave dưới đây là wave sắp tới.
	phase_controller.request_next_wave()
	var wave: int = phase_controller.wave_number
	if EXPAND_EVERY_N_WAVES > 0 and wave > 1 			and (wave - 1) % EXPAND_EVERY_N_WAVES == 0:
		grid_controller.expand()
	_restock_deck()
	phase_controller.start_prep_phase()
	update_ui()

func attempt_shop_purchase(item_id: String) -> void:
	if not shop_manager:
		return
	if phase_controller.current_phase == PhaseController.GamePhase.WAVE:
		phase_controller.phase_message = "⚠ Không thể mua hàng trong lúc chiến đấu!"
		update_ui()
		return
	var item: ShopItemData = shop_manager.get_item_by_id(item_id)
	if not item:
		# Thao tác lên bộ quân được sinh động mỗi lượt roll nên không nằm trong
		# catalog tĩnh — tìm trong danh sách đang bày rồi xử lý riêng.
		if item_id.begins_with("deck_"):
			_buy_deck_action(item_id)
		return
	if item_id.begins_with("deck_"):
		_buy_deck_action(item_id)
		return
	if item.use_royal_decree:
		if not king_manager:
			push_error("attempt_shop_purchase: KingManager null!")
			return
		if not king_manager.spend_royal_decree(item.cost):
			phase_controller.phase_message = "⚠ Không đủ Royal Decree! Cần %.1f RD" % item.cost
			update_ui()
			return
	else:
		var gold_cost := int(item.cost)
		if current_gold < gold_cost:
			phase_controller.phase_message = "⚠ Không đủ vàng! Cần %d" % gold_cost
			update_ui()
			return
		current_gold -= gold_cost
	update_ui()
	shop_manager.execute_purchase(item_id)

func attempt_shop_reroll() -> void:
	if phase_controller.current_phase == PhaseController.GamePhase.WAVE:
		phase_controller.phase_message = "⚠ Không thể xáo shop trong lúc chiến đấu!"
		update_ui()
		return
	var cost: int = shop_manager.get_reroll_cost() if shop_manager and shop_manager.has_method("get_reroll_cost") else 2
	if current_gold < cost:
		phase_controller.phase_message = "⚠ Không đủ vàng để xáo! Cần %d G" % cost
		update_ui()
		return
	current_gold -= cost
	if shop_manager:
		shop_manager.refresh_shop(false)
	update_ui()

func select_territory(biome_key: String) -> void:
	if not territory_manager:
		return
	if territory_manager.get_stock(biome_key) <= 0:
		return
	tower_placer.cancel_build()
	territory_manager.select(biome_key)
	update_ui()

# ==========================================================================
# UI
# ==========================================================================

func update_ui() -> void:
	if _game_manager:
		_game_manager.current_health = current_health
		_game_manager.current_gold   = current_gold

	var hud              := get_node_or_null("HUD")
	var decree_value     := king_manager.get_current_royal_decree() if king_manager else 0.0
	var favor_summary    := king_manager.format_favor_summary()     if king_manager else ""
	var territory_summary: String = king_manager.get_territory_summary() if king_manager else "None"
	var synergy_summary: String = synergy_manager.get_active_synergy_summary() if synergy_manager else ""

	# Synergy loại quân đã TẮT bằng cờ — không in dòng chết lên HUD.
	if FeatureFlags.UNIT_SYNERGY_ENABLED 			and synergy_summary != "" and synergy_summary != "None":
		territory_summary = territory_summary + " | Synergy: " + synergy_summary

	# Thế cờ là nguồn BỘI lớn nhất — phải hiện cùng chỗ với các chip khác.
	if chess_formations and is_instance_valid(chess_formations):
		var fc: Dictionary = chess_formations.counts()
		if not fc.is_empty():
			var parts := PackedStringArray()
			for fid in fc:
				parts.append("%s×%d" % [ChessFormations.display_name(str(fid)), int(fc[fid])])
			territory_summary += " | ⬢ " + ", ".join(parts)

	# Trục synergy thứ hai (nguyên tố) đi cùng dòng — người chơi cần thấy CẢ HAI
	# để quyết định đặt tháp tiếp theo ở đâu.
	if element_synergy and is_instance_valid(element_synergy):
		var element_summary: String = element_synergy.summary_text()
		if element_summary != "":
			territory_summary += " | ✦ " + element_summary
		var capstones: Array[String] = element_synergy.active_capstones()
		if not capstones.is_empty():
			territory_summary += " [%s]" % ", ".join(capstones)

	var phase_display: String = phase_controller.phase_message if phase_controller else ""
	if territory_manager and territory_manager.is_placing():
		var bk: String = territory_manager.get_pending_biome()
		var bname: String = TerritoryManager.BIOME_STATS.get(bk, {}).get("name", bk)
		var remaining: int = territory_manager.get_stock(bk)
		phase_display = " Đặt [%s] (x%d) — Click ô hợp lệ / RMB hủy" % [bname, remaining]
	elif tower_placer and tower_placer.is_in_dismiss_mode():
		phase_display = "[DISMISS] Click tháp để giải tán (RMB để hủy)"

	if hud and hud.has_method("update_labels"):
		var can_continue: bool = phase_controller.current_phase == PhaseController.GamePhase.SHOP
		hud.update_labels(current_health, current_gold, decree_value, favor_summary, territory_summary, phase_display, can_continue)

	if hud and hud.has_method("update_king_info") and _game_manager and _game_manager.selected_king:
		hud.update_king_info(_game_manager.selected_king, king_manager)

	if label_health: label_health.text = "Máu: " + str(current_health)
	if label_gold:   label_gold.text   = "Vàng: " + str(current_gold)

# ==========================================================================
# GAME STATE
# ==========================================================================

## Rival King chạm tới ngai vàng → thua ngay, bất kể còn bao nhiêu HP.
## Nếu chỉ trừ máu rồi cho "thắng" thì trận cuối mất hết ý nghĩa.
func _on_boss_escaped() -> void:
	if _game_over_triggered:
		return
	push_warning("game_map: Rival King đã chạm tới King — thua trận.")
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("defeat", -2.0)
	current_health = 0
	update_ui()
	game_over()

func game_over() -> void:
	if _game_over_triggered:
		return
	_game_over_triggered = true
	if boss_controller: boss_controller._clear_boss_ui()
	_cancel_potion_aim()   # dọn vòng ngắm còn treo trước khi khoá màn hình
	var hud := get_node_or_null("HUD")
	if hud:
		if hud.has_method("hide_shop_panel"): hud.hide_shop_panel()
		if hud.has_method("hide_shop_popup"): hud.hide_shop_popup()
		if hud.has_method("hide_perk_draft"): hud.hide_perk_draft()
	if _game_manager:
		_game_manager.force_game_over()
	else:
		get_tree().paused = true

func _initialize_from_game_manager() -> void:
	if not _game_manager:
		return
	current_health = _game_manager.current_health
	current_gold   = _game_manager.current_gold
	var king: KingStats = _game_manager.selected_king
	if king and king_manager:
		king_manager.initialize_from_king_stats(king)
	_grant_starting_units()

func _grant_starting_units() -> void:
	if not shop_manager or not _game_manager:
		return
	var king: KingStats = _game_manager.selected_king
	if not king:
		return
	var ids:        Array = king.starting_unit_ids
	var quantities: Array = king.starting_unit_quantities
	for i in ids.size():
		var stats_path := "res://res/towers/%s.tres" % ids[i]
		if not ResourceLoader.exists(stats_path): continue
		var stats := load(stats_path) as TowerStats
		if not stats: continue
		var count: int = quantities[i] if i < quantities.size() else 1
		for j in count:
			shop_manager.register_troop_purchase(stats)

# ==========================================================================
# SIGNAL HANDLERS
# ==========================================================================

func _on_enemy_reached_base(damage: int) -> void:
	# "Khiên Vương Triều": Nhà Vua miễn hoàn toàn sát thương trong thời gian hiệu lực.
	if _is_king_shielded():
		_show_shield_block()
		return
	current_health -= damage
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("king_hit", -2.0)
	update_ui()
	if current_health <= 0:
		game_over()

func _on_enemy_defeated(gold: int) -> void:
	# Kill combo: chuỗi hạ địch trong 2.5s → nhân vàng (state nằm ở GameManager)
	var combo_mult: float = 1.0
	if _game_manager and _game_manager.has_method("register_kill"):
		combo_mult = _game_manager.register_kill()
	var combo_gold: int = int(gold * combo_mult)
	# Perk "Thuế Máu": vàng cộng thêm mỗi kill (đọc từ GameManager per-run state)
	var perk_bonus: int = _game_manager.get_perk_gold_per_kill() if _game_manager else 0
	current_gold += combo_gold + perk_bonus
	if _game_manager:
		_game_manager.run_enemies_killed += 1
		_game_manager.run_gold_earned    += combo_gold + perk_bonus
	update_ui()

func _on_wave_cleared() -> void:
	if phase_controller.current_phase == PhaseController.GamePhase.WAVE:
		if king_manager:
			king_manager.grant_wave_clear_decree()
		_lifesteal_this_wave = 0
		if equipment_system:
			equipment_system.on_wave_cleared()   # cộng dồn "Rễ Cây Cổ"
		phase_controller.enter_shop_phase()

## Trang bị "Kiếm Hút Máu" — tháp gọi qua `on_kill_confirmed`.
## Trần theo WAVE chứ không theo tháp: nhiều tháp cùng lắp cũng không hồi vô hạn.
func equipment_lifesteal_heal(amount: int) -> void:
	if amount <= 0 or _lifesteal_this_wave >= LIFESTEAL_CAP_PER_WAVE:
		return
	var heal: int = mini(amount, LIFESTEAL_CAP_PER_WAVE - _lifesteal_this_wave)
	_lifesteal_this_wave += heal
	current_health += heal
	update_ui()

func _on_map_chunk_created(path: Array[Vector2i]) -> void:
	if king_manager:
		king_manager.register_territories(path, "path")
	if path_arrows:
		path_arrows.rebuild()

func _on_map_expanded(_new_height: int, _path: Array[Vector2i]) -> void:
	if wave_spawner:
		wave_spawner.setup(grid_controller.current_path_grid, self)
	_center_camera_on_board()
	for node in get_tree().get_nodes_in_group("enemies"):    node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"): node.queue_free()
	# boss (nếu có) vừa bị dọn cùng đàn quái
	if boss_controller: boss_controller._clear_boss_ui()
	# Đường dài thêm → phải rải lại mũi tên chỉ hướng.
	if path_arrows: path_arrows.rebuild()
	update_ui()

## Ô lãnh thổ bị đường mở rộng đè lên — dọn mesh/state và hoàn lại kho.
func _on_territory_overwritten(cells: Array[Vector2i]) -> void:
	if territory_manager and territory_manager.has_method("remove_territories_at"):
		territory_manager.remove_territories_at(cells, king_manager)
	update_ui()

## Tower bị xoá do path mở rộng đè lên — gỡ synergy + refresh aura như dismiss thường.
func _on_tower_removed_on_expand(tower: Node3D) -> void:
	if synergy_manager:
		synergy_manager.on_tower_removed(tower)
	if tower_placer:
		tower_placer.refresh_commander_aura()

## Bản đồ mở về WEST/NORTH → GridController đã dịch toàn bộ toạ độ ô đi `delta`.
## Mọi hệ thống KHÁC lưu state keyed theo cell phải dịch theo, nếu không sẽ trỏ sai ô.
## (grid_data / current_path_grid được rebase in-place nên tower_placer,
##  map_overlay_drawer, wave_spawner không cần làm gì.)
func _on_map_rebased(delta: Vector2i) -> void:
	if territory_manager and territory_manager.has_method("rebase"):
		territory_manager.rebase(delta)
	if king_manager and king_manager.has_method("rebase_territories"):
		king_manager.rebase_territories(delta)
	# Vết nứt keyed theo ô nhưng KHÔNG rebase được (mesh đã nằm ở toạ độ thế giới cũ)
	# → dọn sạch. Rebase chỉ xảy ra ở phase SHOP nên không mất hiệu ứng đang dùng.
	ReactionTable.clear_cracks()
	# Overlay hình thế vẽ theo toạ độ thế giới của ô → phải dựng lại sau khi ô dời.
	if formation_overlay:
		formation_overlay.rebuild()
	# Mũi tên cũng đặt theo toạ độ thế giới → dời ô là phải rải lại.
	if path_arrows:
		path_arrows.rebuild()

func _center_camera_on_board() -> void:
	var cam := get_node_or_null("CameraRig")
	if not cam or not cam.has_method("center_on_board"):
		return
	# Board mở rộng được cả 4 hướng → không còn giả định "vùng chơi ở các hàng cuối".
	# Focus vào trung điểm giữa ô King và tâm board: luôn thấy base + phần lớn sân,
	# player pan/zoom xem phần còn lại.
	var gc: GridController = grid_controller
	var w: float = gc.grid_width  * GridController.TILE_SIZE
	var h: float = gc.grid_height * GridController.TILE_SIZE
	var board_center := Vector3(w / 2.0, 0.0, h / 2.0)
	var focus := board_center
	if not gc.current_path_grid.is_empty():
		var king_world: Vector3 = GridUtil.cell_to_world(gc.current_path_grid.back())
		focus = (king_world + board_center) * 0.5
	# Chừa lề để thấy vành đất + cây cối quanh board (địa hình), không chỉ riêng ô cờ.
	const VIEW_MARGIN: float = 3.0
	var span: float = minf(float(maxi(gc.grid_width, gc.grid_height)), 16.0) + VIEW_MARGIN
	cam.center_on_board(focus, span)

func _on_phase_changed(phase: PhaseController.GamePhase) -> void:
	# Luật Rival King chỉ sống trong wave boss của hắn, KHÔNG kéo sang wave
	# thường — nếu không thì "Tượng bị câm" biến thành nerf vĩnh viễn.
	if king_rules and is_instance_valid(king_rules):
		var w: int = phase_controller.wave_number
		if wave_spawner and wave_spawner.is_boss_wave(w):
			king_rules.activate_for_boss(WaveSpawner.BOSS_WAVES.find(w))
			# Báo luật TRƯỚC khi đánh — Boss Blind của Balatro luôn nói trước.
			var hud_r := get_node_or_null("HUD")
			if hud_r and hud_r.has_method("show_king_rule"):
				hud_r.show_king_rule(king_rules.rule_name(), king_rules.rule_desc())
		else:
			king_rules.clear()
	# Ngưỡng đổi theo wave → bảng Nền × Bội phải tính lại ở mỗi lần đổi pha.
	_refresh_board_score()
	var hud := get_node_or_null("HUD")
	if hud:
		match phase:
			PhaseController.GamePhase.PREPARE:
				if hud.has_method("hide_shop_popup"):  hud.hide_shop_popup()
				if hud.has_method("hide_shop_panel"):  hud.hide_shop_panel()
				if hud.has_method("hide_perk_draft"):  hud.hide_perk_draft()
				if wave_spawner:
					var intel_text: String = wave_spawner.get_wave_intel_text(phase_controller.wave_number)
					var intel_data: Dictionary = wave_spawner.build_wave_intel_data(phase_controller.wave_number)
					if hud.has_method("show_wave_intel"):       hud.show_wave_intel(intel_text)
					# Popup trinh sát là Window nên vẽ ĐÈ lên mọi CanvasLayer —
					# kể cả lớp hướng dẫn. Hoãn lại tới khi đọc xong hướng dẫn.
					if hud.has_method("show_wave_intel_popup") and not _tutorial_open():
						hud.show_wave_intel_popup(intel_data)
			PhaseController.GamePhase.WAVE:
				if hud.has_method("hide_shop_popup"):  hud.hide_shop_popup()
				if hud.has_method("hide_shop_panel"):  hud.hide_shop_panel()
				if hud.has_method("hide_wave_intel"):  hud.hide_wave_intel()
				if hud.has_method("hide_perk_draft"):  hud.hide_perk_draft()
			PhaseController.GamePhase.SHOP:
				if hud.has_method("hide_wave_intel"):  hud.hide_wave_intel()
	update_ui()

func _on_prep_countdown_updated(seconds: int) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("update_prep_countdown"):
		hud.update_prep_countdown(seconds)

## Trả quân đã rút về bộ. Bộ mỏng dần trong một wave rồi đầy lại — đúng nhịp
## "tay bài" của Balatro: mỗi vòng bạn thấy một lát cắt khác của cùng một bộ.
func _restock_deck() -> void:
	if army_deck and is_instance_valid(army_deck):
		army_deck.restock()


## Mua một thao tác lên bộ: trừ vàng rồi áp. Không đủ tiền hoặc thao tác bất
## hợp lệ (bộ chạm sàn, quân đã ★3) thì KHÔNG trừ tiền.
func _buy_deck_action(action_id: String) -> void:
	var offer: ShopItemData = null
	for it in shop_manager.get_active_offers():
		if it != null and str(it.id) == action_id:
			offer = it
			break
	if offer == null:
		return
	var price: int = int(round(offer.cost))
	if current_gold < price:
		phase_controller.phase_message = "⚠ Không đủ vàng."
		update_ui()
		return
	if not apply_deck_action(action_id):
		phase_controller.phase_message = "⚠ Không thực hiện được thao tác này."
		update_ui()
		return
	current_gold -= price
	if _game_manager:
		_game_manager.current_gold = current_gold
	shop_manager.remove_from_active_offers(action_id)
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("shop_buy", -4.0)
	update_ui()


## Bốn thao tác lên bộ, bán trong shop. Đây là chỗ "build" thành hình:
## xoá Tốt để bộ mỏng, phong Hậu cho Tốt, nâng sao vĩnh viễn một loại.
func apply_deck_action(action_id: String) -> bool:
	if army_deck == null or not is_instance_valid(army_deck):
		return false
	var parts := action_id.split(":")
	if parts.size() < 2:
		return false
	match parts[0]:
		"deck_thin":
			return army_deck.remove_unit(parts[1], 1)
		"deck_star":
			return army_deck.upgrade_star(parts[1])
		"deck_add":
			return army_deck.add_unit(parts[1], 1)
		"deck_morph":
			return parts.size() >= 3 and army_deck.transmute(parts[1], parts[2])
	return false


## Vàng khởi đầu và trần quân riêng của Bộ Khai Cuộc.
## Bộ Cá Ngựa ít quân nhưng giàu; Bộ Khổ Hạnh nghèo nhưng ô thường mạnh.
func _apply_deck_modifiers() -> void:
	if army_deck == null or army_deck.active_deck_id == "":
		return
	var data := ArmyDeck.load_deck(army_deck.active_deck_id)
	if data == null:
		return
	current_gold = maxi(0, current_gold + int(data.gold_delta))
	if _game_manager:
		_game_manager.current_gold = current_gold
	_deck_unit_cap_delta = int(data.unit_cap_delta)


## Chênh lệch trần quân do Bộ Khai Cuộc quy định.
var _deck_unit_cap_delta: int = 0


func _on_deck_changed(_counts: Dictionary) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("is_deck_panel_open") and hud.is_deck_panel_open():
		hud.refresh_deck_panel()


func _on_place_rejected(reason: String) -> void:
	phase_controller.phase_message = "⚠ " + reason
	update_ui()
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("error", -6.0)


func _on_prep_ready_changed(ready: bool) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("set_start_wave_button_visible"):
		hud.set_start_wave_button_visible(ready)

func _on_shop_phase_entered(_wave: int, interest: int) -> void:
	# Giá xáo tăng dần TRONG một phiên shop → phải hạ về mức nền ở phiên mới.
	if shop_manager and shop_manager.has_method("reset_reroll_cost"):
		shop_manager.reset_reroll_cost()
	if interest > 0:
		current_gold += interest
		if _game_manager:
			_game_manager.run_gold_earned += interest
	# Encounter check mỗi 3 wave
	if phase_controller.wave_number % 3 == 0 and encounter_manager:
		encounter_manager.trigger_random_encounter()
	else:
		phase_controller.show_shop_after_encounter()

func _on_season_buffs_apply_requested(wave_number: int) -> void:
	if not wave_spawner:
		return
	var buff: Dictionary = wave_spawner.get_season_buff(wave_number)
	var dmg_mult: float    = buff.get("damage_mult",   1.0)
	var spd_penalty: float = buff.get("speed_penalty", 0.0)
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("apply_season_buff"):
			tower.apply_season_buff(dmg_mult, spd_penalty)

func _on_shop_panel_show_requested() -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_shop_panel"):
		hud.show_shop_panel()
	_maybe_offer_perk_draft(hud)
	update_ui()

# ==========================================================================
# BIOME (wiring môi trường + hiệu ứng)
# ==========================================================================

## Nạp script hiệu ứng biome nếu hệ khác đã cung cấp. Không có file → bỏ qua im lặng,
## bản đồ vẫn đổi khí hậu về mặt hình ảnh.
func _setup_biome_effects() -> void:
	if not ResourceLoader.exists(BIOME_EFFECTS_PATH):
		return
	var effects_script := load(BIOME_EFFECTS_PATH) as GDScript
	if effects_script == null:
		push_warning("game_map: %s không phải GDScript hợp lệ — bỏ qua hiệu ứng biome."
			% BIOME_EFFECTS_PATH)
		return
	var instance: Variant = effects_script.new()
	if not (instance is Node):
		push_warning("game_map: biome_effects.gd phải extends Node — bỏ qua hiệu ứng biome.")
		return
	biome_effects = instance
	biome_effects.name = "BiomeEffects"
	add_child(biome_effects)
	if biome_effects.has_method("setup"):
		biome_effects.setup(self)

## Environment trong .tscn là SubResource dùng chung — tween trực tiếp sẽ ghi đè
## giá trị gốc. Nhân bản một lần duy nhất lúc khởi tạo.
func _duplicate_environment() -> void:
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment = world_env.environment.duplicate()

## Một vùng bản đồ vừa nhận khí hậu mới → chuyển ánh sáng/sương, áp hiệu ứng
## gameplay và báo HUD.
func _on_biome_region_added(biome_id: String, _region: Rect2i) -> void:
	var spec: Dictionary = BiomeLibrary.get_spec(biome_id)
	_tween_environment_to(spec)
	if biome_effects and biome_effects.has_method("apply_biome"):
		biome_effects.apply_biome(biome_id)
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_biome_banner"):
		hud.show_biome_banner(str(spec.get("name", biome_id)), str(spec.get("desc", "")))

## Vùng mới mở ra → tặng ô nguyên tố khớp khí hậu (futureplan §2.4).
## Đây là mắt xích khiến HƯỚNG MỞ RỘNG quyết định lối chơi: đi về Hoả Diệm thì
## được ô Hoả miễn phí, nên mỗi run có bản sắc riêng ngay từ đầu.
func _on_free_tiles_granted(element: String, count: int) -> void:
	if territory_manager == null or count <= 0:
		return
	var biome_key: String = territory_manager.biome_of_element(element)
	if biome_key.is_empty():
		return
	for i in range(count):
		territory_manager.add_stock(biome_key)
	var label: String = ElementTypes.display_name(element)
	if phase_controller:
		phase_controller.phase_message = "✦ Vùng đất mới tặng %d ô %s!" % [count, label]

## Tween mượt WorldEnvironment + DirectionalLight3D sang bảng màu của biome.
func _tween_environment_to(spec: Dictionary) -> void:
	if _biome_env_tween and _biome_env_tween.is_valid():
		_biome_env_tween.kill()
	_biome_env_tween = null

	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		_tween_to(env, "background_color",    spec.get("bg_color",        env.background_color))
		_tween_to(env, "ambient_light_color", spec.get("ambient_color",   env.ambient_light_color))
		_tween_to(env, "ambient_light_energy", spec.get("ambient_energy", env.ambient_light_energy))
		_tween_to(env, "fog_light_color",     spec.get("fog_color",       env.fog_light_color))
		_tween_to(env, "fog_density",         spec.get("fog_density",     env.fog_density))

	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		_tween_to(sun, "light_color",  spec.get("light_color",  sun.light_color))
		_tween_to(sun, "light_energy", spec.get("light_energy", sun.light_energy))

## Tween được tạo LƯỜI — chỉ khi thật sự có property để chuyển, tránh Tween rỗng
## (Godot báo lỗi khi một Tween chạy mà không có Tweener nào).
func _tween_to(target: Object, property: String, value: Variant) -> void:
	if _biome_env_tween == null or not _biome_env_tween.is_valid():
		_biome_env_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_biome_env_tween.tween_property(target, property, value, BIOME_TWEEN_TIME)

# ==========================================================================
# PERK SYSTEM (wiring)
# ==========================================================================

## Offer draft 1-trong-3 perk khi vào shop phase. Được gọi từ
## _on_shop_panel_show_requested — signal này chỉ phát SAU khi encounter
## (nếu có) đã resolve, nên draft không bao giờ đè lên encounter popup.
func _maybe_offer_perk_draft(hud: Node) -> void:
	if not perk_system or _game_over_triggered:
		return
	if phase_controller.current_phase != PhaseController.GamePhase.SHOP:
		return
	if _perk_draft_offered_wave == phase_controller.wave_number:
		return
	_perk_draft_offered_wave = phase_controller.wave_number
	# Bậc perk mở dần theo wave — PerkSystem cần biết đang ở wave nào.
	perk_system.set_wave(phase_controller.wave_number)
	var draft: Array = perk_system.roll_draft()
	if draft.is_empty():
		return
	if hud and hud.has_method("show_perk_draft"):
		hud.show_perk_draft(draft, func(perk_id: String): perk_system.pick(perk_id))

## Tháp mới đặt xuống nhận ngay layer PERK tổng hợp (giống synergy re-apply).
func _on_tower_placed_apply_perks(_grid_pos: Vector2i, tower: Node3D) -> void:
	if perk_system:
		perk_system.apply_to_tower(tower)

## Ô phước/nguyền: buff/nerf sát thương tại thời điểm đặt (tháp không đổi ô khi expand —
## chỉ vị trí world đổi — nên place-time là đủ).
func _on_tower_placed_apply_tile_buff(grid_pos: Vector2i, tower: Node3D) -> void:
	if not grid_controller or not tower or not tower.has_method("apply_tile_buff"):
		return
	match grid_controller.get_special_tile(grid_pos):
		"blessed":
			tower.apply_tile_buff(GridController.BLESSED_DMG_PCT)
			FX.spawn_burst(self, GridUtil.cell_to_world(grid_pos) + Vector3(0.0, 0.3, 0.0),
				Color(1.0, 0.85, 0.3), 10, 0.7)
		"cursed":
			tower.apply_tile_buff(GridController.CURSED_DMG_PCT)
			FX.spawn_burst(self, GridUtil.cell_to_world(grid_pos) + Vector3(0.0, 0.3, 0.0),
				Color(0.6, 0.25, 0.85), 10, 0.7)

## Mô tả một ô KHÔNG có tháp và KHÔNG phải ô lãnh thổ — để HUD dựng panel.
## Trả `{title, subtitle, rows: [[khoá, giá trị]], hint}`.
func _describe_cell(cell: Vector2i) -> Dictionary:
	var gc := grid_controller
	var rows: Array = []
	var special: String = gc.get_special_tile(cell)
	var title := "Ô trống"
	var subtitle := "[Đất thường]"
	var hint := "Đặt quân lên đây, hoặc mua ô nguyên tố để biến nó thành ô có hệ."

	if gc.is_path_cell(cell):
		title = "Đường đi"
		subtitle = "[Lối quái]"
		hint = "Không đặt được quân trên đường. Địch đi theo mũi tên vàng."
	elif special == "blessed":
		title = "Ô Phước"
		subtitle = "[Ô đặc biệt]"
		rows.append(["⚔ Tháp trên ô", "+%.0f%%" % (GridController.BLESSED_DMG_PCT * 100.0)])
		hint = "Đặt quân mạnh nhất lên đây. Ô này sinh sẵn khi tạo bản đồ."
	elif special == "cursed":
		title = "Ô Nguyền"
		subtitle = "[Ô đặc biệt]"
		rows.append(["⚔ Tháp trên ô", "%.0f%%" % (GridController.CURSED_DMG_PCT * 100.0)])
		rows.append([" Địch chết tại đây", "+%d vàng" % Enemy.CURSED_KILL_BONUS_GOLD])
		hint = "Tránh đặt quân đắt lên đây — hoặc dùng nó làm ô kiếm vàng."

	# Vùng biome luôn có, kể cả ô thường: nó quyết định chỉ số địch và tháp.
	var biome_id: String = gc.get_cell_biome(cell) if gc.has_method("get_cell_biome") else ""
	if biome_id != "":
		rows.append(["◈ Vùng", str(BiomeLibrary.get_spec(biome_id).get("name", biome_id))])
	rows.append(["◎ Toạ độ", "(%d, %d)" % [cell.x, cell.y]])
	return {"title": title, "subtitle": subtitle, "rows": rows, "hint": hint}


## Perk "Sắc Lệnh Khẩn": +RD mỗi khi wave mới bắt đầu.
func _on_wave_started_grant_perk_rd(_wave_number: int, _enemy_count: int) -> void:
	if _game_manager and king_manager and _game_manager.perk_rd_per_wave_start > 0.0:
		king_manager.add_royal_decree(_game_manager.perk_rd_per_wave_start)

## Sau khi PerkSystem.pick() thành công — áp dụng hiệu ứng instant (máu/vàng
## nguồn sự thật nằm ở game_map) và cập nhật HUD.
func _on_perk_picked(perk: Dictionary) -> void:
	var inst: Dictionary = perk.get("instant", {})
	if not inst.is_empty():
		current_health += int(inst.get("hp_delta", 0))
		var gold_delta: int = int(inst.get("gold_delta", 0))
		current_gold += gold_delta
		if _game_manager and gold_delta > 0:
			_game_manager.run_gold_earned += gold_delta
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("update_perk_list"):
		hud.update_perk_list(perk_system.get_owned_names())
	update_ui()
	# PerkSystem.pick() đã chặn perk giết player — đây chỉ là guard phòng hờ.
	if current_health <= 0:
		game_over()

func enter_dismiss_mode() -> void:
	if tower_placer:
		tower_placer.enter_dismiss_mode()

func _on_tower_selected(stats: TowerStats) -> void:
	tower_placer.start_build(stats)

func _on_territory_placed(pos: Vector2i, biome: String) -> void:
	var entry = grid_controller.grid_data.get(pos)
	if entry is Node3D and is_instance_valid(entry):
		tower_placer.reapply_biome_buff_to_tower(entry, biome)
	update_ui()

func _on_territories_changed(biome_counts: Dictionary) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("refresh_territories"):
		hud.refresh_territories(biome_counts)
	# Mua/nâng một ô có thể đổi nguyên tố của tháp đứng trên đó → đếm lại synergy.
	if element_synergy:
		element_synergy.recount()

## Nguyên tố người chơi đang đầu tư nhiều nhất — nguồn cho pity shop và cho
## draft perk định hướng. "" khi chưa có tháp nào bắn nguyên tố.
func _dominant_element() -> String:
	if element_synergy == null or not is_instance_valid(element_synergy):
		return ""
	var best := ""
	var best_count := 0
	for element in element_synergy.counts.keys():
		var count := int(element_synergy.counts[element])
		if count > best_count:
			best_count = count
			best = str(element)
	return best

## Đếm lại synergy nguyên tố. Hoãn một frame: `tower_placed` phát TRƯỚC khi tháp
## đọc xong nguyên tố ô dưới chân, đếm ngay sẽ hụt mất tháp vừa đặt.
func _on_chess_formations_changed(_counts: Dictionary) -> void:
	update_ui()

## Trần số quân ở wave hiện tại.
func max_units() -> int:
	var wave: int = phase_controller.wave_number if phase_controller else 1
	var extra := 0
	if king_rules and is_instance_valid(king_rules):
		extra = king_rules.extra_places()
	return maxi(3, mini(MAX_UNITS_CAP,
		MAX_UNITS_BASE + int(floor(float(maxi(0, wave - 1)) * MAX_UNITS_PER_WAVE))
		+ extra + _deck_unit_cap_delta))


## Số quân đang đứng trên bàn.
func unit_count() -> int:
	return get_tree().get_nodes_in_group("towers").size()


## Còn chỗ đặt quân không. tower_placer hỏi trước khi cho đặt.
func can_place_more_units() -> bool:
	return unit_count() < max_units()


## Tóm tắt Nền × Bội cho HUD. Trả rỗng nếu hệ chưa dựng xong.
func board_summary() -> Dictionary:
	if board_score == null or not is_instance_valid(board_score):
		return {}
	return board_score.summary(phase_controller.wave_number if phase_controller else 1)

func _refresh_board_score() -> void:
	if chess_formations and is_instance_valid(chess_formations):
		chess_formations.recount()
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("update_board_score"):
		hud.update_board_score(board_summary())
	update_ui()

func _recount_element_synergy() -> void:
	# Bố cục bàn đổi → đường trượt của Xe/Tượng/Hậu đổi theo (quân mới có thể
	# chắn ngang). Dựng lại bảng ô-có-quân TRƯỚC khi bất cứ ai đọc tầm phủ.
	Tower.bump_layout(get_tree())
	_refresh_all_coverage()
	_refresh_board_score()
	if element_synergy == null:
		return
	await get_tree().process_frame
	if is_instance_valid(element_synergy):
		element_synergy.recount()

## Bắt mọi quân dựng lại tập ô phủ ngay (không đợi frame kế) — panel và overlay
## đọc `covered_cells` ngay sau khi đặt quân.
func _refresh_all_coverage() -> void:
	for t in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(t) and t.has_method("refresh_coverage"):
			t.refresh_coverage()
	# Tầm của quân TRƯỢT đổi theo bố cục, nên lớp tô sáng phải vẽ lại.
	if coverage_overlay and is_instance_valid(coverage_overlay):
		coverage_overlay.refresh()

func _on_element_synergy_changed(_levels: Dictionary) -> void:
	update_ui()   # dòng tóm tắt synergy nguyên tố nằm trong update_ui

func _on_territory_stock_changed(stock: Dictionary) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("refresh_territory_stock"):
		hud.refresh_territory_stock(stock)

func _on_synergy_buffs_updated() -> void:
	tower_placer.refresh_synergy_and_aura(synergy_manager)

func _on_encounter_resolved(choice: EncounterChoice) -> void:
	# Sync RD cap tới KingManager nếu encounter thay đổi decree_delta
	if choice and choice.decree_delta != 0.0 and king_manager:
		king_manager.decree_cap = maxf(1.0, king_manager.decree_cap + choice.decree_delta)
		king_manager.royal_decree_changed.emit(king_manager.royal_decree)
	phase_controller.show_shop_after_encounter()

func _on_gm_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PREPARING \
		and phase_controller.current_phase == PhaseController.GamePhase.SHOP:
		if _game_manager and _game_manager.current_state != GameManager.GameState.GAME_OVER:
			phase_controller.show_shop_after_encounter()

func _on_king_ability_activated(_ability_name: String, _king_stats: KingStats) -> void:
	king_ability_executor.execute()

func _on_shop_item_purchased(item: ShopItemData) -> void:
	if item == null:
		return
	match item.item_type:
		ShopItemData.ItemType.TROOP:
			if item.tower_stats:
				shop_manager.register_troop_purchase(item.tower_stats)
				tower_placer.start_build(item.tower_stats)
		ShopItemData.ItemType.EQUIPMENT:
			if equipment_system and not equipment_system.add_item(item.catalog_id):
				phase_controller.phase_message = " Kho trang bị đã đầy!"
			if shop_manager:  # món trang bị là duy nhất — mua rồi thì biến khỏi quầy
				shop_manager.remove_from_active_offers(item.id)
		ShopItemData.ItemType.RELIC:
			if relic_system and not relic_system.add_relic(item.catalog_id):
				phase_controller.phase_message = "★ Đủ 5 di vật — bán bớt để đổi!"
			if shop_manager:
				shop_manager.remove_from_active_offers(item.id)
		ShopItemData.ItemType.TERRITORY:
			var biome: String = item.territory_tag if TerritoryManager.BIOME_STATS.has(item.territory_tag) \
				else TerritoryManager.BIOME_KEYS[randi() % TerritoryManager.BIOME_KEYS.size()]
			territory_manager.add_stock(biome)
		ShopItemData.ItemType.DISMISS:
			tower_placer.add_dismiss_stock()
			if shop_manager:  # chỉ mua 1 lần mỗi shop phase
				shop_manager.remove_from_active_offers(item.id)
		ShopItemData.ItemType.UPGRADE:
			tower_placer.apply_upgrade(item)
			if shop_manager:
				shop_manager.remove_from_active_offers(item.id)
	update_ui()

func _refresh_hud_dismiss_stock(stock: int) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("refresh_dismiss_stock"):
		hud.refresh_dismiss_stock(stock)

# Background 2D _draw() cũ đã bỏ — thay bằng WorldEnvironment + GroundPlane trong game_map.tscn.

# ── Boss (uỷ quyền sang BossController) ───────────────────────────────────────
# Giữ tên hàm cũ vì WaveSpawner connect thẳng vào chúng.

func _on_boss_spawned(boss: Node) -> void:
	if boss_controller: boss_controller._on_boss_spawned(boss)

func _on_boss_phase_changed(phase: int) -> void:
	if boss_controller: boss_controller._on_boss_phase_changed(phase)

func _on_boss_defeated() -> void:
	if boss_controller: boss_controller._on_boss_defeated()

# ── Thuốc (uỷ quyền sang PotionController) ────────────────────────────────────
# Giữ tên hàm cũ vì PotionSystem và HUD gọi thẳng vào chúng.

var potion_controller: PotionController = null

func potion_heal_king(amount: int) -> void:
	if potion_controller: potion_controller.potion_heal_king(amount)

func potion_king_shield(seconds: float) -> void:
	if potion_controller: potion_controller.potion_king_shield(seconds)

func _is_king_shielded() -> bool:
	return potion_controller != null and potion_controller._is_king_shielded()

func _show_shield_block() -> void:
	if potion_controller: potion_controller._show_shield_block()

func _grant_random_potion(source: String = "") -> bool:
	return potion_controller != null and potion_controller._grant_random_potion(source)

func _handle_potion_aim_input(event: InputEvent) -> bool:
	return potion_controller != null and potion_controller._handle_potion_aim_input(event)

func _cancel_potion_aim(notify_hud: bool = true) -> void:
	if potion_controller: potion_controller._cancel_potion_aim(notify_hud)

## Hiện hướng dẫn nhập môn ở ván ĐẦU TIÊN. Tạm dừng game trong lúc đọc để người
## chơi không bị wave đầu chạy mất.
func _maybe_show_tutorial() -> void:
	if TutorialOverlay.already_seen():
		return
	var tut := TutorialOverlay.show_for(self)
	get_tree().paused = true
	tut.finished.connect(_on_tutorial_finished)

## Đang mở hướng dẫn — dùng để hoãn các popup có thể che mất nó.
func _tutorial_open() -> bool:
	var t := get_node_or_null("TutorialOverlay")
	return t != null and is_instance_valid(t) and not t.is_queued_for_deletion()

func _on_tutorial_finished() -> void:
	get_tree().paused = false
	# Giờ mới hiện popup trinh sát wave đầu — trước đó nó che mất hướng dẫn.
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("show_wave_intel_popup") and wave_spawner:
		hud.show_wave_intel_popup(
			wave_spawner.build_wave_intel_data(phase_controller.wave_number))

# ── Nâng sao: CHỈ bằng ghép quân trùng ───────────────────────────────────────
# Từng có đường thứ hai "nâng sao bằng vàng" làm sink kinh tế. Đã gỡ: nó biến
# mọi quyết định bố cục thành bài toán tiền và làm mất ý nghĩa của việc săn quân
# trùng trong shop — vốn là trục chiến thuật chính của thể loại auto-battler.
# Sink kinh tế nay nằm ở giá xáo shop tăng dần và ở ô nguyên tố.
