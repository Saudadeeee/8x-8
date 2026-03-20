# res://scripts/map/game_map.gd
# Orchestrator chính của gameplay.
# Delegates: WaveSpawner (enemy/season), TerritoryManager (biome),
#            KingManager, SynergyManager, EncounterManager, ShopPanelManager.
extends Node2D

# ── Node Refs ──────────────────────────────────────────────────────────────
@onready var layer_base:  TileMapLayer    = $LayerBase
@onready var layer_grass: TileMapLayer    = $LayerGrass
@onready var king_manager: KingManager    = $KingManager
@onready var shop_manager: ShopPanelManager = $ShopManager

# ── Sub-manager scripts (preload = class reference without editor cache dependency)
const WaveSpawner      = preload("res://scripts/map/wave_spawner.gd")
const TerritoryManager = preload("res://scripts/map/territory_manager.gd")

# ── Manager Instances ──────────────────────────────────────────────────────
var wave_spawner      = null   # WaveSpawner instance
var territory_manager = null   # TerritoryManager instance
var synergy_manager:   SynergyManager   = null
var encounter_manager: EncounterManager = null

# ── Resources ──────────────────────────────────────────────────────────────
var tower_scene   = preload("res://scenes/tower/tower_base.tscn")
var map_generator = MapGenerator.new()

# ── Phase Machine ──────────────────────────────────────────────────────────
enum GamePhase { PREPARE, WAVE, SHOP }

const MAX_WAVES:            int   = 10
const PREP_DURATION:        float = 10.0

var current_phase:          GamePhase = GamePhase.PREPARE
var wave_number:            int   = 1
var prep_countdown:         float = PREP_DURATION
var _wave_confirmed:        bool  = false   # true khi player đã đọc wave intel và xác nhận
var upcoming_shop_boost:    bool  = false
var active_shop_boost:      bool  = false
var _shop_shown_this_phase: bool  = false
var _game_over_triggered:   bool  = false
var phase_message:          String = ""

# ── Player Stats ───────────────────────────────────────────────────────────
@export_group("Player Stats")
@export var current_health: int = 20
@export var current_gold:   int = 100

@export_group("UI References")
@export var label_health: Label
@export var label_gold:   Label

var _game_manager = null

# ── Grid ───────────────────────────────────────────────────────────────────
var grid_width:  int = 8
var grid_height: int = 8
const MAX_GRID_SIZE: int = 32
const TILE_SIZE   = 16
const SOURCE_ID   = 1
const ATLAS_COORD_ROAD  = Vector2i(6, 2)
const ATLAS_COORD_WHITE = Vector2i(9, 0)
const ATLAS_COORD_BLACK = Vector2i(9, 1)

var grid_data:          Dictionary        = {}
var current_path_grid:  Array[Vector2i]   = []
var current_path_debug: Array[Vector2i]   = []

# ── Tower Placement ────────────────────────────────────────────────────────
var tower_upgrades:          Dictionary = {}
var current_building_stats:  TowerStats = null
var build_preview_sprite:    Sprite2D   = null
var _was_e_pressed:          bool       = false

# ── Dismiss Mode ───────────────────────────────────────────────────────────
var _dismiss_mode:  bool = false
var _dismiss_stock: int  = 0

# ── King Ability ──────────────────────────────────────────────────────────
const BOON_DURATION:             float = 10.0
const COMMANDER_AURA_SPEED_BONUS: float = 0.25   # -0.25s cooldown cho towers kề Commander

# ── Background ────────────────────────────────────────────────────────────
var _bg_tex: Texture2D = null

# ==========================================================================
# LIFECYCLE
# ==========================================================================

func _exit_tree() -> void:
	if _game_manager and _game_manager.state_changed.is_connected(_on_gm_state_changed):
		_game_manager.state_changed.disconnect(_on_gm_state_changed)

