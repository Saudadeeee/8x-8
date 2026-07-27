# res://scripts/elements/element_marks.gd
# Component "Dấu Nguyên Tố" gắn trên MỖI địch — enemy tự `add_child` trong `_ready()`.
#
# Trách nhiệm (futureplan.md §1.1):
#   - Giữ tối đa `max_marks` Dấu; Dấu thứ N+1 đẩy Dấu CŨ NHẤT ra.
#   - Dấu mới ghép được cặp với Dấu đang có → gọi ReactionTable và TIÊU THỤ CẢ HAI Dấu.
#   - Áp hiệu ứng nền: sát thương theo giây (dps) + làm chậm (slow) mỗi frame.
#   - Vẽ nhãn biểu tượng Dấu nổi trên đầu địch.
#
# Cố ý KHÔNG tham chiếu class `Enemy`: enemy.gd đã tham chiếu ElementMarks, thêm chiều
# ngược lại sẽ tạo cyclic reference lúc parse. Mọi truy cập chéo dùng duck typing.
class_name ElementMarks
extends Node

## Phát khi một phản ứng nổ trên chính con địch này.
signal reaction_triggered(reaction_id: String, position: Vector3)

## Số Dấu tối đa mang cùng lúc. Di Vật "Bánh Xe Nguyên Tố" nâng lên 3 (futureplan §3.3).
var max_marks: int = ElementTypes.DEFAULT_MAX_MARKS

# Nhãn nổi trên đầu — cao hơn HP bar của enemy (HP_BAR_HEIGHT = 1.25) để không chồng.
const LABEL_Y: float = 1.55
const LABEL_ELITE_SCALE: float = 1.35   # elite phóng to 1.35× → nâng nhãn theo
const LABEL_FONT_SIZE: int = 22

const DOT_INTERVAL: float = 1.0    # nhịp sát thương nền (1 giây)
const SLOW_REFRESH: float = 0.3    # hạn slow ngắn, gia hạn mỗi frame → luôn đúng

# ── Đồng hồ dùng chung ────────────────────────────────────────────────────────
# Đồng hồ thật nằm ở ReactionTable (xem ghi chú ở đó: cắt vòng phụ thuộc).
# Ở đây chỉ là cửa đọc cho tiện gọi — `ElementMarks.now()`.
static func now() -> float:
	return ReactionTable.now()

# ── State ─────────────────────────────────────────────────────────────────────
# Mỗi Dấu: {element: String, expires_at: float, stacks: int, source: Node}
# Thứ tự mảng = thứ tự gắn → phần tử [0] luôn là Dấu CŨ NHẤT.
var _marks: Array[Dictionary] = []
var _owner_node: Node = null       # con địch mang Dấu (parent)
var _label: Label3D = null         # nhãn biểu tượng, là con của địch (không phải của node này)
var _dot_timer: float = DOT_INTERVAL

func _ready() -> void:
	_owner_node = get_parent()
	if _owner_node == null:
		push_warning("ElementMarks không có parent — Dấu sẽ không hoạt động.")

func _exit_tree() -> void:
	# Dọn nhãn để không treo lại trong scene khi node bị gỡ riêng lẻ.
	_free_label()

# ── API công khai ─────────────────────────────────────────────────────────────

