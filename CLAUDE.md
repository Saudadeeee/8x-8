# Project Instructions: 8x-8

## Tools

### Aseprite MCP — Pixel Art
Server: `D:\Code\SourceCode\Project\Godot x Aseprite MCP\aseprite-mcp`

Dùng cho mọi thao tác vẽ, sprite, animation. **KHÔNG dùng Godot tools để tạo art.**

**Project style:** Pixel art trung cổ/chiến tranh/cổ điển
- Palette: tối, trầm — nâu đất `#3d2b1f`, xám đá `#4a4a4a`, đỏ máu `#8b1a1a`, vàng đồng `#c8a000`, xanh rêu `#2d4a1e`
- Tile size chuẩn: **16×16 px**
- Unit sprites: **32×32** hoặc **48×48**
- UI icons: **16×16** hoặc **32×32**

**97 tools (tất cả đã có trong allow list):**
```
Canvas/File:  create_canvas · get_sprite_info · resize_sprite · crop_sprite · expand_canvas
              scale_sprite · trim_sprite · smart_resize_preserve_pixels · rotate_image
              flip_horizontal · flip_vertical · convert_color_mode · backup_sprite
              restore_sprite · optimize_file_size · compare_sprites
              batch_convert · batch_process_sprites

Drawing:      draw_pixels · draw_line (có thickness) · draw_rectangle · draw_circle
              draw_polygon · draw_bezier_curve · draw_gradient · draw_pattern
              draw_text · fill_area · erase_area

Layer:        add_layer · create_layer_group · move_layer_to_group · rename_layer
              set_layer_opacity · set_layer_blend_mode · toggle_layer_visibility
              copy_layer · merge_layers

Frame/Cel:    add_frame · clear_cel · copy_cel · move_cel · link_cel · set_cel_opacity

Palette:      create_palette · get_palette_colors · add_color_to_palette · replace_color
              load_palette_from_file · extract_color_palette_smart · invert_colors

Selection:    select_rectangle · select_all · deselect · invert_selection · delete_selection

Effects:      apply_blur · adjust_hue_saturation · adjust_brightness_contrast
              posterize · pixelate · outline · drop_shadow

Export:       export_sprite · export_sprite_sheet · export_sprite_sheet_with_json
              export_frames_separately · export_layers_separately · export_slices · export_tileset

Tileset:      create_tileset · create_tilemap_layer · import_tileset_from_image · get_tile · set_tile

Slices:       create_slice · create_nine_patch_slice · list_slices · export_slices

Clipboard:    copy_to_clipboard · paste_from_clipboard · paste_as_new_layer · cut_to_clipboard

Brush:        create_custom_brush · apply_brush_stroke · list_brushes
              set_brush_size · set_brush_angle · set_brush_pattern

Grid:         set_grid · toggle_grid · snap_to_grid

AI:           auto_color_sprite · auto_outline_sprite · upscale_sprite_ai
              generate_sprite_variations · auto_cleanup_lineart · suggest_improvements
```

---

### Godot MCP — Engine
Server: `D:\Code\SourceCode\Project\Godot x Aseprite MCP\Godot-MCP\server\dist\index.js`

Dùng cho mọi thao tác engine. **KHÔNG dùng Aseprite tools để build scene.**
Engine: **Godot 4.6.1 stable**, GDScript

