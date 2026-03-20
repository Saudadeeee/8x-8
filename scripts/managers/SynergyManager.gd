# res://scripts/managers/SynergyManager.gd
# Quản lý hệ thống Synergy: ≥N quân cùng loại → buff toàn cục.
extends Node
class_name SynergyManager

signal synergy_activated(synergy_id: String, level: int)
signal synergy_deactivated(synergy_id: String)
signal buffs_updated()

# SynergyDefinition resources — điền tự động trong _ready() nếu rỗng
@export var synergy_definitions: Array[Resource] = []

# Runtime
var active_synergies: Dictionary = {}          # tag → { count, active_level }
var soldier_synergy_map: Dictionary = {}       # tower_node → Array[String] tags
var _def_map: Dictionary = {}                  # tag → SynergyDefinition (cache)

func _ready() -> void:
	_ensure_default_definitions()
	for res in synergy_definitions:
		var def = res as SynergyDefinition
		if def:
			_def_map[def.tag] = def

# --- Tạo definitions mặc định nếu không có ---
func _ensure_default_definitions() -> void:
	if synergy_definitions.size() > 0:
		return
	# Thử auto-load từ res://res/synergies/*.tres trước
	_load_definitions_from_directory()
	if synergy_definitions.size() > 0:
		return
	# Fallback: dùng hardcoded defaults
	var defaults = [
		["pawn",   "Pawn Phalanx",    [2,4,6], [
			{"damage_bonus":0.10,"speed_bonus":0.00,"range_bonus":0.0},
			{"damage_bonus":0.20,"speed_bonus":0.05,"range_bonus":0.0},
			{"damage_bonus":0.30,"speed_bonus":0.10,"range_bonus":0.0}]],
		["knight", "Knight Charge",   [2,4],   [
			{"damage_bonus":0.00,"speed_bonus":0.15,"range_bonus":0.0},
			{"damage_bonus":0.10,"speed_bonus":0.25,"range_bonus":0.0}]],
		["rook",   "Rook Fortress",   [2,4],   [
			{"damage_bonus":0.15,"speed_bonus":0.00,"range_bonus":0.0},
			{"damage_bonus":0.30,"speed_bonus":0.00,"range_bonus":0.0}]],
		["bishop", "Bishop Blessing", [2,4],   [
			{"damage_bonus":0.00,"speed_bonus":0.20,"range_bonus":0.0},
			{"damage_bonus":0.00,"speed_bonus":0.40,"range_bonus":0.0}]],
		["queen",  "Queen's Reign",   [1,2],   [
			{"damage_bonus":0.20,"speed_bonus":0.10,"range_bonus":0.0},
			{"damage_bonus":0.40,"speed_bonus":0.20,"range_bonus":0.0}]],
		# --- Faction synergies (towers mới) ---
		["crossbowman","Wild Volley",   [2,4],   [
			{"damage_bonus":0.00,"speed_bonus":0.20,"range_bonus":0.0},
			{"damage_bonus":0.10,"speed_bonus":0.40,"range_bonus":1.0}]],
		["warlock", "Arcane Veil",      [2,3],   [
			{"damage_bonus":0.10,"speed_bonus":0.00,"range_bonus":0.0},
			{"damage_bonus":0.20,"speed_bonus":0.00,"range_bonus":1.0}]],
		["catapult","Iron Barrage",     [2,3],   [
			{"damage_bonus":0.25,"speed_bonus":0.00,"range_bonus":0.0},
			{"damage_bonus":0.50,"speed_bonus":0.00,"range_bonus":0.0}]],
		["dark_mage","Hell's Covenant",[2,3],   [
			{"damage_bonus":0.15,"speed_bonus":0.10,"range_bonus":0.0},
			{"damage_bonus":0.30,"speed_bonus":0.20,"range_bonus":1.0}]],
	]
	for d in defaults:
		var def = SynergyDefinition.new()
		def.tag = d[0]; def.display_name = d[1]
		var t: Array[int] = []; for v in d[2]: t.append(v)
		def.thresholds = t
		var b: Array[Dictionary] = []; for v in d[3]: b.append(v)
		def.bonuses = b
		synergy_definitions.append(def)
		_def_map[def.tag] = def

func _load_definitions_from_directory() -> void:
	var dir = DirAccess.open("res://res/synergies/")
	if not dir:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var def = load("res://res/synergies/" + file) as SynergyDefinition
			if def:
				synergy_definitions.append(def)
		file = dir.get_next()
	dir.list_dir_end()

# --- Đăng ký khi đặt tháp (nhận TowerStats) ---
func on_tower_placed(tower: Node, stats: TowerStats) -> void:
	var tag = TowerStats.UnitType.keys()[stats.type].to_lower()
	soldier_synergy_map[tower] = [tag]
	if not active_synergies.has(tag):
		active_synergies[tag] = {"count": 0, "active_level": 0}
	active_synergies[tag]["count"] += 1
	_recalculate_synergies()

# --- Hủy đăng ký khi xóa tháp ---
func on_tower_removed(tower: Node) -> void:
	if not soldier_synergy_map.has(tower):
		return
	for tag in soldier_synergy_map[tower]:
		if active_synergies.has(tag):
			active_synergies[tag]["count"] -= 1
			if active_synergies[tag]["count"] <= 0:
				active_synergies.erase(tag)
				synergy_deactivated.emit(tag)
	soldier_synergy_map.erase(tower)
	_recalculate_synergies()

# --- Tính lại toàn bộ synergy ---
func _recalculate_synergies() -> void:
	for tag in active_synergies.keys():
		var count: int = active_synergies[tag]["count"]
		var def = _def_map.get(tag) as SynergyDefinition
		if def == null:
			continue
		var new_level = 0
		for i in range(def.thresholds.size()):
			if count >= def.thresholds[i]:
				new_level = i + 1
		var old_level: int = active_synergies[tag]["active_level"]
		active_synergies[tag]["active_level"] = new_level
		if new_level > old_level:
			synergy_activated.emit(tag, new_level)
		elif new_level < old_level and new_level == 0:
			synergy_deactivated.emit(tag)
	buffs_updated.emit()

# --- Lấy tổng buff synergy cho một tháp ---
func get_tower_synergy_buff(tower: Node) -> Dictionary:
	var result = {"damage_bonus": 0.0, "speed_bonus": 0.0, "range_bonus": 0.0}
	if not soldier_synergy_map.has(tower):
		return result
	for tag in soldier_synergy_map[tower]:
		if not active_synergies.has(tag):
			continue
		var level: int = active_synergies[tag]["active_level"]
		if level <= 0:
			continue
		var def = _def_map.get(tag) as SynergyDefinition
		if def == null or level > def.bonuses.size():
			continue
		var bonus = def.bonuses[level - 1]
		result["damage_bonus"] += bonus.get("damage_bonus", 0.0)
		result["speed_bonus"]  += bonus.get("speed_bonus",  0.0)
		result["range_bonus"]  += bonus.get("range_bonus",  0.0)
	return result

# --- Lấy tóm tắt synergy đang active (cho HUD) ---
func get_active_synergy_summary() -> String:
	var lines: Array[String] = []
	for tag in active_synergies.keys():
		var level: int = active_synergies[tag]["active_level"]
		var count: int = active_synergies[tag]["count"]
		if level <= 0:
			continue
		var def = _def_map.get(tag) as SynergyDefinition
		var name_str = def.display_name if def else tag.capitalize()
		lines.append("%s (%d) Lv%d" % [name_str, count, level])
	return "\n".join(lines) if lines.size() > 0 else "None"
