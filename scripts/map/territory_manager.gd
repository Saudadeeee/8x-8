# res://scripts/map/territory_manager.gd
# Quản lý toàn bộ hệ thống Ô Nguyên Tố (trước đây gọi là Territory/Biome):
# placement, visual 3D, kho (stock), buff chỉ số, CẤP Ô và HÌNH THẾ.
#
# HAI LỚP TÁC DỤNG — độc lập, KHÔNG thay thế nhau (futureplan.md §2):
#   1. Buff chỉ số (cũ, vẫn nguyên): mỗi loại ô cộng damage / tốc đánh / tầm cho tháp
#      đứng trên nó, đi qua BuffLayer.BIOME. KHÔNG đổi một dòng nào của phần này.
#   2. Nguyên tố (mới): mỗi loại ô mang một `element` (ElementTypes). Tháp đứng trên ô
#      nào thì đòn đánh gắn DẤU của ô đó. Nguyên tố KHÔNG thuộc về loại tháp —
#      đặt quân ở đâu = chọn nguyên tố cho quân đó.
#
# BA CẤP Ô: Lv1 Mạch → Lv2 Nguồn → Lv3 Long Mạch. Nâng cấp bằng cách đặt ô CÙNG LOẠI
# lên ô cùng loại đã có (mượn đúng cảm giác merge ★ của tháp).
#
# Territory visual = MeshInstance3D box mỏng đặt trên mặt tile, TÂM LUÔN Ở y = TILE_Y
# (0.052) ở mọi cấp — bất biến của project, xem CLAUDE.md. Ô cấp cao chỉ DÀY hơn
# (nở đều 2 phía, đáy vẫn > 0) và phát sáng mạnh hơn.
#
# Được game_map.gd khởi tạo và làm con node.
extends Node
class_name TerritoryManager  # registered globally — dùng để type-check và access BIOME_STATS từ các file khác

# --- SIGNALS ---
signal territory_placed(pos: Vector2i, biome: String)
signal territories_changed(biome_counts: Dictionary)
signal stock_changed(stock: Dictionary)
## Bố cục ô nguyên tố vừa đổi → tập hình thế (Hàng Long / Tứ Trụ / Song Cực / Trận Vòng)
## đã được tính lại. Payload = kết quả thô của FormationDetector.detect().
signal formations_changed(data: Dictionary)

# --- CONSTANTS ---
const BIOME_KEYS: Array[String] = ["fire", "swamp", "ice", "forest", "desert", "thunder"]

## Mỗi entry gồm HAI nhóm field:
##   - Buff chỉ số: dùng PHẦN TRĂM (`damage_pct` / `speed_pct`), KHÔNG phải số cộng
##     phẳng. Cộng phẳng thưởng ngược cho quân rẻ: +6 dmg trên Pawn (base 12) là
##     +50%, trên Ballista (base 85) chỉ +7%. `tower.apply_biome_buff` quy phần
##     trăm ra tuyệt đối theo base của CHÍNH tháp đó.
##   - `element`: nguyên tố mà ô này cấp cho tháp đứng lên (khớp ElementTypes.*).
##     Viết literal thay vì `ElementTypes.FIRE` để dict hằng chắc chắn parse được;
##     `_verify_element_mapping()` trong setup() bắt lỗi lệch giá trị ngay khi chạy.
const BIOME_STATS: Dictionary = {
	"fire":    {"name": "Mạch Hoả",  "element": "fire",    "desc": "+25% Sát thương · Dấu Hoả",          "damage_pct": 0.25, "speed_pct": 0.00, "range_bonus": 0, "color": Color(0.9, 0.3, 0.05, 0.35)},
	"swamp":   {"name": "Mạch Thuỷ", "element": "water",   "desc": "−15% Hồi chiêu · Dấu Thuỷ",          "damage_pct": 0.00, "speed_pct": 0.15, "range_bonus": 0, "color": Color(0.2, 0.6, 0.1,  0.35)},
	"ice":     {"name": "Mạch Băng", "element": "ice",     "desc": "+1 Tầm bắn / +8% Sát thương · Dấu Băng", "damage_pct": 0.08, "speed_pct": 0.00, "range_bonus": 1, "color": Color(0.4, 0.7, 1.0,  0.35)},
	"forest":  {"name": "Mạch Độc",  "element": "poison",  "desc": "+12% Sát thương / −8% Hồi chiêu · Dấu Độc", "damage_pct": 0.12, "speed_pct": 0.08, "range_bonus": 0, "color": Color(0.15, 0.7, 0.1, 0.35)},
	"desert":  {"name": "Mạch Thổ",  "element": "earth",   "desc": "+18% Sát thương · Dấu Thổ",          "damage_pct": 0.18, "speed_pct": 0.00, "range_bonus": 0, "color": Color(0.9, 0.75, 0.2, 0.35)},
	"thunder": {"name": "Mạch Lôi",  "element": "thunder", "desc": "+10% Sát thương / +1 Tầm · Dấu Lôi", "damage_pct": 0.10, "speed_pct": 0.00, "range_bonus": 1, "color": Color(0.55, 0.25, 1.0, 0.35)},
}


