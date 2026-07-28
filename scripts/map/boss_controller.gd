# res://scripts/map/boss_controller.gd
#
# BOSS (Rival King) — nối thanh máu HUD, theo dõi pha, và trao thưởng khi hạ.
# Tách khỏi game_map.gd để file đó không phình; game_map giữ các hàm uỷ quyền
# cùng tên nên WaveSpawner và HUD không phải đổi gì.
#
# Mọi call HUD đều guard `has_method`: HUD chưa có API boss thì boss vẫn đánh
# bình thường, chỉ thiếu thanh máu.
extends Node
class_name BossController

## game_map — nguồn của vàng, HUD, territory_manager…
var map: Node3D = null

var _active_boss: Node = null
var _boss_last_hp: int = -1
var _boss_phase: int = 1

static func attach(owner_map: Node3D) -> BossController:
	var c := BossController.new()
	c.name = "BossController"
	c.map = owner_map
	owner_map.add_child(c)
	return c

## game_map._process gọi mỗi frame.
func tick() -> void:
	_sync_boss_bar()

## Có boss đang sống trên sân không.
func has_active_boss() -> bool:
	return _active_boss != null and is_instance_valid(_active_boss)


## WaveSpawner báo boss ra sân. Mọi call HUD đều guard has_method: HUD chưa có
## API boss thì boss vẫn đánh bình thường, chỉ thiếu thanh máu.
func _on_boss_spawned(boss: Node) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	_active_boss  = boss
	_boss_phase   = 1
	_boss_last_hp = -1

	# connect() theo tên signal — tránh truy cập member không có trên base Node
	if boss.has_signal("boss_phase_changed"):
		boss.connect("boss_phase_changed", _on_boss_phase_changed)
	if boss.has_signal("boss_defeated"):
		boss.connect("boss_defeated", _on_boss_defeated)

	var boss_name: String = str(boss.call("get_display_name")) if boss.has_method("get_display_name") else "Rival King"
	var boss_title: String = str(boss.call("get_title")) if boss.has_method("get_title") else ""
	var max_hp: int = int(boss.call("get_max_hp")) if boss.has_method("get_max_hp") else int(boss.get("current_hp"))

	var hud := map.get_node_or_null("HUD")
	if hud:
		if hud.has_method("show_boss_intro"): hud.show_boss_intro(boss_name, boss_title)
		if hud.has_method("show_boss_bar"):   hud.show_boss_bar(boss_name, max_hp)

	map.phase_controller.phase_message = "☠ %s đã xuất trận! Hạ hắn để thống nhất vương quốc." % boss_name
	map.update_ui()

## Bơm HP vào thanh máu HUD — chỉ gọi khi máu ĐỔI để không tốn frame budget.
func _sync_boss_bar() -> void:
	if _active_boss == null:
		return
	if not is_instance_valid(_active_boss):
		_clear_boss_ui()   # boss lọt qua King / bị dọn khi expand
		return
	var hp: int = int(_active_boss.get("current_hp"))
	if hp == _boss_last_hp:
		return
	_boss_last_hp = hp
	var hud := map.get_node_or_null("HUD")
	if hud and hud.has_method("update_boss_bar"):
		hud.update_boss_bar(maxi(hp, 0), _boss_phase)

func _on_boss_phase_changed(phase: int) -> void:
	_boss_phase   = phase
	_boss_last_hp = -1   # ép cập nhật ngay frame sau để HUD đổi màu theo pha
	map.phase_controller.phase_message = "☠ Rival King bước sang PHA %d — hắn mạnh hơn!" % phase
	map.update_ui()

func _on_boss_defeated() -> void:
	map.current_gold += map.BOSS_BONUS_GOLD
	if map._game_manager:
		map._game_manager.run_gold_earned += map.BOSS_BONUS_GOLD
	var am = get_node_or_null("/root/AudioManagerSingleton")
	if am and am.has_method("play_sfx"):
		am.play_sfx("victory", -2.0)
	_clear_boss_ui()
	# Chiến lợi phẩm: 2 bình thuốc (đặt TRƯỚC dòng thông báo boss để message boss thắng thế).
	for _i in map.BOSS_POTION_DROPS:
		map._grant_random_potion("Rival King")
	map.phase_controller.phase_message = " RIVAL KING ĐÃ GỤC NGÃ! +%d vàng" % map.BOSS_BONUS_GOLD
	map.update_ui()
	_offer_boss_reward()

