# res://scripts/ui/hud/hud_codex.gd
#
# SÁCH NGUYÊN TỐ (phím F1) — tách khỏi game_hud.gd để file đó không phình.
# Component sống như child node của HUD; HUD chỉ giữ MỘT dòng uỷ quyền
# `toggle_codex()`. Không có state nào chia sẻ với HUD ngoài node gốc "Control".
extends Node
class_name HudCodex

## HUD chứa component này — chỉ dùng để tìm node gốc "Control".
var hud: CanvasLayer = null

static func attach(owner_hud: CanvasLayer) -> HudCodex:
	var c := HudCodex.new()
	c.name = "HudCodex"
	c.hud = owner_hud
	owner_hud.add_child(c)
	return c

# Hệ nguyên tố có 6 Dấu × 10 phản ứng × 4 hình thế × 3 cấp ô. Không có chỗ tra
# cứu thì người chơi mới chỉ thấy "số nhảy lung tung" — codex là điều kiện để
# hệ này chơi được, không phải tính năng phụ.
#
# Nội dung ĐỌC THẲNG từ nguồn sự thật (ElementTypes / ReactionTable /
# FormationDetector / TerritoryManager.LEVEL_BONUS) nên thêm phản ứng mới là
# codex tự có, không phải nhớ cập nhật hai chỗ.

var _codex_overlay: Control = null

func is_open() -> bool:
	return _codex_overlay != null and is_instance_valid(_codex_overlay) 		and _codex_overlay.visible

func toggle_codex() -> void:
	if _codex_overlay != null and is_instance_valid(_codex_overlay):
		_codex_overlay.visible = not _codex_overlay.visible
		return
	_build_codex()

