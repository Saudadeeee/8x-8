# Tình trạng hình ảnh — cái gì đang do CODE sinh, cái gì cần vẽ lại

Khảo sát ngày 2026-07-28. Tất cả số liệu dưới đây đo bằng máy, không ước lượng:
306 file PNG trong `assets/` được giải nén và **đếm số màu thật**; glyph được
render ra ảnh rồi đếm pixel; model và tham chiếu asset được đối chiếu với code.

**Cách đọc**: pixel art vẽ tay dùng **5–15 màu**. Ảnh do script sinh có jitter
ngẫu nhiên từng pixel nên ra **60–140 màu** trên cùng kích thước. Đó là thước đo
khách quan để tách "art thật" khỏi "programmer art".

---

## 1. TÓM TẮT — ưu tiên xử lý

| # | Việc | Mức | Vì sao |
|---|---|---|---|
| 1 | Vẽ lại **32 texture địa hình** `assets/textures/terrain/` | **Cao** | 48–142 màu/ô 32×32 = nhiễu ngẫu nhiên. Đây là thứ chiếm ~80% diện tích màn hình |
| 2 | Vẽ lại **11 panel/nút UI** `assets/ui/panels/` | **Cao** | 48–127 màu. Khung bao mọi thứ trong game |
| 3 | Đóng gói **một font** vào `assets/fonts/` | **Cao** | Hiện KHÔNG có font nào — 35 ký hiệu đang mượn font hệ thống Windows |
| 4 | Vẽ **13 icon perk** `assets/ui/perks/` | Trung | Thư mục rỗng, card perk đang hiện ký hiệu ◆ |
| 5 | ~~Xoá asset chết~~ **ĐÃ XONG** — 449 file | — | Xem §7 |
| 6 | Vẽ lại `queen.png` cho đúng 32×32 | Thấp | Đang 32×40, lệch chuẩn |

---

## 2. HOÀN TOÀN DO CODE SINH — không có file ảnh nào

Những thứ này **không tồn tại dưới dạng asset**. Muốn đổi diện mạo phải sửa code,
không phải vẽ.

### 2.1 Bàn cờ 3D

| Thứ | Sinh ở đâu | Hình dạng |
|---|---|---|
| Ô bàn cờ | `grid_controller.gd` | `BoxMesh` mỗi ô + `StandardMaterial3D` dán texture địa hình |
| Viền đất quanh bàn (skirt) | `grid_controller.gd` | `BoxMesh` cao độ jitter |
| Ô lãnh thổ 3 cấp | `territory_manager.gd` | `BoxMesh` + `BoxMesh` viền, dán `assets/tiles/territory_*.png` |
| Overlay đường đi / ô cấm | `map_overlay_drawer.gd` | `PlaneMesh` quad + `CylinderMesh` + `Label3D` |
| Overlay hình thế | `formation_overlay.gd` | 4 thanh viền `PlaneMesh` + `Label3D` tên |
| Vòng nguyên tố dưới chân tháp | `tower.gd` | `TorusMesh` màu theo nguyên tố |
| Vòng ngắm ném thuốc | `potion_controller.gd` | Mesh vòng + `Label3D` |
| Vết nứt Chấn Địa | `reaction_table.gd` | Mesh phẳng |
| Viên đạn | `projectile.gd` | `BoxMesh` — **không có sprite/model nào** |
| Thanh máu địch | `enemy.gd` | `QuadMesh` billboard |
| Số sát thương bay lên | `fx.gd` | `Label3D`, trần 60 nhãn |
| Hạt nổ / tia sáng | `fx.gd` | particle sinh bằng code |

**Đáng chú ý**: viên đạn là một khối hộp. Đây là thứ xuất hiện nhiều nhất trên
màn hình khi giao tranh mà chưa có art riêng.

### 2.2 Giao diện 2D

Mọi màn hình trừ HUD **dựng 100% bằng code** — file `.tscn` chỉ có đúng 1 node gốc:

