# res://scripts/map/tower_placer.gd
# Placement, dismiss, upgrade tháp + Commander aura + build preview sprite.
# Được game_map.gd khởi tạo và làm con node.
extends Node
class_name TowerPlacer

# --- SIGNALS ---
signal tower_placed(grid_pos: Vector2i, tower: Node3D)
signal tower_dismissed(grid_pos: Vector2i, refund_gold: int)
signal dismiss_stock_changed(new_stock: int)
signal build_mode_changed(stats: TowerStats)  # null = build mode tắt

# --- CONSTANTS ---
const COMMANDER_AURA_SPEED_BONUS: float = 0.25
const PREVIEW_HEIGHT: float = 0.5
const MODEL_DIR := "res://assets/models/%s.gltf"
const GHOST_VALID   := Color(0.35, 1.0, 0.45, 0.55)
const GHOST_INVALID := Color(1.0, 0.25, 0.25, 0.55)

# --- STATE ---
var current_building_stats: TowerStats = null
var tower_upgrades:         Dictionary = {}
var _dismiss_mode:  bool = false
var _dismiss_stock: int  = 0

# --- REFS (set bởi game_map sau add_child) ---
var king_manager:      KingManager      = null
var territory_manager                   = null
var synergy_manager:   SynergyManager   = null
var shop_manager:      ShopPanelManager = null
var grid_data:         Dictionary       = {}     # reference tới GridController.grid_data
var grid_controller                     = null
var build_preview_sprite: Sprite3D      = null   # owned by game_map (Node3D child)

var _tower_scene = preload("res://scenes/tower/tower_base.tscn")
const _TM = preload("res://scripts/map/territory_manager.gd")

# Ghost 3D preview (model trong suốt) — thay billboard khi model tồn tại
var _ghost: Node3D = null
var _ghost_mats: Array[BaseMaterial3D] = []

func setup(
		km:      KingManager,
		tm,
		sm:      SynergyManager,
		shop:    ShopPanelManager,
		gd_ref:  Dictionary,
		gc,
		preview: Sprite3D) -> void:
	king_manager         = km
	territory_manager    = tm
	synergy_manager      = sm
	shop_manager         = shop
	grid_data            = gd_ref
	grid_controller      = gc
	build_preview_sprite = preview

# --- BUILD MODE ---

func start_build(stats: TowerStats) -> void:
	_dismiss_mode          = false
	current_building_stats = stats
	_free_ghost()
	if stats and _try_build_ghost(stats):
		if build_preview_sprite:
			build_preview_sprite.visible = false
	elif build_preview_sprite:
		if stats and stats.texture:
			build_preview_sprite.texture = stats.texture
		build_preview_sprite.visible = true
	build_mode_changed.emit(stats)

func cancel_build() -> void:
	_dismiss_mode          = false
	current_building_stats = null
	_free_ghost()
	if build_preview_sprite:
		build_preview_sprite.visible = false
	if territory_manager:
		territory_manager.cancel()
	build_mode_changed.emit(null)

## Ghost = model 3D trong suốt, tint xanh/đỏ theo validity. Trả false nếu không có model.
func _try_build_ghost(stats: TowerStats) -> bool:
	var model_path := MODEL_DIR % stats.id
	if not ResourceLoader.exists(model_path):
		return false
	var scene := load(model_path) as PackedScene
	if scene == null:
		return false
	_ghost = Node3D.new()
	_ghost.name = "BuildGhost"
	var model := scene.instantiate()
	_ghost.add_child(model)
	_ghost_mats.clear()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var src: Material = (mi as MeshInstance3D).get_active_material(0)
		if src is BaseMaterial3D:
			var dup := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dup.albedo_color = GHOST_VALID
			(mi as MeshInstance3D).material_override = dup
			_ghost_mats.append(dup)
	get_parent().add_child(_ghost)
	_ghost.visible = false
	return true

func _free_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_mats.clear()