## Ánh xạ ngược nguyên tố → khoá ô. Dùng khi hệ khác nói bằng "ngôn ngữ nguyên tố"
## (ví dụ ô miễn phí theo khí hậu vùng) còn kho lại keyed theo biome key.
const ELEMENT_TO_BIOME: Dictionary = {
	"fire":    "fire",
	"water":   "swamp",
	"ice":     "ice",
	"poison":  "forest",
	"earth":   "desert",
	"thunder": "thunder",
}

const TILE_HEIGHT: float = 0.04
const TILE_Y:      float = 0.052

# --- CONSTANTS: CẤP Ô (futureplan §2.2) ---
const MIN_TILE_LEVEL: int = 1
const MAX_TILE_LEVEL: int = 3
## Tên hiển thị theo cấp (index = level - 1).
const LEVEL_NAMES: Array[String] = ["Mạch", "Nguồn", "Long Mạch"]
## Phần thưởng cộng dồn theo cấp — DỮ LIỆU THUẦN, hệ Dấu/phản ứng tự đọc và áp.
##   mark_duration_bonus : cộng thêm bao nhiêu GIÂY vào thời gian tồn tại của Dấu
##   reaction_mult       : hệ số NHÂN vào sát thương/hiệu lực phản ứng
##   tower_damage_pct    : % sát thương cộng cho tháp đứng trên ô (chỉ Lv3)
const LEVEL_BONUS: Array[Dictionary] = [
	{"mark_duration_bonus": 0.0, "reaction_mult": 1.00, "tower_damage_pct": 0.00},
	{"mark_duration_bonus": 2.0, "reaction_mult": 1.25, "tower_damage_pct": 0.00},
	{"mark_duration_bonus": 4.0, "reaction_mult": 1.60, "tower_damage_pct": 0.15},
]
## Độ dày mesh theo cấp. Mesh nở ĐỀU hai phía quanh tâm y = TILE_Y = 0.052 ⇒ đáy của
## cấp dày nhất vẫn ở 0.052 − 0.10/2 = 0.002 > 0, không bao giờ đâm xuyên mặt tile (y = 0).
const LEVEL_THICKNESS: Array[float] = [TILE_HEIGHT, 0.07, 0.10]
## Cường độ phát sáng theo cấp — Lv1 hoàn toàn không glow (giữ nguyên hình ảnh cũ).
const LEVEL_EMISSION: Array[float] = [0.0, 0.25, 0.6]
## Viền sáng của ô cấp ≥ 2: tấm mỏng RỘNG hơn ô một chút, lòi ra thành vành sáng.
const RIM_OVERHANG: float = 0.06
const RIM_THICKNESS: float = 0.008

# --- REFS ---
var grid_controller: GridController = null
var _parent_node: Node3D = null  # game_map — nơi add_child visual

# --- STATE ---
var owned_tiles: Dictionary = {}       # Vector2i → true
var biome_tiles: Dictionary = {}       # Vector2i → biome_key String
## Vector2i → int (1..MAX_TILE_LEVEL). Ô có mặt trong `biome_tiles` LUÔN có mặt ở đây.
## PHẢI được rebase cùng các dict khác — xem rebase().
var tile_level: Dictionary = {}
## Kết quả FormationDetector.detect() gần nhất (khoá "cells" / "formations" / "groups").
var formations: Dictionary = {}
var _territory_stock: Dictionary = {}  # biome_key → int
var _territory_textures: Dictionary = {} # biome_key → Texture2D
var _territory_meshes: Dictionary = {}   # Vector2i → MeshInstance3D
var _territory_preview: MeshInstance3D = null
var _preview_material: StandardMaterial3D = null
var _preview_base_color: Color = Color(1, 1, 1, 0.8)
var _tile_box: BoxMesh = null
## level → BoxMesh (chia sẻ giữa mọi ô cùng cấp) và level → BoxMesh của viền sáng.
var _level_boxes: Array[BoxMesh] = []
var _rim_boxes: Array[BoxMesh] = []
## "biome|level" → StandardMaterial3D — không sinh material mới cho từng ô.
var _tile_materials: Dictionary = {}
var _rim_materials: Dictionary = {}    # biome_key → StandardMaterial3D (màu theo nguyên tố)
var _placement_mode: bool = false
var _pending_biome: String = ""

# --- SETUP ---
func setup(gc: GridController, parent: Node3D) -> void:
	grid_controller = gc
	_parent_node = parent
	_tile_box = BoxMesh.new()
	_tile_box.size = Vector3(1.0, TILE_HEIGHT, 1.0)
	_build_level_meshes()
	_verify_element_mapping()
	formations = FormationDetector.empty_result()
	_load_textures()
	_setup_preview()

## Mesh dùng chung cho từng cấp — tạo đúng một lần.
func _build_level_meshes() -> void:
	_level_boxes.clear()
	_rim_boxes.clear()
	for level in range(MIN_TILE_LEVEL, MAX_TILE_LEVEL + 1):
		var thickness: float = LEVEL_THICKNESS[level - 1]
		var box := BoxMesh.new()
		box.size = Vector3(1.0, thickness, 1.0)
		_level_boxes.append(box)
		var rim := BoxMesh.new()
		rim.size = Vector3(1.0 + RIM_OVERHANG, RIM_THICKNESS, 1.0 + RIM_OVERHANG)
		_rim_boxes.append(rim)

