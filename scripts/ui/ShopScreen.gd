# res://scripts/ui/ShopScreen.gd
# Giao diện cửa hàng (Shop).
extends Control
class_name ShopScreen

# --- THAM CHIẾU NODE ---
@onready var item_container: HBoxContainer = $ItemContainer   # Chứa các ShopItemCard
@onready var reroll_button: Button = $BottomBar/RerollButton
@onready var close_button: Button = $BottomBar/CloseButton
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var reroll_cost_label: Label = $BottomBar/RerollCostLabel

# --- THAM CHIẾU MANAGER ---
var shop_manager: ShopPanelManager = null

func _ready() -> void:
	reroll_button.pressed.connect(_on_reroll_pressed)
	close_button.pressed.connect(_on_close_pressed)
	GameManagerSingleton.gold_changed.connect(_on_gold_changed)

func open(manager: ShopPanelManager) -> void:
	shop_manager = manager
	shop_manager.shop_offers_refreshed.connect(_on_shop_refreshed)
	_on_shop_refreshed(manager.get_items())
	gold_label.text = "Vàng: %d" % GameManagerSingleton.gold
	visible = true

func close() -> void:
	visible = false
	if shop_manager and shop_manager.shop_offers_refreshed.is_connected(_on_shop_refreshed):
		shop_manager.shop_offers_refreshed.disconnect(_on_shop_refreshed)

func _on_shop_refreshed(items: Array) -> void:
	# Xóa item cũ
	for child in item_container.get_children():
		child.queue_free()
	# Tạo card mới
	for item in items:
		var card = _create_item_card(item)
		item_container.add_child(card)

func _create_item_card(item: ShopItemData) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(110, 150)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var name_label = Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cost_label = Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buy_btn = Button.new()

	var currency_suffix := " G"
	match item.item_type:
		ShopItemData.ItemType.TROOP:
			if item.icon:
				icon.texture = item.icon
			elif item.tower_stats and item.tower_stats.texture:
				icon.texture = item.tower_stats.texture
			name_label.text = item.display_name
			currency_suffix = " RD" if item.use_royal_decree else " G"
			cost_label.text = str(item.cost) + currency_suffix
		ShopItemData.ItemType.TERRITORY:
			if item.icon:
				icon.texture = item.icon
			name_label.text = item.display_name
			cost_label.text = str(item.cost) + " RD"
		ShopItemData.ItemType.UPGRADE:
			if item.icon:
				icon.texture = item.icon
			elif item.tower_stats and item.tower_stats.texture:
				icon.texture = item.tower_stats.texture
			var label_text = item.display_name
			if item.upgrade_description != "":
				label_text += "\n(%s)" % item.upgrade_description
			name_label.text = label_text
			currency_suffix = " RD" if item.use_royal_decree else " G"
			cost_label.text = str(item.cost) + currency_suffix
		ShopItemData.ItemType.DISMISS:
			if item.icon:
				icon.texture = item.icon
			name_label.text = item.display_name
			cost_label.text = "Giải tán: +%dG" % item.dismiss_reward

	buy_btn.text = "Mua"
	buy_btn.pressed.connect(func(): _attempt_purchase(item))
	for node in [icon, name_label, cost_label, buy_btn]:
		vbox.add_child(node)
	return card

func _on_reroll_pressed() -> void:
	if shop_manager:
		shop_manager.refresh_shop()

func _on_close_pressed() -> void:
	close()

func _attempt_purchase(item: ShopItemData) -> void:
	if not shop_manager:
		return
	var map_node = shop_manager.get_parent()
	if not map_node:
		return
	var king = map_node.get_node_or_null("KingManager") as KingManager
	if not king:
		return
	shop_manager.attempt_purchase(item.id, king)

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Vàng: " + str(new_gold)
