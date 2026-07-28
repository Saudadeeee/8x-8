# res://scripts/map/potion_controller.gd
#
# HỆ THUỐC — vòng ngắm 3D, wiring HUD, nguồn rơi thuốc, hiệu ứng khẩn cấp
# (hồi máu Vua, khiên chặn một đòn). Tách khỏi game_map.gd.
#
# Phím tắt Z/X/C do HUD bắt rồi phát signal `potion_aim_requested`; controller
# này dựng vòng ngắm trên mặt đất và chờ click để ném. game_map giữ các hàm uỷ
# quyền cùng tên nên PotionSystem và HUD không phải đổi gì.
extends Node
class_name PotionController

## game_map — nguồn của máu Vua, vàng, HUD, grid.
var map: Node3D = null

## Cao độ vòng ngắm. BẤT BIẾN: mặt tile y = 0, territory mesh y = 0.052,
## overlay quad y = 0.06 → vòng ngắm 0.07 để không z-fight với bất cứ lớp nào.
const POTION_RING_Y: float = 0.07
## Bán kính VẼ tối đa — thuốc "toàn map" (r = 999) chỉ vẽ tới đây cho dễ nhìn.
const POTION_RING_MAX_DRAW: float = 6.0
## Nhịp quét đếm mục tiêu khi ngắm (giây) — không cần mỗi frame.
const POTION_AIM_SCAN_INTERVAL: float = 0.1
## Nhịp quét địch Elite để móc signal rơi thuốc (giây).
const POTION_ELITE_SCAN_INTERVAL: float = 0.5
## Meta đánh dấu địch đã được móc signal rơi thuốc (tránh nối 2 lần).
const POTION_HOOK_META: String = "_potion_drop_hooked"

var _potion_aim_slot: int = -1
var _potion_aim_radius: float = 2.5
var _potion_aim_ring: MeshInstance3D = null
var _potion_aim_mat: StandardMaterial3D = null
var _potion_aim_label: Label3D = null
var _potion_aim_scan_accum: float = 0.0
var _potion_elite_scan_accum: float = 0.0
var _potion_shield_left: float = 0.0

static func attach(owner_map: Node3D) -> PotionController:
	var c := PotionController.new()
	c.name = "PotionController"
	c.map = owner_map
	owner_map.add_child(c)
	return c

# PotionSystem lo dữ liệu + hiệu ứng lên tháp/địch. game_map lo:
#   (1) vòng ngắm trong thế giới 3D và luồng click,
#   (2) nguồn rơi thuốc (Elite / Rival King / khởi đầu),
#   (3) các `special` cần máu/khiên — nguồn sự thật nằm ở đây.
# Ngắm thuốc dùng được CẢ TRONG PHA WAVE (khác đặt tháp) — đó là điểm cốt lõi.

## Nhịp mỗi frame cho hệ thuốc: đếm ngược khiên, di chuyển vòng ngắm, quét Elite.
## game_map._process gọi mỗi frame.
func tick(delta: float) -> void:
	if _potion_shield_left > 0.0:
		_potion_shield_left = maxf(0.0, _potion_shield_left - delta)

	_potion_elite_scan_accum += delta
	if _potion_elite_scan_accum >= POTION_ELITE_SCAN_INTERVAL:
		_potion_elite_scan_accum = 0.0
		_hook_elite_potion_drops()
		_tick_alchemist_perk()

	if _potion_aim_slot < 0 or not is_instance_valid(_potion_aim_ring):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var ground := GridUtil.mouse_to_ground(camera, get_viewport().get_mouse_position())
	if ground.x < -1e5:
		return   # ray không cắt mặt đất (camera nhìn lên trời) — giữ vòng ở chỗ cũ
	_potion_aim_ring.global_position = Vector3(ground.x, POTION_RING_Y, ground.z)
	if is_instance_valid(_potion_aim_label):
		_potion_aim_label.global_position = Vector3(ground.x, 0.95, ground.z)

	_potion_aim_scan_accum += delta
	if _potion_aim_scan_accum < POTION_AIM_SCAN_INTERVAL:
		return
	_potion_aim_scan_accum = 0.0
	_refresh_potion_aim_feedback(ground)