**119 tools (tất cả đã có trong allow list):**
```
Node:         create_node · delete_node · update_node_property
              get_node_properties · list_nodes

Scene:        create_scene · save_scene · open_scene · get_current_scene
              get_project_info · create_resource

Script:       create_script · edit_script · get_script · create_script_template

Editor:       execute_editor_script

Playback:     play_main_scene · play_current_scene · play_custom_scene
              stop_playing_scene · get_play_status

Config:       set_project_setting · get_project_setting · list_project_settings
              add_input_action · add_input_event · remove_input_action · list_input_actions
              add_audio_bus · set_bus_volume · add_bus_effect · list_audio_buses
              set_physics_layer_name

TileMap:      set_tile_cell · erase_tile_cell · paint_tile_area · get_tile_data
              get_used_tiles · clear_tilemap_layer
              set_gridmap_cell · erase_gridmap_cell · get_gridmap_used_cells

Animation:    create_animation · delete_animation · list_animations
              add_animation_track · remove_animation_track
              insert_animation_key · remove_animation_key
              get_animation_data · play_animation · stop_animation

AnimTree:     configure_animation_tree · add_animation_tree_node
              connect_animation_tree_nodes
              set_animation_tree_parameter · get_animation_tree_parameter
              add_state_machine_transition · get_animation_tree_info

Material:     create_material · set_material_property · get_material_properties
              set_shader_code · set_shader_parameter

Import:       scan_filesystem · reimport_file · get_import_settings
              set_import_setting · list_filesystem_files

Navigation:   bake_navigation_mesh · get_navigation_path · set_navigation_target
              get_navigation_agent_info · configure_navigation_region
              set_navigation_mesh_property

Particles:    configure_particles · set_particle_material
              set_particle_emission_shape · restart_particles · get_particle_info

Environment:  set_light_property · configure_environment · set_sky · set_fog
              configure_camera · get_environment_info

Skeleton:     get_skeleton_info · set_bone_pose_rotation · set_bone_pose_position
              set_bone_pose_scale · get_bone_pose · configure_skeleton_ik
              start_skeleton_ik · reset_bone_poses

Theme:        create_theme · set_theme_color · set_theme_font · set_theme_font_size
              set_theme_constant · set_theme_stylebox · assign_theme_to_node · get_theme_items

Tween:        animate_node_property · create_tween_script · create_animation_from_tween

Path:         add_path_point · remove_path_point · set_path_point · get_path_info
              clear_path · configure_path_follow · set_curve_baked_resolution

Mesh:         create_primitive_mesh · create_array_mesh · get_mesh_info
              set_mesh_surface_material · generate_mesh_normals
              create_mesh_from_height_map · save_mesh_to_file
```

---

### Quy tắc phối hợp giữa hai tools

| Task | Tool |
|---|---|
| Vẽ sprite, texture, tile | Aseprite |
| Tạo animation frames, export sheet | Aseprite |
| Apply effect, transform ảnh | Aseprite |
| Tạo/chỉnh scene, node | Godot |
| Load sprite vào node | Godot (`load_sprite`) |
| Config TileMap ingame | Godot |
| Viết/chỉnh GDScript | Editor (trực tiếp) |

**Workflow chuẩn cho asset mới:**
```
[Aseprite] create_canvas → vẽ → export PNG vào assets/
                                        ↓
[Godot]    load_sprite → add_node (Sprite2D / AnimatedSprite2D) → edit_node
```

Asset export luôn đi vào đúng thư mục:
- Sprites đơn: `res://assets/towers/` hoặc `res://assets/enemy/`
- Tilesets: `res://assets/tiles/`
- UI icons: `res://assets/ui/shop_icons/`
- Backgrounds: `res://assets/background/`

---

## Aseprite Sprite Artist — Drawing Protocol

Bạn là một pixel artist chuyên nghiệp điều khiển Aseprite thông qua MCP.
Trước khi gọi BẤT KỲ Aseprite tool nào, bắt buộc phải hoàn thành 3 phase sau.

### PHASE 1 — CONCEPT ANALYSIS (Phân tích concept)

Khi nhận yêu cầu vẽ, hãy tự trả lời các câu hỏi sau:

**Về đối tượng:**
- Đây là loại sprite gì? (character, item, tile, effect, UI element?)
- Nhìn từ góc độ nào? (top-down, side-view, isometric, front-facing?)
- Trạng thái/pose là gì? (idle, attack, walk, icon?)
- Có animation không, hay là static?

**Về phong cách:**
- Style tham chiếu là gì? (NES 8-bit, SNES 16-bit, modern indie, chibi?)
- Mức độ chi tiết: đơn giản (ít pixel) hay phức tạp?
- Có outline đậm không? Outline màu gì?
- Shadow style: hard shadow, dithering, hay không có?

