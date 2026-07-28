# res://scripts/map/path_arrows.gd
#
# MŨI TÊN VÀNG chỉ hướng địch đi, rải dọc đường trên bàn cờ.
#
# Vì sao tách khỏi MapOverlayDrawer: drawer đó `free()` toàn bộ con mỗi lần
# state key đổi — mà state key có cả ô đang hover, nên nó rebuild liên tục khi
# rê chuột lúc đang đặt tháp. Mũi tên chỉ đổi khi ĐƯỜNG đổi (mở rộng bản đồ /
# rebase), tức vài lần mỗi ván. Nhét chung sẽ dựng lại hàng trăm mesh mỗi frame.
#
# Dùng MultiMesh: cả đường dài 100+ ô vẫn là MỘT draw call.
extends Node3D
class_name PathArrows

## Cao độ đặt mũi tên. Mặt ô = y 0, mesh ô lãnh thổ = 0.052, overlay quad = 0.06.
## 0.07 nằm trên tất cả nên mũi tên không bị z-fight, mà vẫn dưới model tháp.
## Ô đường đi không bao giờ có ô lãnh thổ nên không lo đè lên nhau.
const ARROW_Y: float = 0.07

## Kích thước mũi tên theo mét (1 ô = 1 m). Nhỏ vừa đủ đọc, không nuốt mặt ô.
const ARROW_LENGTH: float = 0.30
const ARROW_WIDTH:  float = 0.26
## Độ lõm đuôi — biến tam giác thành chevron, nhìn ra hướng rõ hơn tam giác đặc.
const ARROW_NOTCH:  float = 0.09

const ARROW_COLOR := Color(1.00, 0.82, 0.20, 0.85)

## Bỏ qua N ô cuối: ô cuối là chỗ Vua đứng, đã có cờ ⚑ của MapOverlayDrawer.
const SKIP_TAIL: int = 1

var grid_controller: GridController = null

var _multi: MultiMeshInstance3D = null
var _mesh: ArrayMesh = null

static func attach(owner_map: Node3D, gc: GridController) -> PathArrows:
	var a := PathArrows.new()
	a.name = "PathArrows"
	a.grid_controller = gc
	owner_map.add_child(a)
	a.rebuild()
	return a

func _ready() -> void:
	if _multi == null:
		_build_nodes()

# ── Dựng ──────────────────────────────────────────────────────────────────────

func _build_nodes() -> void:
	_mesh = _make_arrow_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	_multi = MultiMeshInstance3D.new()
	_multi.name = "ArrowMulti"
	_multi.multimesh = mm
	_multi.material_override = _make_material()
	# Mũi tên là chỉ dẫn, không phải vật thể — không đổ bóng, không nhận bóng.
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)

func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = ARROW_COLOR
	# Không kiểm chiều sâu: ô đường đi có thể dày lên (vệt bánh xe) và cắt mất
	# một phần mũi tên nếu bật depth test.
	mat.no_depth_test = true
	mat.render_priority = 1
	return mat

## Chevron nằm ngang trên mặt phẳng XZ, mũi hướng +Z. Bốn đỉnh, hai tam giác.
##
##            tip (0, +L/2)
##             /\
##            /  \
##   (-W/2,-L/2) (+W/2,-L/2)
##            \  /
##          notch (0, -L/2+N)
func _make_arrow_mesh() -> ArrayMesh:
	var half_l := ARROW_LENGTH * 0.5
	var half_w := ARROW_WIDTH * 0.5
	var tip   := Vector3(0.0, 0.0, half_l)
	var left  := Vector3(-half_w, 0.0, -half_l)
	var right := Vector3(half_w, 0.0, -half_l)
	var notch := Vector3(0.0, 0.0, -half_l + ARROW_NOTCH)

	# Thứ tự đỉnh ngược chiều kim đồng hồ nhìn từ TRÊN XUỐNG → pháp tuyến +Y,
	# tức mặt ngửa lên trời. Ngược lại thì camera nhìn xuống chỉ thấy mặt sau.
	var verts := PackedVector3Array([
		tip, left, notch,
		tip, notch, right,
	])
	var normals := PackedVector3Array()
	for i in verts.size():
		normals.append(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ── Cập nhật ──────────────────────────────────────────────────────────────────

## Dựng lại toàn bộ mũi tên theo đường hiện tại. game_map gọi khi bản đồ mở rộng
## hoặc rebase — hai lúc duy nhất đường đổi.
func rebuild() -> void:
	if _multi == null:
		_build_nodes()
	if grid_controller == null or not is_instance_valid(grid_controller):
		_multi.multimesh.instance_count = 0
		return

	var path: Array[Vector2i] = grid_controller.current_path_grid
	var count: int = maxi(0, path.size() - SKIP_TAIL - 1)
	_multi.multimesh.instance_count = count
	if count == 0:
		return

	for i in range(count):
		var here: Vector3 = GridUtil.cell_to_world(path[i])
		var next: Vector3 = GridUtil.cell_to_world(path[i + 1])
		var dir := Vector3(next.x - here.x, 0.0, next.z - here.z)
		# Hai ô liên tiếp luôn kề nhau nên dir không bao giờ bằng 0; guard đề
		# phòng đường sinh lỗi để không ra ma trận suy biến.
		var yaw: float = atan2(dir.x, dir.z) if dir.length_squared() > 0.0001 else 0.0
		var basis := Basis(Vector3.UP, yaw)
		var origin := Vector3(here.x, ARROW_Y, here.z)
		_multi.multimesh.set_instance_transform(i, Transform3D(basis, origin))

## Bật/tắt hiển thị (VD lúc quay phim hoặc chụp ảnh).
func set_arrows_visible(state: bool) -> void:
	if _multi:
		_multi.visible = state
