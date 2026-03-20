# res://scripts/objects/projectile.gd
extends Area2D

var target: Enemy = null
var speed: float = 300.0
var damage: int = 10
var texture_data: Texture2D = null

# Special effects
var slow_amount: float = 0.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0
var burn_dps: int = 0
var burn_duration: float = 0.0

# Tham chiếu node hình ảnh (Bắt buộc trong Scene Projectile phải có node Sprite2D)
@onready var sprite: Sprite2D = $Sprite2D 

func _ready():
	# Giúp đạn bay độc lập, không bị dính chặt vào tháp
	top_level = true 
	
	# Kết nối va chạm
	area_entered.connect(_on_area_entered)
	
	# [MỚI] Gán hình ảnh nếu có
	if texture_data != null:
		sprite.texture = texture_data

func _process(delta):
	if is_instance_valid(target):
		# Hướng viên đạn xoay về phía mục tiêu
		look_at(target.global_position)
		
		# Bay tới mục tiêu
		position = position.move_toward(target.global_position, speed * delta)
		
		# Kiểm tra va chạm bằng khoảng cách (phòng hờ lag)
		if position.distance_to(target.global_position) < 5.0:
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
		var space = get_world_2d().direct_space_state
		var shape = CircleShape2D.new()
		shape.radius = splash_radius
		var params = PhysicsShapeQueryParameters2D.new()
		params.shape = shape
		params.transform = Transform2D(0.0, global_position)
		params.collision_mask = 2  # Layer "Enemy"
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
