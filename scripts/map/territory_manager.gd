# res://scripts/map/territory_manager.gd
# Quản lý toàn bộ hệ thống Territory/Biome: placement, visual 3D, stock, buff.
# Territory visual = MeshInstance3D box mỏng (1.0 × 0.04 × 1.0) đặt trên mặt tile.
# Được game_map.gd khởi tạo và làm con node.
extends Node
class_name TerritoryManager  # registered globally — dùng để type-check và access BIOME_STATS từ các file khác

# --- SIGNALS ---
signal territory_placed(pos: Vector2i, biome: String)
signal territories_changed(biome_counts: Dictionary)
signal stock_changed(stock: Dictionary)

# --- CONSTANTS ---
const BIOME_KEYS: Array[String] = ["fire", "swamp", "ice", "forest", "desert", "thunder"]
const BIOME_STATS: Dictionary = {
	"fire":    {"name": "Hỏa Địa",    "desc": "+6 Sát thương",            "damage_bonus": 6, "attack_speed_reduction": 0.0, "range_bonus": 0, "color": Color(0.9, 0.3, 0.05, 0.35)},
	"swamp":   {"name": "Đầm Lầy",    "desc": "+0.2s Tốc độ tấn công",    "damage_bonus": 0, "attack_speed_reduction": 0.2, "range_bonus": 0, "color": Color(0.2, 0.6, 0.1,  0.35)},
	"ice":     {"name": "Băng Nguyên","desc": "+2 Tầm bắn",               "damage_bonus": 0, "attack_speed_reduction": 0.0, "range_bonus": 2, "color": Color(0.4, 0.7, 1.0,  0.35)},
	"forest":  {"name": "Rừng Rậm",   "desc": "+3 Sát thương / +1 Tầm",  "damage_bonus": 3, "attack_speed_reduction": 0.0, "range_bonus": 1, "color": Color(0.15, 0.7, 0.1, 0.35)},
	"desert":  {"name": "Sa Mạc",     "desc": "+4 Sát thương / -0.1s CD", "damage_bonus": 4, "attack_speed_reduction": 0.1, "range_bonus": 0, "color": Color(0.9, 0.75, 0.2, 0.35)},
	"thunder": {"name": "Lôi Vực",    "desc": "+3 Sát thương / +1 Tầm",  "damage_bonus": 3, "attack_speed_reduction": 0.0, "range_bonus": 1, "color": Color(0.55, 0.25, 1.0, 0.35)},
}

const TILE_HEIGHT: float = 0.04
const TILE_Y:      float = 0.052

# --- REFS ---
var grid_controller: GridController = null
var _parent_node: Node3D = null  # game_map — nơi add_child visual

# --- STATE ---
var owned_tiles: Dictionary = {}       # Vector2i → true
var biome_tiles: Dictionary = {}       # Vector2i → biome_key String
var _territory_stock: Dictionary = {}  # biome_key → int
var _territory_textures: Dictionary = {} # biome_key → Texture2D
var _territory_meshes: Dictionary = {}   # Vector2i → MeshInstance3D
var _territory_preview: MeshInstance3D = null
var _preview_material: StandardMaterial3D = null
var _preview_base_color: Color = Color(1, 1, 1, 0.8)
var _tile_box: BoxMesh = null
var _placement_mode: bool = false
var _pending_biome: String = ""

# --- SETUP ---
func setup(gc: GridController, parent: Node3D) -> void:
	grid_controller = gc
	_parent_node = parent
	_tile_box = BoxMesh.new()
	_tile_box.size = Vector3(1.0, TILE_HEIGHT, 1.0)
	_load_textures()
	_setup_preview()

func _load_textures() -> void:
	for key in BIOME_KEYS:
		var path = "res://assets/tiles/territory_%s.png" % key
		if ResourceLoader.exists(path):
			_territory_textures[key] = load(path) as Texture2D
		else:
			var img = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				_territory_textures[key] = ImageTexture.create_from_image(img)

func _setup_preview() -> void:
	_territory_preview = MeshInstance3D.new()
	_territory_preview.mesh = _tile_box
	_preview_material = _make_biome_material("", true)
	_territory_preview.material_override = _preview_material
	_territory_preview.visible = false
	_parent_node.add_child(_territory_preview)

