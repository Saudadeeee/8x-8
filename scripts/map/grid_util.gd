# res://scripts/map/grid_util.gd
# Chuyển đổi toạ độ grid ↔ world 3D (Y-up, tile = 1.0 m).
# Thay thế toàn bộ các call site map_to_local / local_to_map của TileMapLayer cũ.
class_name GridUtil
extends Object

const TILE_SIZE: float = 1.0

## Tâm ô (x, y) trên mặt phẳng y = 0.
static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)

## Ô chứa vị trí world (floor theo x, z).
static func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x)), int(floor(pos.z)))

## Giao điểm ray chuột với mặt phẳng y = 0.
## Trả về sentinel rất xa (map ra ô out-of-bounds) nếu ray không cắt mặt đất.
static func mouse_to_ground(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	if camera == null:
		return Vector3(-1e6, 0.0, -1e6)
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var direction: Vector3 = camera.project_ray_normal(mouse_pos)
	var ground := Plane(Vector3.UP, 0.0)
	var hit = ground.intersects_ray(origin, direction)
	if hit == null:
		return Vector3(-1e6, 0.0, -1e6)
	return hit as Vector3

## Ô grid dưới con trỏ chuột (qua ray-plane y = 0).
static func mouse_to_cell(camera: Camera3D, mouse_pos: Vector2) -> Vector2i:
	return world_to_cell(mouse_to_ground(camera, mouse_pos))
