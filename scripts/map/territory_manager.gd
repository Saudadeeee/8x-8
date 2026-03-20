# res://scripts/map/territory_manager.gd
# Quản lý toàn bộ hệ thống Territory/Biome: placement, sprite, stock, buff.
# Được game_map.gd khởi tạo và làm con node.
extends Node

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

# --- REFS ---
var layer_grass: TileMapLayer = null
var _parent_node: Node = null  # game_map — nơi add_child sprite

# --- STATE ---
var owned_tiles: Dictionary = {}       # Vector2i → true
var biome_tiles: Dictionary = {}       # Vector2i → biome_key String
var _territory_stock: Dictionary = {}  # biome_key → int
var _territory_textures: Dictionary = {} # biome_key → Texture2D
var _territory_sprites: Dictionary = {}  # Vector2i → Sprite2D
var _territory_preview: Sprite2D = null
var _placement_mode: bool = false
var _pending_biome: String = ""

# --- SETUP ---
func setup(grass: TileMapLayer, parent: Node) -> void:
	layer_grass = grass
	_parent_node = parent
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
	_territory_preview = Sprite2D.new()
	_territory_preview.z_index = 5
	_territory_preview.visible = false
	_parent_node.add_child(_territory_preview)

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
		_create_sprite(pos, biome)
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
		_territory_preview.texture = _territory_textures.get(biome_key, null)
		_territory_preview.modulate = Color(1, 1, 1, 0.8)
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

func update_preview(global_mouse_pos: Vector2, grid_data: Dictionary) -> void:
	if not _territory_preview or not layer_grass:
		return
	var gpos = layer_grass.local_to_map(layer_grass.to_local(global_mouse_pos))
	_territory_preview.position = layer_grass.map_to_local(gpos)
	if get_available_tiles(grid_data).has(gpos):
		_territory_preview.modulate = Color(1, 1, 1, 0.8)
	else:
		_territory_preview.modulate = Color(1, 0.2, 0.2, 0.5)

func get_preview_node() -> Sprite2D:
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

	_create_sprite(pos, biome_key)

	# Cập nhật stock và placement mode
	_territory_stock[biome_key] = max(0, _territory_stock.get(biome_key, 0) - 1)
	if _territory_stock.get(biome_key, 0) > 0:
		if _territory_preview:
			_territory_preview.modulate = Color(1, 1, 1, 0.8)
			_territory_preview.visible = true
	else:
		cancel()

	territory_placed.emit(pos, biome_key)
	stock_changed.emit(_territory_stock.duplicate())
	_emit_territories_changed()

# --- QUERY ---
func get_available_tiles(_grid_data: Dictionary) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	if not layer_grass:
		return results
	# Dùng layer_grass.get_used_cells() — path tiles đã bị erase_cell nên không xuất hiện ở đây.
	# Empty grass tiles và tower tiles đều hợp lệ để đặt territory.
	for p in layer_grass.get_used_cells():
		if biome_tiles.has(p): continue   # đã có biome
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

# --- SPRITE ---
func _create_sprite(pos: Vector2i, biome: String) -> void:
	# Xóa sprite cũ nếu có
	if _territory_sprites.has(pos):
		var old = _territory_sprites[pos]
		if is_instance_valid(old):
			old.queue_free()
		_territory_sprites.erase(pos)

	var spr = Sprite2D.new()
	var tex = _territory_textures.get(biome, null)
	if tex == null:
		var biome_color: Color = BIOME_STATS.get(biome, {}).get("color", Color(0.5, 0.5, 0.5, 0.5))
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(biome_color)
		tex = ImageTexture.create_from_image(img)
	spr.texture = tex
	spr.z_index = 0
	spr.position = layer_grass.map_to_local(pos)
	_parent_node.add_child(spr)
	_territory_sprites[pos] = spr

# --- CLEAR (khi tạo map mới) ---
func clear_all() -> void:
	for spr in _territory_sprites.values():
		if is_instance_valid(spr):
			spr.queue_free()
	_territory_sprites.clear()
	owned_tiles.clear()
	biome_tiles.clear()
	cancel()

# --- HUD HELPERS ---
func _emit_territories_changed() -> void:
	territories_changed.emit(get_biome_counts())