func _ready() -> void:
	get_tree().debug_collisions_hint = false
	get_tree().debug_navigation_hint = false

	# ── HUD + Camera ─────────────────────────────────────────────────────
	if not get_node_or_null("HUD"):
		var hud_scene := preload("res://scenes/ui/game_hud.tscn") as PackedScene
		var hud_inst  := hud_scene.instantiate()
		hud_inst.name = "HUD"
		add_child(hud_inst)
	if not get_node_or_null("Camera2D"):
		var cam_script := preload("res://scripts/mechanic/camera/camera_controller.gd")
		var cam        := cam_script.new()
		cam.name = "Camera2D"
		add_child(cam)

	# ── Tower build preview ───────────────────────────────────────────────
	build_preview_sprite = Sprite2D.new()
	build_preview_sprite.modulate = Color(1, 1, 1, 0.5)
	build_preview_sprite.scale    = Vector2(0.7, 0.7)
	build_preview_sprite.z_index  = 10
	build_preview_sprite.visible  = false
	add_child(build_preview_sprite)

	# ── WaveSpawner ───────────────────────────────────────────────────────
	wave_spawner = WaveSpawner.new()
	wave_spawner.name = "WaveSpawner"
	add_child(wave_spawner)
	wave_spawner.enemy_reached_base.connect(_on_enemy_reached_base)
	wave_spawner.enemy_defeated.connect(_on_enemy_defeated)
	wave_spawner.wave_cleared.connect(_on_wave_cleared)

	# ── TerritoryManager ─────────────────────────────────────────────────
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

	# ── Preload biome icons for shop ─────────────────────────────────────
	# (icons referenced by HUD — preload happens inside territory_manager already for textures)

	# ── Signal connections ────────────────────────────────────────────────
	var hud = get_node_or_null("HUD")
	if hud and hud.has_signal("tower_selected"):
		hud.tower_selected.connect(_on_tower_selected)

	if king_manager:
		king_manager.royal_decree_changed.connect(_on_royal_decree_changed)
		king_manager.ability_activated.connect(_on_king_ability_activated)
		king_manager.ability_cooldown_changed.connect(_on_ability_cooldown_changed)

	if shop_manager:
		shop_manager.shop_item_purchased.connect(_on_shop_item_purchased)

	_game_manager = get_node_or_null("/root/GameManagerSingleton")
	if _game_manager and _game_manager.has_signal("state_changed"):
		_game_manager.state_changed.connect(_on_gm_state_changed)

	# ── Background ────────────────────────────────────────────────────────
	var bg_path = "res://assets/background/bg_stone.png"
	if ResourceLoader.exists(bg_path):
		_bg_tex = load(bg_path)
	else:
		var bg_img = Image.load_from_file(ProjectSettings.globalize_path(bg_path))
		if bg_img:
			_bg_tex = ImageTexture.create_from_image(bg_img)

	# ── EncounterScreen overlay ────────────────────────────────────────────
	var enc_path = "res://scenes/ui/encounter_screen.tscn"
	if not get_tree().get_root().find_child("EncounterScreen", true, false) and ResourceLoader.exists(enc_path):
		get_tree().get_root().add_child.call_deferred(load(enc_path).instantiate())

	# ── Init game ────────────────────────────────────────────────────────
	_initialize_from_game_manager()

	# TerritoryManager setup (needs layer_grass before map is created)
	territory_manager.setup(layer_grass, self)

	# Map first (grid_data needed for territory initialization)
	create_new_chunk()

	# Territory init after map exists
	var territory_count = 4
	if _game_manager and _game_manager.selected_king:
		territory_count = _game_manager.selected_king.starting_territory_count
	territory_manager.initialize(territory_count, grid_data, king_manager, int(grid_height / 2.0))

	_start_prep_phase()
	update_ui()

func _process(delta: float) -> void:
	# Debug: E-key spawns an enemy
	var e_pressed = Input.is_key_pressed(KEY_E)
	if e_pressed and not _was_e_pressed:
		if wave_spawner:
			wave_spawner.spawn_enemy()
	_was_e_pressed = e_pressed

	# Tower placement preview
	if current_building_stats and build_preview_sprite.visible:
		var gmp = get_global_mouse_position()
		var grid_pos = layer_grass.local_to_map(layer_grass.to_local(gmp))
		build_preview_sprite.position = layer_grass.map_to_local(grid_pos)
		var valid_pos  = grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height
		var decree_ok  = king_manager and king_manager.can_afford(current_building_stats.decree_cost)
		if valid_pos and is_buildable_tile(grid_pos) and not (grid_data.get(grid_pos) is Node2D) and decree_ok:
			build_preview_sprite.modulate = Color(0, 1, 0, 0.6)
		else:
			build_preview_sprite.modulate = Color(1, 0, 0, 0.6)
		queue_redraw()

	# Territory placement preview
	if territory_manager and territory_manager.is_placing():
		territory_manager.update_preview(get_global_mouse_position(), grid_data)
		queue_redraw()

	# Dismiss mode redraw for cursor
	if _dismiss_mode:
		queue_redraw()

	_handle_phase_timers(delta)

# ==========================================================================
# MAP GENERATION
# ==========================================================================

func create_new_chunk() -> void:
	layer_base.clear()
	layer_grass.clear()
	grid_data.clear()
	current_path_grid.clear()
	current_path_debug.clear()

	# Clear territory sprites via manager (if already set up)
	if territory_manager:
		territory_manager.clear_all()

	# Clear towers, enemies, projectiles
	for node in get_tree().get_nodes_in_group("towers"):    node.queue_free()
	for node in get_tree().get_nodes_in_group("enemies"):   node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"): node.queue_free()

	map_generator.width = grid_width
	map_generator.height = grid_height
	map_generator.min_path_length = max(21, int(grid_width * grid_height / 4.0))
	map_generator.blocked_positions = {}
	var start_pos = Vector2i(randi() % grid_width, 0)
	var path = map_generator.generate_path(start_pos, grid_height - 1)

	if path.is_empty():
		push_error("Lỗi: Không tìm được đường đi!")
		return

	current_path_grid  = path
	current_path_debug = path
	draw_map_layers(path)
	queue_redraw()

func draw_map_layers(path: Array[Vector2i]) -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			layer_base.set_cell(pos, SOURCE_ID, ATLAS_COORD_ROAD)
			var tile_coord = ATLAS_COORD_WHITE if (x + y) % 2 == 0 else ATLAS_COORD_BLACK
			layer_grass.set_cell(pos, SOURCE_ID, tile_coord)

	for pos in path:
		layer_grass.erase_cell(pos)
		grid_data[pos] = "path"

	if king_manager:
		king_manager.register_territories(path, "path")