func _make_biome_material(biome: String, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	var tex: Texture2D = _territory_textures.get(biome, null)
	if tex:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.albedo_color = Color.WHITE
	else:
		var biome_color: Color = BIOME_STATS.get(biome, {}).get("color", Color(0.5, 0.5, 0.5, 0.5))
		mat.albedo_color = Color(biome_color.r, biome_color.g, biome_color.b, 1.0)
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

# --- KHỞI TẠO LÃNH THỔ ĐẦU GAME ---
func initialize(count: int, grid_data: Dictionary, km: KingManager, bottom_y: int = 4) -> void:
	var candidates: Array[Vector2i] = []
	for pos in grid_data.keys():
		if not (pos is Vector2i): continue
		var p := pos as Vector2i
		if p.y < bottom_y: continue
		if grid_data.get(p) == "path": continue
		candidates.append(p)
	candidates.shuffle()

	var given = 0
	var registered: Array[Vector2i] = []
	for pos in candidates:
		if given >= count:
			break
		var biome = BIOME_KEYS[randi() % BIOME_KEYS.size()]
		owned_tiles[pos] = true
		biome_tiles[pos] = biome
		_create_tile_visual(pos, biome)
		registered.append(pos)
		given += 1

	if km and registered.size() > 0:
		for pos in registered:
			var arr: Array[Vector2i] = [pos]
			km.register_territories(arr, biome_tiles[pos])

	_emit_territories_changed()

# --- STOCK ---
func add_stock(biome: String) -> void:
	_territory_stock[biome] = _territory_stock.get(biome, 0) + 1
	stock_changed.emit(_territory_stock.duplicate())

func get_stock(biome: String) -> int:
	return _territory_stock.get(biome, 0)

func get_all_stock() -> Dictionary:
	return _territory_stock.duplicate()

# --- PLACEMENT MODE ---
func select(biome_key: String) -> void:
	if _territory_stock.get(biome_key, 0) <= 0:
		return
	_placement_mode = true
	_pending_biome = biome_key
	if _territory_preview:
		_preview_material = _make_biome_material(biome_key, true)
		_preview_base_color = Color(
			_preview_material.albedo_color.r,
			_preview_material.albedo_color.g,
			_preview_material.albedo_color.b, 0.8)
		_preview_material.albedo_color = _preview_base_color
		_territory_preview.material_override = _preview_material
		_territory_preview.visible = true

func cancel() -> void:
	_placement_mode = false
	_pending_biome = ""
	if _territory_preview:
		_territory_preview.visible = false

func is_placing() -> bool:
	return _placement_mode

func get_pending_biome() -> String:
	return _pending_biome

## Cập nhật preview theo ô đang hover — game_map tính cell từ ray chuột và truyền vào.
func update_preview(cell: Vector2i, grid_data: Dictionary) -> void:
	if not _territory_preview or not _preview_material:
		return
	_territory_preview.position = GridUtil.cell_to_world(cell) + Vector3(0.0, TILE_Y, 0.0)
	if get_available_tiles(grid_data).has(cell):
		_preview_material.albedo_color = _preview_base_color
	else:
		_preview_material.albedo_color = Color(1, 0.2, 0.2, 0.5)

func get_preview_node() -> MeshInstance3D:
	return _territory_preview

# --- ĐẶT TERRITORY ---
func try_place(pos: Vector2i, grid_data: Dictionary, km: KingManager) -> bool:
	if not get_available_tiles(grid_data).has(pos):
		return false
	_place_at(pos, _pending_biome, grid_data, km)
	return true

func _place_at(pos: Vector2i, biome_key: String, _grid_data: Dictionary, km: KingManager) -> void:
	owned_tiles[pos] = true
	biome_tiles[pos] = biome_key

	if km:
		var arr: Array[Vector2i] = [pos]
		km.register_territories(arr, biome_key)

	_create_tile_visual(pos, biome_key)

	# Cập nhật stock và placement mode
	_territory_stock[biome_key] = max(0, _territory_stock.get(biome_key, 0) - 1)
	if _territory_stock.get(biome_key, 0) > 0:
		if _territory_preview and _preview_material:
			_preview_material.albedo_color = _preview_base_color
			_territory_preview.visible = true
	else:
		cancel()

	territory_placed.emit(pos, biome_key)
	stock_changed.emit(_territory_stock.duplicate())
	_emit_territories_changed()

# --- QUERY ---
func get_available_tiles(grid_data: Dictionary) -> Array[Vector2i]:
	# Mọi ô trong grid trừ ô path và ô đã có biome.
	# Ô có tower vẫn hợp lệ (giống hành vi get_used_cells() của layer_grass cũ).
	var results: Array[Vector2i] = []
	if not grid_controller:
		return results
	for x in range(grid_controller.grid_width):
		for y in range(grid_controller.grid_height):
			var p := Vector2i(x, y)
			if grid_data.get(p) is String and grid_data.get(p) == "path": continue
			if biome_tiles.has(p): continue
			results.append(p)
	return results

func get_biome_at(pos: Vector2i) -> String:
	return biome_tiles.get(pos, "")

func has_biome_at(pos: Vector2i) -> bool:
	return biome_tiles.has(pos)

func get_biome_counts() -> Dictionary:
	var counts: Dictionary = {}
	for pos in biome_tiles:
		var b: String = biome_tiles[pos]
		counts[b] = counts.get(b, 0) + 1
	return counts

# --- VISUAL ---
func _create_tile_visual(pos: Vector2i, biome: String) -> void:
	# Xóa visual cũ nếu có
	if _territory_meshes.has(pos):
		var old = _territory_meshes[pos]
		if is_instance_valid(old):
			old.queue_free()
		_territory_meshes.erase(pos)

	var tile := MeshInstance3D.new()
	tile.mesh = _tile_box
	tile.material_override = _make_biome_material(biome, false)
	tile.position = GridUtil.cell_to_world(pos) + Vector3(0.0, TILE_Y, 0.0)
	_parent_node.add_child(tile)
	_territory_meshes[pos] = tile

# --- CLEAR (khi tạo map mới) ---
func clear_all() -> void:
	for tile in _territory_meshes.values():
		if is_instance_valid(tile):
			tile.queue_free()
	_territory_meshes.clear()
	owned_tiles.clear()
	biome_tiles.clear()
	cancel()

# --- HUD HELPERS ---
func _emit_territories_changed() -> void:
	territories_changed.emit(get_biome_counts())
