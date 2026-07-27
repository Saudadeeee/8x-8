# Hướng Dẫn Tạo Nội Dung — 8x-8

Tài liệu thực dụng để thêm **Perk / Quân (Tower) / Địch (Enemy)** mà không cần
sửa code lõi. Mọi mô tả dưới đây đã được đối chiếu với code hiện tại
(`perk_system.gd`, `shop_manager.gd`, `wave_spawner.gd`, `SynergyManager.gd`).

## Tra nhanh — thêm một thứ mất bao nhiêu file?

| Muốn thêm | Sửa gì | Có phải viết code không? |
|---|---|---|
| **Quân cờ** (tower) | 1 file `res/towers/<id>.tres` (+ `assets/models/<id>.gltf`) | Không |
| **Địch** | 1 file `res/enemy/<id>.tres` — nhớ điền `spawn_seasons` | Không |
| **Perk** | 1 file JSON trong `data/perks/` | Không |
| **Lõi buff = Trang bị** | 1 file JSON trong `data/equipment/` (+ icon 32×32) | Không |
| **Di vật** (buff cả run) | 1 file JSON trong `data/relics/` (+ icon) | Không |
| **Thuốc** (dùng giữa trận) | 1 file JSON trong `data/potions/` (+ icon) | Không |
| **Nhánh synergy MỚI** | thêm giá trị vào `enum UnitType` + `res/synergies/<tag>.tres` | Có, 1 dòng |
| **Nguyên tố / phản ứng mới** | `element_types.gd` + `reaction_table.gd` | Có |

Xong thì **luôn chạy**:

```
python tools/check_content.py
```

Nó bắt các lỗi khiến nội dung mới "có mà không chạy": thiếu field, trùng `id`,
tầm bắn vượt trần, địch không bao giờ spawn, thiếu icon/model. `LOI` là chắc
chắn hỏng; `CANH` là tuỳ ý (ví dụ chưa kịp vẽ icon).

---

## 1. Thêm PERK (JSON — không cần sửa code)

### Cách game nạp

`scripts/perks/perk_system.gd` khi `_ready` sẽ quét **`res://data/perks/`**,
nạp **mọi file `*.json`**. Mỗi file phải là **một JSON array** các perk object.
Perk hợp lệ được merge vào pool chung cùng perk built-in và đi qua đúng
pipeline (roll theo trọng số rarity, stack, eligibility...) — không có
special-case nào. Perk lỗi chỉ bị `push_warning` + bỏ qua, **không bao giờ**
làm hỏng perk built-in hay các perk khác trong cùng file.

### Schema đầy đủ

| Field | Kiểu | Bắt buộc | Ghi chú |
|---|---|---|---|
| `id` | String | ✅ | snake_case, **duy nhất** (trùng id có sẵn → bị bỏ qua + warning) |
| `name` | String | ✅ | tên hiển thị trên card |
| `desc` | String | ✅ | mô tả trên card |
| `rarity` | String | ✅ | `common` \| `rare` \| `epic` \| `legendary` |
| `stackable` | bool | ❌ | `true` = được chọn lặp lại nhiều lần (mặc định `false`) |
| `requires_hp` | int | ❌ | chỉ xuất hiện trong draft khi HP King ≥ giá trị này |
| *kênh hiệu ứng* | object | ✅ ít nhất 1 | xem bảng dưới |

**Trọng số rarity khi roll:** common 60 · rare 25 · epic 12 · legendary 3.

### Kênh hiệu ứng (effect channels)

Perk phải có **ít nhất một** kênh dưới đây với **ít nhất một** subkey hợp lệ:

| Kênh | Subkey | Ý nghĩa | Cách cộng dồn khi nhiều perk |
|---|---|---|---|
| `tower` | `damage_bonus` | +% sát thương theo base damage (0.10 = +10%) | **cộng dồn** |
| | `speed_bonus` | số **giây** trừ vào cooldown đánh (0.08 = nhanh hơn 0.08s) | cộng dồn |
| | `range_bonus` | +số **ô** tầm bắn (int) | cộng dồn |
| `economy` | `gold_per_kill` | +vàng mỗi kill | cộng dồn |
| | `interest_cap` | trần lãi vàng cuối wave (mặc định 15) | lấy **max** |
| | `interest_rate` | lãi suất cuối wave (mặc định 0.10) | lấy **max** |
| `instant` | `hp_delta` | ±máu King ngay lập tức (âm được, nhưng không được giết player) | one-shot |
| | `gold_delta` | ±vàng ngay lập tức | one-shot |
| `rd` | `per_wave_start` | +Royal Decree mỗi khi wave mới bắt đầu | cộng dồn |
| | `grant_mult` | hệ số RD nhận khi thắng wave (1.5 = +50%) | lấy **max** |