## Gọi từ game_map._process() mỗi frame khi đang build mode.
func update_preview(mouse_pos: Vector2) -> void:
	if not current_building_stats:
		return
	var has_ghost := _ghost != null and is_instance_valid(_ghost)
	if not has_ghost and (not build_preview_sprite or not build_preview_sprite.visible):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var grid_pos := GridUtil.mouse_to_cell(camera, mouse_pos)

	var gc         = grid_controller
	var valid_pos: bool = grid_pos.x >= 0 and grid_pos.x < gc.grid_width \
		and grid_pos.y >= 0 and grid_pos.y < gc.grid_height
	var decree_ok: bool = king_manager and king_manager.can_afford(current_building_stats.decree_cost)
	var ok: bool = valid_pos and is_buildable(grid_pos) \
		and not (grid_data.get(grid_pos) is Node3D) and decree_ok

	if has_ghost:
		_ghost.visible = valid_pos
		_ghost.position = GridUtil.cell_to_world(grid_pos)
		var tint := GHOST_VALID if ok else GHOST_INVALID
		for m in _ghost_mats:
			m.albedo_color = tint
	else:
		build_preview_sprite.position = GridUtil.cell_to_world(grid_pos) + Vector3(0.0, PREVIEW_HEIGHT, 0.0)
		build_preview_sprite.modulate = Color(0, 1, 0, 0.6) if ok else Color(1, 0, 0, 0.6)

## Đặt tháp tại grid_pos — gọi khi player click trong build mode.
func place(grid_pos: Vector2i) -> void:
	if current_building_stats == null:
		return

	if shop_manager and shop_manager.is_unit_limited(current_building_stats.id):
		if not shop_manager.consume_unit_stock(current_building_stats.id):
			push_warning("TowerPlacer: Không còn %s để đặt." % current_building_stats.name)
			return

	if king_manager and not king_manager.spend_royal_decree(current_building_stats.decree_cost):
		push_warning("TowerPlacer: Không đủ Royal Decree! Cần: %.1f" % current_building_stats.decree_cost)
		return

	var new_tower = _tower_scene.instantiate()
	new_tower.stats = current_building_stats
	get_parent().add_child(new_tower)
	new_tower.position = GridUtil.cell_to_world(grid_pos)
	grid_data[grid_pos] = new_tower

	if new_tower.has_method("load_tower_data"):
		new_tower.load_tower_data()
		_apply_upgrade_to_tower(new_tower)

	if king_manager:
		king_manager.apply_favor_to_tower(new_tower)

	var biome: String = territory_manager.get_biome_at(grid_pos) if territory_manager else ""
	if biome != "":
		_apply_biome_buff_to_tower(new_tower, biome)

	if synergy_manager and current_building_stats:
		synergy_manager.on_tower_placed(new_tower, current_building_stats)

	_refresh_commander_aura()
	tower_placed.emit(grid_pos, new_tower)

func is_in_build_mode() -> bool:
	return current_building_stats != null

func is_in_dismiss_mode() -> bool:
	return _dismiss_mode

# --- DISMISS MODE ---

func enter_dismiss_mode() -> void:
	if _dismiss_stock <= 0:
		return
	current_building_stats = null
	_free_ghost()
	if build_preview_sprite:
		build_preview_sprite.visible = false
	if territory_manager:
		territory_manager.cancel()
	_dismiss_mode = true
	build_mode_changed.emit(null)

func dismiss_at(grid_pos: Vector2i) -> void:
	var entry = grid_data.get(grid_pos)
	if entry is Node3D and is_instance_valid(entry):
		if synergy_manager:
			synergy_manager.on_tower_removed(entry)
		var reward := 0
		if entry.get("stats") and entry.stats:
			reward = int(entry.stats.cost * 0.5)
		entry.queue_free()
		grid_data.erase(grid_pos)
		_dismiss_stock = max(0, _dismiss_stock - 1)
		if _dismiss_stock <= 0:
			_dismiss_mode = false
		_refresh_commander_aura()
		dismiss_stock_changed.emit(_dismiss_stock)
		tower_dismissed.emit(grid_pos, reward)
	else:
		_dismiss_mode = false
		dismiss_stock_changed.emit(_dismiss_stock)

