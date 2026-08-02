# res://scripts/map/map_overlay_drawer.gd
# Xử lý toàn bộ overlay 3D: build highlight, territory preview, dismiss mode, base marker.
# Quản lý pool quad (PlaneMesh) + Label3D thay cho _draw() 2D cũ.
# Chỉ rebuild khi state thay đổi (dirty key) — không rebuild mỗi frame.
# Được game_map.gd khởi tạo và làm con node.
extends Node3D
class_name MapOverlayDrawer

const TILE_SIZE: float = 1.0
const QUAD_SIZE: float = 0.92
const OVERLAY_Y: float = 0.06
const LABEL_Y:   float = 0.35
const _TM = preload("res://scripts/map/territory_manager.gd")

const COLOR_BUILD_HIGHLIGHT := Color(0.2, 1.0, 0.3, 0.35)
const COLOR_RANGE_DISC      := Color(1.0, 1.0, 1.0, 0.15)
const COLOR_DISMISS_TILE    := Color(1.0, 0.1, 0.1, 0.25)
const COLOR_DISMISS_HOVER   := Color(1.0, 0.1, 0.1, 0.55)
const COLOR_BASE_MARKER     := Color(0.78, 0.63, 0.0, 0.65)

# --- REFS (set bởi game_map sau add_child) ---
var territory_manager = null
var tower_placer:    TowerPlacer    = null
var grid_controller: GridController = null

# --- INTERNAL ---
var _quad_mesh: PlaneMesh = null
var _last_state_key: String = ""

func setup(tm, tp: TowerPlacer, gc: GridController) -> void:
	territory_manager = tm
	tower_placer      = tp
	grid_controller   = gc
	_quad_mesh = PlaneMesh.new()
	_quad_mesh.size = Vector2(QUAD_SIZE, QUAD_SIZE)

# --- LIFECYCLE ---

func _process(_delta: float) -> void:
	if not tower_placer or not grid_controller:
		return
	var key := _compute_state_key()
	if key == _last_state_key:
		return
	_last_state_key = key
	_rebuild()

# --- DIRTY TRACKING ---

func _hovered_cell() -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2i(-9999, -9999)
	# Cùng cách chọn như game_map: ô được tô sáng phải TRÙNG ô sẽ nhận click,
	# nếu không con trỏ ✕ (dismiss) sẽ sáng ở một ô rồi click lại ăn ô khác.
	return PickUtil.mouse_to_cell(camera, get_viewport().get_mouse_position())

func _compute_state_key() -> String:
	var gc := grid_controller
	var tp := tower_placer
	var build_id: String = tp.current_building_stats.id if tp.current_building_stats else ""
	var placing: String = territory_manager.get_pending_biome() \
		if territory_manager and territory_manager.is_placing() else ""
	var hover := _hovered_cell()
	var base: Vector2i = gc.current_path_grid.back() if not gc.current_path_grid.is_empty() else Vector2i(-1, -1)
	var biome_count: int = territory_manager.biome_tiles.size() if territory_manager else 0
	# hover chỉ ảnh hưởng dismiss overlay + range disc → chỉ đưa vào key khi cần
	var hover_part := str(hover) if (tp._dismiss_mode or build_id != "") else ""
	return "%s|%s|%s|%d|%d|%d|%s|%s" % [
		build_id, placing, str(tp._dismiss_mode),
		gc.grid_height, gc.grid_data.size(), biome_count,
		str(base), hover_part,
	]

# --- REBUILD ---

func _rebuild() -> void:
	for child in get_children():
		child.free()

	var gc := grid_controller
	var tp := tower_placer

	_build_build_highlights(gc, tp)
	_build_territory_placement(gc)
	_build_dismiss_overlay(gc, tp)
	_build_base_marker(gc)

func _build_build_highlights(gc: GridController, tp: TowerPlacer) -> void:
	if not tp.current_building_stats:
		return

	# Highlight các ô hợp lệ
	for y in range(gc.grid_height):
		for x in range(gc.grid_width):
			var pos := Vector2i(x, y)
			if gc.is_path_cell(pos):            continue
			if gc.grid_data.get(pos) is Node3D: continue
			_add_quad(GridUtil.cell_to_world(pos), COLOR_BUILD_HIGHLIGHT)

	# Xem trước TẦM PHỦ theo NƯỚC ĐI, không phải đĩa tròn.
	#
	# Đĩa tròn nói dối: Xe đặt ở đây phủ trọn cột chứ không phủ hình tròn, và
	# đường trượt của nó bị quân khác CHẶN. Vẽ đúng ô sẽ phủ là thứ biến việc đặt
	# quân thành bài toán nhìn-là-thấy — đây là phản hồi quan trọng nhất của cả
	# thiết kế mới, thiếu nó thì người chơi đặt mò.
	var hover := _hovered_cell()
	if gc.is_in_bounds(hover):
		var st: TowerStats = tp.current_building_stats
		var kind: int = int(st.attack_pattern)
		if kind == ChessPattern.Kind.RADIAL:
			var radius: float = st.attack_range * TILE_SIZE + (TILE_SIZE / 2.0)
			_add_disc(GridUtil.cell_to_world(hover), radius, COLOR_RANGE_DISC)
		else:
			var blocked := {}
			for t in get_tree().get_nodes_in_group("towers"):
				if is_instance_valid(t) and t.has_method("home_cell"):
					blocked[t.home_cell()] = true
			blocked.erase(hover)
			for c in ChessPattern.cells(kind, hover, st.attack_range, blocked):
				if gc.is_in_bounds(c):
					# Ô ĐƯỜNG ĐI tô đậm hơn: chỉ ô đường mới thật sự sinh sát
					# thương, phủ ô trống là phủ hụt.
					_add_quad(GridUtil.cell_to_world(c),
						COLOR_COVER_PATH if gc.is_path_cell(c) else COLOR_COVER)

