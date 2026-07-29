# Đánh giá sẵn sàng phát hành — 8x-8

Ngày 2026-07-29. Mọi kết luận dưới đây đo bằng máy: chạy bot chơi trọn một ván,
187 khẳng định tự động, kiểm file save hỏng, quét asset và chuỗi hiển thị.

## Kết luận ngắn

> **CẬP NHẬT 2026-07-29 — toàn bộ mục CHẶN đã xử lý.** Xem §7 ở cuối.

**Sẵn sàng cho demo công khai. Chưa sẵn sàng để BÁN.**

Còn thiếu để bán: âm thanh vẫn là bíp tổng hợp, chưa có hệ thống dịch đa ngôn
ngữ, và chưa build/chạy thử bản desktop (thiếu export template ~800MB).

---

## 1. Đã đo được gì

### Chơi trọn ván bằng bot

Đo bằng HAI bot khác nhau, và chúng cho kết luận trái ngược:

**Bot A — mua tối đa 3 tháp/wave** (tự giới hạn):
```
wave  1 | HP= 45 vang= 260
wave 10 | HP= 17 vang=2095   → THẮNG
```

**Bot B — tiêu SẠCH vàng mỗi wave** (cận trên của người chơi ngây thơ):
```
wave  1 | HP= 20 vang= 16 thap= 25
wave  5 | HP= 18 vang=  4 thap= 49
wave  7 | HP= 10 vang= 11 thap= 78
wave  9 | HP=  9 vang= 96 thap= 97
```

- **Thắng được thật**, không kẹt, không crash.
- **Độ khó ỔN.** Bot B tụt từ 20 xuống 9 máu — sát nút. Máu khởi đầu của King
  Iron là **20**, con số 45 ở bot A là do meta-upgrade tích luỹ.
- **Kinh tế KHÔNG dư.** Bot B chỉ còn 4–96 vàng mỗi wave. Con số "tồn 2095" của
  bot A là **hiện vật đo lường**: bot đó tự giới hạn mua 3 tháp nên không tiêu
  hết, chứ không phải game thiếu chỗ tiêu.

> Bài học: bot đo cân bằng phải tiêu hết tài nguyên, nếu không nó đo chính giới
> hạn của mình chứ không đo game. Kết luận "độ khó thấp + thừa vàng" ở bản đánh
> giá đầu đã bị rút lại sau khi đo lại.

### Tự động hoá

| Công cụ | Kết quả |
|---|---|
| `run_tests.py` — 7 batch, 187 khẳng định | **0 lỗi** |
| `check_content.py` | 0 lỗi, 1 cảnh báo |
| `check_art.py` | 0 ảnh chết, 0 tên file lệch hoa/thường |
| `audit_wiring.py` | 12 nghi vấn (signal API dư, vô hại) |
| Parse toàn dự án | 0 lỗi |

---

## 2. CHẶN PHÁT HÀNH

### 2.1 Chưa từng export — không có `export_presets.cfg`

Game **chưa được đóng gói lần nào**. Chưa biết nó chạy thế nào ngoài editor.
Rủi ro cụ thể đã lường được:

- **Không có font nào được đóng gói.** 35 ký hiệu trong UI (★ ⚔ ✓ ♥ ⚡ 🌍 🔥 🛡 …)
  hiện đang mượn font hệ thống Windows. Đo bằng runtime:
  `ThemeDB.fallback_font.has_char()` trả **false cho cả 35** — chúng hiện được
  chỉ nhờ Godot fallback sang Segoe UI. **Export sang Linux/macOS là ô vuông rỗng.**
- Đã sửa một lỗi cùng loại: `assets/towers/Pawn.png` trong khi code hỏi
  `pawn.png` — Windows không phân biệt hoa thường nên chạy tốt, Linux thì hỏng.
  Không loại trừ còn lớp lỗi tương tự chỉ lộ ra khi export.

