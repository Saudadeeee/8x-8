# res://scripts/elements/formation_overlay.gd
# VẼ HÌNH THẾ LÊN BÀN CỜ (futureplan §2.3).
#
# Vì sao cần: hình thế là phần thưởng cho việc BỐ TRÍ ô, nhưng trước đây nó chỉ
# hiện trong panel khi click từng ô. Người chơi không thấy được "hai ô này đang
# ghép thành Song Cực" nên không có lý do gì để nghĩ về bố cục — cả một trục
# thiết kế trở nên vô hình.
#
# Rebuild CHỈ khi `formations_changed` phát (đặt/nâng/bán ô), không phải mỗi
# frame: bố cục đổi rất thưa so với tốc độ khung hình.
#
# Bất biến cao độ: mặt ô nguyên tố dày nhất chạm y = TILE_Y + 0.10/2 = 0.102,
# nên overlay phải nằm TRÊN mốc đó, nếu không Lv3 sẽ che mất.
extends Node3D
class_name FormationOverlay

const OVERLAY_Y: float = 0.12
const QUAD_SIZE: float = 0.86
# 1.7: cao hơn model tháp (~1.0-1.3m) — để thấp hơn thì nhãn nằm LỌT TRONG thân
# tháp và không đọc được, đúng lỗi đã gặp ở bản đầu.
const LABEL_Y: float = 1.7
## Vien day bao nhieu met. Du day de thay tu goc camera diorama, du mong de
## khong che mat rune giua o.
const BORDER_THICK: float = 0.14
const FILL_ALPHA: float = 0.70

## Màu riêng cho từng hình thế — đọc được loại hình thế mà không cần đọc chữ.
const FORMATION_COLORS: Dictionary = {
	"dragon_line": Color(1.00, 0.82, 0.30),
	"four_pillar": Color(0.45, 0.85, 1.00),
	"dual_pole":   Color(0.95, 0.45, 1.00),
	"ring":        Color(0.50, 1.00, 0.60),
}

var _territory_manager: Node = null
var _quad_mesh: PlaneMesh = null
## Bật/tắt toàn bộ lớp này (nút trên HUD sau này có thể dùng).
var enabled: bool = true

func setup(territory_manager: Node) -> void:
	_territory_manager = territory_manager
	_quad_mesh = PlaneMesh.new()
	_quad_mesh.size = Vector2(QUAD_SIZE, QUAD_SIZE)
	if _territory_manager != null and _territory_manager.has_signal("formations_changed"):
		_territory_manager.formations_changed.connect(_on_formations_changed)
	rebuild()

func _on_formations_changed(_data: Dictionary) -> void:
	rebuild()

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if value:
		rebuild()

func rebuild() -> void:
	for child in get_children():
		child.free()
	if not enabled or _territory_manager == null or not is_instance_valid(_territory_manager):
		return
	if not _territory_manager.has_method("get_formation_groups"):
		return

	# Ve o truoc, gom nhan sau: hai nhom cung loai co centroid trung nhau se in
	# de len nhau thanh chu dinh lien ("Song CucSong Cuc"). Gom lai roi day ra.
	var labels: Array = []
	for entry in _territory_manager.call("get_formation_groups"):
		if entry is Dictionary:
			var spot = _draw_group(entry as Dictionary)
			if spot != null:
				labels.append(spot)
	_place_labels(labels)

## Dat nhan, tranh cho cac nhan qua gan nhau. Nhan trung vi tri thi day len cao
## dan; nhan cung TEN va cung cho thi bo han (mot ten la du).
## Hai nhan KHAC ten gan nhau thi day len cao dan (van doc duoc ca hai).
const LABEL_MIN_GAP: float = 0.9
const LABEL_STEP_Y: float = 0.42
## Hai nhan CUNG ten trong ban kinh nay chi giu MOT. Bon o lien nhau co the tao
## hai cap Song Cuc rieng biet, in ca hai thi thanh "Song Cuc Song Cuc" dinh lien.
const SAME_NAME_MERGE: float = 3.2

func _place_labels(labels: Array) -> void:
	var placed: Array = []
	for item in labels:
		var pos: Vector3 = item["pos"]
		var text: String = item["text"]
		var skip := false
		for prev in placed:
			var d: float = Vector2(pos.x - prev["pos"].x, pos.z - prev["pos"].z).length()
			if str(prev["text"]) == text and d < SAME_NAME_MERGE:
				skip = true
				break
			if d < LABEL_MIN_GAP:
				pos.y += LABEL_STEP_Y
		if skip:
			continue
		_add_label(pos, text, item["color"])
		placed.append({"pos": pos, "text": text})

## Ve o cua mot nhom, tra ve vi tri + chu cho nhan (null neu nhom rong).
func _draw_group(group: Dictionary):
	var id := str(group.get("id", ""))
	var color: Color = FORMATION_COLORS.get(id, Color.WHITE)
	# Trận Vòng gắn thẻ vào ô GIỮA (ô thường), nhưng thứ đáng nhìn là 4 ô tạo
	# vòng — vẽ cả hai để người chơi thấy quan hệ.
	var cells: Array = _cells_of(group)
	if cells.is_empty():
		return null

	var centroid := Vector3.ZERO
	for cell in cells:
		var world: Vector3 = GridUtil.cell_to_world(cell)
		_add_quad(world, color)
		centroid += world
	centroid /= float(cells.size())
	return {"pos": Vector3(centroid.x, LABEL_Y, centroid.z),
		"text": FormationDetector.display_name(id), "color": color}

func _cells_of(group: Dictionary) -> Array:
	var out: Array = []
	var cells = group.get("cells")
	if cells is Array:
		for cell in cells:
			if cell is Vector2i:
				out.append(cell)
	var ring = group.get("ring_cells")
	if ring is Array:
		for cell in ring:
			if cell is Vector2i and not out.has(cell):
				out.append(cell)
	return out

func _add_quad(center: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Cộng màu thay vì phủ màu: ô nguyên tố bên dưới vẫn đọc được nguyên tố của nó,
	# lớp hình thế chỉ "sáng thêm" lên trên.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, FILL_ALPHA)
	# BON THANH VIEN thay vi mot tam to kin: to kin cong mau len ca o se lam bay
	# mau nguyen to va NUOT MAT rune duoi day — chinh thu giup doc ban co.
	var t := BORDER_THICK
	var half := QUAD_SIZE * 0.5
	for edge in [Vector3(0, 0, -half + t * 0.5), Vector3(0, 0, half - t * 0.5),
			Vector3(-half + t * 0.5, 0, 0), Vector3(half - t * 0.5, 0, 0)]:
		var bar := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		if absf(edge.x) > 0.001:
			mesh.size = Vector2(t, QUAD_SIZE)
		else:
			mesh.size = Vector2(QUAD_SIZE, t)
		bar.mesh = mesh
		bar.material_override = mat
		bar.position = Vector3(center.x + edge.x, OVERLAY_Y, center.z + edge.z)
		add_child(bar)

func _add_label(center: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.00040
	# Luôn vẽ đè lên model: nhãn bị tháp che thì coi như không có.
	label.no_depth_test = true
	label.render_priority = 2
	label.position = Vector3(center.x, center.y, center.z)
	add_child(label)
