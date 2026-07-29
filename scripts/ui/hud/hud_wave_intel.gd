# res://scripts/ui/hud/hud_wave_intel.gd
#
# POPUP TRINH SÁT WAVE — bảng địch sắp tới trong pha chuẩn bị (loài, số lượng,
# năng lực, nguyên tố khắc/kháng). Tách khỏi game_hud.gd.
extends Node
class_name HudWaveIntel

var hud: CanvasLayer = null

static func attach(owner_hud: CanvasLayer) -> HudWaveIntel:
	var c := HudWaveIntel.new()
	c.name = "HudWaveIntel"
	c.hud = owner_hud
	owner_hud.add_child(c)
	return c

# ── Wave Intel Popup ───────────────────────────────────────────────────────────

## "▲Hoả ▼Thổ" — nguyên tố khắc chế / bị kháng của một loài.
## Đọc từ EnemyStats.DEFAULT_AFFINITY nên thêm loài mới là bảng tự có.
func _affinity_text(enemy_id: String) -> String:
	var row: Variant = EnemyStats.DEFAULT_AFFINITY.get(enemy_id)
	if not (row is Array) or (row as Array).size() < 2:
		return "—"
	var weak := ElementTypes.display_name(str(row[0]))
	if (row as Array).size() >= 3:
		weak += "/" + ElementTypes.display_name(str(row[2]))
	return "▲%s  ▼%s" % [weak, ElementTypes.display_name(str(row[1]))]

var _intel_popup: PopupPanel = null

