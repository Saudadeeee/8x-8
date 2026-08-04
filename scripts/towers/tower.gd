# res://scripts/towers/tower.gd
class_name Tower
extends Node3D

@export var stats: TowerStats

const TILE_SIZE: float = 1.0
const SHOW_RANGE_DEBUG: bool = false   # giữ flag — không còn debug draw trong 3D
const MUZZLE_HEIGHT: float = 0.5
const MODEL_DIR := "res://assets/models/%s.gltf"

# ── Hệ sao (★ star merge) ─────────────────────────────────────────────────
# Sao là hệ số NHÂN, hoàn toàn tách khỏi BuffLayer (vốn là cộng thêm).
# Index của các bảng dưới = star - 1.
## Trần tầm bắn sau MỌI cộng dồn. 9 ô = base cao nhất (7) + 2 ô thưởng.
const MAX_EFFECTIVE_RANGE: int = 9
## Sàn hồi chiêu = tỉ lệ này × hồi chiêu gốc của chính tháp (trần tăng tốc ×2.5).
const MIN_COOLDOWN_RATIO: float = 0.4

const MAX_STAR: int = 3
const STAR_DAMAGE_MULT:  Array[float] = [1.0, 1.8, 3.2]   # ★1 / ★2 / ★3
const STAR_RANGE_BONUS:  Array[int]   = [0, 0, 1]         # ★3 thêm 1 ô tầm bắn
const STAR_VISUAL_SCALE: Array[float] = [1.0, 1.15, 1.32] # model to dần theo sao
const STAR_LABEL_NAME:   String       = "StarLabel"
const STAR_LABEL_HEIGHT: float        = 1.15
const STAR_LABEL_SILVER := Color(0.847, 0.847, 0.878)     # #d8d8e0 — ★2
const STAR_LABEL_GOLD   := Color(1.0, 0.824, 0.235)       # #ffd23c — ★3
const STAR_UP_COLOR     := Color(1.0, 0.85, 0.25)         # burst khi lên sao

# Màu đạn theo loại tower — dùng cho bolt mesh + burst khi trúng
const PROJ_COLORS: Dictionary = {
	"pawn":        Color(1.0, 0.85, 0.5),
	"knight":      Color(1.0, 0.55, 0.2),
	"rook":        Color(0.8, 0.8, 0.85),
	"bishop":      Color(0.4, 0.9, 1.0),
	"queen":       Color(1.0, 0.8, 0.15),
	"commander":   Color(0.95, 0.25, 0.25),
	"crossbowman": Color(0.9, 0.75, 0.5),
	"catapult":    Color(0.6, 0.6, 0.6),
	"warlock":     Color(0.75, 0.3, 0.95),
	"dark_mage":   Color(0.85, 0.2, 0.85),
	"water":       Color(0.3, 0.6, 1.0),
}

@onready var visual:          Node3D           = $Visual
@onready var range_area:      Area3D           = $RangeArea
@onready var collision_shape: CollisionShape3D = $RangeArea/CollisionShape3D

var projectile_scene = preload("res://scenes/projectile/projectile.tscn")

# ── Computed stats (recalculated from base + all buff layers) ──────────────
var current_damage:       int   = 0
var current_attack_speed: float = 1.0
var current_range:        int   = 0

# ── Buff layer system ─────────────────────────────────────────────────────
# Adding a new buff source = add one enum value + one call to _set_buff_layer().
# Layer mới phải append CUỐI — giữ nguyên index các layer cũ.
# BIOME         = biome của Ô LÃNH THỔ (territory) tháp đang đứng.
# BIOME_CLIMATE = khí hậu TOÀN BẢN ĐỒ (BiomeEffects) — hoàn toàn tách biệt.
# EQUIP  = trang bị gắn riêng cho tháp này (2 ô).
# POTION = thuốc vùng, tạm thời, tự hết hạn.
# TILE_ELEMENT = thưởng theo CẤP ô nguyên tố (Lv3 Long Mạch +15% sát thương).
#                Tách khỏi TILE (ô Phước/Nguyền) và BIOME (buff chỉ số của ô) vì
#                ba nguồn này tồn tại đồng thời trên cùng một ô.
# ELEM_SYNERGY = synergy theo NGUYÊN TỐ (trục đếm thứ 2). Tách khỏi SYNERGY
#                (đếm theo loại quân) vì hai trục tồn tại song song trên cùng tháp.
enum BuffLayer { UPGRADE, BIOME, FAVOR, BOON, AURA, SYNERGY, PERK, TILE, BIOME_CLIMATE, EQUIP, POTION, TILE_ELEMENT, ELEM_SYNERGY }

## Buff synergy nguyên tố — ElementSynergy gọi. Rỗng dict = gỡ lớp.
func apply_element_synergy_buff(data: Dictionary) -> void:
	if data.is_empty():
		_clear_buff_layer(BuffLayer.ELEM_SYNERGY)
		return
	_set_buff_layer(BuffLayer.ELEM_SYNERGY,
		stats.base_damage * float(data.get("damage_pct", 0.0)) if stats else 0.0,
		float(data.get("speed_bonus", 0.0)),
		int(data.get("range_bonus", 0)))

var _dmg_bonus: Dictionary = {}  # BuffLayer → float (absolute bonus to base_damage)
var _spd_bonus: Dictionary = {}  # BuffLayer → float (seconds to subtract from attack_speed)
var _rng_bonus: Dictionary = {}  # BuffLayer → int   (tiles to add to attack_range)

# Season is kept separate: damage is a multiplier (not additive), speed is a penalty
var season_damage_mult:  float = 1.0
var season_speed_penalty: float = 0.0

# ── Sao: nhân sát thương + cộng tầm, KHÔNG đi qua BuffLayer ────────────────
# star luôn nằm trong [1, MAX_STAR]; hai biến dưới là cache dẫn xuất từ star
# nên recalculate_stats() (gọi từ bất kỳ nguồn buff nào) luôn giữ được hệ sao.
var star: int = 1
var star_damage_mult: float = 1.0
var _star_range_bonus: int  = 0
var _star_label: Label3D    = null

# King Flame ability — temporary burn projectile override (read/written by game_map.gd)
var boon_burn_override: bool = false

# ── Combat state ──────────────────────────────────────────────────────────
## Địch nằm trong hình cầu LỌC THÔ (Area3D). Lọc tinh theo nước đi ở _process.
var _in_area: Array[Enemy] = []
var targets_in_range: Array[Enemy] = []
var current_target:   Enemy        = null
var can_shoot:        bool         = true
var cooldown_timer:   Timer

# ── Ưu tiên mục tiêu ──────────────────────────────────────────────────────
# FIRST     = phần tử đầu danh sách (quái vào tầm sớm nhất — mặc định cũ)
# STRONGEST = current_hp cao nhất · CLOSEST = gần tháp nhất · WEAKEST = hp thấp nhất
enum TargetMode { FIRST, STRONGEST, CLOSEST, WEAKEST }

const TARGET_MODE_LABELS: Array[String] = ["Surrender", "Highest HP", "Nearest", "Lowest HP"]

var target_mode: int = TargetMode.FIRST

# ── Juice ─────────────────────────────────────────────────────────────────
var _visual_tween: Tween = null
var _mesh_instances: Array[MeshInstance3D] = []   # material_override riêng per instance

# ── Overcharge (right-click magic) ────────────────────────────────────────
const OVERCHARGE_COOLDOWN_MULT: float = 0.5
const OVERCHARGE_TINT  := Color(0.75, 1.1, 1.4)   # cyan nhẹ khi active
const OVERCHARGE_COLOR := Color(0.4, 0.85, 1.0)   # burst + emission

var _overcharge_active: bool = false
var _oc_emission_mats: Array[BaseMaterial3D] = []  # mats mà overcharge đã bật emission

