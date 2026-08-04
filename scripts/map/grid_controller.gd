# res://scripts/map/grid_controller.gd
# Sở hữu grid_data, current_path_grid và xử lý map generation/expansion.
# Render board 3D dạng diorama địa hình thật:
#   - Grid  : mỗi ô một MeshInstance3D (BoxMesh chia sẻ) — MẶT TRÊN LUÔN ĐÚNG y = 0.
#   - Skirt : vành đất trang trí SKIRT_WIDTH ô quanh grid, hạ thấp dần + jitter (ngoài gameplay).
#   - Cliff : 4 vách đá dựng đứng + viền đỉnh cliff_top + đáy bịt kín (thay khung gỗ cũ).
#   - Props : cỏ/đá/bụi/cây gom vào MultiMeshInstance3D — KHÔNG collision, KHÔNG chắn tầm nhìn.
#
# BIOME (bản đồ chắp vá): mỗi ô có một biome id trong `cell_biome`. Chunk đầu dùng
# `base_biome` cho toàn board; MỖI LẦN mở rộng, vùng MỚI nhận một biome khác (xem
# BiomeLibrary). Texture / màu / prop của ô đều tra theo biome của chính ô đó, nên
# board dần thành bản đồ nhiều khí hậu ghép lại. Ô blessed/cursed GIỮ texture rune
# riêng — không đổi theo biome.
# Toàn bộ trang trí sinh ra DETERMINISTIC theo (cell - _rebase_total, _map_seed) nên
# _rebuild_board() lúc expand không làm vùng cũ nhảy chỗ — kể cả sau khi rebase.
# Các component khác nhận REFERENCE tới grid_data (Dictionary là reference type).
#
# MỞ RỘNG 4 HƯỚNG (NORTH/SOUTH/WEST/EAST):
#   - Toạ độ ô LUÔN nằm trong [0, grid_width) × [0, grid_height) — không bao giờ âm.
#   - Mở về WEST/NORTH → REBASE: dịch mọi state keyed theo cell đi delta (+8 trên trục
#     tương ứng) rồi mới tăng kích thước. Nhờ vậy tower_placer / map_overlay_drawer /
#     territory_manager (đang duyệt 0..width/height) không cần biết gì về việc rebase.
#   - Hướng được CHẤM ĐIỂM theo khoảng cách ô King tới biên, thử từ tốt nhất; chỉ commit
#     khi đoạn path mới đã sinh xong → thất bại là no-op sạch.
# Được game_map.gd khởi tạo và làm con node.
extends Node
class_name GridController

# --- SIGNALS ---
signal map_chunk_created(path: Array[Vector2i])
signal map_expanded(new_height: int, new_path: Array[Vector2i])
## Toàn bộ toạ độ ô đã bị dịch đi `delta` (mở rộng về WEST/NORTH — xem _rebase).
## Phát NGAY TRƯỚC map_expanded. Mọi hệ thống lưu state keyed theo cell PHẢI dịch theo.
signal map_rebased(delta: Vector2i)
signal tower_refunded_on_expand(gold_amount: int)
signal tower_removed_on_expand(tower: Node3D)
## Đường mới (hiếm khi) đè lên ô lãnh thổ đã mua → TerritoryManager phải dọn + hoàn kho.
signal territory_overwritten_on_expand(cells: Array[Vector2i])
## Một vùng vừa được gán biome: chunk đầu (region = toàn board) hoặc vùng mở rộng mới.
## Phát SAU khi cell_biome + mesh đã cập nhật xong → handler đọc được state cuối cùng.
signal biome_region_added(biome_id: String, region: Rect2i)
## Mở rộng sang vùng khí hậu mới → tặng ô nguyên tố miễn phí (futureplan §2.4).
## `element` là id của ElementTypes, `count` là số ô. Phát SAU biome_region_added.
## CHỈ phát khi MỞ RỘNG — chunk khởi đầu không tặng ô.
signal free_tiles_granted(element: String, count: int)

# --- CONSTANTS: GRID ---
const TILE_SIZE:     float = 1.0   # 1 ô = 1.0 m
## Cap cho CẢ HAI trục (grid_width và grid_height) — map mở rộng được 4 hướng.
const MAX_AXIS:      int   = 24
## Alias giữ tương thích tên cũ (trước đây chỉ dùng cho grid_height).
const MAX_GRID_SIZE: int   = MAX_AXIS
## Số ô thêm vào mỗi lần mở rộng (theo trục của hướng đã chọn).
const EXPAND_STEP:   int   = 8
## Độ dài tối thiểu của đoạn path mới mỗi lần mở rộng.
const EXTENSION_MIN_LENGTH: int = 9
## Điểm phạt cho hướng vừa mở rộng lần trước → bản đồ mở về nhiều hướng khác nhau.
const REPEAT_DIR_PENALTY: int = 7
const TILE_THICKNESS: float = 0.1

## Bốn hướng mở rộng. NORTH/WEST cần rebase (dịch toàn bộ toạ độ) để không sinh ô âm.
enum ExpandDir { NORTH, SOUTH, WEST, EAST }

# Màu nền của từng loại mặt đất KHÔNG còn là hằng số ở đây — mỗi biome tự khai báo
# tint_light / tint_dark / tint_road / tint_cliff / tint_cliff_top trong BiomeLibrary.

# Ô đặc biệt: phước (vàng, buff tháp) / nguyền (tím, nerf tháp nhưng bonus vàng khi kill)
const COLOR_TILE_BLESSED := Color("c8a94a")
const COLOR_TILE_CURSED  := Color("53386b")
const BLESSED_PER_REGION: int = 2
const CURSED_PER_REGION:  int = 1
const BLESSED_DMG_PCT: float =  0.20   # +20% base damage khi tháp đặt trên ô phước
const CURSED_DMG_PCT:  float = -0.15   # -15% base damage khi tháp đặt trên ô nguyền
## Texture rune đã đủ nhận diện → emission chỉ còn nhấn nhẹ, không chói.
const SPECIAL_EMISSION: float = 0.18

# --- CONSTANTS: TEXTURE / MODEL PATHS ---
# Texture nền/vách theo biome đi qua BiomeLibrary.tex_path() — chỉ ô rune là cố định.
const TEX_TERRAIN_BLESSED := "res://assets/textures/terrain/terrain_blessed.png"
const TEX_TERRAIN_CURSED  := "res://assets/textures/terrain/terrain_cursed.png"

const PROP_MODEL_PATH := "res://assets/models/props/%s.gltf"
const KING_MODEL_PATH    := "res://assets/models/king.gltf"
const KING_FALLBACK_TEX  := "res://assets/towers/flag.png"

# --- CONSTANTS: SKIRT (vành đất trang trí) ---
const SKIRT_WIDTH:       int   = 4
const SKIRT_THICKNESS:   float = 0.30    # dày để bậc thang không bị hở khe
const SKIRT_STEP_Y:      float = -0.05   # mỗi ô ra xa hạ thêm 5 cm
const SKIRT_JITTER:      float = 0.04    # ngoài vùng gameplay → được phép jitter
const SKIRT_FAR_TINT:    float = 0.85    # vành ngoài cùng tối hơn
const SKIRT_PROP_CHANCE: float = 0.45
const SKIRT_SCALE_MIN:   float = 0.85
const SKIRT_SCALE_MAX:   float = 1.25
const SKIRT_OFFSET_MAX:  float = 0.34
## Hệ số tối của 3 nhóm skirt (0 = sát grid, 2 = vành ngoài cùng).
const SKIRT_GROUP_TINT: Array[float] = [1.0, SKIRT_FAR_TINT, SKIRT_FAR_TINT * 0.82]

# --- CONSTANTS: CLIFF ---
const CLIFF_DEPTH:          float = 1.2
const CLIFF_SIDE_THICKNESS: float = 0.12
const CLIFF_TOP_HEIGHT:     float = 0.06
const CLIFF_RIM_WIDTH:      float = 0.36
const CLIFF_BOTTOM_THICK:   float = 0.10
const COLOR_BOARD_BOTTOM := Color("17110d")

# --- CONSTANTS: PROPS ---
# Danh sách prop của từng biome nằm trong BiomeLibrary (skirt_props / ground_props).
const PROP_ROCK: String = "rock"

const PATH_ROCK_CHANCE: float = 0.08     # đường mòn: chỉ đá rất nhỏ
## Scale mặc định của prop trên grid khi entry không khai báo smin/smax.
const PROP_SCALE_MIN: float = 0.70
const PROP_SCALE_MAX: float = 1.00
## Prop CAO (spec đánh dấu "tall") chỉ mọc từ vành này trở ra — gần hơn sẽ chắn camera.
const SKIRT_TALL_MIN_DIST: int = 2
## Props trên grid luôn lệch ra rìa ô — không bao giờ nằm giữa ô (chỗ tháp đứng).
const PROP_EDGE_MIN: float = 0.30
const PROP_EDGE_MAX: float = 0.40

