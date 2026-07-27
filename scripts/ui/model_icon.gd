# res://scripts/ui/model_icon.gd
class_name ModelIcon
extends SubViewportContainer

## Icon 3D THẬT: render model glTF vào SubViewport rồi hiển thị như một Control.
## [br][br]
## Đây là điểm nhấn "UI 3D" — card shop / tower info / perk / king select dùng nó
## thay cho sprite phẳng. Model tự xoay chậm để có chiều sâu.
## [br][br]
## An toàn khi thiếu asset: nếu [code].gltf[/code] không tồn tại (hoặc đã vượt
## hạn mức [constant MAX_LIVE_3D] icon 3D cùng lúc) thì hiển thị texture 2D
## fallback bên trong SubViewport (filter NEAREST, giữ pixel art).

const MODEL_DIR := "res://assets/models/%s.gltf"

## Cạnh SubViewport (px). 96 đủ nét cho icon ≤ 128 px.
const VIEW_SIZE := 96
## Kích thước mục tiêu của model trong không gian 3D (m) — khớp ortho size camera.
const FIT_SIZE := 1.55
## Trần số icon 3D sống cùng lúc — SubViewport UPDATE_ALWAYS khá đắt.
const MAX_LIVE_3D := 8

## Số ModelIcon đang render 3D trên toàn game (dùng để chặn quá tải).
static var _live_3d_count: int = 0

## Bật/tắt tự xoay.
@export var spin: bool = true
## Tốc độ xoay (rad/s).
@export var spin_speed: float = 0.6

var _viewport: SubViewport = null
var _pivot: Node3D = null
var _camera: Camera3D = null
var _fallback_rect: TextureRect = null
var _has_model: bool = false
var _counted: bool = false
## Cạnh render thực tế — nâng lên khi icon hiển thị lớn hơn VIEW_SIZE để không mờ.
var _view_px: int = VIEW_SIZE

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_SIZE, VIEW_SIZE)
	set_process(false)

func _process(delta: float) -> void:
	if spin and _has_model and is_instance_valid(_pivot):
		_pivot.rotate_y(spin_speed * delta)

func _exit_tree() -> void:
	_release_count()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_count()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		# Panel ẩn (ví dụ ShopPanel lúc chưa tới phase Shop) → ngừng render 3D.
		# Nhờ vậy ModelIcon tạo sẵn trong _ready cũng không tốn GPU.
		_sync_render_to_visibility()

func _sync_render_to_visibility() -> void:
	if not is_instance_valid(_viewport):
		return
	var live := is_visible_in_tree()
	if not live:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)
		return
	# Có model 3D đang xoay → phải vẽ liên tục; chỉ fallback 2D tĩnh thì 1 frame.
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if _has_model else SubViewport.UPDATE_ONCE)
	set_process(spin and _has_model)

## Huỷ icon và GIẢI PHÓNG NGAY hạn mức 3D (không đợi queue_free cuối frame).
## Phải dùng hàm này khi rebuild panel, nếu không icon mới sẽ bị đẩy về fallback 2D.
func dispose() -> void:
	_release_count()
	queue_free()

# ── Public API ────────────────────────────────────────────────────────────────

## Nạp model theo id trong res/*.tres (pawn, orc, king, …).
func setup_by_id(unit_id: String, fallback_tex: Texture2D = null) -> void:
	setup(MODEL_DIR % unit_id, fallback_tex)

## Nạp model theo đường dẫn tuyệt đối; thiếu file → dùng [param fallback_tex].
func setup(model_path: String, fallback_tex: Texture2D = null) -> void:
	_ensure_viewport()
	if _viewport == null:
		return
	_clear_content()

	var can_3d := _live_3d_count < MAX_LIVE_3D
	if can_3d and model_path != "" and ResourceLoader.exists(model_path):
		var packed := load(model_path) as PackedScene
		if packed:
			var model := packed.instantiate()
			if model is Node3D:
				# Holder trung gian: scale/offset canh khung được áp lên holder nên
				# transform gốc của glTF (thường có rotation Y-up) không bị hỏng.
				var holder := Node3D.new()
				holder.name = "FitHolder"
				_pivot.add_child(holder)
				holder.add_child(model)
				_fit_holder(holder, model as Node3D)
				_has_model = true
				_claim_count()
				_set_3d_visible(true)
				_sync_render_to_visibility()
				return
			# Model tồn tại nhưng không phải Node3D — bỏ, dùng fallback
			model.queue_free()
		else:
			push_warning("ModelIcon: không load được PackedScene: %s" % model_path)

	_show_fallback(fallback_tex)

## Bật/tắt xoay tại runtime.
func set_spin(enabled: bool) -> void:
	spin = enabled
	set_process(enabled and _has_model and is_visible_in_tree())

## Tạm dừng render thủ công (ví dụ panel trượt ra ngoài màn nhưng vẫn visible).
## Truyền true sẽ đồng bộ lại theo visibility thực tế.
func set_active(active: bool) -> void:
	if not is_instance_valid(_viewport):
		return
	if active:
		_sync_render_to_visibility()
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)

