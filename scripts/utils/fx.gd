# res://scripts/utils/fx.gd
# Hiệu ứng dùng chung — particle burst one-shot, damage number, click ring.
# Không cần scene riêng.
class_name FX
extends Object

# Giới hạn số damage number đang sống — tránh spam label khi splash/burn dày đặc.
const MAX_LIVE_LABELS: int = 60
static var _live_labels: int = 0

## Nổ particle nhỏ tại vị trí world. Tự free khi chạy xong.
static func spawn_burst(
		parent: Node,
		pos: Vector3,
		color: Color,
		amount: int = 12,
		burst_scale: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.6 * burst_scale
	p.initial_velocity_max = 3.2 * burst_scale
	p.gravity = Vector3(0.0, -7.0, 0.0)
	p.scale_amount_min = 0.5 * burst_scale
	p.scale_amount_max = 1.0 * burst_scale

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mesh.material = mat
	p.mesh = mesh

	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)

## Số sát thương/hồi máu bay lên tại vị trí world — Label3D billboard tự free.
## Add vào parent (không phải enemy) để label không di chuyển theo mục tiêu.
static func damage_number(
		parent: Node,
		pos: Vector3,
		text: String,
		color: Color = Color.WHITE,
		size: int = 18) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _live_labels >= MAX_LIVE_LABELS:
		return
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = size
	lbl.pixel_size = 0.01
	lbl.modulate = color
	lbl.outline_size = maxi(4, int(size / 3.0))
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.fixed_size = false
	lbl.no_depth_test = true   # đọc xuyên qua model
	parent.add_child(lbl)
	lbl.global_position = pos
	_live_labels += 1
	# tree_exited bắt mọi đường free (tween xong / parent bị free) — counter không leak
	lbl.tree_exited.connect(func(): FX._live_labels = maxi(0, FX._live_labels - 1))
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.5, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_property(lbl, "outline_modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

## Hiệu ứng nổ riêng cho từng phản ứng nguyên tố (xem ReactionTable).
## Mỗi phản ứng có chữ ký thị giác khác hẳn nhau — người chơi phải nhận ra
## chuyện gì vừa xảy ra mà không cần đọc chữ.
static func reaction_burst(parent: Node, pos: Vector3, reaction_id: String) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var core := pos + Vector3(0.0, 0.45, 0.0)
	var ground := Vector3(pos.x, 0.02, pos.z)
	match reaction_id:
		"vaporize":
			# Bốc Hơi: chớp trắng dày, hơi nước bung nhỏ và gọn — sát thương đơn mục tiêu.
			spawn_burst(parent, core, Color(1.0, 0.97, 0.9), 24, 0.55)
			spawn_burst(parent, core, Color(1.0, 0.62, 0.2), 12, 0.85)
		"melt":
			# Tan Chảy: dung nham cam-đỏ chảy xuống + vệt sáng dưới chân (giáp tan).
			spawn_burst(parent, core, Color(1.0, 0.42, 0.16), 20, 1.0)
			spawn_burst(parent, core, Color(0.95, 0.75, 0.25), 8, 0.5)
			spawn_click_ring(parent, ground, Color(1.0, 0.5, 0.2))
		"freeze":
			# Đóng Băng: mảnh băng bay chậm + vòng băng lan trên đất.
			spawn_burst(parent, core, Color(0.65, 0.92, 1.0), 18, 0.6)
			spawn_click_ring(parent, ground, Color(0.6, 0.88, 1.0))
		"conduct":
			# Dẫn Điện: tia tím bắn XA để đọc được hướng lan sang bầy.
			spawn_burst(parent, core, Color(0.82, 0.5, 1.0), 22, 2.0)
			spawn_burst(parent, core, Color(1.0, 0.95, 1.0), 6, 1.2)
		"overload":
			# Quá Tải: nổ to nhất trong 6 phản ứng + sóng xung kích dưới đất.
			spawn_burst(parent, core, Color(1.0, 0.85, 0.3), 28, 2.2)
			spawn_burst(parent, core, Color(1.0, 0.45, 0.15), 14, 1.4)
			spawn_click_ring(parent, ground, Color(1.0, 0.8, 0.25))
		"contagion":
			# Lan Truyền: mây độc xanh lan rộng, hạt rơi chậm (gravity nhẹ qua scale lớn).
			spawn_burst(parent, core, Color(0.5, 1.0, 0.4), 26, 1.6)
			spawn_click_ring(parent, ground, Color(0.45, 0.95, 0.35))
		"superconduct":
			# Siêu Dẫn: chớp xanh lạnh + vòng rộng dưới đất = tầm ảnh hưởng phá giáp.
			spawn_burst(parent, core, Color(0.55, 0.72, 1.0), 22, 1.8)
			spawn_burst(parent, core, Color(0.9, 0.96, 1.0), 8, 1.0)
			spawn_click_ring(parent, ground, Color(0.5, 0.7, 1.0))
		"toxic_burn":
			# Cháy Độc: xanh nõn pha cam — đọc ra ngay là Độc gặp Hoả.
			spawn_burst(parent, core, Color(0.78, 0.98, 0.22), 24, 1.3)
			spawn_burst(parent, core, Color(1.0, 0.55, 0.15), 10, 0.9)
		"quake":
			# Chấn Địa: hạt đất nâu bắn thấp + hai vòng sóng chồng nhau trên mặt đất.
			spawn_burst(parent, core, Color(0.72, 0.55, 0.32), 20, 1.1)
			spawn_click_ring(parent, ground, Color(0.85, 0.65, 0.35))
			spawn_click_ring(parent, ground, Color(0.55, 0.4, 0.22))
		"primal":
			# Nguyên Sơ: to nhất hệ — chớp trắng, ba vòng sóng, hạt bay rất xa.
			spawn_burst(parent, core, Color(1.0, 0.97, 0.85), 34, 2.8)
			spawn_burst(parent, core, Color(0.85, 0.7, 1.0), 18, 1.8)
			spawn_click_ring(parent, ground, Color(1.0, 0.95, 0.75))
			spawn_click_ring(parent, ground, Color(0.8, 0.65, 1.0))
			spawn_click_ring(parent, ground, Color(1.0, 0.85, 0.4))
		"crystallize":
			# Kết Tinh: mảnh vàng lấp lánh bay lên — tín hiệu "ra tiền".
			spawn_burst(parent, core, Color(1.0, 0.87, 0.38), 18, 0.9)
			spawn_burst(parent, core, Color(1.0, 1.0, 0.8), 6, 0.5)
		_:
			push_warning("FX.reaction_burst: chưa có hiệu ứng cho '%s'" % reaction_id)
			spawn_burst(parent, core, Color.WHITE, 10, 1.0)

## Vòng tròn ma thuật nở ra khi click đất trống — ring phẳng + sparkle nhỏ, 0.4s.
static func spawn_click_ring(
		parent: Node,
		pos: Vector3,
		color: Color = Color(0.55, 0.8, 1.0)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	torus.material = mat
	ring.mesh = torus
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0.0, 0.03, 0.0)
	ring.scale = Vector3(0.3, 0.3, 0.3)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.6, 0.5, 1.6), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
	spawn_burst(parent, pos + Vector3(0.0, 0.1, 0.0), color, 6, 0.4)
