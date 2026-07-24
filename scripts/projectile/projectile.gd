# res://scripts/objects/projectile.gd
extends Area3D

# splash_radius trong TowerStats vẫn là px (16 px = 1 tile) — quy đổi sang m
const PX_TO_M: float = 1.0 / 16.0
const HIT_DISTANCE: float = 0.2
const AIM_HEIGHT: float = 0.3

var target: Enemy = null
var speed: float = 18.75   # 300 px/s cũ ÷ 16 px/m
var damage: int = 10
var texture_data: Texture2D = null   # giữ cho tương thích cũ, không còn dùng
var color: Color = Color(1.0, 0.9, 0.5)

# Special effects
var slow_amount: float = 0.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0   # px — quy đổi khi query
var burn_dps: int = 0
var burn_duration: float = 0.0

@onready var mesh_instance: MeshInstance3D = $Mesh

func _ready():
	# Giúp đạn bay độc lập, không bị dính chặt vào tháp
	top_level = true

	# Kết nối va chạm
	area_entered.connect(_on_area_entered)

	_build_visual()

## Bolt mesh phát sáng theo màu tower (mesh + material riêng per instance).
func _build_visual() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.42)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mesh.material = mat
	mesh_instance.mesh = mesh

func _process(delta):
	if is_instance_valid(target):
		var aim: Vector3 = target.global_position + Vector3(0.0, AIM_HEIGHT, 0.0)

		# Hướng viên đạn xoay về phía mục tiêu (guard vị trí trùng nhau)
		if global_position.distance_squared_to(aim) > 0.000001:
			look_at(aim, Vector3.UP)

		# Bay tới mục tiêu
		position = position.move_toward(aim, speed * delta)

		# Kiểm tra va chạm bằng khoảng cách (phòng hờ lag)
		if position.distance_to(aim) < HIT_DISTANCE:
			hit_target()
	else:
		# Nếu mục tiêu chết giữa đường -> Hủy đạn
		queue_free()

func _on_area_entered(area):
	# Nếu va chạm đúng với mục tiêu đang nhắm
	if area == target:
		hit_target()

func hit_target():
	if not is_instance_valid(target):
		queue_free()
		return

	# Hiệu ứng nổ tại điểm chạm
	FX.spawn_burst(get_parent(), global_position, color, 8, 0.7)

	# Sát thương chính
	target.take_damage(damage)

	# Áp slow
	if slow_amount > 0.0 and slow_duration > 0.0:
		target.apply_slow(slow_amount, slow_duration)

	# Áp burn DoT
	if burn_dps > 0 and burn_duration > 0.0:
		target.apply_burn(burn_dps, burn_duration)

	# Splash AoE — tìm tất cả quái trong bán kính
	if splash_radius > 0.0:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var shape := SphereShape3D.new()
		shape.radius = splash_radius * PX_TO_M
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis.IDENTITY, global_position)
		params.collision_mask = 2  # Layer "Enemy"
		params.collide_with_areas = true
		params.collide_with_bodies = false
		var results = space.intersect_shape(params, 16)
		for r in results:
			var body = r.get("collider")
			if body == null:
				body = r.get("rid")
			if body is Enemy and body != target:
				body.take_damage(int(damage * 0.6))  # 60% splash damage
				if slow_amount > 0.0:
					body.apply_slow(slow_amount * 0.5, slow_duration)

	queue_free()