| Màn | Node trong .tscn | Dòng code dựng UI |
|---|---|---|
| `main_menu.tscn` | 1 | `main_menu.gd` |
| `king_select.tscn` | 1 | `king_select.gd` |
| `encounter_screen.tscn` | 1 | `encounter_screen.gd` |
| `game_over_screen.tscn` | 1 | `game_over_screen.gd` |
| `victory_screen.tscn` | 1 | `victory_screen.gd` |
| `meta_progression.tscn` | 1 | `meta_progression.gd` |
| `settings_screen.tscn` | 1 | `settings_screen.gd` |
| `game_hud.tscn` | 40 | `game_hud.gd` + 7 component |

Tổng `scripts/ui/` = **7525 dòng**. Nghĩa là: muốn đổi bố cục menu thì sửa code,
mở Godot editor kéo thả sẽ không thấy gì.

Nền menu chính là **hai `ColorRect` màu phẳng** (`main_menu.gd`) — nền tối
`#0d0805` + một lớp vignette đen 35%. Không có tranh nền.

`UIStyle` (779 dòng) là nơi duy nhất tạo StyleBox. Nó **ưu tiên texture 9-patch**
trong `assets/ui/panels/`, thiếu file thì tự vẽ `StyleBoxFlat` bằng code. Hiện
file có đủ, nhưng chính các file đó là ảnh sinh bằng script (xem §3.2).

---

## 3. CÓ FILE ẢNH NHƯNG DO SCRIPT SINH — cần vẽ lại

### 3.1 Texture địa hình — 32 file, ưu tiên CAO NHẤT

`assets/textures/terrain/*.png`, tất cả 32×32.

```
cliff_side.png            142 màu   ← nhiễu nặng nhất
volcanic_light.png        110 màu
wasteland_light.png       106 màu
terrain_light.png         105 màu
terrain_dark.png           96 màu
terrain_cursed.png         92 màu
swamp_dark / tundra_dark / wasteland_dark   89 màu
... (32 file, thấp nhất 48 màu)
```

So sánh: `territory_fire.png` vẽ tay chỉ **5 màu**, `bom_lua.png` **7 màu**.

Đây là mặt trên của **mọi ô bàn cờ** — thứ chiếm phần lớn diện tích màn hình.
Nhiễu 100 màu trên ô 32px làm bàn cờ trông lấm tấm chứ không ra pixel art, và
khi camera zoom ra thì nhòe thành một mảng xám.

Bộ đủ cho mỗi biome: `<prefix>_{light,dark,road,cliff_side,cliff_top}.png`
với prefix ∈ `terrain` (mặc định) · `wasteland` · `tundra` · `volcanic` ·
`swamp` · `verdant`. Cộng `terrain_blessed.png` và `terrain_cursed.png`.

### 3.2 Panel và nút UI — 11 file, ưu tiên CAO

`assets/ui/panels/*.png`

```
panel_wood.png       48x48   127 màu
panel_stone.png      48x48   114 màu
btn_normal.png       36x36    99 màu
btn_hover.png        36x36    99 màu
btn_disabled.png     36x36    99 màu
btn_pressed.png      36x36    86 màu
panel_parchment.png  52x52    80 màu
panel_dark.png       48x48    48 màu
bar_bg / bar_fill / frame_gold
```

Đây là 9-patch bao **mọi panel và nút trong game**. `UIStyle.PANEL_SPEC` quy
định biên 9-patch: stone/wood = 8px, parchment = 10px. Vẽ lại phải giữ đúng
biên đó, nếu không góc sẽ bị kéo giãn.

### 3.3 Âm thanh (ngoài phạm vi hình ảnh nhưng cùng gốc)

19 file `.wav` trong `assets/audio/sfx/` được **tổng hợp bằng script Python**,
không phải thu/thiết kế. Nghe ra tiếng bíp tổng hợp.

---

## 4. FONT — chưa đóng gói, đang mượn hệ thống

**Dự án không có file font nào** (`assets/` không chứa `.ttf`/`.otf`).
Godot dùng mặc định **Open Sans SemiBold**.

Đo bằng runtime: `ThemeDB.fallback_font.has_char()` trả **false cho cả 35 ký hiệu**
đang dùng trong UI — ★ ⚔ ✓ ♥ ⚡ 🌍 🔥 🛡 🎯 …

Nhưng render thật thì **chúng vẫn hiện**: đếm pixel cho thấy ★ = 437px, 🌍 = 1810px,
trong khi ô tofu chuẩn (U+E000) = 855px. Nghĩa là Godot đang **fallback sang font
hệ thống Windows** (Segoe UI Symbol / Segoe UI Emoji).