# --- CONSTANTS: RNG SALT (deterministic per-cell) ---
const SALT_TILE:  int = 1
const SALT_PROP:  int = 2
const SALT_SKIRT: int = 3
const SALT_MIX:   int = 0x9E3779B9

# --- GRID STATE (shared by reference với các component khác) ---
var grid_width:        int = 8
var grid_height:       int = 8
var grid_data:         Dictionary      = {}
var current_path_grid: Array[Vector2i] = []
var special_tiles:     Dictionary      = {}   # Vector2i → "blessed" / "cursed"

# --- BIOME STATE ---
## Vector2i → biome id (khoá của BiomeLibrary.ALL). MỌI ô trong bounds đều có mặt ở đây.
## Được _rebase() dịch cùng các dict khác nên vùng cũ không bao giờ đổi khí hậu.
var cell_biome: Dictionary = {}
## Biome của chunk khởi đầu — cũng là giá trị fallback khi tra ô lạ.
var base_biome: String = BiomeLibrary.DEFAULT_ID
## Biome của vùng gán gần nhất — để lần mở rộng sau tránh trùng khí hậu liền kề.
var _last_region_biome: String = BiomeLibrary.DEFAULT_ID

# --- REFS (set bởi game_map sau add_child) ---
var board_root: Node3D = null
var _map_generator: MapGenerator = null
## Callable trả về Dictionary/Array các ô cần bảo vệ khỏi đường mới (ô lãnh thổ).
## game_map set sau khi TerritoryManager tồn tại.
var protected_cells_provider: Callable = Callable()
## Callable(cell: Vector2i) -> String trả về nguyên tố của ô. game_map CÓ THỂ set để
## chỉ định nguồn dữ liệu; không set thì get_element_at() tự tìm TerritoryManager
## sibling qua get_parent().get("territory_manager") — xem _find_territory_manager().
var element_provider: Callable = Callable()

# --- ELEMENT CACHE (get_element_at bị gọi MỖI PHÁT BẮN → phải O(1)) ---
## Vector2i → String. Chỉ ghi khi đã có nguồn dữ liệu thật, nên lúc TerritoryManager
## chưa sẵn sàng sẽ không bị "đóng băng" giá trị NONE sai.
var _element_cache: Dictionary = {}
## TerritoryManager tìm được qua fallback — cache để không dò cây node mỗi lần bắn.
var _territory_ref: Node = null

# --- INTERNAL RENDER STATE ---
var _tiles_root: Node3D = null
var _props_root: Node3D = null
var _king_visual: Node3D = null
var _tile_mesh:  BoxMesh = null
var _skirt_mesh: BoxMesh = null
var _mat_blessed: StandardMaterial3D = null
var _mat_cursed:  StandardMaterial3D = null
var _mat_board_bottom: StandardMaterial3D = null
## "biome|kind|tint" → StandardMaterial3D. Material nền/vách sinh MỘT lần rồi tái dùng
## cho mọi lần _rebuild_board() — không tạo material mới mỗi lần dựng lại board.
var _mat_cache: Dictionary = {}

# --- INTERNAL PROP STATE ---
var _map_seed: int = 0                      # random 1 lần/run, GIỮ NGUYÊN qua expand
## Tổng mọi delta đã rebase. Trang trí seed theo (cell - _rebase_total) nên vùng cũ
## giữ NGUYÊN cây/cỏ/đá kể cả sau khi mở về WEST/NORTH.
var _rebase_total: Vector2i = Vector2i.ZERO
## Hướng đã mở rộng lần gần nhất (-1 = chưa mở lần nào) — dùng để phạt lặp hướng.
var _last_expand_dir: int = -1
var _rng   := RandomNumberGenerator.new()   # dùng cho mọi quyết định scatter/rotation
var _rng_y := RandomNumberGenerator.new()   # riêng cho _skirt_top_y() — không phá state _rng
var _grid_props:        Dictionary = {}     # Vector2i → Array[{id, xform}] (trong grid)
var _skirt_props:       Dictionary = {}     # Vector2i → Array[{id, xform}] (vành ngoài)
var _hidden_prop_cells: Dictionary = {}     # Vector2i → true (ô có tháp → ẩn props)
var _prop_parts_cache:  Dictionary = {}     # prop_id → Array[{mesh, xform, material}]

## Trả về tập ô KHÔNG được để đường mới đi qua (ngoài tháp + path cũ).
## game_map gắn provider trỏ tới TerritoryManager.owned_tiles.
## Trả Dictionary (cell → true) để tra cứu O(1); rỗng nếu chưa gắn.
func _protected_cells() -> Dictionary:
	if not protected_cells_provider.is_valid():
		return {}
	var result = protected_cells_provider.call()
	if result is Dictionary:
		return result
	if result is Array:
		var out: Dictionary = {}
		for c in result:
			out[c] = true
		return out
	return {}

func setup(board: Node3D, gen: MapGenerator) -> void:
	board_root     = board
	_map_generator = gen
	_ensure_render_resources()

# --- PUBLIC API ---

func create_new_chunk() -> void:
	grid_data.clear()           # in-place clear — references held by other components remain valid
	current_path_grid.clear()
	special_tiles.clear()
	cell_biome.clear()
	# Seed cố định cho cả run: expand rebuild lại vẫn ra đúng địa hình cũ.
	_map_seed = randi()
	_rebase_total = Vector2i.ZERO
	_prop_parts_cache.clear()
	_mat_cache.clear()
	invalidate_element_cache()

	# Khí hậu khởi đầu — toàn bộ chunk đầu dùng chung một biome.
	base_biome = BiomeLibrary.random_id()
	_last_region_biome = base_biome

	_map_generator.width              = grid_width
	_map_generator.height             = grid_height
	_map_generator.min_y              = 0
	_map_generator.bound_min          = Vector2i.ZERO
	_map_generator.bound_max          = Vector2i(grid_width, grid_height)
	_map_generator.target_cells       = {}
	_map_generator.min_path_length    = max(21, int(grid_width * grid_height / 4.0))
	_map_generator.blocked_positions  = {}
	_map_generator.adjacent_blocked   = {}

	var start_pos := Vector2i(randi() % grid_width, 0)
	var path       = _map_generator.generate_path(start_pos, grid_height - 1)

	if path.is_empty():
		push_error("GridController: Không tìm được đường đi!")
		return

	current_path_grid.assign(path)
	for pos in path:
		grid_data[pos] = "path"
	var region := Rect2i(0, 0, grid_width, grid_height)
	_assign_region_biome(region, base_biome)
	_roll_special_tiles_in_rect(region)
	_rebuild_board()
	biome_region_added.emit(base_biome, region)
	map_chunk_created.emit(path)

## Mở rộng bản đồ thêm EXPAND_STEP ô theo MỘT trong 4 hướng.
## Hướng được chấm điểm theo khoảng cách từ ô King tới biên tương ứng (gần = tốt, vì
## đoạn DFS mới ngắn và ít phải lách quanh đường cũ), thử lần lượt từ tốt nhất.
## KHÔNG có state nào bị đổi cho tới khi đoạn path mới đã sinh thành công.
func expand() -> void:
	if current_path_grid.is_empty():
		push_error("GridController: Không có đường cũ để nối!")
		return

	var king_cell: Vector2i = current_path_grid.back()
	var candidates: Array[int] = _ranked_expand_dirs(king_cell)
	if candidates.is_empty():
		push_warning("GridController: Bản đồ đã đạt kích thước tối đa %d trên cả 2 trục." % MAX_AXIS)
		return

	for dir in candidates:
		if _try_expand_dir(dir, king_cell):
			return

	push_warning("GridController: Không nối được đường ở cả %d hướng ứng viên — giữ nguyên bản đồ."
		% candidates.size())