## Đổi màu vòng + nhãn đếm mục tiêu. Chỉ đọc group (RẺ) — KHÔNG đụng tower.gd.
func _refresh_potion_aim_feedback(ground: Vector3) -> void:
	if map.potion_system == null:
		return
	var data: Dictionary = map.potion_system.get_potion_at(_potion_aim_slot)
	if data.is_empty():
		_cancel_potion_aim()
		return
	var target: String = PotionSystem.target_of(data)
	var count: int = map.potion_system.count_targets(data, ground)
	var valid: bool = count > 0 or target == "self"
	var tint: Color = Color(0.35, 0.95, 0.45) if valid else Color(0.95, 0.55, 0.20)
	if _potion_aim_mat:
		_potion_aim_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.22)
		_potion_aim_mat.emission = tint
	if is_instance_valid(_potion_aim_label):
		match target:
			"allies":  _potion_aim_label.text = " %d tháp" % count
			"enemies": _potion_aim_label.text = " %d địch" % count
			_:         _potion_aim_label.text = " Khẩn cấp"
		_potion_aim_label.modulate = tint

# ── Vòng ngắm ───────────────────────────────────────────────────────────────

## Dựng lại vòng ngắm cho bán kính `radius` (luôn dọn cái cũ trước).
func _build_potion_aim_ring(radius: float) -> void:
	_free_potion_aim_ring()
	var draw_radius: float = minf(maxf(radius, 0.3), POTION_RING_MAX_DRAW)

	_potion_aim_mat = StandardMaterial3D.new()
	_potion_aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_potion_aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_potion_aim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_potion_aim_mat.albedo_color = Color(0.35, 0.95, 0.45, 0.22)
	_potion_aim_mat.emission_enabled = true
	_potion_aim_mat.emission = Color(0.35, 0.95, 0.45)
	_potion_aim_mat.emission_energy_multiplier = 1.1

	var disc := CylinderMesh.new()
	disc.top_radius = draw_radius
	disc.bottom_radius = draw_radius
	disc.height = 0.02
	disc.radial_segments = 48
	disc.material = _potion_aim_mat

	_potion_aim_ring = MeshInstance3D.new()
	_potion_aim_ring.name = "PotionAimRing"
	_potion_aim_ring.mesh = disc
	_potion_aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.add_child(_potion_aim_ring)
	_potion_aim_ring.global_position = Vector3(0.0, POTION_RING_Y, 0.0)

	_potion_aim_label = Label3D.new()
	_potion_aim_label.name = "PotionAimLabel"
	_potion_aim_label.text = ""
	_potion_aim_label.font_size = 26
	_potion_aim_label.pixel_size = 0.01
	_potion_aim_label.outline_size = 8
	_potion_aim_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	_potion_aim_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_potion_aim_label.no_depth_test = true
	map.add_child(_potion_aim_label)
	_potion_aim_label.global_position = Vector3(0.0, 0.95, 0.0)

## Dọn sạch vòng ngắm — gọi ở MỌI đường thoát chế độ ngắm.
func _free_potion_aim_ring() -> void:
	if is_instance_valid(_potion_aim_ring):
		_potion_aim_ring.queue_free()
	if is_instance_valid(_potion_aim_label):
		_potion_aim_label.queue_free()
	_potion_aim_ring = null
	_potion_aim_label = null
	_potion_aim_mat = null

# ── Luồng ngắm / thả ────────────────────────────────────────────────────────

## HUD yêu cầu ngắm ô `slot`.
func _on_potion_aim_requested(slot: int) -> void:
	if map.potion_system == null or map._game_over_triggered:
		_cancel_potion_aim()
		return
	# Đang tạm dừng thì _process/_unhandled_input của game_map không chạy → vòng
	# ngắm sẽ đứng yên và click không tới nơi. Từ chối thẳng thay vì kẹt người chơi.
	if is_inside_tree() and get_tree().paused:
		_cancel_potion_aim()
		return
	if not map.potion_system.can_use(slot):
		_cancel_potion_aim()
		return
	# Ngắm thuốc ưu tiên hơn mọi mode khác → tắt build/dismiss/territory trước.
	if map.tower_placer:
		map.tower_placer.cancel_build()

	_potion_aim_slot = slot
	_potion_aim_radius = map.potion_system.radius_at(slot)
	_build_potion_aim_ring(_potion_aim_radius)
	_potion_aim_scan_accum = POTION_AIM_SCAN_INTERVAL   # cập nhật nhãn ngay frame đầu

	var hud := map.get_node_or_null("HUD")
	if hud and hud.has_method("set_potion_aiming"):
		hud.set_potion_aiming(true, _potion_aim_radius)
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("click_magic", -8.0)

