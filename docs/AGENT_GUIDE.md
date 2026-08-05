# 8x-8 — Sổ tay cho AI agent

> Đây là **điểm vào duy nhất**. Đọc §1–§3 trước khi sửa bất cứ dòng nào.
> `CLAUDE.md` ở gốc repo là **nhật ký** (vì sao từng quyết định được đưa ra);
> file này là **tham chiếu** (làm thế nào để thao tác).
>
> Cập nhật lần cuối: 2026-08-05 · Godot 4.7.1 · GDScript

---

## §0. Tra nhanh

| Cần gì | Đi đâu |
|---|---|
| Thêm quân cờ / địch / Vua | §6.1 — thả một `.tres` |
| Thêm di vật cộng chỉ số | §6.2 — thả một `.tres`, **không** đụng code |
| Thêm di vật **đổi luật** | §6.3 — 6 bước, thiếu một là chết âm thầm |
| Thêm perk / thuốc / trang bị | §6.4 |
| Sửa cân bằng | §7 — **đo trước, sửa sau** |
| Chạy test | `python tools/run_tests.py` |
| Xem game đang có gì | `godot --headless --script res://tools/content_report.gd` |
| Bị "tính năng không chạy" | §8 — bảng bẫy |

**Godot binary:** `D:/Games/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`

---

## §1. Game này là gì

Roguelike tower-defense lai auto-battler, chủ đề cờ. Một ván ~15 phút, **12 wave**,
ba wave boss (5 · 9 · 12). Thua khi máu Vua về 0, **hoặc** khi Rival King chạm
tới Vua (thua ngay, không cần hết máu).

### Công thức trung tâm — `NỀN × BỘI`

Mọi cơ chế phải trả lời được: **nó vào được `Nền × Bội` không?** Không thì tắt
cờ ở [feature_flags.gd](../scripts/managers/feature_flags.gd).

```
NỀN(ô)  = Σ sát-thương-mỗi-giây của mọi quân ĐANG PHỦ ô đó
BỘI(ô)  = tích: thế cờ × cấp ô nguyên tố × di vật × luật Rival King
```

Nguồn: [board_score.gd](../scripts/map/board_score.gd).

**Bội tách làm hai nửa** — đây là bất biến quan trọng nhất của file đó:

| | Đi đâu | Ai áp |
|---|---|---|
| `combat_mult()` | `Tower.formation_damage_mult` | nhân thẳng vào sát thương |
| `residual_mult()` | dự báo HUD | khuếch đại PHẢN ỨNG, đã áp ở nơi khác |

> **Bất biến (có test chốt): `cell_mult = combat_mult × residual_mult`.**
> Thêm một dòng vào `mult_breakdown` mà quên gắn cờ `combat` thì nó rơi vào
> residual và trở thành **số chết trên HUD** — đúng lỗi đã làm 7 thế cờ + 9 di
> vật không gây sát thương suốt nhiều tuần.

### Quân đánh theo NƯỚC ĐI, không theo bán kính

[chess_pattern.gd](../scripts/towers/chess_pattern.gd) là nguồn sự thật.
**13 nước đi**, 12 đang có quân dùng (`RADIAL` đã nghỉ hưu).

- Xe/Tượng/Hậu **trượt** → **quân của mình CHẶN** đường. Địch không chặn.
- Mã/Tốt/Vua **nhảy** → không bị chặn.
- **Pháo** (cờ tướng) cần **đúng một** quân làm ngòi.
- **TẦM = SỐ VÒNG.** Vòng k = bước gốc × k. Không có luật này thì `+1 tầm` là
  số chết với 6/13 nước đi (nước nhảy là tập ô cố định).

Hai điểm vào **phải khớp nhau tuyệt đối**:
```gdscript
ChessPattern.cells(kind, from, max_range, blocked, pierce) -> Array[Vector2i]
ChessPattern.covers(kind, from, to, max_range, blocked, pierce) -> bool
```

