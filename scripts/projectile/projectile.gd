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

# ── Nguyên tố (đến từ Ô tháp đứng — xem futureplan.md §2) ─────────────────
## Dấu chính viên đạn sẽ gắn lên địch. Rỗng = đòn vật lý thuần.
var element: String = ""
## Dấu phụ (trang bị "Bình Chứa Kép") — gắn cùng lúc, có thể tự kích phản ứng.
var element_secondary: String = ""
## Tháp bắn ra viên này — dùng để lấy reaction_power_mult / mark_duration_mult.
var element_source: Node = null
## Thuốc "Tinh Dầu Xuyên Giáp": bỏ qua giáp mục tiêu cho đòn này.
var pierce_armor: bool = false

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

		# Hướng viên đạn xoay về phía mục tiêu.
		# Guard PHẲNG (bỏ trục y) chứ không guard khoảng cách 3D: khi địch đứng
		# thẳng trên/dưới viên đạn, hướng nhìn song song với Vector3.UP và
		# `look_at` báo lỗi "up vector and direction are aligned" mỗi frame.
		# Xảy ra thật khi địch đi vào đúng ô của tháp.
		var flat := Vector2(aim.x - global_position.x, aim.z - global_position.z)
		if flat.length_squared() > 0.000001:
			look_at(aim, Vector3.UP)

		# Bay tới mục tiêu
		position = position.move_toward(aim, speed * delta)

		# Kiểm tra va chạm bằng khoảng cách (phòng hờ lag)
		if position.distance_to(aim) < HIT_DISTANCE:
			hit_target()
	else:
		# Nếu mục tiêu chết giữa đường -> Hủy đạn
		queue_free()

# ── Hiệu ứng trang bị của tháp bắn ra viên này ────────────────────────────
# Mọi giá trị đọc qua `element_source.get(...)`: `element_source` khai kiểu Node
# nên truy cập thẳng thuộc tính sẽ lỗi parse.

func _equip_float(key: String) -> float:
	if not is_instance_valid(element_source):
		return 0.0
	var value: Variant = element_source.get(key)
	return float(value) if (value is int or value is float) else 0.0

## Hệ số nhân từ trang bị điều kiện. Các nguồn CỘNG với nhau rồi mới nhân một lần
## (Lao Săn + Hộ Phù = ×1.9), không nhân chồng — tránh combo trang bị bùng nổ.
func _conditional_mult(enemy: Node) -> float:
	if not is_instance_valid(element_source) or not is_instance_valid(enemy):
		return 1.0
	var bonus := 0.0

	var full := _equip_float("equip_bonus_vs_full")
	if full > 0.0 and _hp_ratio(enemy) >= 0.999:
		bonus += full
	var low := _equip_float("equip_bonus_vs_low")
	if low > 0.0 and _hp_ratio(enemy) <= 0.25:
		bonus += low
	var marked := _equip_float("equip_bonus_vs_marked")
	if marked > 0.0 and _has_mark(enemy):
		bonus += marked
	return 1.0 + bonus

## Tỉ lệ máu hiện tại. `_max_hp` là máu đã scale theo wave (nguồn sự thật của enemy).
func _hp_ratio(enemy: Node) -> float:
	var current: Variant = enemy.get("current_hp")
	var maximum: Variant = enemy.get("_max_hp")
	if not (current is int or current is float):
		return 1.0
	var cap := float(maximum) if (maximum is int or maximum is float) else 0.0
	if cap <= 0.0:
		return 1.0
	return clampf(float(current) / cap, 0.0, 1.0)

func _has_mark(enemy: Node) -> bool:
	var marks: Variant = enemy.get("marks")
	if not (marks is Node) or not is_instance_valid(marks):
		return false
	if not marks.has_method("mark_count"):
		return false
	return int((marks as Node).call("mark_count")) > 0

## Búa Chấn Động — dùng CHUNG meta đóng băng của ReactionTable nên chỉ có một
## nguồn sự thật cho "địch đang bị khoá", không sinh hệ choáng thứ hai.
func _try_stun(enemy: Node) -> void:
	var chance := _equip_float("equip_stun_chance")
	if chance <= 0.0 or randf() >= chance or not is_instance_valid(enemy):
		return
	var until := ElementMarks.now() + 0.5
	if not enemy.has_meta(ReactionTable.META_FROZEN_UNTIL) \
			or float(enemy.get_meta(ReactionTable.META_FROZEN_UNTIL)) < until:
		enemy.set_meta(ReactionTable.META_FROZEN_UNTIL, until)

## Cung Xuyên Táo — "xuyên" mô phỏng bằng đánh thêm N địch GẦN NHẤT quanh điểm
## chạm. Xuyên theo tia thật cần raycast dọc hướng bay và đổi cả vòng đời viên
## đạn; xấp xỉ này giữ đúng cảm giác (nhiều mục tiêu mỗi phát) với chi phí nhỏ.
const PIERCE_RADIUS: float = 1.6