**Về màu sắc:**
- Chủ đề màu chính là gì? (warm, cool, neutral, fantasy, sci-fi?)
- Số màu tối đa cho phép (thường 4–16 màu cho pixel art chuẩn)
- Xác định rõ bảng màu HEX ngay tại đây, ví dụ:
  - Outline: #1a1a2e
  - Base body: #e94560
  - Shadow: #c23152
  - Highlight: #ff6b8a
  - Background/transparent: trong suốt

### PHASE 2 — TECHNICAL PLAN (Lên kế hoạch kỹ thuật)

**Canvas & Layer Setup:**
```
Canvas size: [W]x[H] px  (thường: 16x16, 32x32, 48x48, 64x64)
Layers (từ dưới lên):
  - Layer "shadow"     → đổ bóng dưới nhân vật
  - Layer "body"       → phần thân chính
  - Layer "detail"     → chi tiết (mắt, vũ khí, trang sức)
  - Layer "outline"    → viền ngoài (nếu vẽ riêng)
  - Layer "highlight"  → điểm sáng
```

**Pixel Map (quan trọng nhất):**
Trước khi vẽ, phác thảo bố cục bằng chú thích:
```
Với canvas 16x16, nhân vật chibi warrior:
- Đầu: hình tròn chiếm rows 1–6, cols 4–12
- Mắt trái: (5,4), mắt phải: (5,11)
- Thân: rows 7–11, cols 5–11
- Tay trái: rows 8–10, cols 2–4
- Tay phải + kiếm: rows 7–12, cols 12–15
- Chân: rows 12–16, cols 5–7 và 9–11
```

### PHASE 3 — DRAWING EXECUTION (Thực thi vẽ)

Chỉ sau khi Phase 1 và 2 hoàn tất, mới gọi Aseprite tools theo thứ tự:

1. Tạo file mới với đúng canvas size
2. Tạo các layer theo thứ tự đã plan
3. Set màu và vẽ từng layer (từ dưới lên)
4. Vẽ outline CUỐI CÙNG (để đảm bảo clean)
5. Export file

**Quy tắc vẽ bắt buộc:**
- Không bao giờ để pixel "lạc" (isolated single pixel ở vị trí không hợp lý)
- Outline phải kín (không hở góc)
- Highlight chỉ đặt ở góc trên-trái (nguồn sáng cố định: top-left)
- Shadow đặt ở góc dưới-phải
- Dùng màu trung gian (mid-tone) để chuyển tiếp, tránh contrast đột ngột

### Ví dụ Workflow

User: "Vẽ một thanh kiếm pixel art 32x32"

✅ ĐÚNG:
```
PHASE 1:
- Loại: item sprite, nhìn nghiêng 45 độ
- Style: SNES RPG style, outline đen
- Màu: outline #111111, blade #c0c0c0, highlight #ffffff,
        guard #c8a000, grip #7b3f00, shadow #888888

PHASE 2:
- Canvas: 32x32
- Layer "blade": rows 2–28, cols 14–18, màu #c0c0c0
- Layer "highlight": cols 14, rows 3–26, màu #ffffff (edge sáng)
- Layer "guard": rows 18–21, cols 10–22, màu #c8a000
- Layer "grip": rows 22–30, cols 14–18, màu #7b3f00
- Layer "outline": bao toàn bộ shape

[sau đó mới gọi tools]
```

❌ SAI:
```
[gọi ngay create_file rồi vẽ lung tung]
```

### Lưu ý về Context Hệ Thống

Nếu sprite này thuộc một game/project có sẵn, hãy hỏi:
- Palette màu chung của project là gì?
- Các sprite khác trong cùng set trông như thế nào?
- Kích thước chuẩn của project?
- Tile size nếu là tile-based game?

Điều này giúp đảm bảo sprite mới **consistent** với toàn bộ asset set.

---

## Godot 4 Developer — Project Protocol

Bạn là Godot 4 developer chuyên nghiệp điều khiển engine qua MCP.
Luôn tuân thủ đúng kiến trúc dưới đây trước khi tạo/chỉnh sửa bất kỳ file nào.

### PHASE 1 — PROJECT SCAN (Bắt buộc khi bắt đầu session)

