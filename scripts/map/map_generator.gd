# res://scripts/map/map_generator.gd
# Sinh đường đi (DFS self-avoiding) cho enemy trên grid.
#
# Hai chế độ đích:
#   - Theo HÀNG  (cũ)  : target_cells rỗng → thành công khi current.y == target_y.
#   - Theo VÙNG  (mới) : target_cells có phần tử → thành công khi current ∈ target_cells.
#                        Dùng cho map mở rộng 4 hướng (đích là biên ngoài vùng mới).
#
# Bounds: bound_min/bound_max (exclusive ở max). Nếu bound_max chưa set (== ZERO)
# thì suy ra từ width/height để giữ tương thích với call site cũ; min_y cũ được
# hợp nhất vào bound_min.y.
extends Node
class_name MapGenerator

## Ngân sách thời gian cho generate_extension_to_region (ms) — DFS vét cạn trên board
## lớn (24×24) có thể rất chậm; expand chạy giữa 2 wave nên vẫn phải mượt.
const SHORTEN_BUDGET_MS: int = 120   # đã có đường: tối đa bấy nhiêu để tìm đường ngắn hơn
const SEARCH_BUDGET_MS:  int = 450   # chưa có đường nào: tối đa bấy nhiêu cho 1 mức relax
## Trần số bước cho MỘT lượt DFS. Không có trần này, backtracking có thể duyệt số
## đường đơn theo hàm mũ và treo hẳn game (đã gặp: expand không bao giờ trả về).
const MAX_DFS_STEPS: int = 40000

var width: int = 8
var height: int = 8
var min_y: int = 0
var min_path_length: int = 21
var blocked_positions: Dictionary = {}
var adjacent_blocked: Dictionary = {}  # Ô không được đứng cạnh (dùng khi nối đường)
var _dfs_steps: int = 0                # đếm bước cho lượt DFS hiện tại (chống bùng nổ)

# --- BOUNDS / TARGET (chế độ vùng) ---
## Góc nhỏ nhất của vùng DFS được phép đi (inclusive).
var bound_min: Vector2i = Vector2i.ZERO
## Góc lớn nhất của vùng DFS (EXCLUSIVE). Vector2i.ZERO = chưa set → suy từ width/height.
var bound_max: Vector2i = Vector2i.ZERO
## Tập ô đích (Vector2i → true). Rỗng = dùng cơ chế cũ theo target_y.
var target_cells: Dictionary = {}

const DIRECTIONS = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

func generate_path(start_pos: Vector2i, end_row_index: int) -> Array[Vector2i]:
	for i in range(100):
		var path = _try_generate_path(start_pos, end_row_index)
		if path.size() >= min_path_length:
			return path

	# Fallback: thử lại không có ràng buộc min_path_length để đảm bảo có đường
	push_warning("Không tìm được đường dài > %d ô. Thử sinh đường dự phòng." % min_path_length)
	var saved_min := min_path_length
	min_path_length = 1
	for i in range(50):
		var path = _try_generate_path(start_pos, end_row_index)
		if not path.is_empty():
			min_path_length = saved_min
			push_warning("Dùng đường dự phòng độ dài %d ô." % path.size())
			return path
	min_path_length = saved_min
	push_error("Không tìm được đường đi nào từ %s đến row %d!" % [str(start_pos), end_row_index])
	return []

func _try_generate_path(start: Vector2i, target_y: int) -> Array[Vector2i]:
	var stack: Array[Vector2i] = [start]
	var visited = {start: true}
	_dfs_steps = 0
	if _dfs_step(stack, visited, target_y):
		return stack
	return []

func _dfs_step(stack: Array[Vector2i], visited: Dictionary, target_y: int) -> bool:
	# DFS self-avoiding CÓ backtracking → số đường đơn có thể bùng nổ tổ hợp.
	# Trên board lớn + nhiều ô bị chặn, một lượt "xấu" từng chạy vô hạn (treo game).
	# Giới hạn số bước để MỌI lượt đều kết thúc; lượt thất bại sẽ được thử lại.
	_dfs_steps += 1
	if _dfs_steps > MAX_DFS_STEPS:
		return false

	var current = stack.back()
	if _is_goal(current, target_y):
		if stack.size() >= min_path_length:
			return true
		return false
	var potential_moves = DIRECTIONS.duplicate()
	potential_moves.shuffle()

	for move in potential_moves:
		var next_pos = current + move

		if is_valid_move(next_pos, current, visited):

			stack.append(next_pos)
			visited[next_pos] = true

			if _dfs_step(stack, visited, target_y):
				return true

			stack.pop_back()
			visited.erase(next_pos)

	return false