## HUD tự huỷ ngắm (ESC / bấm lại ô đang ngắm) — HUD đã tự cập nhật nên không báo ngược.
func _on_potion_aim_cancelled() -> void:
	_cancel_potion_aim(false)

## Thoát chế độ ngắm và dọn vòng tròn. [param notify_hud] = false khi chính HUD
## là bên khởi xướng (tránh vòng lặp signal).
func _cancel_potion_aim(notify_hud: bool = true) -> void:
	var was_aiming: bool = _potion_aim_slot >= 0
	_potion_aim_slot = -1
	_potion_aim_scan_accum = 0.0
	_free_potion_aim_ring()
	if notify_hud and was_aiming:
		var hud := map.get_node_or_null("HUD")
		if hud and hud.has_method("set_potion_aiming"):
			hud.set_potion_aiming(false, 0.0)

## Input trong chế độ ngắm. Trả true nếu event đã bị "tiêu thụ".
func _handle_potion_aim_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_potion_aim()
			get_viewport().set_input_as_handled()
			return true
		return false
	if not (event is InputEventMouseButton) or not event.pressed:
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_potion_aim()
		get_viewport().set_input_as_handled()
		return true
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_cancel_potion_aim()
		get_viewport().set_input_as_handled()
		return true
	var ground := GridUtil.mouse_to_ground(camera, get_viewport().get_mouse_position())
	get_viewport().set_input_as_handled()
	if ground.x < -1e5:
		return true   # click lên trời — nuốt click nhưng GIỮ chế độ ngắm
	_throw_potion_at(ground)
	return true

## Thả bình đang ngắm xuống `ground`. Dọn vòng ngắm TRƯỚC khi thi triển để
## FX của thuốc không bị vòng tròn che.
func _throw_potion_at(ground: Vector3) -> void:
	var slot: int = _potion_aim_slot
	_cancel_potion_aim()
	if map.potion_system == null or slot < 0:
		return
	var data: Dictionary = map.potion_system.get_potion_at(slot)
	var potion_name: String = str(data.get("name", "Thuốc"))
	if not map.potion_system.use_potion(slot, ground):
		return
	if map.phase_controller:
		map.phase_controller.phase_message = " Đã dùng %s!" % potion_name
	map.update_ui()

# ── Wiring HUD ──────────────────────────────────────────────────────────────

func _on_potion_bag_changed(bag: Array) -> void:
	var hud := map.get_node_or_null("HUD")
	if hud and hud.has_method("refresh_potion_bag"):
		hud.refresh_potion_bag(bag)

func _on_relics_changed(ids: Array) -> void:
	var hud := map.get_node_or_null("HUD")
	if hud and hud.has_method("refresh_relics"):
		hud.refresh_relics(ids)

# ── Nguồn rơi thuốc ─────────────────────────────────────────────────────────

func _grant_starting_potions() -> void:
	if map.potion_system == null or map.STARTING_POTION_ID.is_empty():
		return
	map.potion_system.add_potion(map.STARTING_POTION_ID)

## Bốc 1 bình ngẫu nhiên bỏ vào túi. Túi đầy → báo HUD, không mất bình nào.
func _grant_random_potion(source: String = "") -> bool:
	if map.potion_system == null:
		return false
	if map.potion_system.free_slots() <= 0:
		if map.phase_controller:
			map.phase_controller.phase_message = " Túi thuốc đã đầy — dùng bớt (Z/X/C) để nhận thêm!"
			map.update_ui()
		return false
	var potion_id: String = map.potion_system.roll_random()
	if potion_id.is_empty() or not map.potion_system.add_potion(potion_id):
		return false
	var data: Dictionary = map.potion_system.get_potion_by_id(potion_id)
	if map.phase_controller:
		var suffix: String = " (%s)" % source if not source.is_empty() else ""
		map.phase_controller.phase_message = " Nhận thuốc: %s%s" % [str(data.get("name", potion_id)), suffix]
		map.update_ui()
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("gold", -5.0)
	return true