**Hệ quả**: trên máy này thì đẹp; export sang Linux/macOS hoặc máy Windows thiếu
font đó thì 35 ký hiệu này thành ô vuông rỗng. Emoji màu của Segoe cũng lệch hẳn
với phong cách pixel art.

Nơi dùng nhiều nhất:

| Ký hiệu | Số chỗ | Ví dụ |
|---|---|---|
| ★ | 19 | sao ghép tháp, thanh di vật |
| ⚔ | 16 | banner wave |
| ⚡ ☠ | 11 mỗi cái | nút kỹ năng Vua, nguyên tố Độc |
| ✦ | 9 | synergy nguyên tố |
| 🌍 🎯 🧪 🏠 🔒 👑 🔧 🛡 💾 🗡 💥 🎲 ⭐ | 1–5 mỗi cái | banner biome, ngắm thuốc, menu |

**Việc cần làm**: chọn một font pixel có dấu tiếng Việt (VD Silver, Pixellari,
hoặc bộ có Vietnamese subset), đặt vào `assets/fonts/`, gán qua Theme. Ký hiệu
nào font không có thì thay bằng icon PNG.

*Lưu ý*: icon nguyên tố trong HUD hiện là **chữ cái** (H/B/L/N/Đ/T) chứ không
phải emoji — đây là quyết định cũ đúng và nên giữ.

---

## 5. THIẾU HẲN — chưa có ảnh nào

| Thứ | Đường dẫn mong đợi | Hiện tại đang hiện gì |
|---|---|---|
| Icon perk (13 cái) | `assets/ui/perks/<id>.png` 48×48 | Ký hiệu ◆ theo bậc hiếm |
| Sprite viên đạn | — | Khối hộp `BoxMesh` |
| Tranh nền menu | — | Hai `ColorRect` màu phẳng |
| Tranh nền các màn khác | — | Màu phẳng |

Id perk cần vẽ: `luoi_giao_tien_tuyen` · `thue_chu_hau` · `quan_su_hoang_trieu` ·
`hoa_su` · `han_bang_quyet` · `loi_dinh` · `thuy_mach` · `doc_su` · `dia_chu` ·
`tho_ren_lang_thang` · `nha_gia_kim` · `thuan_vat_ly` · `tho_ghep_mach`

---

## 6. ART THẬT — đã ổn, không cần đụng

**207/306 file PNG** dưới 40 màu = pixel art vẽ tay đúng chuẩn.

| Nhóm | Số lượng | Màu | Ghi chú |
|---|---|---|---|
| Icon thuốc | 20 | 5–10 | 32×32, vẽ bằng Aseprite |
| Icon trang bị | 20 | 5–10 | 32×32 |
| Icon di vật | 12 | 5–10 | 32×32 |
| Ô nguyên tố | 6 | ~5 | 32×32, mỗi ô một rune riêng |
| Crest shop | 7 | ~5 | 32×32, dùng chung rune với ô |
| Icon encounter | 10 + 4 | 8–14 | 32×32 và 80×80 |
| Banner tiêu đề/thắng/thua | 3 | 5–8 | 320×80 và 320×96 |
| Sprite quân cờ | 11 | ~10 | 32×32 (trừ queen 32×40) |
| Sprite địch | 5 | ~10 | 32×32 |

**Model 3D**: 28/28 id đều có `.gltf` (15 quân + 10 địch + 3 boss), cộng
`king.gltf` và 15 model prop. Làm bằng Blockbench, tỉ lệ 16 đơn vị = 1 m.
**Không thiếu model nào.**

---

## 7. ASSET CHẾT — ĐÃ DỌN (2026-07-28)

**316 file đã xoá.** Tất cả vẫn nằm trong git history (commit `2aaf152`).

> **Đã thử xoá 130 file `assets/models/<id>_N.png` rồi PHẢI KHÔI PHỤC.** Ban đầu
> tôi kết luận chúng là rác export Blockbench, vì mọi `.gltf` đều nhúng texture
> base64 và không file nào trỏ texture ngoài. **Kết luận đó sai.** Godot khi
> import glTF sẽ **trích xuất** texture nhúng ra chính các PNG đó, và file `.scn`
> biên dịch trong `.godot/imported/` phụ thuộc vào chúng. Xoá đi thì **cả 45 model
> không load nổi** — mà `--import` vẫn báo sạch, vì phụ thuộc chỉ được kiểm lúc
> LOAD chứ không phải lúc import. Đừng đụng vào thư mục đó.