Subkey lạ trong kênh hợp lệ → warning + bỏ qua subkey đó (perk vẫn dùng được
nếu còn subkey hợp lệ khác). Kênh `tower` được gộp thành MỘT layer PERK duy
nhất re-apply cho mọi tháp (giống synergy).

### Ví dụ copy-paste (file `data/perks/my_perks.json`)

```json
[
	{
		"id": "khien_go_soi",
		"name": "Khiên Gỗ Sồi",
		"rarity": "common",
		"desc": "+6 máu ngay lập tức.",
		"instant": {"hp_delta": 6},
		"stackable": true
	},
	{
		"id": "phao_dai_thep",
		"name": "Pháo Đài Thép",
		"rarity": "legendary",
		"desc": "+25% sát thương, +1 tầm bắn toàn bộ tháp.",
		"tower": {"damage_bonus": 0.25, "range_bonus": 1}
	}
]
```

Lưu ý JSON: **không trailing comma**, số thập phân dùng dấu chấm. File mẫu
đang chạy: `data/perks/custom_perks.json` (3 perk ví dụ).

---

## 2. Thêm QUÂN (Tower)

### Quy trình nhanh

1. Copy một file có sẵn trong `res/towers/` (vd `longbowman.tres`) hoặc dùng
   template chú thích đầy đủ: **`res/towers/_template_tower.txt`**.
2. Đổi tên file thành `<id_moi>.tres`, sửa `id` + stats bên trong.
3. Xong — **shop tự nhận diện**: `shop_manager.gd → _populate_default_items()`
   dùng `DirAccess` quét mọi `.tres` trong `res://res/towers/` và tạo shop item
   TROOP (giá = field `cost`).

### Ý nghĩa field + đơn vị (xem chú thích chi tiết trong template)

- `cost` — **vàng** mua trong shop · `decree_cost` — **RD** khi triển khai.
- `base_damage` (int) · `attack_speed` — **giây/đòn** (nhỏ = nhanh) ·
  `attack_range` — **số ô** (1 ô = 1 m).
- `splash_radius` — **px**, 16 px = 1 ô (runtime tự chia 16).
- `slow_amount` 0–1 + `slow_duration` giây · `burn_dps` + `burn_duration` giây ·
  `projectile_count` >1 = multishot.
- `type` — chỉ số enum `TowerStats.UnitType` (0=PAWN … 14=BALLISTA), quyết định
  **nhóm synergy**. `element`, `faction` ("iron"/"wild"/"hell"/"magic").

### Model 3D

Đặt tại `assets/models/<id>.gltf` (Blockbench: 16 units = 1 m = 1 ô, tower cao
~18–29 units). **Không có model cũng chạy được** — game tự fallback billboard
Sprite3D từ field `texture`.

### Synergy

`SynergyManager.gd` map tower → synergy bằng tag =
`UnitType.keys()[stats.type].to_lower()` (vd type 11 → tag `"paladin"`).
Definitions lấy theo thứ tự:
1. `res://res/synergies/*.tres` nếu có (auto-load);
2. fallback: bảng hardcode trong `_ensure_default_definitions()`.

→ Tower mới dùng **type có sẵn** thì tự hưởng synergy của type đó. Muốn type
mới hoàn toàn: thêm vào enum `UnitType` trong `scripts/towers/TowerStats.gd`
**và** thêm định nghĩa vào `SynergyManager.gd` (chỉ đường — file này thuộc
nhóm world, sửa cẩn thận).

### Khóa theo wave (min-wave gating)

Dict `BOSS_TROOP_MIN_WAVE` trong `scripts/shop/shop_manager.gd`:

