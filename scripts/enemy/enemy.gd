# res://scripts/enemies/enemy.gd
extends Area3D
class_name Enemy

signal reached_base(damage: int)
signal enemy_defeated(gold: int)

@export var stats: EnemyStats

# Stats tốc độ trong .tres vẫn là px/s (16 px = 1 tile) — quy đổi sang m/s (1 tile = 1 m)
const PX_TO_M: float = 1.0 / 16.0
const WAYPOINT_THRESHOLD: float = 0.05
const MODEL_DIR := "res://assets/models/%s.gltf"

# Biến Runtime (Chạy trong game)
var current_hp: int = 0
var current_speed: float = 0.0
var _is_dead: bool = false   # guard chống die() bị gọi nhiều lần

# Slow debuff
var _slow_amount: float = 0.0
var _slow_timer: float = 0.0

# Burn DoT
var _burn_dps: int = 0
var _burn_timer: float = 0.0
var _burn_tick: float = 1.0  # bắt đầu ở 1.0 → tick đầu tiên sau 1 giây

# ── Nguyên tố (futureplan §1) ─────────────────────────────────────────────
## Component giữ Dấu Nguyên Tố + kích phản ứng. Tạo trong _ready().
var marks: ElementMarks = null
## Mốc hết hiệu lực của "xoá sạch giáp" (phản ứng Tan Chảy). 0 = không bị xoá.
var _armor_shred_until: float = 0.0
# Trừ giáp phẳng (Siêu Dẫn) — tách khỏi _armor_shred_until vì hai cơ chế khác nhau.
var _armor_flat: int = 0
var _armor_flat_until: float = 0.0

# Abilities (armor/regen/heal aura — đọc từ EnemyStats)
var _max_hp: int = 0            # max HP đã scale theo wave — trần cho mọi hồi máu
var _regen_accum: float = 0.0   # tích lũy hồi máu lẻ (regen_per_sec * delta)
var _heal_aura_timer: float = 0.0

# Elite (do WaveSpawner phong cấp sau load_enemy_data)
var is_elite: bool = false
var gold_multiplier: float = 1.0   # nhân vào gold_reward khi chết (elite ×2.5)

# Throttle label hồi máu — regen tick dày (troll ~8/s) sẽ nuốt hết budget label
var _last_heal_label_ms: int = 0
const HEAL_LABEL_INTERVAL_MS: int = 450

const HEAL_AURA_INTERVAL: float = 1.5
const HEAL_PULSE_COLOR := Color(0.4, 1, 0.5)

# Biến đường đi
var path_points: Array[Vector3] = []
var current_point_index: int = 0

# ── Juice / feedback ──────────────────────────────────────────────────────
var _mesh_instances: Array[MeshInstance3D] = []   # material_override riêng per instance
var _flash_timer: float = 0.0
var _bob_time: float = 0.0
var _hp_bar_fg: MeshInstance3D = null
var _hp_bar_root: Node3D = null

const COLOR_FLASH := Color(2.5, 2.5, 2.5)   # >1 để cháy sáng
const COLOR_BURN  := Color(1.6, 0.7, 0.4)
const COLOR_SLOW  := Color(0.6, 0.8, 1.5)
const COLOR_ELITE := Color(1.45, 1.15, 0.5) # ánh vàng elite — pulse trong _update_tint
const COLOR_FROZEN := Color(0.45, 0.8, 1.6) # xanh băng đậm khi bị Đóng Băng
const HP_BAR_WIDTH: float = 0.62
const HP_BAR_HEIGHT: float = 1.25

# Elite tuning
const ELITE_SCALE: float = 1.35
const CURSED_KILL_BONUS_GOLD: int = 2   # thưởng khi địch chết TRÊN ô nguyền
const EARTH_MARK_BONUS_GOLD: int = 15   # Dấu Thổ: địch chết để lại mảnh vàng (futureplan §1.1)

# Màu damage number theo loại nguồn sát thương
const DMG_NUM_COLORS := {
	"hit":  Color(1.0, 1.0, 1.0),
	"crit": Color(1.0, 0.9, 0.2),
	"burn": Color(1.0, 0.55, 0.15),
}

@onready var visual: Node3D = $Visual