func expand_map() -> void:
	if grid_height >= MAX_GRID_SIZE:
		push_warning("expand_map: Bản đồ đã đạt kích thước tối đa %dx%d" % [MAX_GRID_SIZE, MAX_GRID_SIZE])
		return
	if current_path_grid.is_empty():
		push_error("expand_map: không có đường cũ để nối!")
		return

	var old_height = grid_height
	grid_height += 8

	var tower_positions: Dictionary = {}
	for pos in grid_data.keys():
		if grid_data[pos] is Node2D:
			tower_positions[pos] = true

	var junction: Vector2i = current_path_grid.back()
	var all_blocked: Dictionary = tower_positions.duplicate()
	for p in current_path_grid:
		if p != junction:
			all_blocked[p] = true

	var old_path_set: Dictionary = {}
	for p in current_path_grid:
		old_path_set[p] = true

	map_generator.width    = grid_width
	map_generator.height   = grid_height
	map_generator.min_y    = old_height - 1
	map_generator.min_path_length  = 9
	map_generator.blocked_positions  = all_blocked
	map_generator.adjacent_blocked  = old_path_set

	var new_segment = map_generator.generate_extension(junction, grid_height - 1)

	map_generator.min_y = 0
	map_generator.min_path_length = max(21, int(grid_width * grid_height / 4.0))
	map_generator.adjacent_blocked = {}

	if new_segment.is_empty():
		push_error("Không tạo được đoạn mở rộng — rollback kích thước!")
		grid_height = old_height
		map_generator.height = old_height
		map_generator.blocked_positions = {}
		return

	# Refund + remove towers on new segment
	var new_seg_set: Dictionary = {}
	for p in new_segment:
		new_seg_set[p] = true
	for pos in tower_positions.keys():
		if new_seg_set.has(pos):
			var tower = grid_data.get(pos)
			if tower and is_instance_valid(tower):
				if tower.stats:
					current_gold += int(tower.stats.cost * 0.5)
				tower.queue_free()
			grid_data.erase(pos)

	for i in range(1, new_segment.size()):
		current_path_grid.append(new_segment[i])
		current_path_debug.append(new_segment[i])

	for node in get_tree().get_nodes_in_group("enemies"):    node.queue_free()
	for node in get_tree().get_nodes_in_group("projectiles"): node.queue_free()

	layer_base.clear()
	layer_grass.clear()
	draw_map_layers(current_path_grid)

	for pos in grid_data.keys():
		var entry = grid_data[pos]
		if entry is Node2D and is_instance_valid(entry):
			entry.position = layer_grass.map_to_local(pos)

	# Update WaveSpawner path
	if wave_spawner:
		wave_spawner.setup(current_path_grid, layer_grass, self)

	queue_redraw()
	update_ui()

	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.position = Vector2((grid_width * TILE_SIZE) / 2.0, (grid_height * TILE_SIZE) / 2.0)

# ==========================================================================
# PHASE MACHINE
# ==========================================================================

func _handle_phase_timers(delta: float) -> void:
	match current_phase:
		GamePhase.PREPARE:
			if not _wave_confirmed:
				return   # chờ player xác nhận trước khi đếm ngược
			if prep_countdown > 0.0:
				prep_countdown = max(prep_countdown - delta, 0.0)
				var extra = " (Reinforced)" if upcoming_shop_boost else ""
				_set_phase_message("Chuẩn bị %ds%s" % [int(ceil(prep_countdown)), extra])
				var hud = get_node_or_null("HUD")
				if hud and hud.has_method("update_prep_countdown"):
					hud.update_prep_countdown(int(ceil(prep_countdown)))
			if prep_countdown <= 0.0:
				var hud = get_node_or_null("HUD")
				if hud and hud.has_method("update_prep_countdown"):
					hud.update_prep_countdown(0)
				_start_wave_phase()
		GamePhase.WAVE:
			var s_name = wave_spawner.get_season_name(wave_number) if wave_spawner else ""
			var spawned = wave_spawner.enemies_spawned if wave_spawner else 0
			var to_spawn = wave_spawner.get_enemies_to_spawn() if wave_spawner else 0
			var alive   = wave_spawner.enemies_alive if wave_spawner else 0
			var status  = "%s | Wave %d - %d/%d | Active %d" % [s_name, wave_number, spawned, to_spawn, alive]
			if active_shop_boost:
				status += " (Reinforced)"
			_set_phase_message(status)
		GamePhase.SHOP:
			_set_phase_message("Shop Phase - Purchase units and press Next Wave")

func _start_prep_phase() -> void:
	current_phase    = GamePhase.PREPARE
	prep_countdown   = PREP_DURATION
	_wave_confirmed  = false   # chờ player xác nhận trước khi đếm ngược

	var hud = get_node_or_null("HUD")
	if hud:
		if hud.has_method("hide_shop_popup"):  hud.hide_shop_popup()
		if hud.has_method("hide_shop_panel"):  hud.hide_shop_panel()

	if wave_spawner:
		var intel_text = wave_spawner.get_wave_intel_text(wave_number)
		var intel_data = wave_spawner.build_wave_intel_data(wave_number)
		_set_phase_message("Đọc thông tin wave rồi xác nhận để bắt đầu chuẩn bị...")
		if hud:
			if hud.has_method("show_wave_intel"):       hud.show_wave_intel(intel_text)
			if hud.has_method("show_wave_intel_popup"): hud.show_wave_intel_popup(intel_data)

