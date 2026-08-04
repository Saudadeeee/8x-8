# res://scripts/ui/hud/hud_boss.gd
#
# THANH MÁU BOSS + màn giới thiệu boss — tách khỏi game_hud.gd.
# API CỐ ĐỊNH cho hệ boss gọi vào (qua HUD): show_boss_bar / update_boss_bar /
# hide_boss_bar / show_boss_intro. Mọi hàm chịu được gọi sai thứ tự
# (update trước show, hide khi chưa show) mà không crash.
extends Node
class_name HudBoss

var hud: CanvasLayer = null

var _boss_panel: PanelContainer = null
var _boss_name_label: Label = null
var _boss_hp_label: Label = null
var _boss_bar: ProgressBar = null
var _boss_max_hp: int = 1
var _boss_phase: int = 0
var _boss_intro_overlay: Control = null

## Màu thanh máu boss theo pha: P1 đỏ máu · P2 cam · P3 vàng cháy.
const BOSS_PHASE_COLORS: Array[Color] = [
	Color(0.85, 0.13, 0.13, 1.0),
	Color(1.00, 0.52, 0.10, 1.0),
	Color(1.00, 0.82, 0.16, 1.0),
]
const BOSS_INTRO_SECONDS: float = 2.0

static func attach(owner_hud: CanvasLayer) -> HudBoss:
	var c := HudBoss.new()
	c.name = "HudBoss"
	c.hud = owner_hud
	owner_hud.add_child(c)
	c._build_boss_bar()
	return c

# ── Boss bar ──────────────────────────────────────────────────────────────────
# API CỐ ĐỊNH cho hệ boss gọi vào: show_boss_bar / update_boss_bar /
# hide_boss_bar / show_boss_intro. Mọi hàm chịu được gọi sai thứ tự (update
# trước show, hide khi chưa show) mà không crash.

## Cờ đã cảnh báo "update khi chưa show" — chỉ warn 1 lần, tránh spam mỗi frame.
var _boss_warned_no_bar: bool = false

## Dựng sẵn panel thanh máu boss (ẩn). Nằm ngang phía TRÊN màn hình, dưới vùng
## banner wave (banner ở giữa màn hình) và dưới combo meter.
func _build_boss_bar() -> void:
	var root_ctrl := hud.get_node_or_null("Control") as Control
	if root_ctrl == null:
		return
	_boss_panel = PanelContainer.new()
	_boss_panel.name = "BossBarPanel"
	_boss_panel.anchor_left   = 0.5
	_boss_panel.anchor_right  = 0.5
	_boss_panel.anchor_top    = 0.0
	_boss_panel.anchor_bottom = 0.0
	_boss_panel.offset_left   = -320
	_boss_panel.offset_right  = 320
	_boss_panel.offset_top    = 100
	_boss_panel.offset_bottom = 164
	_boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_theme_stylebox_override(
		"panel", UIStyle.panel_tinted("stone", UIStyle.BLOOD))
	UIStyle.pixel_filter(_boss_panel)
	_boss_panel.visible = false
	root_ctrl.add_child(_boss_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_boss_name_label = Label.new()
	_boss_name_label.name = "BossName"
	_boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.title(_boss_name_label, 22, UIStyle.GOLD)
	header.add_child(_boss_name_label)

	_boss_hp_label = Label.new()
	_boss_hp_label.name = "BossHP"
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.body(_boss_hp_label, 14, UIStyle.TEXT)
	header.add_child(_boss_hp_label)

	_boss_bar = UIStyle.make_bar(BOSS_PHASE_COLORS[0], 18)
	_boss_bar.name = "BossHealthBar"
	_boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_boss_bar)

## Hiện thanh máu boss với tên + máu tối đa. Gọi lại khi đổi boss cũng an toàn.
func show_boss_bar(boss_name: String, max_hp: int) -> void:
	if not is_instance_valid(_boss_panel):
		_build_boss_bar()
	if not is_instance_valid(_boss_panel):
		push_warning("game_hud: không dựng được boss bar (thiếu node Control).")
		return
	_boss_max_hp = maxi(1, max_hp)
	_boss_phase = 0            # 0 = chưa có pha → update đầu tiên sẽ set màu
	_boss_warned_no_bar = false
	if is_instance_valid(_boss_name_label):
		_boss_name_label.text = "☠  %s" % (boss_name if boss_name != "" else "BOSS")
	if is_instance_valid(_boss_hp_label):
		_boss_hp_label.text = "%d / %d" % [_boss_max_hp, _boss_max_hp]
	if is_instance_valid(_boss_bar):
		UIStyle.set_bar_color(_boss_bar, BOSS_PHASE_COLORS[0])
		_boss_bar.set_meta("_ui_bar_target", 1.0)
		_boss_bar.value = 1.0
	# Đếm ngược prep dùng chung dải y này — boss chỉ xuất hiện trong wave nên
	# tắt luôn cho khỏi chồng chữ (prep sau sẽ tự bật lại qua update_prep_countdown).
	hud.set_prep_countdown_visible(false)
	_boss_panel.visible = true
	_boss_panel.modulate = Color(1, 1, 1, 1)
	UIStyle.pop_in(_boss_panel)

