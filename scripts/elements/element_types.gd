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
		"name": "Hoả", "icon": "H", "emoji": "", "color": Color("ff6a12"),
		"dps": 12.0, "slow": 0.0, "duration": 4.0,
		"pierce_armor": false, "stacking": false,
		"desc": "Cháy 12 sát thương/giây",
	},
	ICE: {
		"name": "Băng", "icon": "B", "emoji": "❄", "color": Color("8fd0ee"),
		"dps": 0.0, "slow": 0.35, "duration": 3.0,
		"pierce_armor": false, "stacking": false,
		"desc": "Làm chậm 35%",
	},
	THUNDER: {
		"name": "Lôi", "icon": "L", "emoji": "", "color": Color("c86aff"),
		"dps": 8.0, "slow": 0.0, "duration": 4.0,
		"pierce_armor": true, "stacking": false,
		"desc": "Giật 8 sát thương/giây, bỏ qua giáp",
	},
	WATER: {
		"name": "Thuỷ", "icon": "N", "emoji": "", "color": Color("3a7ab0"),
		"dps": 0.0, "slow": 0.0, "duration": 5.0,
		"pierce_armor": false, "stacking": false,
		"amplify_from": [ICE, THUNDER], "amplify_pct": 0.20,
		"desc": "Ướt: +20% sát thương Băng/Lôi. Tự nó không gây sát thương",
	},
	POISON: {
		"name": "Độc", "icon": "Đ", "emoji": "☠", "color": Color("66e03a"),
		"dps": 6.0, "slow": 0.0, "duration": 8.0,
		"pierce_armor": false, "stacking": true, "max_stacks": 5,
		"desc": "6 sát thương/giây, cộng dồn tối đa 5 tầng",
	},
	EARTH: {
		"name": "Thổ", "icon": "T", "emoji": "", "color": Color("8a7550"),
		"dps": 0.0, "slow": 0.25, "duration": 5.0,
		"pierce_armor": false, "stacking": false,
		"desc": "Làm chậm 25%, địch chết để lại mảnh vàng",
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