func confirm_wave_ready() -> void:
	if current_phase != GamePhase.PREPARE or _wave_confirmed:
		return
	_wave_confirmed = true
	_set_phase_message("Chuẩn bị %ds | %s" % [int(ceil(prep_countdown)),
		wave_spawner.get_wave_intel_text(wave_number) if wave_spawner else ""])

func _start_wave_phase() -> void:
	var hud = get_node_or_null("HUD")
	if hud:
		if hud.has_method("hide_shop_popup"):  hud.hide_shop_popup()
		if hud.has_method("hide_shop_panel"):  hud.hide_shop_panel()
		if hud.has_method("hide_wave_intel"):  hud.hide_wave_intel()

	current_phase    = GamePhase.WAVE
	active_shop_boost  = upcoming_shop_boost
	upcoming_shop_boost = false

	_apply_current_season_buffs()

	if wave_spawner:
		wave_spawner.setup(current_path_grid, layer_grass, self)
		var enemy_count = wave_spawner.calculate_enemies_for_wave(wave_number, active_shop_boost)
		wave_spawner.start_wave(wave_number, enemy_count, active_shop_boost)
		_set_phase_message("%s | Wave %d — Spawning %d enemies" % [
			wave_spawner.get_season_name(wave_number), wave_number, enemy_count])

func _enter_shop_phase() -> void:
	if current_phase == GamePhase.SHOP:
		return

	if wave_number >= MAX_WAVES:
		if _game_manager:
			_game_manager.force_victory()
		return

	if wave_spawner:
		wave_spawner.stop()
	if _game_manager:
		_game_manager.current_wave = wave_number

	current_phase         = GamePhase.SHOP
	active_shop_boost     = false
	upcoming_shop_boost   = false
	_shop_shown_this_phase = false

	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("hide_wave_intel"):
		hud.hide_wave_intel()

	# Gold interest: 10% capped at 15
	var interest = min(int(current_gold * 0.10), 15)
	var interest_msg = ""
	if interest > 0:
		current_gold += interest
		if _game_manager:
			_game_manager.run_gold_earned += interest
		interest_msg = " | Lãi: +%d vàng" % interest

	if shop_manager:
		shop_manager.update_wave(wave_number)
		shop_manager.refresh_shop(true)

	_set_phase_message("Wave %d hoàn thành!%s Mua quân rồi bấm NEXT WAVE." % [wave_number, interest_msg])

	# Encounter mỗi 3 wave
	if wave_number % 3 == 0 and encounter_manager:
		encounter_manager.trigger_random_encounter()
		return

	_show_shop_after_encounter()

func request_next_wave_phase() -> void:
	if _game_over_triggered:
		return
	if current_phase != GamePhase.SHOP:
		return
	wave_number += 1
	expand_map()
	_start_prep_phase()

func _apply_current_season_buffs() -> void:
	if not wave_spawner:
		return
	var buff = wave_spawner.get_season_buff(wave_number)
	var dmg_mult    = buff.get("damage_mult",   1.0)
	var spd_penalty = buff.get("speed_penalty", 0.0)
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("apply_season_buff"):
			tower.apply_season_buff(dmg_mult, spd_penalty)

func _set_phase_message(new_text: String) -> void:
	if phase_message != new_text:
		phase_message = new_text
		update_ui()

func _show_shop_after_encounter() -> void:
	if current_phase != GamePhase.SHOP:
		return
	if _shop_shown_this_phase:
		return
	_shop_shown_this_phase = true
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("show_shop_panel"):
		hud.show_shop_panel()
	update_ui()

# ==========================================================================
# ENEMY / WAVE SIGNAL HANDLERS
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
	if current_phase == GamePhase.WAVE:
		_enter_shop_phase()

# ==========================================================================
# TOWER PLACEMENT
# ==========================================================================

func is_buildable_tile(grid_pos: Vector2i) -> bool:
	return layer_grass.get_cell_source_id(grid_pos) != -1

func place_tower(grid_pos: Vector2i) -> void:
	if current_building_stats == null:
		return

	if shop_manager and shop_manager.is_unit_limited(current_building_stats.id):
		if not shop_manager.consume_unit_stock(current_building_stats.id):
			push_warning("Không còn %s để đặt." % current_building_stats.name)
			return

	var decree_cost = current_building_stats.decree_cost
	if king_manager and not king_manager.spend_royal_decree(decree_cost):
		push_warning("Không đủ Royal Decree! Cần: %.1f" % decree_cost)
		return

	var new_tower = tower_scene.instantiate()
	new_tower.stats = current_building_stats
	add_child(new_tower)
	new_tower.position = layer_grass.map_to_local(grid_pos)
	grid_data[grid_pos] = new_tower

	if new_tower.has_method("load_tower_data"):
		new_tower.load_tower_data()
		_apply_upgrade_to_tower(new_tower)

	if king_manager:
		king_manager.apply_favor_to_tower(new_tower)

	var biome = territory_manager.get_biome_at(grid_pos) if territory_manager else ""
	if biome != "":
		_apply_biome_buff_to_tower(new_tower, biome)

	if synergy_manager and current_building_stats:
		synergy_manager.on_tower_placed(new_tower, current_building_stats)

	_refresh_commander_aura()
	update_ui()