## Cập nhật máu boss (tween mượt) + đổi màu theo pha (1 đỏ · 2 cam · 3 vàng).
## Gọi khi chưa show_boss_bar: bỏ qua yên lặng (chỉ warn một lần).
func update_boss_bar(hp: int, phase: int = 1) -> void:
	if not is_instance_valid(_boss_panel) or not _boss_panel.visible:
		if not _boss_warned_no_bar:
			_boss_warned_no_bar = true
			push_warning("game_hud: update_boss_bar gọi khi chưa show_boss_bar — bỏ qua.")
		return
	var clamped_hp: int = clampi(hp, 0, _boss_max_hp)
	var ratio: float = float(clamped_hp) / float(maxi(1, _boss_max_hp))
	if is_instance_valid(_boss_bar):
		UIStyle.tween_bar(_boss_bar, ratio, 0.25)
	if is_instance_valid(_boss_hp_label):
		_boss_hp_label.text = "%d / %d" % [clamped_hp, _boss_max_hp]
	var phase_index: int = clampi(phase, 1, BOSS_PHASE_COLORS.size()) - 1
	if phase != _boss_phase:
		_boss_phase = phase
		var col: Color = BOSS_PHASE_COLORS[phase_index]
		if is_instance_valid(_boss_bar):
			UIStyle.set_bar_color(_boss_bar, col)
		_boss_panel.add_theme_stylebox_override(
			"panel", UIStyle.panel_tinted("stone", col.darkened(0.42)))
		if is_instance_valid(_boss_name_label):
			UIStyle.flash_color(_boss_name_label, Color(1, 1, 1, 1), UIStyle.GOLD, 0.12)
		UIStyle.pulse(_boss_panel, 1.06)
		hud._play_sfx("wave_start", -4.0)

## Ẩn thanh máu boss (fade nhẹ rồi tắt). Gọi khi chưa show cũng không sao.
func hide_boss_bar() -> void:
	_boss_warned_no_bar = false
	if not is_instance_valid(_boss_panel) or not _boss_panel.visible:
		return
	var panel := _boss_panel
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.30)
	t.tween_callback(func() -> void:
		if is_instance_valid(panel):
			panel.visible = false
			panel.modulate.a = 1.0)

## Màn giới thiệu boss ~2 giây: nền tối, tên cực lớn + phụ đề, tự đóng.
## KHÔNG chặn chuột (mouse_filter IGNORE) và luôn tự huỷ — gọi chồng thì màn
## cũ bị dọn trước.
## [br]Tham số [param name] trùng tên thuộc tính Node là CỐ Ý — API đã chốt với
## hệ boss, không được đổi.
@warning_ignore("shadowed_variable_base_class")
func show_boss_intro(name: String, title: String) -> void:
	var root_ctrl := hud.get_node_or_null("Control") as Control
	if root_ctrl == null:
		push_warning("game_hud: không hiện được boss intro (thiếu node Control).")
		return
	_free_boss_intro()

	var overlay := UIStyle.dim_overlay(0.5)
	overlay.name = "BossIntroOverlay"
	# Không bao giờ khoá input — intro chỉ là lớp trang trí
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ctrl.add_child(overlay)
	_boss_intro_overlay = overlay

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 6)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var sub_top := Label.new()
	sub_top.text = "☠  A MIGHTY FOE APPEARS  ☠"
	sub_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.title(sub_top, 22, UIStyle.BLOOD.lightened(0.35))
	center.add_child(sub_top)

	var name_lbl := Label.new()
	name_lbl.text = name if name != "" else "BOSS"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.title(name_lbl, 82, UIStyle.GOLD)
	center.add_child(name_lbl)

	if title != "":
		var title_lbl := Label.new()
		title_lbl.text = title
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIStyle.body(title_lbl, 24, UIStyle.TEXT)
		center.add_child(title_lbl)

	UIStyle.pop_in(name_lbl)
	UIStyle.pop_in(sub_top, 0.06)
	UIStyle.pulse(name_lbl, 1.14)
	hud._play_sfx("wave_start")

	# Timer bỏ qua time_scale → intro luôn ~2 giây thật, kể cả khi đang chạy 3×.
	var tree := get_tree()
	if tree == null:
		_free_boss_intro()
		return
	var timer := tree.create_timer(BOSS_INTRO_SECONDS, true, false, true)
	timer.timeout.connect(_on_boss_intro_timeout.bind(overlay))

## Đóng intro — chỉ dọn đúng overlay đã hẹn giờ (gọi chồng không xoá nhầm cái mới).
func _on_boss_intro_timeout(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	if _boss_intro_overlay != overlay:
		overlay.queue_free()
		return
	var t := create_tween()
	t.tween_property(overlay, "modulate:a", 0.0, 0.35)
	t.tween_callback(func() -> void:
		if _boss_intro_overlay == overlay:
			_boss_intro_overlay = null
		if is_instance_valid(overlay):
			overlay.queue_free())

func _free_boss_intro() -> void:
	if is_instance_valid(_boss_intro_overlay):
		var old := _boss_intro_overlay
		var parent := old.get_parent()
		if parent:
			parent.remove_child(old)
		old.queue_free()
	_boss_intro_overlay = null

# ==============================================================================