func add_dismiss_stock(amount: int = 1) -> void:
	_dismiss_stock += amount
	dismiss_stock_changed.emit(_dismiss_stock)

# --- UPGRADES ---

func apply_upgrade(item: ShopItemData) -> void:
	if not item or not item.tower_stats:
		return
	var key      := item.tower_stats.id
	var existing := tower_upgrades.get(key, {"damage_bonus": 0.0, "attack_speed_reduction": 0.0}) as Dictionary
	var updated  := {
		"damage_bonus":           existing.get("damage_bonus",           0.0) + float(item.upgrade_damage_bonus),
		"attack_speed_reduction": existing.get("attack_speed_reduction", 0.0) + item.upgrade_attack_speed_reduction,
	}
	tower_upgrades[key] = updated
	_apply_upgrade_to_existing_towers(key, updated)

# Gọi sau khi synergy buffs thay đổi để apply lại toàn bộ
func refresh_synergy_and_aura(synergy_manager_ref: SynergyManager) -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(tower) or not tower.has_method("apply_synergy_buff"):
			continue
		var buff: Dictionary = synergy_manager_ref.get_tower_synergy_buff(tower)
		tower.apply_synergy_buff(buff)
	_refresh_commander_aura()

# Gọi khi territory đặt lên ô đã có tower
func reapply_biome_buff_to_tower(tower: Node3D, biome_key: String) -> void:
	_apply_biome_buff_to_tower(tower, biome_key)

# --- BUILDABLE CHECK ---

func is_buildable(grid_pos: Vector2i) -> bool:
	# Tương đương check "có grass tile" cũ: trong grid và không phải ô path.
	return grid_controller and grid_controller.is_in_bounds(grid_pos) \
		and not grid_controller.is_path_cell(grid_pos)

# --- INTERNAL HELPERS ---

func _apply_biome_buff_to_tower(tower: Node3D, biome_key: String) -> void:
	if not tower or not tower.has_method("apply_biome_buff"):
		return
	var biome_data = _TM.BIOME_STATS.get(biome_key, null)
	if biome_data:
		tower.apply_biome_buff(biome_data)

func _apply_upgrade_to_existing_towers(stats_id: String, upgrade_data: Dictionary) -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if not tower or not is_instance_valid(tower): continue
		if not tower.has_method("apply_upgrade"):      continue
		if tower.get("stats") and tower.stats.id == stats_id:
			tower.apply_upgrade(upgrade_data)

func _apply_upgrade_to_tower(tower: Node3D) -> void:
	if not tower or not is_instance_valid(tower): return
	if not tower.has_method("apply_upgrade"):      return
	if not tower.get("stats"):                     return
	var upgrade_data = tower_upgrades.get(tower.stats.id)
	if upgrade_data:
		tower.apply_upgrade(upgrade_data)

## Public: gọi từ game_map khi tower bị xoá ngoài luồng dismiss (vd. map expand).
func refresh_commander_aura() -> void:
	_refresh_commander_aura()

func _refresh_commander_aura() -> void:
	# Bước 1: xoá aura cũ khỏi tất cả towers
	for tower in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(tower) and tower.has_method("clear_aura_buff"):
			tower.clear_aura_buff()
	# Bước 2: tìm Commander, apply aura cho 8 ô kề
	for pos in grid_data.keys():
		var entry = grid_data.get(pos)
		if not (entry is Node3D) or not is_instance_valid(entry): continue
		if not entry.get("stats") or entry.stats.id != "commander": continue
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var adj = grid_data.get(Vector2i(pos.x + dx, pos.y + dy))
				if not (adj is Node3D) or not is_instance_valid(adj): continue
				if adj.has_method("apply_aura_buff"):
					adj.apply_aura_buff({"attack_speed_reduction": COMMANDER_AURA_SPEED_BONUS})