## Danh sách hướng ứng viên đã sắp xếp (tốt nhất trước). Hướng làm trục vượt MAX_AXIS
## bị loại. Điểm = khoảng cách ô King tới biên của hướng đó; tie-break ngẫu nhiên để
## mỗi run ra hình dạng bản đồ khác nhau.
func _ranked_expand_dirs(king_cell: Vector2i) -> Array[int]:
	var scored: Array = []
	if grid_height + EXPAND_STEP <= MAX_AXIS:
		scored.append({"dir": ExpandDir.NORTH, "score": king_cell.y})
		scored.append({"dir": ExpandDir.SOUTH, "score": (grid_height - 1) - king_cell.y})
	if grid_width + EXPAND_STEP <= MAX_AXIS:
		scored.append({"dir": ExpandDir.WEST,  "score": king_cell.x})
		scored.append({"dir": ExpandDir.EAST,  "score": (grid_width - 1) - king_cell.x})

	# score * 100 + jitter[0..99]: hướng điểm khác nhau giữ đúng thứ tự, hướng điểm
	# bằng nhau được xáo ngẫu nhiên.
	# Phạt hướng vừa dùng: đích DFS luôn là biên NGOÀI của vùng mới → King nằm sẵn trên
	# biên đó → hướng cũ luôn có điểm 0 và sẽ được chọn mãi. Phạt để bản đồ mở đa hướng thật.
	for entry in scored:
		var penalty: int = REPEAT_DIR_PENALTY if int(entry["dir"]) == _last_expand_dir else 0
		entry["rank"] = (int(entry["score"]) + penalty) * 100 + (randi() % 100)
	scored.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))

	var out: Array[int] = []
	for entry in scored:
		out.append(int(entry["dir"]))
	return out

## Thử mở rộng theo 1 hướng. Trả true nếu ĐÃ commit (state đã đổi + signal đã phát),
## false nếu thất bại — khi false thì KHÔNG có state nào bị thay đổi.
func _try_expand_dir(dir: int, king_cell: Vector2i) -> bool:
	# ── 1. Hình học vùng mới (trong hệ toạ độ SAU rebase) ────────────────────
	var delta      := Vector2i.ZERO
	var new_width  := grid_width
	var new_height := grid_height
	var region     := Rect2i()

	match dir:
		ExpandDir.NORTH:
			delta      = Vector2i(0, EXPAND_STEP)
			new_height = grid_height + EXPAND_STEP
			region     = Rect2i(0, 0, new_width, EXPAND_STEP)
		ExpandDir.SOUTH:
			new_height = grid_height + EXPAND_STEP
			region     = Rect2i(0, grid_height, new_width, EXPAND_STEP)
		ExpandDir.WEST:
			delta     = Vector2i(EXPAND_STEP, 0)
			new_width = grid_width + EXPAND_STEP
			region    = Rect2i(0, 0, EXPAND_STEP, new_height)
		ExpandDir.EAST:
			new_width = grid_width + EXPAND_STEP
			region    = Rect2i(grid_width, 0, EXPAND_STEP, new_height)
		_:
			push_error("GridController: hướng mở rộng không hợp lệ (%d)" % dir)
			return false

	var junction: Vector2i = king_cell + delta

	# ── 2. Bản dịch TẠM của blocked sets (chỉ biến local — state thật chưa đổi) ──
	var blocked:  Dictionary = {}
	var adjacent: Dictionary = {}
	for cell in grid_data.keys():
		if grid_data[cell] is Node3D:
			blocked[(cell as Vector2i) + delta] = true
	for p in current_path_grid:
		var shifted: Vector2i = p + delta
		adjacent[shifted] = true
		if shifted != junction:
			blocked[shifted] = true
	# Ô lãnh thổ người chơi đã mua cũng phải được bảo vệ như ô có tháp:
	# nếu đường mới cán qua, mesh biome sẽ nổi trên mặt đường và buff chết vĩnh viễn.
	# protected_shifted dùng lại ở bước 5b (lưới an toàn) — PHẢI là toạ độ sau rebase
	# vì new_segment cũng ở hệ toạ độ đó.
	var protected_shifted: Dictionary = {}
	for cell in _protected_cells():
		var pc: Vector2i = (cell as Vector2i) + delta
		protected_shifted[pc] = true
		blocked[pc] = true

	# ── 3. Ô đích = biên NGOÀI của vùng mới → King luôn nằm sâu trong lãnh thổ mới ──
	var targets: Dictionary = _outer_edge_cells(dir, new_width, new_height)
	for cell in targets.keys():
		if not region.has_point(cell as Vector2i) or blocked.has(cell):
			targets.erase(cell)
	if targets.is_empty():
		return false

	# ── 4. Sinh đoạn path mới trên TOÀN BỘ rect mới ─────────────────────────
	_map_generator.width              = new_width
	_map_generator.height             = new_height
	_map_generator.min_y              = 0
	_map_generator.bound_min          = Vector2i.ZERO
	_map_generator.bound_max          = Vector2i(new_width, new_height)
	_map_generator.min_path_length    = EXTENSION_MIN_LENGTH
	_map_generator.blocked_positions  = blocked
	_map_generator.adjacent_blocked   = adjacent

	var new_segment: Array[Vector2i] = _map_generator.generate_extension_to_region(junction, targets)

	# Generator luôn được trả về trạng thái trung tính, bất kể kết quả.
	_map_generator.blocked_positions = {}
	_map_generator.adjacent_blocked  = {}
	_map_generator.target_cells      = {}
	_map_generator.min_y             = 0

	if new_segment.size() < 2:
		# Chưa commit gì → caller thử hướng khác.
		_map_generator.width           = grid_width
		_map_generator.height          = grid_height
		_map_generator.bound_max       = Vector2i(grid_width, grid_height)
		_map_generator.min_path_length = max(21, int(grid_width * grid_height / 4.0))
		return false

	# ══ 5. COMMIT — từ đây trở đi state được thay đổi ════════════════════════
	_rebase(delta)
	grid_width  = new_width
	grid_height = new_height
	_map_generator.min_path_length = max(21, int(grid_width * grid_height / 4.0))

	# 5a. Tháp nằm trên đoạn path mới: hoàn 50% + báo synergy/aura rồi xoá.
	#     (DFS đã tránh ô tháp qua blocked_positions — nhánh này là lưới an toàn.)
	var new_seg_set: Dictionary = {}
	for i in range(1, new_segment.size()):
		new_seg_set[new_segment[i]] = true

	for cell in grid_data.keys():
		if not new_seg_set.has(cell):
			continue
		var tower = grid_data[cell]
		if not (tower is Node3D):
			continue
		if is_instance_valid(tower):
			if tower.get("stats") and tower.stats:
				tower_refunded_on_expand.emit(int(tower.stats.cost * 0.5))
			# Báo cho synergy/aura trước khi free — nếu không buff count bị kẹt vĩnh viễn
			tower_removed_on_expand.emit(tower)
			tower.queue_free()
		grid_data.erase(cell)

	# 5b. Nối path mới (bỏ phần tử đầu — trùng junction).
	# Lưới an toàn: ô lãnh thổ đã bị chặn ở bước 2, nhưng nếu provider chưa được set
	# (hoặc rỗng) thì vẫn phải dọn để không còn mesh biome nổi trên mặt đường.
	# LƯU Ý: phát signal SAU map_rebased, vì lúc này TerritoryManager vẫn giữ key
	# theo hệ toạ độ CŨ — dọn sớm sẽ không tìm thấy ô.
	var overwritten_territory: Array[Vector2i] = []
	for i in range(1, new_segment.size()):
		var cell: Vector2i = new_segment[i]
		if protected_shifted.has(cell):
			overwritten_territory.append(cell)
		current_path_grid.append(cell)
		grid_data[cell] = "path"
		special_tiles.erase(cell)   # path mới có thể đè ô đặc biệt cũ

	# 5c. Khí hậu MỚI cho vùng vừa mở — khác biome của vùng gán gần nhất để bản đồ
	#     thành mảng chắp vá thấy rõ. Vùng cũ đã rebase nên giữ nguyên biome của nó.
	var region_biome: String = BiomeLibrary.random_id([_last_region_biome])
	_assign_region_biome(region, region_biome)
	_last_region_biome = region_biome

	# 5d. Ô phước/nguyền CHỈ trong vùng mới — vùng cũ đã được rebase nên giữ nguyên.
	_roll_special_tiles_in_rect(region)

	_rebuild_board()

	# 5e. Tháp còn lại: cập nhật vị trí world theo key MỚI.
	for cell in grid_data.keys():
		var entry = grid_data[cell]
		if entry is Node3D and is_instance_valid(entry):
			entry.position = GridUtil.cell_to_world(cell)

	if OS.is_debug_build():
		_assert_path_contiguous()

	_last_expand_dir = dir   # để lần sau ưu tiên hướng khác

	if delta != Vector2i.ZERO:
		map_rebased.emit(delta)

	# Dọn lãnh thổ bị đè — phải sau map_rebased để key của TerritoryManager đã cùng hệ toạ độ.
	if not overwritten_territory.is_empty():
		push_warning("GridController: đường mới đè %d ô lãnh thổ — hoàn về kho."
			% overwritten_territory.size())
		territory_overwritten_on_expand.emit(overwritten_territory)

	biome_region_added.emit(region_biome, region)
	# Quà ô nguyên tố của khí hậu mới — sau biome_region_added để handler nào đọc
	# cell_biome cũng thấy state cuối cùng.
	_grant_free_element_tiles(region_biome)
	map_expanded.emit(grid_height, current_path_grid)
	return true