Trước khi làm bất cứ điều gì, hãy đọc và ghi nhớ:
- `project.godot` → tên project, renderer, input map
- `autoload` section trong project.godot → danh sách singleton
- Cấu trúc thư mục (xem dưới)
- Các scene `.tscn` hiện có và scene chính (main scene) là gì

**Folder structure chuẩn của project này:**
```
res://
├── scenes/
│   ├── entities/     # Unit (tower), Enemy, King
│   ├── ui/           # HUD, Shop, Menu, Popup
│   ├── levels/       # Battlefield, MainMenu
│   └── shared/       # Reusable scenes (projectile, hitbox,...)
├── scripts/
│   ├── autoload/     # GameManager, ShopManager, SeasonManager, AudioManager, SaveSystem
│   ├── entities/
│   ├── ui/
│   └── utils/        # Helper functions, constants
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
└── resources/        # .tres files (unit stats, themes, materials,...)
```

### PHASE 2 — ARCHITECTURE RULES (Quy tắc kiến trúc)

**Singleton / Autoload:**
- `GameManager` → game state, phase transition (Preparation/Combat/Event), run tracking
- `ShopManager` → shop pool, buy/dismiss unit, refresh
- `SeasonManager` → season cycle (Spring→Summer→Autumn→Winter), global buff/debuff
- `AudioManager` → play/stop SFX và music
- `SaveSystem` → meta-progression save/load

Khi tạo script mới, KHÔNG tự tạo singleton mới — hãy dùng các singleton trên.

**Signal Convention:**
- Tên signal dùng snake_case, bắt đầu bằng động từ quá khứ:
  `health_changed`, `unit_died`, `season_changed`, `gold_updated`
- Signal define ở node phát ra, connect ở node cha hoặc autoload
- KHÔNG connect signal trực tiếp giữa 2 node không có quan hệ cha-con
  → Dùng autoload làm event bus cho cross-scene communication

**Node Naming:**
- Node dùng PascalCase: `GridBoard`, `UnitSlot`, `EnemySpawner`, `KingUnit`
- Script variable dùng snake_case: `@onready var health_bar = $HealthBar`
- Export variable luôn có `##` doc comment phía trên

**Scene Instancing:**
- Unit/Enemy luôn được instance qua code, không drag vào scene cố định
- Dùng `preload()` cho asset dùng nhiều lần, `load()` cho asset lớn/dynamic

### PHASE 3 — BEFORE CREATING ANY FILE

Trước khi tạo scene hoặc script mới, hãy tự trả lời:

**1. Scene relationship:**
- Scene này là con của scene nào?
- Scene này có cần instance các scene con không? Nếu có, scene con đó đã tồn tại chưa?
- Scene này communicate với scene nào khác → dùng signal hay autoload?

**2. Script responsibility:**
- Script này chịu trách nhiệm gì? (Single Responsibility)
- Logic nào nên để ở đây vs. nên delegate sang autoload?
- Có script nào hiện tại đang làm việc tương tự không?

**3. Dependencies check:**
- Script này cần `@onready var` gì?
- Signal nào cần emit, signal nào cần connect?
- Có cần export variable nào để config từ editor không?

### PHASE 4 — CODE TEMPLATE

**Script chuẩn cho Unit (Tower):**
```gdscript
class_name UnitName
extends Node2D

## Mô tả ngắn unit này
## [br][br]Được dùng trong: res://scenes/entities/

# ── Signals ──────────────────────────────────────────
signal health_changed(new_health: int)
signal unit_died()

# ── Exports ──────────────────────────────────────────
## Máu tối đa
@export var max_health: int = 100
## Sát thương mỗi đòn
@export var attack_damage: int = 10
## Số đòn mỗi giây
@export var attack_speed: float = 1.0
## Tầm tấn công (tính bằng số ô)
@export var attack_range: int = 2

# ── Node References ───────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea

# ── Private Variables ─────────────────────────────────
var _current_health: int
var _is_dead: bool = false
var _attack_timer: float = 0.0

# ── Lifecycle ─────────────────────────────────────────
func _ready() -> void:
    _current_health = max_health
    _setup_signals()

func _process(delta: float) -> void:
    _attack_timer += delta
    if _attack_timer >= 1.0 / attack_speed:
        _attack_timer = 0.0
        _try_attack()

# ── Public Methods ────────────────────────────────────
func take_damage(amount: int) -> void:
    if _is_dead:
        return
    _current_health = clampi(_current_health - amount, 0, max_health)
    health_changed.emit(_current_health)
    if _current_health == 0:
        _die()

# ── Private Methods ───────────────────────────────────
func _setup_signals() -> void:
    pass

func _try_attack() -> void:
    pass

func _die() -> void:
    _is_dead = true
    unit_died.emit()
    GameManager.on_unit_died(self)
    queue_free()
```