## Lưới an toàn: bảng ô → nguyên tố phải luôn khớp ElementTypes. Sai chính tả một chữ
## sẽ khiến tháp trên ô đó im lặng không gắn Dấu — rất khó truy, nên cảnh báo sớm.
func _verify_element_mapping() -> void:
	for key in BIOME_KEYS:
		var element: String = str((BIOME_STATS.get(key, {}) as Dictionary).get("element", ""))
		if not ElementTypes.is_valid(element):
			push_warning("TerritoryManager: ô '%s' ánh xạ tới nguyên tố không hợp lệ '%s'."
				% [key, element])
			continue
		if str(ELEMENT_TO_BIOME.get(element, "")) != key:
			push_warning("TerritoryManager: ELEMENT_TO_BIOME['%s'] không trỏ ngược về ô '%s'."
				% [element, key])

func _load_textures() -> void:
	for key in BIOME_KEYS:
		var path = "res://assets/tiles/territory_%s.png" % key
		if ResourceLoader.exists(path):
			_territory_textures[key] = load(path) as Texture2D
		else:
			var img = Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				_territory_textures[key] = ImageTexture.create_from_image(img)

func _setup_preview() -> void:
	_territory_preview = MeshInstance3D.new()
	_territory_preview.mesh = _tile_box
	_preview_material = _make_biome_material("", true)
	_territory_preview.material_override = _preview_material
	_territory_preview.visible = false
	_parent_node.add_child(_territory_preview)