---

## §2. Bất biến — vi phạm là hỏng game

| # | Bất biến | Hỏng thế nào |
|---|---|---|
| 1 | Mặt trên tile trong grid **phải** ở `y = 0` | mouse picking cắt ray-plane y=0 |
| 2 | Nguyên tố đến từ **Ô**, không từ loại quân | không có "tháp hoả"; `tower.current_element()` đọc ô dưới chân |
| 3 | Bàn khoá **8×8** cả ván + **trần số quân** | ô khan hiếm là thứ tạo ra câu đố xếp hình |
| 4 | `cell_mult = combat_mult × residual_mult` | §1 |
| 5 | Sao (`star`) là phép **NHÂN**, không qua `BuffLayer` | BuffLayer là cộng; đi qua đó sẽ nhân chồng |
| 6 | `-1` là "không đổi" cho nước đi, **không phải `0`** | `0` là `Kind.ROOK` hợp lệ |
| 7 | Chế độ **ĐẶT** dùng `GridUtil`; info/sa thải dùng `PickUtil` | §8, hàng "không đặt được quân" |
| 8 | `Engine.time_scale` **không bao giờ = 0** | pause dùng `get_tree().paused` |
| 9 | Đồng hồ hệ nguyên tố ở `ReactionTable`, **không** dùng `Time.get_ticks_msec()` | đồng hồ hệ thống không co theo time_scale, chạy cả khi pause |
| 10 | Mọi từ chối thao tác **phải nói lý do** | `push_warning` chỉ ra console; người chơi thấy click biến mất |

---

## §3. Bản đồ kiến trúc

### Autoload — chỉ có **4**

```
GameManagerSingleton   scripts/managers/GameManager.gd    state, vàng, HP, perk_*, relic_*
SceneManagerSingleton  scripts/managers/SceneManager.gd
SettingsManagerSingleton
AudioManagerSingleton  play_sfx(name, db, pitch)
```

> Mọi thứ khác (`SynergyManager`, `WaveSpawner`, `TerritoryManager`,
> `ShopPanelManager`, `KingManager`, `BoardScore`, `PerkSystem`…) là **child node
> của `game_map`**, không phải autoload. Với tới bằng `map.get("ten_field")`.

### File chính

| File | Dòng | Vai trò |
|---|---|---|
| [game_map.gd](../scripts/map/game_map.gd) | 1540 | **orchestration** — đọc trước khi sửa gameplay |
| [game_hud.gd](../scripts/ui/game_hud.gd) | 3017 | HUD; 7 component tách ở `scripts/ui/hud/` |
| [grid_controller.gd](../scripts/map/grid_controller.gd) | 1409 | bàn cờ, ô, biome |
| [tower.gd](../scripts/towers/tower.gd) | 1278 | quân — chỉ số, nước đi, tầm phủ |
| [board_score.gd](../scripts/map/board_score.gd) | 700 | Nền × Bội |
| [wave_spawner.gd](../scripts/map/wave_spawner.gd) | 676 | wave, boss, đường cong độ khó |
| [relic_system.gd](../scripts/items/relic_system.gd) | — | di vật |
| [relic_conditions.gd](../scripts/items/relic_conditions.gd) | — | engine điều kiện/bộ đếm |

### Luồng một tính năng

```
Người chơi bấm
   ↓
game_map._unhandled_input  (hoặc HUD signal)
   ↓
Hệ con xử lý (tower_placer / shop_manager / territory_manager)
   ↓
signal phát ra
   ↓
GameManager cập nhật state  →  game_map.update_ui()
   ↓
HUD vẽ lại  +  AudioManager phát tiếng
```

### Component HUD — cạm bẫy tham chiếu

Gắn bằng `X.attach(hud)` ⇒ **cha nó là HUD (CanvasLayer), KHÔNG phải game_map**.
Dùng `get_parent()` để tìm game_map sẽ luôn trả null — đã làm chết cả mục nguyên
tố + nút bán ô trong panel quân. Dùng helper `_map()`.