## Màu tầm phủ theo nước đi. Ô đường đi đậm hơn hẳn ô thường.
const COLOR_COVER      := Color(0.35, 0.75, 1.00, 0.22)
const COLOR_COVER_PATH := Color(1.00, 0.80, 0.20, 0.55)


func _build_territory_placement(gc: GridController) -> void:
	if not territory_manager or not territory_manager.is_placing():
		return

	var biome_tag: String = territory_manager.get_pending_biome()
	var bdata = _TM.BIOME_STATS.get(biome_tag, null)
	var hi_col := Color(0.3, 0.5, 1.0, 0.4)
	if bdata:
		var bc: Color = bdata["color"]
		hi_col = Color(bc.r, bc.g, bc.b, 0.4)

	# get_placeable_tiles gồm CẢ ô nâng cấp được (cùng loại, chưa đủ cấp) — nếu chỉ
	# dùng get_available_tiles thì ô nâng cấp không được tô, player không biết đặt lên được.
	var cells: Array = []
	if territory_manager.has_method("get_placeable_tiles"):
		cells = territory_manager.get_placeable_tiles(gc.grid_data, biome_tag)
	else:
		cells = territory_manager.get_available_tiles(gc.grid_data)
	for vpos in cells:
		var center: Vector3 = GridUtil.cell_to_world(vpos)
		var is_upgrade: bool = territory_manager.has_method("is_upgrade_target") \
			and territory_manager.is_upgrade_target(vpos, biome_tag)
		# Ô nâng cấp tô VÀNG + nhãn ▲ để phân biệt với ô đặt mới
		_add_quad(center, Color(1.0, 0.85, 0.25, 0.45) if is_upgrade else hi_col)
		_add_label(center, "▲" if is_upgrade else "+", Color(1, 1, 1, 0.95))

func _build_dismiss_overlay(gc: GridController, tp: TowerPlacer) -> void:
	if not tp._dismiss_mode:
		return

	# Highlight tất cả towers
	for pos in gc.grid_data.keys():
		var e = gc.grid_data.get(pos)
		if not (e is Node3D and is_instance_valid(e)): continue
		_add_quad(GridUtil.cell_to_world(pos), COLOR_DISMISS_TILE)

	# Con trỏ ✕ tại ô hover
	var hover := _hovered_cell()
	if not gc.is_in_bounds(hover):
		return
	var center: Vector3 = GridUtil.cell_to_world(hover)
	var entry = gc.grid_data.get(hover)
	if entry is Node3D and is_instance_valid(entry):
		_add_quad(center, COLOR_DISMISS_HOVER)
		_add_label(center, "✕", Color(1, 1, 1, 1.0))
	else:
		_add_label(center, "✕", Color(1, 0.3, 0.3, 0.6))

func _build_base_marker(gc: GridController) -> void:
	if gc.current_path_grid.is_empty():
		return
	var base_pos: Vector2i = gc.current_path_grid.back()
	var center: Vector3 = GridUtil.cell_to_world(base_pos)
	_add_quad(center, COLOR_BASE_MARKER)
	_add_label(center, "⚑", Color(1, 1, 1, 0.95))

# --- PRIMITIVES ---

func _make_overlay_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat

func _add_quad(center: Vector3, color: Color) -> void:
	var quad := MeshInstance3D.new()
	quad.mesh = _quad_mesh
	quad.material_override = _make_overlay_material(color)
	quad.position = Vector3(center.x, OVERLAY_Y, center.z)
	add_child(quad)

func _add_disc(center: Vector3, radius: float, color: Color) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	var disc := MeshInstance3D.new()
	disc.mesh = cyl
	disc.material_override = _make_overlay_material(color)
	disc.position = Vector3(center.x, OVERLAY_Y / 2.0, center.z)
	add_child(disc)

func _add_label(center: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0006
	label.outline_size = 8
	label.position = Vector3(center.x, LABEL_Y, center.z)
	add_child(label)