# ==========================================================================
# LIFECYCLE
# ==========================================================================

func _ready() -> void:
	add_to_group("towers")

	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	collision_shape.visible = false
	# Shape trong .tscn là sub-resource dùng chung giữa mọi instance —
	# phải thay bằng shape riêng, nếu không radius của tower này ghi đè tower khác.
	collision_shape.shape = SphereShape3D.new()

	range_area.area_entered.connect(_on_area_entered)
	range_area.area_exited.connect(_on_area_exited)
	_build_pick_area()

	if stats:
		load_tower_data()

# ── Vùng click (picking) ──────────────────────────────────────────────────
# VẤN ĐỀ: chọn ô bằng ray cắt mặt phẳng y = 0. Camera nghiêng −50°, model tháp
# cao ~1.2 m → THÂN tháp trên màn hình nằm lệch khỏi ô của nó khoảng
# 1.2 / tan(50°) ≈ 1.0 m = trọn một ô. Người chơi click vào thân tháp thì trúng
# ô PHÍA SAU nó, phải rê xuống đúng chân tháp mới chọn được.
#
# CÁCH SỬA: mỗi tháp mang một hộp va chạm bằng đúng một ô và cao bằng model,
# nằm trên layer "Pick" riêng. game_map bắn raycast vật lý vào layer đó TRƯỚC,
# chỉ khi trượt mới rơi về ray-plane. Click vào bất cứ điểm nào trên hình tháp
# đều chọn đúng tháp đó.
const PICK_LAYER: int = 8          # bit 4 — 3d_physics/layer_4 = "Pick"
# Rộng ĐÚNG 1 ô: để nhỏ hơn thì khe giữa hai tháp kề nhau thành vùng chết,
# click vào đó lại rơi xuống mặt đất. Hai hộp kề nhau chỉ chạm mặt, không chồng.
const PICK_BOX_SIZE := Vector3(1.0, 1.5, 1.0)

var _pick_area: Area3D = null

func _build_pick_area() -> void:
	_pick_area = Area3D.new()
	_pick_area.name = "PickArea"
	# Chỉ để raycast tìm thấy: không theo dõi va chạm, không nằm trên layer nào
	# mà hệ khác quét (RangeArea của tháp khác quét layer Enemy).
	_pick_area.collision_layer = PICK_LAYER
	_pick_area.collision_mask = 0
	_pick_area.monitoring = false
	_pick_area.monitorable = true
	_pick_area.input_ray_pickable = true

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = PICK_BOX_SIZE
	shape.shape = box
	# Đáy hộp sát mặt đất; hộp rộng đúng một ô nên hai tháp kề nhau không chồng
	# vùng click — raycast luôn trả về tháp đang nhìn thấy gần camera nhất.
	shape.position = Vector3(0.0, PICK_BOX_SIZE.y / 2.0, 0.0)
	_pick_area.add_child(shape)
	add_child(_pick_area)

func _process(delta) -> void:
	# Area3D chỉ là lọc THÔ (hình cầu bao trọn mọi ô nước đi có thể vươn tới).
	# Lọc TINH theo nước đi nằm ở đây: quân chỉ bắn được ô mà luật cờ cho phép.
	# Lọc lại TỪ DANH SÁCH THÔ mỗi frame: địch di chuyển nên ô nó đứng đổi liên
	# tục, quân phải nhặt được nó ngay khi nó bước vào ô mình phủ.
	# Gán tường minh từng phần tử: `Array.filter()` trả về `Array` KHÔNG có kiểu,
	# gán thẳng vào `Array[Enemy]` ném lỗi runtime MỖI FRAME — và lỗi đó không
	# làm game sập, chỉ khiến mọi tháp không bao giờ có mục tiêu. Đã dính.
	var alive: Array[Enemy] = []
	var valid: Array[Enemy] = []
	for e in _in_area:
		if not is_instance_valid(e):
			continue
		alive.append(e)
		if _is_valid_target(e):
			valid.append(e)
	_in_area = alive
	targets_in_range = valid
	if not is_instance_valid(current_target) or not _is_valid_target(current_target):
		update_target()
	_face_target(delta)
	_tick_auto_reaction(delta)
	if current_target and can_shoot and not _silenced_by_king():
		shoot()

## Xoay model (yaw) hướng về target hiện tại — mượt, không xoay root để giữ range area.
func _face_target(delta: float) -> void:
	if not visual or not is_instance_valid(current_target):
		return
	var dir: Vector3 = current_target.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(10.0 * delta, 0.0, 1.0))

func load_tower_data() -> void:
	_build_visual()
	recalculate_stats()
	update_range_visual()
	# _build_visual() reset scale của $Visual → phải áp lại scale/nhãn theo sao.
	_update_star_visual()
	# Ô Lv3 dưới chân cho +15% sát thương — đọc ngay lúc đặt.
	refresh_tile_element_bonus()

## Load model 3D theo stats.id; fallback = Sprite3D billboard dùng texture 2D cũ.
func _build_visual() -> void:
	if not visual or not stats:
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
			# Material glTF share giữa mọi instance cùng loại —
			# duplicate để tint overcharge per-instance không lan sang tháp khác.
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				var src: Material = mi.get_active_material(0)
				if src:
					mi.material_override = src.duplicate()
					_mesh_instances.append(mi)
			_play_spawn_pop()
			return

	# Fallback billboard
	if stats.texture == null:
		var fallback := "res://assets/towers/%s.png" % stats.id
		if ResourceLoader.exists(fallback):
			stats.texture = load(fallback)
	var billboard := Sprite3D.new()
	billboard.pixel_size = 0.03
	billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	billboard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard.position = Vector3(0.0, 0.5, 0.0)
	if stats.texture:
		billboard.texture = stats.texture
	visual.add_child(billboard)
	_play_spawn_pop()

## Scale nghỉ của $Visual — phụ thuộc sao. Mọi tween scale phải trả về giá trị này
## thay vì Vector3.ONE, nếu không tháp ★2/★3 sẽ tụt về kích thước ★1 sau khi bắn.
func _base_visual_scale() -> Vector3:
	var idx: int = clampi(star - 1, 0, STAR_VISUAL_SCALE.size() - 1)
	return Vector3.ONE * STAR_VISUAL_SCALE[idx]