## Tập ô trên biên NGOÀI của vùng mới theo hướng mở rộng.
func _outer_edge_cells(dir: int, new_width: int, new_height: int) -> Dictionary:
	var cells: Dictionary = {}
	match dir:
		ExpandDir.NORTH:
			for x in range(new_width):  cells[Vector2i(x, 0)] = true
		ExpandDir.SOUTH:
			for x in range(new_width):  cells[Vector2i(x, new_height - 1)] = true
		ExpandDir.WEST:
			for y in range(new_height): cells[Vector2i(0, y)] = true
		ExpandDir.EAST:
			for y in range(new_height): cells[Vector2i(new_width - 1, y)] = true
	return cells

# --- REBASE (dịch toàn bộ toạ độ khi mở về WEST/NORTH) ---

## Dịch MỌI state keyed theo cell đi `delta`. Nhờ đó bounds luôn là
## [0, grid_width) × [0, grid_height) và các component duyệt 0..width/height
## (tower_placer, map_overlay_drawer, territory_manager) không cần biết gì về rebase.
##
## QUAN TRỌNG: grid_data và current_path_grid được các component khác giữ REFERENCE
## (tower_placer.setup nhận gc.grid_data) → TUYỆT ĐỐI không gán object mới, chỉ
## clear() in-place rồi nạp lại dữ liệu đã dịch.
func _rebase(delta: Vector2i) -> void:
	if delta == Vector2i.ZERO:
		return

	_shift_dict_keys_in_place(grid_data, delta)
	_shift_dict_keys_in_place(special_tiles, delta)
	_shift_dict_keys_in_place(cell_biome, delta)
	_shift_dict_keys_in_place(_hidden_prop_cells, delta)
	_shift_grid_props_in_place(delta)
	# Cache nguyên tố keyed theo cell — sau khi dịch toạ độ thì mọi entry đều sai ô.
	# Xoá sạch rẻ hơn và an toàn hơn nhiều so với dịch từng key.
	invalidate_element_cache()

	var shifted_path: Array[Vector2i] = []
	for cell in current_path_grid:
		shifted_path.append(cell + delta)
	current_path_grid.clear()
	for cell in shifted_path:
		current_path_grid.append(cell)

	_rebase_total += delta

## Dịch key Vector2i của dictionary — clear + nạp lại IN-PLACE (giữ nguyên object).
func _shift_dict_keys_in_place(dict: Dictionary, delta: Vector2i) -> void:
	var shifted: Dictionary = {}
	for key in dict.keys():
		shifted[(key as Vector2i) + delta] = dict[key]
	dict.clear()
	for key in shifted.keys():
		dict[key] = shifted[key]

## _grid_props giữ Transform3D ở world space → phải dịch cả key VÀ origin.
func _shift_grid_props_in_place(delta: Vector2i) -> void:
	var world_delta := Vector3(float(delta.x), 0.0, float(delta.y)) * TILE_SIZE
	var shifted: Dictionary = {}
	for cell in _grid_props.keys():
		var moved: Array = []
		for entry in (_grid_props[cell] as Array):
			var xf: Transform3D = entry["xform"]
			xf.origin += world_delta
			moved.append({"id": entry["id"], "xform": xf})
		shifted[(cell as Vector2i) + delta] = moved
	_grid_props.clear()
	for cell in shifted.keys():
		_grid_props[cell] = shifted[cell]

## Debug guard: path phải liền mạch, trong bounds, và mọi ô đều là "path" trong grid_data.
func _assert_path_contiguous() -> void:
	for i in current_path_grid.size():
		var cell: Vector2i = current_path_grid[i]
		if not is_in_bounds(cell):
			push_error("GridController: path[%d]=%s ngoài bounds %dx%d"
				% [i, str(cell), grid_width, grid_height])
		if not is_path_cell(cell):
			push_error("GridController: path[%d]=%s không được đánh dấu 'path' trong grid_data"
				% [i, str(cell)])
		if i == 0:
			continue
		var step: Vector2i = cell - current_path_grid[i - 1]
		if absi(step.x) + absi(step.y) != 1:
			push_error("GridController: path đứt tại index %d: %s → %s"
				% [i, str(current_path_grid[i - 1]), str(cell)])

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

## Ô có phải path (đường enemy đi) không.
func is_path_cell(cell: Vector2i) -> bool:
	return grid_data.get(cell) is String and grid_data.get(cell) == "path"

## "blessed" / "cursed" / "" nếu ô thường.
func get_special_tile(cell: Vector2i) -> String:
	return special_tiles.get(cell, "")

# --- BIOME API ---

## Biome id của một ô. Ô ngoài bounds / chưa gán → biome khởi đầu (không bao giờ rỗng).
func get_cell_biome(cell: Vector2i) -> String:
	return str(cell_biome.get(cell, base_biome))

## Biome tại ô King (cuối path) — khí hậu đang bao trùm căn cứ.
func get_current_biome() -> String:
	if current_path_grid.is_empty():
		return base_biome
	return get_cell_biome(current_path_grid.back())

# ==========================================================================
# Ô NGUYÊN TỐ — futureplan.md §2
# ==========================================================================
# LƯU Ý PHÂN BIỆT HAI HỆ CÙNG TÊN "BIOME":
#   - `cell_biome` ở trên  = KHÍ HẬU VÙNG (wasteland/tundra/...) → ảnh hưởng CHỈ SỐ.
#   - Ô Nguyên Tố (dưới đây) = ô người chơi MUA và đặt → ảnh hưởng DẤU.
# Hai hệ hoàn toàn độc lập, chỉ giao nhau ở chỗ khí hậu vùng mới tặng ô nguyên tố.

## Nguyên tố của ô — nguồn Dấu cho tháp đứng trên đó. Ô thường → ElementTypes.NONE.
##
## HÀM NÀY BỊ GỌI MỖI PHÁT BẮN nên phải rẻ: tra cache trước, chỉ hỏi TerritoryManager
## khi cache miss. Cache bị xoá sạch mỗi khi bố cục ô đổi (territories_changed) hoặc
## toạ độ bị dịch (_rebase).
func get_element_at(cell: Vector2i) -> String:
	if _element_cache.has(cell):
		return str(_element_cache[cell])

	var element: String = ElementTypes.NONE
	var resolved: bool = false

	if element_provider.is_valid():
		var value = element_provider.call(cell)
		if value is String:
			element = value as String
			resolved = true

	if not resolved:
		var tm := _find_territory_manager()
		if tm != null:
			var raw = tm.call("get_element_at", cell)
			if raw is String:
				element = raw as String
			resolved = true

	if not ElementTypes.is_valid(element):
		element = ElementTypes.NONE
		# Di vật "Living Ley Line": ô Lv3 lan nguyên tố của nó sang 4 ô kề.
		# Chỉ chạy khi ô này TRỐNG nên ô nguyên tố thật không bao giờ bị ghi đè.
		if resolved and _vein_spread_enabled():
			element = _vein_from_neighbour(cell)
	# Chưa có nguồn dữ liệu nào → KHÔNG cache (tránh ghim NONE vĩnh viễn khi
	# TerritoryManager chưa kịp khởi tạo).
	if resolved:
		_element_cache[cell] = element
	return element

func _vein_spread_enabled() -> bool:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	return gm != null and bool(gm.get("relic_vein_spread"))

## Nguyên tố lan từ ô Lv3 kề. Đọc THẲNG TerritoryManager chứ không đệ quy
## `get_element_at`, nếu không hai ô trống kề nhau sẽ gọi qua lại vô hạn.
func _vein_from_neighbour(cell: Vector2i) -> String:
	var tm := _find_territory_manager()
	if tm == null or not tm.has_method("get_element_at") or not tm.has_method("get_tile_level"):
		return ElementTypes.NONE
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbour: Vector2i = cell + offset
		if int(tm.call("get_tile_level", neighbour)) < 3:
			continue
		var found = tm.call("get_element_at", neighbour)
		if found is String and ElementTypes.is_valid(found):
			return found as String
	return ElementTypes.NONE

## Cấp ô nguyên tố (0 = ô thường, 1..3). Forward sang TerritoryManager, guard đầy đủ.
func get_tile_level(cell: Vector2i) -> int:
	var tm := _find_territory_manager()
	if tm == null or not tm.has_method("get_tile_level"):
		return 0
	return int(tm.call("get_tile_level", cell))