## Gắn một Dấu. `duration_mult` đến từ trang bị "Đá Dẫn Nguyên Tố" / thuốc "Dầu Dẫn".
## `duration_bonus` cộng THẲNG số giây (thưởng cấp Ô nguyên tố: Lv2 +2s, Lv3 +4s).
## Cộng SAU khi nhân `duration_mult` để hai nguồn không nhân chồng nhau.
func apply(element: String, source: Node = null, duration_mult: float = 1.0,
		duration_bonus: float = 0.0) -> void:
	if not ElementTypes.is_valid(element):
		return
	if not _owner_alive():
		return

	var spec: Dictionary = ElementTypes.spec(element)
	var duration: float = ElementTypes.duration_of(element) * maxf(0.05, duration_mult)
	duration += maxf(0.0, duration_bonus)
	var deadline: float = now() + duration

	# 1) Đã mang Dấu cùng loại → làm mới thời hạn (Độc cộng thêm 1 tầng).
	#    Giữ nguyên vị trí trong mảng để thứ tự "cũ nhất" không bị xáo.
	var same := _index_of(element)
	if same >= 0:
		var existing: Dictionary = _marks[same]
		existing["expires_at"] = maxf(float(existing.get("expires_at", 0.0)), deadline)
		if source != null:
			existing["source"] = source
		if bool(spec.get("stacking", false)):
			var cap: int = _stack_cap(element, spec)
			existing["stacks"] = mini(int(existing.get("stacks", 1)) + 1, cap)
		_marks[same] = existing
		_refresh_label()
		return

	# 2) Dấu mới — thử ghép phản ứng với Dấu đang có (duyệt từ Dấu CŨ NHẤT).
	#    Có phản ứng → nổ ngay, tiêu thụ CẢ HAI, KHÔNG thêm Dấu mới vào mảng.
	for i in range(_marks.size()):
		var other: Dictionary = _marks[i]
		var other_element := str(other.get("element", ""))
		var reaction: Dictionary = ReactionTable.find(element, other_element)
		if reaction.is_empty():
			continue
		# Di vật "Lò Phản Ứng": có xác suất phản ứng nổ mà KHÔNG ăn Dấu cũ.
		# Dấu MỚI vẫn không được thêm vào (nếu thêm cả hai thì mỗi đòn sau đó
		# lại nổ tiếp và vòng lặp phản ứng thành vô hạn).
		if not _keeps_marks():
			_marks.remove_at(i)
		else:
			# Làm mới hạn Dấu giữ lại — nếu không nó vẫn hết hạn theo mốc cũ.
			other["expires_at"] = maxf(float(other.get("expires_at", 0.0)), deadline)
			_marks[i] = other
		_refresh_label()
		_fire_reaction(reaction, element, other, source)
		return

	# 3) Không phản ứng → thêm Dấu; vượt trần thì đẩy Dấu CŨ NHẤT ra.
	while _marks.size() >= maxi(1, max_marks):
		_marks.pop_front()
	_marks.append({
		"element": element,
		"expires_at": deadline,
		"stacks": 1,
		"source": source,
	})
	_refresh_label()
	_perk_water_spread(element, source, duration_mult)

## Perk "Thuỷ Mạch" — Dấu Thuỷ vừa bám thì tự cấy sang 1 địch kề gần nhất.
## Dùng `implant` để không kích phản ứng dây chuyền, và chỉ chạy ở nhánh
## "Dấu mới được thêm" nên gia hạn Dấu cũ không lây thêm lần nữa.
const WATER_SPREAD_RADIUS: float = 2.0

func _perk_water_spread(element: String, source: Node, duration_mult: float) -> void:
	if element != ElementTypes.WATER or not _owner_alive():
		return
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null or not bool(gm.get("perk_water_spread")):
		return
	var origin: Vector3 = (_owner_node as Node3D).global_position if _owner_node is Node3D else Vector3.ZERO
	var best: Node = null
	var best_dist := WATER_SPREAD_RADIUS * WATER_SPREAD_RADIUS
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == _owner_node or not is_instance_valid(node) or not (node is Node3D):
			continue
		if bool(node.get("_is_dead")):
			continue
		var dist: float = (node as Node3D).global_position.distance_squared_to(origin)
		if dist <= best_dist:
			best_dist = dist
			best = node
	if best == null:
		return
	var marks: Variant = best.get("marks")
	if marks is Node and is_instance_valid(marks) and (marks as Node).has_method("implant"):
		(marks as Node).call("implant", ElementTypes.WATER, 1, source, duration_mult)