## Pop scale khi đặt tower.
func _play_spawn_pop() -> void:
	if not is_inside_tree():
		return
	if _visual_tween:
		_visual_tween.kill()
	var base := _base_visual_scale()
	visual.scale = base * 0.15
	_visual_tween = create_tween()
	_visual_tween.tween_property(visual, "scale", base, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ==========================================================================
# HỆ SAO (★ STAR MERGE)
# ==========================================================================

## Còn nâng sao được không (dùng bởi TowerPlacer.can_merge_at).
func can_star_up() -> bool:
	return star < MAX_STAR

## Đặt cấp sao (1..MAX_STAR). Nếu là NÂNG sao thì chơi FX + SFX.
func set_star(n: int) -> void:
	var clamped: int = clampi(n, 1, MAX_STAR)
	var leveled_up: bool = clamped > star
	star             = clamped
	star_damage_mult = STAR_DAMAGE_MULT[star - 1]
	_star_range_bonus = STAR_RANGE_BONUS[star - 1]
	recalculate_stats()
	update_range_visual()
	_update_star_visual()
	if leveled_up:
		_play_star_up_fx()

## Đồng bộ scale model + nhãn ★ theo cấp sao hiện tại.
func _update_star_visual() -> void:
	if visual:
		# Không đè lên tween đang chạy — tween sẽ tự kết thúc ở _base_visual_scale().
		if not (_visual_tween and _visual_tween.is_valid() and _visual_tween.is_running()):
			visual.scale = _base_visual_scale()
	_refresh_star_label()

## Label3D world-space phía trên tháp. ★1 ẩn hoàn toàn để board không rối.
func _refresh_star_label() -> void:
	if star <= 1:
		if is_instance_valid(_star_label):
			_star_label.visible = false
		return
	if not is_instance_valid(_star_label):
		_star_label = get_node_or_null(NodePath(STAR_LABEL_NAME)) as Label3D
	if not is_instance_valid(_star_label):
		_star_label = _create_star_label()
		if _star_label == null:
			return
	_star_label.visible  = true
	_star_label.text     = "★".repeat(star)
	_star_label.modulate = STAR_LABEL_GOLD if star >= 3 else STAR_LABEL_SILVER

## Nhãn là con của ROOT (không phải $Visual) — nên không bị _build_visual() xoá,
## không bị scale theo sao và không xoay theo yaw khi tháp ngắm mục tiêu.
func _create_star_label() -> Label3D:
	var lbl := Label3D.new()
	lbl.name             = STAR_LABEL_NAME
	lbl.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test    = true
	lbl.fixed_size       = false
	lbl.shaded           = false
	lbl.double_sided     = true
	lbl.alpha_cut        = Label3D.ALPHA_CUT_DISCARD
	lbl.render_priority  = 2
	lbl.outline_render_priority = 1
	lbl.font_size        = 64
	lbl.outline_size     = 16
	lbl.outline_modulate = Color(0.05, 0.04, 0.02, 1.0)
	lbl.pixel_size       = 0.005
	lbl.position         = Vector3(0.0, STAR_LABEL_HEIGHT, 0.0)
	add_child(lbl)
	return lbl

## Burst vàng + sfx + pop scale khi lên sao.
func _play_star_up_fx() -> void:
	if not is_inside_tree():
		return
	FX.spawn_burst(get_parent(), global_position + Vector3(0.0, 0.6, 0.0), STAR_UP_COLOR, 24, 1.25)
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("crit", -4.0)
	if not visual:
		return
	if _visual_tween:
		_visual_tween.kill()
	var base := _base_visual_scale()
	visual.scale = base * 1.45
	_visual_tween = create_tween()
	_visual_tween.tween_property(visual, "scale", base, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ==========================================================================
# BUFF SYSTEM
# ==========================================================================

## Core recalculate — always sum from base + all active buff layers.
func recalculate_stats() -> void:
	if not stats:
		return
	var total_dmg: float = stats.base_damage
	var total_spd: float = 0.0
	var total_rng: int   = 0
	for v in _dmg_bonus.values(): total_dmg += v
	for v in _spd_bonus.values(): total_spd += v
	for v in _rng_bonus.values(): total_rng += v
	# Di vật "Fortress": Xe thành Pháo (khó bắn hơn vì cần ngòi) nên được bù
	# sát thương. Nhân ở đây chứ không qua BuffLayer vì nó phụ thuộc nước đi
	# HIỆN TẠI, mà nước đi đổi theo di vật.
	var gm_c := get_node_or_null("/root/GameManagerSingleton")
	if gm_c != null and bool(gm_c.relic_rook_as_cannon) and stats 			and int(stats.attack_pattern) == ChessPattern.Kind.ROOK:
		total_dmg *= maxf(1.0, float(gm_c.relic_cannon_damage_mult))
	# Meta upgrade ("Rèn vũ khí" / "Luyện tay") — cộng cho MỌI tháp, mọi ván.
	# Cộng ở đây chứ không qua BuffLayer: nó không bao giờ bị gỡ giữa ván nên
	# không cần một lớp riêng, và đi qua lớp nào cũng có nguy cơ bị hàm clear_*
	# của nguồn khác xoá nhầm.
	var gm_meta := get_node_or_null("/root/GameManagerSingleton")
	if gm_meta != null:
		total_dmg += stats.base_damage * maxf(0.0, float(gm_meta.meta_tower_damage_pct))
		total_spd += stats.attack_speed * maxf(0.0, float(gm_meta.meta_tower_speed_pct))
	# star_damage_mult là hệ số NHÂN (giống season) — luôn dẫn xuất từ `star` nên
	# không thể nhân chồng dù recalculate_stats() được gọi bao nhiêu lần.
	# SÀN sát thương = 1. Nhiều nguồn có thể ÂM (trang bị đánh đổi như Repeater
	# -40% sát thương lấy +50% tốc, khí hậu biome, di vật nhân đôi mặt trái).
	# Không có sàn thì cộng dồn đủ nhiều sẽ ra sát thương âm — quái được HỒI MÁU
	# khi bị bắn. Đã đo được -9 với hai Repeater + di vật Song Thủ.
	current_damage       = maxi(1, int(total_dmg * season_damage_mult * star_damage_mult))
	# SÀN hồi chiêu theo TỈ LỆ base, không phải hằng 0.1s. Giảm hồi chiêu là số
	# giây CỘNG PHẲNG từ nhiều nguồn (ô, perk, thuốc, trang bị); với sàn cứng 0.1
	# một tháp base 1.0s có thể chạm 10 phát/giây = ×10 DPS, phá mọi cân bằng.
	# MIN_COOLDOWN_RATIO = 0.4 → trần tăng tốc là ×2.5 so với chính nó.
	current_attack_speed = maxf(stats.attack_speed * MIN_COOLDOWN_RATIO,
		stats.attack_speed - total_spd + season_speed_penalty)
	# TRẦN tầm bắn: bàn khởi đầu chỉ 8×8 (chéo ~11 ô). Không chặn thì ô Băng +1,
	# perk +1, Hàng Long +1, ★3 +1, Chân Đế Xoay +1 cộng dồn lên tới +5 và mọi
	# tháp lại phủ trọn bàn — đúng cái vừa sửa ở bảng chỉ số.
	current_range = mini(MAX_EFFECTIVE_RANGE,
		stats.attack_range + total_rng + _star_range_bonus)

# ==========================================================================
# NGUYÊN TỐ (đến từ Ô, không từ loại tháp — xem futureplan.md §2)
# ==========================================================================

## Nguyên tố ghi đè. Hai nguồn TÁCH RIÊNG: gỡ trang bị không được xoá nguyên tố
## thuốc đang chạy, và ngược lại. Rỗng cả hai = dùng nguyên tố của ô đang đứng.
var _equip_element: String = ""
var _potion_element: String = ""
## Nguyên tố phụ — trang bị "Dual Vessel" cho phép gắn 2 Dấu mỗi đòn.
var element_secondary: String = ""
## Hệ số khuếch đại phản ứng do tháp này kích. TỔNG HỢP — đừng gán thẳng,
## gọi `_refresh_element_mults()` sau khi đổi một trong ba nguồn dưới.
var reaction_power_mult: float = 1.0
## Hệ số kéo dài Dấu tháp này gắn (nhân). Tổng hợp — xem trên.
var mark_duration_mult: float = 1.0
## Số giây cộng THẲNG vào thời hạn Dấu (thưởng cấp Ô nguyên tố Lv2/Lv3).
var mark_duration_bonus: float = 0.0

# Ba nguồn của hệ số nguyên tố, giữ riêng để nguồn này đổi không xoá nguồn kia:
var _equip_reaction_mult: float = 1.0   # trang bị 2 ô
var _equip_mark_mult: float = 1.0
var _tile_reaction_mult: float = 1.0    # cấp Ô nguyên tố + hình thế Tứ Trụ
# (nguồn thứ ba là GameManager.global_reaction_mult — di vật, đọc trực tiếp)

## Tính lại `reaction_power_mult` / `mark_duration_mult` từ mọi nguồn.
## Nhân chứ không cộng: mỗi nguồn là một "lớp khuếch đại" độc lập, và
## ReactionTable đã kẹp trần DAMAGE_MULT_CAP nên không sợ nhân vô hạn.
func _refresh_element_mults() -> void:
	var global_mult := 1.0
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm != null:
		var value: Variant = gm.get("global_reaction_mult")
		if value is int or value is float:
			global_mult = maxf(0.0, float(value))
	reaction_power_mult = maxf(0.1, _equip_reaction_mult * _tile_reaction_mult * global_mult)
	mark_duration_mult  = maxf(0.1, _equip_mark_mult)

## Nguyên tố hiện tại của tháp. Ưu tiên: override (thuốc/trang bị) → ô đang đứng.
## Tháp trên ô thường trả về "" và đánh vật lý thuần — đúng thiết kế, KHÔNG phải lỗi.
func current_element() -> String:
	# Ưu tiên: thuốc (tạm, người chơi chủ động) → trang bị (bền) → ô đang đứng.
	if ElementTypes.is_valid(_potion_element):
		return _potion_element
	if ElementTypes.is_valid(_equip_element):
		return _equip_element
	var gc := _find_grid_controller()
	if gc == null or not gc.has_method("get_element_at"):
		return ElementTypes.NONE
	var cell := GridUtil.world_to_cell(global_position)
	var own := str(gc.get_element_at(cell))
	if ElementTypes.is_valid(own):
		return own
	# Trận Vòng: ô giữa là ô THƯỜNG, tháp ở đó mượn nguyên tố của 4 ô bao quanh.
	if ElementTypes.is_valid(formation_ring_element):
		return formation_ring_element
	# Ống Dẫn Mạch: đứng ô thường vẫn hút nguyên tố của ô KỀ. Chỉ chạy khi ô dưới
	# chân trống nên tháp có trang bị này vẫn ưu tiên ô của chính nó.
	if equip_conduit:
		return _neighbour_element(gc, cell, "")
	return ElementTypes.NONE

# ── Hình thế (futureplan §2.3) ────────────────────────────────────────────
## Song Cực: nhịp tự kích phản ứng (giây). 0 = không thuộc hình thế này.
var formation_auto_interval: float = 0.0
## Nguyên tố của ô đối cực — Dấu thứ hai cần để nổ phản ứng.
var formation_pole_partner: String = ""
## Trận Vòng: nguyên tố của vòng vây (tháp đứng ô giữa mượn dùng).
var formation_ring_element: String = ""

var _auto_reaction_timer: float = 0.0

## Song Cực tự bắn HAI Dấu (của mình + của cực kia) vào địch gần nhất trong tầm,
## đủ để ElementMarks tự nổ phản ứng. Không tự tính sát thương ở đây — mọi con
## đường đều phải đi qua ReactionTable, nếu không sẽ có hai bảng cân bằng.
func _tick_auto_reaction(delta: float) -> void:
	if formation_auto_interval <= 0.0:
		return
	var own := current_element()
	if not ElementTypes.is_valid(own) or not ElementTypes.is_valid(formation_pole_partner):
		return
	_auto_reaction_timer += delta
	if _auto_reaction_timer < formation_auto_interval:
		return
	_auto_reaction_timer = 0.0

	var victim: Enemy = null
	var best := INF
	for enemy in targets_in_range:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < best:
			best = dist
			victim = enemy
	if victim == null or not victim.has_method("apply_element"):
		return
	# Cực kia TRƯỚC, của mình SAU: Dấu thứ hai mới là cái kích nổ, và ta muốn
	# nguồn phản ứng ghi nhận là THÁP NÀY để mọi hệ số của nó được tính vào.
	victim.apply_element(formation_pole_partner, self, mark_duration_mult, mark_duration_bonus)
	if is_instance_valid(victim):
		victim.apply_element(own, self, mark_duration_mult, mark_duration_bonus)

## Dấu PHỤ gắn kèm mỗi đòn. Trang bị cố định thắng; nếu không, Bình Chứa Kép
## lấy nguyên tố của ô kề KHÁC nguyên tố ô đang đứng → tháp tự kích phản ứng.
func current_element_secondary() -> String:
	if ElementTypes.is_valid(element_secondary):
		return element_secondary
	if not equip_dual_vessel:
		return ElementTypes.NONE
	var gc := _find_grid_controller()
	if gc == null or not gc.has_method("get_element_at"):
		return ElementTypes.NONE
	return _neighbour_element(gc, GridUtil.world_to_cell(global_position), current_element())

## Nguyên tố của ô kề trực giao đầu tiên khác `exclude`. Thứ tự cố định
## (bắc → nam → tây → đông) để kết quả deterministic, không nhấp nháy mỗi đòn.
func _neighbour_element(gc: Node, cell: Vector2i, exclude: String) -> String:
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var found := str(gc.get_element_at(cell + offset))
		if ElementTypes.is_valid(found) and found != exclude:
			return found
	return ElementTypes.NONE

## Thưởng theo CẤP ô nguyên tố dưới chân (Lv3 Long Mạch: +15% sát thương).
## Gọi lúc đặt tháp và mỗi khi ô được nâng cấp (TerritoryManager gọi lại).
func refresh_tile_element_bonus() -> void:
	if not stats:
		return
	var gc := _find_grid_controller()
	if gc == null or not gc.has_method("get_element_bonus"):
		return
	var bonus: Dictionary = gc.get_element_bonus(GridUtil.world_to_cell(global_position))

	# Thưởng phi-sát-thương của ô: khuếch đại phản ứng, kéo dài Dấu, +tầm (Hàng Long).
	_tile_reaction_mult = maxf(0.1, float(bonus.get("reaction_mult", 1.0)))
	mark_duration_bonus = maxf(0.0, float(bonus.get("mark_duration_bonus", 0.0)))
	_refresh_element_mults()

	# Hình thế: Song Cực (tự kích phản ứng theo nhịp) và Trận Vòng (ô giữa là ô
	# THƯỜNG nhưng mượn nguyên tố của vòng vây).
	formation_auto_interval = maxf(0.0, float(bonus.get("auto_reaction_interval", 0.0)))
	formation_pole_partner  = str(bonus.get("pole_partner", ""))
	formation_ring_element  = str(bonus.get("ring_element", ""))
	if formation_auto_interval <= 0.0:
		_auto_reaction_timer = 0.0
	# Đặt SAU khi formation_ring_element đã cập nhật: current_element() đọc nó.
	_refresh_element_ring()
	# +tầm đi qua BuffLayer.TILE_ELEMENT như mọi buff khác nên recalculate_stats
	# không xoá mất nó. _set_buff_layer ở cuối hàm ghi cả 3 giá trị một lần.
	var range_bonus: int = int(bonus.get("range_bonus", 0))

	var pct: float = float(bonus.get("tower_damage_pct", 0.0))
	# Di vật "Primal Heart" — đủ 6 nguyên tố trên bàn thì MỌI tháp +30%,
	# kể cả tháp không đứng ô nguyên tố. Đi chung lớp TILE_ELEMENT vì cùng nhịp
	# làm mới (mỗi lần bố cục ô thay đổi).
	pct += _primal_heart_pct()
	# Perk "Pure Steel": phần thưởng cho tháp CỐ Ý không đứng ô nguyên tố.
	# Đọc `current_element()` chứ không đọc ô: tháp có Trượng Nguyên Tố vẫn bắn
	# nguyên tố dù đứng ô thường, nên không được ăn phần thưởng này.
	if not ElementTypes.is_valid(current_element()):
		var gm_phys := get_node_or_null("/root/GameManagerSingleton")
		if gm_phys != null:
			var flat: Variant = gm_phys.get("perk_no_element_damage")
			if flat is int or flat is float:
				pct += maxf(0.0, float(flat))
	if is_zero_approx(pct) and range_bonus == 0:
		_clear_buff_layer(BuffLayer.TILE_ELEMENT)
		return
	# % của base — cùng quy ước với synergy, để không nhân chồng với sao/season.
	_set_buff_layer(BuffLayer.TILE_ELEMENT, stats.base_damage * pct, 0.0, range_bonus)

## % sát thương từ "Primal Heart" — 0 nếu chưa đủ 6 nguyên tố trên bàn.
func _primal_heart_pct() -> float:
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm == null:
		return 0.0
	var pct: Variant = gm.get("relic_all_elements_pct")
	if not (pct is int or pct is float) or float(pct) <= 0.0:
		return 0.0
	var host := get_parent()
	if host == null:
		return 0.0
	var tm: Variant = host.get("territory_manager")
	if not (tm is Node) or not (tm as Node).has_method("distinct_element_count"):
		return 0.0
	if int((tm as Node).call("distinct_element_count")) < ElementTypes.ALL.size():
		return 0.0
	return float(pct)

# ── Vòng nguyên tố dưới chân tháp ─────────────────────────────────────────
# Nguyên tố đến từ Ô, nên nhìn tháp KHÔNG đoán được nó bắn Dấu gì — phải nhớ
# ô nào đang ở dưới nó. Vòng sáng này biến thông tin đó thành thứ liếc là thấy,
# và nó theo `current_element()` nên trang bị ép nguyên tố cũng hiện đúng.
const ELEMENT_RING_Y: float = 0.14
const ELEMENT_RING_INNER: float = 0.33
const ELEMENT_RING_OUTER: float = 0.46

var _element_ring: MeshInstance3D = null
var _element_ring_shown: String = ""

func _refresh_element_ring() -> void:
	var element := current_element()
	if element == _element_ring_shown:
		return
	_element_ring_shown = element

	if not ElementTypes.is_valid(element):
		if is_instance_valid(_element_ring):
			_element_ring.queue_free()
		_element_ring = null
		return

	if not is_instance_valid(_element_ring):
		var torus := TorusMesh.new()
		torus.inner_radius = ELEMENT_RING_INNER
		torus.outer_radius = ELEMENT_RING_OUTER
		_element_ring = MeshInstance3D.new()
		_element_ring.name = "ElementRing"
		_element_ring.mesh = torus
		# top_level: vòng nằm theo Ô chứ không theo model, nên không được thừa
		# hưởng scale/xoay của $Visual (model xoay theo mục tiêu mỗi frame).
		_element_ring.top_level = true
		add_child(_element_ring)
	_element_ring.global_position = Vector3(global_position.x, ELEMENT_RING_Y, global_position.z)

	var color: Color = ElementTypes.color_of(element)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.2
	# Không kiểm chiều sâu: vòng nằm sát mặt ô, ô Lv3 dày 0.10 sẽ cắt mất một phần.
	mat.no_depth_test = true
	_element_ring.material_override = mat

func _find_grid_controller() -> Node:
	var host := get_parent()
	if host == null:
		return null
	return host.get("grid_controller") if host.get("grid_controller") != null else null

# ── Trang bị (2 ô/tháp) ───────────────────────────────────────────────────
func apply_equipment_buff(data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.EQUIP,
		float(data.get("damage_flat", 0.0)),
		float(data.get("speed_bonus", 0.0)),
		int(data.get("range_bonus", 0)))
	_equip_reaction_mult = maxf(0.1, float(data.get("reaction_power_mult", 1.0)))
	_equip_mark_mult     = maxf(0.1, float(data.get("mark_duration_mult", 1.0)))
	element_secondary    = str(data.get("element_secondary", ""))
	# grant_element: trang bị "Element Staff" ép nguyên tố bất kể ô đang đứng.
	var forced := str(data.get("grant_element", ""))
	_equip_element = forced if ElementTypes.is_valid(forced) else ""
	equip_crit_bonus      = maxf(0.0, float(data.get("crit_bonus", 0.0)))
	equip_extra_projectiles = maxi(0, int(data.get("projectile_bonus", 0)))
	equip_pierce_armor    = bool(data.get("pierce_armor", false))
	equip_bonus_vs_full   = maxf(0.0, float(data.get("bonus_vs_full", 0.0)))
	equip_bonus_vs_low    = maxf(0.0, float(data.get("bonus_vs_low", 0.0)))
	equip_bonus_vs_marked = maxf(0.0, float(data.get("bonus_vs_marked", 0.0)))
	equip_stun_chance     = clampf(float(data.get("stun_chance", 0.0)), 0.0, 1.0)
	equip_pierce_targets  = maxi(0, int(data.get("pierce_targets", 0)))
	equip_lifesteal       = maxi(0, int(data.get("lifesteal", 0)))
	equip_reaction_radius_bonus = maxf(0.0, float(data.get("reaction_radius_bonus", 0.0)))
	equip_cooldown_refund = maxf(0.0, float(data.get("cooldown_refund", 0.0)))
	equip_immune_disable  = bool(data.get("immune_disable", false))
	equip_conduit         = bool(data.get("conduit", false))
	equip_dual_vessel     = bool(data.get("dual_vessel", false))
	_refresh_element_mults()

func clear_equipment_buff() -> void:
	_clear_buff_layer(BuffLayer.EQUIP)
	_equip_reaction_mult = 1.0
	_equip_mark_mult     = 1.0
	element_secondary    = ""
	_equip_element       = ""
	equip_crit_bonus     = 0.0
	equip_extra_projectiles = 0
	equip_pierce_armor   = false
	equip_bonus_vs_full  = 0.0
	equip_bonus_vs_low   = 0.0
	equip_bonus_vs_marked = 0.0
	equip_stun_chance    = 0.0
	equip_pierce_targets = 0
	equip_lifesteal      = 0
	equip_reaction_radius_bonus = 0.0
	equip_cooldown_refund = 0.0
	equip_immune_disable = false
	equip_conduit        = false
	equip_dual_vessel    = false
	_refresh_element_mults()

# Cờ/số liệu trang bị mà projectile và ReactionTable đọc qua `get()`.
# Để dạng biến public thay vì dict: `get("ten")` trên Node trả null khi thiếu,
# nên bên đọc chỉ cần một guard kiểu là xong — rẻ hơn tra dict mỗi viên đạn.
var equip_crit_bonus: float = 0.0
var equip_extra_projectiles: int = 0
var equip_pierce_armor: bool = false
var equip_bonus_vs_full: float = 0.0     # Cây Lao Săn
var equip_bonus_vs_low: float = 0.0      # Chuỳ Kết Liễu
var equip_bonus_vs_marked: float = 0.0   # Hộ Phù Thợ Săn
var equip_stun_chance: float = 0.0       # Búa Chấn Động
var equip_pierce_targets: int = 0        # Cung Xuyên Táo
var equip_lifesteal: int = 0             # Kiếm Hút Máu
var equip_reaction_radius_bonus: float = 0.0  # Mắt Bão
var equip_cooldown_refund: float = 0.0   # Đồng Hồ Ngược
var equip_immune_disable: bool = false   # Bệ Đá Vững
var equip_conduit: bool = false          # Ống Dẫn Mạch
var equip_dual_vessel: bool = false      # Bình Chứa Kép

## Rút ngắn thời gian hồi chiêu đang chạy (Đồng Hồ Ngược, gọi từ ReactionTable).
func refund_cooldown(seconds: float) -> void:
	if seconds <= 0.0 or cooldown_timer == null or cooldown_timer.is_stopped():
		return
	var left := cooldown_timer.time_left - seconds
	if left <= 0.0:
		cooldown_timer.stop()
		_on_cooldown_timeout()
	else:
		cooldown_timer.start(left)

## Projectile báo về khi đòn của tháp này hạ được địch (Kiếm Hút Máu).
func on_kill_confirmed() -> void:
	if equip_lifesteal <= 0:
		return
	var host := get_parent()
	if host != null and host.has_method("equipment_lifesteal_heal"):
		host.call("equipment_lifesteal_heal", equip_lifesteal)

# ── Thuốc vùng (tạm thời) ─────────────────────────────────────────────────
## Thuốc buff tháp trong vùng. `duration` giây rồi tự gỡ.
## Gọi chồng sẽ LÀM MỚI thời hạn thay vì cộng dồn (tránh stack vô hạn).
func apply_potion_buff(data: Dictionary, duration: float) -> void:
	_set_buff_layer(BuffLayer.POTION,
		float(data.get("damage_flat", 0.0)),
		float(data.get("speed_bonus", 0.0)),
		int(data.get("range_bonus", 0)))
	var elem: String = str(data.get("grant_element", ""))
	if ElementTypes.is_valid(elem):
		_potion_element = elem
	# Bùa Đa Thủ / Tinh Dầu Xuyên Giáp — không đụng `stats` (Resource dùng chung
	# giữa mọi tháp cùng loại), chỉ ghi vào biến runtime của instance này.
	potion_extra_projectiles = maxi(0, int(data.get("projectile_bonus", 0)))
	potion_pierce_armor = bool(data.get("pierce_armor", false))
	_potion_token += 1
	var token := _potion_token
	var timer := get_tree().create_timer(maxf(0.1, duration))
	timer.timeout.connect(func():
		if is_instance_valid(self) and _potion_token == token:
			clear_potion_buff())

func clear_potion_buff() -> void:
	_clear_buff_layer(BuffLayer.POTION)
	_potion_element = ""
	potion_extra_projectiles = 0
	potion_pierce_armor = false

var _potion_token: int = 0
## Thuốc "Manyhands Charm": bắn thêm mấy mũi. Runtime-only, KHÔNG ghi vào stats.
var potion_extra_projectiles: int = 0
## Thuốc "Armor-Piercing Oil": đòn đánh bỏ qua giáp.
var potion_pierce_armor: bool = false

## Internal: write all three axes for one layer and recalculate.
func _set_buff_layer(layer: BuffLayer, dmg: float = 0.0, spd: float = 0.0, rng: int = 0) -> void:
	_dmg_bonus[layer] = dmg
	_spd_bonus[layer] = spd
	_rng_bonus[layer] = rng
	recalculate_stats()
	update_range_visual()

## Internal: remove a layer entirely and recalculate.
func _clear_buff_layer(layer: BuffLayer) -> void:
	_dmg_bonus.erase(layer)
	_spd_bonus.erase(layer)
	_rng_bonus.erase(layer)
	recalculate_stats()
	update_range_visual()

# ── Public buff API (same external signatures, cleaner internals) ──────────

func apply_upgrade(upgrade_data: Dictionary) -> void:
	if not upgrade_data:
		return
	_set_buff_layer(BuffLayer.UPGRADE,
		upgrade_data.get("damage_bonus", 0.0),
		upgrade_data.get("attack_speed_reduction", 0.0))

## Buff của Ô lãnh thổ. Nhận PHẦN TRĂM và quy ra tuyệt đối theo base của CHÍNH
## tháp này — nhờ vậy một ô có giá trị như nhau với mọi loại quân.
## Vẫn đọc `damage_bonus` / `attack_speed_reduction` để .tres hay JSON cũ (nếu có)
## không gãy; hai khoá đó cộng thẳng, dùng cho hiệu ứng cố ý phi tỉ lệ.
func apply_biome_buff(biome_data: Dictionary) -> void:
	var base_dmg: float = float(stats.base_damage) if stats else 0.0
	var base_cd: float = float(stats.attack_speed) if stats else 1.0
	var dmg: float = base_dmg * float(biome_data.get("damage_pct", 0.0)) 		+ float(biome_data.get("damage_bonus", 0))
	var spd: float = base_cd * float(biome_data.get("speed_pct", 0.0)) 		+ float(biome_data.get("attack_speed_reduction", 0.0))
	_set_buff_layer(BuffLayer.BIOME, dmg, spd, int(biome_data.get("range_bonus", 0)))

func apply_king_favor_buff(buff_data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.FAVOR,
		buff_data.get("damage_bonus", 0.0),
		buff_data.get("attack_speed_reduction", 0.0))

func apply_boon_buff(buff_data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.BOON,
		buff_data.get("damage_bonus", 0.0),
		buff_data.get("attack_speed_reduction", 0.0))

func remove_boon_buff() -> void:
	boon_burn_override = false
	_clear_buff_layer(BuffLayer.BOON)

func apply_aura_buff(buff_data: Dictionary) -> void:
	_set_buff_layer(BuffLayer.AURA,
		buff_data.get("damage_bonus", 0.0),
		buff_data.get("attack_speed_reduction", 0.0),
		int(buff_data.get("range_bonus", 0)))

func clear_aura_buff() -> void:
	_clear_buff_layer(BuffLayer.AURA)

func reset_cooldown() -> void:
	if cooldown_timer:
		cooldown_timer.stop()
	can_shoot = true

func apply_synergy_buff(buff_data: Dictionary) -> void:
	if not stats:
		return
	# Synergy bonus is expressed as percentage of base — convert to absolute here.
	_set_buff_layer(BuffLayer.SYNERGY,
		stats.base_damage  * buff_data.get("damage_bonus", 0.0),
		stats.attack_speed * buff_data.get("speed_bonus",  0.0),
		int(buff_data.get("range_bonus", 0.0)))

func apply_perk_buff(buff_data: Dictionary) -> void:
	if not stats:
		return
	# Perk: damage theo % của base, speed là giây trừ trực tiếp, range là số ô.
	_set_buff_layer(BuffLayer.PERK,
		stats.base_damage * buff_data.get("damage_bonus", 0.0),
		buff_data.get("speed_bonus", 0.0),
		int(buff_data.get("range_bonus", 0)))

func clear_perk_buff() -> void:
	_clear_buff_layer(BuffLayer.PERK)

## Khí hậu biome toàn bản đồ (BiomeEffects).
## dmg_pct   : % của base_damage (0.10 = +10%).
## spd_delta : GIÂY cộng vào thời gian hồi đòn — DƯƠNG nghĩa là bắn CHẬM hơn.
##             recalculate_stats() TRỪ _spd_bonus khỏi attack_speed nên phải
##             đảo dấu ở đây.
func apply_climate_buff(dmg_pct: float, spd_delta: float) -> void:
	if not stats:
		return
	_set_buff_layer(BuffLayer.BIOME_CLIMATE,
		stats.base_damage * dmg_pct,
		-spd_delta)

func clear_climate_buff() -> void:
	_clear_buff_layer(BuffLayer.BIOME_CLIMATE)

## Ô phước/nguyền: pct theo % của base damage (blessed +0.2 / cursed -0.15).
func apply_tile_buff(pct: float) -> void:
	if not stats:
		return
	if is_zero_approx(pct):
		_clear_buff_layer(BuffLayer.TILE)
		return
	_set_buff_layer(BuffLayer.TILE, stats.base_damage * pct)

func apply_season_buff(damage_mult: float, speed_penalty: float) -> void:
	season_damage_mult   = damage_mult
	season_speed_penalty = speed_penalty
	recalculate_stats()
	update_range_visual()

func update_range_visual() -> void:
	if not stats:
		return
	if not (collision_shape.shape is SphereShape3D):
		collision_shape.shape = SphereShape3D.new()
	# Area3D chỉ là LỌC THÔ: bán kính phải bao trọn mọi ô nước đi có thể vươn
	# tới, lọc tinh theo luật cờ nằm ở `_is_valid_target`. Mã nhảy tới ô cách
	# 2 ô theo Chebyshev nên sàn là 3.
	var range_to_use: int = maxi(3, effective_range())
	collision_shape.shape.radius = range_to_use * TILE_SIZE + (TILE_SIZE / 2.0)

# ==========================================================================
# OVERCHARGE (right-click magic — game_map trừ vàng rồi gọi overcharge())
# ==========================================================================

func is_overcharged() -> bool:
	return _overcharge_active

## Bắn nhanh gấp đôi trong `duration` giây. Bỏ qua nếu đang active.
func overcharge(duration: float = 5.0) -> void:
	if _overcharge_active or not is_inside_tree():
		return
	_overcharge_active = true
	_set_overcharge_visual(true)
	FX.spawn_burst(get_parent(), global_position + Vector3(0.0, 0.6, 0.0), OVERCHARGE_COLOR, 18, 1.1)
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("overcharge", -4.0)
	# Scene-tree timer tự giải phóng; nếu tower bị free trước timeout thì
	# connection tới object đã free không được gọi — an toàn.
	get_tree().create_timer(duration).timeout.connect(_end_overcharge)

func _end_overcharge() -> void:
	_overcharge_active = false
	_set_overcharge_visual(false)

## Emission pulse + tint cyan trên material per-instance (đã duplicate ở _build_visual).
func _set_overcharge_visual(active: bool) -> void:
	if active:
		_oc_emission_mats.clear()
		for mi in _mesh_instances:
			if is_instance_valid(mi) and mi.material_override is BaseMaterial3D:
				var m := mi.material_override as BaseMaterial3D
				m.albedo_color = OVERCHARGE_TINT
				if not m.emission_enabled:
					m.emission_enabled = true
					m.emission = OVERCHARGE_COLOR
					m.emission_energy_multiplier = 0.8
					_oc_emission_mats.append(m)
	else:
		# Chỉ tắt emission trên mats do overcharge bật — không phá material vốn phát sáng
		for m in _oc_emission_mats:
			if is_instance_valid(m):
				m.emission_enabled = false
		_oc_emission_mats.clear()
		for mi in _mesh_instances:
			if is_instance_valid(mi) and mi.material_override is BaseMaterial3D:
				(mi.material_override as BaseMaterial3D).albedo_color = Color.WHITE

# ==========================================================================
# COMBAT
# ==========================================================================

## Ô mà quân này đang phủ (toạ độ lưới). Dùng cho vẽ tầm, cho hệ thế cờ và cho
## bảng Nền × Bội.
##
## HIỆU NĂNG: đây là bảng TRA, không phải phép kiểm. Kiểm `ChessPattern.covers`
## cho từng địch mỗi frame là O(tháp × địch) — 100 tháp × 50 địch = 5000 lượt
## quét mỗi frame. Dựng sẵn tập ô rồi tra Dictionary là O(1).
var covered_cells: Array[Vector2i] = []
var _covered_lookup: Dictionary = {}
var _home_cell: Vector2i = Vector2i(-9999, -9999)

## Bảng ô có quân, DÙNG CHUNG cho mọi tháp. Chỉ dựng lại khi bố cục bàn đổi
## (đặt/gỡ/ghép quân) — `bump_layout()` là điểm vào duy nhất.
static var _blocked_shared: Dictionary = {}
static var _layout_version: int = 0
var _coverage_version: int = -1


## game_map gọi sau mỗi lần bàn cờ đổi bố cục. Mọi tháp sẽ tự dựng lại tầm phủ
## ở frame kế — đường trượt của Xe/Tượng/Hậu phụ thuộc quân đứng chắn nên
## thêm một quân là đổi tầm của cả hàng.
static func bump_layout(tree: SceneTree) -> void:
	_blocked_shared = {}
	if tree == null:
		return
	for t in tree.get_nodes_in_group("towers"):
		if is_instance_valid(t) and t.has_method("home_cell"):
			_blocked_shared[t.home_cell()] = true
	_layout_version += 1


## Ô của chính tháp này (cache — `world_to_cell` bị gọi rất nhiều).
func home_cell() -> Vector2i:
	if _home_cell.x < -9000:
		_home_cell = GridUtil.world_to_cell(global_position)
	return _home_cell


## Kiểu nước đi của quân (đọc từ .tres, mặc định toả tròn cho quân chưa khai).
func pattern_kind() -> int:
	if stats == null:
		return ChessPattern.Kind.RADIAL
	var base_kind: int = int(stats.attack_pattern)
	var gm_k := get_node_or_null("/root/GameManagerSingleton")
	if gm_k == null:
		return base_kind
	# Di vật đổi LUẬT nước đi. Thứ tự ưu tiên: ★3 > loại quân > gốc.
	# -1 nghĩa "không đổi" — KHÔNG dùng 0 vì 0 là Kind.ROOK hợp lệ.
	if int(star) >= 3 and int(gm_k.relic_star3_pattern) >= 0:
		return int(gm_k.relic_star3_pattern)
	if base_kind == ChessPattern.Kind.PAWN and int(gm_k.relic_pawn_pattern) >= 0:
		return int(gm_k.relic_pawn_pattern)
	if base_kind == ChessPattern.Kind.ROOK and bool(gm_k.relic_rook_as_cannon):
		return ChessPattern.Kind.CANNON
	return base_kind


func effective_range() -> int:
	if current_range > 0:
		return current_range
	return stats.attack_range if stats else 1


## Dựng lại tập ô phủ. Rẻ, nhưng chỉ chạy khi `_layout_version` đổi.
func refresh_coverage() -> void:
	_home_cell = Vector2i(-9999, -9999)
	var blocked := _blocked_shared.duplicate()
	blocked.erase(home_cell())        # ô của chính mình không tự chặn mình
	# Di vật xuyên quân: đường trượt đi qua ĐÚNG N quân của mình rồi mới dừng.
	# KHÔNG xoá sạch `blocked` — làm vậy là gỡ hẳn ràng buộc, mà chặn đường trượt
	# chính là thứ biến việc đặt quân thành câu đố. Xuyên N là NỚI, không phải XOÁ.
	var gm_r := get_node_or_null("/root/GameManagerSingleton")
	var pierce: int = int(gm_r.relic_pierce_count) if gm_r != null else 0
	covered_cells = ChessPattern.cells(pattern_kind(), home_cell(),
		effective_range(), blocked, pierce)
	# Di vật "Horseshoe": Mã nhảy thêm một vòng chữ L xa hơn (±1,±3 / ±3,±1).
	if pattern_kind() == ChessPattern.Kind.KNIGHT and gm_r != null 			and int(gm_r.relic_knight_reach) > 0:
		for st in ChessPattern.KNIGHT_FAR:
			var c2: Vector2i = home_cell() + st
			if not blocked.has(c2) and not covered_cells.has(c2):
				covered_cells.append(c2)
	_covered_lookup = {}
	for c in covered_cells:
		_covered_lookup[c] = true
	_coverage_version = _layout_version
	update_range_visual()


## Rival King "The Mute King"/"The Choked King" khoá hẳn một kiểu nước đi trong wave của hắn.
## Kiểm ở đây chứ không xoá mục tiêu: tháp vẫn ngắm, vẫn xoay, chỉ không nhả đạn
## — người chơi thấy ngay quân nào đang bị khoá thay vì tưởng game hỏng.
func _silenced_by_king() -> bool:
	var kr := get_node_or_null("/root/GameMap/KingRules")
	if kr == null:
		return false
	return bool(kr.call("silences", pattern_kind()))


## Quân này có phủ ô `cell` không. Điểm vào cho BoardScore và overlay tầm.
func covers_cell(cell: Vector2i) -> bool:
	if pattern_kind() == ChessPattern.Kind.RADIAL:
		var d := cell - home_cell()
		return maxi(absi(d.x), absi(d.y)) <= effective_range()
	if _coverage_version != _layout_version:
		refresh_coverage()
	return _covered_lookup.has(cell)


## Địch còn sống VÀ đứng trên ô quân này phủ.
func _is_valid_target(e) -> bool:
	if not is_instance_valid(e):
		return false
	if pattern_kind() == ChessPattern.Kind.RADIAL:
		return true          # quân chưa khai nước đi → giữ hành vi bán kính cũ
	if _coverage_version != _layout_version:
		refresh_coverage()
	return _covered_lookup.has(GridUtil.world_to_cell(e.global_position))


## Số quân của mình mà đường trượt xuyên qua được (di vật). 0 = luật cờ chuẩn.
func pierce_count() -> int:
	var gm_p := get_node_or_null("/root/GameManagerSingleton")
	return int(gm_p.relic_pierce_count) if gm_p != null else 0


func update_target() -> void:
	var valid: Array[Enemy] = []
	for e in _in_area:
		if _is_valid_target(e):
			valid.append(e)
	targets_in_range = valid
	if targets_in_range.is_empty():
		current_target = null
		return
	match target_mode:
		TargetMode.STRONGEST:
			current_target = _pick_by_hp(true)
		TargetMode.WEAKEST:
			current_target = _pick_by_hp(false)
		TargetMode.CLOSEST:
			current_target = _pick_closest()
		_:
			current_target = targets_in_range[0]

## Quái có current_hp cao nhất (highest = true) hoặc thấp nhất.
func _pick_by_hp(highest: bool) -> Enemy:
	var best: Enemy = null
	var best_hp: int = 0
	for e in targets_in_range:
		if not is_instance_valid(e):
			continue
		var hp: int = e.current_hp
		if best == null or (hp > best_hp if highest else hp < best_hp):
			best    = e
			best_hp = hp
	return best

## Quái gần tháp nhất (khoảng cách phẳng, bỏ qua trục Y).
func _pick_closest() -> Enemy:
	var best: Enemy = null
	var best_dist: float = 0.0
	for e in targets_in_range:
		if not is_instance_valid(e):
			continue
		var d: Vector3 = e.global_position - global_position
		d.y = 0.0
		var dist_sq: float = d.length_squared()
		if best == null or dist_sq < best_dist:
			best      = e
			best_dist = dist_sq
	return best

## Đổi sang chế độ ưu tiên kế tiếp. Trả về mode mới (UI có thể hiển thị sau).
func cycle_target_mode() -> int:
	target_mode = (target_mode + 1) % TargetMode.size()
	update_target()
	return target_mode

## Nhãn tiếng Việt của mode hiện tại — dành cho UI/tooltip.
func get_target_mode_label() -> String:
	return TARGET_MODE_LABELS[clampi(target_mode, 0, TARGET_MODE_LABELS.size() - 1)]

func shoot() -> void:
	can_shoot = false
	# Các mode khác FIRST cần đánh giá lại mỗi loạt bắn, nếu không tháp sẽ bám
	# mãi một mục tiêu cho tới khi nó chết/ra khỏi tầm.
	if target_mode != TargetMode.FIRST and targets_in_range.size() > 1:
		update_target()
	# +potion_extra_projectiles: thuốc Bùa Đa Thủ. Cộng ở đây chứ KHÔNG sửa
	# stats.projectile_count — stats là Resource dùng chung giữa mọi tháp cùng loại.
	var count: int = (stats.projectile_count if stats else 1) 		+ potion_extra_projectiles + equip_extra_projectiles
	var used_targets: Array = []

	for i in count:
		var tgt: Enemy = null
		# Viên đầu bám current_target khi dùng ưu tiên đặc biệt; mode FIRST giữ
		# nguyên luồng cũ (duyệt targets_in_range theo thứ tự vào tầm).
		if i == 0 and target_mode != TargetMode.FIRST \
				and is_instance_valid(current_target) and not used_targets.has(current_target):
			tgt = current_target
		if tgt == null:
			for candidate in targets_in_range:
				if is_instance_valid(candidate) and not used_targets.has(candidate):
					tgt = candidate
					break
		if tgt == null:
			tgt = current_target
		if not is_instance_valid(tgt):
			break
		used_targets.append(tgt)
		_fire_projectile(tgt)

	_play_recoil()
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("shoot", -9.0)
	# Overcharge: cooldown giảm một nửa khi active
	cooldown_timer.start(current_attack_speed * (OVERCHARGE_COOLDOWN_MULT if _overcharge_active else 1.0))

## Recoil nhẹ khi bắn — squash rồi bật lại.
func _play_recoil() -> void:
	if not visual or not is_inside_tree():
		return
	if _visual_tween and _visual_tween.is_valid() and _visual_tween.is_running():
		return   # đừng cắt spawn pop / star-up pop / recoil đang chạy
	_visual_tween = create_tween()
	var base := _base_visual_scale()
	visual.scale = base * Vector3(1.08, 0.9, 1.08)
	_visual_tween.tween_property(visual, "scale", base, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _fire_projectile(tgt: Enemy) -> void:
	if not projectile_scene or not is_instance_valid(tgt):
		return
	var bullet = projectile_scene.instantiate()
	bullet.target = tgt
	bullet.damage = current_damage
	# Nguyên tố đến từ Ô tháp đang đứng (hoặc thuốc/trang bị ghi đè) — KHÔNG từ loại tháp.
	bullet.element = current_element()
	bullet.element_secondary = current_element_secondary()
	bullet.element_source = self
	bullet.pierce_armor = potion_pierce_armor or equip_pierce_armor
	if stats:
		bullet.color = PROJ_COLORS.get(stats.id, Color(1.0, 0.9, 0.5))
		# Đạn mang màu nguyên tố nếu có — nhìn là biết tháp đang "nạp" hệ gì
		if ElementTypes.is_valid(bullet.element):
			bullet.color = ElementTypes.color_of(bullet.element)
		bullet.slow_amount   = stats.slow_amount
		bullet.slow_duration = stats.slow_duration
		bullet.splash_radius = stats.splash_radius
		bullet.burn_dps      = stats.burn_dps
		bullet.burn_duration = stats.burn_duration
	# King Flame ability: grant burn on projectiles even if tower doesn't normally burn
	if boon_burn_override and bullet.burn_dps == 0:
		bullet.burn_dps      = 5
		bullet.burn_duration = 3.0
	# Ghi nhận sát thương tiềm năng cho bảng thống kê cuối run (nếu GameManager hỗ trợ).
	if stats:
		var gm = get_node_or_null("/root/GameManagerSingleton")
		if gm and gm.has_method("record_tower_damage"):
			gm.record_tower_damage(stats.id, current_damage)
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0)
	bullet.add_to_group("projectiles")

func _on_cooldown_timeout() -> void:
	can_shoot = true

# ==========================================================================
# COLLISION
# ==========================================================================

func _on_area_entered(area) -> void:
	# KHÔNG lọc theo nước đi ở đây. Địch chạm mép hình cầu lọc thô khi CHƯA đứng
	# trên ô được phủ — lọc lúc này thì nó bị loại vĩnh viễn, vì `area_entered`
	# chỉ bắn MỘT lần và địch không bao giờ "vào lại" nữa.
	# Đây là lỗi thật đã đo được: công thức báo dư 4× mà quái vẫn lọt.
	if area is Enemy and not _in_area.has(area):
		_in_area.append(area)

func _on_area_exited(area) -> void:
	if area is Enemy:
		_in_area.erase(area)
		targets_in_range.erase(area)
		if current_target == area:
			current_target = null
