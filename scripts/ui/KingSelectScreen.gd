# res://scripts/ui/KingSelectScreen.gd
# Màn hình chọn Vua trước khi bắt đầu ván chơi.
extends Control
class_name KingSelectScreen

# --- SIGNALS ---
signal king_confirmed(king: KingStats)

# --- THAM CHIẾU NODE ---
@onready var king_grid: GridContainer = $KingGrid           # Lưới hiển thị các vua
@onready var portrait_display: TextureRect = $DetailPanel/Portrait
@onready var name_label: Label = $DetailPanel/NameLabel
@onready var lore_label: Label = $DetailPanel/LoreLabel
@onready var ability_label: Label = $DetailPanel/AbilityLabel
@onready var favor_label: Label = $DetailPanel/FavorLabel
@onready var army_preview: HBoxContainer = $DetailPanel/ArmyPreview
@onready var confirm_button: Button = $DetailPanel/ConfirmButton
@onready var locked_label: Label = $DetailPanel/LockedLabel

# --- DỮ LIỆU ---
@export var all_kings: Array[Resource] = []     # Tất cả KingStats resources

var selected_king: KingStats = null
var meta_progress: MetaProgress = null

func _ready() -> void:
	meta_progress = MetaProgress.load_or_create()
	_populate_king_grid()
	confirm_button.pressed.connect(_on_confirm_pressed)

func _populate_king_grid() -> void:
	# TODO: Tạo KingCard button cho mỗi vua
	for king_res in all_kings:
		var king = king_res as KingStats
		var card = _create_king_card(king)
		king_grid.add_child(card)

func _create_king_card(king: KingStats) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 100)
	# TODO: Thêm portrait, tên, icon khóa nếu chưa unlock
	var is_unlocked = king.id in meta_progress.unlocked_king_ids or king.is_starter_king
	btn.disabled = not is_unlocked
	btn.pressed.connect(func(): _on_king_card_selected(king))
	return btn

func _on_king_card_selected(king: KingStats) -> void:
	selected_king = king
	_update_detail_panel(king)

func _update_detail_panel(king: KingStats) -> void:
	if king.portrait:
		portrait_display.texture = king.portrait
	name_label.text = king.king_name
	lore_label.text = king.lore
	ability_label.text = "Kỹ năng: %s\n%s" % [king.ability_name, king.ability_description]
	favor_label.text = "Ưu tiên: %s" % ", ".join(king.favored_unit_types)
	# TODO: Hiển thị preview army
	confirm_button.disabled = false

func _on_confirm_pressed() -> void:
	if selected_king:
		king_confirmed.emit(selected_king)
		GameManagerSingleton.start_run(selected_king)
