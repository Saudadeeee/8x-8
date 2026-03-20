# res://scripts/managers/EncounterManager.gd
# Quản lý hệ thống Random Encounter giữa các wave.
extends Node
class_name EncounterManager

signal encounter_resolved(choice: EncounterChoice)

@export var all_encounters: Array[Resource] = []

var current_encounter: EncounterData = null
var encounter_history: Array[String] = []

func _ready() -> void:
	_ensure_default_encounters()

# --- Điền encounter mặc định nếu rỗng ---
func _ensure_default_encounters() -> void:
	if all_encounters.size() > 0:
		return
	# Thử auto-load từ res://res/encounters/*.tres trước
	_load_encounters_from_directory()
	# Nếu không có .tres nào → dùng hardcoded defaults làm fallback
	if all_encounters.is_empty():
		all_encounters = _build_default_encounters()

func _load_encounters_from_directory() -> void:
	var dir = DirAccess.open("res://res/encounters/")
	if not dir:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var enc = load("res://res/encounters/" + file) as EncounterData
			if enc:
				all_encounters.append(enc)
		file = dir.get_next()
	dir.list_dir_end()

func _build_default_encounters() -> Array[Resource]:
	var result: Array[Resource] = []

	# --- REWARD ---
	result.append(_enc("wandering_merchant", "Thương Nhân Lang Thang",
		"Một thương nhân xuất hiện với những vật phẩm quý hiếm. Ông ta chào hàng...",
		EncounterData.EncounterType.REWARD, EncounterData.Rarity.COMMON, 1, 1.5,
		[_choice("Mua vũ khí (+30 Vàng)", "Chi 20 HP để lấy 30 vàng.", 30, -20),
		 _choice("Bỏ qua", "Không rủi ro.", 0, 0)]))

	result.append(_enc("ancient_treasury", "Kho Báu Cổ Đại",
		"Bạn tìm thấy một hầm kho bí ẩn. Bên trong là vàng bạc chưa từng ai chạm đến.",
		EncounterData.EncounterType.REWARD, EncounterData.Rarity.UNCOMMON, 1, 1.0,
		[_choice("Lấy kho báu (+50 Vàng)", "Mở cửa hầm và lấy vàng.", 50, 0),
		 _choice("Để lại (an toàn)", "Không gì xảy ra.", 0, 0)]))

	# --- RISK ---
	result.append(_enc("cursed_sanctuary", "Đền Thờ Bị Nguyền",
		"Một ngôi đền cổ tỏa ra ánh sáng tím. Những lời thì thầm vang lên — đây là đánh đổi nguy hiểm.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.UNCOMMON, 2, 0.8,
		[_choice("Nhận lời nguyền (mất 8 HP)", "Nhận được sức mạnh nhưng mất máu căn cứ.", 40, -8),
		 _choice("Bỏ đi", "An toàn là trên hết.", 0, 0)]))

	result.append(_enc("black_crow_swarm", "Bầy Quạ Đen",
		"Hàng nghìn con quạ đen đổ xuống như mưa. Chúng mang theo tin dữ từ vương quốc.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.COMMON, 1, 1.2,
		[_choice("Chống lại bầy quạ (mất 5 HP)", "Đuổi chúng đi để bảo vệ vị trí.", 20, -5),
		 _choice("Rút lui (mất 10 Vàng)", "Tránh thiệt hại về người.", -10, 0)]))

	result.append(_enc("dark_pact", "Giao Ước Bóng Tối",
		"Một bóng hình xuất hiện. Nó hứa hẹn quyền năng đổi lấy máu của ngươi.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.RARE, 3, 0.5,
		[_choice("Ký giao ước (mất 15 HP, +80 Vàng)", "Nguy hiểm nhưng lợi nhuận cao.", 80, -15),
		 _choice("Từ chối", "Không có sức mạnh nào đáng giá sinh mệnh.", 0, 0)]))

	# --- MIXED ---
	result.append(_enc("wandering_king", "Vị Vua Lang Thang",
		"Một vị vua đã mất ngai vàng xuất hiện trước mặt bạn. Ông muốn nói chuyện.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.RARE, 2, 0.6,
		[_choice("Nhận lời mời (mất 5 HP, +30 Vàng)", "Trao đổi thông tin chiến lược.", 30, -5),
		 _choice("Cung cấp pháo thủ (+20 Vàng, không đổi gì)", "Tặng ông ta nguồn lực.", 20, 0),
		 _choice("Cẩn thận từ chối", "Không rủi ro, không lợi.", 0, 0)]))

	result.append(_enc("abandoned_outpost", "Đồn Tiền Tiêu Bỏ Hoang",
		"Một đồn tiền tiêu cũ còn sót lại vũ khí và vàng. Nhưng nó trông có vẻ bẫy.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 1, 1.0,
		[_choice("Tìm kiếm cẩn thận (+20 Vàng, 50% mất 5 HP)", "Rủi ro trung bình, phần thưởng vừa.", 20, -3),
		 _choice("Bỏ qua an toàn", "Không rủi ro.", 0, 0)]))

	result.append(_enc("field_hospital", "Trạm Quân Y Chiến Trường",
		"Một trạm quân y dã chiến. Bác sĩ quân y có thể chữa lành vết thương nhưng cần được trả công.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 2, 1.0,
		[_choice("Chữa thương (+10 HP, mất 30 Vàng)", "Hồi phục đáng kể.", -30, 10),
		 _choice("Chữa nhẹ (+5 HP, mất 10 Vàng)", "Hồi phục khiêm tốn.", -10, 5),
		 _choice("Không cần", "Giữ vàng, chịu đựng.", 0, 0)]))

	return result

