# res://scripts/map/grid_controller.gd
# Sở hữu grid_data, current_path_grid và xử lý map generation/expansion.
# Render board 3D: mỗi ô một MeshInstance3D (BoxMesh chia sẻ) dưới BoardRoot.
# Các component khác nhận REFERENCE tới grid_data (Dictionary là reference type).
# Được game_map.gd khởi tạo và làm con node.
extends Node
class_name GridController

# --- SIGNALS ---
signal map_chunk_created(path: Array[Vector2i])
signal map_expanded(new_height: int, new_path: Array[Vector2i])
signal tower_refunded_on_expand(gold_amount: int)
signal tower_removed_on_expand(tower: Node3D)

# --- CONSTANTS ---
const TILE_SIZE:     float = 1.0   # 1 ô = 1.0 m
const MAX_GRID_SIZE: int   = 32
const TILE_THICKNESS: float = 0.1

const COLOR_TILE_WHITE := Color("b8a88a")
const COLOR_TILE_BLACK := Color("4a3f35")
const COLOR_TILE_ROAD  := Color("6b5a3e")
const COLOR_FRAME      := Color("3d2b1f")
const FRAME_THICKNESS: float = 0.4
const FRAME_HEIGHT:    float = 0.24

const KING_MODEL_PATH    := "res://assets/models/king.gltf"
const KING_FALLBACK_TEX  := "res://assets/towers/flag.png"

# --- GRID STATE (shared by reference với các component khác) ---
var grid_width:        int = 8
var grid_height:       int = 8
var grid_data:         Dictionary      = {}
var current_path_grid: Array[Vector2i] = []

# --- REFS (set bởi game_map sau add_child) ---
var board_root: Node3D = null
var _map_generator: MapGenerator = null

# --- INTERNAL RENDER STATE ---
var _tiles_root: Node3D = null
var _king_visual: Node3D = null
var _tile_mesh: BoxMesh = null
var _mat_white: StandardMaterial3D = null
var _mat_black: StandardMaterial3D = null
var _mat_road:  StandardMaterial3D = null

func setup(board: Node3D, gen: MapGenerator) -> void:
	board_root     = board
	_map_generator = gen
	_ensure_render_resources()

# --- PUBLIC API ---

func create_new_chunk() -> void:
	grid_data.clear()           # in-place clear — references held by other components remain valid
	current_path_grid.clear()

	_map_generator.width              = grid_width
	_map_generator.height             = grid_height
	_map_generator.min_path_length    = max(21, int(grid_width * grid_height / 4.0))
	_map_generator.blocked_positions  = {}

	var start_pos := Vector2i(randi() % grid_width, 0)
	var path       = _map_generator.generate_path(start_pos, grid_height - 1)

	if path.is_empty():
		push_error("GridController: Không tìm được đường đi!")
		return

	current_path_grid = path
	for pos in path:
		grid_data[pos] = "path"
	_rebuild_board()
	map_chunk_created.emit(path)

func expand() -> void:
	if grid_height >= MAX_GRID_SIZE:
		push_warning("GridController: Bản đồ đã đạt kích thước tối đa %d" % MAX_GRID_SIZE)
		return
	if current_path_grid.is_empty():
		push_error("GridController: Không có đường cũ để nối!")
		return

	var old_height := grid_height
	grid_height += 8

	# Thu thập vị trí towers (để tránh chặn path mới)
	var tower_positions: Dictionary = {}
	for pos in grid_data.keys():
		if grid_data[pos] is Node3D:
			tower_positions[pos] = true

	var junction: Vector2i = current_path_grid.back()
	var all_blocked: Dictionary = tower_positions.duplicate()
	for p in current_path_grid:
		if p != junction:
			all_blocked[p] = true

	var old_path_set: Dictionary = {}
	for p in current_path_grid:
		old_path_set[p] = true

	_map_generator.width              = grid_width
	_map_generator.height             = grid_height
	_map_generator.min_y              = old_height - 1
	_map_generator.min_path_length    = 9
	_map_generator.blocked_positions  = all_blocked
	_map_generator.adjacent_blocked   = old_path_set

	var new_segment = _map_generator.generate_extension(junction, grid_height - 1)

	_map_generator.min_y              = 0
	_map_generator.min_path_length    = max(21, int(grid_width * grid_height / 4.0))
	_map_generator.adjacent_blocked   = {}

	if new_segment.is_empty():
		push_error("GridController: Không tạo được đoạn mở rộng — rollback!")
		grid_height             = old_height
		_map_generator.height   = old_height
		_map_generator.blocked_positions = {}
		return

	# Xoá + hoàn tiền tower nằm trên đoạn path mới
	var new_seg_set: Dictionary = {}
	for p in new_segment:
		new_seg_set[p] = true

	for pos in tower_positions.keys():
		if not new_seg_set.has(pos):
			continue
		var tower = grid_data.get(pos)
		if tower and is_instance_valid(tower):
			if tower.get("stats") and tower.stats:
				tower_refunded_on_expand.emit(int(tower.stats.cost * 0.5))
			# Báo cho synergy/aura trước khi free — nếu không buff count bị kẹt vĩnh viễn
			tower_removed_on_expand.emit(tower)
			tower.queue_free()
		grid_data.erase(pos)

	# Nối path mới (bỏ junction trùng với điểm cuối cũ)
	for i in range(1, new_segment.size()):
		current_path_grid.append(new_segment[i])
		grid_data[new_segment[i]] = "path"

	# Vẽ lại toàn bộ bản đồ
	_rebuild_board()

	# Cập nhật vị trí các tower còn lại sau expand
	for pos in grid_data.keys():
		var entry = grid_data[pos]
		if entry is Node3D and is_instance_valid(entry):
			entry.position = GridUtil.cell_to_world(pos)

	map_expanded.emit(grid_height, current_path_grid)

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