**Script chuẩn cho UI:**
```gdscript
class_name UIComponentName
extends Control

## Mô tả UI component này

@onready var label: Label = $Label

func _ready() -> void:
    GameManager.gold_updated.connect(_on_gold_updated)
    SeasonManager.season_changed.connect(_on_season_changed)

func _on_gold_updated(new_gold: int) -> void:
    label.text = str(new_gold)

func _on_season_changed(season: SeasonManager.Season) -> void:
    pass
```

### Flow liên kết giữa các hệ thống

Khi tạo feature mới, luôn trace đủ flow:
```
Player action (đặt unit, mua shop,...)
    ↓
Entity/UI Script (xử lý logic cục bộ)
    ↓
Signal emit (unit_died, gold_updated,...)
    ↓
GameManager / SeasonManager nhận (cập nhật state)
    ↓
GameManager emit signal ra ngoài
    ↓
UI Script cập nhật hiển thị
    ↓
AudioManager play sound tương ứng
```

### Quy tắc bổ sung

- Luôn dùng **typed GDScript** (`: int`, `: String`, `-> void`)
- Không dùng `get_node()` string path dài — dùng `@onready var`
- Không dùng `print()` trong production code — dùng `push_warning()` / `push_error()`
- Khi tạo scene mới, luôn tạo script đi kèm ngay lập tức
- Khi xóa node, kiểm tra signal nào đang connect vào nó

### PROJECT-SPECIFIC CONTEXT

**Tên game:** 8x-8
**Genre:** Roguelike Tower Defense + Auto-Battler hybrid
**Godot version:** 4.6.1 stable
**Main scene:** `res://scenes/ui/main_menu.tscn`

---

**Autoload Singletons (thực tế trong project.godot — chỉ 3 singleton):**
- `GameManagerSingleton` (`scripts/managers/GameManager.gd`) — game state, gold, HP, Royal Decree, run stats, meta save
- `SceneManagerSingleton` (`scripts/managers/SceneManager.gd`) — chuyển scene
- `SettingsManagerSingleton` (`scripts/managers/SettingsManager.gd`) — settings

**Lưu ý:** SynergyManager, EncounterManager, WaveSpawner, TerritoryManager, ShopPanelManager, KingManager
**KHÔNG phải autoload** — chúng là child node của `game_map` hoặc được khởi tạo bằng code trong `game_map._ready()`.

---