Component **không được** tham chiếu ngược `GameHUD.C_GOLD` — hai `class_name`
trỏ vòng nhau thì Godot không phân giải kiểu. Bảng màu ở `UIStyle.HUD_*`.

---

## §4. Nội dung hiện có

| Loại | Số | Nguồn |
|---|---|---|
| Quân cờ | **20** (12/13 nước đi) | `res/towers/*.tres` |
| Địch | **10** + 3 Rival King | `res/enemy/*.tres` |
| Di vật | **100** (22 đổi luật · 78 chỉ số) | `res/relics/*.tres` |
| Perk | 25 | `res/perks/*.tres` |
| Trang bị / Thuốc | 20 / 20 | `res/equipment/` · `res/potions/` |
| Vua | 6 | `res/kings/*.tres` |
| Bộ khai cuộc | 6 | `res/decks/*.tres` |
| Thế cờ (quân) | 7 | `chess_formations.gd` |
| Hình thế ô | 4 | `formation_detector.gd` |
| Nguyên tố / phản ứng | 6 / 10 | `element_types.gd` · `reaction_table.gd` |
| Luật Rival King | 6 | `king_rules.gd` |
| Encounter | 18 | bảng cứng trong `EncounterManager.gd`¹ |
| Nâng cấp meta | 14 | bảng cứng trong `meta_progression.gd` |

¹ `EncounterManager` **thử** nạp `res://res/encounters/*.tres` trước; thư mục đó
chưa tồn tại nên nó rơi về bảng cứng. Tạo thư mục + thả `.tres` vào là chúng
thắng bảng cứng — không phải sửa code.

### Hệ đã TẮT bằng cờ (code còn nguyên)

`seasons` · `biome_climate` · `unit_synergy` · `special_tiles` · `crit` ·
`kill_combo` · `map_expansion`

Lý do từng cái ghi trong [feature_flags.gd](../scripts/managers/feature_flags.gd).
Bật lại = đổi một hằng, **nhưng phải đo lại cân bằng**.

---

## §5. Đường cong độ khó

**Được THIẾT KẾ, không để tự nảy ra.** [wave_spawner.gd](../scripts/map/wave_spawner.gd):

```gdscript
target_wave_hp(w) = WAVE_HP_BASE × WAVE_HP_GROWTH^(w-1)   # × BOSS_WAVE_HP_MULT ở wave boss
```

`get_health_multiplier()` giờ là hệ số **NẮN** tổng máu về đường cong đó — nó
**không còn** là đường cong độ khó. Wave boss chỉ có 6 lính nên hệ số của nó to
gấp ba wave thường; **đó là đúng, đừng "sửa"**.

Máu hiện tại: `900 · 1202 · 1604 · 2141 · 3287 · 3816 · 5095 · 6802 · 10442 ·
12122 · 16183 · 24845`

**Máu Rival King có đường cong RIÊNG** (`BOSS_HP_BASE`/`BOSS_HP_GROWTH`) và chia
cho tốc độ của chính hắn. Lý do là bất đối xứng cấu trúc: dọn cả wave thì thêm
quân ở đâu cũng có ích, còn hạ MỘT con boss thì chỉ quân phủ đúng đường hắn đi
mới tính. Buộc chung một đường thì boss bỏ xa người chơi mỗi wave một chút.

**Dial duy nhất để chỉnh độ khó tổng:** `WAVE_HP_GROWTH`.
Đo được (bot n=30, mua di vật ngẫu nhiên): `1.285 → 30%` · `1.335 → 16%` · `1.405 → 20-26%`.

---

## §6. Thêm nội dung

### 6.1 Quân cờ · Địch · Vua · Bộ khai cuộc — **một file `.tres`**

Chép template rồi sửa. Không đụng code.