## Cấy thẳng một Dấu, BỎ QUA kiểm tra phản ứng — dùng cho hiệu ứng lây lan
## (Lan Truyền, Cháy Độc...). Không có đường này thì lây lan sẽ tự kích phản ứng
## dây chuyền trên từng mục tiêu và có nguy cơ nổ vô hạn.
##
## `stacks` là GIÁ TRỊ TUYỆT ĐỐI, KHÔNG cộng dồn: gọi implant(POISON, 1) mười
## lần vẫn chỉ ra 1 tầng. Cố ý — Lan Truyền phải sao chép ĐÚNG số tầng của con
## nguồn, còn Cháy Độc tự tính sẵn số nhân đôi rồi mới truyền vào.
## Muốn cộng dồn từng tầng thì dùng `apply()`.
func implant(element: String, stacks: int = 1, source: Node = null, duration_mult: float = 1.0) -> void:
	if not ElementTypes.is_valid(element) or not _owner_alive():
		return
	var spec: Dictionary = ElementTypes.spec(element)
	# Dùng _stack_cap chứ không đọc thẳng spec: perk "Độc Sư" / synergy "Đại Dịch"
	# phải nâng trần cho CẢ Dấu cấy (Cháy Độc, Lan Truyền), không riêng Dấu bắn ra.
	var cap: int = _stack_cap(element, spec) if bool(spec.get("stacking", false)) else 1
	var deadline: float = now() + ElementTypes.duration_of(element) * maxf(0.05, duration_mult)

	var same := _index_of(element)
	if same >= 0:
		var existing: Dictionary = _marks[same]
		existing["expires_at"] = maxf(float(existing.get("expires_at", 0.0)), deadline)
		existing["stacks"] = mini(maxi(int(existing.get("stacks", 1)), stacks), cap)
		_marks[same] = existing
	else:
		while _marks.size() >= maxi(1, max_marks):
			_marks.pop_front()
		_marks.append({
			"element": element,
			"expires_at": deadline,
			"stacks": clampi(stacks, 1, cap),
			"source": source,
		})
	_refresh_label()

func has_mark(element: String) -> bool:
	return _index_of(element) >= 0

func mark_count() -> int:
	return _marks.size()

## Synergy Hoả ×6 "Biển Lửa" — mỗi nhịp cháy, Dấu Hoả cấy sang địch trong bán kính.
## Dùng `implant` nên KHÔNG tự kích phản ứng: nếu dùng `apply`, một con dính Thuỷ
## đứng cạnh sẽ nổ Bốc Hơi mỗi giây và biến DoT thành máy huỷ diệt vô hạn.
func _sea_of_fire_spread(mark: Dictionary) -> void:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return
	var raw: Variant = gm.get("syn_fire_spread")
	var radius: float = float(raw) if (raw is int or raw is float) else 0.0
	if radius <= 0.0 or not (_owner_node is Node3D):
		return
	var origin: Vector3 = (_owner_node as Node3D).global_position
	var radius_sq := radius * radius
	var source: Variant = mark.get("source")
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == _owner_node or not is_instance_valid(node) or not (node is Node3D):
			continue
		if bool(node.get("_is_dead")):
			continue
		if (node as Node3D).global_position.distance_squared_to(origin) > radius_sq:
			continue
		var other: Variant = node.get("marks")
		if other is Node and is_instance_valid(other) and (other as Node).has_method("implant"):
			# Chỉ cấy cho con CHƯA có Dấu Hoả — nếu không, lửa gia hạn lẫn nhau
			# vòng tròn và không bao giờ tắt.
			if not bool((other as Node).call("has_mark", ElementTypes.FIRE)):
				(other as Node).call("implant", ElementTypes.FIRE, 1,
					source if source is Node else null)

## Hệ số khắc/kháng của con địch này với một nguyên tố.
func _owner_element_mult(element: String) -> float:
	if _owner_node == null or not _owner_node.has_method("element_multiplier"):
		return 1.0
	return float(_owner_node.call("element_multiplier", element))

## % sát thương DoT cộng thêm cho một nguyên tố (perk "Hoả Sư"...).
func _perk_element_bonus(element: String) -> float:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return 0.0
	var table: Variant = gm.get("perk_element_damage")
	if not (table is Dictionary):
		return 0.0
	var value: Variant = (table as Dictionary).get(element)
	return maxf(0.0, float(value)) if (value is int or value is float) else 0.0

## Trần số tầng của một Dấu — perk "Độc Sư" nâng trần Độc.
func _stack_cap(element: String, spec: Dictionary) -> int:
	var cap: int = maxi(1, int(spec.get("max_stacks", 1)))
	if element != ElementTypes.POISON:
		return cap
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return cap
	# Hai nguồn nâng trần: perk "Độc Sư" (8) và synergy Độc ×6 "Đại Dịch" (10).
	# Lấy MAX — chồng cả hai vẫn là 10, không cộng thành 18.
	for field in ["perk_poison_max_stacks", "syn_poison_stacks"]:
		var value: Variant = gm.get(field)
		if value is int or value is float:
			cap = maxi(cap, int(value))
	return cap