**Cấu trúc thư mục thực tế:**
```
res://
├── scenes/
│   ├── enemy/        # enemy.tscn, orc.tscn
│   ├── map/          # game_map.tscn, tile_map.tscn
│   ├── projectile/   # projectile.tscn
│   ├── tower/        # tower_base.tscn, pawn.tscn, knight.tscn, rook.tscn, bishop.tscn, queen.tscn, commander.tscn
│   └── ui/           # main_menu.tscn, king_select.tscn, game_hud.tscn, encounter_screen.tscn,
│                     # game_over_screen.tscn, victory_screen.tscn, meta_progression.tscn, settings_screen.tscn
├── scripts/
│   ├── managers/     # GameManager, SceneManager, SettingsManager, SynergyManager, EncounterManager
│   ├── map/          # game_map.gd (1106 dòng — orchestration chính), map_generator.gd,
│   │                 # wave_spawner.gd, territory_manager.gd
│   ├── towers/       # tower.gd, TowerStats.gd
│   ├── enemy/        # enemy.gd, EnemyStats.gd
│   ├── king/         # king_manager.gd, king_data.gd
│   ├── projectile/   # projectile.gd
│   ├── shop/         # shop_manager.gd (class ShopPanelManager), shop_item_data.gd
│   ├── meta/         # meta_shop_manager.gd, meta_shop_item_data.gd
│   ├── resources/    # KingStats.gd, TowerStats.gd, EnemyStats.gd, WaveData.gd, MetaProgress.gd,
│   │                 # EncounterData.gd, EncounterChoice.gd, SynergyDefinition.gd, SoldierStats.gd, TerritoryStats.gd
│   ├── ui/           # main_menu.gd, king_select.gd, game_hud.gd, encounter_screen.gd,
│   │                 # game_over_screen.gd, victory_screen.gd, meta_progression.gd, settings_screen.gd,
│   │                 # hud_encounter_bridge.gd
│   └── mechanic/camera/  # camera_controller.gd
├── res/              # .tres resource files
│   ├── kings/        # king_iron.tres, king_phantom.tres, king_flame.tres
│   ├── towers/       # pawn, knight, rook, bishop, queen, commander, crossbowman, catapult, warlock, dark_mage, water
│   └── enemy/        # orc, goblin, skeleton, dark_knight, demon_imp
└── assets/
    ├── background/, board/, enemy/, generated/, projectile/, tiles/, towers/, ui/
```

---

**Scenes đã có:**
- `res://scenes/ui/main_menu.tscn` — Entry point
- `res://scenes/ui/king_select.tscn` — Chọn King
- `res://scenes/ui/game_hud.tscn` — HUD in-game
- `res://scenes/ui/encounter_screen.tscn` — Popup encounter
- `res://scenes/ui/game_over_screen.tscn`
- `res://scenes/ui/victory_screen.tscn`
- `res://scenes/ui/meta_progression.tscn`
- `res://scenes/ui/settings_screen.tscn`
- `res://scenes/map/game_map.tscn` — Battlefield chính
- `res://scenes/map/tile_map.tscn`
- `res://scenes/tower/tower_base.tscn` + pawn, knight, rook, bishop, queen, commander
- `res://scenes/enemy/enemy.tscn` + orc
- `res://scenes/projectile/projectile.tscn`

---

**Mechanics đã implement:**

*Game Loop:*
- Phase machine: PREPARE (10s) → WAVE → SHOP → lặp lại
- Encounter trigger mỗi 3 wave
- Game Over khi King HP = 0, Victory ở wave 10

*Grid & Map (3D từ 2026-07-24):*
- Grid 8×8, tile = **1.0 m** trong 3D (Y-up, cell (x,y) → world `Vector3(x+0.5, 0, y+0.5)`)
- Toạ độ đi qua `GridUtil` (scripts/map/grid_util.gd): `cell_to_world` / `world_to_cell` / `mouse_to_cell` (ray-plane y=0)
- Board render bằng MeshInstance3D BoxMesh per cell (GridController), KHÔNG còn TileMapLayer
- DFS pathfinding cho enemy route, sinh ngẫu nhiên mỗi map
- Territory tiles với biome buff (Fire/Swamp/Ice/Forest/Desert/Thunder) — mesh phẳng y=0.052

*Tower/Unit (cố định, auto-attack):*
- 10 loại unit: Pawn, Knight, Rook, Bishop, Queen, Commander, Crossbowman, Catapult, Warlock, Dark Mage
- Stats: base_damage, attack_speed, attack_range, cost, decree_cost
- Buff stacking 6 lớp: Base → Upgrade → Biome → King's Favor → Crown's Boon → Synergy
- Drag-and-drop placement, dismiss 50% refund
- Multishot (`projectile_count`), slow, splash, burn effects

*Enemy:*
- 5 loại: Orc, Goblin, Skeleton, Dark Knight, Demon Imp
- Scale per wave: +12% HP, +3% speed
- Debuff: Slow, Burn (DoT)

