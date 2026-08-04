# res://scripts/managers/EncounterManager.gd
# Quản lý hệ thống Random Encounter giữa các wave.
extends Node
class_name EncounterManager

signal encounter_resolved(choice: EncounterChoice)

@export var all_encounters: Array[Resource] = []

var current_encounter: EncounterData = null
var encounter_history: Array[String] = []

# Snapshot chỉ số GameManager tại thời điểm encounter bắt đầu —
# dùng để tính delta khi encounter_screen tự áp dụng hiệu ứng lên GameManager.
var _gm_baseline: Dictionary = {}
var _awaiting_resolution: bool = false

func _ready() -> void:
	_ensure_default_encounters()
	# encounter_screen.gd áp dụng gold/hp/rd trực tiếp lên GameManager rồi đổi state.
	# Lắng nghe state_changed để đồng bộ kết quả về game_map (nguồn hiển thị gold/hp)
	# và KingManager (RD cap) — nếu không, update_ui() sẽ ghi đè mất kết quả encounter.
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if gm and gm.has_signal("state_changed"):
		gm.state_changed.connect(_on_gm_state_changed)

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
	# ══════════════════════════════════════════════════════════════════
	# TRIẾT LÝ: "Risk for the Biscuit" — Mọi lựa chọn đều có giá phải trả.
	# Không có lựa chọn miễn phí. Bỏ qua cũng là một quyết định.
	# Format: _choice(text, preview, gold_delta, hp_delta, rd_cap_delta)
	# ══════════════════════════════════════════════════════════════════
	var result: Array[Resource] = []

	# ── 1. THƯƠNG NHÂN LANG THANG ─────────────────────────────────────
	# Giá trị: thuốc +5HP (-40G) | bản đồ chiến thuật +25RD (-30G) | chỉ đường +20G
	result.append(_enc("wandering_merchant", "Wandering Merchant",
		"A wounded merchant is selling his stock. Something here is useful - none of it is cheap.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 1, 1.5,
		[_choice("Buy healing supplies\n[-40 Gold  →  +5 HP]",
			"Expensive - but HP is not easily bought back.", -40, 5, 0.0),
		 _choice("Buy the tactical maps\n[-30 Gold  →  +25 permanent max Decree]",
			"This knowledge sharpens your command.", -30, 0, 25.0),
		 _choice("Point him the way\n[Free  →  +20 Gold (he repays you)]",
			"A small reward. Nothing lost.", 20, 0, 0.0)],
		"res://assets/ui/encounters/encounter_merchant.png"))

	# ── 2. KHO BÁU CỔ ĐẠI ────────────────────────────────────────────
	# Giá trị: phá khóa +80G (-8HP bẫy) | mở cẩn thận +40G (-2HP) | bỏ qua (-không gì)
	result.append(_enc("ancient_treasury", "Ancient Vault",
		"A vault sealed for years. There is a great deal of gold inside - and the traps may still work.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.UNCOMMON, 1, 1.0,
		[_choice("Break the lock now\n[+80 Gold  →  -8 HP (traps fire)]",
			"Greedy? Certainly. But 80 gold is not a small number.", 80, -8, 0.0),
		 _choice("Open it carefully, piece by piece\n[+40 Gold  →  -2 HP (a small trap)]",
			"More durable, and still not free.", 40, -2, 0.0),
		 _choice("Not worth the risk\n[Skip - nothing lost, nothing gained]",
			"Perfectly safe. This is not the last chance.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_treasury.png"))

	# ── 3. ĐỀN THỜ BỊ NGUYỀN ─────────────────────────────────────────
	# Giá trị: nhận lời nguyền +50G (-8HP) | phá hủy +10G (-3HP mảnh vỡ) | rời đi (0)
	result.append(_enc("cursed_shrine", "Cursed Shrine",
		"Violet light pours from the shrine. A whisper promises gold in exchange for blood.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.UNCOMMON, 2, 0.8,
		[_choice("Pray and accept the curse\n[+50 Gold  →  -8 HP]",
			"Gold bought with life. Are you willing?", 50, -8, 0.0),
		 _choice("Destroy the shrine\n[+10 Gold (fragments)  →  -3 HP (flying stone)]",
			"Destruction pays a little, and still costs something.", 10, -3, 0.0),
		 _choice("Leave at once\n[Nothing - no loss, no gain]",
			"Sometimes the wisest move is to do nothing.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_shrine.png"))

	# ── 4. BẦY QUẠ ĐEN ───────────────────────────────────────────────
	# Giá trị: chống lại +25G (-5HP) | đốt lửa +10G (-3HP) | rút lui an toàn (-15G)
	result.append(_enc("black_crow_swarm", "Murder of Crows",
		"A thousand crows fall like nightfall. They carry an omen - and the weapons of the dead.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.COMMON, 1, 1.2,
		[_choice("Fight the flock\n[+25 Gold (recovered weapons)  →  -5 HP]",
			"Beating them yields spoils - and wounds.", 25, -5, 0.0),
		 _choice("Burn them off\n[+10 Gold (salvaged fuel)  →  -3 HP (toxic smoke)]",
			"Safer, but not entirely clean.", 10, -3, 0.0),
		 _choice("Fall back and let them pass\n[-15 Gold (lost gear)  →  No HP lost]",
			"Life matters more than gold - but gold is not cheap either.", -15, 0, 0.0)],
		"res://assets/ui/encounters/encounter_crows.png"))

	# ── 5. GIAO ƯỚC BÓNG TỐI ─────────────────────────────────────────
	# Giá trị: ký giao ước +100G (-15HP) | phủ nhận -25G (an toàn) | bỏ chạy (-5HP miễn phí)
	result.append(_enc("dark_pact", "Dark Bargain",
		"A faceless shape lays a contract before you. A hundred gold for fifteen life. The ink is already mixed.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.RARE, 3, 0.5,
		[_choice("Sign the contract\n[+100 Gold  →  -15 HP (for the rest of this run)]",
			"The biggest payout. But those 15 HP never come back.", 100, -15, 0.0),
		 _choice("Buy your way out\n[-25 Gold  →  Walk away clean]",
			"Pay your way out. Expensive, but clean.", -25, 0, 0.0),
		 _choice("Run\n[-5 HP (struck while fleeing)  →  No gold lost]",
			"Cheaper, but not free. The shape dislikes being ignored.", 0, -5, 0.0)],
		"res://assets/ui/encounters/encounter_pact.png"))

	# ── 6. VỊ VUA LANG THANG ─────────────────────────────────────────
	# Giá trị: thuê cố vấn -50G (+50RD max) | đổi bí quyết -20G (+4HP) | từ chối (0)
	result.append(_enc("wandering_king", "The Wandering King",
		"A king who lost his throne offers to share what he knows. He has much to teach - none of it free.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.RARE, 2, 0.6,
		[_choice("Sign a strategic alliance\n[-50 Gold  →  +50 permanent max Decree]",
			"The most expensive. But max Decree is a long-term edge you cannot ignore.", -50, 0, 50.0),
		 _choice("Trade healing knowledge\n[-20 Gold  →  +4 HP]",
			"Cheaper. HP is a precious resource.", -20, 4, 0.0),
		 _choice("Decline politely\n[Nothing lost - nothing gained]",
			"Keep the gold. Another chance will come.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_king.png"))

	# ── 7. ĐỒN TIỀN TIÊU BỎ HOANG ────────────────────────────────────
	# Giá trị: lục soát đầy đủ +35G (-5HP bẫy) | kiểm tra nhanh +15G (an toàn) | bỏ qua (0)
	result.append(_enc("abandoned_outpost", "Abandoned Outpost",
		"Weapons and gold still sit in the outpost - but the old traps may not be dead yet.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 1, 1.0,
		[_choice("Search everything\n[+35 Gold  →  -5 HP (an old trap fires)]",
			"Greedy but reasonable. Only 5 HP for 35 gold.", 35, -5, 0.0),
		 _choice("Check only the obvious\n[+15 Gold  →  No HP lost]",
			"Safe. Less, but certain.", 15, 0, 0.0),
		 _choice("Skip the outpost\n[Nothing - press on]",
			"Time is a resource.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_outpost.png"))

	# ── 8. TRẠM QUÂN Y ───────────────────────────────────────────────
	# Giá trị: chữa đầy -40G (+8HP) | sơ cứu -15G (+3HP) | từ chối (0 — HP thấp hơn về sau)
	result.append(_enc("field_hospital", "Field Infirmary",
		"The field surgeon can close your wounds - but battlefield surgery is not cheap.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 2, 1.0,
		[_choice("Full treatment\n[-40 Gold  →  +8 HP]",
			"The most expensive, and the most healing. Worth it when HP is low.", -40, 8, 0.0),
		 _choice("Quick first aid\n[-15 Gold  →  +3 HP]",
			"More economical. Enough to hold a few more assaults.", -15, 3, 0.0),
		 _choice("Refuse treatment\n[Save the gold - low HP later is your problem]",
			"Free today. But low HP later costs far more.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_hospital.png"))

	# ── 9. LÒ RÈN CỔ ĐẠI ─────────────────────────────────────────────
	# Giá trị: tôi luyện -60G (+50RD max) | bán phế liệu -3HP (+25G) | bỏ qua (0)
	result.append(_enc("ancient_forge", "Ancient Forge",
		"The ancient forge still holds its heat. Anyone patient enough could reforge themselves - or sell the scrap.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.UNCOMMON, 3, 0.7,
		[_choice("Temper your strategic will\n[-60 Gold  →  +50 permanent max Decree]",
			"A long-term investment. Costly in gold, but max Decree climbs sharply.", -60, 0, 50.0),
		 _choice("Gather and sell the scrap\n[-3 HP (burned hands)  →  +25 Gold]",
			"Small risk, modest profit. No capital required.", 25, -3, 0.0),
		 _choice("Skip the forge\n[Nothing lost - nothing gained]",
			"Not this time.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_forge.png"))

	# ── 10. BÓNG MA CHIẾN TRƯỜNG ─────────────────────────────────────
	# Giá trị: hấp thụ năng lượng -10HP (+45RD max) | lắng nghe ký ức -8HP (+50G) | xua đuổi -20G (an toàn)
	result.append(_enc("battlefield_ghost", "Battlefield Wraith",
		"The spirit of a fallen warrior still lingers. It holds power - and the memory of victories.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.RARE, 4, 0.4,
		[_choice("Absorb its energy\n[-10 HP  →  +45 permanent max Decree]",
			"It hurts, and it is worth it. +45 max Decree is an enormous edge.", 0, -10, 45.0),
		 _choice("Listen to its memories\n[-8 HP (the visions haunt you)  →  +50 Gold]",
			"Plenty of gold, but HP all the same. Nothing here is free.", 50, -8, 0.0),
		 _choice("Banish it with a rite\n[-20 Gold  →  Walk away clean]",
			"Costs gold, keeps your HP intact. The careful choice.", -20, 0, 0.0)],
		"res://assets/ui/encounters/encounter_ghost.png"))

	# ── 11. CỐNG PHẨM HOÀNG GIA (REWARD) ─────────────────────────────
	# Giá trị: chọn 1 trong 3 phần thưởng — vàng +30G | quân nhu +3HP | sắc lệnh +15RD max
	result.append(_enc("royal_tribute", "Royal Tribute",
		"Border villagers bring tribute for your protection. They can spare only one gift.",
		EncounterData.EncounterType.REWARD, EncounterData.Rarity.COMMON, 1, 1.2,
		[_choice("Take the chest of gold\n[+30 Gold]",
			"Gold is always useful. Nothing to debate.", 30, 0, 0.0),
		 _choice("Take supplies and food\n[+3 HP]",
			"The walls are reinforced and the soldiers are fed.", 0, 3, 0.0),
		 _choice("Take the ancient decree scroll\n[+15 permanent max Decree]",
			"Your authority reaches a little further.", 0, 0, 15.0)],
		"res://assets/ui/encounters/encounter_merchant.png"))

	# ── 12. LỄ HỘI MÙA GẶT (REWARD) ──────────────────────────────────
	# Giá trị: thu thuế +25G | chung vui +10G +2HP | nhận lương thực +4HP
	result.append(_enc("harvest_festival", "Harvest Festival",
		"The harvest is rich. The people hold a festival and invite the King. You decide how the share is split.",
		EncounterData.EncounterType.REWARD, EncounterData.Rarity.UNCOMMON, 3, 0.8,
		[_choice("Collect the harvest tax\n[+25 Gold]",
			"The treasury grows. The people mind, but they bow.", 25, 0, 0.0),
		 _choice("Celebrate with them\n[+10 Gold (gifts)  →  +2 HP (morale)]",
			"A king close to his people has a steadier army.", 10, 2, 0.0),
		 _choice("Requisition food for the army\n[+4 HP]",
			"Full granaries make for a sturdier hold.", 0, 4, 0.0)],
		"res://assets/ui/encounters/encounter_outpost.png"))

	# ── 13. LÃO BINH KỂ CHUYỆN (STORY) ───────────────────────────────
	# Giá trị: lắng nghe +10RD max | biếu vàng an dưỡng -15G (+3HP) | rời đi (0)
	result.append(_enc("old_veteran_tale", "The Old Soldier",
		"By the dying fire, an old soldier who served the late king recounts a battle from long ago. His voice shakes; his eyes do not.",
		EncounterData.EncounterType.STORY, EncounterData.Rarity.COMMON, 1, 1.0,
		[_choice("Sit and listen all night\n[+10 permanent max Decree (old doctrine)]",
			"A hundred battles of experience is a treasure no gold can buy.", 0, 0, 10.0),
		 _choice("Give him gold for his old age\n[-15 Gold  →  +3 HP (the troops take note)]",
			"The soldiers saw it - and they know their king values honour.", -15, 3, 0.0),
		 _choice("Nod and move on\n[Nothing lost - nothing gained]",
			"War does not wait on old stories.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_hospital.png"))

	# ── 14. THI SĨ LANG THANG (STORY) ────────────────────────────────
	# Giá trị: bảo trợ -20G (+15RD max danh tiếng) | nghe một khúc -5G (+1HP) | đuổi đi (0)
	result.append(_enc("wandering_bard", "Wandering Bard",
		"A poet with a lute asks to sing an epic of your war. The song will travel further than any banner - if you pay what it is worth.",
		EncounterData.EncounterType.STORY, EncounterData.Rarity.UNCOMMON, 2, 0.9,
		[_choice("Fund the whole epic\n[-20 Gold  →  +15 permanent max Decree (renown)]",
			"The whole kingdom will pass your name along. Authority grows with it.", -20, 0, 15.0),
		 _choice("Hear one short verse, pay a little\n[-5 Gold  →  +1 HP (the troops cheer)]",
			"One marching song is enough to warm sentries in the night mist.", -5, 1, 0.0),
		 _choice("Send him away\n[Nothing lost - songs feed no one]",
			"The battlefield has no use for poetry. Perhaps.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_king.png"))

	# ── 15. TẤM GƯƠNG BÓNG TỐI (STORY — riêng Phantom King) ──────────
	# Giá trị: soi gương -5HP (+40RD max) | đập vỡ +20G | quay đi (0)
	result.append(_enc("phantom_mirror", "Mirror of Shadows",
		"Among the ruins, a black mirror reflects no torchlight - it reflects the dark in you. It whispers in the Phantom King's voice.",
		EncounterData.EncounterType.STORY, EncounterData.Rarity.RARE, 2, 0.9,
		[_choice("Look straight into the mirror\n[-5 HP  →  +40 permanent max Decree]",
			"Face your own darkness - and take it for your own.", 0, -5, 40.0),
		 _choice("Shatter the mirror\n[+20 Gold (rare black silver)]",
			"Some doors are better left shut. The shards still fetch a price.", 20, 0, 0.0),
		 _choice("Turn away without looking back\n[Nothing - the dark stays asleep]",
			"You know better than anyone: the dark always charges.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_ghost.png", "king_phantom"))

	# ── 16. BÀN THỜ LỬA THIÊNG (RISK — riêng Flame Queen) ────────────
	# Giá trị: hiến tế máu -6HP (+60G) | dâng vàng -30G (+5HP) | dập tắt (0)
	result.append(_enc("flame_altar", "Altar of Sacred Flame",
		"The flame on the old altar surges as the Queen draws near - it knows its mistress's blood. The sacred fire demands an offering.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.RARE, 2, 0.9,
		[_choice("Offer blood\n[-6 HP  →  +60 Gold (the fire spits molten coin)]",
			"The sacred fire pays well - but it takes only blood.", 60, -6, 0.0),
		 _choice("Feed gold to the flame\n[-30 Gold  →  +5 HP (the fire blesses you)]",
			"Wealth traded for protection. The flame is satisfied.", -30, 5, 0.0),
		 _choice("Order the altar doused\n[Nothing - the fire dies, and the silence is cold]",
			"The Queen kneels to no flame.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_shrine.png", "king_flame"))

	# ── LONG MẠCH LỘ THIÊN ───────────────────────────────────────────
	# Đổi HP/vàng lấy Ô NGUYÊN TỐ (futureplan §2.4). Ba lựa chọn = ba triết lý:
	# đào sâu build hiện tại · mở rộng sang hệ khác · giữ tài nguyên.
	result.append(_enc("exposed_ley_line", "Exposed Ley Line",
		"The ground splits open, exposing an elemental vein flowing beneath. Mining it is not free.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.UNCOMMON, 3, 1.2,
		[_choice_tiles("Dig deep along the vein\n[-8 HP  →  3 veins of your strongest element]",
			"Three matching veins stacked become a Level 3 Ley Line.", 0, -8, 3, "dominant"),
		 _choice_tiles("Bore sideways for a stranger vein\n[-70 Gold  →  2 random element veins]",
			"Opens a path to a different element - risky, but who knows.", -70, 0, 2, "random"),
		 _choice("Seal the vein and move on\n[+35 Gold (ore scraps) - no veins]",
			"You do not always need to dig deep.", 35, 0, 0.0)],
		"res://assets/ui/encounters/encounter_shrine.png"))

	# ── THỢ KHẮC ĐÁ CÂM ──────────────────────────────────────────────
	# Phiên bản "an toàn" của Long Mạch: chỉ tốn vàng, cho ít ô hơn.
	result.append(_enc("silent_stonecutter", "The Silent Stonecutter",
		"A mute old man with calloused hands lays out several stone slabs carved with elemental runes.",
		EncounterData.EncounterType.REWARD, EncounterData.Rarity.COMMON, 2, 1.0,
		[_choice_tiles("Buy two matching slabs\n[-90 Gold  →  2 veins of your strongest element]",
			"Two stacked veins become a Level 2 Source.", -90, 0, 2, "dominant"),
		 _choice_tiles("Buy one slab, any kind\n[-40 Gold  →  1 random vein]",
			"Cheap, and it might be the missing piece of your Bagua.", -40, 0, 1, "random"),
		 _choice("Just look, then leave\n[Free - the old man nods]",
			"Nothing lost. Nothing gained either.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_merchant.png"))

	return result

func _enc(id: String, title: String, flavor: String, etype, rarity, min_w: int, weight: float, choices_list: Array, icon_path: String = "", king_id: String = "") -> EncounterData:
	var e = EncounterData.new()
	e.id = id; e.title = title; e.flavor_text = flavor
	e.encounter_type = etype; e.rarity = rarity
	e.min_wave = min_w; e.weight = weight
	e.required_king_id = king_id
	if icon_path != "" and ResourceLoader.exists(icon_path):
		e.encounter_icon = load(icon_path)
	var c_arr: Array[Resource] = []
	for c in choices_list: c_arr.append(c)
	e.choices = c_arr
	return e

func _choice(text: String, preview: String, gold: int, hp: int, rd: float = 0.0) -> EncounterChoice:
	var c = EncounterChoice.new()
	c.choice_text = text
	c.outcome_preview = preview
	c.gold_delta = gold
	c.health_delta = hp
	c.decree_delta = rd
	return c

## Biến thể của `_choice` kèm thưởng ô nguyên tố.
func _choice_tiles(text: String, preview: String, gold: int, hp: int,
		tiles: int, kind: String = "dominant") -> EncounterChoice:
	var c := _choice(text, preview, gold, hp, 0.0)
	c.element_tiles = tiles
	c.element_tile_kind = kind
	return c

## Đưa `count` ô nguyên tố loại `kind` vào kho lãnh thổ.
## `kind`: "dominant" (theo build hiện tại) · "random" · id nguyên tố cụ thể.
func _grant_element_tiles(map: Node, count: int, kind: String) -> void:
	if map == null:
		return
	var tm = map.get_node_or_null("TerritoryManager")
	if tm == null or not tm.has_method("add_stock"):
		push_warning("EncounterManager: element_tiles cần TerritoryManager — bỏ qua.")
		return

	var element := kind
	if kind == "dominant":
		element = str(map.call("_dominant_element")) if map.has_method("_dominant_element") else ""
		if element.is_empty():
			element = ElementTypes.ALL[randi() % ElementTypes.ALL.size()]
	elif kind == "random":
		element = ElementTypes.ALL[randi() % ElementTypes.ALL.size()]
	if not ElementTypes.is_valid(element):
		push_warning("EncounterManager: element_tile_kind '%s' không hợp lệ — bỏ qua." % kind)
		return

	var biome: String = TerritoryManager.biome_of_element(element)
	if biome.is_empty():
		return
	for _i in range(count):
		tm.call("add_stock", biome)
	var phase = map.get("phase_controller")
	if phase != null and is_instance_valid(phase):
		phase.set("phase_message", "✦ Gained %d %s veins from the event!" % [
			count, ElementTypes.display_name(element)])

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
		# Snapshot chỉ số trước khi encounter_screen áp dụng hiệu ứng lên GameManager
		_gm_baseline = {
			"gold":       gm.current_gold,
			"health":     gm.current_health,
			"decree_max": gm.current_decree_max,
		}
		_awaiting_resolution = true
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

# --- Đồng bộ kết quả encounter (path encounter_screen → GameManager) ---

func _on_gm_state_changed(new_state: int) -> void:
	if not _awaiting_resolution:
		return
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if not gm or new_state == gm.GameState.ENCOUNTER:
		return  # transition VÀO encounter — chưa resolve
	_awaiting_resolution = false
	_sync_encounter_outcome_to_map(gm)

## encounter_screen áp dụng gold/hp/rd trực tiếp lên GameManager, nhưng game_map
## giữ current_gold/current_health riêng và update_ui() sẽ push đè lên GameManager.
## → Áp delta (so với baseline) về game_map + đồng bộ RD cap sang KingManager.
func _sync_encounter_outcome_to_map(gm) -> void:
	if _gm_baseline.is_empty():
		return
	var gold_delta: int  = gm.current_gold - int(_gm_baseline.get("gold", gm.current_gold))
	var hp_delta: int    = gm.current_health - int(_gm_baseline.get("health", gm.current_health))
	var cap_delta: float = gm.current_decree_max - float(_gm_baseline.get("decree_max", gm.current_decree_max))
	_gm_baseline.clear()
	current_encounter = null

	var map = get_parent()  # game_map — truy cập dynamic (không hard-type)
	if not map:
		return
	if "current_gold" in map:
		map.current_gold   += gold_delta
		map.current_health += hp_delta
	if cap_delta != 0.0:
		var km = map.get_node_or_null("KingManager")
		if km is KingManager:
			km.decree_cap = maxf(1.0, km.decree_cap + cap_delta)
			km.royal_decree_changed.emit(km.royal_decree)
	if map.has_method("update_ui"):
		map.update_ui()

# --- Xử lý lựa chọn ---
# API resolve đầy đủ (mọi field của EncounterChoice) cho code gọi trực tiếp.
# Path UI hiện tại (encounter_screen) chỉ áp dụng gold/hp/rd và được đồng bộ
# qua _on_gm_state_changed ở trên.
func resolve_choice(choice: EncounterChoice) -> void:
	if not choice: return
	var gm = get_node_or_null("/root/GameManagerSingleton")
	if not gm: return

	# Tự resolve — hủy cơ chế delta-sync để không áp dụng hai lần
	_awaiting_resolution = false
	_gm_baseline.clear()

	var gold_before: int   = gm.current_gold
	var health_before: int = gm.current_health

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

	_apply_extended_outcomes(choice)

	# Đồng bộ delta thực tế về game_map để update_ui() không ghi đè mất kết quả
	var map = get_parent()  # game_map — truy cập dynamic (không hard-type)
	if map and "current_gold" in map:
		map.current_gold   += gm.current_gold - gold_before
		map.current_health += gm.current_health - health_before
		if map.has_method("update_ui"):
			map.update_ui()

	encounter_resolved.emit(choice)  # game_map._on_encounter_resolved đồng bộ RD cap → KingManager
	current_encounter = null
	gm.change_state(gm.GameState.PREPARING)

## Các field nâng cao của EncounterChoice (trước đây là no-op) — wire vào hệ thống thật.
func _apply_extended_outcomes(choice: EncounterChoice) -> void:
	var map = get_parent()  # game_map — truy cập dynamic (không hard-type)

	# 1) add_soldier: TowerStats → cộng 1 quân vào kho quân (army stock) của ShopManager
	if choice.add_soldier:
		var tower_stats := choice.add_soldier as TowerStats
		var shop = map.get_node_or_null("ShopManager") if map else null
		if tower_stats and shop and shop.has_method("register_troop_purchase"):
			shop.register_troop_purchase(tower_stats)
		else:
			push_warning("EncounterManager: add_soldier cần TowerStats + ShopManager — bỏ qua.")

	# 2) remove_soldier_tag: trừ 1 quân chưa đặt (theo id) khỏi kho quân
	if choice.remove_soldier_tag != "":
		var shop_rm = map.get_node_or_null("ShopManager") if map else null
		if shop_rm and shop_rm.has_method("consume_unit_stock"):
			if not shop_rm.consume_unit_stock(choice.remove_soldier_tag):
				push_warning("EncounterManager: không còn quân '%s' trong kho để xóa." % choice.remove_soldier_tag)
		else:
			push_warning("EncounterManager: remove_soldier_tag cần ShopManager — bỏ qua.")

	# 3) add_territory: TerritoryStats (id = "territory_<biome>" hoặc "<biome>") → +1 stock lãnh thổ
	if choice.add_territory:
		var ter := choice.add_territory as TerritoryStats
		var tm = map.get_node_or_null("TerritoryManager") if map else null
		if ter and tm and tm.has_method("add_stock"):
			var biome_key := ter.id.trim_prefix("territory_")
			if TerritoryManager.BIOME_STATS.has(biome_key):
				tm.add_stock(biome_key)
			else:
				push_warning("EncounterManager: biome '%s' không hợp lệ cho add_territory." % biome_key)
		else:
			push_warning("EncounterManager: add_territory cần TerritoryStats + TerritoryManager — bỏ qua.")

	# 3b) element_tiles: tặng N ô nguyên tố vào kho (futureplan §2.4).
	#     Tặng vào KHO chứ không đặt sẵn lên bàn — vị trí đặt là quyết định của
	#     người chơi, và đó chính là chỗ hay của hệ ô nguyên tố.
	if choice.element_tiles > 0:
		_grant_element_tiles(map, choice.element_tiles, choice.element_tile_kind)

	# 4) trigger_script: logic phức tạp — script phải có execute(ctx: Dictionary)
	if choice.trigger_script:
		if choice.trigger_script.can_instantiate():
			var handler = choice.trigger_script.new()
			if handler and handler.has_method("execute"):
				handler.execute({
					"game_manager":      get_node_or_null("/root/GameManagerSingleton"),
					"game_map":          map,
					"encounter_manager": self,
				})
			else:
				push_warning("EncounterManager: trigger_script thiếu execute(ctx).")
		else:
			push_warning("EncounterManager: trigger_script không thể instantiate.")