func _enc(id: String, title: String, flavor: String, etype, rarity, min_w: int, weight: float, choices_list: Array) -> EncounterData:
	var e = EncounterData.new()
	e.id = id; e.title = title; e.flavor_text = flavor
	e.encounter_type = etype; e.rarity = rarity
	e.min_wave = min_w; e.weight = weight
	var c_arr: Array[Resource] = []
	for c in choices_list: c_arr.append(c)
	e.choices = c_arr
	return e

func _choice(text: String, preview: String, gold: int, hp: int) -> EncounterChoice:
	var c = EncounterChoice.new()
	c.choice_text = text; c.outcome_preview = preview
	c.gold_delta = gold; c.health_delta = hp
	return c

# --- Kích hoạt encounter ngẫu nhiên ---
func trigger_random_encounter() -> void:
	var available = _get_available_encounters()
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if available.is_empty():
		if gm:
			gm.change_state(gm.GameState.PREPARING)
		return
	current_encounter = _weighted_random_pick(available)
	encounter_history.append(current_encounter.id)
	if gm:
		gm.trigger_encounter(current_encounter)

func _get_available_encounters() -> Array:
	var gm = get_node_or_null("/root/GameManagerSingleton")
	var wave = gm.current_wave if gm else 0
	var king_id = gm.selected_king.id if gm and gm.selected_king else ""
	var result = []
	for enc_res in all_encounters:
		var enc = enc_res as EncounterData
		if not enc: continue
		if enc.min_wave > wave: continue
		if enc.required_king_id != "" and enc.required_king_id != king_id: continue
		result.append(enc)
	return result

func _weighted_random_pick(encounters: Array) -> EncounterData:
	var total = 0.0
	for e in encounters: total += (e as EncounterData).weight
	var roll = randf() * total
	var cum = 0.0
	for e in encounters:
		cum += (e as EncounterData).weight
		if roll <= cum:
			return e as EncounterData
	return encounters.back() as EncounterData

# --- Xử lý lựa chọn ---
func resolve_choice(choice: EncounterChoice) -> void:
	if not choice: return
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if not gm: return
	if choice.gold_delta > 0:
		gm.add_gold(choice.gold_delta)
	elif choice.gold_delta < 0:
		gm.spend_gold(abs(choice.gold_delta))
	if choice.health_delta < 0:
		gm.take_damage(abs(choice.health_delta))
	elif choice.health_delta > 0:
		gm.current_health += choice.health_delta
		gm.health_changed.emit(gm.current_health)
	if choice.decree_delta != 0.0:
		gm.current_decree_max = max(1.0, gm.current_decree_max + choice.decree_delta)
	encounter_resolved.emit(choice)
	current_encounter = null
	gm.change_state(gm.GameState.PREPARING)