func _apply_biome_buff_to_tower(tower: Node2D, biome_key: String) -> void:
	if not tower or not tower.has_method("apply_biome_buff"):
		return
	var biome_data = TerritoryManager.BIOME_STATS.get(biome_key, null)
	if biome_data:
		tower.apply_biome_buff(biome_data)

# ── Tower Upgrade ──────────────────────────────────────────────────────────

func _apply_tower_upgrade(item: ShopItemData) -> void:
	if not item or not item.tower_stats:
		return
	var key = item.tower_stats.id
	var existing: Dictionary = tower_upgrades.get(key, {"damage_bonus": 0.0, "attack_speed_reduction": 0.0})
	var updated: Dictionary = {
		"damage_bonus":           existing.get("damage_bonus", 0.0) + float(item.upgrade_damage_bonus),
		"attack_speed_reduction": existing.get("attack_speed_reduction", 0.0) + item.upgrade_attack_speed_reduction
	}
	tower_upgrades[key] = updated
	_apply_upgrade_to_existing_towers(key, updated)

func _apply_upgrade_to_existing_towers(stats_id: String, upgrade_data: Dictionary) -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if not tower or not is_instance_valid(tower): continue
		if not tower.has_method("apply_upgrade"):      continue
		if tower.stats and tower.stats.id == stats_id:
			tower.apply_upgrade(upgrade_data)

func _apply_upgrade_to_tower(tower: Node2D) -> void:
	if not tower or not is_instance_valid(tower): return
	if not tower.has_method("apply_upgrade"):      return
	if not tower.stats:                            return
	var upgrade_data = tower_upgrades.get(tower.stats.id)
	if upgrade_data:
		tower.apply_upgrade(upgrade_data)

# ── Dismiss ────────────────────────────────────────────────────────────────

func enter_dismiss_mode() -> void:
	if _dismiss_stock <= 0:
		return
	_dismiss_mode = true
	current_building_stats = null
	build_preview_sprite.visible = false
	if territory_manager:
		territory_manager.cancel()
	queue_redraw()

func _do_dismiss_tower(grid_pos: Vector2i) -> void:
	var entry = grid_data.get(grid_pos)
	if entry is Node2D and is_instance_valid(entry):
		if synergy_manager:
			synergy_manager.on_tower_removed(entry)
		var reward = 0
		if entry.get("stats") and entry.stats:
			reward = int(entry.stats.cost * 0.5)
		entry.queue_free()
		grid_data.erase(grid_pos)
		current_gold += reward
		_dismiss_stock = max(0, _dismiss_stock - 1)
		if _dismiss_stock <= 0:
			_dismiss_mode = false
		_refresh_commander_aura()
		_refresh_hud_dismiss_stock()
		update_ui()
	else:
		_dismiss_mode = false
		_refresh_hud_dismiss_stock()

# ==========================================================================
# COMMANDER AURA
# ==========================================================================

## Gọi sau mỗi lần đặt/xóa tháp — quét toàn bộ Commander trên bàn,
## xóa aura cũ rồi apply lại cho 8 ô kề.
func _refresh_commander_aura() -> void:
	# Bước 1: xóa aura hiện tại khỏi tất cả towers
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("clear_aura_buff"):
			tower.clear_aura_buff()
	# Bước 2: tìm commander, apply aura cho towers kề
	for pos in grid_data.keys():
		var entry = grid_data.get(pos)
		if not (entry is Node2D) or not is_instance_valid(entry): continue
		if not entry.get("stats") or entry.stats.id != "commander": continue
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var adj = grid_data.get(Vector2i(pos.x + dx, pos.y + dy))
				if not (adj is Node2D) or not is_instance_valid(adj): continue
				if adj.has_method("apply_aura_buff"):
					adj.apply_aura_buff({"attack_speed_reduction": COMMANDER_AURA_SPEED_BONUS})

func _refresh_hud_dismiss_stock() -> void:
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("refresh_dismiss_stock"):
		hud.refresh_dismiss_stock(_dismiss_stock)

# ==========================================================================
# SHOP INTEGRATION
# ==========================================================================

func attempt_shop_purchase(item_id: String) -> void:
	if not shop_manager:
		return
	if current_phase == GamePhase.WAVE:
		phase_message = "⚠ Không thể mua hàng trong lúc chiến đấu!"
		update_ui()
		return
	var item = shop_manager.get_item_by_id(item_id)
	if not item:
		return
	if item.use_royal_decree:
		if not king_manager:
			push_error("attempt_shop_purchase: KingManager null!")
			return
		if not king_manager.spend_royal_decree(item.cost):
			phase_message = "⚠ Không đủ Royal Decree! Cần %.1f RD" % item.cost
			update_ui()
			return
	else:
		var gold_cost = int(item.cost)
		if current_gold < gold_cost:
			phase_message = "⚠ Không đủ vàng! Cần %d" % gold_cost
			update_ui()
			return
		current_gold -= gold_cost
	update_ui()
	shop_manager.execute_purchase(item_id)

func attempt_shop_reroll() -> void:
	if current_phase == GamePhase.WAVE:
		phase_message = "⚠ Không thể xáo shop trong lúc chiến đấu!"
		update_ui()
		return
	var cost = shop_manager.get_reroll_cost() if shop_manager and shop_manager.has_method("get_reroll_cost") else 2
	if current_gold < cost:
		phase_message = "⚠ Không đủ vàng để xáo! Cần %d G" % cost
		update_ui()
		return
	current_gold -= cost
	if shop_manager:
		shop_manager.refresh_shop(false)
	update_ui()

