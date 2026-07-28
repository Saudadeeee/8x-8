# res://scripts/ui/glyphs.gd
#
# KÝ HIỆU GAME — bảng tra tên → mã Private Use Area.
#
# Vì sao không dùng thẳng emoji: 16 ký tự (⚡ 🔥 🌍 🧪 …) có thuộc tính Unicode
# `Emoji_Presentation = Yes`. HarfBuzz/TextServer ép chúng sang **font emoji của
# hệ thống** bất kể font chính có glyph hay không — đo được: advance 19px thay vì
# 6px, và vẽ ra màu cam thay vì màu chữ. Trên Windows trông vẫn "được" nên lỗi
# này VÔ HÌNH khi phát triển; export sang Linux/macOS là ô vuông rỗng.
#
# PUA (U+E000–U+F8FF) không mang thuộc tính Unicode nào nên không bao giờ bị
# định tuyến sang font khác. Glyph do `tools/make_font.py` vẽ vào atlas.
#
# Trong chuỗi, dùng escape `` chứ đừng dán ký tự PUA thô — nhìn mã mới
# biết đó là gì, và grep được.
class_name Glyphs
extends Object

const FIRE      := ""   # lửa — combo, nguyên tố Hoả
const BOLT      := ""   # sét — kỹ năng Vua, nguyên tố Lôi
const WORLD     := ""   # vùng đất — banner biome
const TARGET    := ""   # vòng ngắm — ném thuốc
const FLASK     := ""   # bình thuốc
const HOME      := ""   # về menu chính
const LOCK      := ""   # mục chưa mở khoá
const CROWN     := ""   # vương miện — Vua, phần thưởng
const WRENCH    := ""   # cờ lê — cài đặt, sửa chữa
const SAVE      := ""   # lưu
const DROP      := ""   # giọt nước — nguyên tố Thuỷ
const ROCK      := ""   # đá — nguyên tố Thổ
const HOURGLASS := ""   # đồng hồ cát — thời gian
const DICE      := ""   # xúc xắc — xáo shop
const STAR      := ""   # sao — cấp tháp, perk
const BURST     := ""   # vụ nổ — phản ứng

## Ký tự emoji → mã PUA tương ứng. Dùng cho chuỗi đến từ DỮ LIỆU NGOÀI (perk /
## vật phẩm nạp từ JSON do người khác viết) — chuỗi trong repo đã thay sẵn.
const EMOJI_MAP := {
	"\U0001F525": FIRE,  "⚡": BOLT,          "\U0001F30D": WORLD,
	"\U0001F3AF": TARGET, "\U0001F9EA": FLASK, "\U0001F3E0": HOME,
	"\U0001F512": LOCK,  "\U0001F451": CROWN, "\U0001F527": WRENCH,
	"\U0001F4BE": SAVE,  "\U0001F4A7": DROP,  "\U0001FAA8": ROCK,
	"⏳": HOURGLASS,      "\U0001F3B2": DICE,  "⭐": STAR,
	"\U0001F4A5": BURST,
}

## Đổi mọi emoji trong chuỗi sang ký hiệu PUA đã có trong font.
## Gọi ở nơi hiển thị chuỗi do người khác viết; chuỗi trong repo đã sạch sẵn.
static func safe(text: String) -> String:
	var out := text
	for emoji in EMOJI_MAP:
		if out.contains(emoji):
			out = out.replace(emoji, str(EMOJI_MAP[emoji]))
	return out
