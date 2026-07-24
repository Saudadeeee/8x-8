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

# ── Player Stats ────────────────────────────────────────────────────────────
@export_group("Player Stats")
@export var current_health: int = 20
@export var current_gold:   int = 100

@export_group("UI References")
@export var label_health: Label
@export var label_gold:   Label

# ── Misc ────────────────────────────────────────────────────────────────────
var _game_manager: GameManager = null
var _was_e_pressed: bool = false
var _game_over_triggered: bool = false

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
	wave_spawner.enemy_reached_base.connect(_on_enemy_reached_base)
	wave_spawner.enemy_defeated.connect(_on_enemy_defeated)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)

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

	# ── GridController ────────────────────────────────────────────────────
	grid_controller = GridController.new()
	grid_controller.name = "GridController"
	add_child(grid_controller)
	grid_controller.setup(board_root, MapGenerator.new())
	grid_controller.map_chunk_created.connect(_on_map_chunk_created)
	grid_controller.map_expanded.connect(_on_map_expanded)
	grid_controller.tower_refunded_on_expand.connect(func(g): current_gold += g)
	grid_controller.tower_removed_on_expand.connect(_on_tower_removed_on_expand)

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
	tower_placer.tower_dismissed.connect(func(_p, refund): current_gold += refund; update_ui())
	tower_placer.dismiss_stock_changed.connect(func(s): _refresh_hud_dismiss_stock(s))

	# ── PhaseController ───────────────────────────────────────────────────
	phase_controller = PhaseController.new()
	phase_controller.name = "PhaseController"
	add_child(phase_controller)
	phase_controller.setup(
		wave_spawner, shop_manager, _game_manager,
		grid_controller,
		func(): return current_gold)
	phase_controller.phase_changed.connect(_on_phase_changed)
	phase_controller.prep_countdown_updated.connect(_on_prep_countdown_updated)
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

	# ── Signal connections ────────────────────────────────────────────────
	var hud := get_node_or_null("HUD")
	if hud and hud.has_signal("tower_selected"):
		hud.tower_selected.connect(_on_tower_selected)

	if king_manager:
		king_manager.royal_decree_changed.connect(func(_v): update_ui())
		king_manager.ability_activated.connect(_on_king_ability_activated)
		king_manager.ability_cooldown_changed.connect(func(_v): update_ui())

	if shop_manager:
		shop_manager.shop_item_purchased.connect(_on_shop_item_purchased)

	if _game_manager and _game_manager.has_signal("state_changed"):
		_game_manager.state_changed.connect(_on_gm_state_changed)

	# ── EncounterScreen overlay ────────────────────────────────────────────
	var enc_path := "res://scenes/ui/encounter_screen.tscn"
	if not get_tree().get_root().find_child("EncounterScreen", true, false) and ResourceLoader.exists(enc_path):
		get_tree().get_root().add_child.call_deferred(load(enc_path).instantiate())

	# ── Init game ─────────────────────────────────────────────────────────
	_initialize_from_game_manager()
	territory_manager.setup(grid_controller, self)
	grid_controller.create_new_chunk()   # emits map_chunk_created → _on_map_chunk_created

	var territory_count := 4
	if _game_manager and _game_manager.selected_king:
		territory_count = _game_manager.selected_king.starting_territory_count
	territory_manager.initialize(territory_count, grid_controller.grid_data, king_manager, int(grid_controller.grid_height / 2.0))

	phase_controller.start_prep_phase()
	_center_camera_on_board()
	update_ui()

func _process(_delta: float) -> void:
	# Debug: E-key spawns enemy
	var e_pressed := Input.is_key_pressed(KEY_E)
	if e_pressed and not _was_e_pressed and wave_spawner:
		wave_spawner.spawn_enemy()
	_was_e_pressed = e_pressed

	# Preview update
	var mouse_pos := get_viewport().get_mouse_position()
	if tower_placer:
		tower_placer.update_preview(mouse_pos)
	if territory_manager and territory_manager.is_placing():
		var camera := get_viewport().get_camera_3d()
		if camera:
			var cell := GridUtil.mouse_to_cell(camera, mouse_pos)
			territory_manager.update_preview(cell, grid_controller.grid_data)

# ==========================================================================
# INPUT
# ==========================================================================

func _unhandled_input(event: InputEvent) -> void:
	# Right-click: cancel
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
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
	var grid_pos := GridUtil.mouse_to_cell(camera, get_viewport().get_mouse_position())
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
		elif territory_manager and territory_manager.has_biome_at(grid_pos):
			if hud and hud.has_method("show_territory_info"):
				var bk: String = territory_manager.get_biome_at(grid_pos)
				hud.show_territory_info(bk, TerritoryManager.BIOME_STATS.get(bk, {}))
		else:
			if hud and hud.has_method("hide_tower_info"):
				hud.hide_tower_info()
		return

	# Build mode: place tower (PREPARE/SHOP only)
	if phase_controller.current_phase == PhaseController.GamePhase.WAVE:
		return
	if tower_placer.is_buildable(grid_pos) and not (gc.grid_data.get(grid_pos) is Node3D):
		tower_placer.place(grid_pos)