| Nhóm | Số file | Lý do |
|---|---|---|
| `assets/board/` | 274 | Tileset 2D (nước/xương/cây), không dòng code nào tham chiếu |
| `assets/background/` | 6 | Nền 2D cũ |
| `assets/generated/` | 8 | Icon shop tạm, tên có timestamp |
| `assets/ui/` lẻ | 6 | `hud_stat_frame` · `panel_frame` · `icon_coin/crown/heart/shield` |
| `assets/towers/` lẻ | 3 | `Tower.png` · `Wisp.png` · `horse.png` — không khớp id nào |
| `assets/tiles/` lẻ | 3 | `territory_tiles.png` · `fire_tile.png` · `ice_tile.png` |
| `assets/ui/panels/panel_dark.png` | 1 | `PANEL_SPEC["dark"]` khai `"file": ""` → không bao giờ nạp |
| `res/map.tres` · `res/water.tres` | 2 | TileSet 2D, chỉ trỏ tới `assets/board` và `assets/background` |
| `scenes/ui/hud.tscn` · `scenes/map/tile_map.tscn` | 2 | Scene 2D mồ côi |
| `.import` / `.uid` mồ côi | ~14 | Theo file gốc đã xoá |

### Hai bug thật phát hiện trong lúc dọn

**1. Tên file lệch hoa–thường** — `assets/towers/Pawn.png` và `assets/enemy/Orc.png`
trong khi id là `pawn` / `orc`. Windows không phân biệt hoa thường nên chạy được,
**export sang Linux/macOS là hỏng**. Đã đổi tên và sửa 4 file `.tres` trỏ tới chúng.

**2. Xoá nhầm 3 sprite đang được dùng** — `Tower.png` · `Wisp.png` · `horse.png`
không khớp `id` nào nên tôi tưởng là rác, nhưng `rook.tres` · `ice_guardian.tres` ·
`knight.tres` trỏ tới chúng qua field `texture`. Shop im lặng bỏ qua ba tháp đó
(`if stats:` guard) nên test vẫn xanh. Đã khôi phục, và `check_content.py` giờ
kiểm **mọi `path="res://…"` trong `.tres`/`.tscn` phải tồn tại**.

**3. `btn_disabled.png` chưa bao giờ được dùng** — `UIStyle.button_styles()` chỉ nạp
normal/hover/pressed rồi tự làm mờ bản normal cho trạng thái disabled. Art có sẵn
mà code không đọc. Đã nối vào (thiếu texture thì vẫn fallback làm mờ như cũ).

### Chống tái phát

`python tools/check_art.py` giờ báo thêm hai mục:

- **Tên file lệch hoa–thường** so với id (Windows che mất lớp lỗi này)
- **Ảnh không ai tham chiếu**. Hai thư mục được loại trừ tường minh vì báo nhầm
  ở đây rất nguy hiểm:
  - `assets/textures/terrain` — nạp bằng chuỗi ghép qua `BiomeLibrary.tex_path()`
  - `assets/models` — `<id>_N.png` là texture Godot trích xuất khi import glTF;
    không code nào trỏ tới nhưng `.godot/imported/*.scn` phụ thuộc vào chúng

Hiện tại: **0 ảnh chết, 0 tên file lệch**.

---

## 8. CÁCH KIỂM TRA LẠI

```bash
# Đếm màu mọi PNG, liệt kê file nghi sinh bằng script
python tools/check_art.py

# Kiểm ảnh thiếu / sai kích thước theo từng loại nội dung
python tools/check_content.py
```

Ngưỡng dùng trong `check_art.py`: **>40 màu trên ảnh ≤64px** thì nghi là sinh
bằng script. Ngưỡng này tách sạch hai nhóm trong dữ liệu hiện tại (art vẽ tay
cao nhất 14 màu, ảnh sinh script thấp nhất 48 màu) — khoảng trống rất rộng nên
không lo báo nhầm.