## Phần thưởng theo cấp ô: {mark_duration_bonus, reaction_mult, tower_damage_pct}.
func get_element_bonus(cell: Vector2i) -> Dictionary:
	var neutral: Dictionary = {"mark_duration_bonus": 0.0, "reaction_mult": 1.0, "tower_damage_pct": 0.0}
	var tm := _find_territory_manager()
	if tm == null or not tm.has_method("get_element_bonus"):
		return neutral
	var value = tm.call("get_element_bonus", cell)
	if value is Dictionary:
		return value as Dictionary
	return neutral

## Xoá cache nguyên tố — gọi khi bố cục ô nguyên tố thay đổi.
func invalidate_element_cache() -> void:
	_element_cache.clear()

## Gắn nguồn dữ liệu nguyên tố tường minh (game_map dùng nếu muốn tự điều phối).
## Luôn xoá cache — giá trị cũ được trả bởi nguồn khác thì không còn tin được.
func set_element_provider(provider: Callable) -> void:
	element_provider = provider
	invalidate_element_cache()

## Tìm TerritoryManager mà KHÔNG cần game_map phải gắn gì.
## TerritoryManager là node ANH EM: game_map tạo nó rồi mới tạo GridController, và giữ
## tham chiếu trong biến `territory_manager` của chính game_map (= get_parent() của ta).
## Kết quả được cache; lần đầu tìm thấy thì nối luôn `territories_changed` để tự
## invalidate cache khi người chơi đặt/gỡ/nâng cấp ô.
func _find_territory_manager() -> Node:
	if _territory_ref != null and is_instance_valid(_territory_ref):
		return _territory_ref
	_territory_ref = null

	var parent := get_parent()
	if parent == null:
		return null
	var candidate = parent.get("territory_manager")
	if candidate == null or not (candidate is Node):
		return null
	var tm := candidate as Node
	if not is_instance_valid(tm) or not tm.has_method("get_element_at"):
		return null

	_territory_ref = tm
	if tm.has_signal("territories_changed") \
			and not tm.is_connected("territories_changed", _on_territory_layout_changed):
		tm.connect("territories_changed", _on_territory_layout_changed)
	return _territory_ref

## Bố cục ô nguyên tố đã đổi → mọi giá trị cache không còn tin được.
func _on_territory_layout_changed(_counts: Dictionary) -> void:
	invalidate_element_cache()

# --- Ô NGUYÊN TỐ MIỄN PHÍ THEO KHÍ HẬU VÙNG (futureplan §2.4) ---

## Vùng khí hậu vừa mở tặng gì. Trả về Array các cặp [element, count].
## Dùng hàm thay vì const Dictionary để tham chiếu thẳng hằng của ElementTypes
## mà không phụ thuộc vào việc GDScript có cho phép biểu thức hằng chéo script hay không.
func _free_tiles_for_biome(biome_id: String) -> Array:
	match biome_id:
		"volcanic":
			return [[ElementTypes.FIRE, 2]]
		"tundra":
			return [[ElementTypes.ICE, 2]]
		"swamp":
			return [[ElementTypes.WATER, 1], [ElementTypes.POISON, 1]]
		"verdant":
			return [[ElementTypes.EARTH, 2]]
		"wasteland":
			return [[ElementTypes.ALL[randi() % ElementTypes.ALL.size()], 1]]
		_:
			return []

## Phát quà ô nguyên tố cho vùng vừa mở rộng.
## Ưu tiên signal (game_map có thể muốn xen thông báo HUD / luật riêng). CHỈ khi
## không ai lắng nghe mới tự cộng thẳng vào kho qua TerritoryManager — nhờ vậy
## không bao giờ tặng hai lần.
func _grant_free_element_tiles(biome_id: String) -> void:
	var grants: Array = _free_tiles_for_biome(biome_id)
	if grants.is_empty():
		return
	var has_listener: bool = not free_tiles_granted.get_connections().is_empty()
	for grant in grants:
		if not (grant is Array) or (grant as Array).size() < 2:
			continue
		var element: String = str((grant as Array)[0])
		var count: int = int((grant as Array)[1])
		if not ElementTypes.is_valid(element) or count <= 0:
			continue
		free_tiles_granted.emit(element, count)
		if not has_listener:
			_add_free_tiles_direct(element, count)

## Fallback: cộng thẳng vào kho TerritoryManager khi chưa ai nối signal.
## Duck-typing hoàn toàn (has_method + call) — KHÔNG tham chiếu class TerritoryManager,
## vì territory_manager.gd đã tham chiếu GridController và cặp đó sẽ thành vòng lặp.
func _add_free_tiles_direct(element: String, count: int) -> void:
	var tm := _find_territory_manager()
	if tm == null or not tm.has_method("add_stock") or not tm.has_method("get_biome_for_element"):
		return
	var biome_key: String = str(tm.call("get_biome_for_element", element))
	if biome_key == "":
		push_warning("GridController: nguyên tố '%s' không có ô tương ứng — bỏ qua quà vùng."
			% element)
		return
	for _i in count:
		tm.call("add_stock", biome_key)

## Gán biome cho MỌI ô trong `region` (toạ độ SAU rebase). Ghi đè có chủ đích để
## vùng mới đồng nhất khí hậu, kể cả ô mà đường mới vừa lấn vào.
func _assign_region_biome(region: Rect2i, biome_id: String) -> void:
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			var cell := Vector2i(x, y)
			if is_in_bounds(cell):
				cell_biome[cell] = biome_id

## Lưới an toàn trước mỗi lần dựng board: ô trong bounds mà chưa có biome (không nên
## xảy ra) sẽ nhận base_biome — render và gameplay không bao giờ gặp ô "vô khí hậu".
func _ensure_every_cell_has_biome() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var cell := Vector2i(x, y)
			if not cell_biome.has(cell):
				cell_biome[cell] = base_biome

## Ô grid gần nhất với một ô bất kỳ (kể cả ô skirt ngoài board) — vành ngoài nhờ đó
## hoà khí hậu với đúng vùng grid nằm kề nó.
func _nearest_grid_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, grid_width - 1), clampi(cell.y, 0, grid_height - 1))

## Ẩn props (cỏ/đá/bụi) tại ô — gọi khi đặt tháp lên ô đó.
## MultiMesh không xoá được 1 instance → build lại các MultiMesh prop (vài trăm transform, rất rẻ).
func clear_props_at(cell: Vector2i) -> void:
	if _hidden_prop_cells.has(cell):
		return
	_hidden_prop_cells[cell] = true
	if _grid_props.has(cell):
		_rebuild_prop_multimeshes()

## Trả props về ô — gọi khi dismiss tháp. Transform gốc vẫn được giữ trong _grid_props.
func restore_props_at(cell: Vector2i) -> void:
	if not _hidden_prop_cells.has(cell):
		return
	_hidden_prop_cells.erase(cell)
	if _grid_props.has(cell):
		_rebuild_prop_multimeshes()

## Roll ô đặc biệt trong vùng chữ nhật `region`: 2 phước + 1 nguyền trên ô KHÔNG phải
## path, chưa có tower, chưa đặc biệt. Vùng được truyền vào dạng Rect2i vì map mở rộng
## được cả 4 hướng (không còn là "dải hàng" như bản chỉ mở theo +y).
func _roll_special_tiles_in_rect(region: Rect2i) -> void:
	# Ô Phước/Nguyền đã TẮT (FeatureFlags.SPECIAL_TILES_ENABLED): ±20% phẳng,
	# không tương tác với nước đi cũng không với thế cờ — nó chỉ là số cộng thêm.
	if not FeatureFlags.SPECIAL_TILES_ENABLED:
		return
	var candidates: Array[Vector2i] = []
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			var pos := Vector2i(x, y)
			if not is_in_bounds(pos):
				continue
			if is_path_cell(pos):
				continue
			if grid_data.get(pos) is Node3D:
				continue
			if special_tiles.has(pos):
				continue
			candidates.append(pos)
	candidates.shuffle()
	var idx := 0
	for i in BLESSED_PER_REGION:
		if idx >= candidates.size():
			return
		special_tiles[candidates[idx]] = "blessed"
		idx += 1
	for i in CURSED_PER_REGION:
		if idx >= candidates.size():
			return
		special_tiles[candidates[idx]] = "cursed"
		idx += 1

# --- MATERIAL / MESH RESOURCES ---

