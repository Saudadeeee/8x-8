# res://scripts/towers/chess_formation_overlay.gd
#
# TÔ SÁNG THẾ CỜ đang thành hình trên bàn.
#
# Cùng vai trò với `FormationOverlay` (hình thế theo ô nguyên tố) nhưng đọc
# `ChessFormations` — thế theo HÌNH HỌC QUÂN. Tách riêng vì hai hệ có nguồn dữ
# liệu khác nhau và có thể cùng hiện một lúc.
#
# Vì sao bắt buộc phải có: thế cờ là nguồn BỘI lớn nhất trong công thức. Không
# nhìn thấy nó thì người chơi không biết vì sao con số nhảy, và "xếp quân cho
# đúng" — trục chiến thuật chính — thành ra may rủi.
#
# CAO ĐỘ: quad y = 0.13 (trên overlay hình thế nguyên tố 0.12 để hai lớp không
# z-fight), nhãn y = 2.0 (cao hơn nhãn kia 1.7 để không chồng chữ).
class_name ChessFormationOverlay
extends Node3D

const OVERLAY_Y: float = 0.13
const LABEL_Y: float = 2.0
const QUAD_SIZE: float = 0.80
const FILL_ALPHA: float = 0.42
## Hai nhãn cùng tên trong bán kính này chỉ giữ MỘT — hai Trận Pháo cạnh nhau
## in cả hai sẽ thành "Trận PháoTrận Pháo" dính liền (lỗi đã gặp ở overlay kia).
const SAME_NAME_MERGE: float = 3.2

## Màu riêng từng thế — đọc được loại thế mà không cần đọc chữ.
const COLORS := {
	"battery":     Color(1.00, 0.55, 0.25),
	"crossfire":   Color(1.00, 0.30, 0.35),
	"knight_pair": Color(0.55, 0.80, 1.00),
	"pawn_wall":   Color(0.75, 0.95, 0.55),
	"royal_guard": Color(1.00, 0.85, 0.30),
	"echelon":     Color(0.80, 0.55, 1.00),
	"fork":        Color(0.35, 1.00, 0.85),
}

var _formations: Node = null
var _quad: PlaneMesh = null
var enabled: bool = true


static func attach(target: Node3D, formations: Node) -> ChessFormationOverlay:
	var ov := ChessFormationOverlay.new()
	ov.name = "ChessFormationOverlay"
	target.add_child(ov)
	ov.setup(formations)
	return ov


func setup(formations: Node) -> void:
	_formations = formations
	_quad = PlaneMesh.new()
	_quad.size = Vector2(QUAD_SIZE, QUAD_SIZE)
	if _formations and _formations.has_signal("formations_changed"):
		_formations.formations_changed.connect(_on_changed)
	rebuild()


func set_enabled(v: bool) -> void:
	enabled = v
	visible = v
	if v:
		rebuild()


func _on_changed(_counts: Dictionary) -> void:
	rebuild()


func rebuild() -> void:
	for c in get_children():
		c.free()
	if not enabled or _formations == null or not is_instance_valid(_formations):
		return

	# Gom ô theo thế rồi mới vẽ: một ô có thể thuộc nhiều thế, vẽ chồng nhiều
	# quad cùng chỗ sẽ z-fight nhấp nháy.
	var by_id := {}
	var cells: Dictionary = _formations.get("_cells")
	if not (cells is Dictionary):
		return
	for cell in cells:
		for id in cells[cell]:
			var key := str(id)
			by_id[key] = (by_id.get(key, []) as Array) + [cell]

	var labels: Array = []
	for id in by_id:
		var group: Array = by_id[id]
		var col: Color = COLORS.get(id, Color(1, 1, 1))
		var sum := Vector3.ZERO
		for cell in group:
			_draw_quad(cell, col)
			sum += GridUtil.cell_to_world(cell)
		labels.append({
			"pos": sum / float(maxi(1, group.size())),
			"text": ChessFormations.display_name(str(id)),
			"mult": ChessFormations.mult_of(str(id)),
			"color": col,
		})
	_place_labels(labels)


func _draw_quad(cell: Vector2i, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, FILL_ALPHA)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# no_depth_test: ô nguyên tố Lv3 dày 0.10 sẽ cắt mất một phần quad.
	mat.no_depth_test = true
	mat.render_priority = 2
	mi.material_override = mat
	var w := GridUtil.cell_to_world(cell)
	mi.position = Vector3(w.x, OVERLAY_Y, w.z)
	add_child(mi)


func _place_labels(labels: Array) -> void:
	var placed: Array = []
	for entry in labels:
		var pos: Vector3 = entry["pos"]
		var text: String = str(entry["text"])
		var skip := false
		for p in placed:
			if str(p["text"]) == text and Vector2(p["pos"].x - pos.x, p["pos"].z - pos.z).length() < SAME_NAME_MERGE:
				skip = true
				break
		if skip:
			continue
		placed.append({"pos": pos, "text": text})
		var lbl := Label3D.new()
		lbl.text = "%s  ×%.1f" % [text, float(entry["mult"])]
		lbl.font_size = 42
		lbl.pixel_size = 0.008
		lbl.modulate = entry["color"]
		lbl.outline_size = 16
		lbl.outline_modulate = Color(0.05, 0.04, 0.03)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.position = Vector3(pos.x, LABEL_Y, pos.z)
		add_child(lbl)