**Việc phải làm**: tạo export preset, build thử Windows + Linux, chạy bản build.

### 2.2 Không có hướng dẫn chơi

Không tìm thấy tutorial/onboarding nào trong `scripts/` hay `scenes/`.

Game có 6 nguyên tố × 10 phản ứng × 4 hình thế × 3 cấp ô × 13 perk × 52 vật phẩm,
và bất biến thiết kế cốt lõi là **"nguyên tố đến từ Ô, không từ loại tháp"** —
điều này không tự nhiên chút nào và không ai đoán ra được. Có Sách Nguyên Tố (F1)
nhưng đó là *tra cứu*, không phải *dạy*.

Người chơi mới nhiều khả năng chỉ mua tháp rồi đặt bừa — tức bỏ qua toàn bộ hệ
thống làm nên bản sắc của game.

### 2.3 Nội dung bằng ~1/3 lời hứa GDD

GDD viết: *"Unite the Kingdom — Đánh bại tất cả Rival Kings"*.

Thực tế: `MAX_WAVES = 10`, **một** boss ở wave 10, thắng là hết. Không có nhiều
Rival King, không mở khoá quân của họ, không có ngoại giao.

Một ván ≈ 10 wave × (30s chuẩn bị + thời gian wave). Ascension 0–5 có kéo dài
tuổi thọ, nhưng nội dung *mới* thì không tăng.

---

## 3. CẦN LÀM TRƯỚC KHI BÁN (không chặn demo)

### 3.1 Art nền là ảnh sinh bằng script

Đo số màu (pixel art vẽ tay 5–15 màu; ảnh script jitter từng pixel ra 48–142 màu):

| Nhóm | Số file | Số màu |
|---|---|---|
| Texture địa hình `assets/textures/terrain/` | 32 | 48–142 |
| Panel + nút UI `assets/ui/panels/` | 10 | 48–127 |

Đây là mặt trên **mọi ô bàn cờ** và khung bao **mọi panel** — tức phần lớn diện
tích màn hình. Trong khi 207 file icon/sprite khác đều là pixel art vẽ tay đúng
chuẩn. Chênh lệch này nhìn ra ngay.

Chi tiết: [ART_STATUS.md](ART_STATUS.md).

### 3.2 Âm thanh là bíp tổng hợp

19 file `.wav` sinh bằng script Python, không phải thu hay thiết kế.

### 3.3 Thiếu hình

- 13 icon perk (`assets/ui/perks/` rỗng → card hiện ký hiệu ◆)
- Viên đạn là khối `BoxMesh`, không có sprite
- Nền menu là hai `ColorRect` màu phẳng, không có tranh

### 3.4 Ngôn ngữ lẫn lộn

UI trộn Việt và Anh, không nhất quán:

```
"▶  NEXT WAVE"          "◆ COMMON"        "🎲 Roll"
"Pawn Strike Training"  "Knight Vanguard" "Dismiss Order"
"★ Perks: %d"           "Unlocked: %s"    "FREE"
```

Chuỗi hiển thị nằm rải rác trong code, **không có hệ thống dịch** (không dùng
`tr()` hay file `.po`). Muốn phát hành đa ngôn ngữ sau này thì phải gom lại toàn bộ.

### 3.5 ~~Độ khó và kinh tế~~ — ĐO LẠI: KHÔNG CẦN SỬA

Xem §1. Bot tiêu sạch vàng tụt còn 9/20 máu ở wave 9 và luôn cạn vàng — độ khó
và kinh tế đều lành mạnh. Kết luận cũ là hiện vật của một bot đo tồi.

---

## 4. ĐÃ SỬA TRONG ĐỢT ĐÁNH GIÁ NÀY

**Save hỏng làm chết vĩnh viễn tiến trình meta** — lỗi chặn phát hành.