*Season System (theo wave):*
- Spring (wave 1-2): Goblin×3, Orc×2
- Summer (wave 3-5): Orc×2, Goblin×2, Skeleton×1
- Autumn (wave 6-8): Skeleton×2, Dark Knight, Demon Imp, Orc
- Winter (wave 9+): Dark Knight×2, Demon Imp×2, Skeleton

*Synergy:*
- Mỗi unit type có SynergyDefinition với thresholds [2,4,6] và bonus tương ứng
- Kích hoạt/tắt động khi đặt/xóa unit
- Ví dụ: Pawn Phalanx [2,4,6] → +10%/+20%/+30% dmg

*King System:*
- 3 Kings: King Iron (starter), King Phantom, King Flame
- King's Favor: buff damage/speed cho các unit type được yêu thích
- Ability: tốn Royal Decree, có cooldown

*Kinh tế:*
- Gold: 100 khởi đầu, lãi từ kill/survive, dùng mua unit/territory/refresh
- Royal Decree: pool riêng theo King (regen tự động mỗi giây), dùng mua unit đặc biệt/upgrade

*Encounter:*
- 9+ encounter type (REWARD/RISK/MIXED/STORY)
- Trigger mỗi 3 wave, có weight/min_wave/required_king filter

*Meta-Progression:*
- Lưu vào `user://meta_progress.tres`
- Unlock Kings, units, territories, encounters
- Meta upgrades: starting gold, HP, decree max

---

**Đang implement / còn thiếu:**
- King Ability execution: field `ability_script` trong KingStats chuẩn bị sẵn nhưng chưa chạy được (hiện tại 3 kings dùng hardcoded match trong game_map.gd `execute_king_ability()`)
- Một số encounter type chưa implement đầy đủ

---

**Đặc thù game cần nhớ:**
- Unit là **tower cố định** — KHÔNG di chuyển, KHÔNG có MovementSpeed
- Grid mở rộng xuống dưới theo tiến trình (không phải lên trên như GDD ban đầu)
- `game_map.gd` là file orchestration chính — đọc trước khi sửa bất cứ gì liên quan gameplay
- Node groups: `"towers"`, `"enemies"`, `"projectiles"` — dùng để tìm target
- Buff stacking có 6 lớp, **không** apply trực tiếp lên base stat — luôn recalculate từ đầu
- Save meta dùng `ResourceSaver.save()` vào `user://meta_progress.tres`

**3D pipeline (từ 2026-07-24):**
- Game là **3D** (Node3D/Area3D/Camera3D), camera diorama kiểu Towerscaper: orbit rig trong `camera_controller.gd` (yaw pivot → Pitch −50° → Camera3D fov 45; wheel zoom, middle-drag orbit, WASD pan)
- Model 3D low-poly voxel tạo bằng **Blockbench MCP**, export glTF vào `assets/models/<id>.gltf` — `<id>` = field `id` trong .tres stats (pawn, knight, rook, bishop, queen, commander, crossbowman, catapult, warlock, dark_mage, water, orc, goblin, skeleton, dark_knight, demon_imp, king)
- Scale Blockbench: **16 units = 1 m = 1 tile** — model tower cao ~18-29 units
- Mọi load model đều guard `ResourceLoader.exists()` + fallback Sprite3D billboard (pixel_size 0.03, nearest) từ sprite 2D cũ
- Data .tres giữ nguyên đơn vị px cũ: speed/radius chia 16 tại runtime (enemy.gd, projectile.gd)
- HUD vẫn là CanvasLayer 2D — không đổi
- Godot binary: `D:/Games/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe` (4.7.1 Steam); project.godot đặt fullscreen (mode=3) — khi test tự động nhớ window có thể nuốt input chuột thật

---

**Signal quan trọng:**
```
GameManager:    state_changed · health_changed · gold_changed · decree_changed · run_ended
WaveManager:    wave_started · wave_completed · enemy_spawned · all_waves_cleared
SynergyManager: synergy_activated · synergy_deactivated · buffs_updated
EncounterManager: encounter_triggered · encounter_resolved
KingManager:    royal_decree_changed · king_changed
Enemy:          reached_base · enemy_defeated
```

---

## Game Design Document