```
res/towers/_template_tower.txt     →  res/towers/<id>.tres
res/enemy/_template_enemy.txt      →  res/enemy/<id>.tres
```

Bắt buộc: `id` (snake_case, duy nhất) · `attack_pattern` (quân) ·
`spawn_seasons` + `spawn_weight` + `weak_element` (địch — thiếu thì **không bao
giờ spawn**).

Ảnh: `assets/towers/<id>.png`, model `assets/models/<id>.gltf` (thiếu model →
tự rơi về sprite 2D).

`python tools/new_content.py <loại> <id>` sinh khung + in danh sách ảnh cần vẽ.

### 6.2 Di vật CỘNG CHỈ SỐ — **một file `.tres`, không đụng code**

```gdscript
effect = {
"cond_mult": { "many_veins": 1.20, "no_veins": -0.48 },   # âm = MẶT TRÁI
"per_mult":  { "veins": 0.30 }                            # chỉ tính phần VƯỢT SÀN
}
```

**21 điều kiện** (`cond_mult`):
`few_pieces` `many_pieces` `full_board` `no_veins` `many_veins` `has_formation`
`three_formations` `boss_wave` `odd_wave` `even_wave` `rich` `broke` `has_star3`
`all_star2` `single_kind` `five_kinds` `king_hurt` `full_hp` `deck_thin`
`late_wave` `always`

**17 bộ đếm** (`per_mult`):
`pieces` `empty_squares` `formations` `formation_kinds` `veins` `vein_levels`
`elements` `stars` `pawns` `rooks` `knights` `bishops` `queens` `cannons`
`relics` `wave` `path_covered`

Ngưỡng + **sàn** ở [relic_conditions.gd](../scripts/items/relic_conditions.gd)
(`COUNT_FLOOR`). Sàn `knights = 3` ⇒ 3 Mã cho **0**, 6 Mã cho 3 đơn vị.

> **Luật thiết kế: phải có MẶT TRÁI.** Không phạt thì mua bừa vẫn là nước đi an
> toàn — đo được bot mua bừa thắng 50%. Hiện 52/69 di vật engine có mặt trái.
> Test batch 3 bắt tỉ lệ này ≥70%.

Thêm hàng loạt: sửa bảng trong [tools/make_relics.py](../tools/make_relics.py)
rồi `python tools/make_relics.py` (tự tính giá, tự gắn mặt trái, tự kiểm trùng id).

### 6.3 Di vật ĐỔI LUẬT — **6 bước, thiếu một là chết âm thầm**

Ví dụ chạy suốt: `rl_fortress` (mọi Xe thành Pháo).

| # | Chỗ | Nội dung |
|---|---|---|
| 1 | `relic_system.EFFECT_KEYS` | khai khoá mới |
| 2 | `relic_system.totals()` | giá trị mặc định |
| 3 | `totals()` nhánh `match` | luật gộp khi sở hữu 2 món cùng khoá |
| 4 | `relic_system._apply_all()` | `gm.set("relic_x", ...)` |
| 5 | **NGƯỜI ĐỌC trong trận** | vd `tower.pattern_kind()` |
| 6 | cuối `_apply_all()` | `Tower.bump_layout()` + `refresh_coverage()` nếu đổi nước đi |

Luật gộp có sẵn: `OR` (bool) · `NHÂN` (hệ số) · `CỘNG` (`knight_reach`,
`pierce_count`) · **món sau ĐÈ** (`pawn_pattern`).

> **Bước 1 là chỗ chết người.** `_sanitize` lọc trắng — khoá lạ bị **vứt im
> lặng** (chỉ `push_warning`). Món vẫn mua được, vẫn hiện mô tả đầy đủ, và
> **không làm gì**. Đã dính với 8 di vật cùng lúc.