func _ready():
	add_to_group("enemies")
	var col = get_node_or_null("CollisionShape3D")
	if col:
		col.visible = false
	# Component Dấu Nguyên Tố — mọi địch đều có, kể cả boss (BossEnemy extends Enemy).
	marks = ElementMarks.new()
	marks.name = "ElementMarks"
	# Di vật "Bánh Xe Nguyên Tố" nâng trần Dấu. Đọc lúc SPAWN: quái đã ra sân
	# không đổi trần giữa chừng, đúng quy ước biome/ascension của dự án.
	var gm_marks := get_node_or_null("/root/GameManagerSingleton")
	if gm_marks != null:
		var cap: Variant = gm_marks.get("relic_max_marks")
		if cap is int or cap is float:
			marks.max_marks = maxi(1, int(cap))
	add_child(marks)
	# Synergy Thuỷ ×6 "Thuỷ Triều": địch ra sân đã ướt sẵn → mọi tháp Lôi/Băng
	# lập tức có phản ứng ngay đòn đầu. Cấy sau add_child để marks đã _ready.
	if gm_marks != null and bool(gm_marks.get("syn_water_spawn_mark")):
		marks.implant(ElementTypes.WATER)
	if stats:
		load_enemy_data()

func load_enemy_data(health_multiplier: float = 1.0, speed_multiplier: float = 1.0):
	if not stats:
		push_error("Enemy không có stats!")
		return
	_build_visual()
	# Khí hậu biome nhân thêm vào HP/tốc độ NGAY LÚC SPAWN — quái đã ra sân
	# không đổi khi biome thay đổi (biome chỉ đổi giữa 2 wave).
	var biome_hp:    float = _biome_mult("biome_enemy_hp_mult")
	var biome_speed: float = _biome_mult("biome_enemy_speed_mult")
	current_hp = max(1, int(round(stats.max_hp * health_multiplier * biome_hp)))
	_max_hp = current_hp   # trần hồi máu = max HP đã scale theo wave
	current_speed = stats.speed * PX_TO_M * speed_multiplier * biome_speed
	_build_hp_bar()

## Đọc một hệ số biome từ GameManagerSingleton — mặc định 1.0 khi thiếu.
func _biome_mult(field: String) -> float:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return 1.0
	var value: Variant = gm.get(field)
	if value is float or value is int:
		return maxf(0.0, float(value))
	return 1.0

## Phong cấp elite — gọi bởi WaveSpawner SAU load_enemy_data.
## Trâu ×3, chậm hơn chút, vàng ×2.5, model to 1.35×, tint vàng pulse.
func make_elite(hp_mult: float = 3.0, speed_mult: float = 0.85, gold_mult: float = 2.5) -> void:
	if is_elite:
		return
	is_elite = true
	gold_multiplier = gold_mult
	current_hp = max(1, int(round(current_hp * hp_mult)))
	_max_hp = current_hp
	current_speed *= speed_mult
	if visual:
		visual.scale = Vector3.ONE * ELITE_SCALE
	if _hp_bar_root and is_instance_valid(_hp_bar_root):
		_hp_bar_root.position.y = HP_BAR_HEIGHT * ELITE_SCALE
	_update_hp_bar()

## Load model 3D theo stats.id; fallback = Sprite3D billboard dùng texture 2D cũ.
func _build_visual() -> void:
	if not visual:
		return
	for child in visual.get_children():
		child.queue_free()

	_mesh_instances.clear()
	var model_path := MODEL_DIR % stats.id
	if ResourceLoader.exists(model_path):
		var scene := load(model_path) as PackedScene
		if scene:
			var model := scene.instantiate()
			visual.add_child(model)
			# Material của glTF share giữa mọi instance cùng loại —
			# duplicate để tint per-instance (flash/debuff) không lan sang con khác.
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				var src: Material = mi.get_active_material(0)
				if src:
					mi.material_override = src.duplicate()
					_mesh_instances.append(mi)
			return

	var billboard := Sprite3D.new()
	billboard.pixel_size = 0.03
	billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard.position = Vector3(0.0, 0.4, 0.0)
	if stats.texture:
		billboard.texture = stats.texture
		billboard.scale = Vector3(stats.scale.x, stats.scale.y, 1.0)
	visual.add_child(billboard)

