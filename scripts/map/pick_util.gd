# res://scripts/map/pick_util.gd
# CHỌN Ô DƯỚI CON TRỎ — bản "biết nhìn model", thay cho ray-plane thuần.
#
# VÌ SAO TỒN TẠI
# `GridUtil.mouse_to_cell` cắt ray với mặt phẳng y = 0. Camera diorama nghiêng
# −50°, model tháp cao ~1.2 m ⇒ trên màn hình thân tháp nằm lệch khỏi ô của nó
# chừng 1.2 / tan(50°) ≈ 1.0 m, tức TRỌN MỘT Ô. Hệ quả: click vào thân tháp lại
# trúng ô phía sau; muốn chọn tháp phải rê chuột xuống đúng chân nó.
#
# CÁCH LÀM
# Bắn raycast vật lý vào layer "Pick" (mỗi tháp mang một hộp bằng đúng một ô,
# cao bằng model — xem `tower._build_pick_area`). Trúng thì lấy ô của tháp đó.
# Trượt thì rơi về ray-plane như cũ, nên ô trống vẫn chọn được bình thường.
class_name PickUtil
extends Object

## Bit layer dành riêng cho hộp click. Trùng `Tower.PICK_LAYER`.
const PICK_MASK: int = 8
## Tầm bắn tia — board tối đa 24×24 nên 200 m là thừa sức.
const RAY_LENGTH: float = 200.0

## Ô dưới con trỏ. Space state lấy TỪ CHÍNH CAMERA — bên gọi không phải là Node3D
## (TowerPlacer là Node thuần), nên không đòi thêm tham số node.
static func mouse_to_cell(camera: Camera3D, mouse_pos: Vector2) -> Vector2i:
	var hit := _pick_tower(camera, mouse_pos)
	if hit != null:
		return GridUtil.world_to_cell((hit as Node3D).global_position)
	return GridUtil.mouse_to_cell(camera, mouse_pos)

## Tháp dưới con trỏ, hoặc null. Dùng khi cần chính node tháp chứ không phải ô.
static func mouse_to_tower(camera: Camera3D, mouse_pos: Vector2) -> Node:
	return _pick_tower(camera, mouse_pos)

static func _pick_tower(camera: Camera3D, mouse_pos: Vector2) -> Node:
	if camera == null or not camera.is_inside_tree():
		return null
	var space := camera.get_world_3d().direct_space_state
	if space == null:
		return null

	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = origin + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	var params := PhysicsRayQueryParameters3D.create(origin, to)
	params.collision_mask = PICK_MASK
	# Hộp click là Area3D (không phải body) nên PHẢI bật collide_with_areas và
	# tắt collide_with_bodies, nếu không tia đi xuyên qua tất cả.
	params.collide_with_areas = true
	params.collide_with_bodies = false

	var result := space.intersect_ray(params)
	if result.is_empty():
		return null
	var collider = result.get("collider")
	if not (collider is Node) or not is_instance_valid(collider):
		return null
	# collider là PickArea; tháp là node CHA của nó.
	var tower := (collider as Node).get_parent()
	return tower if (tower is Node3D and is_instance_valid(tower)) else null