**Câu hỏi phải tự trả lời trước khi viết dòng nào:**
> *"Ai NHÂN nó vào sát thương / ai ĐỌC nó trong trận?"* — không phải "ai đọc
> field này". `audit_wiring.py` chỉ trả lời được câu sau, và nó **đã bỏ lọt**
> 7 thế cờ + 9 di vật (chúng có người đọc, nhưng người đọc đó chỉ vẽ HUD).

**Chọn đúng chỗ cắm:**

| Muốn đổi | Cắm vào |
|---|---|
| nước đi | `tower.pattern_kind()` |
| tầm / số vòng | `tower.effective_range()` |
| chặn đường trượt | `tower.pierce_count()` |
| chỉ số (nhân) | `tower.recalculate_stats()` |
| chỉ số (cộng) | `BuffLayer` |
| luật nguyên tố | `ReactionTable` / `ElementMarks` |
| ô nguyên tố | `TerritoryManager.get_element_bonus()` |
| kinh tế, shop | `ShopPanelManager` |

### 6.4 Perk · Thuốc · Trang bị

`.tres` ở `res/perks/`, `res/potions/`, `res/equipment/`; hoặc JSON ở `data/`.

Thứ tự nạp (`ContentLoader.load_dir`): **bảng cứng → `.tres` → JSON**, trùng
`id` thì bản sau thắng. Bản export mang đuôi `.remap` — phải `trim_suffix()`
trước khi `load()`.

### 6.5 Icon

| Loại | Đường dẫn | Cỡ |
|---|---|---|
| Di vật | `assets/ui/relics/<id>.png` | 32×32 |
| Trang bị / Thuốc | `assets/ui/equipment/` · `potions/` | 32×32 |
| Perk | `assets/ui/perks/<id>.png` | 48×48 |
| Quân | `assets/towers/<id>.png` | 32×32 |

Tên file **trùng đúng `id`** — code ghép chuỗi, không có bảng ánh xạ.
Thiếu icon → tự rơi về nhãn chữ, **không vỡ UI**.

> **Vẽ art phải qua gamedev toolkit MCP** (Aseprite MCP cho 2D, Blockbench MCP
> cho 3D). Không tự viết script sinh PNG.
> Số lượng lớn thì dùng `mcp__aseprite__run_lua_script` — vẫn là đường MCP.
> **BẪY**: server không nhận ký tự ngoài ASCII trong script Lua.

---

## §7. Đo và cân bằng

### Nguyên tắc số một

> **Đo trước, sửa sau. Không đoán.**
> Lớp lỗi hay gặp nhất ở dự án này **không phải crash** mà là *tính năng chết âm
> thầm*: khai báo đủ, mô tả đẹp, và không làm gì cả.

### Bộ công cụ

```bash
python tools/run_tests.py            # 421 khẳng định, 12 batch, chạy trên GAME THẬT
python tools/run_tests.py 3 12       # chọn batch
python tools/check_content.py        # thiếu field, trùng id, thiếu icon/model
python tools/check_art.py            # số màu, lệch hoa-thường, ảnh mồ côi
python tools/audit_wiring.py         # signal/field khai mà không ai đọc
godot --headless --script res://tools/content_report.gd   # kiểm kê nội dung
```

### Bot chơi trọn ván

```bash
python tools/bot_bench.py 5                              # 5 ván × 6 bộ bài
python tools/bot_bench.py 5 relics=off|any|fit           # chiến lược mua di vật
python tools/bot_bench.py 5 relics=fit build=element     # + cam kết một lối chơi
```

Bot là **ngưỡng SÀN** — không dùng thuốc, không tính perk. Người chơi phải hơn nó.

CSV mỗi wave: `wave,hp,vàng,quân,ratio,rd,divat=n/xM,dmg1t,hp_mất,lọt`

### Ba điều PHẢI biết khi đọc số

**1. Tỉ lệ thắng nhiễu ±9 điểm ở n=30.** Chênh lệch dưới 15 điểm **không kết
luận được gì**. Đã ba lần đọc 10–20 điểm thành "có ý nghĩa" rồi bị lần đo sau
bác bỏ.