## Lượt phản ứng này có giữ lại Dấu cũ không (di vật "Lò Phản Ứng")?
func _keeps_marks() -> bool:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return false
	var chance: Variant = gm.get("relic_no_consume_chance")
	if not (chance is int or chance is float):
		return false
	return randf() < clampf(float(chance), 0.0, 0.95)

## Số tầng của một Dấu (0 nếu không mang).
func stacks_of(element: String) -> int:
	var i := _index_of(element)
	return int(_marks[i].get("stacks", 1)) if i >= 0 else 0

## Gỡ sạch Dấu + nhãn. enemy.die() gọi hàm này trước khi free.
func clear_all() -> void:
	_marks.clear()
	_free_label()

## Bản sao chỉ-đọc của danh sách Dấu (cho UI / debug).
func marks_snapshot() -> Array:
	var out: Array = []
	for m in _marks:
		out.append(m.duplicate())
	return out

# ── Vòng đời ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Đẩy đồng hồ TRƯỚC mọi early-return: enemy.gd đọc `ElementMarks.now()` để
	# kiểm tra Đóng Băng, đồng hồ đứng = địch bị khoá vĩnh viễn.
	ReactionTable.advance_clock(delta)

	if _marks.is_empty():
		_dot_timer = DOT_INTERVAL   # Dấu tiếp theo luôn có trọn 1 giây trước nhịp đầu
		return
	if not _owner_alive():
		clear_all()
		return

	_expire_marks()
	if _marks.is_empty():
		_dot_timer = DOT_INTERVAL
		return

	_apply_slow()

	_dot_timer -= delta
	if _dot_timer <= 0.0:
		_dot_timer = DOT_INTERVAL
		_apply_dot()

# ── Nội bộ ────────────────────────────────────────────────────────────────────

func _index_of(element: String) -> int:
	for i in range(_marks.size()):
		if str(_marks[i].get("element", "")) == element:
			return i
	return -1

func _owner_alive() -> bool:
	if _owner_node == null or not is_instance_valid(_owner_node):
		return false
	if not _owner_node.is_inside_tree():
		return false
	return not bool(_owner_node.get("_is_dead"))

## Gỡ các Dấu quá hạn (duyệt ngược để remove_at an toàn).
func _expire_marks() -> void:
	var t := now()
	var changed := false
	for i in range(_marks.size() - 1, -1, -1):
		if float(_marks[i].get("expires_at", 0.0)) <= t:
			_marks.remove_at(i)
			changed = true
	if changed:
		_refresh_label()

## Làm chậm = giá trị LỚN NHẤT trong các Dấu, gia hạn mỗi frame.
## `apply_slow` của enemy lấy max nên gọi lặp là an toàn.
func _apply_slow() -> void:
	var strongest := 0.0
	for m in _marks:
		var spec: Dictionary = ElementTypes.spec(str(m.get("element", "")))
		strongest = maxf(strongest, float(spec.get("slow", 0.0)))
	# Gọi qua `call()`: `_owner_node` khai kiểu Node nên truy cập thẳng phương thức
	# của Enemy sẽ là lỗi parse (và khai kiểu Enemy thì thành cyclic reference).
	if strongest > 0.0 and _owner_node.has_method("apply_slow"):
		_owner_node.call("apply_slow", strongest, SLOW_REFRESH)