func _pierce_behind(base_damage: int) -> void:
	var count := int(_equip_float("equip_pierce_targets"))
	if count <= 0 or not is_inside_tree():
		return
	var hit := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if hit >= count:
			return
		if node == target or not is_instance_valid(node) or not (node is Node3D):
			continue
		if bool(node.get("_is_dead")):
			continue
		if (node as Node3D).global_position.distance_to(global_position) > PIERCE_RADIUS:
			continue
		node.call("take_damage", base_damage, "hit")
		hit += 1

## Kiếm Hút Máu — chỉ tính khi chính đòn này hạ mục tiêu.
func _report_kill(enemy: Node) -> void:
	if not is_instance_valid(element_source) or not is_instance_valid(enemy):
		return
	if not bool(enemy.get("_is_dead")):
		return
	if element_source.has_method("on_kill_confirmed"):
		element_source.call("on_kill_confirmed")

func _on_area_entered(area):
	# Nếu va chạm đúng với mục tiêu đang nhắm
	if area == target:
		hit_target()

func hit_target():
	if not is_instance_valid(target):
		queue_free()
		return

	# Roll crit — 1 lần mỗi viên đạn, đọc chỉ số từ GameManager (guard thiếu singleton)
	var crit_chance: float = 0.05
	var crit_mult: float = 2.0
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm:
		var gc = gm.get("crit_chance")
		var gx = gm.get("crit_mult")
		if gc != null: crit_chance = float(gc)
		if gx != null: crit_mult = float(gx)
	# Trang bị chí mạng của CHÍNH tháp bắn ra — cộng lên tỉ lệ toàn cục.
	if is_instance_valid(element_source):
		var bonus: Variant = element_source.get("equip_crit_bonus")
		if bonus is int or bonus is float:
			crit_chance += maxf(0.0, float(bonus))
	var is_crit := randf() < crit_chance
	var final_damage := int(damage * crit_mult) if is_crit else damage
	final_damage = int(round(final_damage * _conditional_mult(target)))

	# Hiệu ứng nổ tại điểm chạm — crit nổ to gấp đôi
	FX.spawn_burst(get_parent(), global_position, color, 16 if is_crit else 8, 1.0 if is_crit else 0.7)

	# Sát thương chính. Xuyên giáp: cộng bù đúng lượng giáp mục tiêu trước khi gọi,
	# vì take_damage sẽ trừ lại — kết quả là sát thương nguyên vẹn.
	var dealt := final_damage
	if pierce_armor and target.has_method("effective_armor"):
		dealt += int(target.effective_armor())
	target.take_damage(dealt, "crit" if is_crit else "hit")
	_try_stun(target)
	_report_kill(target)
	_pierce_behind(final_damage)

	# Áp slow
	if slow_amount > 0.0 and slow_duration > 0.0:
		target.apply_slow(slow_amount, slow_duration)

	# Áp burn DoT
	if burn_dps > 0 and burn_duration > 0.0:
		target.apply_burn(burn_dps, burn_duration)

	# ── Gắn Dấu Nguyên Tố ────────────────────────────────────────────────
	# Đặt SAU sát thương chính: phản ứng có thể giết mục tiêu, đánh trước thì
	# "sát thương đòn kích hoạt" mới đúng nghĩa. Mỗi bước đều kiểm tra lại
	# `is_instance_valid` vì Dấu đầu có thể nổ phản ứng và hạ mục tiêu ngay.
	# Đọc qua `get()` chứ không truy cập thẳng thuộc tính: `element_source` khai kiểu Node,
	# GDScript sẽ báo lỗi parse nếu gọi thuộc tính không có trong Node.
	var mark_duration_mult := 1.0
	var mark_duration_bonus := 0.0
	if is_instance_valid(element_source):
		var raw_mult: Variant = element_source.get("mark_duration_mult")
		if raw_mult is float or raw_mult is int:
			mark_duration_mult = maxf(0.05, float(raw_mult))
		# Cộng giây thẳng — thưởng cấp Ô nguyên tố (Lv2 +2s, Lv3 +4s).
		var raw_bonus: Variant = element_source.get("mark_duration_bonus")
		if raw_bonus is float or raw_bonus is int:
			mark_duration_bonus = maxf(0.0, float(raw_bonus))

	if ElementTypes.is_valid(element) and target.has_method("apply_element"):
		target.apply_element(element, element_source, mark_duration_mult, mark_duration_bonus)
		# Dấu phụ ("Bình Chứa Kép"/"Lăng Kính Đôi") — có thể tự kích phản ứng một mình
		if ElementTypes.is_valid(element_secondary) and is_instance_valid(target):
			target.apply_element(element_secondary, element_source, mark_duration_mult,
				mark_duration_bonus)

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
				body.take_damage(int(damage * 0.6), "hit")  # 60% splash damage — không crit
				if slow_amount > 0.0:
					body.apply_slow(slow_amount * 0.5, slow_duration)
				# Splash chỉ gắn Dấu CHÍNH — Dấu phụ là đặc quyền của đòn trúng trực tiếp,
				# nếu không một quả nổ sẽ rải phản ứng khắp bầy chỉ bằng một viên đạn.
				if ElementTypes.is_valid(element) and is_instance_valid(body) \
						and body.has_method("apply_element"):
					body.apply_element(element, element_source, mark_duration_mult,
						mark_duration_bonus)

	queue_free()
