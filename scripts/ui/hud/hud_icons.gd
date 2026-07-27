# res://scripts/ui/hud/hud_icons.gd
#
# Nạp icon vật phẩm theo `id`. Dùng chung cho túi thuốc, thanh di vật và ô
# trang bị trong panel tháp — trước đây ba chỗ này gọi một hàm nằm trong
# game_hud.gd, nên component tách ra không dùng lại được.
#
# QUY ƯỚC: tên file icon phải trùng ĐÚNG `id` của vật phẩm. Thiếu file thì trả
# null và nơi gọi tự rơi về nhãn chữ viết tắt — thêm vật phẩm mới mà chưa vẽ
# icon vẫn chạy, không vỡ UI.
class_name HudIcons
extends Object

const POTION_DIR: String = "res://assets/ui/potions/%s.png"
const RELIC_DIR:  String = "res://assets/ui/relics/%s.png"
const EQUIP_DIR:  String = "res://assets/ui/equipment/%s.png"

## Cache theo đường dẫn đầy đủ. Lưu cả kết quả null để không thử load lại mỗi
## frame một file không tồn tại.
static var _cache: Dictionary = {}

static func load_icon(dir_fmt: String, id: String) -> Texture2D:
	if id.is_empty():
		return null
	var key := dir_fmt % id
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if ResourceLoader.exists(key):
		tex = load(key) as Texture2D
	_cache[key] = tex
	return tex

static func potion(id: String) -> Texture2D:
	return load_icon(POTION_DIR, id)

static func relic(id: String) -> Texture2D:
	return load_icon(RELIC_DIR, id)

static func equipment(id: String) -> Texture2D:
	return load_icon(EQUIP_DIR, id)
