# res://scripts/elements/element_types.gd
# Nguồn sự thật DUY NHẤT cho hệ nguyên tố.
#
# Nguyên tắc thiết kế (xem futureplan.md §2): nguyên tố KHÔNG thuộc về loại tháp.
# Tháp lấy nguyên tố từ Ô NGUYÊN TỐ mà nó đang đứng. Không có "tháp Hoả" — chỉ có
# "tháp đang đứng trên Mạch Hoả".
class_name ElementTypes
extends Object

const NONE  := ""
const FIRE  := "fire"
const ICE   := "ice"
const THUNDER := "thunder"
const WATER := "water"
const POISON := "poison"
const EARTH := "earth"

const ALL: Array[String] = [FIRE, ICE, THUNDER, WATER, POISON, EARTH]

## Thông số Dấu (mark) mỗi nguyên tố để lại trên địch.
## dps/slow chỉ là hiệu ứng NỀN — sức mạnh thật nằm ở phản ứng khi ghép 2 Dấu.
const SPEC: Dictionary = {
	FIRE: {
		"name": "Fire", "icon": "H", "emoji": "", "color": Color("ff6a12"),
		"dps": 12.0, "slow": 0.0, "duration": 4.0,
		"pierce_armor": false, "stacking": false,
		"desc": "Burns for 12 damage/sec",
	},
	ICE: {
		"name": "Ice", "icon": "B", "emoji": "❄", "color": Color("8fd0ee"),
		"dps": 0.0, "slow": 0.35, "duration": 3.0,
		"pierce_armor": false, "stacking": false,
		"desc": "Slows by 35%",
	},
	THUNDER: {
		"name": "Thunder", "icon": "L", "emoji": "", "color": Color("c86aff"),
		"dps": 8.0, "slow": 0.0, "duration": 4.0,
		"pierce_armor": true, "stacking": false,
		"desc": "Shocks for 8 damage/sec, ignores armor",
	},
	WATER: {
		"name": "Water", "icon": "N", "emoji": "", "color": Color("3a7ab0"),
		"dps": 0.0, "slow": 0.0, "duration": 5.0,
		"pierce_armor": false, "stacking": false,
		"amplify_from": [ICE, THUNDER], "amplify_pct": 0.20,
		"desc": "Wet: +20% Ice/Thunder damage. Deals no damage on its own",
	},
	POISON: {
		"name": "Poison", "icon": "P", "emoji": "☠", "color": Color("66e03a"),
		"dps": 6.0, "slow": 0.0, "duration": 8.0,
		"pierce_armor": false, "stacking": true, "max_stacks": 5,
		"desc": "6 damage/sec, stacks up to 5 times",
	},
	EARTH: {
		"name": "Earth", "icon": "T", "emoji": "", "color": Color("8a7550"),
		"dps": 0.0, "slow": 0.25, "duration": 5.0,
		"pierce_armor": false, "stacking": false,
		"desc": "Slows by 25%; slain enemies drop gold shards",
	},
}

const DEFAULT_MAX_MARKS: int = 2

static func spec(element: String) -> Dictionary:
	return SPEC.get(element, {})

static func is_valid(element: String) -> bool:
	return element != NONE and SPEC.has(element)

static func display_name(element: String) -> String:
	return str(SPEC.get(element, {}).get("name", "—"))

## Ký hiệu 1 chữ cái — font mặc định Godot KHÔNG có emoji, dùng emoji sẽ ra ô vuông.
## Phân biệt bằng MÀU (color_of) chứ không bằng hình.
static func icon(element: String) -> String:
	return str(SPEC.get(element, {}).get("icon", ""))

## Emoji cho tài liệu/tooltip — chỉ dùng khi đã gắn font có emoji.
static func emoji(element: String) -> String:
	return str(SPEC.get(element, {}).get("emoji", ""))

static func color_of(element: String) -> Color:
	return SPEC.get(element, {}).get("color", Color.WHITE)

static func duration_of(element: String) -> float:
	return float(SPEC.get(element, {}).get("duration", 4.0))