# ==========================================================================
# PUBLIC API (gọi từ HUD)
# ==========================================================================

func confirm_wave_ready() -> void:
	phase_controller.confirm_wave_ready()

func request_next_wave_phase() -> void:
	if _game_over_triggered:
		return
	phase_controller.request_next_wave()
	grid_controller.expand()
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

	if synergy_summary != "" and synergy_summary != "None":
		territory_summary = territory_summary + " | Synergy: " + synergy_summary

	var phase_display: String = phase_controller.phase_message if phase_controller else ""
	if territory_manager and territory_manager.is_placing():
		var bk: String = territory_manager.get_pending_biome()
		var bname: String = TerritoryManager.BIOME_STATS.get(bk, {}).get("name", bk)
		var remaining: int = territory_manager.get_stock(bk)
		phase_display = "🌍 Đặt [%s] (x%d) — Click ô hợp lệ / RMB hủy" % [bname, remaining]
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

func game_over() -> void:
	if _game_over_triggered:
		return
	_game_over_triggered = true
	var hud := get_node_or_null("HUD")
	if hud:
		if hud.has_method("hide_shop_panel"): hud.hide_shop_panel()
		if hud.has_method("hide_shop_popup"): hud.hide_shop_popup()
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
	current_health -= damage
	update_ui()
	if current_health <= 0:
		game_over()

func _on_enemy_defeated(gold: int) -> void:
	current_gold += gold
	if _game_manager:
		_game_manager.run_enemies_killed += 1
		_game_manager.run_gold_earned    += gold
	update_ui()

func _on_wave_cleared() -> void:
	if phase_controller.current_phase == PhaseController.GamePhase.WAVE:
		if king_manager:
			king_manager.grant_wave_clear_decree()
		phase_controller.enter_shop_phase()

func _on_map_chunk_created(path: Array[Vector2i]) -> void:
	if king_manager:
		king_manager.register_territories(path, "path")

func _on_map_expanded(_new_height: int, _path: Array[Vector2i]) -> void:
	if wave_spawner:
		wave_spawner.setup(grid_controller.current_path_grid, self)
	_center_camera_on_board()
	for node in get_tree().get_nodes_in_group("enemies"):    node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"): node.queue_free()
	update_ui()

## Tower bị xoá do path mở rộng đè lên — gỡ synergy + refresh aura như dismiss thường.
func _on_tower_removed_on_expand(tower: Node3D) -> void:
	if synergy_manager:
		synergy_manager.on_tower_removed(tower)
	if tower_placer:
		tower_placer.refresh_commander_aura()

func _center_camera_on_board() -> void:
	var cam := get_node_or_null("CameraRig")
	if not cam or not cam.has_method("center_on_board"):
		return
	# Board có thể dài tới 32 hàng — fit toàn bộ sẽ đẩy camera quá xa.
	# Focus vào vùng chơi quanh King base (các hàng cuối), player pan/zoom xem phần còn lại.
	var w: float = grid_controller.grid_width * GridController.TILE_SIZE
	var h: float = grid_controller.grid_height * GridController.TILE_SIZE
	var visible_rows: float = min(h, 14.0)
	var center := Vector3(w / 2.0, 0.0, h - visible_rows / 2.0)
	var span: float = max(w, visible_rows)
	cam.center_on_board(center, span)

func _on_phase_changed(phase: PhaseController.GamePhase) -> void:
	var hud := get_node_or_null("HUD")
	if hud:
		match phase:
			PhaseController.GamePhase.PREPARE:
				if hud.has_method("hide_shop_popup"):  hud.hide_shop_popup()
				if hud.has_method("hide_shop_panel"):  hud.hide_shop_panel()
				if wave_spawner:
					var intel_text: String = wave_spawner.get_wave_intel_text(phase_controller.wave_number)
					var intel_data: Dictionary = wave_spawner.build_wave_intel_data(phase_controller.wave_number)
					if hud.has_method("show_wave_intel"):       hud.show_wave_intel(intel_text)
					if hud.has_method("show_wave_intel_popup"): hud.show_wave_intel_popup(intel_data)
			PhaseController.GamePhase.WAVE:
				if hud.has_method("hide_shop_popup"):  hud.hide_shop_popup()
				if hud.has_method("hide_shop_panel"):  hud.hide_shop_panel()
				if hud.has_method("hide_wave_intel"):  hud.hide_wave_intel()
			PhaseController.GamePhase.SHOP:
				if hud.has_method("hide_wave_intel"):  hud.hide_wave_intel()
	update_ui()

func _on_prep_countdown_updated(seconds: int) -> void:
	var hud := get_node_or_null("HUD")
	if hud and hud.has_method("update_prep_countdown"):
		hud.update_prep_countdown(seconds)

func _on_shop_phase_entered(_wave: int, interest: int) -> void:
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
	update_ui()

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