func _on_shop_item_purchased(item: ShopItemData) -> void:
	if item == null:
		return
	match item.item_type:
		ShopItemData.ItemType.TROOP:
			if item.tower_stats:
				_handle_tower_purchase(item.tower_stats)
		ShopItemData.ItemType.TERRITORY:
			_apply_territory_purchase(item)
		ShopItemData.ItemType.DISMISS:
			_dismiss_stock += 1
			_refresh_hud_dismiss_stock()
		ShopItemData.ItemType.UPGRADE:
			_apply_tower_upgrade(item)
			if shop_manager:
				shop_manager.remove_from_active_offers(item.id)

func _handle_tower_purchase(stats: TowerStats) -> void:
	if not stats or not shop_manager:
		return
	shop_manager.register_troop_purchase(stats)
	_on_tower_selected(stats)

func _apply_territory_purchase(item: ShopItemData) -> void:
	var biome = item.territory_tag if TerritoryManager.BIOME_STATS.has(item.territory_tag) \
		else TerritoryManager.BIOME_KEYS[randi() % TerritoryManager.BIOME_KEYS.size()]
	if territory_manager:
		territory_manager.add_stock(biome)
	update_ui()

func select_territory(biome_key: String) -> void:
	if not territory_manager:
		return
	if territory_manager.get_stock(biome_key) <= 0:
		return
	current_building_stats = null
	build_preview_sprite.visible = false
	_dismiss_mode = false
	territory_manager.select(biome_key)
	queue_redraw()
	update_ui()

# ==========================================================================
# INPUT
# ==========================================================================

func _unhandled_input(event) -> void:
	# Right-click: cancel any active placement mode
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_dismiss_mode = false
		current_building_stats = null
		if build_preview_sprite:
			build_preview_sprite.visible = false
		if territory_manager:
			territory_manager.cancel()
		var hud_r = get_node_or_null("HUD")
		if hud_r and hud_r.has_method("hide_tower_info"):
			hud_r.hide_tower_info()
		queue_redraw()
		return

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	var gmp      = get_global_mouse_position()
	var grid_pos = layer_grass.local_to_map(layer_grass.to_local(gmp))
	var in_bounds = grid_pos.x >= 0 and grid_pos.x < grid_width \
		and grid_pos.y >= 0 and grid_pos.y < grid_height
	if not in_bounds:
		return

	# Territory placement mode
	if territory_manager and territory_manager.is_placing():
		if territory_manager.try_place(grid_pos, grid_data, king_manager):
			# Signal _on_territory_placed handles buff + redraw
			pass
		return

	# Dismiss mode
	if _dismiss_mode:
		_do_dismiss_tower(grid_pos)
		return

	# Click info mode (no build mode)
	if current_building_stats == null:
		var entry = grid_data.get(grid_pos)
		var hud = get_node_or_null("HUD")
		if entry is Node2D and is_instance_valid(entry) and entry.get("stats"):
			if hud and hud.has_method("show_tower_info"):
				var biome = territory_manager.get_biome_at(grid_pos) if territory_manager else ""
				hud.show_tower_info(entry.stats, biome, entry)
		elif territory_manager and territory_manager.has_biome_at(grid_pos):
			if hud and hud.has_method("show_territory_info"):
				var bk = territory_manager.get_biome_at(grid_pos)
				hud.show_territory_info(bk, TerritoryManager.BIOME_STATS.get(bk, {}))
		else:
			if hud and hud.has_method("hide_tower_info"):
				hud.hide_tower_info()
		return

	# Build mode: place tower (PREPARE/SHOP only)
	if current_phase == GamePhase.WAVE:
		return
	if is_buildable_tile(grid_pos):
		if not (grid_data.get(grid_pos) is Node2D):
			place_tower(grid_pos)

# ==========================================================================
# UI
# ==========================================================================

func update_ui() -> void:
	if _game_manager:
		_game_manager.current_health = current_health
		_game_manager.current_gold   = current_gold

	var hud = get_node_or_null("HUD")
	var decree_value       = king_manager.get_current_royal_decree() if king_manager else 0.0
	var favor_summary      = king_manager.format_favor_summary()    if king_manager else ""
	var territory_summary  = king_manager.get_territory_summary()   if king_manager else "None"
	var synergy_summary    = synergy_manager.get_active_synergy_summary() if synergy_manager else ""

	if synergy_summary != "" and synergy_summary != "None":
		territory_summary = territory_summary + " | Synergy: " + synergy_summary

	var phase_display = phase_message
	if territory_manager and territory_manager.is_placing():
		var bk   = territory_manager.get_pending_biome()
		var bname = TerritoryManager.BIOME_STATS.get(bk, {}).get("name", bk)
		var remaining = territory_manager.get_stock(bk)
		phase_display = "🌍 Đặt [%s] (x%d) — Click ô hợp lệ / RMB hủy" % [bname, remaining]
	elif _dismiss_mode:
		phase_display = "[DISMISS] Click tháp để giải tán (RMB để hủy)"

	if hud and hud.has_method("update_labels"):
		var can_continue = current_phase == GamePhase.SHOP
		hud.update_labels(current_health, current_gold, decree_value, favor_summary, territory_summary, phase_display, can_continue)

	if hud and hud.has_method("update_king_info") and _game_manager and _game_manager.selected_king:
		hud.update_king_info(_game_manager.selected_king, king_manager)

	if label_health: label_health.text = "Máu: " + str(current_health)
	if label_gold:   label_gold.text   = "Vàng: " + str(current_gold)