func show_wave_intel_popup(data: Dictionary) -> void:
	if _intel_popup and is_instance_valid(_intel_popup):
		_intel_popup.queue_free()
	_intel_popup = PopupPanel.new()
	_intel_popup.name = "WaveIntelPopup"
	_intel_popup.exclusive = false

	var root_ctrl = hud.get_node_or_null("Control")
	if not root_ctrl:
		return
	root_ctrl.add_child(_intel_popup)

	# Bọc nội dung trong PanelContainer giấy da để popup có khối, không phẳng
	var frame = PanelContainer.new()
	frame.name = "IntelFrame"
	UIStyle.apply_panel(frame, "parchment")
	_intel_popup.add_child(frame)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	frame.add_child(vbox)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = "⚔  TRINH SÁT — WAVE %d" % data.get("wave", 0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(title_lbl, 22, UIStyle.GOLD)
	vbox.add_child(title_lbl)

	# Season
	var season_lbl = Label.new()
	season_lbl.text = "%s  |  %s" % [data.get("season_name", ""), data.get("season_desc", "")]
	season_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.body(season_lbl, 12, Color(0.8, 0.9, 1.0, 1.0))
	season_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(season_lbl)

	# Biome hiện tại — bỏ qua dòng này nếu chưa có hệ biome nào được áp
	var biome_line: String = hud._biome_intel_line(data)
	if biome_line != "":
		var biome_lbl = Label.new()
		biome_lbl.text = biome_line
		biome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.body(biome_lbl, 12, UIStyle.GREEN)
		biome_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(biome_lbl)

	vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))

	# Header row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)
	for col_text in ["Quân địch", "SL", "HP", "Tốc độ", "Dmg", "Khắc / Kháng", "Năng lực"]:
		var h = Label.new()
		h.text = col_text
		UIStyle.body(h, 11, UIStyle.TEXT_DIM)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(h)

	vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))

	# Enemy rows
	var enemies: Array = data.get("enemies", [])
	var enemy_index := 0
	for e in enemies:
		var row_holder = PanelContainer.new()
		row_holder.add_theme_stylebox_override(
			"panel", UIStyle.flat_inset(Color(0.0, 0.0, 0.0, 0.26), Color(0.0, 0.0, 0.0, 0.42), 2))
		vbox.add_child(row_holder)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_holder.add_child(row)
		UIStyle.pop_in(row_holder, 0.06 + enemy_index * 0.035)
		enemy_index += 1

		var cols = [
			e.get("display", "?"),
			"×%d" % e.get("count", 0),
			str(e.get("hp", 0)),
			# speed trong .tres vẫn là px/s (16 px = 1 ô) — chỉ quy đổi khi hiển thị
			"%.1f ô/s" % (float(e.get("speed", 0)) / 16.0),
			"-%d HP" % e.get("damage", 1),
			# Cột khắc/kháng — thứ quyết định NÊN ĐẶT THÁP LÊN Ô NÀO cho wave này.
			_affinity_text(str(e.get("id", ""))),
			str(e.get("note", EnemyStats.ABILITY_NOTES.get(e.get("id", ""), "—"))),
		]
		var col_colors = [UIStyle.TEXT, UIStyle.GREEN, Color(1.0, 0.4, 0.4), Color(0.4, 0.9, 1.0), UIStyle.RED,
			Color(1.0, 0.85, 0.35), UIStyle.TEXT_DIM]
		for i in cols.size():
			var lbl = Label.new()
			lbl.text = cols[i]
			UIStyle.body(lbl, 12, col_colors[i])
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)

	vbox.add_child(UIStyle.separator(UIStyle.HUD_BORDER))

	# Total
	var total_lbl = Label.new()
	total_lbl.text = "Tổng: %d địch phải tiêu diệt" % data.get("total", 0)
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.title(total_lbl, 15, UIStyle.TEXT)
	vbox.add_child(total_lbl)

	# Close button — xác nhận bắt đầu countdown
	var close_btn = Button.new()
	close_btn.text = "⚔  SẴN SÀNG CHIẾN ĐẤU!"
	close_btn.custom_minimum_size = Vector2(260, 46)
	UIStyle.apply_button_accent(close_btn, UIStyle.RED, 15)
	close_btn.pressed.connect(func():
		_intel_popup.hide()
		var map = hud._find_game_map()
		if map and map.has_method("confirm_wave_ready"):
			map.confirm_wave_ready()
	)
	vbox.add_child(close_btn)

	# Nếu player đóng popup bằng cách khác, cũng confirm
	_intel_popup.popup_hide.connect(func():
		var map = hud._find_game_map()
		if map and map.has_method("confirm_wave_ready"):
			map.confirm_wave_ready()
	, CONNECT_ONE_SHOT)

	# Popup PHẢI co theo nội dung. `popup_centered()` không truyền kích thước thì
	# Window tự phình (đo được 580×2064 trong khi nội dung chỉ cao 336). Đo
	# minimum size của khung rồi truyền THẲNG vào popup_centered — gán `size`
	# trước lời gọi không có tác dụng vì popup_centered ghi đè.
	_intel_popup.min_size = Vector2i(580, 0)
	_intel_popup.popup_centered(Vector2i(580, 400))
	# Đo SAU một frame: ngay lúc vừa dựng, Label autowrap chưa xuống dòng nên
	# minimum size báo ~2056 thay vì 336 — popup sẽ dài hết màn hình.
	_resize_to_content(frame)

## Co popup vừa đúng nội dung. Tách hàm vì phải `await`, mà nơi gọi không phải
## coroutine.
func _resize_to_content(frame: Control) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	await hud.get_tree().process_frame
	await hud.get_tree().process_frame
	if not is_instance_valid(_intel_popup) or not is_instance_valid(frame):
		return
	var want: Vector2 = frame.get_combined_minimum_size()
	var w: int = maxi(580, int(want.x) + 24)
	var h: int = int(want.y) + 24
	_intel_popup.min_size = Vector2i(w, h)
	_intel_popup.size = Vector2i(w, h)
	# Căn giữa lại thủ công vì popup_centered() đã chạy với kích thước cũ.
	var screen := DisplayServer.window_get_size()
	_intel_popup.position = Vector2i((screen.x - w) / 2, (screen.y - h) / 2)
	UIStyle.pop_in(frame)

## Đóng popup. Cần vì PopupPanel là Window nên vẽ ĐÈ lên mọi CanvasLayer —
## để nó mở khi draft perk hiện ra thì người chơi không thấy thẻ perk nào.
func hide_popup() -> void:
	if is_instance_valid(_intel_popup):
		_intel_popup.hide()
