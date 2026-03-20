# res://scripts/map/map_generator.gd
extends Node
class_name MapGenerator

var width: int = 8
var height: int = 8
var min_y: int = 0
var min_path_length: int = 21
var blocked_positions: Dictionary = {}
var adjacent_blocked: Dictionary = {}  # Ô không được đứng cạnh (dùng khi nối đường)

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
	if _dfs_step(stack, visited, target_y):
		return stack
	return []

func _dfs_step(stack: Array[Vector2i], visited: Dictionary, target_y: int) -> bool:
	var current = stack.back()
	if current.y == target_y:
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

func generate_extension(start_pos: Vector2i, end_row_index: int) -> Array[Vector2i]:
	# Sinh đoạn nối dài từ start_pos (cuối path cũ) xuống end_row_index
	# min_y phải được set trước để giới hạn vùng sinh
	for i in range(300):
		var path = _try_generate_path(start_pos, end_row_index)
		if not path.is_empty():
			return path
	push_warning("Không tạo được đoạn mở rộng từ %s đến row %d" % [str(start_pos), end_row_index])
	return []

func is_valid_move(pos: Vector2i, from_pos: Vector2i, visited: Dictionary) -> bool:

	if pos.x < 0 or pos.x >= width or pos.y < min_y or pos.y >= height:
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
