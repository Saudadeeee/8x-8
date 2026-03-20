# res://scripts/managers/GridManager.gd
# DEPRECATED — Chức năng đã được chuyển sang scripts/map/territory_manager.gd
# File này không còn được sử dụng và có thể xóa an toàn.
extends Node
class_name GridManager

# --- SIGNALS ---
signal grid_expanded(new_size: Vector2i)
signal tile_updated(grid_pos: Vector2i, tile_type: String)
signal territory_placed(grid_pos: Vector2i, territory: TerritoryStats)

# --- LOẠI Ô ---
enum TileType {
	EMPTY,      # Ô trống có thể đặt quân
	PATH,       # Đường đi của quái
	SOLDIER,    # Ô đang có quân
	TERRITORY,  # Ô lãnh thổ đặc biệt
	BLOCKED     # Ô không thể dùng
}

# --- TILESET (phải khớp với game_map.gd) ---
const _SOURCE_ID := 1
const _ATLAS_ROAD  := Vector2i(6, 2)
const _ATLAS_WHITE := Vector2i(9, 0)
const _ATLAS_BLACK := Vector2i(9, 1)

# --- THAM CHIẾU ---
@export var layer_base: TileMapLayer
@export var layer_grass: TileMapLayer
@export var layer_territory: TileMapLayer   # Layer riêng để vẽ Territory tiles

# --- DỮ LIỆU LƯỚI ---
# Key: Vector2i, Value: { "type": TileType, "soldier": Node, "territory": TerritoryStats }
var grid_data: Dictionary = {}
var grid_size: Vector2i = Vector2i(8, 8)
var current_path: Array[Vector2i] = []

# Sprite2D nodes hiển thị territory texture (key: Vector2i)
var _territory_sprites: Dictionary = {}

# --- KHỞI TẠO ---
func setup_grid(path: Array[Vector2i], size: Vector2i) -> void:
	grid_data.clear()
	grid_size = size
	current_path = path
	for pos in path:
		_set_tile_type(pos, TileType.PATH)

# --- MỞ RỘNG LƯỚI ---
func expand_grid(additional_rows: int) -> void:
	var old_height := grid_size.y
	grid_size.y += additional_rows

	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		gm.current_grid_size = grid_size

	# Vẽ tiles mới cho các hàng vừa thêm
	if layer_base and layer_grass:
		for y in range(old_height, grid_size.y):
			for x in range(grid_size.x):
				var pos := Vector2i(x, y)
				layer_base.set_cell(pos, _SOURCE_ID, _ATLAS_ROAD)
				var tile_coord := _ATLAS_WHITE if (x + y) % 2 == 0 else _ATLAS_BLACK
				layer_grass.set_cell(pos, _SOURCE_ID, tile_coord)

	grid_expanded.emit(grid_size)

# --- QUẢN LÝ QUÂN ---
func place_soldier(grid_pos: Vector2i, soldier: Node) -> bool:
	if not can_place_at(grid_pos):
		return false
	_set_tile_data(grid_pos, TileType.SOLDIER, { "soldier": soldier })
	tile_updated.emit(grid_pos, "soldier")
	return true

func remove_soldier(grid_pos: Vector2i) -> void:
	if grid_data.has(grid_pos):
		grid_data[grid_pos]["type"] = TileType.EMPTY
		grid_data[grid_pos]["soldier"] = null
	tile_updated.emit(grid_pos, "empty")

# --- QUẢN LÝ LÃNH THỔ ---
func place_territory(grid_pos: Vector2i, territory: TerritoryStats) -> void:
	if not grid_data.has(grid_pos):
		_set_tile_type(grid_pos, TileType.TERRITORY)
	grid_data[grid_pos]["territory"] = territory
	_render_territory_sprite(grid_pos, territory)
	territory_placed.emit(grid_pos, territory)

func _render_territory_sprite(grid_pos: Vector2i, territory: TerritoryStats) -> void:
	# Xóa sprite cũ nếu tồn tại
	if _territory_sprites.has(grid_pos):
		var old: Node = _territory_sprites[grid_pos]
		if is_instance_valid(old):
			old.queue_free()
		_territory_sprites.erase(grid_pos)

	if not territory or not territory.tile_texture:
		return
	if not layer_grass:
		push_warning("GridManager: layer_grass chưa được set, không thể render territory.")
		return

	var spr := Sprite2D.new()
	spr.texture = territory.tile_texture
	spr.z_index = -1
	spr.position = layer_grass.map_to_local(grid_pos)
	add_child(spr)
	_territory_sprites[grid_pos] = spr

func remove_territory(grid_pos: Vector2i) -> void:
	if _territory_sprites.has(grid_pos):
		var spr: Node = _territory_sprites[grid_pos]
		if is_instance_valid(spr):
			spr.queue_free()
		_territory_sprites.erase(grid_pos)
	if grid_data.has(grid_pos):
		grid_data[grid_pos].erase("territory")
		if grid_data[grid_pos].get("type") == TileType.TERRITORY:
			grid_data[grid_pos]["type"] = TileType.EMPTY
	tile_updated.emit(grid_pos, "empty")

func get_territory_at(grid_pos: Vector2i) -> TerritoryStats:
	if grid_data.has(grid_pos):
		return grid_data[grid_pos].get("territory", null)
	return null

# --- KIỂM TRA ---
func can_place_at(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= grid_size.x:
		return false
	if grid_pos.y < 0 or grid_pos.y >= grid_size.y:
		return false
	var tile = grid_data.get(grid_pos, { "type": TileType.EMPTY })
	return tile["type"] == TileType.EMPTY or tile["type"] == TileType.TERRITORY

func get_tile_type(grid_pos: Vector2i) -> TileType:
	return grid_data.get(grid_pos, { "type": TileType.EMPTY })["type"]

func get_soldier_at(grid_pos: Vector2i) -> Node:
	return grid_data.get(grid_pos, {}).get("soldier", null)

# --- TIỆN ÍCH ---
func _set_tile_type(pos: Vector2i, type: TileType) -> void:
	if not grid_data.has(pos):
		grid_data[pos] = {}
	grid_data[pos]["type"] = type

func _set_tile_data(pos: Vector2i, type: TileType, extra: Dictionary) -> void:
	_set_tile_type(pos, type)
	for key in extra:
		grid_data[pos][key] = extra[key]