## Material MỚI mỗi lần gọi — chỉ dùng cho preview (preview đổi albedo liên tục nên
## KHÔNG được chia sẻ). Ô thật đi qua _tile_material() có cache.
func _make_biome_material(biome: String, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	var tex: Texture2D = _territory_textures.get(biome, null)
	if tex:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.albedo_color = Color.WHITE
	else:
		var biome_color: Color = BIOME_STATS.get(biome, {}).get("color", Color(0.5, 0.5, 0.5, 0.5))
		mat.albedo_color = Color(biome_color.r, biome_color.g, biome_color.b, 1.0)
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

## Material của ô thật, cache theo (biome × cấp). Lv1 giống hệt bản cũ (không emission);
## Lv2/Lv3 thêm phát sáng màu NGUYÊN TỐ của ô để nhận ra ngay ô đã nâng cấp.
func _tile_material(biome: String, level: int) -> StandardMaterial3D:
	var lv: int = clampi(level, MIN_TILE_LEVEL, MAX_TILE_LEVEL)
	var key: String = "%s|%d" % [biome, lv]
	if _tile_materials.has(key):
		return _tile_materials[key]
	var mat := _make_biome_material(biome, false)
	var energy: float = LEVEL_EMISSION[lv - 1]
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = _element_glow(biome)
		mat.emission_energy_multiplier = energy
	_tile_materials[key] = mat
	return mat

## Material của vành sáng quanh ô cấp ≥ 2 — unshaded để luôn rực đúng màu nguyên tố.
func _rim_material(biome: String) -> StandardMaterial3D:
	if _rim_materials.has(biome):
		return _rim_materials[biome]
	var glow: Color = _element_glow(biome)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = glow
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = 1.0
	_rim_materials[biome] = mat
	return mat

## Màu phát sáng của một loại ô = màu nguyên tố của nó (fallback: màu ô cũ).
func _element_glow(biome: String) -> Color:
	var element: String = element_of_biome(biome)
	if ElementTypes.is_valid(element):
		return ElementTypes.color_of(element)
	var fallback: Color = BIOME_STATS.get(biome, {}).get("color", Color(1, 1, 1, 1))
	return Color(fallback.r, fallback.g, fallback.b, 1.0)

# --- KHỞI TẠO LÃNH THỔ ĐẦU GAME ---
func initialize(count: int, grid_data: Dictionary, km: KingManager, bottom_y: int = 4) -> void:
	var candidates: Array[Vector2i] = []
	for pos in grid_data.keys():
		if not (pos is Vector2i): continue
		var p := pos as Vector2i
		if p.y < bottom_y: continue
		if grid_data.get(p) == "path": continue
		candidates.append(p)
	candidates.shuffle()

	var given = 0
	var registered: Array[Vector2i] = []
	for pos in candidates:
		if given >= count:
			break
		var biome = BIOME_KEYS[randi() % BIOME_KEYS.size()]
		owned_tiles[pos] = true
		biome_tiles[pos] = biome
		tile_level[pos] = MIN_TILE_LEVEL
		_create_tile_visual(pos, biome, MIN_TILE_LEVEL)
		registered.append(pos)
		given += 1

	if km and registered.size() > 0:
		for pos in registered:
			var arr: Array[Vector2i] = [pos]
			km.register_territories(arr, biome_tiles[pos])

	_recompute_formations()
	_emit_territories_changed()

# --- STOCK ---
func add_stock(biome: String) -> void:
	_territory_stock[biome] = _territory_stock.get(biome, 0) + 1
	stock_changed.emit(_territory_stock.duplicate())

func get_stock(biome: String) -> int:
	return _territory_stock.get(biome, 0)

func get_all_stock() -> Dictionary:
	return _territory_stock.duplicate()

# --- PLACEMENT MODE ---
func select(biome_key: String) -> void:
	if _territory_stock.get(biome_key, 0) <= 0:
		return
	_placement_mode = true
	_pending_biome = biome_key
	if _territory_preview:
		_preview_material = _make_biome_material(biome_key, true)
		_preview_base_color = Color(
			_preview_material.albedo_color.r,
			_preview_material.albedo_color.g,
			_preview_material.albedo_color.b, 0.8)
		_preview_material.albedo_color = _preview_base_color
		_territory_preview.material_override = _preview_material
		_territory_preview.visible = true

func cancel() -> void:
	_placement_mode = false
	_pending_biome = ""
	if _territory_preview:
		_territory_preview.visible = false

func is_placing() -> bool:
	return _placement_mode

func get_pending_biome() -> String:
	return _pending_biome

## Cập nhật preview theo ô đang hover — game_map tính cell từ ray chuột và truyền vào.
func update_preview(cell: Vector2i, grid_data: Dictionary) -> void:
	if not _territory_preview or not _preview_material:
		return
	_territory_preview.position = GridUtil.cell_to_world(cell) + Vector3(0.0, TILE_Y, 0.0)
	if can_place_at(cell, grid_data, _pending_biome):
		_preview_material.albedo_color = _preview_base_color
	else:
		_preview_material.albedo_color = Color(1, 0.2, 0.2, 0.5)

func get_preview_node() -> MeshInstance3D:
	return _territory_preview

# --- ĐẶT / NÂNG CẤP Ô NGUYÊN TỐ ---
func try_place(pos: Vector2i, grid_data: Dictionary, km: KingManager) -> bool:
	if not can_place_at(pos, grid_data, _pending_biome):
		return false
	_place_at(pos, _pending_biome, grid_data, km)
	return true

## Ô này có đặt được ô nguyên tố loại `biome_key` không? O(1) — KHÔNG dựng lại
## danh sách ô trống như get_available_tiles (hàm này bị gọi mỗi lần chuột di chuyển).
## Hai trường hợp hợp lệ:
##   1. Ô trống (không path, chưa có ô nguyên tố) → đặt mới Lv1.
##   2. Ô đã có ô nguyên tố CÙNG LOẠI và chưa đạt Lv3 → nâng cấp.
## Ô khác loại → KHÔNG hợp lệ (giữ nguyên hành vi cũ, không âm thầm ghi đè).
func can_place_at(pos: Vector2i, grid_data: Dictionary, biome_key: String) -> bool:
	if biome_key == "" or not BIOME_STATS.has(biome_key):
		return false
	if grid_controller and not grid_controller.is_in_bounds(pos):
		return false
	var cell_entry = grid_data.get(pos)
	if cell_entry is String and cell_entry == "path":
		return false
	if not biome_tiles.has(pos):
		return true
	if str(biome_tiles[pos]) != biome_key:
		return false
	return get_tile_level(pos) < MAX_TILE_LEVEL

## Ô đã có ô nguyên tố cùng loại và còn nâng cấp được — dùng cho UI/overlay.
func is_upgrade_target(pos: Vector2i, biome_key: String) -> bool:
	return biome_tiles.has(pos) \
		and str(biome_tiles[pos]) == biome_key \
		and get_tile_level(pos) < MAX_TILE_LEVEL

## Toàn bộ ô đặt được cho một loại = ô trống + ô nâng cấp được.
## get_available_tiles() GIỮ NGUYÊN nghĩa cũ ("ô trống") để overlay_drawer không đổi.
func get_placeable_tiles(grid_data: Dictionary, biome_key: String) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	if not grid_controller:
		return results
	for x in range(grid_controller.grid_width):
		for y in range(grid_controller.grid_height):
			var p := Vector2i(x, y)
			if can_place_at(p, grid_data, biome_key):
				results.append(p)
	return results

## Báo cho tháp đang đứng trên ô `pos` đọc lại thưởng theo cấp ô (Lv3 +15% sát thương).
## Duyệt group thay vì giữ tham chiếu — TerritoryManager không sở hữu tháp.
func _refresh_tower_tile_bonus(pos: Vector2i) -> void:
	var want := GridUtil.cell_to_world(pos)
	for t in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(t) or not t.has_method("refresh_tile_element_bonus"):
			continue
		if t.global_position.distance_to(want) < 0.5:
			t.refresh_tile_element_bonus()
			return

## Đặt mới hoặc NÂNG CẤP tại `pos`. Gọi sau khi can_place_at() đã xác nhận hợp lệ.
func _place_at(pos: Vector2i, biome_key: String, _grid_data: Dictionary, km: KingManager) -> void:
	var existing: String = str(biome_tiles.get(pos, ""))
	var is_upgrade: bool = existing != "" and existing == biome_key
	var level: int = MIN_TILE_LEVEL

	if is_upgrade:
		level = mini(get_tile_level(pos) + 1, MAX_TILE_LEVEL)
		tile_level[pos] = level
		# KHÔNG gọi km.register_territories: số ô lãnh thổ không đổi, đăng ký lại chỉ
		# ghi đè cùng một entry — giữ im lặng cho rõ ý đồ.
	else:
		if existing != "" and existing != biome_key:
			push_warning("TerritoryManager: ô %s đã là '%s', không đặt đè '%s'."
				% [str(pos), existing, biome_key])
			return
		owned_tiles[pos] = true
		biome_tiles[pos] = biome_key
		tile_level[pos] = MIN_TILE_LEVEL
		if km:
			var arr: Array[Vector2i] = [pos]
			km.register_territories(arr, biome_key)

	_create_tile_visual(pos, biome_key, level)
	# Ô vừa lên cấp có thể đang có tháp đứng trên → cập nhật thưởng +% của Lv3 ngay,
	# nếu không tháp sẽ giữ chỉ số cũ tới khi bị recalculate vì lý do khác.
	_refresh_tower_tile_bonus(pos)

	# Cập nhật stock và placement mode
	_territory_stock[biome_key] = max(0, _territory_stock.get(biome_key, 0) - 1)
	if _territory_stock.get(biome_key, 0) > 0:
		if _territory_preview and _preview_material:
			_preview_material.albedo_color = _preview_base_color
			_territory_preview.visible = true
	else:
		cancel()

	_recompute_formations()
	territory_placed.emit(pos, biome_key)
	stock_changed.emit(_territory_stock.duplicate())
	_emit_territories_changed()

## Dọn lãnh thổ tại các ô bị đường mở rộng đè lên: xoá state + mesh, hoàn lại kho
## để player đặt chỗ khác (tương tự tháp bị đè được hoàn 50% vàng).
## Ô cấp cao hoàn ĐÚNG số ô đã bỏ vào (Lv3 = 3 ô) — nâng cấp không được phép mất trắng.
func remove_territories_at(cells: Array[Vector2i], km: KingManager = null) -> void:
	var refunded := 0
	for cell in cells:
		if not owned_tiles.has(cell):
			continue
		var biome: String = str(biome_tiles.get(cell, ""))
		var level: int = get_tile_level(cell)
		owned_tiles.erase(cell)
		biome_tiles.erase(cell)
		tile_level.erase(cell)
		var mesh = _territory_meshes.get(cell)
		if mesh and is_instance_valid(mesh):
			mesh.queue_free()
		_territory_meshes.erase(cell)
		if km and km.territory_map.has(cell):
			km.territory_map.erase(cell)
		if biome != "":
			_territory_stock[biome] = _territory_stock.get(biome, 0) + level
			refunded += level
	if refunded > 0:
		_recompute_formations()
		stock_changed.emit(_territory_stock.duplicate())
		_emit_territories_changed()

## Bán một ô nguyên tố — hoàn `SELL_REFUND_PCT` giá gốc theo CẤP ô (futureplan §6.6).
## Đây là lưới an toàn cho việc chuyển build: đi sai hướng ở wave 5 vẫn xoay được.
## Khác `remove_territories_at` (bị đường đè, hoàn về KHO), bán là đổi lấy VÀNG.
const SELL_REFUND_PCT: float = 0.6
## Giá vàng quy ước của một cấp ô — dùng để tính tiền hoàn.
const TILE_GOLD_VALUE: int = 50

func sell_tile_at(pos: Vector2i, km: KingManager = null) -> int:
	if not owned_tiles.has(pos):
		return 0
	var level: int = get_tile_level(pos)
	owned_tiles.erase(pos)
	biome_tiles.erase(pos)
	tile_level.erase(pos)
	var mesh = _territory_meshes.get(pos)
	if mesh and is_instance_valid(mesh):
		mesh.queue_free()
	_territory_meshes.erase(pos)
	if km and km.territory_map.has(pos):
		km.territory_map.erase(pos)

	_recompute_formations()
	_emit_territories_changed()

	# Tháp đứng trên ô vừa bán mất nguyên tố + thưởng cấp ô → phải làm mới ngay.
	if grid_controller and grid_controller.has_method("invalidate_element_cache"):
		grid_controller.invalidate_element_cache()
	_refresh_tower_tile_bonus(pos)

	var refund: int = int(round(float(TILE_GOLD_VALUE * level) * SELL_REFUND_PCT))
	var gm := get_node_or_null("/root/GameManagerSingleton")
	if gm != null and gm.has_method("add_gold") and refund > 0:
		gm.add_gold(refund)
	return refund

# --- QUERY ---
func get_available_tiles(grid_data: Dictionary) -> Array[Vector2i]:
	# Mọi ô trong grid trừ ô path và ô đã có biome.
	# Ô có tower vẫn hợp lệ (giống hành vi get_used_cells() của layer_grass cũ).
	# NGHĨA CŨ được giữ nguyên (chỉ ô TRỐNG) — muốn kèm ô nâng cấp thì dùng
	# get_placeable_tiles(grid_data, biome_key).
	var results: Array[Vector2i] = []
	if not grid_controller:
		return results
	for x in range(grid_controller.grid_width):
		for y in range(grid_controller.grid_height):
			var p := Vector2i(x, y)
			if grid_data.get(p) is String and grid_data.get(p) == "path": continue
			if biome_tiles.has(p): continue
			results.append(p)
	return results

func get_biome_at(pos: Vector2i) -> String:
	return biome_tiles.get(pos, "")

func has_biome_at(pos: Vector2i) -> bool:
	return biome_tiles.has(pos)

func get_biome_counts() -> Dictionary:
	var counts: Dictionary = {}
	for pos in biome_tiles:
		var b: String = biome_tiles[pos]
		counts[b] = counts.get(b, 0) + 1
	return counts

# ==========================================================================
# NGUYÊN TỐ — futureplan.md §2
# ==========================================================================

## Nguyên tố của một LOẠI ô ("fire" → ElementTypes.FIRE). "" nếu loại không hợp lệ.
static func element_of_biome(biome_key: String) -> String:
	return str((BIOME_STATS.get(biome_key, {}) as Dictionary).get("element", ElementTypes.NONE))

## Loại ô cấp một nguyên tố ("water" → "swamp"). "" nếu nguyên tố không hợp lệ.
static func biome_of_element(element: String) -> String:
	return str(ELEMENT_TO_BIOME.get(element, ""))

## Bản INSTANCE của biome_of_element. Tồn tại để hệ khác gọi qua duck-typing
## (has_method + call) mà không phải tham chiếu class TerritoryManager — tránh
## cyclic script reference (territory_manager.gd đã tham chiếu GridController).
func get_biome_for_element(element: String) -> String:
	return biome_of_element(element)

## Nguyên tố tại một Ô CỤ THỂ. Ô không có ô nguyên tố → ElementTypes.NONE ("").
## Đây là nguồn sự thật mà GridController.get_element_at() bọc lại cho tháp dùng.
func get_element_at(pos: Vector2i) -> String:
	if not biome_tiles.has(pos):
		return ElementTypes.NONE
	var element: String = element_of_biome(str(biome_tiles[pos]))
	return element if ElementTypes.is_valid(element) else ElementTypes.NONE

## Cấp của ô (1..3). Ô không có ô nguyên tố trả về 0 để phân biệt rõ với Lv1.
func get_tile_level(pos: Vector2i) -> int:
	if not biome_tiles.has(pos):
		return 0
	return clampi(int(tile_level.get(pos, MIN_TILE_LEVEL)), MIN_TILE_LEVEL, MAX_TILE_LEVEL)

## Tên đầy đủ của ô để hiển thị: "Mạch Hoả" / "Nguồn Hoả" / "Long Mạch Hoả".
func get_tile_display_name(pos: Vector2i) -> String:
	var level: int = get_tile_level(pos)
	if level <= 0:
		return ""
	var biome: String = str(biome_tiles.get(pos, ""))
	var element_name: String = ElementTypes.display_name(element_of_biome(biome))
	return "%s %s" % [LEVEL_NAMES[level - 1], element_name]

## Phần thưởng theo CẤP ô — dữ liệu thuần cho hệ Dấu/phản ứng đọc.
## Trả về bản SAO: `{mark_duration_bonus: float, reaction_mult: float, tower_damage_pct: float}`.
## Ô thường → giá trị trung tính (0 / 1.0 / 0).
## Gộp CẢ HAI nguồn thưởng của ô: cấp ô (Lv1-3) và hình thế (Hàng Long, Tứ Trụ…).
## Một điểm ra duy nhất để tháp chỉ phải gọi một hàm — thêm nguồn mới thì sửa ở đây.
func get_element_bonus(pos: Vector2i) -> Dictionary:
	var level: int = get_tile_level(pos)
	var out: Dictionary = LEVEL_BONUS[0].duplicate() if level <= 0 \
		else LEVEL_BONUS[level - 1].duplicate()

	var formation: Dictionary = get_formation_bonus(pos)
	# reaction_mult NHÂN (hai lớp khuếch đại độc lập), range_bonus CỘNG.
	out["reaction_mult"] = float(out.get("reaction_mult", 1.0)) \
		* float(formation.get("reaction_mult", 1.0))
	out["range_bonus"] = int(out.get("range_bonus", 0)) + int(formation.get("range_bonus", 0))
	# Chép NGUYÊN các khoá còn lại (auto_reaction_interval, pole_partner,
	# ring_element…). Không chép thì Song Cực / Trận Vòng phát hiện được nhưng
	# tháp không bao giờ nhận được dữ liệu để thực thi.
	for key in formation.keys():
		if key == "reaction_mult" or key == "range_bonus":
			continue
		out[key] = formation[key]
	return out

# ==========================================================================
# HÌNH THẾ — futureplan.md §2.3 (tính bằng FormationDetector, KHÔNG tự áp buff)
# ==========================================================================

## Danh sách id hình thế có phần thưởng áp lên THÁP ĐỨNG TRÊN ô này.
func get_formations_at(pos: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var cells = formations.get("cells")
	if not (cells is Dictionary):
		return out
	var ids = (cells as Dictionary).get(pos)
	if not (ids is Array):
		return out
	for id in (ids as Array):
		out.append(str(id))
	return out

## Toàn bộ kết quả detect gần nhất — bản SAO nông (khoá "cells"/"formations"/"groups").
func get_all_formations() -> Dictionary:
	return formations.duplicate()

## {id → số lượng hình thế}. Rỗng khi bàn chưa thành hình thế nào.
func get_formation_counts() -> Dictionary:
	var counts = formations.get("formations")
	return (counts as Dictionary).duplicate() if counts is Dictionary else {}

## Chi tiết từng hình thế (kèm ô thành phần, ô giữa của Trận Vòng...).
func get_formation_groups() -> Array:
	var groups = formations.get("groups")
	return (groups as Array) if groups is Array else []

## Gộp phần thưởng của MỌI hình thế đang áp lên ô này.
## `range_bonus` cộng dồn, `reaction_mult` nhân dồn — hệ tiêu thụ chỉ việc đọc.
func get_formation_bonus(pos: Vector2i) -> Dictionary:
	var total: Dictionary = {"range_bonus": 0, "reaction_mult": 1.0}
	for id in get_formations_at(pos):
		var bonus: Dictionary = FormationDetector.bonus_of(id)
		total["range_bonus"] = int(total["range_bonus"]) + int(bonus.get("range_bonus", 0))
		total["reaction_mult"] = float(total["reaction_mult"]) * float(bonus.get("reaction_mult", 1.0))
		for key in bonus.keys():
			if key == "range_bonus" or key == "reaction_mult":
				continue
			total[key] = bonus[key]
	_add_group_context(pos, total)
	return total

## Bổ sung dữ liệu chỉ có trong `groups` (bảng BONUS là hằng, không biết ô nào
## ghép với ô nào): nguyên tố của ô ĐỐI CỰC (Song Cực) và của vòng vây (Trận Vòng).
## Thiếu hai giá trị này thì tháp không biết phải gắn Dấu gì.
func _add_group_context(pos: Vector2i, total: Dictionary) -> void:
	var groups := get_formation_groups()
	for entry in groups:
		if not (entry is Dictionary):
			continue
		var group: Dictionary = entry
		var id := str(group.get("id", ""))
		var cells = group.get("cells")
		if not (cells is Array) or not (cells as Array).has(pos):
			continue
		if id == FormationDetector.DUAL_POLE:
			# Cực kia = vế còn lại của cặp so với nguyên tố của chính ô này.
			var own := _element_at_safe(pos)
			var a := str(group.get("element", ""))
			total["pole_partner"] = str(group.get("element_b", "")) if own == a else a
		elif id == FormationDetector.RING:
			total["ring_element"] = str(group.get("element", ""))

func _element_at_safe(pos: Vector2i) -> String:
	var found := get_element_at(pos)
	return found if found is String else ""

## Quét lại toàn bộ bố cục. Rẻ: FormationDetector duyệt theo SỐ Ô NGUYÊN TỐ đang có
## (thường < 30), không quét w×h. Gọi sau mọi thay đổi bố cục.
func _recompute_formations() -> void:
	var element_map: Dictionary = {}
	for pos in biome_tiles.keys():
		var element: String = element_of_biome(str(biome_tiles[pos]))
		if ElementTypes.is_valid(element):
			element_map[pos] = element
	var w: int = grid_controller.grid_width  if grid_controller else 0
	var h: int = grid_controller.grid_height if grid_controller else 0
	formations = FormationDetector.detect(element_map, w, h)
	# Đặt MỘT ô có thể tạo/phá hình thế ở ô khác (2×2, hàng 3, vòng) → phải làm mới
	# TOÀN BỘ tháp, không chỉ ô vừa đụng. Số tháp nhỏ (<50) nên quét thẳng là đủ rẻ.
	_refresh_all_tower_tile_bonus()
	formations_changed.emit(formations)

## Số nguyên tố KHÁC NHAU đang có trên bàn — di vật "Trái Tim Nguyên Sơ" đọc.
func distinct_element_count() -> int:
	var seen: Dictionary = {}
	for pos in biome_tiles.keys():
		var element: String = element_of_biome(str(biome_tiles[pos]))
		if ElementTypes.is_valid(element):
			seen[element] = true
	return seen.size()

func _refresh_all_tower_tile_bonus() -> void:
	if not is_inside_tree():
		return
	for t in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(t) and t.has_method("refresh_tile_element_bonus"):
			t.refresh_tile_element_bonus()

# --- VISUAL ---
## Dựng lại mesh của một ô. Gọi cả khi đặt mới lẫn khi nâng cấp (mesh cũ bị thay hẳn).
## BẤT BIẾN: tâm mesh LUÔN ở y = TILE_Y (0.052) ở MỌI cấp — ô dày hơn nở đều 2 phía nên
## đáy cấp 3 vẫn ở 0.002 > 0, không bao giờ đâm xuyên mặt tile grid (y = 0).
## Overlay quad (y = 0.06) vốn đã nằm trong bề dày ô từ bản Lv1 (0.032..0.072) và overlay
## chỉ vẽ trên ô TRỐNG, nên cấp cao không tạo xung đột mới.
func _create_tile_visual(pos: Vector2i, biome: String, level: int = MIN_TILE_LEVEL) -> void:
	# Xóa visual cũ nếu có (viền sáng là node CON nên được giải phóng cùng)
	if _territory_meshes.has(pos):
		var old = _territory_meshes[pos]
		if is_instance_valid(old):
			old.queue_free()
		_territory_meshes.erase(pos)

	var lv: int = clampi(level, MIN_TILE_LEVEL, MAX_TILE_LEVEL)
	var tile := MeshInstance3D.new()
	tile.mesh = _level_boxes[lv - 1] if _level_boxes.size() >= lv else _tile_box
	tile.material_override = _tile_material(biome, lv)
	tile.position = GridUtil.cell_to_world(pos) + Vector3(0.0, TILE_Y, 0.0)
	_parent_node.add_child(tile)
	_territory_meshes[pos] = tile

	if lv >= 2:
		_attach_rim(tile, biome, lv)

## Vành sáng màu nguyên tố quanh ô cấp ≥ 2. Là node CON của mesh ô ⇒ tự dịch theo
## khi rebase và tự bị free khi ô bị gỡ/nâng cấp.
func _attach_rim(tile: MeshInstance3D, biome: String, level: int) -> void:
	if _rim_boxes.size() < level:
		return
	var rim := MeshInstance3D.new()
	rim.mesh = _rim_boxes[level - 1]
	rim.material_override = _rim_material(biome)
	# Nằm sát mép trên của ô, hơi thụt xuống để không z-fight với mặt ô.
	rim.position = Vector3(0.0, LEVEL_THICKNESS[level - 1] / 2.0 - RIM_THICKNESS, 0.0)
	tile.add_child(rim)

# --- REBASE (bản đồ mở rộng về WEST/NORTH) ---

## GridController đã dịch toàn bộ toạ độ ô đi `delta` (xem GridController._rebase).
## Mọi state keyed theo cell + vị trí world của visual phải dịch theo.
## Dùng clear + nạp lại IN-PLACE để mọi reference bên ngoài vẫn trỏ đúng object.
func rebase(delta: Vector2i) -> void:
	if delta == Vector2i.ZERO:
		return
	_shift_keys_in_place(owned_tiles, delta)
	_shift_keys_in_place(biome_tiles, delta)
	# tile_level cũng keyed theo cell — bỏ sót sẽ làm mọi ô tụt về Lv1 sau khi map
	# mở về WEST/NORTH (get_tile_level fallback MIN_TILE_LEVEL).
	_shift_keys_in_place(tile_level, delta)

	var shifted: Dictionary = {}
	for key in _territory_meshes.keys():
		shifted[(key as Vector2i) + delta] = _territory_meshes[key]
	_territory_meshes.clear()
	for key in shifted.keys():
		var pos := key as Vector2i
		var mesh = shifted[key]
		_territory_meshes[pos] = mesh
		if mesh is MeshInstance3D and is_instance_valid(mesh):
			# Giữ nguyên cao độ hiện tại của mesh, chỉ dịch trên mặt XZ.
			var world: Vector3 = GridUtil.cell_to_world(pos)
			(mesh as MeshInstance3D).position = Vector3(world.x, (mesh as MeshInstance3D).position.y, world.z)

	# Hình thế keyed theo cell → phải tính lại trên hệ toạ độ MỚI.
	_recompute_formations()
	# GridController đã xoá cache nguyên tố trong _rebase() của nó, NHƯNG lúc đó dữ liệu
	# của ta còn ở hệ toạ độ cũ. Xoá lần nữa ở đây để không sót entry nào bị ghi lại
	# trong khoảng giữa hai bước.
	if grid_controller and grid_controller.has_method("invalidate_element_cache"):
		grid_controller.invalidate_element_cache()

## Dịch key Vector2i của dictionary — clear + nạp lại IN-PLACE (giữ nguyên object).
func _shift_keys_in_place(dict: Dictionary, delta: Vector2i) -> void:
	var shifted: Dictionary = {}
	for key in dict.keys():
		shifted[(key as Vector2i) + delta] = dict[key]
	dict.clear()
	for key in shifted.keys():
		dict[key] = shifted[key]

# --- CLEAR (khi tạo map mới) ---
func clear_all() -> void:
	for tile in _territory_meshes.values():
		if is_instance_valid(tile):
			tile.queue_free()
	_territory_meshes.clear()
	owned_tiles.clear()
	biome_tiles.clear()
	tile_level.clear()
	formations = FormationDetector.empty_result()
	formations_changed.emit(formations)
	cancel()

# --- HUD HELPERS ---
func _emit_territories_changed() -> void:
	territories_changed.emit(get_biome_counts())