**2. Cần chính xác thì đo BỘI, không đo tỉ lệ thắng.** Cột `divat=n/xM` đo thẳng
cơ chế, nhiễu thấp hơn nhiều.

**3. `relics=fit` KHÔNG phải mô hình người chơi giỏi.** Nó chỉ *kén hơn* khi
mua, mà kén thì để trống ô di vật ⇒ nó thua cả bot mua bừa. Muốn chứng minh
"chọn đúng thì thắng" phải viết bot **biết XÂY** (dồn ô lên Lv3, ghép sao, xếp
thế cờ có chủ đích). **Chưa có nó thì mọi số về `fit` là nhiễu.**

### Hiệu chỉnh bảng số

`bot_bench.py` in mục *"hieu chinh bang so"*: ratio trung bình ở wave **THUA** so
với wave **SỐNG QUA**, và một mục **riêng cho wave boss**.

Mốc lành mạnh: thua < 1.0 < sống. Wave boss có điều kiện thua RIÊNG (boss chạm
Vua = thua ngay), nên nó được so riêng.

### Viết test cho dự án này — 4 bẫy

1. **Lambda GDScript bắt biến local theo GIÁ TRỊ.** Dùng `Array`/`Dictionary`.
2. **`grid_data` chứa lẫn `Node` và `String`** (marker ô). Lọc `if v is Node`.
3. **Đừng bắt một luật phải có tác dụng SỐNG trên bàn hiện tại.** `toll_king`
   (Bội = 1 − số_quân×3%) trả 1.0 khi bàn trống là **đúng đắn**. Kiểm **khai
   báo**, không kiểm tác dụng sống — nếu không test chập chờn theo thế đường.
4. **Chạy lặp 3 lần.** Hướng đường đi và hàng trong shop là ngẫu nhiên.

---

## §8. Bảng bẫy — tra khi "tính năng không chạy"

| Triệu chứng | Nguyên nhân thật | Sửa |
|---|---|---|
| Di vật mua được, mô tả đủ, **không làm gì** | khoá không có trong `EFFECT_KEYS`, bị `_sanitize` vứt im lặng | §6.3 bước 1 |
| Số trên HUD đổi, **sát thương không đổi** | dòng `mult_breakdown` thiếu cờ `combat` | §1 |
| Di vật chỉ ăn với quân đặt **SAU** khi mua | thiếu `Tower.bump_layout` + `refresh_coverage` | §6.3 bước 6 |
| Bội **ghim vĩnh viễn** sau khi gỡ quân | `queue_free()` để node trong cây tới cuối frame, mà signal xử lý ĐỒNG BỘ | lọc `is_queued_for_deletion()` |
| **Không đặt được quân**, càng nhiều quân càng tệ | chế độ đặt dùng `PickUtil` — hộp click cao 1.5 m phủ 2 ô phía trước | dùng `GridUtil` cho chế độ ĐẶT |
| Click biến mất, **không báo gì** | nhánh `return` im lặng | phát `place_rejected` |
| Panel HUD **trống trơn** | component dùng `get_parent()` để tìm game_map (cha nó là HUD) | dùng `_map()` |
| Panel **phình dần không co lại** | `queue_free()` con nhưng chưa `remove_child()` | `remove_child()` TRƯỚC |
| `+1 tầm` **không đổi gì** | nước NHẢY là tập ô cố định | TẦM = SỐ VÒNG (§1) |
| Panel không co theo nội dung | panel không nằm trong container | `_resize_*.call_deferred()` |
| Panel cắt mất dòng cuối | đo minimum size của panel bọc `ScrollContainer` | đo VBox BÊN TRONG |
| Quái **hồi máu khi bị bắn** | sát thương âm (trang bị đánh đổi × di vật) | `current_damage` sàn 1 |
| `match` GDScript lỗi parse | pattern xuống dòng | gộp một dòng |
| `get_meta(key, null)` vẫn lỗi | thiếu key | `has_meta` trước |
| Model 3D **chết hàng loạt** | xoá `assets/models/<id>_N.png` | **KHÔNG BAO GIỜ xoá** — Godot trích texture nhúng ra đó |
| Chữ đổi `font_size` **không đổi cỡ** | bitmap font không khai `fixed_size` | `UIStyle.font_for(size)` — nắn về 14/28/42 |
| Ký hiệu ra **ô tofu / màu cam** | Unicode `Emoji_Presentation` bị ép sang font hệ thống | dùng PUA `U+E001..E010` (`Glyphs`) |
| Test batch **không khởi động** giữa chuỗi | flaky của Godot headless | runner tự thử lại 1 lần |