`MetaProgress.load_or_create()` trước đây là `return load(SAVE_PATH) as MetaProgress`.
File save hỏng → `load()` trả null → cast ra null → `GameManager.meta_progress`
đứng **null vĩnh viễn**. Không crash (mọi nơi đều có guard) nên **không ai biết**,
nhưng toàn bộ tiến trình meta chết câm và không bao giờ tự phục hồi. Mất điện
giữa lúc ghi save là đủ để hỏng.

Đã sửa hai đầu:

- `load_or_create()` luôn trả về một `MetaProgress` dùng được; file hỏng được đổi
  tên sang `meta_progress.corrupt.tres` chứ không xoá.
- `save()` ghi ra file tạm rồi mới đổi tên đè lên bản thật, nên bị giết giữa
  chừng không để lại file cụt.

Kiểm chứng: 3 dạng file hỏng (rác, rỗng, sai kiểu) đều phục hồi đúng. Đã thêm
vào batch test 5.

---

## 5. ĐIỂM MẠNH

- **Chơi được trọn vẹn, không crash.** Bot chạy hết 10 wave và thắng.
- **Kiến trúc data-driven.** Thêm quân/địch/perk/vật phẩm chỉ cần thả file, có
  `new_content.py` sinh khung và `check_content.py` bắt lỗi.
- **Lưới test thật** — 187 khẳng định chạy trên game thật (dựng scene, đặt tháp,
  nổ phản ứng, mở rộng bản đồ), không mock. Đã bắt được bug thật nhiều lần.
- **Hệ nguyên tố có chiều sâu** — 10 phản ứng, hình thế, synergy hai trục,
  khắc/kháng. Đây là thứ làm game khác biệt.
- **Cân bằng đã đo, không đoán**: dải tầm bắn, trần cộng dồn, máu địch cấp số nhân
  đều có lý do ghi lại trong CLAUDE.md.

---

## 6. LỘ TRÌNH ĐỀ XUẤT

| Giai đoạn | Việc | Ước lượng |
|---|---|---|
| **A — playtest được** | Export preset + build thử 2 nền tảng · đóng gói font · tutorial ngắn 3–4 bước | 1–2 tuần |
| **B — demo công khai** | Vẽ lại texture địa hình + panel UI · 13 icon perk · thống nhất ngôn ngữ | 2–4 tuần |
| **C — bán được** | Thêm Rival King thứ 2–3 (nội dung ×2–3) · âm thanh thật · cân lại độ khó và chỗ tiêu vàng · hệ thống dịch | 1–3 tháng |

Nút thắt lớn nhất **không phải code** — mà là art, âm thanh và khối lượng nội dung.

---

## 7. ĐÃ XỬ LÝ (2026-07-29)

| Mục | Trạng thái |
|---|---|
| 2.1 Chưa từng export | `export_presets.cfg` (Windows/Linux/Web) trong repo; **build Web chạy thật, 0 lỗi** |
| 2.1 Không đóng gói font | Font pixel **295 glyph** tự vẽ, đủ tiếng Việt + 58 ký hiệu game |
| 2.2 Không có tutorial | 5 thẻ, thẻ 2 dạy bất biến "nguyên tố đến từ Ô" |
| 2.3 Nội dung 1/3 GDD | **3 Rival King** ở wave 7/14/20, MAX_WAVES 10→20, hạ vua mở khoá quân |
| 3.1 Art nền sinh bằng script | 42 file vẽ lại, `check_art.py` từ 42 nghi vấn → **0** |
| 3.3 Thiếu hình | 25 icon perk, đạn thành mũi tên, nền menu gradient |
| 3.4 Ngôn ngữ lẫn lộn | **52 chuỗi** sang tiếng Việt |
| 3.5 Độ khó & kinh tế | Đo lại: độ khó ổn. Vàng dư chỉ có ở bản 20 wave → trần xáo shop tăng theo wave |

**Còn lại**: âm thanh thật · hệ thống dịch (`tr()` + `.po`) · build desktop.

Lưới test: **212 khẳng định, 0 lỗi**.