## Ô có phải path (đường enemy đi) không.
func is_path_cell(cell: Vector2i) -> bool:
	return grid_data.get(cell) is String and grid_data.get(cell) == "path"

# --- INTERNAL ---

func _ensure_render_resources() -> void:
	if _tile_mesh:
		return
	_tile_mesh = BoxMesh.new()
	_tile_mesh.size = Vector3(TILE_SIZE, TILE_THICKNESS, TILE_SIZE)
	_mat_white = _make_tile_material(COLOR_TILE_WHITE)
	_mat_black = _make_tile_material(COLOR_TILE_BLACK)
	_mat_road  = _make_tile_material(COLOR_TILE_ROAD)

func _make_tile_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat

func _rebuild_board() -> void:
	if not board_root:
		push_error("GridController: board_root chưa được set!")
		return
	_ensure_render_resources()

	if _tiles_root and is_instance_valid(_tiles_root):
		_tiles_root.free()   # free ngay để tránh tile cũ tồn tại thêm 1 frame
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	board_root.add_child(_tiles_root)

	var path_set: Dictionary = {}
	for p in current_path_grid:
		path_set[p] = true

	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			var tile := MeshInstance3D.new()
			tile.mesh = _tile_mesh
			if path_set.has(pos):
				tile.material_override = _mat_road
			else:
				tile.material_override = _mat_white if (x + y) % 2 == 0 else _mat_black
			# Mặt trên tile nằm đúng y = 0
			tile.position = GridUtil.cell_to_world(pos) + Vector3(0.0, -TILE_THICKNESS / 2.0, 0.0)
			_tiles_root.add_child(tile)

	_build_frame()
	_place_king_visual()

## Khung viền gỗ tối quanh board — rebuild cùng tiles khi expand.
func _build_frame() -> void:
	var w := float(grid_width) * TILE_SIZE
	var h := float(grid_height) * TILE_SIZE
	var t := FRAME_THICKNESS
	var frame_mat := _make_tile_material(COLOR_FRAME)
	var y := -TILE_THICKNESS + FRAME_HEIGHT / 2.0 - 0.02
	var sides := [
		# [size, position]
		[Vector3(w + 2.0 * t, FRAME_HEIGHT, t), Vector3(w / 2.0, y, -t / 2.0)],
		[Vector3(w + 2.0 * t, FRAME_HEIGHT, t), Vector3(w / 2.0, y, h + t / 2.0)],
		[Vector3(t, FRAME_HEIGHT, h), Vector3(-t / 2.0, y, h / 2.0)],
		[Vector3(t, FRAME_HEIGHT, h), Vector3(w + t / 2.0, y, h / 2.0)],
	]
	for s in sides:
		var box := BoxMesh.new()
		box.size = s[0]
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = frame_mat
		mi.position = s[1]
		_tiles_root.add_child(mi)

## Đặt model King tại ô cuối path (base). Reposition khi map mở rộng.
func _place_king_visual() -> void:
	if current_path_grid.is_empty():
		return
	var base_cell: Vector2i = current_path_grid.back()

	if not _king_visual or not is_instance_valid(_king_visual):
		_king_visual = Node3D.new()
		_king_visual.name = "KingVisual"
		board_root.add_child(_king_visual)
		if ResourceLoader.exists(KING_MODEL_PATH):
			var scene := load(KING_MODEL_PATH) as PackedScene
			if scene:
				_king_visual.add_child(scene.instantiate())
		if _king_visual.get_child_count() == 0:
			var billboard := Sprite3D.new()
			billboard.pixel_size = 0.03
			billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			billboard.position = Vector3(0.0, 0.5, 0.0)
			if ResourceLoader.exists(KING_FALLBACK_TEX):
				billboard.texture = load(KING_FALLBACK_TEX)
			_king_visual.add_child(billboard)

	_king_visual.position = GridUtil.cell_to_world(base_cell)