# ==========================================================================
# KING ABILITY
# ==========================================================================

func _on_king_ability_activated(_ability_name: String, _king_stats: KingStats) -> void:
	execute_king_ability()

func execute_king_ability() -> void:
	var king_id = ""
	if _game_manager and _game_manager.selected_king:
		king_id = _game_manager.selected_king.id

	match king_id:
		"king_iron":
			# Iron Decree: +30 Royal Decree ngay lập tức + Pawn +50% tốc độ 8s
			if king_manager:
				king_manager.add_royal_decree(30.0)
			for tower in get_tree().get_nodes_in_group("towers"):
				if not is_instance_valid(tower) or not tower.has_method("apply_boon_buff"): continue
				if not tower.get("stats") or tower.stats.id != "pawn": continue
				var spd_boost = tower.stats.attack_speed * 0.5
				tower.apply_boon_buff({"damage_bonus": 0.0, "attack_speed_reduction": spd_boost})
			get_tree().create_timer(8.0).timeout.connect(_on_boon_expired)

		"king_phantom":
			# Shadow Veil: Reset cooldown tất cả towers (bắn ngay) + Slow địch 50% trong 5s
			for tower in get_tree().get_nodes_in_group("towers"):
				if is_instance_valid(tower) and tower.has_method("reset_cooldown"):
					tower.reset_cooldown()
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
					enemy.apply_slow(0.5, 5.0)

		"king_flame":
			# Royal Inferno: 50 dmg tất cả địch + Queen double damage 10s
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					enemy.take_damage(50)
			for tower in get_tree().get_nodes_in_group("towers"):
				if not is_instance_valid(tower) or not tower.has_method("apply_boon_buff"): continue
				if not tower.get("stats") or tower.stats.id != "queen": continue
				tower.apply_boon_buff({"damage_bonus": float(tower.stats.base_damage), "attack_speed_reduction": 0.0})
				tower.set("boon_burn_override", true)
			get_tree().create_timer(BOON_DURATION).timeout.connect(_on_boon_expired)

		_:
			# Fallback generic boon cho các king chưa define
			for tower in get_tree().get_nodes_in_group("towers"):
				if is_instance_valid(tower) and tower.has_method("apply_boon_buff"):
					tower.apply_boon_buff({"damage_bonus": 8.0, "attack_speed_reduction": 0.3})
			get_tree().create_timer(BOON_DURATION).timeout.connect(_on_boon_expired)

func _on_boon_expired() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("remove_boon_buff"):
			tower.remove_boon_buff()
			if tower.get("boon_burn_override") != null:
				tower.set("boon_burn_override", false)

# ==========================================================================
# SIGNAL HANDLERS
# ==========================================================================

func _on_royal_decree_changed(_value: float) -> void:   update_ui()
func _on_ability_cooldown_changed(_remaining: float) -> void: update_ui()

func _on_tower_selected(stats: TowerStats) -> void:
	current_building_stats = stats
	if stats.texture:
		build_preview_sprite.texture = stats.texture
	build_preview_sprite.visible = true

func _on_territory_placed(pos: Vector2i, biome: String) -> void:
	# Apply biome buff to any tower already on that tile
	var entry = grid_data.get(pos)
	if entry is Node2D and is_instance_valid(entry):
		_apply_biome_buff_to_tower(entry, biome)
	update_ui()
	queue_redraw()

func _on_territories_changed(biome_counts: Dictionary) -> void:
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("refresh_territories"):
		hud.refresh_territories(biome_counts)

func _on_territory_stock_changed(stock: Dictionary) -> void:
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("refresh_territory_stock"):
		hud.refresh_territory_stock(stock)

func _on_synergy_buffs_updated() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.has_method("apply_synergy_buff"): continue
		var buff = synergy_manager.get_tower_synergy_buff(tower)
		tower.apply_synergy_buff(buff)
	_refresh_commander_aura()

func _on_encounter_resolved(_choice) -> void:
	_show_shop_after_encounter()

func _on_gm_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.PREPARING and current_phase == GamePhase.SHOP:
		if _game_manager and _game_manager.current_state != GameManager.GameState.GAME_OVER:
			_show_shop_after_encounter()

# ==========================================================================
# GAME STATE
# ==========================================================================

func game_over() -> void:
	if _game_over_triggered:
		return
	_game_over_triggered = true
	var _hud = get_node_or_null("HUD")
	if _hud:
		if _hud.has_method("hide_shop_panel"): _hud.hide_shop_panel()
		if _hud.has_method("hide_shop_popup"): _hud.hide_shop_popup()
	if _game_manager:
		_game_manager.force_game_over()
	else:
		get_tree().paused = true

func _initialize_from_game_manager() -> void:
	if not _game_manager:
		return
	current_health = _game_manager.current_health
	current_gold   = _game_manager.current_gold
	var king = _game_manager.selected_king
	if king and king_manager:
		king_manager.initialize_from_king_stats(king)
	_grant_starting_units()