## Một nhịp sát thương nền của tất cả Dấu đang mang.
func _apply_dot() -> void:
	if not _owner_node.has_method("take_damage"):
		return

	# "Ướt": Dấu Thuỷ khuếch đại sát thương của các Dấu liệt kê trong `amplify_from`.
	var water_spec: Dictionary = ElementTypes.spec(ElementTypes.WATER)
	var amplify_from: Array = water_spec.get("amplify_from", [])
	var amplify_pct := float(water_spec.get("amplify_pct", 0.0))
	var wet := has_mark(ElementTypes.WATER)

	# Duyệt bản sao: take_damage có thể giết địch → die() gọi clear_all() làm rỗng _marks.
	for m in _marks.duplicate():
		if not _owner_alive():
			return
		var element := str(m.get("element", ""))
		var spec: Dictionary = ElementTypes.spec(element)
		var dps := float(spec.get("dps", 0.0))
		if dps <= 0.0:
			continue

		var amount := dps * float(maxi(1, int(m.get("stacks", 1))))
		if wet and amplify_from.has(element):
			amount *= 1.0 + amplify_pct
		# Perk theo nguyên tố ("Hoả Sư", "Thợ Ghép Mạch") — nhân vào DoT của
		# đúng Dấu đó, KHÔNG đụng sát thương phản ứng (đã có reaction_power_mult).
		amount *= 1.0 + _perk_element_bonus(element)
		# Khắc/kháng nguyên tố của loài (EnemyStats.DEFAULT_AFFINITY).
		amount *= _owner_element_mult(element)

		if element == ElementTypes.FIRE:
			_sea_of_fire_spread(m)
		var final_damage := int(round(amount))
		if final_damage <= 0:
			continue

		# Dấu Lôi bỏ qua giáp. `take_damage` trừ giáp BÊN TRONG nó, nên ở đây phải
		# cộng bù đúng lượng giáp hiệu dụng vào trước để phần trừ đi triệt tiêu.
		if bool(spec.get("pierce_armor", false)):
			final_damage += _owner_effective_armor()

		_owner_node.call("take_damage", final_damage, "burn")

## Giáp hiệu dụng của địch (0 khi đang bị Tan Chảy xoá giáp).
func _owner_effective_armor() -> int:
	if _owner_node != null and _owner_node.has_method("effective_armor"):
		return int(_owner_node.call("effective_armor"))
	return 0

## Kích phản ứng: chốt vị trí trước (địch có thể chết trong `trigger`).
func _fire_reaction(reaction: Dictionary, incoming: String, consumed: Dictionary, source: Node) -> void:
	var pos := Vector3.ZERO
	if _owner_node is Node3D:
		pos = (_owner_node as Node3D).global_position

	# Ngữ cảnh cho các phản ứng cần biết Dấu bị tiêu thụ (Lan Truyền giữ nguyên số tầng Độc).
	var poison_stacks := 1
	if str(consumed.get("element", "")) == ElementTypes.POISON:
		poison_stacks = maxi(1, int(consumed.get("stacks", 1)))

	var reaction_source: Node = source
	if reaction_source == null:
		var fallback: Variant = consumed.get("source")
		if fallback is Node:
			reaction_source = fallback

	ReactionTable.trigger(reaction, _owner_node, reaction_source, {
		"incoming": incoming,
		"consumed": consumed.duplicate(),
		"poison_stacks": poison_stacks,
	})
	reaction_triggered.emit(str(reaction.get("id", "")), pos)

# ── Nhãn biểu tượng Dấu ───────────────────────────────────────────────────────

## Nhãn là CON CỦA ĐỊCH (Node3D) chứ không phải của node này: ElementMarks là Node
## thuần, đặt Label3D dưới nó sẽ cắt đứt chuỗi transform 3D → nhãn nằm sai chỗ.
func _refresh_label() -> void:
	if _marks.is_empty():
		_free_label()
		return
	if not _owner_alive() or not (_owner_node is Node3D):
		return

	if _label == null or not is_instance_valid(_label):
		_label = Label3D.new()
		_label.name = "ElementMarkLabel"
		_label.font_size = LABEL_FONT_SIZE
		_label.pixel_size = 0.01
		_label.outline_size = 7
		_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.fixed_size = false
		_owner_node.add_child(_label)
		var y := LABEL_Y
		if bool(_owner_node.get("is_elite")):
			y *= LABEL_ELITE_SCALE
		_label.position = Vector3(0.0, y, 0.0)

	var text := ""
	for m in _marks:
		var element := str(m.get("element", ""))
		text += ElementTypes.icon(element)
		var stacks := int(m.get("stacks", 1))
		if stacks > 1:
			text += str(stacks)
	_label.text = text
	# Tô theo Dấu mới nhất — kể cả khi font thiếu glyph emoji, màu vẫn đọc được.
	_label.modulate = ElementTypes.color_of(str(_marks[_marks.size() - 1].get("element", "")))

func _free_label() -> void:
	if _label != null and is_instance_valid(_label) and not _label.is_queued_for_deletion():
		_label.queue_free()
	_label = null