```gdscript
const BOSS_TROOP_MIN_WAVE: Dictionary = {
	"queen": 4, "commander": 4, ...  # id không có trong dict → mở từ wave 1
}
```

Thêm `"<id_moi>": <wave>` nếu muốn tower chỉ xuất hiện trong shop từ wave N.

---

## 3. Thêm ĐỊCH (Enemy)

### Quy trình nhanh

1. Copy file trong `res/enemy/` (vd `troll.tres`) hoặc dùng template:
   **`res/enemy/_template_enemy.txt`**.
2. Đổi tên `<id_moi>.tres`, sửa `id` (KHÔNG được rỗng) + stats.
3. `wave_spawner.gd → _load_enemy_stats()` tự nạp mọi `.tres` trong
   `res://res/enemy/` vào registry theo `id`.
4. **Điền `spawn_seasons`** trong chính file `.tres` đó — nếu để rỗng thì loài
   này nạp được nhưng **không bao giờ spawn**.

```
spawn_seasons = Array[int]([0, 1])   ; 0=Xuân 1=Hạ 2=Thu 3=Đông
spawn_weight = 2                     ; số bản sao thả vào pool mỗi mùa
display_name = "Sói Tuyết"           ; tên hiện ở popup trinh sát / codex
ability_note = "Chạy theo bầy, né chậm"
```

`wave_spawner._append_data_driven_enemies()` đọc thẳng các field này. Mười loài
có sẵn để `spawn_seasons` rỗng vì chúng nằm trong bảng mùa cứng
(`_get_season_enemy_pool`) — giữ nguyên để tần suất cân bằng cũ không đổi. Loài
MỚI thì dùng field, không phải đụng vào bảng đó.

### Field + đơn vị

- `max_hp` (int) — scale +12%/wave · `speed` — **px/giây**, 16 px = 1 ô/s
  (runtime chia 16), scale +3%/wave · `damage_to_base` — máu King mất khi lọt ·
  `gold_reward` — vàng khi diệt.
- **Abilities đặc biệt** (0 = tắt):
  - `armor` — giáp phẳng, mỗi đòn trừ đi [armor] dmg, tối thiểu còn 1 (golem 6).
  - `regen_per_sec` — hồi máu/giây (troll 8).
  - `heal_aura_amount` + `heal_aura_radius` — hồi máu đồng minh trong bán kính
    **mét** (shaman 6 / 1.6 m). Cả hai phải > 0.

### Khắc / kháng nguyên tố

Để rỗng thì lấy mặc định theo `id` trong `EnemyStats.DEFAULT_AFFINITY`. Ghi đè
bằng `weak_element` / `weak_element_2` / `resist_element` (khắc ×1.5, kháng ×0.6).
Loài mới **nên có ít nhất một điểm yếu** — không thì mọi hệ nguyên tố đánh nó
như nhau và việc chọn hệ mất ý nghĩa.

### Các bảng cũ (chỉ để tương thích ngược)

`wave_spawner._ENEMY_DISPLAY_NAMES` và `EnemyStats.ABILITY_NOTES` giữ tên/ghi
chú của 10 loài đời đầu. Loài mới **không cần** đụng vào: field trong `.tres`
được ưu tiên, hai bảng đó chỉ là nơi tra dự phòng.

Model 3D: `assets/models/<id>.gltf`; thiếu → tự fallback billboard từ `texture`.

---

## 4. Thêm THUỐC / TRANG BỊ / DI VẬT (JSON — không cần sửa code)

Ba hệ vật phẩm dùng chung một khuôn: mỗi hệ quét một thư mục, nạp **mọi file
`*.json`**, mỗi file là **một JSON array** các object. Entry trùng `id` với
built-in sẽ **ghi đè** built-in (dùng để chỉnh cân bằng mà không đụng code);
`id` mới thì thêm vào pool.

| Hệ | Thư mục | File code | Bảng khoá hợp lệ |
|---|---|---|---|
| Thuốc | `res://data/potions/` | `scripts/items/potion_system.gd` | `BUFF_KEYS` · `STRIKE_KEYS` · `SPECIALS` |
| Trang bị | `res://data/equipment/` | `scripts/items/equipment_system.gd` | `EFFECT_KEYS` |
| Di vật | `res://data/relics/` | `scripts/items/relic_system.gd` | `EFFECT_KEYS` |