## HP bar billboard — 2 quad (nền + máu), chỉ hiện khi mất máu.
func _build_hp_bar() -> void:
	if _hp_bar_root and is_instance_valid(_hp_bar_root):
		_hp_bar_root.queue_free()
	_hp_bar_root = Node3D.new()
	_hp_bar_root.name = "HpBar"
	add_child(_hp_bar_root)
	# Elite to hơn 1.35× — nâng bar lên theo để không cắm vào đầu model
	_hp_bar_root.position = Vector3(0.0, HP_BAR_HEIGHT * (ELITE_SCALE if is_elite else 1.0), 0.0)
	_hp_bar_root.visible = false

	var bg := MeshInstance3D.new()
	bg.mesh = _make_bar_quad(HP_BAR_WIDTH + 0.04, 0.1, Color(0.08, 0.05, 0.05, 0.85))
	_hp_bar_root.add_child(bg)

	_hp_bar_fg = MeshInstance3D.new()
	_hp_bar_fg.mesh = _make_bar_quad(HP_BAR_WIDTH, 0.06, Color(0.25, 0.9, 0.3, 0.95))
	_hp_bar_fg.position = Vector3(0.0, 0.0, 0.001)
	((_hp_bar_fg.mesh as QuadMesh).material as StandardMaterial3D).render_priority = 1
	_hp_bar_root.add_child(_hp_bar_fg)