## Đổi kích thước hiển thị. Nếu lớn hơn VIEW_SIZE thì nâng cả độ phân giải
## SubViewport để icon không bị upscale mờ.
func set_icon_size(px: int) -> void:
	custom_minimum_size = Vector2(px, px)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_view_px = maxi(VIEW_SIZE, px)
	if is_instance_valid(_viewport):
		_viewport.size = Vector2i(_view_px, _view_px)

## Có đang render model 3D thật (false = đang dùng fallback 2D).
func has_model() -> bool:
	return _has_model

# ── Build ─────────────────────────────────────────────────────────────────────

## Dựng SubViewport + camera + đèn (chỉ 1 lần). own_world_3d BẮT BUỘC bật,
## nếu không viewport sẽ kéo cả World3D của bàn cờ vào icon.
func _ensure_viewport() -> void:
	if is_instance_valid(_viewport):
		return
	_viewport = SubViewport.new()
	_viewport.name = "IconViewport"
	_viewport.size = Vector2i(_view_px, _view_px)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.disable_3d = false
	add_child(_viewport)

	# Ánh sáng môi trường nhẹ để mặt tối của model không đen kịt
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.60, 0.70, 1.0)
	env.ambient_light_energy = 0.85
	world_env.environment = env
	_viewport.add_child(world_env)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_viewport.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.name = "IconCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 2.2
	_camera.near = 0.05
	_camera.far = 20.0
	# Nhìn chéo xuống ~25° từ phía trước
	_camera.position = Vector3(0.0, 1.12, 2.40)
	_camera.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	_viewport.add_child(_camera)

	# Key light ấm từ trên-trái (khớp quy ước ánh sáng pixel art của dự án)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(1.0, 0.94, 0.82, 1.0)
	key.light_energy = 1.7
	key.rotation_degrees = Vector3(-42.0, 34.0, 0.0)
	_viewport.add_child(key)

	# Fill light lạnh yếu từ phía đối diện → tách khối
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.58, 0.68, 0.92, 1.0)
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-14.0, -132.0, 0.0)
	_viewport.add_child(fill)

	# TextureRect fallback nằm TRONG viewport (2D vẽ trên 3D) — tránh vướng
	# cơ chế sort children của SubViewportContainer.
	_fallback_rect = TextureRect.new()
	_fallback_rect.name = "FallbackIcon"
	_fallback_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fallback_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fallback_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback_rect.visible = false
	_viewport.add_child(_fallback_rect)

## Xoá model cũ + reset trạng thái (giữ lại camera/đèn).
func _clear_content() -> void:
	_release_count()
	_has_model = false
	set_process(false)
	if is_instance_valid(_pivot):
		_pivot.rotation = Vector3.ZERO
		for child in _pivot.get_children():
			child.queue_free()
	if is_instance_valid(_fallback_rect):
		_fallback_rect.visible = false

## Fallback 2D: nội dung tĩnh → chỉ cần render 1 frame rồi dừng (UPDATE_ONCE).
func _show_fallback(fallback_tex: Texture2D) -> void:
	_set_3d_visible(false)
	if not is_instance_valid(_fallback_rect):
		return
	if fallback_tex == null:
		_fallback_rect.visible = false
	else:
		_fallback_rect.texture = fallback_tex
		_fallback_rect.visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	set_process(false)

## Tắt camera/đèn khi chỉ hiện fallback 2D — khỏi render 3D vô ích.
func _set_3d_visible(enabled: bool) -> void:
	if is_instance_valid(_camera):
		_camera.visible = enabled
	if is_instance_valid(_pivot):
		_pivot.visible = enabled

# ── Auto-fit model ────────────────────────────────────────────────────────────

## Canh model vừa khung: tính AABB tổng (đã gồm transform gốc của model) trong
## không gian holder, scale holder về FIT_SIZE rồi dịch tâm về gốc pivot để
## model xoay quanh trục giữa của chính nó.
func _fit_holder(holder: Node3D, model: Node3D) -> void:
	var box := _combined_aabb(model, model.transform)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest <= 0.0001:
		push_warning("ModelIcon: AABB model rỗng, giữ scale gốc.")
		return
	var factor: float = FIT_SIZE / longest
	holder.scale = Vector3(factor, factor, factor)
	holder.position = -box.get_center() * factor

## Duyệt đệ quy gom AABB (đã transform về không gian model root).
func _combined_aabb(node: Node, accumulated: Transform3D) -> AABB:
	var result := AABB()
	var has_any := false
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			result = accumulated * mi.get_aabb()
			has_any = true
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var child_xform: Transform3D = accumulated * (child as Node3D).transform
		var sub := _combined_aabb(child, child_xform)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if not has_any else result.merge(sub)
		has_any = true
	return result if has_any else AABB()

# ── Quota icon 3D ─────────────────────────────────────────────────────────────
func _claim_count() -> void:
	if _counted:
		return
	_counted = true
	_live_3d_count += 1

func _release_count() -> void:
	if not _counted:
		return
	_counted = false
	_live_3d_count = maxi(0, _live_3d_count - 1)
