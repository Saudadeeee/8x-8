> Làm việc với repo này bằng AI agent? Đọc **[docs/AGENT_GUIDE.md](docs/AGENT_GUIDE.md)** trước.

# 8x-8

Roguelike Tower Defense lai Auto-Battler, làm bằng **Godot 4.7** (GDScript, Forward+).
Bàn cờ 8×8 nhìn kiểu diorama 3D. Mỗi run một bản đồ khác nhau; chết là mất tất,
chỉ giữ lại meta-progression.

Điểm khác biệt so với tower defense thường: **nguyên tố đến từ Ô, không từ loại tháp.**
Cùng một quân Pawn đứng trên Mạch Hoả và trên Mạch Băng là hai thứ khác nhau. Vì vậy
bố trí bàn cờ mới là quyết định chính, không phải chọn mua quân nào.

---

## Chạy

Mở thư mục này bằng Godot 4.7 rồi F5. Main scene: `res://scenes/ui/main_menu.tscn`.

Chạy không cần mở editor:

```bash
godot --path .
```

## Kiểm tra

```bash
python tools/run_tests.py        # 187 khẳng định trên game thật — chạy 2 lần cho chắc
python tools/check_content.py    # validate .tres / JSON + kích thước ảnh
python tools/audit_wiring.py     # tìm dữ liệu khai mà không ai đọc
python tools/check_art.py        # tìm ảnh do script sinh (cần vẽ lại)
```

Tình trạng hình ảnh — cái gì đang do code sinh, cái gì cần vẽ lại:
**[docs/ART_STATUS.md](docs/ART_STATUS.md)**

Đánh giá sẵn sàng phát hành: **[docs/RELEASE_READINESS.md](docs/RELEASE_READINESS.md)**

`run_tests.py` dựng game_map thật rồi đặt tháp, mua đồ, nổ phản ứng, mở rộng bản đồ —
không mock. Sửa hằng `GODOT` trong file nếu binary nằm chỗ khác.

Hướng mở rộng bản đồ và nội dung quầy shop là **ngẫu nhiên**, nên chạy test lặp lại vài
lần mới bắt được lỗi phụ thuộc may rủi.

---

## Vòng chơi

```
Menu → Chọn King → [ Chuẩn bị → Wave → Shop → Perk ] lặp lại → Thua (King chết) / Thắng
```

- **Chuẩn bị** — mua và đặt quân, bố trí ô nguyên tố.
- **Wave** — địch đi theo đường DFS sinh ngẫu nhiên, tháp tự bắn. Wave 10 là boss.
- **Shop** — 5 slot, **luôn có ít nhất 1 quân**. Xáo lại tốn vàng, càng xáo càng đắt.
- **Perk** — chọn 1 trong 3. Bậc perk mở dần: thường từ wave 1, hiếm 3, sử thi 5,
  huyền thoại 8.
- Cứ **3 wave** bản đồ mở rộng một hướng; cứ 3 wave có một Encounter.

## Hệ nguyên tố

6 nguyên tố (Hoả · Băng · Lôi · Thuỷ · Độc · Thổ) → **10 phản ứng**. Mỗi địch mang tối đa
2 Dấu; ghép đủ cặp thì nổ và tiêu thụ cả hai.

Ô nguyên tố có 3 cấp (đặt ô cùng loại lên chính nó để nâng). Xếp ô theo 4 **hình thế**
— Hàng Long · Tứ Trụ · Song Cực · Trận Vòng — để thêm thưởng. Đủ 6 nguyên tố trên bàn
mở **Bát Quái**.

Bấm **F1** trong trận để mở Sách Nguyên Tố — nội dung sinh thẳng từ code nên không bao
giờ lệch với luật thật.

## Nội dung hiện có

| | Số lượng |
|---|---|
| Quân cờ | 15 |
| Địch | 10 loài + 3 boss |
| King | 3 |
| Nguyên tố / phản ứng / hình thế | 6 / 10 / 4 |
| Perk | 13 |
| Thuốc · Trang bị · Di vật | 20 · 20 · 12 |
| Encounter | 18 |

---

## Thêm nội dung

Gần như mọi thứ là **data-driven** — thả một file vào đúng thư mục là xong, không phải
viết code:

Tạo khung file bằng một lệnh — nó ghi sẵn file đúng định dạng rồi **in ra danh
sách ảnh phải vẽ kèm kích thước**:

```bash
python tools/new_content.py tower  halberdier
python tools/new_content.py enemy  snow_wolf
python tools/new_content.py perk   loi_the_ho
python tools/new_content.py potion binh_khoi_den
python tools/new_content.py equip  giap_gai
python tools/new_content.py relic  vuong_mien_vo

python tools/new_content.py --list        # xem mọi id đã dùng
```

| Muốn thêm | Dữ liệu | Ảnh (tên file = `id`) |
|---|---|---|
| Quân cờ | `res/towers/<id>.tres` | `assets/models/<id>.gltf` · `assets/towers/<id>.png` 32×32 |
| Địch | `res/enemy/<id>.tres` (nhớ `spawn_seasons`) | `assets/models/<id>.gltf` · `assets/enemy/<id>.png` 32×32 |
| Perk | JSON trong `data/perks/` | `assets/ui/perks/<id>.png` 48×48 |
| Thuốc | JSON trong `data/potions/` | `assets/ui/potions/<id>.png` 32×32 |
| Trang bị | JSON trong `data/equipment/` | `assets/ui/equipment/<id>.png` 32×32 |
| Di vật | JSON trong `data/relics/` | `assets/ui/relics/<id>.png` 32×32 |

**Tên file ảnh phải trùng đúng `id`** — code ghép chuỗi `thư_mục % id`, không có
bảng ánh xạ. Thiếu ảnh không làm vỡ UI (mọi chỗ đều có phương án dự phòng),
nhưng cũng vì thế mà quên vẽ thì không ai báo — chạy `check_content.py`.

Xong thì chạy `python tools/check_content.py`. Chi tiết từng field, quy ước vẽ
icon, tỉ lệ model 3D: **[docs/CONTENT_AUTHORING.md](docs/CONTENT_AUTHORING.md)**
(chương 6 nói riêng về hiển thị).

## Cấu trúc

```
scenes/          map · tower · enemy · projectile · ui
scripts/
  managers/      GameManager · SceneManager · SettingsManager · AudioManager (autoload)
                 + SynergyManager · EncounterManager
  map/           game_map (orchestration) · grid_controller · map_generator
                 wave_spawner · territory_manager · tower_placer · phase_controller
                 potion_controller · boss_controller
  elements/      element_types · reaction_table · element_marks · formation_detector
                 element_synergy · formation_overlay
  items/         potion_system · equipment_system · relic_system
  perks/         perk_system
  ui/            game_hud + ui/hud/ (component tách riêng) · ui_style
res/             .tres: towers · enemy · kings
data/            JSON nội dung: perks · potions · equipment · relics
assets/          models .gltf · textures · ui · audio
tests/           7 batch test chức năng
tools/           run_tests · check_content · new_content · audit_wiring
```

`scripts/map/game_map.gd` là file điều phối chính — đọc nó trước khi sửa bất cứ thứ gì
liên quan tới gameplay.

Quy ước kiến trúc, các bất biến thiết kế và danh sách bẫy đã gặp nằm trong
[CLAUDE.md](CLAUDE.md).