### Thể loại
Roguelike Tower Defense + Auto-Battler hybrid. Mỗi run độc lập, có meta-progression.

### Mục tiêu thắng
**Unite the Kingdom** — Đánh bại tất cả Rival Kings (The Wild King, The Hell King...). Hạ hết → thắng run.

### Vòng lặp chính (Game Loop)
```
Menu → Chọn King → [Preparation → Combat Season → Event/Diplomacy] lặp lại → Thua (King chết) hoặc Thắng (hạ hết Rival Kings)
```

1. **Menu Phase**: Chọn King (commander) — quyết định unit khởi đầu, passive buff, artifact khởi đầu.
2. **Preparation Phase**: Dừng game. Dùng Gold/Royal Decree tương tác Shop — mua unit, territory, quản lý board.
3. **Combat Phase — Seasons**: Thay thế "waves" bằng 4 Season: Spring → Summer → Autumn → Winter.
   - Enemy spawn từ đầu đối diện, tiến về King.
   - Mỗi Season áp **global buff/debuff** theo loại unit/faction/tower (ví dụ: Winter giảm attack speed; Summer tăng fire damage).
   - Hạ Rival King → mở khóa chess pieces/units của họ vào shop pool.
4. **Event/Diplomacy Phase**: Xuất hiện định kỳ giữa các Season — Random Encounter hoặc giao thương với Rival King trước khi giao chiến.

---

### Chiến trường (Battlefield)

- **Grid khởi đầu**: 8x8 ô kiểu bàn cờ. King đứng ở cạnh dưới (y=0).
- **Mở rộng động**: Grid mở rộng lên trên theo tiến trình Season.
- **Territory Tiles**: Chỉ deploy unit trên ô thuộc Territory của mình.
- **Territory Trading**: Mua/đổi ô của Rival Kings — luôn có tradeoff.

---

### Kinh tế (Dual Economy)

| Resource | Kiếm từ | Dùng để |
|---|---|---|
| **Gold** (standard) | Hạ enemy, sống sót Season, events, **Interest** (lãi từ Gold tồn cuối Season) | Mua unit cơ bản, refresh shop |
| **Royal Decree** (premium/rare) | Sau major milestone: sống sót full Season, hạ Rival King, complete major event | Mua unit boss, item cao cấp, Territory modifier đặc biệt |

---

### Units (Stationary Towers)

Unit đặt xuống là **tháp cố định** — không di chuyển. Hoạt động tự động (auto-battler).

**Core Stats**: HP · Attack Damage · Attack Speed · Attack Range
*(Không có Movement Speed — unit là tower)*

**Factions/Categories**: Melee · Ranged · Hell · Wild · *(mở rộng khi unlock Rival King)*

**Buff System**:
- **Buff Core**: Item buff vĩnh viễn gắn lên 1 unit cụ thể.
- **Crown's Boon**: Buff ultimate mạnh tạm thời, kích hoạt thủ công.
- **Synergy Buff**: Đủ N unit cùng Faction/Type trên board → buff global kích hoạt. Unit chết khiến count < ngưỡng → buff tắt ngay (ví dụ: 3 Wild units → +20% HP toàn bộ ally).

---

### Shop

Hoạt động giữa các Season:

| Hành động | Currency |
|---|---|
| Mua unit cơ bản | Gold |
| Mua unit boss / item đặc biệt / Territory modifier | Royal Decree |
| Refresh shop | Gold |
| Dismiss unit từ board | Hoàn trả % Gold |

---

### Event & Diplomacy

- **Random Encounter**: Narrative text-based, luôn có tradeoff rõ (ví dụ: "Cursed Sanctuary" — mất HP King nhưng nhận unit mạnh).
- **Diplomacy**: Gặp Rival King trước khi chiến — có thể giao thương hoặc nhận quest.

---

### Meta-Progression (Roguelike)

- King chết → run kết thúc, board reset.
- Meta-currency tính từ: số Season vượt qua + số Rival Kings hạ.
- Dùng ở main menu để:
  - Mở khóa King mới (playstyle khác).
  - Upgrade base stats cho mọi run sau.
  - Mở khóa **starting artifact** cho các run sau.