func _ensure_render_resources() -> void:
	if _tile_mesh:
		return
	_tile_mesh = BoxMesh.new()
	_tile_mesh.size = Vector3(TILE_SIZE, TILE_THICKNESS, TILE_SIZE)
	_skirt_mesh = BoxMesh.new()
	_skirt_mesh.size = Vector3(TILE_SIZE, SKIRT_THICKNESS, TILE_SIZE)

	# Ô rune KHÔNG đổi theo biome — giữ nhận diện phước/nguyền ở mọi khí hậu.
	_mat_blessed = _make_special_material(TEX_TERRAIN_BLESSED, COLOR_TILE_BLESSED, Color(0.9, 0.72, 0.25))
	_mat_cursed  = _make_special_material(TEX_TERRAIN_CURSED,  COLOR_TILE_CURSED,  Color(0.5, 0.2, 0.7))
	_mat_board_bottom = _make_flat_material(COLOR_BOARD_BOTTOM)

# --- BIOME MATERIAL (cache theo biome × kind × tint) ---

## Material mặt đất/vách của một biome. `kind` ∈ BiomeLibrary.TEX_KINDS,
## `tint` là hệ số tối (1.0 = nguyên bản, dùng cho các vành skirt xa).
## Kết quả được cache → _rebuild_board() KHÔNG sinh material mới.
func _biome_material(biome_id: String, kind: String, tint: float = 1.0) -> StandardMaterial3D:
	var key: String = "%s|%s|%d" % [biome_id, kind, roundi(tint * 100.0)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat: StandardMaterial3D = _build_biome_material(biome_id, kind, tint)
	_mat_cache[key] = mat
	return mat

## Ba mức ưu tiên:
##   1. Texture riêng của biome (khi asset đã có) — dùng thẳng.
##   2. Chưa có → mượn texture wasteland cũ rồi nhuộm theo tỉ lệ màu biome/wasteland,
##      giữ được vân đất mà vẫn ra đúng tông khí hậu.
##   3. Không có texture nào → màu phẳng của biome.
func _build_biome_material(biome_id: String, kind: String, tint: float) -> StandardMaterial3D:
	var color: Color = BiomeLibrary.tint_of(biome_id, kind)
	var flat: Color  = _scaled(color, tint)
	var path: String = BiomeLibrary.tex_path(biome_id, kind)
	if path != "" and ResourceLoader.exists(path):
		return _make_textured_material(path, flat, Color(tint, tint, tint, 1.0))
	var legacy: String = BiomeLibrary.tex_path(BiomeLibrary.DEFAULT_ID, kind)
	if legacy != "" and legacy != path and ResourceLoader.exists(legacy):
		var ratio: Color = _tint_ratio(color, BiomeLibrary.tint_of(BiomeLibrary.DEFAULT_ID, kind))
		return _make_textured_material(legacy, flat, _scaled(ratio, tint))
	return _make_flat_material(flat)

## Hệ số nhuộm để texture wasteland ra đúng tông biome: target / base (theo kênh).
## Chặn trên 1.6 để không đẩy albedo lên mức bị glow bloom bắt.
func _tint_ratio(target: Color, base: Color) -> Color:
	return Color(
		clampf(target.r / maxf(base.r, 0.02), 0.0, 1.6),
		clampf(target.g / maxf(base.g, 0.02), 0.0, 1.6),
		clampf(target.b / maxf(base.b, 0.02), 0.0, 1.6),
		1.0)

## Nhân RGB với hệ số tối, alpha luôn giữ 1.0.
func _scaled(color: Color, tint: float) -> Color:
	return Color(color.r * tint, color.g * tint, color.b * tint, 1.0)

## Material có texture pixel art (nearest). Thiếu texture → fallback màu phẳng như bản cũ.
func _make_textured_material(tex_path: String, fallback: Color,
		albedo: Color = Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			mat.albedo_texture = tex
			# Nearest giữ nét pixel art; mipmap chống nhiễu hạt khi camera zoom xa
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			mat.albedo_color   = Color(albedo.r, albedo.g, albedo.b, 1.0)
			return mat
		push_warning("GridController: texture '%s' không load được — fallback màu phẳng." % tex_path)
	mat.albedo_color = Color(fallback.r, fallback.g, fallback.b, 1.0)
	return mat

## Ô phước/nguyền: texture + emission nhẹ để nhận ra ngay giữa board.
func _make_special_material(tex_path: String, fallback: Color, glow: Color) -> StandardMaterial3D:
	var mat := _make_textured_material(tex_path, fallback)
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = SPECIAL_EMISSION
	return mat

func _make_flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat

# --- DETERMINISTIC RNG ---

## Reseed _rng theo (cell, salt, _map_seed) → mọi quyết định trang trí của ô luôn giống nhau
## sau mỗi _rebuild_board(). KHÔNG dùng randf() toàn cục trong scatter.
## Trừ _rebase_total để ô cũ giữ NGUYÊN seed sau khi map mở về WEST/NORTH (rebase dịch
## toạ độ; nếu hash trực tiếp theo cell thì cây/cỏ vùng cũ sẽ nhảy chỗ).
func _reseed(cell: Vector2i, salt: int) -> void:
	_rng.seed = _cell_seed(cell, salt)

## Seed ổn định của một ô — bất biến qua mọi lần rebase.
func _cell_seed(cell: Vector2i, salt: int) -> int:
	return hash(cell - _rebase_total) ^ _map_seed ^ (salt * SALT_MIX)

## Khoảng cách (ô) từ cell tới rìa grid: 0 = trong grid, 1..SKIRT_WIDTH = vành skirt.
func _skirt_distance(cell: Vector2i) -> int:
	var dx := 0
	if cell.x < 0:
		dx = -cell.x
	elif cell.x >= grid_width:
		dx = cell.x - grid_width + 1
	var dy := 0
	if cell.y < 0:
		dy = -cell.y
	elif cell.y >= grid_height:
		dy = cell.y - grid_height + 1
	return maxi(dx, dy)

## Cao độ mặt trên ô skirt — dùng _rng_y riêng nên gọi ở đâu cũng ra cùng giá trị.
func _skirt_top_y(cell: Vector2i, dist: int) -> float:
	_rng_y.seed = _cell_seed(cell, SALT_SKIRT)
	return SKIRT_STEP_Y * float(dist) + _rng_y.randf_range(-SKIRT_JITTER, SKIRT_JITTER)

# --- BOARD REBUILD ---

func _rebuild_board() -> void:
	if not board_root:
		push_error("GridController: board_root chưa được set!")
		return
	_ensure_render_resources()
	_ensure_every_cell_has_biome()

	if _tiles_root and is_instance_valid(_tiles_root):
		_tiles_root.free()   # free ngay để tránh tile cũ tồn tại thêm 1 frame
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	board_root.add_child(_tiles_root)

	_build_tiles(_tiles_root)
	_build_skirt(_tiles_root)
	_build_cliff(_tiles_root)

	_scatter_grid_props()
	_scatter_skirt_props()
	_rebuild_prop_multimeshes()

	_place_king_visual()

## Ô trong grid: MeshInstance3D riêng (mỗi loại 1 material) — mặt trên đúng y = 0.
func _build_tiles(parent: Node3D) -> void:
	var path_set: Dictionary = {}
	for p in current_path_grid:
		path_set[p] = true

	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			var is_road: bool = path_set.has(pos)
			var biome: String = get_cell_biome(pos)
			var tile := MeshInstance3D.new()
			tile.mesh = _tile_mesh
			if is_road:
				tile.material_override = _biome_material(biome, "road")
			elif special_tiles.get(pos, "") == "blessed":
				tile.material_override = _mat_blessed
			elif special_tiles.get(pos, "") == "cursed":
				tile.material_override = _mat_cursed
			else:
				tile.material_override = _biome_material(biome, "light" if (x + y) % 2 == 0 else "dark")
			# Xoay mesh 0/90/180/270° để texture không lặp thành pattern rõ.
			# Ô đường chỉ 0/180° → vệt bánh xe giữ đúng trục, đường không bị đứt đoạn.
			_reseed(pos, SALT_TILE)
			var steps: int = (_rng.randi_range(0, 1) * 2) if is_road else _rng.randi_range(0, 3)
			tile.rotation = Vector3(0.0, PI / 2.0 * float(steps), 0.0)
			# Position KHÔNG đổi: mặt trên nằm đúng y = 0 (mouse picking dùng ray-plane y=0)
			tile.position = GridUtil.cell_to_world(pos) + Vector3(0.0, -TILE_THICKNESS / 2.0, 0.0)
			parent.add_child(tile)

## Vành đất trang trí quanh grid — KHÔNG thuộc grid_data, KHÔNG buildable.
## Mỗi ô skirt mượn biome của ô GRID GẦN NHẤT → vành ngoài hoà đúng khí hậu vùng kề nó.
## Gom theo (biome × nhóm độ tối) thành MultiMesh để không sinh hàng trăm node.
func _build_skirt(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Skirt"
	parent.add_child(root)

	var groups: Dictionary = {}   # "biome|group" → {biome, group, xforms}
	for x in range(-SKIRT_WIDTH, grid_width + SKIRT_WIDTH):
		for y in range(-SKIRT_WIDTH, grid_height + SKIRT_WIDTH):
			var cell := Vector2i(x, y)
			var dist := _skirt_distance(cell)
			if dist == 0:
				continue
			var top := _skirt_top_y(cell, dist)
			_reseed(cell, SALT_TILE)
			var yaw := PI / 2.0 * float(_rng.randi_range(0, 3))
			var origin := Vector3(float(x) + 0.5, top - SKIRT_THICKNESS / 2.0, float(y) + 0.5)
			var g := _skirt_group(cell, dist)
			var biome: String = get_cell_biome(_nearest_grid_cell(cell))
			var key: String = "%s|%d" % [biome, g]
			if not groups.has(key):
				groups[key] = {"biome": biome, "group": g, "xforms": []}
			(groups[key]["xforms"] as Array).append(Transform3D(Basis(Vector3.UP, yaw), origin))

	var index := 0
	for key in groups.keys():
		var entry: Dictionary = groups[key]
		var mat := _biome_material(str(entry["biome"]), "dark", SKIRT_GROUP_TINT[int(entry["group"])])
		var mmi := _make_static_multimesh(_skirt_mesh, entry["xforms"], mat)
		mmi.name = "SkirtGroup%d" % index
		index += 1
		root.add_child(mmi)

## Toàn bộ skirt là đất sẫm; chỉ khác độ tối theo khoảng cách.
## Vành giữa xen ngẫu nhiên 2 tông (không theo bàn cờ) để trông tự nhiên, loang lổ.
func _skirt_group(cell: Vector2i, dist: int) -> int:
	if dist >= SKIRT_WIDTH:
		return 2
	if dist == 1:
		return 0
	_reseed(cell, SALT_SKIRT)
	return 0 if _rng.randf() < 0.5 else 1

# --- CLIFF (thay khung gỗ cũ) ---

## Vách đá bao quanh TOÀN BỘ (grid + skirt), thả xuống dưới từ mức mặt skirt ngoài cùng.
func _build_cliff(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Cliff"
	parent.add_child(root)

	var x0 := -float(SKIRT_WIDTH)
	var z0 := -float(SKIRT_WIDTH)
	var x1 := float(grid_width + SKIRT_WIDTH)
	var z1 := float(grid_height + SKIRT_WIDTH)
	var w  := x1 - x0
	var d  := z1 - z0
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var top := SKIRT_STEP_Y * float(SKIRT_WIDTH)   # mức mặt skirt ngoài cùng
	var cy  := top - CLIFF_DEPTH / 2.0
	var t   := CLIFF_SIDE_THICKNESS

	# [size, position, chiều dài mặt (để tính uv1_scale), biên grid tương ứng]
	var sides := [
		[Vector3(w + 2.0 * t, CLIFF_DEPTH, t), Vector3(cx, cy, z0 - t / 2.0), w + 2.0 * t, ExpandDir.NORTH],
		[Vector3(w + 2.0 * t, CLIFF_DEPTH, t), Vector3(cx, cy, z1 + t / 2.0), w + 2.0 * t, ExpandDir.SOUTH],
		[Vector3(t, CLIFF_DEPTH, d), Vector3(x0 - t / 2.0, cy, cz), d, ExpandDir.WEST],
		[Vector3(t, CLIFF_DEPTH, d), Vector3(x1 + t / 2.0, cy, cz), d, ExpandDir.EAST],
	]
	for s in sides:
		var base := _biome_material(_edge_biome(int(s[3])), "cliff_side")
		root.add_child(_make_box(s[0], s[1], _tiled_material(base, float(s[2]), CLIFF_DEPTH)))

	_build_cliff_rim(root, x0, z0, x1, z1, top)
	_build_board_bottom(root, cx, cz, w, d, top)

## Biome ĐẠI DIỆN của một biên grid: loại xuất hiện nhiều nhất trên hàng/cột biên đó.
## Vách đá là khối liền nên mỗi mặt chỉ mang được một khí hậu — lấy đa số là xấp xỉ
## sát nhất (mặt vừa được mở rộng luôn thuần một biome).
func _edge_biome(dir: int) -> String:
	var counts: Dictionary = {}
	var best: String = base_biome
	var best_count: int = 0
	for cell in _outer_edge_cells(dir, grid_width, grid_height).keys():
		var biome: String = get_cell_biome(cell as Vector2i)
		var n: int = int(counts.get(biome, 0)) + 1
		counts[biome] = n
		if n > best_count:
			best_count = n
			best = biome
	return best

## Dải cliff_top mỏng viền quanh mép ngoài skirt — che seam giữa mặt skirt và vách.
func _build_cliff_rim(root: Node3D, x0: float, z0: float, x1: float, z1: float, top: float) -> void:
	var t := CLIFF_RIM_WIDTH
	var h := CLIFF_TOP_HEIGHT
	var y := top + h / 2.0 - 0.01
	var w := x1 - x0
	var d := z1 - z0
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var bars := [
		[Vector3(w + t, h, t), Vector3(cx, y, z0), w + t, ExpandDir.NORTH],
		[Vector3(w + t, h, t), Vector3(cx, y, z1), w + t, ExpandDir.SOUTH],
		[Vector3(t, h, d + t), Vector3(x0, y, cz), d + t, ExpandDir.WEST],
		[Vector3(t, h, d + t), Vector3(x1, y, cz), d + t, ExpandDir.EAST],
	]
	for b in bars:
		var base := _biome_material(_edge_biome(int(b[3])), "cliff_top")
		root.add_child(_make_box(b[0], b[1], _tiled_material(base, float(b[2]), t)))

## Mặt đáy tối bịt dưới — camera thấp không thấy rỗng.
func _build_board_bottom(root: Node3D, cx: float, cz: float, w: float, d: float, top: float) -> void:
	var t := CLIFF_SIDE_THICKNESS
	var size := Vector3(w + 2.0 * t, CLIFF_BOTTOM_THICK, d + 2.0 * t)
	var pos := Vector3(cx, top - CLIFF_DEPTH + CLIFF_BOTTOM_THICK / 2.0, cz)
	root.add_child(_make_box(size, pos, _mat_board_bottom))

## Copy material + uv1_scale theo kích thước mặt để texture lặp thay vì bị kéo giãn.
func _tiled_material(base: StandardMaterial3D, length: float, height: float) -> StandardMaterial3D:
	var mat := base.duplicate() as StandardMaterial3D
	mat.uv1_scale = Vector3(maxf(1.0, length / 2.0), maxf(1.0, height / 2.0), 1.0)
	return mat

func _make_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	return mi

# --- PROP SCATTER ---

## Props trong grid: chỉ ô KHÔNG phải blessed/cursed. Ô path chỉ được vài viên đá nhỏ.
## Ô có tháp → transform vẫn được sinh nhưng đánh dấu ẩn (để dismiss trả cỏ về).
func _scatter_grid_props() -> void:
	_grid_props.clear()
	_hidden_prop_cells.clear()
	for pos in grid_data.keys():
		if grid_data[pos] is Node3D:
			_hidden_prop_cells[pos] = true

	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			if special_tiles.has(pos):
				continue                      # giữ rune sạch
			_reseed(pos, SALT_PROP)
			if is_path_cell(pos):
				if _rng.randf() < PATH_ROCK_CHANCE:
					_push_prop(_grid_props, pos, PROP_ROCK, GridUtil.cell_to_world(pos), 0.35, 0.50)
				continue
			_scatter_ground_props_at(pos)

## Rải prop mặt đất theo `ground_props` của biome CHÍNH Ô ĐÓ — mỗi entry roll ĐỘC LẬP
## với xác suất w/100, nên một ô có thể vừa có cỏ vừa có đá.
func _scatter_ground_props_at(pos: Vector2i) -> void:
	var base: Vector3 = GridUtil.cell_to_world(pos)   # y = 0
	var entries: Array = BiomeLibrary.get_spec(get_cell_biome(pos)).get("ground_props", [])
	for entry in entries:
		if _rng.randf() >= float(entry.get("w", 0)) / 100.0:
			continue
		var count: int = 1
		if bool(entry.get("clump", false)):
			count = 1 if _rng.randf() < 0.6 else 2
		var prop_id: String = str(entry.get("id", PROP_ROCK))
		var smin: float = float(entry.get("smin", PROP_SCALE_MIN))
		var smax: float = float(entry.get("smax", PROP_SCALE_MAX))
		for i in count:
			_push_prop(_grid_props, pos, prop_id, base, smin, smax)

## Props trên skirt: mượn biome của ô grid gần nhất; cây to chỉ mọc từ vành
## SKIRT_TALL_MIN_DIST trở ra để không chắn camera nhìn vào board.
func _scatter_skirt_props() -> void:
	_skirt_props.clear()
	for x in range(-SKIRT_WIDTH, grid_width + SKIRT_WIDTH):
		for y in range(-SKIRT_WIDTH, grid_height + SKIRT_WIDTH):
			var cell := Vector2i(x, y)
			var dist := _skirt_distance(cell)
			if dist == 0:
				continue
			_reseed(cell, SALT_PROP)
			if _rng.randf() >= SKIRT_PROP_CHANCE:
				continue
			var prop_id := _pick_skirt_prop(get_cell_biome(_nearest_grid_cell(cell)), dist)
			if prop_id == "":
				continue
			var base := Vector3(float(x) + 0.5, _skirt_top_y(cell, dist), float(y) + 0.5)
			_push_prop(_skirt_props, cell, prop_id, base, SKIRT_SCALE_MIN, SKIRT_SCALE_MAX,
				0.0, SKIRT_OFFSET_MAX)

## Chọn MỘT prop theo trọng số `skirt_props` của biome. Đúng 1 lần _rng.randf() để
## chuỗi RNG của ô không đổi so với bản trước khi có biome.
func _pick_skirt_prop(biome_id: String, dist: int) -> String:
	var pool: Array = []
	var total: int = 0
	for entry in (BiomeLibrary.get_spec(biome_id).get("skirt_props", []) as Array):
		if dist < SKIRT_TALL_MIN_DIST and bool(entry.get("tall", false)):
			continue
		var weight: int = int(entry.get("w", 0))
		if weight <= 0:
			continue
		pool.append(entry)
		total += weight
	if pool.is_empty():
		return ""
	var roll: float = _rng.randf() * float(total)
	var acc: float = 0.0
	for entry in pool:
		acc += float(entry.get("w", 0))
		if roll < acc:
			return str(entry.get("id", PROP_ROCK))
	return str((pool.back() as Dictionary).get("id", PROP_ROCK))

## Sinh 1 transform prop và đẩy vào store. Offset đẩy prop ra rìa ô (không nằm giữa ô).
func _push_prop(store: Dictionary, cell: Vector2i, prop_id: String, base: Vector3,
		scale_min: float, scale_max: float,
		off_min: float = PROP_EDGE_MIN, off_max: float = PROP_EDGE_MAX) -> void:
	var ox := _rng.randf_range(off_min, off_max) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var oz := _rng.randf_range(off_min, off_max) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var s  := _rng.randf_range(scale_min, scale_max)
	var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
	var xf := Transform3D(basis, base + Vector3(ox, 0.0, oz))
	var list: Array = store.get(cell, [])
	list.append({"id": prop_id, "xform": xf})
	store[cell] = list

# --- PROP RENDER (MultiMesh) ---

## Gom toàn bộ prop transform theo loại → 1 MultiMesh / (loại × part của model).
func _rebuild_prop_multimeshes() -> void:
	if not board_root:
		return
	if not _props_root or not is_instance_valid(_props_root):
		_props_root = Node3D.new()
		_props_root.name = "Props"
		board_root.add_child(_props_root)
	for child in _props_root.get_children():
		child.free()

	var by_id: Dictionary = {}
	_collect_props(_grid_props, by_id, true)
	_collect_props(_skirt_props, by_id, false)

	for prop_id in by_id.keys():
		var xforms: Array = by_id[prop_id]
		var parts: Array = _prop_parts(prop_id)
		for i in parts.size():
			var part: Dictionary = parts[i]
			var mmi := _make_prop_multimesh(part, xforms)
			mmi.name = "MM_%s_%d" % [prop_id, i]
			_props_root.add_child(mmi)

func _collect_props(src: Dictionary, out: Dictionary, skip_hidden: bool) -> void:
	for cell in src.keys():
		if skip_hidden and _hidden_prop_cells.has(cell):
			continue
		for entry in (src[cell] as Array):
			var prop_id: String = entry["id"]
			var list: Array = out.get(prop_id, [])
			list.append(entry["xform"])
			out[prop_id] = list

func _make_prop_multimesh(part: Dictionary, xforms: Array) -> MultiMeshInstance3D:
	var local: Transform3D = part["xform"]
	var out: Array = []
	for xf in xforms:
		out.append((xf as Transform3D) * local)
	return _make_static_multimesh(part["mesh"], out, part.get("material"))

func _make_static_multimesh(mesh: Mesh, xforms: Array, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat
	return mmi

# --- PROP MESH LOADING ---

## Mesh của 1 loại prop, tách theo part (model glTF có thể gồm nhiều MeshInstance3D).
## Thiếu model → primitive fallback nhỏ để địa hình vẫn có chi tiết.
func _prop_parts(prop_id: String) -> Array:
	if _prop_parts_cache.has(prop_id):
		return _prop_parts_cache[prop_id]
	var parts: Array = []
	var path: String = PROP_MODEL_PATH % prop_id
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			_collect_mesh_parts(inst, Transform3D.IDENTITY, parts)
			inst.free()
		else:
			push_warning("GridController: prop '%s' không load được — dùng mesh fallback." % prop_id)
	if parts.is_empty():
		parts = _fallback_prop_parts(prop_id)
	_prop_parts_cache[prop_id] = parts
	return parts

func _collect_mesh_parts(node: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append({
			"mesh":     (node as MeshInstance3D).mesh,
			"xform":    xf,
			"material": (node as MeshInstance3D).material_override,
		})
	for child in node.get_children():
		_collect_mesh_parts(child, xf, out)

## Prop chưa có model .gltf → primitive thay thế, đủ để địa hình không trống trơn.
func _fallback_prop_parts(prop_id: String) -> Array:
	match prop_id:
		"tree_pine":
			return [_cone_part(0.34, 1.70, Color("2d4a1e"))]
		"tree_dead":
			return [_cyl_part(0.06, 0.14, 1.60, Color("4a3a28"))]
		"jungle_tree":
			return [_cone_part(0.42, 1.95, Color("2f6b22"))]
		"frozen_tree":
			return [_cone_part(0.32, 1.60, Color("9fc4d6"))]
		"charred_stump":
			return [_cyl_part(0.15, 0.22, 0.60, Color("241d1a"))]
		"obelisk":
			return [_box_part(Vector3(0.28, 1.45, 0.28), Color("2a1e20"))]
		"ice_spike":
			return [_cone_part(0.19, 0.95, Color("bfe4f5"))]
		"snow_rock":
			return [_box_part(Vector3(0.40, 0.30, 0.36), Color("d5e2ec"))]
		"lava_rock":
			return [_box_part(Vector3(0.38, 0.30, 0.34), Color("2e1f1c"))]
		"reed":
			return [_cyl_part(0.03, 0.05, 0.82, Color("6f7a3a"))]
		"mushroom":
			return [_cyl_part(0.15, 0.06, 0.26, Color("9a4a3c"))]
		"bush":
			return [_box_part(Vector3(0.42, 0.55, 0.42), Color("3b5c28"))]
		"rock":
			return [_box_part(Vector3(0.38, 0.32, 0.34), Color("6a6a66"))]
		"stump":
			return [_cyl_part(0.20, 0.24, 0.38, Color("55432c"))]
		_:
			return [_box_part(Vector3(0.16, 0.28, 0.16), Color("5c7a33"))]

func _box_part(size: Vector3, color: Color) -> Dictionary:
	var box := BoxMesh.new()
	box.size = size
	return _primitive_part(box, size.y, color)

func _cyl_part(top_r: float, bottom_r: float, height: float, color: Color) -> Dictionary:
	var cyl := CylinderMesh.new()
	cyl.top_radius    = top_r
	cyl.bottom_radius = bottom_r
	cyl.height        = height
	cyl.radial_segments = 6
	return _primitive_part(cyl, height, color)

func _cone_part(radius: float, height: float, color: Color) -> Dictionary:
	return _cyl_part(0.0, radius, height, color)

## Primitive mesh có tâm ở giữa → dịch lên height/2 để chân prop nằm đúng y = 0.
func _primitive_part(mesh: Mesh, height: float, color: Color) -> Dictionary:
	return {
		"mesh":     mesh,
		"xform":    Transform3D(Basis(), Vector3(0.0, height / 2.0, 0.0)),
		"material": _make_flat_material(color),
	}

# --- KING VISUAL ---

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