### Phím đã bị chiếm

`camera_controller` **poll thẳng** `Input.is_key_pressed()` ⇒ `set_input_as_handled()`
vô hiệu. **Không dùng** `W` `A` `S` `D`. Thuốc dùng `Z/X/C`, bộ quân dùng `B`.

---

## §9. Quy trình chuẩn cho một thay đổi

```
1. ĐO trạng thái hiện tại        (bot_bench / probe / content_report)
2. Sửa
3. ĐO lại — cùng phép đo         (số phải nhúc nhích ĐÚNG chiều)
4. python tools/run_tests.py     (nhóm batch, đừng chạy 12 batch một lần)
5. python tools/check_content.py
6. Thêm test chốt bất biến vừa sửa
7. Chụp màn nếu đổi UI
8. Commit — chép SỐ ĐO vào message
```

### Viết commit

Ghi **con số**, không ghi tính từ. Mẫu tốt:

```
fix: game giờ THẮNG được — sửa đường cong độ khó

TRƯỚC: bot chơi 18 ván, THẮNG 0. Mất 0 máu suốt 9 wave rồi chết sạch một wave.
SAU:   bot thắng 7/18 (39%). Mọi bộ bài đều tới được wave 12.

Đo bản cũ: 433 581 767 1476 2452 2221 4524 ...
  = ×1.32 ×1.92 ×1.66 ×0.91 ×2.04 — HAI wave TỤT máu, BA wave nhân đôi.
```

Quy ước: `feat|fix|refactor|docs|test|chore|perf|ci: <mô tả>`

---

## §10. Chưa xong / còn nợ

| Việc | Trạng thái |
|---|---|
| Bot **biết XÂY** để đo giá trị của việc chọn đúng di vật | **chưa có** — chặn mọi kết luận về cân bằng di vật |
| Model 3D cho 5 quân biến thể cờ | dùng sprite 2D thay thế |
| 100 icon di vật vẽ bằng script Python | **cần vẽ lại qua Aseprite MCP** |
| Cân bằng 6 Bộ Khai Cuộc | mới đo "chạy đúng", chưa đo bộ nào quá mạnh |
| Người thật chơi thử | **chưa có ai** — bot đo được cân bằng, không nói được chỗ nào chán |
| Export desktop | mới build Web; desktop cần template ~800 MB |

---

## §11. Tài liệu khác

| File | Nội dung |
|---|---|
| [CLAUDE.md](../CLAUDE.md) | **nhật ký** — vì sao từng quyết định được đưa ra, kèm số đo |
| [CONTENT_AUTHORING.md](CONTENT_AUTHORING.md) | bảng "thêm một thứ mất bao nhiêu file" |
| [ART_STATUS.md](ART_STATUS.md) | khảo sát hình ảnh, thước đo art thật vs programmer art |
| [RELEASE_READINESS.md](RELEASE_READINESS.md) | đánh giá phát hành |

> Sửa gameplay xong thì **cập nhật cả file này lẫn CLAUDE.md**: file này ghi
> *cách làm*, CLAUDE.md ghi *vì sao* kèm số đo.