func _make_bar_quad(w: float, h: float, col: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = col
	quad.material = mat
	return quad

func _update_hp_bar() -> void:
	if not _hp_bar_fg or not stats:
		return
	var ratio: float = clampf(float(current_hp) / float(max(1, _get_hp_cap())), 0.0, 1.0)
	_hp_bar_root.visible = ratio < 1.0
	_hp_bar_fg.scale.x = maxf(ratio, 0.01)
	# Billboard quad: scale từ giữa — không cần offset, đủ đọc ở cỡ này
	var mat := (_hp_bar_fg.mesh as QuadMesh).material as StandardMaterial3D
	mat.albedo_color = Color(0.9, 0.25, 0.2, 0.95) if ratio < 0.35 \
		else (Color(0.95, 0.75, 0.2, 0.95) if ratio < 0.7 else Color(0.25, 0.9, 0.3, 0.95))

func apply_slow(amount: float, duration: float) -> void:
	_slow_amount = max(_slow_amount, amount)
	_slow_timer  = max(_slow_timer, duration)

func apply_burn(dps: int, duration: float) -> void:
	_burn_dps   = max(_burn_dps, dps)
	_burn_timer = max(_burn_timer, duration)

## Gắn một Dấu Nguyên Tố. Uỷ quyền hoàn toàn cho component ElementMarks —
## nơi duy nhất biết luật trần Dấu, hết hạn và ghép phản ứng.
func apply_element(element: String, source: Node = null, dur_mult: float = 1.0,
		dur_bonus: float = 0.0) -> void:
	if _is_dead or marks == null or not is_instance_valid(marks):
		return
	marks.apply(element, source, dur_mult, dur_bonus)

## Xoá sạch giáp trong `duration` giây (phản ứng Tan Chảy).
func shred_armor(duration: float) -> void:
	if duration <= 0.0:
		return
	_armor_shred_until = maxf(_armor_shred_until, ElementMarks.now() + duration)

## Trừ THẲNG `amount` giáp trong `duration` giây (phản ứng Siêu Dẫn, trang bị phá giáp).
## Khác `shred_armor` (xoá sạch): trừ phẳng nên vẫn có ý nghĩa chồng lên quái giáp cao.
func reduce_armor(amount: int, duration: float) -> void:
	if amount <= 0 or duration <= 0.0:
		return
	var t := ElementMarks.now()
	if _armor_flat_until <= t:
		_armor_flat = 0   # lần trừ trước đã hết hạn — không cộng dồn qua thời gian
	_armor_flat = maxi(_armor_flat, amount)
	_armor_flat_until = maxf(_armor_flat_until, t + duration)

## Giáp thực sự đang có hiệu lực — 0 khi đang bị Tan Chảy xoá giáp.
## ElementMarks đọc hàm này để cộng bù đúng lượng giáp cho Dấu Lôi (bỏ qua giáp).
func effective_armor() -> int:
	if stats == null or stats.armor <= 0:
		return 0
	if _armor_shred_until > 0.0:
		if ElementMarks.now() < _armor_shred_until:
			return 0
		_armor_shred_until = 0.0
	if _armor_flat_until > 0.0:
		if ElementMarks.now() < _armor_flat_until:
			return maxi(0, stats.armor - _armor_flat)
		_armor_flat_until = 0.0
		_armor_flat = 0
	return stats.armor

## Hệ số sát thương của một nguyên tố lên con này (khắc 1.5× / kháng 0.6×).
## ElementMarks nhân vào DoT, ReactionTable nhân vào sát thương phản ứng.
func element_multiplier(element: String) -> float:
	if stats == null or not stats.has_method("element_multiplier"):
		return 1.0
	return float(stats.call("element_multiplier", element))

## Hệ số nhận sát thương thêm khi đang mang Dấu (di vật Vòng Cổ Thợ Săn).
func _marked_damage_mult() -> float:
	if marks == null or not is_instance_valid(marks) or marks.mark_count() <= 0:
		return 1.0
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return 1.0
	var pct: Variant = gm.get("relic_marked_damage_taken")
	if not (pct is int or pct is float):
		return 1.0
	return 1.0 + maxf(0.0, float(pct))

## Đang bị Đóng Băng? Meta do ReactionTable đặt; tự dọn khi hết hạn nên
## không có đường nào khoá địch vĩnh viễn.
func _is_frozen() -> bool:
	if not has_meta(ReactionTable.META_FROZEN_UNTIL):
		return false
	if ElementMarks.now() < float(get_meta(ReactionTable.META_FROZEN_UNTIL)):
		return true
	remove_meta(ReactionTable.META_FROZEN_UNTIL)
	return false

## Sát thương một nhịp thiêu đốt sau khi nhân hệ số biome (mặc định ×1.0).
## Trả 0 khi biome triệt tiêu burn — caller bỏ qua tick để không hiện số "0".
func _scaled_burn_damage() -> int:
	if _burn_dps <= 0:
		return 0
	var mult := _biome_mult("biome_burn_mult")
	if is_zero_approx(mult):
		return 0
	return maxi(1, int(round(_burn_dps * mult)))

func _process(delta):
	if _is_dead: return
	if path_points.is_empty(): return

	# Xử lý slow
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_amount = 0.0

	# Xử lý burn DoT (tick mỗi 1 giây)
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick  -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 1.0
			var burn_damage := _scaled_burn_damage()
			if burn_damage > 0:
				take_damage(burn_damage, "burn")

	# Hồi máu bản thân (vd: troll) — tích lũy phần lẻ, áp dụng khi đủ 1 HP
	if stats and stats.regen_per_sec > 0.0 and current_hp < _get_hp_cap():
		_regen_accum += stats.regen_per_sec * delta
		if _regen_accum >= 1.0:
			var regen_amount := int(_regen_accum)
			_regen_accum -= float(regen_amount)
			heal(regen_amount)

	# Aura hồi máu đồng minh (vd: shaman) — nhịp mỗi HEAL_AURA_INTERVAL giây
	if stats and stats.heal_aura_amount > 0 and stats.heal_aura_radius > 0.0:
		_heal_aura_timer += delta
		if _heal_aura_timer >= HEAL_AURA_INTERVAL:
			_heal_aura_timer = 0.0
			_pulse_heal_aura()

	# Đóng Băng (phản ứng Băng+Thuỷ): CHỈ khoá di chuyển. Mọi thứ khác — DoT, hồi máu,
	# aura, tint, damage number — vẫn chạy bình thường ở trên/dưới.
	var frozen := _is_frozen()
	# Vết nứt (Chấn Địa) lấy MAX với slow thường chứ không cộng dồn — hai nguồn cộng
	# lại dễ chạm 100% và biến vết nứt thành khoá cứng vĩnh viễn trên đường đi.
	var slow := maxf(_slow_amount, ReactionTable.crack_slow_at(GridUtil.world_to_cell(global_position)))
	var effective_speed = 0.0 if frozen else current_speed * (1.0 - clampf(slow, 0.0, 0.95))
	var target = path_points[current_point_index]

	if not frozen:
		_face_direction(target)
		position = position.move_toward(target, effective_speed * delta)

	# Bob khi di chuyển — nhún theo tốc độ thực tế (đứng băng thì speed = 0 nên đứng im)
	_bob_time += delta * effective_speed * 9.0
	if visual:
		visual.position.y = absf(sin(_bob_time)) * 0.07
		visual.rotation.z = sin(_bob_time) * 0.05

	_update_tint(delta)

	if not frozen and position.distance_to(target) < WAYPOINT_THRESHOLD:
		current_point_index += 1
		if current_point_index >= path_points.size():
			reached_end()

## Tint model theo trạng thái: flash trúng đòn > đóng băng > burn > slow > bình thường.
func _update_tint(delta: float) -> void:
	if _mesh_instances.is_empty():
		return
	if _flash_timer > 0.0:
		_flash_timer -= delta
	var tint := Color.WHITE
	if _flash_timer > 0.0:
		tint = COLOR_FLASH
	elif _is_frozen():
		tint = COLOR_FROZEN
	elif _burn_timer > 0.0:
		tint = COLOR_BURN.lerp(Color.WHITE, 0.5 + 0.5 * sin(_bob_time * 2.0))
	elif _slow_timer > 0.0:
		tint = COLOR_SLOW
	elif is_elite:
		# Pulse vàng nhẹ liên tục — chỉ khi không có status khác đè lên
		tint = COLOR_ELITE.lerp(Color.WHITE, 0.4 + 0.4 * sin(_bob_time * 1.5))
	for mi in _mesh_instances:
		if is_instance_valid(mi) and mi.material_override is BaseMaterial3D:
			(mi.material_override as BaseMaterial3D).albedo_color = tint

## Xoay mặt theo hướng di chuyển (guard vector 0 / colinear với UP).
func _face_direction(target: Vector3) -> void:
	var dir := target - position
	dir.y = 0.0
	if dir.length_squared() < 0.000001:
		return
	look_at(global_position + dir, Vector3.UP)

func set_path(grid_path: Array[Vector2i]):
	path_points.clear()
	for grid_pos in grid_path:
		path_points.append(GridUtil.cell_to_world(grid_pos))

	if path_points.size() > 0:
		position = path_points[0]
		current_point_index = 1

## kind: "hit" (mặc định) / "crit" / "burn" / "reaction" — quyết định màu số sát thương + SFX.
func take_damage(amount: int, kind: String = "hit"):
	if _is_dead:
		return
	var armor := effective_armor()   # 0 khi đang bị Tan Chảy xoá giáp
	if armor > 0:
		amount = max(1, amount - armor)   # giáp phẳng, luôn chịu tối thiểu 1
	# Di vật "Vòng Cổ Thợ Săn": địch đang mang Dấu ăn thêm % từ MỌI nguồn.
	# Nhân SAU khi trừ giáp để không biến nó thành công cụ xuyên giáp.
	amount = int(round(amount * _marked_damage_mult()))
	current_hp -= amount
	_flash_timer = 0.12
	_update_hp_bar()
	_spawn_damage_number(amount, kind)
	# SFX: burn tick không kêu (spam), crit có tiếng riêng
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		if kind == "crit":
			am.play_sfx("crit", -4.0)
		elif kind == "hit":
			am.play_sfx("hit", -8.0)
	if current_hp <= 0:
		die()

## Số sát thương bay lên — text/màu/cỡ theo loại nguồn (SAU khi trừ giáp).
func _spawn_damage_number(amount: int, kind: String) -> void:
	if not is_inside_tree():
		return
	# Phản ứng nguyên tố tự vẽ nhãn riêng ("Bốc Hơi 250!") trong ReactionTable —
	# bỏ qua ở đây để không chồng hai label lên cùng một điểm.
	if kind == "reaction":
		return
	var text := str(amount)
	var size := 18
	match kind:
		"crit":
			text = "%d!" % amount
			size = 26
		"burn":
			size = 13
	var color: Color = DMG_NUM_COLORS.get(kind, Color.WHITE)
	var jitter := Vector3(randf_range(-0.15, 0.15), 1.2, randf_range(-0.15, 0.15))
	FX.damage_number(get_parent(), global_position + jitter, text, color, size)

## Hồi máu — không vượt trần HP đã scale theo wave. Trả về true nếu có hồi thật.
func heal(amount: int) -> bool:
	if _is_dead or amount <= 0:
		return false
	var cap := _get_hp_cap()
	if current_hp >= cap:
		return false
	var healed := mini(amount, cap - current_hp)
	current_hp = mini(current_hp + amount, cap)
	_update_hp_bar()
	# Label hồi máu có throttle riêng — regen +1 dồn dập không spam số
	var now := Time.get_ticks_msec()
	if is_inside_tree() and now - _last_heal_label_ms >= HEAL_LABEL_INTERVAL_MS:
		_last_heal_label_ms = now
		var jitter := Vector3(randf_range(-0.15, 0.15), 1.2, randf_range(-0.15, 0.15))
		FX.damage_number(get_parent(), global_position + jitter, "+%d" % healed, Color(0.35, 1.0, 0.45), 15)
	return true

## Trần HP hiện tại (đã scale theo wave); fallback về stats khi chưa load.
func _get_hp_cap() -> int:
	if _max_hp > 0:
		return _max_hp
	return stats.max_hp if stats else 1

## Shaman aura: hồi máu enemy khác (không hồi bản thân) trong bán kính (mét).
func _pulse_heal_aura() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not (node is Enemy):
			continue
		var target := node as Enemy
		if target._is_dead:
			continue
		if global_position.distance_to(target.global_position) > stats.heal_aura_radius:
			continue
		if target.heal(stats.heal_aura_amount):
			FX.spawn_burst(get_parent(), target.global_position + Vector3(0, 0.5, 0), HEAL_PULSE_COLOR, 4, 0.4)

func die():
	if _is_dead:
		return
	_is_dead = true
	# Elite thưởng vàng nhân hệ số; chết TRÊN ô nguyền → bonus nhỏ (tradeoff của cursed tile)
	var gold_amount := int(round((stats.gold_reward if stats else 0) * gold_multiplier))
	# Dấu Thổ phải tính TRƯỚC clear_all() — sau đó Dấu không còn để đọc.
	var earth_bonus := _earth_mark_bonus()
	# Gỡ Dấu + nhãn ngay: xác còn tween squash 0.18s, để lại nhãn Dấu treo lơ lửng.
	if marks and is_instance_valid(marks):
		marks.clear_all()
	enemy_defeated.emit(gold_amount + _cursed_tile_bonus() + earth_bonus)

	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("enemy_death", -7.0)

	# Hiệu ứng chết: burst + squash rồi mới free
	var burst_color := Color(0.5, 0.85, 0.3)
	if stats and stats.id == "skeleton":
		burst_color = Color(0.9, 0.88, 0.8)
	elif stats and stats.id == "dark_knight":
		burst_color = Color(0.3, 0.28, 0.38)
	elif stats and stats.id == "demon_imp":
		burst_color = Color(0.85, 0.3, 0.35)
	FX.spawn_burst(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), burst_color, 14, 1.0)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	remove_from_group("enemies")   # xác chết không còn là target
	if _hp_bar_root:
		_hp_bar_root.visible = false
	if visual and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)
	else:
		queue_free()

