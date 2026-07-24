# res://scripts/utils/fx.gd
# Hiệu ứng dùng chung — particle burst one-shot, không cần scene riêng.
class_name FX
extends Object

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