## Đích: theo tập ô nếu có target_cells, ngược lại theo hàng target_y (hành vi cũ).
func _is_goal(cell: Vector2i, target_y: int) -> bool:
	if target_cells.is_empty():
		return cell.y == target_y
	return target_cells.has(cell)

func generate_extension(start_pos: Vector2i, end_row_index: int) -> Array[Vector2i]:
	# Sinh đoạn nối dài từ start_pos (cuối path cũ) xuống end_row_index
	# min_y phải được set trước để giới hạn vùng sinh
	for i in range(300):
		var path = _try_generate_path(start_pos, end_row_index)
		if not path.is_empty():
			return path
	push_warning("Không tạo được đoạn mở rộng từ %s đến row %d" % [str(start_pos), end_row_index])
	return []

## Sinh đoạn nối dài từ start_pos tới BẤT KỲ ô nào trong `targets`.
## DFS có thứ tự hướng random nên retry nhiều lần; nếu vẫn thất bại thì nới dần
## min_path_length (giống fallback của generate_path) trước khi bỏ cuộc.
## Trả về [] nếu hết lượt — caller PHẢI coi đây là "không mở rộng được" và rollback.
func generate_extension_to_region(start_pos: Vector2i, targets: Dictionary, attempts: int = 40) -> Array[Vector2i]:
	if targets.is_empty():
		push_warning("MapGenerator: target_cells rỗng — không thể sinh đoạn mở rộng.")
		return []

	var saved_targets: Dictionary = target_cells
	var saved_min_len: int        = min_path_length
	target_cells = targets

	var relax_steps: Array[int] = [saved_min_len, maxi(1, int(saved_min_len / 2.0)), 1]
	var result: Array[Vector2i] = []

	# DFS ngẫu nhiên có thể trả về đoạn lượn rất dài (từng thấy +59 ô) → quái đi quá lâu.
	# Thử nhiều lần và GIỮ ĐOẠN NGẮN NHẤT; dừng sớm khi đã đủ gọn.
	# DFS vét cạn rất đắt trên board lớn → có ngân sách thời gian để không treo game.
	var good_enough: int = maxi(saved_min_len, int(saved_min_len * 2.2))
	var t_start: int = Time.get_ticks_msec()
	for step_len in relax_steps:
		min_path_length = step_len
		for i in range(attempts):
			var path := _try_generate_path(start_pos, -1)
			if not path.is_empty():
				if result.is_empty() or path.size() < result.size():
					result = path
				if result.size() <= good_enough:
					break
			var elapsed: int = Time.get_ticks_msec() - t_start
			# Đã có đường và hết ngân sách "tìm đường ngắn hơn" → dùng luôn.
			if not result.is_empty() and elapsed > SHORTEN_BUDGET_MS:
				break
			# Chưa có đường nào mà quá lâu → bỏ mức relax này, thử mức tiếp theo.
			if result.is_empty() and elapsed > SEARCH_BUDGET_MS:
				break
		if not result.is_empty():
			break
		if Time.get_ticks_msec() - t_start > SEARCH_BUDGET_MS:
			break

	target_cells    = saved_targets
	min_path_length = saved_min_len

	if result.is_empty():
		push_warning("MapGenerator: không nối được đường từ %s tới vùng đích (%d ô)."
			% [str(start_pos), targets.size()])
	return result

## Góc nhỏ nhất thực tế — hợp nhất min_y cũ vào bound_min.y.
func _effective_bound_min() -> Vector2i:
	return Vector2i(bound_min.x, maxi(bound_min.y, min_y))

## Góc lớn nhất thực tế (exclusive) — suy từ width/height nếu bound_max chưa set.
func _effective_bound_max() -> Vector2i:
	if bound_max == Vector2i.ZERO:
		return Vector2i(width, height)
	return bound_max

func is_valid_move(pos: Vector2i, from_pos: Vector2i, visited: Dictionary) -> bool:

	var bmin := _effective_bound_min()
	var bmax := _effective_bound_max()
	if pos.x < bmin.x or pos.x >= bmax.x or pos.y < bmin.y or pos.y >= bmax.y:
		return false

	if visited.has(pos):
		return false

	if blocked_positions.has(pos):
		return false

	for dir in DIRECTIONS:
		var neighbor = pos + dir
		if neighbor == from_pos:
			continue
		# Không được cạnh ô đã đi (tránh loop) hoặc ô path cũ (tuân thủ quy tắc cách nhau)
		if visited.has(neighbor) or adjacent_blocked.has(neighbor):
			return false

	return true