# ── Chiến lợi phẩm boss: chọn 1 trong 3 (futureplan §6.4) ──────────────────
# Ba lá LUÔN có đúng ba vai: khớp build · đổi hướng · vàng. Đó là cách đảm bảo
# "không lối nào sai": đi đúng hướng thì được thưởng sâu, muốn quay xe thì có
# đường, và kẹt tiền thì vẫn có lối thoát.
const BOSS_REWARD_GOLD: int = 250
const BOSS_REWARD_TILES: int = 2

func _offer_boss_reward() -> void:
	var hud := map.get_node_or_null("HUD")
	if hud == null or not hud.has_method("show_perk_draft"):
		return   # không có UI → thưởng vàng đã cộng ở trên, không mất gì
	var choices: Array = []

	var dominant: String = map._dominant_element()
	if dominant.is_empty():
		dominant = ElementTypes.ALL[randi() % ElementTypes.ALL.size()]
	choices.append({
		"id": "boss_tile_%s" % dominant,
		"name": "Long Mạch %s" % ElementTypes.display_name(dominant),
		"desc": "Nhận %d ô %s — đặt chồng lên nhau để lên Lv2 ngay." % [
			BOSS_REWARD_TILES, ElementTypes.display_name(dominant)],
		"rarity": "epic", "icon": ElementTypes.icon(dominant),
	})

	# Lá đổi hướng: di vật (đổi luật chơi) — có thì lấy, hết thì thay bằng ô khác hệ.
	var relic_id: String = map.relic_system.roll_random() if map.relic_system else ""
	if relic_id != "" and map.relic_system != null and not map.relic_system.is_full():
		var relic: Dictionary = map.relic_system.relic_data(relic_id)
		choices.append({
			"id": "boss_relic_%s" % relic_id,
			"name": str(relic.get("name", relic_id)),
			"desc": str(relic.get("desc", "")),
			"rarity": "legendary", "icon": "★",
		})
	else:
		var other := _other_element(dominant)
		choices.append({
			"id": "boss_tile_%s" % other,
			"name": "Mạch %s" % ElementTypes.display_name(other),
			"desc": "Nhận %d ô %s — mở hướng đi mới." % [
				BOSS_REWARD_TILES, ElementTypes.display_name(other)],
			"rarity": "rare", "icon": ElementTypes.icon(other),
		})

	choices.append({
		"id": "boss_gold",
		"name": "Kho Báu Chiến Tranh",
		"desc": "+%d vàng ngay lập tức." % BOSS_REWARD_GOLD,
		"rarity": "rare", "icon": "⛁",
	})

	hud.show_perk_draft(choices, _apply_boss_reward)

func _other_element(exclude: String) -> String:
	for element in ElementTypes.ALL:
		if element != exclude:
			return element
	return ElementTypes.FIRE

## Áp phần thưởng boss theo id lá đã chọn. Id mã hoá luôn loại + tham số nên
## không cần giữ state giữa lúc mở UI và lúc người chơi bấm.
func _apply_boss_reward(choice_id: String) -> void:
	var hud := map.get_node_or_null("HUD")
	if hud and hud.has_method("hide_perk_draft"):
		hud.hide_perk_draft()

	if choice_id == "boss_gold":
		map.current_gold += BOSS_REWARD_GOLD
		if map._game_manager:
			map._game_manager.run_gold_earned += BOSS_REWARD_GOLD
		map.phase_controller.phase_message = "⛁ Kho Báu Chiến Tranh: +%d vàng!" % BOSS_REWARD_GOLD
	elif choice_id.begins_with("boss_relic_"):
		var relic_id := choice_id.substr("boss_relic_".length())
		if map.relic_system and map.relic_system.add_relic(relic_id):
			map.phase_controller.phase_message = "★ Nhận di vật: %s" % \
				str(map.relic_system.relic_data(relic_id).get("name", relic_id))
	elif choice_id.begins_with("boss_tile_"):
		var element := choice_id.substr("boss_tile_".length())
		var biome: String = TerritoryManager.biome_of_element(element)
		if biome != "" and map.territory_manager:
			for _i in range(BOSS_REWARD_TILES):
				map.territory_manager.add_stock(biome)
			map.phase_controller.phase_message = "✦ Nhận %d ô %s!" % [
				BOSS_REWARD_TILES, ElementTypes.display_name(element)]
	map.update_ui()

func _clear_boss_ui() -> void:
	_active_boss  = null
	_boss_last_hp = -1
	var hud := map.get_node_or_null("HUD")
	if hud and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()
