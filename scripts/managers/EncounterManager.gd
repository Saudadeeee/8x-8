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
	result.append(_enc("wandering_merchant", "Thương Nhân Lang Thang",
		"Một thương nhân bị thương đang rao bán hàng hoá. Có gì đó hữu ích — nhưng không rẻ.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 1, 1.5,
		[_choice("Mua thuốc hồi phục\n[-40 Vàng  →  +5 HP]",
			"Đắt nhưng HP là thứ không thể mua lại dễ dàng.", -40, 5, 0.0),
		 _choice("Mua bản đồ chiến thuật\n[-30 Vàng  →  +25 RD tối đa vĩnh viễn]",
			"Kiến thức này sẽ nâng cao khả năng chỉ huy của ngươi.", -30, 0, 25.0),
		 _choice("Chỉ đường cho hắn\n[Miễn phí  →  +20 Vàng (ông ta trả ơn)]",
			"Phần thưởng nhỏ. Không có gì mất đi.", 20, 0, 0.0)],
		"res://assets/ui/encounters/encounter_merchant.png"))

	# ── 2. KHO BÁU CỔ ĐẠI ────────────────────────────────────────────
	# Giá trị: phá khóa +80G (-8HP bẫy) | mở cẩn thận +40G (-2HP) | bỏ qua (-không gì)
	result.append(_enc("ancient_treasury", "Kho Báu Cổ Đại",
		"Hầm kho phong kín bao năm. Vàng bên trong rất nhiều — nhưng bẫy chưa chắc đã hỏng.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.UNCOMMON, 1, 1.0,
		[_choice("Phá khóa vào ngay\n[+80 Vàng  →  -8 HP (bẫy kích hoạt)]",
			"Tham lam? Chắc chắn. Nhưng 80 vàng không phải con số nhỏ.", 80, -8, 0.0),
		 _choice("Mở cẩn thận từng phần\n[+40 Vàng  →  -2 HP (cạm bẫy nhỏ)]",
			"Bền bỉ hơn nhưng vẫn có giá phải trả.", 40, -2, 0.0),
		 _choice("Không đáng liều\n[Bỏ qua — không mất gì, không được gì]",
			"An toàn tuyệt đối. Cơ hội này không phải lần cuối.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_treasury.png"))

	# ── 3. ĐỀN THỜ BỊ NGUYỀN ─────────────────────────────────────────
	# Giá trị: nhận lời nguyền +50G (-8HP) | phá hủy +10G (-3HP mảnh vỡ) | rời đi (0)
	result.append(_enc("cursed_shrine", "Đền Thờ Bị Nguyền",
		"Ánh sáng tím bốc ra từ bàn thờ. Lời thì thầm hứa hẹn vàng bạc đổi lấy máu.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.UNCOMMON, 2, 0.8,
		[_choice("Cầu nguyện và nhận lời nguyền\n[+50 Vàng  →  -8 HP]",
			"Vàng bạc đổi bằng sinh mệnh. Ngươi có sẵn sàng?", 50, -8, 0.0),
		 _choice("Phá hủy đền thờ\n[+10 Vàng (mảnh vỡ)  →  -3 HP (đá bắn)]",
			"Hủy diệt mang lại ít vàng nhưng vẫn có giá.", 10, -3, 0.0),
		 _choice("Rời đi ngay\n[Không có gì — không mất, không được]",
			"Đôi khi khôn ngoan nhất là không làm gì.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_shrine.png"))

	# ── 4. BẦY QUẠ ĐEN ───────────────────────────────────────────────
	# Giá trị: chống lại +25G (-5HP) | đốt lửa +10G (-3HP) | rút lui an toàn (-15G)
	result.append(_enc("black_crow_swarm", "Bầy Quạ Đen",
		"Nghìn con quạ đổ xuống như bóng tối. Chúng mang điềm báo — và cả vũ khí rơi của lính chết.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.COMMON, 1, 1.2,
		[_choice("Chiến đấu với bầy quạ\n[+25 Vàng (vũ khí thu hồi)  →  -5 HP]",
			"Đánh bại chúng mang lại chiến lợi phẩm — nhưng vẫn bị thương.", 25, -5, 0.0),
		 _choice("Đốt lửa xua đuổi\n[+10 Vàng (nguyên liệu cháy)  →  -3 HP (khói độc)]",
			"An toàn hơn nhưng vẫn không thoát hoàn toàn.", 10, -3, 0.0),
		 _choice("Rút lui nhường đường\n[-15 Vàng (mất trang bị)  →  Không mất HP]",
			"Tính mạng quan trọng hơn vàng — nhưng vàng không phải rẻ.", -15, 0, 0.0)],
		"res://assets/ui/encounters/encounter_crows.png"))

	# ── 5. GIAO ƯỚC BÓNG TỐI ─────────────────────────────────────────
	# Giá trị: ký giao ước +100G (-15HP) | phủ nhận -25G (an toàn) | bỏ chạy (-5HP miễn phí)
	result.append(_enc("dark_pact", "Giao Ước Bóng Tối",
		"Bóng hình không mặt đặt hợp đồng trước mặt ngươi. 100 vàng đổi 15 máu. Mực đã chuẩn bị sẵn.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.RARE, 3, 0.5,
		[_choice("Ký giao ước\n[+100 Vàng  →  -15 HP (vĩnh viễn trong run này)]",
			"Lợi nhuận cao nhất. Nhưng 15 HP không bao giờ quay lại.", 100, -15, 0.0),
		 _choice("Phủ nhận bằng vàng\n[-25 Vàng  →  Thoát an toàn hoàn toàn]",
			"Trả tiền để thoát. Đắt nhưng sạch tay.", -25, 0, 0.0),
		 _choice("Bỏ chạy\n[-5 HP (bị tấn công khi chạy)  →  Không mất vàng]",
			"Rẻ hơn nhưng không miễn phí. Bóng hình không thích bị phớt lờ.", 0, -5, 0.0)],
		"res://assets/ui/encounters/encounter_pact.png"))

	# ── 6. VỊ VUA LANG THANG ─────────────────────────────────────────
	# Giá trị: thuê cố vấn -50G (+50RD max) | đổi bí quyết -20G (+4HP) | từ chối (0)
	result.append(_enc("wandering_king", "Vị Vua Lang Thang",
		"Một vị vua đã mất ngai vàng đề nghị chia sẻ kiến thức. Ông ta có nhiều thứ để dạy — không miễn phí.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.RARE, 2, 0.6,
		[_choice("Ký liên minh chiến lược\n[-50 Vàng  →  +50 RD tối đa vĩnh viễn]",
			"Đắt nhất. Nhưng RD tối đa là lợi thế lâu dài không thể bỏ qua.", -50, 0, 50.0),
		 _choice("Trao đổi bí quyết chữa thương\n[-20 Vàng  →  +4 HP]",
			"Rẻ hơn. HP là nguồn lực quý giá.", -20, 4, 0.0),
		 _choice("Từ chối lịch sự\n[Không mất gì — không được gì]",
			"Bảo tồn vàng. Cơ hội khác sẽ đến.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_king.png"))

	# ── 7. ĐỒN TIỀN TIÊU BỎ HOANG ────────────────────────────────────
	# Giá trị: lục soát đầy đủ +35G (-5HP bẫy) | kiểm tra nhanh +15G (an toàn) | bỏ qua (0)
	result.append(_enc("abandoned_outpost", "Đồn Tiền Tiêu Bỏ Hoang",
		"Vũ khí và vàng vẫn còn trong đồn — nhưng bẫy cũ chưa chắc đã hết tác dụng.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 1, 1.0,
		[_choice("Lục soát toàn bộ\n[+35 Vàng  →  -5 HP (bẫy cũ kích hoạt)]",
			"Tham lam nhưng hữu lý. Chỉ mất 5 HP cho 35 vàng.", 35, -5, 0.0),
		 _choice("Kiểm tra những gì rõ ràng\n[+15 Vàng  →  Không mất HP]",
			"An toàn. Ít hơn nhưng chắc chắn.", 15, 0, 0.0),
		 _choice("Bỏ qua đồn\n[Không có gì — tiếp tục nhiệm vụ]",
			"Thời gian là tài nguyên.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_outpost.png"))

	# ── 8. TRẠM QUÂN Y ───────────────────────────────────────────────
	# Giá trị: chữa đầy -40G (+8HP) | sơ cứu -15G (+3HP) | từ chối (0 — HP thấp hơn về sau)
	result.append(_enc("field_hospital", "Trạm Quân Y Chiến Trường",
		"Bác sĩ quân y có thể hồi phục vết thương — nhưng phẫu thuật chiến trường không rẻ.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.COMMON, 2, 1.0,
		[_choice("Điều trị đầy đủ\n[-40 Vàng  →  +8 HP]",
			"Đắt nhất nhưng hồi phục nhiều nhất. Đáng giá khi HP thấp.", -40, 8, 0.0),
		 _choice("Sơ cứu nhanh\n[-15 Vàng  →  +3 HP]",
			"Kinh tế hơn. Đủ để trụ thêm vài đợt tấn công.", -15, 3, 0.0),
		 _choice("Từ chối điều trị\n[Tiết kiệm vàng — HP thấp về sau là vấn đề của ngươi]",
			"Miễn phí hôm nay. Nhưng HP thấp trong tương lai sẽ đắt hơn nhiều.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_hospital.png"))

	# ── 9. LÒ RÈN CỔ ĐẠI ─────────────────────────────────────────────
	# Giá trị: tôi luyện -60G (+50RD max) | bán phế liệu -3HP (+25G) | bỏ qua (0)
	result.append(_enc("ancient_forge", "Lò Rèn Cổ Đại",
		"Lò rèn cổ đại vẫn còn nhiệt. Kẻ nào đủ kiên nhẫn có thể đúc lại bản thân — hoặc bán phế liệu.",
		EncounterData.EncounterType.MIXED, EncounterData.Rarity.UNCOMMON, 3, 0.7,
		[_choice("Tôi luyện ý chí chiến lược\n[-60 Vàng  →  +50 RD tối đa vĩnh viễn]",
			"Đầu tư dài hạn. Tốn nhiều vàng nhưng RD max tăng mạnh.", -60, 0, 50.0),
		 _choice("Thu nhặt và bán phế liệu\n[-3 HP (bỏng tay)  →  +25 Vàng]",
			"Nguy hiểm nhỏ, lợi nhuận vừa phải. Không cần vốn.", 25, -3, 0.0),
		 _choice("Bỏ qua lò rèn\n[Không mất gì — không được gì]",
			"Không phải lúc này.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_forge.png"))

	# ── 10. BÓNG MA CHIẾN TRƯỜNG ─────────────────────────────────────
	# Giá trị: hấp thụ năng lượng -10HP (+45RD max) | lắng nghe ký ức -8HP (+50G) | xua đuổi -20G (an toàn)
	result.append(_enc("battlefield_ghost", "Bóng Ma Chiến Trường",
		"Linh hồn chiến binh tử trận còn vương vấn. Nó chứa năng lượng — và cả ký ức về những trận thắng.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.RARE, 4, 0.4,
		[_choice("Hấp thụ năng lượng ma\n[-10 HP  →  +45 RD tối đa vĩnh viễn]",
			"Đau nhưng xứng đáng. RD max +45 là lợi thế cực lớn.", 0, -10, 45.0),
		 _choice("Lắng nghe ký ức chiến trận\n[-8 HP (ám ảnh tâm lý)  →  +50 Vàng]",
			"Vàng nhiều nhưng vẫn mất HP. Không có gì là miễn phí.", 50, -8, 0.0),
		 _choice("Xua đuổi bằng nghi lễ\n[-20 Vàng  →  Thoát an toàn hoàn toàn]",
			"Tốn vàng nhưng HP nguyên vẹn. Lựa chọn của kẻ thận trọng.", -20, 0, 0.0)],
		"res://assets/ui/encounters/encounter_ghost.png"))

	# ── 11. CỐNG PHẨM HOÀNG GIA (REWARD) ─────────────────────────────
	# Giá trị: chọn 1 trong 3 phần thưởng — vàng +30G | quân nhu +3HP | sắc lệnh +15RD max
	result.append(_enc("royal_tribute", "Cống Phẩm Hoàng Gia",
		"Dân làng vùng biên mang cống phẩm tạ ơn ngươi đã bảo vệ họ. Họ chỉ đủ sức dâng một món.",
		EncounterData.EncounterType.REWARD, EncounterData.Rarity.COMMON, 1, 1.2,
		[_choice("Nhận rương vàng\n[+30 Vàng]",
			"Vàng luôn hữu dụng. Không có gì phải bàn.", 30, 0, 0.0),
		 _choice("Nhận quân nhu và lương thực\n[+3 HP]",
			"Thành lũy được gia cố, binh sĩ no bụng.", 0, 3, 0.0),
		 _choice("Nhận cuộn sắc lệnh cổ\n[+15 RD tối đa vĩnh viễn]",
			"Uy quyền của ngươi lan xa hơn một chút.", 0, 0, 15.0)],
		"res://assets/ui/encounters/encounter_merchant.png"))

	# ── 12. LỄ HỘI MÙA GẶT (REWARD) ──────────────────────────────────
	# Giá trị: thu thuế +25G | chung vui +10G +2HP | nhận lương thực +4HP
	result.append(_enc("harvest_festival", "Lễ Hội Mùa Gặt",
		"Vụ mùa bội thu. Dân chúng mở hội ăn mừng và mời Đức Vua ngự giá. Ngươi chọn cách chia phần.",
		EncounterData.EncounterType.REWARD, EncounterData.Rarity.UNCOMMON, 3, 0.8,
		[_choice("Thu thuế mùa vụ\n[+25 Vàng]",
			"Quốc khố đầy thêm. Dân hơi tiếc nhưng vẫn cúi đầu.", 25, 0, 0.0),
		 _choice("Chung vui cùng dân\n[+10 Vàng (quà mừng)  →  +2 HP (sĩ khí)]",
			"Vua gần dân, lòng quân thêm vững.", 10, 2, 0.0),
		 _choice("Trưng thu lương thực cho quân đội\n[+4 HP]",
			"Kho lương đầy — thành lũy trụ vững hơn.", 0, 4, 0.0)],
		"res://assets/ui/encounters/encounter_outpost.png"))

	# ── 13. LÃO BINH KỂ CHUYỆN (STORY) ───────────────────────────────
	# Giá trị: lắng nghe +10RD max | biếu vàng an dưỡng -15G (+3HP) | rời đi (0)
	result.append(_enc("old_veteran_tale", "Lão Binh Kể Chuyện",
		"Bên đống lửa tàn, một lão binh từng phụng sự tiên vương kể lại trận đánh năm xưa. Giọng ông run run nhưng ánh mắt vẫn rực lửa.",
		EncounterData.EncounterType.STORY, EncounterData.Rarity.COMMON, 1, 1.0,
		[_choice("Ngồi xuống lắng nghe trọn đêm\n[+10 RD tối đa vĩnh viễn (binh pháp cổ)]",
			"Kinh nghiệm trăm trận của ông là kho báu không vàng nào mua nổi.", 0, 0, 10.0),
		 _choice("Biếu vàng để ông an dưỡng tuổi già\n[-15 Vàng  →  +3 HP (lòng quân cảm phục)]",
			"Binh sĩ nhìn thấy — và họ biết vua của mình trọng nghĩa.", -15, 3, 0.0),
		 _choice("Gật đầu chào rồi rời đi\n[Không mất gì — không được gì]",
			"Chiến tranh không chờ những câu chuyện cũ.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_hospital.png"))

	# ── 14. THI SĨ LANG THANG (STORY) ────────────────────────────────
	# Giá trị: bảo trợ -20G (+15RD max danh tiếng) | nghe một khúc -5G (+1HP) | đuổi đi (0)
	result.append(_enc("wandering_bard", "Thi Sĩ Lang Thang",
		"Một thi sĩ ôm đàn xin hát trường ca về cuộc chiến của ngươi. Lời ca sẽ bay xa hơn mọi lá cờ — nếu ngươi trả công xứng đáng.",
		EncounterData.EncounterType.STORY, EncounterData.Rarity.UNCOMMON, 2, 0.9,
		[_choice("Bảo trợ trọn trường ca\n[-20 Vàng  →  +15 RD tối đa vĩnh viễn (danh tiếng)]",
			"Khắp vương quốc sẽ truyền tụng tên ngươi. Uy quyền theo đó mà lớn.", -20, 0, 15.0),
		 _choice("Nghe một khúc ngắn, thưởng ít bạc\n[-5 Vàng  →  +1 HP (khích lệ ba quân)]",
			"Một khúc quân hành cũng đủ ấm lòng lính thú đêm sương.", -5, 1, 0.0),
		 _choice("Đuổi hắn đi\n[Không mất gì — lời ca cũng chẳng nuôi nổi ai]",
			"Chiến trường không cần thơ. Có lẽ vậy.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_king.png"))

	# ── 15. TẤM GƯƠNG BÓNG TỐI (STORY — riêng Phantom King) ──────────
	# Giá trị: soi gương -5HP (+40RD max) | đập vỡ +20G | quay đi (0)
	result.append(_enc("phantom_mirror", "Tấm Gương Bóng Tối",
		"Trong tàn tích, một tấm gương đen không phản chiếu ánh đuốc — nó phản chiếu chính bóng tối trong ngươi. Nó thì thầm bằng giọng của Phantom King.",
		EncounterData.EncounterType.STORY, EncounterData.Rarity.RARE, 2, 0.9,
		[_choice("Nhìn thẳng vào gương\n[-5 HP  →  +40 RD tối đa vĩnh viễn]",
			"Đối diện bóng tối của chính mình — và thu phục nó.", 0, -5, 40.0),
		 _choice("Đập vỡ tấm gương\n[+20 Vàng (mảnh bạc đen quý hiếm)]",
			"Có những cánh cửa không nên mở. Bán mảnh vỡ cũng được giá.", 20, 0, 0.0),
		 _choice("Quay đi không nhìn lại\n[Không có gì — bóng tối vẫn ngủ yên]",
			"Ngươi biết rõ hơn ai hết: bóng tối luôn đòi giá.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_ghost.png", "king_phantom"))

	# ── 16. BÀN THỜ LỬA THIÊNG (RISK — riêng Flame Queen) ────────────
	# Giá trị: hiến tế máu -6HP (+60G) | dâng vàng -30G (+5HP) | dập tắt (0)
	result.append(_enc("flame_altar", "Bàn Thờ Lửa Thiêng",
		"Ngọn lửa trên bàn thờ cổ bùng lên khi Nữ Hoàng đến gần — nó nhận ra dòng máu của chủ nhân. Lửa thiêng đòi lễ vật.",
		EncounterData.EncounterType.RISK, EncounterData.Rarity.RARE, 2, 0.9,
		[_choice("Hiến tế bằng máu\n[-6 HP  →  +60 Vàng (lửa nhả vàng nung chảy)]",
			"Lửa thiêng trả công hậu hĩnh — nhưng nó chỉ nhận máu.", 60, -6, 0.0),
		 _choice("Dâng vàng vào ngọn lửa\n[-30 Vàng  →  +5 HP (lửa phù hộ)]",
			"Đổi của lấy sự che chở. Ngọn lửa hài lòng.", -30, 5, 0.0),
		 _choice("Ra lệnh dập tắt bàn thờ\n[Không có gì — lửa tắt, im lặng đến lạnh người]",
			"Nữ Hoàng không quỳ trước bất kỳ ngọn lửa nào.", 0, 0, 0.0)],
		"res://assets/ui/encounters/encounter_shrine.png", "king_flame"))

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
