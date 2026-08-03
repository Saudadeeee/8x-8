# res://scripts/towers/coverage_overlay.gd
#
# TÔ SÁNG TẦM PHỦ của quân đang được chọn.
#
# Vì sao bắt buộc phải có: với mô hình nước đi, "tầm bắn 5" KHÔNG nói lên gì cả —
# Xe tầm 5 phủ 20 ô theo hai trục, Mã tầm 5 phủ 16 ô hình chữ L, Tốt tầm 5 phủ 12
# ô chéo. Người chơi nhặt được "+1 tầm bắn" mà không có cách nào thấy nó đổi cái
# gì. Panel ghi "phủ 20 ô" là một con số trừu tượng; tô đúng ô lên bàn mới là
# thứ đọc được.
#
# Xem trước LÚC ĐẶT đã có ở `map_overlay_drawer`. Cái này là cho quân ĐÃ ĐẶT —
# click vào là thấy nó với tới đâu.
#
# CAO ĐỘ: quad y = 0.14, trên cả overlay hình thế nguyên tố (0.12) và thế cờ
# (0.13). Nó là lớp tạm thời do người chơi chủ động bật nên được nằm trên cùng.
class_name CoverageOverlay
extends Node3D

const OVERLAY_Y: float = 0.14
const QUAD_SIZE: float = 0.90
## Ô ĐƯỜNG ĐI đậm hơn hẳn: chỉ ô đường mới thật sự sinh sát thương.
const COLOR_PATH := Color(1.00, 0.85, 0.25, 0.60)
const COLOR_PLAIN := Color(0.45, 0.80, 1.00, 0.25)
## Ô của chính quân đang chọn.
const COLOR_HOME := Color(0.35, 1.00, 0.55, 0.55)

var map: Node3D = null
var _quad: PlaneMesh = null
var _shown_for: Node = null


static func attach(target: Node3D) -> CoverageOverlay:
	var ov := CoverageOverlay.new()
	ov.name = "CoverageOverlay"
	ov.map = target
	target.add_child(ov)
	return ov


func _ready() -> void:
	_quad = PlaneMesh.new()
	_quad.size = Vector2(QUAD_SIZE, QUAD_SIZE)


## Tô tầm phủ của `tower`. Truyền null để tắt.
func show_for(tower: Node) -> void:
	_clear()
	_shown_for = tower
	if tower == null or not is_instance_valid(tower):
		return
	if not tower.has_method("home_cell"):
		return

	var gc = map.get("grid_controller") if map else null
	_draw(tower.home_cell(), COLOR_HOME)
	var covered: Variant = tower.get("covered_cells")
	if not (covered is Array):
		return
	for c in (covered as Array):
		if not (c is Vector2i):
			continue
		if gc != null and not gc.is_in_bounds(c):
			continue
		var on_path: bool = gc != null and gc.is_path_cell(c)
		_draw(c, COLOR_PATH if on_path else COLOR_PLAIN)


func hide_all() -> void:
	_clear()
	_shown_for = null


## Vẽ lại cho quân đang chọn — gọi khi bố cục đổi (tầm của quân trượt đổi theo).
func refresh() -> void:
	if _shown_for != null and is_instance_valid(_shown_for):
		show_for(_shown_for)


func _clear() -> void:
	for c in get_children():
		c.free()


func _draw(cell: Vector2i, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# no_depth_test: ô nguyên tố Lv3 dày 0.10 sẽ cắt mất một phần quad.
	mat.no_depth_test = true
	mat.render_priority = 4
	mi.material_override = mat
	var w := GridUtil.cell_to_world(cell)
	mi.position = Vector3(w.x, OVERLAY_Y, w.z)
	add_child(mi)