## Móc signal `enemy_defeated` của các Elite mới xuất hiện. WaveSpawner chỉ phát
## `enemy_defeated(gold)` (không kèm node) nên phải nghe thẳng từ chính con Elite —
## quét theo nhịp POTION_ELITE_SCAN_INTERVAL, mỗi con chỉ móc một lần.
func _hook_elite_potion_drops() -> void:
	if map.potion_system == null:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.has_meta(POTION_HOOK_META):
			continue
		if not bool(enemy.get("is_elite")):
			continue
		enemy.set_meta(POTION_HOOK_META, true)
		if enemy.has_signal("enemy_defeated"):
			enemy.connect("enemy_defeated", _on_elite_defeated_potion_drop, CONNECT_ONE_SHOT)

## Perk "Nhà Giả Kim" — cứ N phản ứng nổ ra thì tặng 1 bình. Kiểm theo NHỊP
## quét (không phải mỗi phản ứng) vì ReactionTable là static, không phát signal.
var _alchemist_last_count: int = 0

func _tick_alchemist_perk() -> void:
	if map._game_manager == null or map.potion_system == null:
		return
	var per: Variant = map._game_manager.get("perk_potion_per_reactions")
	var threshold: int = int(per) if (per is int or per is float) else 0
	if threshold <= 0:
		return
	var total: int = ReactionTable.reaction_count
	# Mỗi mốc chỉ thưởng MỘT lần: so mốc đã vượt của lần trước với lần này.
	if int(total / threshold) <= int(_alchemist_last_count / threshold):
		_alchemist_last_count = total
		return
	_alchemist_last_count = total
	_grant_random_potion("Nhà Giả Kim")

func _on_elite_defeated_potion_drop(_gold: int) -> void:
	# Di vật "Bản Đồ Kho Báu" biến tỉ lệ 15% thành chắc chắn.
	var guaranteed: bool = map._game_manager != null and bool(map._game_manager.get("relic_elite_always_drop"))
	if guaranteed or randf() < map.ELITE_POTION_DROP_CHANCE:
		_grant_random_potion("Elite")

# ── Hiệu ứng khẩn cấp (PotionSystem gọi ngược lên qua has_method) ───────────

## "Máu Vua" — hồi máu cho Nhà Vua.
func potion_heal_king(amount: int) -> void:
	if amount <= 0:
		return
	map.current_health += amount
	FX.damage_number(map, _king_world_pos() + Vector3(0.0, 1.2, 0.0),
		"+%d ❤" % amount, Color(0.4, 1.0, 0.5), 26)
	FX.spawn_burst(map, _king_world_pos() + Vector3(0.0, 0.4, 0.0), Color(0.4, 1.0, 0.5), 16, 1.0)
	if map.phase_controller:
		map.phase_controller.phase_message = "❤ Máu Vua: +%d máu!" % amount
	map.update_ui()

## "Khiên Vương Triều" — Nhà Vua miễn sát thương trong `seconds` giây.
## Gọi chồng thì LÀM MỚI thời hạn (lấy giá trị lớn hơn), không cộng dồn.
func potion_king_shield(seconds: float) -> void:
	_potion_shield_left = maxf(_potion_shield_left, maxf(0.1, seconds))
	FX.spawn_burst(map, _king_world_pos() + Vector3(0.0, 0.5, 0.0), Color(0.55, 0.8, 1.0), 22, 1.3)
	if map.phase_controller:
		map.phase_controller.phase_message = "🛡 Khiên Vương Triều: miễn sát thương %.0f giây!" % _potion_shield_left
	map.update_ui()

func _is_king_shielded() -> bool:
	return _potion_shield_left > 0.0

## Phản hồi khi khiên chặn một đòn — nếu không hiện gì, player tưởng game lỗi.
func _show_shield_block() -> void:
	var pos := _king_world_pos() + Vector3(0.0, 1.0, 0.0)
	FX.damage_number(map, pos, "🛡 MIỄN", Color(0.55, 0.8, 1.0), 22)
	FX.spawn_burst(map, pos, Color(0.55, 0.8, 1.0), 10, 0.8)
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("hit", -8.0, 1.4)

## Vị trí world của ô King (cuối đường đi). Fallback về tâm board nếu chưa có path.
func _king_world_pos() -> Vector3:
	if map.grid_controller and not map.grid_controller.current_path_grid.is_empty():
		return GridUtil.cell_to_world(map.grid_controller.current_path_grid.back())
	return Vector3.ZERO

## Đang ở chế độ ngắm hay không — game_map hỏi trước khi nhường click.
func is_aiming() -> bool:
	return _potion_aim_slot >= 0