## Dấu Thổ: "địch chết để lại mảnh vàng" (futureplan §1.1).
## Cộng thẳng vào giá trị của signal `enemy_defeated` — game_map đã lắng nghe signal này
## và tự đẩy vàng qua GameManager, nên KHÔNG cần đường ghi vàng thứ hai.
func _earth_mark_bonus() -> int:
	if marks == null or not is_instance_valid(marks):
		return 0
	if not marks.has_mark(ElementTypes.EARTH):
		return 0
	var parent := get_parent()
	if parent and is_inside_tree():
		var earth_color := ElementTypes.color_of(ElementTypes.EARTH)
		FX.spawn_burst(parent, global_position + Vector3(0.0, 0.3, 0.0), earth_color, 10, 0.7)
		FX.damage_number(parent, global_position + Vector3(0.0, 1.1, 0.0),
			"+%d vàng" % EARTH_MARK_BONUS_GOLD, Color(1.0, 0.85, 0.3), 15)
	return EARTH_MARK_BONUS_GOLD

## Bonus vàng khi chết TRÊN ô nguyền — truy cập grid_controller của game_map (parent)
## một cách phòng thủ: mọi bước đều guard, thiếu gì trả 0.
func _cursed_tile_bonus() -> int:
	var parent := get_parent()
	if parent == null or not is_inside_tree():
		return 0
	var gc = parent.get("grid_controller")
	if gc == null:
		return 0
	var specials = gc.get("special_tiles")
	if not (specials is Dictionary):
		return 0
	var cell: Vector2i = GridUtil.world_to_cell(global_position)
	if specials.get(cell, "") != "cursed":
		return 0
	FX.spawn_burst(parent, global_position + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.85, 0.25), 8, 0.6)
	FX.damage_number(parent, global_position + Vector3(0.0, 1.0, 0.0),
		"+%d vàng" % CURSED_KILL_BONUS_GOLD, Color(1.0, 0.85, 0.3), 14)
	return CURSED_KILL_BONUS_GOLD

func reached_end():
	if _is_dead:
		return
	_is_dead = true
	FX.spawn_burst(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Color(0.95, 0.2, 0.2), 10, 0.8)
	reached_base.emit(stats.damage_to_base if stats else 1)
	queue_free()