func _grant_starting_units() -> void:
	if not shop_manager or not _game_manager:
		return
	var king = _game_manager.selected_king
	if not king:
		return
	var ids:        Array = king.starting_unit_ids
	var quantities: Array = king.starting_unit_quantities
	for i in ids.size():
		var unit_id    = ids[i]
		var count: int = quantities[i] if i < quantities.size() else 1
		var stats_path = "res://res/towers/%s.tres" % unit_id
		if not ResourceLoader.exists(stats_path): continue
		var stats = load(stats_path) as TowerStats
		if not stats: continue
		for j in count:
			shop_manager.register_troop_purchase(stats)

# ==========================================================================
# DRAWING
# ==========================================================================

func _draw() -> void:
	# Background
	var bg_rect = Rect2(Vector2(-8000, -8000), Vector2(16000, 16000))
	if _bg_tex:
		draw_texture_rect(_bg_tex, bg_rect, true)
	else:
		draw_rect(bg_rect, Color(0.11, 0.094, 0.078, 1.0), true)

	# Build mode: highlight valid tiles
	if current_building_stats:
		for y in range(grid_height):
			for x in range(grid_width):
				var pos = Vector2i(x, y)
				if layer_grass.get_cell_source_id(pos) == -1: continue
				if grid_data.get(pos) is Node2D:             continue
				var center = layer_grass.map_to_local(pos)
				draw_rect(Rect2(center - Vector2(8,8), Vector2(16,16)), Color(1.0,0.85,0.0,0.18), true)
				draw_rect(Rect2(center - Vector2(8,8), Vector2(16,16)), Color(1.0,0.85,0.0,0.75), false, 1.2)

	# Build mode: range preview circle
	if current_building_stats and build_preview_sprite and build_preview_sprite.visible:
		var radius = current_building_stats.attack_range * TILE_SIZE + (TILE_SIZE / 2.0)
		draw_circle(build_preview_sprite.position, radius, Color(0,1,0,0.1))
		draw_arc(build_preview_sprite.position, radius, 0, TAU, 32, Color(0,1,0,0.5), 1.0)

	# Territory placement: highlight valid tiles
	if territory_manager and territory_manager.is_placing():
		var biome_tag = territory_manager.get_pending_biome()
		var bdata     = TerritoryManager.BIOME_STATS.get(biome_tag, null)
		var hi_col    = Color(0.3, 0.85, 0.4, 1.0)
		if bdata:
			var bc = bdata["color"]
			hi_col = Color(bc.r, bc.g, bc.b, 1.0)
		var font_t = ThemeDB.fallback_font
		for vpos in territory_manager.get_available_tiles(grid_data):
			var vcenter = layer_grass.map_to_local(vpos)
			var vrect   = Rect2(vcenter - Vector2(8,8), Vector2(16,16))
			draw_rect(vrect, Color(hi_col.r, hi_col.g, hi_col.b, 0.5), true)
			draw_rect(vrect, hi_col, false, 2.0)
			if font_t:
				draw_string(font_t, vcenter - Vector2(3,-3), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1,1,1,0.95))

	# Dismiss mode: highlight towers + hover X
	if _dismiss_mode:
		var font_d = ThemeDB.fallback_font
		for pos in grid_data.keys():
			var e = grid_data.get(pos)
			if not (e is Node2D and is_instance_valid(e)): continue
			var dc    = layer_grass.map_to_local(pos)
			var drect = Rect2(dc - Vector2(8,8), Vector2(16,16))
			draw_rect(drect, Color(1.0,0.1,0.1,0.25), true)
			draw_rect(drect, Color(1.0,0.1,0.1,0.85), false, 1.5)
		var dm_mouse = get_global_mouse_position()
		var dm_grid  = layer_grass.local_to_map(layer_grass.to_local(dm_mouse))
		var dm_entry = grid_data.get(dm_grid)
		if dm_entry is Node2D and is_instance_valid(dm_entry):
			var dc2 = layer_grass.map_to_local(dm_grid)
			draw_rect(Rect2(dc2 - Vector2(8,8), Vector2(16,16)), Color(1.0,0.1,0.1,0.55), true)
			draw_line(dc2 - Vector2(5,5), dc2 + Vector2(5,5), Color(1,1,1,1.0), 2.0)
			draw_line(dc2 + Vector2(5,-5), dc2 - Vector2(5,-5), Color(1,1,1,1.0), 2.0)
		elif font_d:
			var dc3 = layer_grass.map_to_local(dm_grid)
			draw_string(font_d, dc3 - Vector2(4,-4), "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1,0.3,0.3,0.6))

	# Base tile (end of enemy path)
	if not current_path_grid.is_empty():
		var base_pos    = current_path_grid.back()
		var base_center = layer_base.map_to_local(base_pos)
		var base_rect   = Rect2(base_center - Vector2(8,8), Vector2(16,16))
		draw_rect(base_rect, Color(0.85,0.05,0.05,0.65), true)
		draw_rect(base_rect, Color(1.0,0.15,0.15,1.0), false, 2.2)
		var base_font = ThemeDB.fallback_font
		if base_font:
			draw_string(base_font, base_center - Vector2(4,-4), "⚑", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1,1,1,0.95))