**Khoá lạ trong `effect` bị bỏ qua kèm `push_warning`** — sai chính tả không im
lặng trôi qua. Xem Output của Godot sau khi sửa JSON.

### Trang bị — ví dụ copy-paste (`data/equipment/my_gear.json`)

```json
[
  {
    "id": "vong_lua",
    "name": "Vòng Lửa",
    "slot": "accessory",
    "rarity": "epic",
    "cost": 130,
    "desc": "Luôn bắn Dấu Hoả và phản ứng mạnh thêm 25%.",
    "effect": {"grant_element": "fire", "reaction_power_mult": 1.25}
  }
]
```

`cost` ghi bằng **vàng** (dùng cho giá bán lại 50%); shop tự quy đổi sang Royal
Decree bằng `ShopPanelManager.EQUIP_GOLD_PER_RD`.

### Di vật — ví dụ (`data/relics/my_relics.json`)

```json
[
  {
    "id": "chuong_bao_tu",
    "name": "Chuông Báo Tử",
    "rarity": "legendary",
    "cost": 300,
    "desc": "Địch mang Dấu nhận thêm 25% sát thương từ mọi nguồn.",
    "effect": {"marked_damage_taken": 0.25}
  }
]
```

Di vật **không cộng dồn cùng id** và tối đa 5 ô. `RelicSystem._apply_all()` luôn
tính lại từ đầu rồi ghi đè — thêm khoá mới thì phải khai cả trong `EFFECT_KEYS`
lẫn `totals()` **và** nơi tiêu thụ giá trị đó.

### Perk lối chơi nguyên tố

Kênh `element` trong perk JSON (xem `data/perks/element_perks.json`). Subkey hợp
lệ liệt kê ở `PerkSystem.EFFECT_CHANNELS["element"]`; giá trị có thể là số, `true`,
hoặc object (`element_damage`: `{"fire": 0.5}`).

---

## 5. Thêm ENCOUNTER tặng ô nguyên tố

`EncounterChoice` có hai field cho việc này (xem `scripts/managers/EncounterManager.gd`,
helper `_choice_tiles`):

| Field | Nghĩa |
|---|---|
| `element_tiles` | số ô được tặng (2 ô chồng lên nhau = Lv2, 3 ô = Lv3) |
| `element_tile_kind` | `"dominant"` (hệ đang mạnh nhất) · `"random"` · id nguyên tố cụ thể |

Ô được tặng vào **kho**, không đặt sẵn lên bàn — chọn vị trí là quyết định của người chơi.

```gdscript
_choice_tiles("Đào sâu theo mạch
[-8 HP  →  3 ô cùng hệ]",
    "Ba ô cùng loại xếp chồng thành một Long Mạch Lv3.", 0, -8, 3, "dominant")
```

---

## Checklist tổng khi thêm nội dung

- [ ] **Chạy `python tools/check_content.py` — 0 LOI** (bắt phần lớn mục dưới)
- [ ] `id` snake_case, duy nhất, trùng tên file `.tres` / model `.gltf`
- [ ] JSON perk: array hợp lệ, không trailing comma, chạy game xem Output có
      warning `PerkSystem:` nào không
- [ ] Tower mới: kiểm tra xuất hiện trong shop (roll vài lần — quầy 5 slot,
      trong đó **1 slot luôn được giữ cho quân**, xem `_pick_guaranteed_troop`)
- [ ] Perk mới: `rarity` quyết định wave sớm nhất nó xuất hiện —
      thường 1 · hiếm 3 · sử thi 5 · huyền thoại 8 (`RARITY_UNLOCK_WAVE`).
      Đặt `legendary` cho perk nhỏ thì cả run sẽ không ai thấy nó
- [ ] Enemy mới: đã điền `spawn_seasons` chưa? (rỗng = không bao giờ spawn)
- [ ] Vật phẩm mới: khoá trong `effect` phải nằm trong `EFFECT_KEYS` của hệ
      tương ứng, và phải có nơi ĐỌC giá trị đó (khai khoá thôi thì món vô dụng)
- [ ] Template chú thích: `res/towers/_template_tower.txt` ·
      `res/enemy/_template_enemy.txt` (nhớ XÓA dòng `#` khi lưu thành `.tres`)