func _build_codex() -> void:
	var root_ctrl := hud.get_node_or_null("Control") as Control
	if root_ctrl == null:
		return

	_codex_overlay = Control.new()
	_codex_overlay.name = "ElementCodex"
	_codex_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bấm được khi game đang pause — người chơi hay tra cứu lúc dừng.
	_codex_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(_codex_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_codex_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -400
	panel.offset_bottom = 400
	UIStyle.apply_panel(panel, "parchment")
	UIStyle.set_pad(panel, 16)
	_codex_overlay.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	var title := Label.new()
	title.text = "CODEX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title, 24, UIStyle.GOLD)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "F1 or ESC to close · B for your set"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(hint, 11, UIStyle.TEXT_DIM)
	col.add_child(hint)

	# Thứ tự có chủ đích: công thức TRƯỚC, rồi công cụ, rồi lớp nâng cao.
	_codex_formula(col)
	_codex_patterns(col)
	_codex_chess_formations(col)
	_codex_king_rules(col)
	_codex_elements(col)
	_codex_reactions(col)
	_codex_formations(col)
	_codex_tile_levels(col)
	_codex_affinity(col)

## Công thức — mục ĐẦU TIÊN vì mọi thứ khác chỉ là cách sửa hai con số này.
func _codex_formula(parent: VBoxContainer) -> void:
	_codex_heading(parent, "◆ THE FORMULA — everything in this game edits one of two numbers")
	_codex_row(parent, "BASE of a square", Color(0.65, 0.90, 1.00),
		"Total damage-per-second of EVERY piece covering that square. "
		+ "A piece covering no PATH square contributes nothing.")
	_codex_row(parent, "MULT of a square", Color(1.00, 0.80, 0.35),
		"Formations × vein level × relics × Rival King rule. Sources MULTIPLY "
		+ "together, so stacking many sources is how you break the run open.")
	_codex_row(parent, "Square Score", UIStyle.GOLD, "BASE × MULT. Hover a square to see every line that feeds it.")
	_codex_row(parent, "Threshold to beat", UIStyle.RED,
		"Total HP of the whole wave. The bar at the bottom is green if you can clear it, red if you already know you cannot.")


## Nước đi — bảng tra "quân này với tới đâu".
func _codex_patterns(parent: VBoxContainer) -> void:
	_codex_heading(parent, "＋ MOVEMENT — pieces attack by chess rules, not by radius")
	for kind in [ChessPattern.Kind.ROOK, ChessPattern.Kind.BISHOP,
			ChessPattern.Kind.QUEEN, ChessPattern.Kind.KNIGHT,
			ChessPattern.Kind.PAWN, ChessPattern.Kind.KING,
			ChessPattern.Kind.SIEGE]:
		var names := PackedStringArray()
		var d := DirAccess.open("res://res/towers/")
		if d:
			for f in d.get_files():
				var cn := f.trim_suffix(".remap")
				if not cn.ends_with(".tres"): continue
				var st := load("res://res/towers/" + cn) as TowerStats
				if st and int(st.attack_pattern) == kind:
					names.append(UIStyle.unit_name_vi(str(st.id)))
		_codex_row(parent, "%s %s" % [ChessPattern.glyph(kind), ChessPattern.label(kind)],
			Color(0.70, 0.90, 1.00), ", ".join(names) if names.size() > 0 else "—")
	_codex_row(parent, "⚠ Blocked", UIStyle.RED,
		"Rooks, Bishops and Queens SLIDE — YOUR OWN pieces in the way cut the line. "
		+ "Knights jump over everything; nothing blocks them.")


## Thế cờ — bảng "xếp thế nào được nhân bao nhiêu".
func _codex_chess_formations(parent: VBoxContainer) -> void:
	_codex_heading(parent, "⬢ FORMATIONS — your biggest MULT source, and they stack")
	for id in ChessFormations.ORDER:
		_codex_row(parent, "%s  ×%.1f" % [ChessFormations.display_name(id),
			ChessFormations.mult_of(id)],
			Color(1.00, 0.80, 0.35), ChessFormations.describe(id))


## Luật Rival King — người chơi phải tra được TRƯỚC khi tới wave boss.
func _codex_king_rules(parent: VBoxContainer) -> void:
	_codex_heading(parent, "☠ RIVAL KINGS — each one changes ONE rule of the board")
	for id in KingRules.ORDER:
		var spec: Dictionary = KingRules.RULES.get(id, {})
		_codex_row(parent, str(spec.get("name", id)), UIStyle.RED,
			str(spec.get("desc", "")))


## Bảng khắc/kháng — đây là chỗ người chơi tra "wave này nên dùng hệ gì".
func _codex_affinity(parent: VBoxContainer) -> void:
	_codex_heading(parent, "⚔ AFFINITY — Marks and reactions deal ×%.1f when strong, ×%.1f when resisted"
		% [EnemyStats.WEAK_MULT, EnemyStats.RESIST_MULT])
	for enemy_id in EnemyStats.DEFAULT_AFFINITY.keys():
		var row: Array = EnemyStats.DEFAULT_AFFINITY[enemy_id]
		if row.size() < 2:
			continue
		var display: String = str(EnemyStats.ABILITY_NOTES.get(enemy_id, ""))
		var weak := ElementTypes.display_name(str(row[0]))
		if row.size() >= 3:
			weak += " / " + ElementTypes.display_name(str(row[2]))
		_codex_row(parent, str(enemy_id).capitalize(), UIStyle.TEXT,
			"▲ %s   ▼ %s%s" % [weak, ElementTypes.display_name(str(row[1])),
				("   — " + display) if display != "" else ""])

func _codex_heading(parent: VBoxContainer, text: String) -> void:
	parent.add_child(UIStyle.separator(UIStyle.HUD_BORDER))
	var lbl := Label.new()
	lbl.text = text
	UIStyle.title(lbl, 15, UIStyle.GOLD)
	parent.add_child(lbl)

## Một dòng codex: nhãn trái (màu riêng) + mô tả phải (co giãn, tự xuống dòng).
func _codex_row(parent: VBoxContainer, left: String, left_color: Color, right: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var key := Label.new()
	key.text = left
	key.custom_minimum_size = Vector2(210, 0)
	UIStyle.glyph(key, 13, left_color)
	row.add_child(key)

	var value := Label.new()
	value.text = right
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.body(value, 11, UIStyle.TEXT)
	row.add_child(value)

func _codex_elements(parent: VBoxContainer) -> void:
	_codex_heading(parent, "◆ SIX ELEMENTS — an enemy carries at most %d Marks at once"
		% ElementTypes.DEFAULT_MAX_MARKS)
	for element in ElementTypes.ALL:
		var spec: Dictionary = ElementTypes.spec(element)
		var parts: PackedStringArray = []
		var dps := float(spec.get("dps", 0.0))
		if dps > 0.0:
			parts.append("%.0f damage/sec" % dps)
		var slow := float(spec.get("slow", 0.0))
		if slow > 0.0:
			parts.append("%.0f%% slow" % (slow * 100.0))
		if bool(spec.get("pierce_armor", false)):
			parts.append("bỏ qua giáp")
		if bool(spec.get("stacking", false)):
			parts.append("cộng dồn tối đa %d tầng" % int(spec.get("max_stacks", 1)))
		var amplify: Array = spec.get("amplify_from", [])
		if not amplify.is_empty():
			var names: PackedStringArray = []
			for other in amplify:
				names.append(ElementTypes.display_name(str(other)))
			parts.append("khuếch đại %s +%.0f%%" % [
				", ".join(names), float(spec.get("amplify_pct", 0.0)) * 100.0])
		parts.append("kéo dài %.0fs" % ElementTypes.duration_of(element))
		_codex_row(parent, "%s  %s" % [ElementTypes.icon(element),
			ElementTypes.display_name(element)],
			ElementTypes.color_of(element), " · ".join(parts))

## Bảng phản ứng đọc thẳng ReactionTable.TABLE — thêm phản ứng là codex tự có.
func _codex_reactions(parent: VBoxContainer) -> void:
	_codex_heading(parent, "✷ REACTIONS — two matching Marks DETONATE and consume both")
	for reaction in ReactionTable.TABLE:
		var pair: Array = reaction.get("pair", [])
		if pair.size() != 2:
			continue
		var left := "%s + %s" % [_codex_slot_name(str(pair[0])), _codex_slot_name(str(pair[1]))]
		_codex_row(parent, "%s\n%s" % [str(reaction.get("name", "?")), left],
			reaction.get("color", UIStyle.TEXT), _codex_reaction_desc(str(reaction.get("id", ""))))

func _codex_slot_name(slot: String) -> String:
	return "bất kỳ" if slot == ReactionTable.WILDCARD else ElementTypes.display_name(slot)

## Mô tả hiệu ứng — viết tay vì `TABLE` chỉ giữ số liệu sát thương, phần "làm gì"
## nằm trong từng hàm thực thi. Số liệu lấy từ hằng để không lệch với code.
func _codex_reaction_desc(id: String) -> String:
	match id:
		"vaporize":
			# Không có toán tử % ở dòng này → viết một dấu %, không phải %%.
			return "250% sát thương lên một mục tiêu. Đòn dồn mạnh nhất hệ."
		"melt":
			return "200%% sát thương và XOÁ SẠCH giáp %.0f giây." % ReactionTable.MELT_ARMOR_SHRED
		"freeze":
			return "Đứng yên %.0fs. Mỗi con có hồi %.0fs — synergy Băng ×6 bỏ hồi này." % [
				ReactionTable.FREEZE_DURATION, ReactionTable.FREEZE_COOLDOWN]
		"conduct":
			return "Lan tối đa %d địch trong %.1fm, mỗi con 60%% sát thương." % [
				ReactionTable.CONDUCT_MAX_TARGETS, ReactionTable.CONDUCT_RADIUS]
		"superconduct":
			return "Trừ %d giáp mọi địch trong %.1fm suốt %.0f giây." % [
				ReactionTable.SUPERCONDUCT_ARMOR, ReactionTable.SUPERCONDUCT_RADIUS,
				ReactionTable.SUPERCONDUCT_DURATION]
		"overload":
			return "Nổ %.1fm, 180%% sát thương, đẩy lùi địch dọc đường đi." % \
				ReactionTable.OVERLOAD_RADIUS
		"toxic_burn":
			return "Nhân đôi tầng Độc rồi cấy sang %d địch gần nhất." % \
				ReactionTable.TOXIC_BURN_SPREAD
		"contagion":
			return "Độc lây sang MỌI địch trong %.1fm, giữ nguyên số tầng." % \
				ReactionTable.CONTAGION_RADIUS
		"crystallize":
			return "80%% sát thương + %d vàng. %.0f%% rơi thêm một ô nguyên tố." % [
				ReactionTable.CRYSTAL_GOLD, ReactionTable.CRYSTAL_SHARD_CHANCE * 100.0]
		"quake":
			return "120%% sát thương, choáng %.0fs, ô đó thành vết nứt (chậm %.0f%% trong %.0fs)." % [
				ReactionTable.QUAKE_STUN, ReactionTable.CRACK_SLOW * 100.0,
				ReactionTable.CRACK_DURATION]
		_:
			return ""

func _codex_formations(parent: VBoxContainer) -> void:
	_codex_heading(parent, "⬢ VEIN PATTERNS — vein layout matters")
	for id in FormationDetector.ALL_IDS:
		_codex_row(parent, FormationDetector.display_name(str(id)),
			Color(0.6, 0.9, 1.0), FormationDetector.describe(str(id)))
	_codex_row(parent, "Bagua", Color(1.0, 0.95, 0.75),
		"With %d different elements on the board: %.0f%% of reactions upgrade to PRIMAL - a %.0f%% blast within %.1fm."
		% [ElementTypes.ALL.size(), ReactionTable.PRIMAL_CHANCE * 100.0,
			ReactionTable.PRIMAL_MULT * 100.0, ReactionTable.PRIMAL_RADIUS])

func _codex_tile_levels(parent: VBoxContainer) -> void:
	_codex_heading(parent, "◈ VEIN LEVELS — place a matching vein on itself to upgrade")
	var names: Array[String] = ["Lv1 Vein", "Lv2 Source", "Lv3 Ley Line"]
	for i in range(TerritoryManager.LEVEL_BONUS.size()):
		var bonus: Dictionary = TerritoryManager.LEVEL_BONUS[i]
		var parts: PackedStringArray = []
		var mark_bonus := float(bonus.get("mark_duration_bonus", 0.0))
		if mark_bonus > 0.0:
			parts.append("Mark +%.0fs" % mark_bonus)
		var reaction := float(bonus.get("reaction_mult", 1.0))
		if reaction > 1.001:
			parts.append("reaction ×%.2f" % reaction)
		var damage := float(bonus.get("tower_damage_pct", 0.0))
		if damage > 0.0:
			parts.append("piece on square +%.0f%% damage" % (damage * 100.0))
		if parts.is_empty():
			parts.append("gắn Dấu tiêu chuẩn")
		_codex_row(parent, names[i] if i < names.size() else "Lv%d" % (i + 1),
			UIStyle.GOLD, " · ".join(parts))
