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

**Autoload Singletons (thực tế trong project.godot — 4 singleton):**
- `GameManagerSingleton` (`scripts/managers/GameManager.gd`) — game state, gold, HP, Royal Decree, run stats, meta save, perk_* fields, crit_chance/crit_mult, combo (`register_kill()`, signal `combo_changed`)
- `SceneManagerSingleton` (`scripts/managers/SceneManager.gd`) — chuyển scene
- `SettingsManagerSingleton` (`scripts/managers/SettingsManager.gd`) — settings
- `AudioManagerSingleton` (`scripts/managers/AudioManager.gd`) — SFX pool + music; `play_sfx(name, db, pitch)`; wav synth thủ tục tại `assets/audio/sfx/` (18 sfx + music_loop)

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
│   ├── ui/hud/       # component tách khỏi game_hud: hud_boss, hud_codex,
│   │                 # hud_perk_draft, hud_potion_bag, hud_relic_bar,
│   │                 # hud_tower_panel, hud_wave_intel + hud_icons/hud_text (static)
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
- **Địa hình thật (từ 2026-07-24)**: tile dùng texture đất khô nứt (`assets/textures/terrain/*.png`, 32×32,
  NEAREST_WITH_MIPMAPS) — ô sáng/tối vẫn tương phản để đọc checkerboard; path = đường mòn có vệt bánh;
  ô Phước/Nguyền có rune khắc. Quanh grid là **skirt 4 ô** đất sẫm liền mạch (không kẻ ô) + cây cối,
  bọc ngoài bằng **vách đá** → đảo diorama. Props (`assets/models/props/`: tree_pine, tree_dead, bush,
  rock, grass_tuft, stump) scatter bằng MultiMesh, lệch ra rìa ô nên không chắn tower;
  `clear_props_at()` / `restore_props_at()` gọi từ tower_placed/dismissed.
- Trang trí deterministic theo `_map_seed` + `hash(cell)` → expand chỉ thêm hàng mới, vùng cũ không nhảy chỗ.
- **Bất biến**: mặt trên tile trong grid PHẢI y=0 (mouse picking ray-plane y=0, territory mesh y=0.052,
  overlay quad y=0.06). Chỉ skirt (ngoài gameplay) được jitter cao độ.

*Boss / Merge / QoL (từ 2026-07-24):*
- **Boss**: `scripts/enemy/boss.gd` (`BossEnemy extends Enemy` — KHÔNG sửa enemy.gd), `BossStats extends EnemyStats`,
  `res/enemy/boss_{wild,hell,frost}.tres`, `scenes/enemy/boss.tscn`. Wave 10 = wave boss (`WaveSpawner.BOSS_WAVES`).
  3 pha theo %máu, chặn 1 đòn > 25% max HP. Vô hiệu hoá tháp = set `can_shoot=false` + khởi động
  `cooldown_timer` CỦA CHÍNH THÁP (tự bật lại, không cần await → boss chết giữa chừng không kẹt tháp).
- **Thắng/thua wave boss**: `wave_cleared` bị chặn tới khi boss chết (`is_boss_pending()`);
  boss chạm King → signal `boss_escaped` → `game_map._on_boss_escaped()` → **thua ngay**.
- **Merge ★**: `tower.star` (1..3), nhân `STAR_DAMAGE_MULT [1.0, 1.8, 3.2]` + `STAR_RANGE_BONUS`.
  Sao là phép NHÂN, KHÔNG dùng BuffLayer (buff layer là cộng) → không nhân chồng khi recalculate.
  Merge = đặt tháp lên ô cùng loại; gate nằm ở `game_map._unhandled_input` (nhánh `mergeable`),
  KHÔNG được thêm luồng input thứ hai trong tower_placer.
  Merge KHÔNG gọi `synergy_manager.on_tower_placed` (số tháp không đổi) — gọi sẽ đếm trùng.
- **Ascension**: `GameManager.ascension_level` (0..5) + `asc_*_mult()`; `wave_spawner.get_health_multiplier/
  get_speed_multiplier` nhân vào (guard `has_method`). Lưu ở `MetaProgress.ascension_unlocked`.
- **Tốc độ game**: `GameManager.set_game_speed/toggle_pause`. `Engine.time_scale` KHÔNG BAO GIỜ = 0 —
  pause dùng `get_tree().paused`; node UI cần bấm khi pause phải đặt `PROCESS_MODE_ALWAYS`.
- **Thống kê**: `GameManager.record_tower_damage(id, amount)` (gọi từ `tower._fire_projectile`) + `top_towers(n)`.

*Hệ BIOME đa môi trường (từ 2026-07-24):*
- 5 biome: `wasteland` (Hoang Mạc) · `tundra` (Băng Nguyên) · `volcanic` (Hoả Diệm) · `swamp` (Đầm Lầy) · `verdant` (Rừng Thẳm)
- `scripts/map/biome_library.gd` (`BiomeLibrary`, toàn static) = nguồn sự thật: texture prefix, màu fallback,
  danh sách prop + trọng số, ánh sáng/ambient/sương/nền, và `mod` (enemy_speed_mult, enemy_hp_mult,
  tower_dmg_pct, tower_spd_delta, gold_per_kill, burn_mult)
- **Biome gán theo VÙNG, không phải theo run**: `grid_controller.cell_biome` (Vector2i → id).
  Chunk đầu 1 biome; mỗi lần mở rộng vùng mới nhận biome khác → bản đồ chắp vá. `cell_biome` PHẢI được
  rebase cùng các dict khác. Signal `biome_region_added(id, region)`; API `get_cell_biome()`, `get_current_biome()`
- Texture: `assets/textures/terrain/<prefix>_{light,dark,road,cliff_side,cliff_top}.png` (25 file).
  Prop: `assets/models/props/*.gltf` (15 model, mỗi biome dùng tập riêng)
- `scripts/map/biome_effects.gd` (`BiomeEffects`, child của game_map) áp mod gameplay qua
  **`BuffLayer.BIOME_CLIMATE`** (KHÁC `BuffLayer.BIOME` của territory) + các field `biome_*` trong GameManager.
  Mod luôn THAY THẾ, không cộng dồn. game_map nạp file này động (guard `ResourceLoader.exists`)
- Environment được `duplicate()` trong `_ready` trước khi tween — nếu không sẽ ghi đè SubResource trong .tscn
- Sương: giữ `fog_density` ≤ ~0.013; cao hơn (0.02+) làm mất hình bàn cờ ở cỡ camera diorama

*Mở rộng map 4 hướng (từ 2026-07-24):*
- Mở rộng mỗi **3 wave** (`game_map.EXPAND_EVERY_N_WAVES`) → trước wave 4, 7, 10. Cap `MAX_AXIS = 24` mỗi trục.
- 4 hướng `ExpandDir {NORTH, SOUTH, WEST, EAST}`. Mở về WEST/NORTH dùng **rebase**: dịch toàn bộ dữ liệu
  +8 trên trục đó để ô luôn ≥ 0 ⇒ mọi code duyệt `0..grid_width/height` (tower_placer, overlay,
  territory) KHÔNG cần sửa. Signal `map_rebased(delta)` phát trước `map_expanded`; listener phải dịch
  state keyed theo cell (territory_manager.rebase, king_manager.rebase_territories).
- Chọn hướng: điểm = khoảng cách ô King tới biên + `REPEAT_DIR_PENALTY` nếu trùng hướng lần trước.
  Lý do: đích DFS là biên NGOÀI vùng mới nên King luôn nằm trên biên đó — không phạt thì lặp mãi 1 hướng.
- Đường quái: spawn giữ nguyên ở `path[0]`, đoạn mới nối vào CUỐI path, King dời vào sâu vùng mới.
  Đoạn mới không cắt (`blocked_positions`) và không dán sát (`adjacent_blocked`) đường cũ.
- `map_generator.generate_extension_to_region()`: DFS tới TẬP ô đích, giữ đoạn NGẮN NHẤT, có ngân sách
  thời gian (`SHORTEN_BUDGET_MS` / `SEARCH_BUDGET_MS`) để không treo frame trên board 24×24.
- Cả 4 hướng fail → `push_warning`, KHÔNG đổi state (map giữ nguyên, game tiếp tục).
- **Ô lãnh thổ được bảo vệ như ô có tháp**: `grid_controller.protected_cells_provider` (game_map set
  trỏ tới `territory_manager.owned_tiles`) → DFS tránh ra. Lưới an toàn: signal
  `territory_overwritten_on_expand` (phát SAU `map_rebased` để cùng hệ toạ độ) →
  `TerritoryManager.remove_territories_at()` dọn mesh + hoàn kho.
- **`MAX_DFS_STEPS` là bắt buộc**: `_dfs_step` là DFS self-avoiding có backtracking, số đường đơn
  bùng nổ tổ hợp. Không có trần bước thì một lượt xấu treo hẳn game (ngân sách thời gian chỉ
  kiểm được GIỮA các lượt, không cắt được lượt đang chạy).
- Trang trí deterministic qua `cell - _rebase_total` nên cây/cỏ vùng cũ không nhảy sau rebase.

*UI (đợt 5):*
- `UIStyle` (scripts/ui/ui_style.gd, toàn static) là nơi DUY NHẤT tạo StyleBox + animation.
  Texture 9-patch ở `assets/ui/panels/` (guard `ResourceLoader.exists`, thiếu thì fallback StyleBoxFlat).
- `ModelIcon` (scripts/ui/model_icon.gd): SubViewport `own_world_3d = true` render model 3D xoay làm icon.
  Cap `MAX_LIVE_3D = 8`; vượt hạn mức hoặc thiếu .gltf → fallback sprite 2D.
- **Cạm bẫy đã gặp**: (1) `get_meta(key, null)` vẫn báo lỗi khi thiếu key → dùng `has_meta` trước;
  (2) KHÔNG tween `position` trên con của Container (Container quản vị trí, lúc `_ready` chưa sort nên
  đọc ra (0,0) → node bị ghim sai chỗ) — chỉ fade/scale.
- DFS pathfinding cho enemy route, sinh ngẫu nhiên mỗi map
- Territory tiles với biome buff (Fire/Swamp/Ice/Forest/Desert/Thunder) — mesh phẳng y=0.052

*Perk System (roguelike draft, từ 2026-07-24):*
- Sau mỗi wave: draft 3-chọn-1 perk (scripts/perks/perk_system.gd, PerkSystem là child của game_map)
- 12 perks built-in + custom qua **JSON** (`data/perks/*.json` — schema trong docs/CONTENT_AUTHORING.md), 4 rarity (60/25/12/3), stack qua BuffLayer.PERK + GameManager perk_* fields
- UI card trong game_hud.gd `show_perk_draft`; pick programmatic được: `perk_system.pick(id)`
- Kênh hiệu ứng: `tower` · `economy` · `instant` · `rd` · **`element`** (perk lối chơi nguyên tố,
  `data/perks/element_perks.json`). Subkey của `element` có thể là số, bool, hoặc dict
  (`element_damage`) — validator chấp cả ba, xem `_is_valid_effect_value`

*HỆ NGUYÊN TỐ (từ 2026-07-26 — xem futureplan.md §1-§3):*
- **Nguyên tố đến từ Ô, KHÔNG từ loại tháp.** `tower.current_element()` đọc
  `grid_controller.get_element_at(cell)`. Đây là bất biến thiết kế: KHÔNG tạo "tháp hoả/tháp thuỷ".
- `scripts/elements/element_types.gd` (`ElementTypes`, toàn static) = nguồn sự thật 6 nguyên tố
  (fire/ice/thunder/water/poison/earth). Icon là CHỮ CÁI (H/B/L/N/Đ/T) — font mặc định của Godot
  không có glyph emoji, dùng emoji sẽ ra ô tofu.
- `element_marks.gd` (`ElementMarks`) là child node của MỖI địch: giữ tối đa `max_marks` Dấu
  (2, di vật "Bánh Xe Nguyên Tố" nâng 3), DoT + slow, nhãn Label3D. Dấu thứ N+1 đẩy Dấu CŨ NHẤT ra.
- `reaction_table.gd` (`ReactionTable`, toàn static) = **10 phản ứng**. Cặp Dấu khớp → nổ và
  TIÊU THỤ CẢ HAI. `WILDCARD "*"` cho Kết Tinh (Thổ + bất kỳ) và nó PHẢI đứng CUỐI bảng —
  thứ tự trong `TABLE` chính là độ ưu tiên tra cứu.
- **Đồng hồ hệ nguyên tố nằm ở ReactionTable**, không phải ElementMarks (cắt cyclic reference).
  KHÔNG dùng `Time.get_ticks_msec()`: đồng hồ hệ thống không co theo `Engine.time_scale` và vẫn
  chạy khi pause → Dấu hết hạn / Đóng Băng tan ngay trong lúc dừng game.
- Trạng thái static (`_cracks`, `reaction_count`, ngân sách frame) sống xuyên scene →
  `game_map._ready()` gọi `ReactionTable.reset()`, `_on_map_rebased` gọi `clear_cracks()`.
- **Ô nguyên tố = territory tái dụng**: `TerritoryManager.BIOME_STATS[key].element`. 3 cấp
  (`tile_level`, ghép bằng cách đặt ô cùng loại lên chính nó). `LEVEL_BONUS` cho
  mark_duration_bonus / reaction_mult / tower_damage_pct. `tile_level` PHẢI rebase cùng các dict khác.
- 4 hình thế (`formation_detector.gd`): Hàng Long · Tứ Trụ · Song Cực · Trận Vòng.
  `territory_manager.get_element_bonus()` gộp CẤP + HÌNH THẾ thành một dict duy nhất.
- Ba nguồn khuếch đại phản ứng NHÂN với nhau trong `tower._refresh_element_mults()`:
  trang bị × cấp ô/hình thế × `GameManager.global_reaction_mult` (di vật). ReactionTable kẹp
  `DAMAGE_MULT_CAP = 4.0` nên không sợ nhân vô hạn.
- `territory_manager.get_element_bonus()` là ĐIỂM RA DUY NHẤT của thưởng ô: gộp cấp ô +
  hình thế, và **chép nguyên mọi khoá còn lại** (`auto_reaction_interval`, `pole_partner`,
  `ring_element`). Thêm khoá mới mà quên chép ở đây thì hình thế "phát hiện được nhưng
  không làm gì" — đúng lỗi đã gặp với Song Cực.

*Synergy nguyên tố — trục đếm THỨ HAI (từ 2026-07-26):*
- `scripts/elements/element_synergy.gd` (`ElementSynergy`, child của game_map). **KHÔNG nhét
  vào SynergyManager**: trục đó gắn với `tower_placed`/`tower_removed`, còn nguyên tố đổi khi
  mua/nâng/bán ô — không có tháp nào được đặt hay gỡ. Đây là hệ riêng, `recount()` quét lại
  toàn bộ mỗi lần bố cục đổi.
- Ngưỡng 2/4/6 (giống trục loại quân). Buff chỉ số qua `BuffLayer.ELEM_SYNERGY`.
  Mốc ×6 đổi LUẬT, ghi vào `GameManager.syn_*`: Biển Lửa (Dấu Hoả lan 1.5m mỗi nhịp DoT) ·
  Băng Vĩnh Cửu (bỏ cooldown ẩn Đóng Băng — ngoại lệ DUY NHẤT của luật đó) · Bão Sét
  (Dẫn Điện 8 mục tiêu) · Đại Dịch (Độc 10 tầng) · Thuỷ Triều (địch spawn mang sẵn Dấu Thuỷ) ·
  Địa Chấn (Kết Tinh 40 vàng).
- `game_map._recount_element_synergy()` **await một frame** trước khi đếm: `tower_placed` phát
  TRƯỚC khi tháp đọc xong nguyên tố ô dưới chân.
- **Bát Quái** = đủ 6 nguyên tố trên BÀN (đếm ô, không đếm tháp) → `bagua_active` mở phản ứng
  **Nguyên Sơ**: 20% mỗi lần nổ thăng cấp thành vụ nổ 400% trong 3m. Thăng cấp rồi thì BỎ HẲN
  phản ứng gốc (`_try_primal` trả true) — chạy cả hai là ăn hai lần sát thương.

*Lưới an toàn "không lối nào sai" (futureplan §6):*
- **Pity shop**: từ wave 3, `shop_manager._make_pity_tile_offer()` luôn chèn 1 ô khớp nguyên tố
  đang mạnh nhất (`game_map._dominant_element`). Chèn ĐẦU TIÊN vào quầy, các loại khác lấp phần còn lại.
- **Draft perk định hướng**: `perk_system._pick_guided()` rút trước 1 lá khớp build, rồi
  `draft.shuffle()` để lá đó không luôn nằm ở vị trí đầu.
- **Boss chọn 1-trong-3** (`game_map._offer_boss_reward`, dùng lại UI `show_perk_draft`):
  khớp build (2 ô nguyên tố) · đổi hướng (di vật) · vàng. Id lá mã hoá luôn tham số nên
  không cần giữ state giữa lúc mở UI và lúc bấm.
- **Bán ô** `territory_manager.sell_tile_at()` hoàn 60% theo CẤP ô; **ô miễn phí** khi mở vùng
  biome mới qua `grid_controller.free_tiles_granted` → `game_map._on_free_tiles_granted`.
- **Encounter tặng ô**: `EncounterChoice.element_tiles` + `element_tile_kind`
  (`"dominant"` / `"random"` / id nguyên tố). Tặng vào KHO, không đặt sẵn lên bàn — vị trí đặt
  là quyết định của người chơi. Xem 2 encounter mẫu `exposed_ley_line`, `silent_stonecutter`.
- **Kết Tinh rơi mảnh**: 5% mỗi lần nổ tặng thẳng 1 ô Lv1 (`ReactionTable._try_crystal_shard`).

*Khắc/kháng nguyên tố (từ 2026-07-27):*
- `EnemyStats.DEFAULT_AFFINITY` = bảng `id → [khắc, kháng, (khắc phụ)]`. Khắc ×1.5, kháng ×0.6.
  Field `weak_element` / `weak_element_2` / `resist_element` trong .tres GHI ĐÈ bảng mặc định →
  file .tres cũ không phải sửa gì.
- Phân bố được cân để **mọi nguyên tố khắc chế ≥2 loài** (futureplan §6.1). 10 loài / 6 hệ không
  chia đều nổi nếu mỗi loài chỉ có một điểm yếu → ba loài "cứng" (dark_knight, troll, golem) có hai.
- Áp ở HAI chỗ: `ElementMarks._apply_dot` (nhân vào DoT của Dấu đó) và
  `ReactionTable._hit_reaction` (lấy hệ số TỐT NHẤT trong cặp Dấu — chỉ cần một vế khắc là đủ,
  lấy trung bình thì mọi phản ứng lai đều nhạt và bảng ái lực thành vô nghĩa).
- Trần `DAMAGE_MULT_CAP` áp TRƯỚC ái lực → sát thương phản ứng tối đa thực tế = 4.0 × 1.5 = 6×.
  Đây là chủ ý: thưởng cho việc chọn đúng hệ theo wave.
- Hiện ở cột "Khắc / Kháng" trong popup trinh sát + mục cuối codex.

*Hình ảnh hệ nguyên tố (từ 2026-07-27):*
- `scripts/elements/formation_overlay.gd` (`FormationOverlay`, child của game_map) tô sáng các ô
  của mỗi hình thế + nhãn tên nổi phía trên. Rebuild CHỈ khi `formations_changed` (và khi rebase —
  overlay vẽ theo toạ độ thế giới). **Cao độ**: quad y=0.12 (trên mặt ô Lv3 = 0.102),
  nhãn y=1.7 (cao hơn model tháp, thấp hơn thì nhãn lọt trong thân tháp).
- `tower._refresh_element_ring()` vẽ vòng torus màu nguyên tố dưới chân tháp. `top_level = true`
  để không thừa hưởng xoay/scale của `$Visual` (model xoay theo mục tiêu mỗi frame).
  `no_depth_test` vì ô Lv3 dày 0.10 sẽ cắt mất một phần vòng.
  Đây là thứ khiến "nguyên tố đến từ Ô" đọc được bằng mắt thay vì phải nhớ.

*Cân bằng chỉ số (2026-07-27) — ĐỌC TRƯỚC KHI SỬA SỐ:*
- **Tầm bắn tính bằng Ô, bàn khởi đầu chỉ 8×8 (chéo ~11 ô).** Bảng cũ có Queen 14 ·
  Bishop/Rook 10 · Catapult/Dark Mage 9 → mọi tháp phủ trọn bàn, đặt ở đâu cũng như nhau.
  Dải mới: cận chiến 2 · ngắn 3 · trung 4 · dài 5-6 · bắn tỉa 7. **Đừng vượt 7.**
- **Trần cộng dồn**: `Tower.MAX_EFFECTIVE_RANGE = 9` (ô Băng +1, perk +1, Hàng Long +1,
  ★3 +1, Chân Đế Xoay +1 cộng lại tới +5 nếu không chặn) và
  `Tower.MIN_COOLDOWN_RATIO = 0.4` — sàn hồi chiêu theo TỈ LỆ base, không phải hằng 0.1s
  (sàn cứng cho phép tháp base 1.0s đạt 10 phát/giây = ×10 DPS).
- **Buff Ô là PHẦN TRĂM** (`damage_pct` / `speed_pct` trong `BIOME_STATS`), không cộng phẳng.
  Cộng phẳng thưởng ngược cho quân rẻ: +6 dmg trên Pawn (base 12) = +50%, trên Ballista
  (base 85) = +7%. `tower.apply_biome_buff` quy ra tuyệt đối theo base của chính tháp đó.
  Mô tả ô trong shop và HUD ĐỌC THẲNG `BIOME_STATS.desc` — đừng chép tay lại, bản chép cũ
  đã lệch hẳn sau khi đổi sang phần trăm.
- **Giá vs sức mạnh**: DPS/100 vàng trước đây chênh 18.8× (Knight 120 vs Alchemist 6.4) —
  tier đắt hoàn toàn vô dụng. Nay chênh 4.3×. Quân rẻ vẫn hiệu quả hơn theo VÀNG nhưng yếu
  theo Ô — ô bàn cờ mới là tài nguyên khan hiếm về cuối.
- **Máu địch tăng CẤP SỐ NHÂN** `ENEMY_HEALTH_GROWTH = 1.15^(w-1)`, không cộng tuyến tính.
  Sức mạnh người chơi vốn nhân dồn (★ ×3.2 × synergy × perk × cấp ô); +12%/wave tuyến tính
  bị bỏ xa — đo thực tế: máu Vua ĐỨNG YÊN từ wave 6, hết áp lực.
- **Xáo shop là chỗ tiêu vàng dư**: 10 vàng, +6 mỗi lần trong cùng phiên, trần 40, reset ở
  phiên sau (`shop_manager.reset_reroll_cost` gọi từ `_on_shop_phase_entered`).
  Giá cũ 2 vàng khiến người chơi tồn >1200 vàng ở wave 9 mà không có gì để mua.
- **Cách đo**: chạy hai bot — một chỉ mua tháp, một dùng cả ô nguyên tố + trang bị + ghép ★.
  Mốc lành mạnh hiện tại: bot thường 45→8 HP (thoi thóp wave 9), bot giỏi 45→54 HP.
  Chênh lệch đó CHÍNH LÀ giá trị của các hệ thống; nếu hai bot ra kết quả giống nhau thì
  hệ thống đang chỉ là trang trí.

*Quầy shop & bậc perk (2026-07-27):*
- **Quầy PHẢI bảo đảm ≥1 quân mỗi lượt roll** (`shop_manager._pick_guaranteed_troop`, chèn
  TRƯỚC pity/trang bị/di vật). Đã dính lỗi thật: `SHOP_SLOT_COUNT` cố định 4, mà từ wave 3 có
  pity ô + trang bị (+ di vật từ wave 5) chiếm chỗ, còn `unit_candidates` lại TRỘN chung TROOP
  với TERRITORY/DISMISS ⇒ có lượt quầy ra 0 quân, người chơi **không đặt được tháp cả wave**
  (không mua được thì không có stock). Slot nâng lên **5**. Thêm loại hàng mới vào quầy thì
  phải kiểm lại điều này.
- **Bậc perk mở dần theo wave**: `RARITY_UNLOCK_WAVE` = thường 1 · hiếm 3 · sử thi 5 ·
  huyền thoại 8 — chưa tới wave thì KHÔNG xuất hiện (chặn cứng, không phải "xác suất thấp").
  `RARITY_CURVE` cho trọng số tuyến tính sau khi mở khoá: thường tụt 60→sàn 20, ba bậc trên
  leo tới trần 40/28/12. `game_map._maybe_offer_perk_draft` gọi `perk_system.set_wave()`
  TRƯỚC `roll_draft()` — quên dòng đó thì mọi wave đều tính như wave 1.
  Lọc xong mà không đủ `DRAFT_SIZE` lá (hết perk thường) thì nới về pool đầy đủ, thà lệch
  tiến trình còn hơn draft rỗng. Đo 1000 draft/wave: wave 1-2 thuần thường, wave 14 ≈
  17% thường / 53% hiếm / 29% sử thi / 1.5% huyền thoại.

*Icon vật phẩm (2026-07-27) — vẽ bằng Aseprite MCP:*
- **52 icon 32×32**, tên file trùng ĐÚNG `id`: 20 thuốc `assets/ui/potions/<id>.png` ·
  12 di vật `assets/ui/relics/<id>.png` · 20 trang bị `assets/ui/equipment/<id>.png`.
- Regression có assert **mọi id trong `POTIONS`/`RELICS`/`ITEMS` đều phải có icon** — thêm
  vật phẩm mà quên vẽ thì test đỏ ngay, không trôi vào build.
- HUD nạp qua `_load_icon()` (có cache, guard `ResourceLoader.exists`). Thiếu file → ô tự
  rơi về nhãn chữ viết tắt như cũ, KHÔNG vỡ UI. Thêm vật phẩm mới mà chưa vẽ icon vẫn chạy.
- **Aseprite MCP** (`D:\Games\Asepriteseprite-mcp`, binary `aseprite/build/bin/aseprite.exe`):
  `run_lua_script` là đường hiệu quả nhất — dựng một thư viện primitive (rect/disc/taper) +
  pass `outline()` tự động rồi vẽ hàng loạt, thay vì đặt từng pixel.
  **BẪY**: server KHÔNG nhận ký tự ngoài ASCII trong script Lua (`charmap codec` lỗi) —
  chú thích trong Lua phải viết không dấu.
- Quy ước hình — nhóm nhận ra được TRƯỚC khi đọc chữ:
  thuốc = bình tròn (buff tháp) · lọ cao (gắn Dấu) · dáng riêng (ném/khẩn cấp);
  trang bị = vũ khí vẽ CHÉO 45° · phụ kiện vật thể tròn/nhỏ · nền tảng có bệ đá dưới chân.
  Outline `#14100c` kín, nguồn sáng cố định trên-trái.
- Ở 32px, chi tiết mảnh KHÔNG đọc được: dây đeo mảnh thành đốm rối, cúp chim mảnh thành cái
  chày, lưỡi lao vẽ bằng disc thành cục. Vẽ lưỡi bằng hàm `blade()` (thoi dọc trục) và bỏ
  hẳn dây đeo — đã phải vẽ lại 4 icon vì lỗi này.

*Ve lai art cu (2026-07-27):*
- **O nguyen to** `assets/tiles/territory_<key>.png` nang 16 -> **32x32**. Ban cu la nhieu ngau
  nhien, va Thuy (`swamp`) voi Doc (`forest`) gan nhu cung mot mau xanh - khong phan biet duoc
  tren ban. Nay moi o co nen da + **rune rieng**: lua / giot nuoc / bong tuyet / dau lau /
  ngon nui / tia set. Mau bam dung `ElementTypes` (Loi la TIM, khong phai vang nhu ban cu).
- **Crest shop** `assets/ui/shop_icons/icon_<key>.png` nang 16 -> **32x32**, dung CHINH rune do
  nen nguoi choi noi duoc "icon trong shop = o tren ban". Ban cu con sai nghia (swamp ve bui co
  nhung gio la Thuy, desert ve mat troi nhung gio la Tho).
- **10 icon encounter** + `encounter_curse.png` (80x80) ve lai toan bo.
- Tile texture di vao `StandardMaterial3D.albedo_texture` voi `TEXTURE_FILTER_NEAREST` (xac minh
  bang runtime, khong doan). O trong nhot trong anh chup la do anh sang biome, KHONG phai texture sai.
- **Bay hinh hoc da dinh 4 lan**: ham `taper()` thu hep XUONG DUOI. Mai den, leu, xo deu can
  LOE ra => phai dung `trapV(topL,topR,botL,botR)` hai canh doc lap. Va halo 3x3 ve duoi moi
  pixel than se LAP khe ho ben trong glyph (ngon lua hai chop thanh khuon mat) - halo phai tinh
  theo vien mat na nhu `outline()`.
- **Rune o 32px phai CAO hon RONG.** Hinh be ngang + hai chop thi mat doc thanh khuon mat -
  da ve lai rune Hoa 4 lan vi loi nay.

*Sua bo cuc UI dot 2 (2026-07-27):*
- **Panel khong nam trong container thi KHONG tu co** — da dinh 3 lan (bang tai nguyen, panel
  shop, panel thap). Moi panel dung `offset` tuyet doi deu phai tinh lai chieu cao sau khi
  dung xong noi dung. Panel shop + panel thap nay goi `_resize_*_panel.call_deferred()`.
- **Do MINIMUM SIZE cua VBox BEN TRONG, khong do panel** khi panel boc mot `ScrollContainer`:
  ScrollContainer luon bao min rat nho (no cuon duoc) nen panel tuong noi dung ngan va cat mat
  dong cuoi. Dung lo nay o panel thap.
- **Banner biome treo SAT DINH man** (`BIOME_BANNER_TOP = -472`), khong o giua: o giua no de
  len header shop va de len tieu de draft perk.
- **Draft perk dim 0.86** (truoc 0.62): ban co 3D sang, dim nhat thi the bai khong noi len.
- `btn_king_ability` tung cat chuoi bang `.left(10)` khien "Iron Decree" thanh "Iron Decre" —
  KHONG phai loi layout. Da bo cat.
- **Overlay hinh the ve BON THANH VIEN, khong to kin o**: to kin cong mau (BLEND_MODE_ADD) len
  ca o se bay mau nguyen to va nuot mat rune duoi day.
- **Nhan hinh the cung ten trong ban kinh `SAME_NAME_MERGE = 3.2` chi giu MOT** — hai cap Song
  Cuc rieng biet dung gan nhau in ca hai thanh "Song Cuc Song Cuc" dinh lien.

*Chrome HUD (2026-07-27) — bố cục màn chơi:*
- **Thanh tài nguyên** `_build_resource_row()`: HP (kèm thanh) · Vàng · Sắc Lệnh (kèm thanh)
  xếp NGANG trong `StatsHolder` (rộng `RESOURCE_PANEL_WIDTH`). Ba cột có `custom_minimum_size`
  TƯỜNG MINH — để cả ba cùng `EXPAND_FILL` thì thanh máu nuốt hết chỗ, hai cột kia bị đẩy ra
  ngoài panel.
- **Dải chip** `_refresh_status_chips()`: `favor_summary` và `territory_summary` do game_map
  ghép bằng `" | "` được TÁCH thành từng chip có nền + màu riêng. Trước đây in nguyên si
  thành một dòng dài đọc như log debug. Tách ở HUD nên không phải đổi chữ ký `update_labels`.
- **BẪY đã dính**: chip cũ xoá bằng `queue_free()` vẫn nằm trong cây tới cuối frame, mà
  `update_ui()` được gọi NHIỀU LẦN mỗi frame ⇒ minimum size của panel phình dần và không bao
  giờ co lại (`StatsHolder` là con trực tiếp của `Control`, không container nào ép nó nhỏ).
  Phải `remove_child()` TRƯỚC `queue_free()`.
- **Chồng lấn theo toạ độ tuyệt đối**: dải thông tin wave (`_intel_panel`) neo ngang đỉnh màn,
  mép trái phải nằm sau `StatsHolder`, nếu không nó che mất số Vàng/Sắc Lệnh. Cột phải xếp
  dọc: King (12..292) → thanh di vật (306..362) → nhắc F1 (368..388). Đổi chiều cao một cái
  thì phải dời cái dưới.
- `RightPanel` trong .tscn neo `anchor_bottom = 1` (cao hết màn) trong khi nội dung vài dòng →
  một dải gỗ rỗng chạy suốt màn hình; `_fix_right_panel()` đổi sang bám mép trên, cao theo
  nội dung, rộng 210 (160 làm "Iron Decree" bị cắt thành "Iron Decre").

*Dọn dẹp cấu trúc (2026-07-27):*
- **`game_hud.gd` 4329 → 2562 dòng**, bảy khối tách thành component ở
  `scripts/ui/hud/`. Mỗi component `extends Node`, gắn bằng `X.attach(hud)` làm
  con của HUD, giữ `var hud: CanvasLayer` để với tới node gốc "Control".
  HUD giữ nguyên MỌI tên hàm công khai (`show_boss_bar`, `show_tower_info`,
  `show_perk_draft`…) dưới dạng một dòng uỷ quyền → **game_map không đổi dòng nào**.
- **Cấm tham chiếu ngược**: component KHÔNG được `GameHUD.C_GOLD` — hai
  `class_name` trỏ vòng nhau thì Godot không phân giải được kiểu. Vì vậy bảng màu
  HUD dời sang `UIStyle.HUD_*`, còn `C_*` trong game_hud giờ chỉ là bí danh.
  Helper dùng chung: `HudIcons` (nạp icon theo id, có cache) · `HudText`
  (`short_label`, `style_button_text`).
- Bẫy khi cắt file bằng script: một hàm nằm LỌT trong khối bị cắt mà phần còn
  lại vẫn gọi (`_style_button_text`, `_perk_counter_label`) → phải trả về hoặc
  chuyển sang helper chung. `--import` bắt hết, nhưng lỗi hiện ở FILE GỌI chứ
  không phải file lỗi; dùng `load("res://<file>.gd")` trong một script nhỏ để lấy
  đúng dòng.
- **`test.tscn` đã xoá** — nó là scene rác thời 2D (Camera2D gắn script camera 3D,
  HUD là ANH EM của GameMap chứ không phải con, nên `game_map._ready` không thấy
  và tạo HUD thứ hai). Nút "Continue" ở main menu từng trỏ vào đó; nay trỏ
  `scenes/map/game_map.tscn` cùng chỗ với "New Game".
- `BossStats` bỏ `display_name` (đã kế thừa từ `EnemyStats`) — Godot cấm lớp con
  khai trùng tên field với lớp cha.

*Thêm nội dung — `python tools/check_content.py` (2026-07-27):*
- **Thêm địch giờ chỉ cần MỘT file `.tres`**: `spawn_seasons` (0=Xuân 1=Hạ 2=Thu
  3=Đông) + `spawn_weight` + `display_name` + `ability_note` nằm ngay trong
  `EnemyStats`. `wave_spawner._append_data_driven_enemies()` đọc thẳng.
  Mười loài cũ để `spawn_seasons` RỖNG nên bảng mùa cứng vẫn là nguồn duy nhất
  của chúng — tần suất cân bằng cũ không đổi.
- `ENEMY_ABILITY_NOTES` chuyển từ game_hud sang `EnemyStats.ABILITY_NOTES`
  (dữ liệu địch, không phải dữ liệu HUD). `_ENEMY_DISPLAY_NAMES` giữ lại làm
  bảng tra dự phòng; field trong .tres được ưu tiên.
- `tools/check_content.py` bắt loại lỗi "nội dung có mà không chạy": thiếu field,
  trùng `id`, `attack_range > 7`, `attack_speed = 0`, **địch không nằm trong bảng
  mùa mà cũng không khai `spawn_seasons` (không bao giờ spawn)**, thiếu icon/model.
  Boss được loại trừ vì chúng spawn qua `BOSS_IDS`. Chạy sau mỗi lần thêm nội dung.
- Bảng "thêm một thứ mất bao nhiêu file" nằm ở đầu `docs/CONTENT_AUTHORING.md`.

*Vật phẩm + perk thành Resource mở bằng Inspector (2026-07-30):*
- 4 lớp ở `scripts/resources/`: `PotionData` · `EquipmentData` · `RelicData` ·
  `PerkData`. Mỗi lớp có `to_dict()` nên **phần code cũ vẫn làm việc với dict**,
  không phải sửa nơi đọc.
- **77 file `.tres`** xuất ra `res/{potions,equipment,relics,perks}/` từ các bảng
  khai cứng. Trước đó 34 món (trang bị + di vật) CHỈ tồn tại trong GDScript —
  `data/equipment/` và `data/relics/` rỗng hoàn toàn.
- `ContentLoader.load_dir()` là điểm nạp chung. Thứ tự: `.tres` → JSON → bảng
  cứng; trùng `id` thì bản sau thắng. Đã kiểm bằng cách sửa `alchemy_book.tres`
  rồi nạp lại — giá trị mới thắng bảng cứng.
- **BẪY**: `special` của thuốc là CHUỖI (`"heal_king"`), không phải dict; và
  `target` có cả giá trị `"self"`. Khai sai kiểu trong Resource thì
  `ResourceSaver` ném lỗi gán lúc xuất.
- Bản export mang đuôi `.remap` — `ContentLoader` phải `trim_suffix(".remap")`
  trước khi `load()`, nếu không bản build không thấy file nào.

*Gỡ nội dung khỏi code — tạo được bằng kéo thả (2026-07-30):*
- **Nhánh synergy mới KHÔNG còn cần sửa `enum UnitType`.** `TowerStats.synergy_tag`
  là chuỗi; `get_synergy_tag()` ưu tiên nó, rỗng thì suy từ enum (tương thích
  ngược, .tres cũ không phải sửa). Mọi nơi đếm synergy PHẢI gọi hàm này —
  `SynergyManager.on_tower_placed` và `king_manager` đã đổi; đọc thẳng `type`
  thì nhánh khai bằng chuỗi bị bỏ qua.
- 15 định nghĩa synergy xuất ra `res/synergies/*.tres`. Bảng cứng trong
  `SynergyManager.gd` giờ chỉ chạy khi thư mục đó RỖNG.
- **Bảng mùa cứng 23 dòng `_get_enemy("...")` đã bị GỠ.** `_get_season_enemy_pool`
  nay chỉ gọi `_append_data_driven_enemies` — mỗi `.tres` tự khai `spawn_seasons`
  + `spawn_weight`. Đã di cư lịch cũ vào 10 file nên tần suất giữ nguyên y hệt
  (kiểm bằng cách in pool từng mùa và so).
- `DEFAULT_AFFINITY` / `ABILITY_NOTES` cũng đã ghi vào từng `.tres`; hai bảng
  trong code chỉ còn là mặc định dự phòng.
- Batch test 11 chốt việc này: đếm số `_get_enemy(` còn lại, và bắt mọi loài
  địch phải TỰ khai `spawn_seasons` + `weak_element` trong `.tres` của nó.

*Âm thanh thật + tiết tấu chậm (2026-07-30):*
- **18 SFX sinh bằng rfxgen** (`gamedev-toolkit-mcp`, `D:\Apps
fxgen`) qua
  `design_sound`, 44.1 kHz mono, thay bộ bíp Python 22 kHz cũ.
  **BẪY**: `starting_point` GHI ĐÈ `wave_type` — muốn sóng cụ thể thì đừng
  truyền `starting_point`, khai tham số tường minh.
- Sau khi sinh phải **chuẩn hoá đỉnh về 0.85**: 5 tiếng chạm trần 1.00 nghe rè.
- Nhạc nền `tools/make_music.py` — soạn NỐT thật (Rê Dorian, 66 BPM, 8 ô nhạc,
  29 s, 3 lớp drone/arpeggio/giai điệu). rfxgen chỉ làm SFX một nhát, không
  ghép được vòng lặp liền mạch. Biên đầu/cuối = 0 nên không có tiếng "cộp".
- **Tiết tấu chậm lại kiểu Bloons TD**: tốc độ địch ×0.55 (dơi 6.88 → 3.78 ô/s),
  `SPAWN_INTERVAL` 0.8 → 1.5 s, đạn 18.75 → 9.5 ô/s (trước bay hết tầm 5 ô
  trong 0.27 s nên mắt không kịp thấy).
- **Chậm lại làm game DỄ HƠN** — đo được: HP bot leo từ 19 lên 34 giữa ván vì
  tháp có nhiều thời gian bắn hơn. Bù bằng SỐ LƯỢNG chứ không phải tốc độ:
  `ENEMIES_PER_WAVE` 10 → 14, tăng 2 → 3/wave, `ENEMY_HEALTH_GROWTH` 1.15 → 1.18.
- **Sink kinh tế mới — nâng sao bằng VÀNG** (`game_map.try_star_up_with_gold`).
  Wave đông ⇒ nhiều vàng hơn; đo được tồn 1741 vàng ở wave 10 vì bàn đã kín.
  Ghép sao bằng quân trùng vẫn giữ; đây là đường THỨ HAI, giá 140/380 + 22 mỗi
  wave. Nút nằm trong panel tháp.

*Mở rộng nội dung — 3 Rival King (2026-07-29):*
- `BOSS_WAVES = [7, 14, 20]`, `MAX_WAVES = 20` (trước 1 boss / 10 wave).
- `_pick_boss_stats()` chọn theo **THỨ TỰ wave boss, không random** — mục tiêu ván
  là hạ đủ cả ba, bốc ngẫu nhiên sẽ có ván gặp trùng một vua hai lần.
- Hạ mỗi Rival King mở khoá một quân vào `MetaProgress.unlocked_soldier_ids`
  (longbowman → paladin → ballista), đúng lời hứa GDD.
- **Đo bằng bot tiêu sạch vàng**: HP 20 → đáy 8 (wave 9) → hồi lên 26 (wave 16),
  hạ 2 vua tới wave 17. Đường cong ổn: khủng hoảng giữa ván, thoải mái về cuối.
- **Vàng dư CHỈ xuất hiện ở bản 20 wave**: 441–714 từ wave 13, vì bàn đã kín
  (256 ô có quân) nên không còn chỗ đặt tháp. Trần xáo shop nay TĂNG THEO WAVE
  (`REROLL_MAX_PER_WAVE`). Sink đúng bài hơn (nâng sao bằng vàng) là bước sau.

*Art sinh bằng generator (2026-07-29) — `tools/make_*.py`:*
- `make_terrain.py` (32 texture ≤3 màu) · `make_panels.py` (10 panel ≤5 màu) ·
  `make_perk_icons.py` (25 icon 48×48 ≤6 màu) · `make_font.py` (295 glyph).
- Khác hẳn bộ cũ: bộ cũ jitter NGẪU NHIÊN từng pixel ra 48–142 màu. Ở đây mỗi
  pixel đặt bằng toạ độ viết tay, chạy lại cho kết quả y hệt.
- **Hai lỗi chỉ thấy khi nhìn ảnh chụp thật, không thấy qua số đo màu**:
  (1) ô sáng/tối quá gần tông → mất kẻ ô bàn cờ sau khi biome nhân màu;
  (2) dùng màu nhấn (đỏ máu Hoả Diệm) cho khe nứt → cả bàn lấm tấm đỏ.
  Màu nhấn chỉ được dùng RẤT ÍT; hoạ tiết nền phải dùng tông kề bên.

*Export + hướng dẫn nhập môn (2026-07-29):*
- `export_presets.cfg` GIỮ TRONG REPO (trước bị .gitignore nên dự án chưa export
  lần nào). 3 preset: Windows · Linux · Web. Máy này chỉ cài template **Web**;
  desktop cần tải template ~800MB qua editor.
- Build Web đã chạy thật: **0 lỗi**, `index.pck` 1.5 MB, đã xác minh font
  (`pixel_8x8`, `game_theme`) và asset nằm trong gói.
- `scripts/ui/tutorial_overlay.gd` — 5 thẻ, tự hiện ván ĐẦU rồi ghi cờ
  `MetaProgress.seen_tutorial`. Nút "Xem lại hướng dẫn" ở màn Cài Đặt bật lại.
- **Popup trinh sát là Window nên vẽ ĐÈ lên mọi CanvasLayer**, kể cả lớp hướng
  dẫn. `game_map._tutorial_open()` hoãn popup tới khi đọc xong.
- Tutorial tạm dừng game → test nào đo máy trạng thái pha phải đặt
  `seen_tutorial = true` trước, nếu không đếm ngược chuẩn bị không chạy.
- **Sau mỗi lần `python tools/make_font.py` PHẢI chạy tiếp**
  `godot --headless --script res://tools/rebuild_font_resource.gd` — `.tres` là
  SNAPSHOT của `.fnt`, không tự đọc lại. Quên thì font mới không có tác dụng.

*Font pixel tự vẽ (2026-07-29) — `python tools/make_font.py`:*
- `assets/fonts/pixel_8x8.{png,fnt}` — **287 glyph** do generator vẽ, mỗi pixel
  đặt tay: ASCII + **đủ dấu tiếng Việt** + 58 ký hiệu game. Thân chữ 5×7, ô chứa
  9×14 (3 hàng trên cho dấu chồng như "ế", 2 hàng dưới cho dấu nặng và chữ g/y).
- Chữ Việt có dấu được **ghép** từ chữ gốc + dấu, không vẽ tay 134 lần.
- `assets/fonts/game_theme.tres` gán qua `gui/theme/custom`. **Phải đặt bằng
  `ProjectSettings.set_setting()` + `save()`** — viết tay vào project.godot thì
  Godot ghi đè và bỏ mất dòng đó (giữ lại chú thích nhưng xoá setting).
- **BẪY LỚN — Emoji_Presentation**: 16 ký tự (⚡ 🔥 🌍 🧪 …) mang thuộc tính
  Unicode `Emoji_Presentation=Yes`. TextServer ÉP chúng sang font emoji của hệ
  thống *bất kể font chính có glyph hay không* — đo được advance 19px thay vì 6px
  và vẽ ra màu cam. Giải: đưa 16 ký hiệu đó vào **Private Use Area** (U+E001..E010).
  PUA không mang thuộc tính Unicode nên không bao giờ bị định tuyến lại.
  Tên hằng ở `scripts/ui/glyphs.gd`; trong chuỗi dùng escape `` chứ đừng
  dán ký tự thô.
- `has_char()` MỘT MÌNH KHÔNG ĐỦ để kết luận — nó trả true cho cả 16 ký tự bị ép.
  Phải đo thêm advance. Batch test 8 kiểm cả hai cách.
- Bitmap font phải tắt antialias + subpixel, nếu không pixel bị nhoè.

*TÁI THIẾT KẾ THEO BALATRO (2026-08-03) — ĐỌC TRƯỚC MỌI THỨ KHÁC:*

Game chuyển từ "TD nhiều hệ thống" sang "roguelike một công thức" kiểu Balatro.
Bài kiểm duy nhất cho mọi cơ chế từ nay: **nó có vào được `Nền × Bội` không?**
Không vào được thì tắt cờ ở `scripts/managers/feature_flags.gd`.

- **Quân cờ đánh theo NƯỚC ĐI, không theo bán kính.** `scripts/towers/chess_pattern.gd`
  (`ChessPattern`, toàn static) là nguồn sự thật. Xe trượt dọc hàng/cột, Tượng
  chéo, Mã nhảy chữ L không bị chặn, Tốt 4 ô chéo kề, Công thành có tầm TỐI
  THIỂU. **Quân của mình CHẶN đường trượt** — đó là ràng buộc tạo ra câu đố xếp
  hình. Địch KHÔNG chặn (nó là mục tiêu).
  Khai bằng `TowerStats.attack_pattern` (`@export_enum`) nên thêm quân vẫn kéo thả.
- **Ngân sách dạy về 0**: không ai cần học Xe đi thế nào. Đây là lý do duy nhất
  chọn chủ đề cờ vua — bản cũ có tên quân cờ mà không có luật cờ nào.
- **Bàn KHOÁ 8×8 cả ván** (`EXPAND_EVERY_N_WAVES = 0`) + **trần số quân**
  (`MAX_UNITS_BASE 10`, `+0.9/wave`, trần 20). Bản cũ nở tới 24×24 = 576 ô và đo
  được bot rải 106 tháp mà CHƯA LẦN NÀO hết chỗ — khi vị trí không khan hiếm thì
  mọi hệ xếp hình chạy không tải. Mã mở rộng vẫn còn và vẫn được test, chỉ không
  được gọi.
- **`Nền × Bội`** (`scripts/map/board_score.gd`):
  `NỀN(ô)` = Σ DPS quân phủ ô đó · `BỘI(ô)` = thế cờ × cấp ô nguyên tố × di vật
  × luật Vua. HUD hiện **một số so với một số**: sát thương cả wave / tổng máu wave.
  **Ba lần tính sai đã sửa** — ghi lại để khỏi lặp:
	(1) `Σ điểm ô / tốc độ × số địch` bỏ qua tranh chấp mục tiêu → dư ~4×;
	(2) `DPS × thời lượng wave` giả định quân luôn có mục tiêu → dư ~3×;
	(3) đúng: `DPS × BỘI_tb × min(thời_lượng, n × k / v)` với k = số ô ĐƯỜNG phủ.
  Còn `EFFICIENCY = 0.55` là **hằng số thực nghiệm** (đạn bay, sát thương thừa,
  đầu/cuối wave vắng địch). Hiệu chỉnh sao cho **tỉ lệ 1.0 trùng ranh giới
  sống/chết** — đo lại sau mỗi lần đổi nhịp wave hoặc chỉ số quân.
- **BẪY ĐÃ DÍNH — lọc mục tiêu lúc `area_entered`**: địch chạm mép hình cầu lọc
  thô khi CHƯA đứng trên ô được phủ thì bị loại VĨNH VIỄN (`area_entered` chỉ bắn
  một lần). Phải giữ danh sách thô `_in_area` rồi lọc theo nước đi MỖI FRAME.
- **BẪY ĐÃ DÍNH — `Array.filter()` trả `Array` không có kiểu**, gán vào
  `Array[Enemy]` ném lỗi runtime mỗi frame; game không sập, chỉ là mọi tháp không
  bao giờ có mục tiêu. Phải append từng phần tử.
- **Thế cờ** (`scripts/towers/chess_formations.gd`) — bản dịch của "ván bài":
  Trận Pháo (2 Xe cùng hàng/cột) · Giao Hoả · Song Mã · Tường Tốt · Cấm Vệ ·
  Thê Đội · Nước Chĩa. Dò theo HÌNH HỌC QUÂN, khác `FormationDetector` cũ (dò
  theo ô nguyên tố). Hai hệ chạy song song: ô cho Nền, quân cho Bội.
- **Bộ quân** (`scripts/shop/army_deck.gd`) — bản dịch của bộ bài. Khởi đầu là bộ
  cờ thật (6 Tốt, 3 Xe, 2 Mã, 2 Tượng, 1 Hậu). Shop **rút quân TỪ BỘ** và bán
  **thao tác lên bộ**: loại quân (bộ mỏng → tỉ lệ rút quân tốt tăng), nâng sao
  vĩnh viễn, phong Hậu. Không nối `shop_manager.army_deck` thì bộ chỉ là bảng số.
- **Rival King ĐỔI LUẬT** (`scripts/map/king_rules.gd`), không phải nhiều máu hơn:
  Vua Câm (Tượng ngừng bắn) · Vua Nghẽn (Xe) · Vua Nghiêng (chỉ nửa bàn tính Bội)
  · Vua Gương (thế cờ không cộng dồn) · Vua Vội · Vua Thuế. Luật CHỈ sống trong
  wave boss, `_on_phase_changed` gọi `clear()` ở wave thường.
- **Đã TẮT bằng cờ** (không xoá): 4 mùa · khí hậu biome · synergy loại quân · ô
  Phước/Nguyền · chí mạng · combo hạ gục · mở rộng bản đồ. Lý do từng cái ghi
  trong `feature_flags.gd`. **Chí mạng tắt vì bảng ngưỡng hứa một con số chính
  xác** — ngẫu nhiên lúc chấm điểm phá đúng lời hứa đó.
- **Quy mô ván**: 12 wave (~15 phút), boss ở 5/9/12, 8 địch +2/wave,
  `ENEMY_HEALTH_GROWTH 1.13`. Bản cũ 20 wave × 850 địch được cân cho bàn 24×24.
- Đo bằng bot đặt tối ưu: tỉ lệ 1.39 · 1.57 · 0.78 · 1.00 → sống; **0.45 ở wave
  boss → chết**. Ranh giới 1.0 khớp thực tế.
- Test batch 12 (`tests/test_12_chess_core.gd`, 43 khẳng định) bảo vệ Ý ĐỊNH
  THIẾT KẾ chứ không phải chi tiết: mọi quân phải khai nước đi (không còn RADIAL),
  bàn phải 8×8, trần quân phải được THI HÀNH, quân không phủ ô đường phải gây 0,
  và **mọi luật Rival King phải có tác dụng thật**.

*Hoàn thiện lớp hiển thị + cân bằng lại (2026-08-03, tiếp):*
- **Tooltip Nền × Bội theo ô** (`game_map.cell_score_info` → `hud.show_cell_tooltip`).
  Đây KHÔNG phải trang trí: Balatro sống nhờ việc hiện từng lá cộng bao nhiêu
  Chip, từng Joker nhân bao nhiêu. Chỉ hiện số tổng thì người chơi biết mình yếu
  mà không biết sửa chỗ nào. Chỉ dựng lại khi ĐỔI ô (nó quét mọi tháp).
- **Card shop hiện NƯỚC ĐI** — với mô hình này "Xe hay Mã" quyết định nhiều hơn
  mọi con số cộng lại.
- `ChessFormationOverlay` tô sáng thế cờ + nhãn nổi. Cao độ quad y=0.13 (trên
  overlay hình thế nguyên tố 0.12), nhãn y=2.0 (trên nhãn kia 1.7) — hai lớp
  cùng hiện nên phải tách cả z lẫn cao độ nhãn.
- **Panel bộ quân phím B**, hiện TỈ LỆ RÚT chứ không chỉ số lượng — đó mới là thứ
  quyết định có nên loại quân. **KHÔNG dùng phím D**: `camera_controller` poll
  thẳng `Input.is_key_pressed(KEY_D)` để pan nên `set_input_as_handled()` vô hiệu.
- **Băng luật Rival King** hiện 6 giây khi vào wave boss. Boss Blind của Balatro
  luôn nói TRƯỚC luật của nó.
- Tutorial + codex viết lại theo trục mới. Codex thêm 4 mục: công thức · nước đi ·
  thế cờ · luật Rival King. Ô nguyên tố nay dạy như **nguồn Bội thứ hai**.
- **Ba lỗi cân bằng chỉ lộ ra khi chơi trọn ván bằng bot:**
  (1) `wave_total_hp` KHÔNG tính máu boss → ngưỡng nói dối ở đúng wave quan
	  trọng nhất, người chơi thấy "đủ" rồi thua ngay;
  (2) `wave_duration` ở wave boss dùng 6 lính = 9 giây, trong khi Rival King đi
	  trọn đường mất ~30 giây → công suất bị đánh giá thấp 3×;
  (3) mốc mùa vẫn là hằng cứng (≤2/≤5/≤8) viết cho ván 20 wave → với ván 12 wave
	  thì Mùa Thu ập tới ngay wave 6 và ngưỡng nhảy 1507 → 4454 trong MỘT bước.
	  Nay mốc chia theo TỈ LỆ độ dài ván + `SEASON_BLEND = 0.55` giữ lại một phần
	  địch mùa trước để dốc thoải.
- Máu boss 1200–1600 → **420–560**: bảng cũ cân cho bàn 24×24 với 100+ tháp.
- Đo lại (bot đặt tối ưu, hai lần chạy): HP 20 giữ tới wave 4, sứt nhẹ ở wave 5
  (boss đầu), **thua ở wave 9** (boss thứ hai). Người chơi thật biết xáo shop,
  loại quân khỏi bộ và mua ô nguyên tố sẽ đi xa hơn.

*Lớp nội dung kiểu Joker + dọn nốt (2026-08-03, tiếp):*
- **Xuyên quân là THANG ĐỘ, không phải công tắc.** Bản đầu có di vật "Đường
  Thẳng Vô Tận" xoá hẳn luật chặn — sai, vì chặn đường trượt CHÍNH LÀ câu đố đặt
  quân; xoá nó là xoá câu đố chứ không phải làm người chơi giỏi hơn.
  Đo tầm phủ trung bình của Xe (tầm 5) trên bàn 8×8:
  | quân | xuyên 0 | xuyên 1 | xuyên 2 | vô hạn |
  |---|---|---|---|---|
  | 10 | 15.0 | 18.6 | 18.6 | 20.0 |
  | 18 | 11.0 | 15.7 | 16.3 | 20.0 |
  | 22 |  9.6 | 14.4 | 15.5 | 20.0 |
  Giá trị dồn hết vào lượt xuyên ĐẦU (+24%…+49%); lượt thứ hai chỉ ~7%; vô hạn
  hơn xuyên 2 không đáng kể. Nên bản "xoá luật" vừa vô dụng lúc đầu (4 quân mất
  0% tầm phủ) vừa gần-tối-đa lúc cuối, mà không có bậc nào ở giữa.
  Nay `pierce_count` cộng dồn: Mũi Giáo Xuyên (1, 250đ) · Mũi Khoan Công Thành
  (2 + thưởng thế cờ, 360đ — KHÔNG bán lượt thứ hai với giá gấp đôi).
  Ô có quân đứng vẫn KHÔNG tính là phủ dù đã xuyên qua — địch không đứng đó được.
- **8 di vật CHẠM VÀO CÔNG THỨC** (`res/relics/chess_*.tres`) — mỗi món sửa CÁCH
  TÍNH chứ không cộng một con số: Vương Miện Gãy (thưởng theo số LOẠI thế cờ) ·
  Cờ Tàn / Vua Đơn Độc (bàn càng thưa càng mạnh) · Vó Ngựa (Mã nhảy thêm vòng
  chữ L xa) · Mũi Giáo Xuyên / Mũi Khoan Công Thành (xuyên N quân mình) · Con Tốt Thí
  · Trống Trận · Đại Cục. Đo được +24% → +126% tuỳ bố cục, đã siết 4 món.
- **BẪY NẶNG — `RelicSystem._sanitize` lọc TRẮNG khoá hiệu ứng.** Sáu khoá mới
  không có trong `EFFECT_KEYS` bị VỨT im lặng (chỉ `push_warning`), nên cả 8 di
  vật mua được, hiện mô tả đầy đủ, mà **không làm gì cả**. `audit_wiring.py`
  KHÔNG bắt được vì khoá có người đọc — chỉ là không bao giờ có giá trị.
  Thêm khoá hiệu ứng mới thì PHẢI thêm vào `EFFECT_KEYS`.
- Di vật đổi nước đi (Vó Ngựa, Đường Thẳng Vô Tận) phải gọi `Tower.bump_layout`
  + `refresh_coverage()` trong `_apply_all`, nếu không chỉ quân đặt SAU mới hưởng.
- `focus_lens` (trang bị crit) đã chết vì crit tắt → đổi thành +1 tầm bắn.
- **Boss KHÔNG khoá quân đang bị luật Rival King làm câm** — hai cơ chế khoá
  chồng nhau thì người chơi mất phần lớn đội hình trong vài giây và không phòng
  bị được. Luật Vua đã là hình phạt, boss không phạt lần hai.
- `ENEMIES_PER_WAVE` 8 → 10: đo được bot đạt tỉ lệ 1.3–3.2 ở bốn wave đầu, không
  có sức ép thì bốn wave đầu chỉ là thủ tục bấm nút.
- Đo lại trọn ván: HP 20·20·20·20 → 13 (boss đầu) → 13 → 8 → 8 → thua wave 9.
  Dốc thật, không còn vách đá.
- Việt hoá nốt màn thắng/thua và nhãn khoá ở màn chọn vua.

*Kiểm toàn diện sau tái thiết kế (2026-08-04) — bốn lỗi tìm được:*
- **`starting_territory_count` là số CHẾT từ commit đầu tiên.**
  `TerritoryManager.initialize` duyệt `grid_data.keys()`, mà dict đó CHỈ chứa ô
  đường (chuỗi `"path"`) và ô có quân — **ô trống không bao giờ là khoá**. Nên
  ứng viên luôn rỗng và mọi Vua khai 3-5 ô lãnh thổ thực tế nhận 0. Không ai
  phát hiện suốt vì game vẫn chạy bình thường. Nay duyệt BIÊN LƯỚI.
  Từ bản Balatro-hoá thì lỗi này nặng hơn hẳn: ô nguyên tố nuôi cả NỀN lẫn BỘI.
- **Wave boss bỏ quên chính CON BOSS khi tính nhóm địch.** `n` lấy từ
  `calculate_enemies_for_wave` = 6 lính hộ vệ, trong khi boss ở trên bàn ~25
  giây. Đo được công suất tụt **83%** giữa wave 8 và 9 (9490 → 1657).
  Nay `enemy_groups()` trả từng nhóm `{count, speed}` KÈM boss — tính theo nhóm
  cũng sửa luôn chỗ cũ lấy một tốc độ chung cho mọi loài.
- **Wave boss có điều kiện thua RIÊNG.** Boss chạm Vua = thua NGAY
  (`boss_escaped`), không liên quan máu Vua còn bao nhiêu. Nên "tổng sát thương
  ≥ tổng máu wave" KHÔNG phải điều kiện sống sót — đo được tỉ lệ **1.03 mà vẫn
  thua sạch**. Nay `summary()` so RIÊNG sát thương-lên-boss với máu boss và lấy
  tỉ lệ NGẶT HƠN trong hai cái.
- **Hai signal mới không ai nghe**: `tower_placer.place_rejected` (chạm trần quân
  thì im lặng, người chơi tưởng game hỏng) và `army_deck.deck_changed` (panel bộ
  quân không tự cập nhật sau khi mua thao tác). `audit_wiring.py` bắt được cả hai
  — chạy nó sau mỗi lần thêm signal.
- Kiểm sạch: trần quân vẫn cho GHÉP SAO khi bàn đã đầy · sao không làm tụt tầm ·
  không quân nào còn dùng RADIAL · hai overlay hình thế khác cao độ (0.12 vs
  0.13, nhãn 1.7 vs 2.0) · `MAX_WAVES` khớp `MAX_WAVES_HINT` · không perk/
  encounter nào còn tham chiếu hệ đã tắt.

*NHIỀU LOẠI CỜ + di vật đổi luật + Bộ Khai Cuộc (2026-08-04):*

Ý tưởng gốc: Balatro dùng poker + tarot + planet; ở đây dùng **cờ vua + cờ tướng
+ shogi + cá ngựa + cờ vây**. Mỗi loại cờ đóng góp một cơ chế mà cờ vua KHÔNG
có. Cắm hết vào `attack_pattern` và `EFFECT_KEYS` sẵn có — **không đụng concept**.

- **5 nước đi mới** trong `ChessPattern.Kind`:
  - `CANNON` **(Pháo — viên ngọc)**: đi thẳng như Xe nhưng chỉ bắn được ô SAU
	đúng MỘT quân làm ngòi. Cả game dạy "quân mình chắn đường là xấu"; Pháo lật
	ngược — bạn PHẢI đặt một quân làm ngòi. Không loại cờ nào khác có nước này.
  - `LANCE` (Hương Xa, shogi) — một hướng, tầm rất xa
  - `GOLD` (Kim Tướng, shogi) — 6 ô bất đối xứng, chéo TRƯỚC mới tính
  - `XIANG` (Tượng cờ tướng) — chéo đúng 2 ô, **bị cản tâm**
  - `DICE` (cá ngựa) — vành khuyên rộng, sát thương lớn, hồi chiêu chậm
- **5 quân mới**, art vẽ theo NGUỒN GỐC nên nhìn là biết thuộc loại cờ nào:
  shogi = miếng ngũ giác · cờ tướng = đĩa tròn · cá ngựa = khối xúc xắc.
- **10 di vật ĐỔI LUẬT** (khác hẳn lớp cộng số): Tốt Nổ (Tốt đánh 8 ô) · Pháo
  Đài (mọi Xe thành Pháo, bù ×2.5 sát thương) · Phong Cấp Shogi (★3 đánh nước
  Hậu) · Long Mạch Lan (ô kề ô nguyên tố cũng tính) · Đất Cằn (ô THƯỜNG +45%
  Bội — mở lối chơi phản nguyên tố) · Kho Vũ Khí (trang bị dùng chung theo
  LOẠI quân) · Song Thủ · Vây Bắt (cờ vây).
- **6 Bộ Khai Cuộc** (`res/decks/*.tres`) — biến thể chơi lại rẻ nhất. Mỗi bộ
  gắn một loại cờ và mang LUẬT riêng, mở khoá bằng điểm tích luỹ. Đây là phần
  meta "mở LỐI CHƠI mới", khác hẳn 14 nâng cấp cộng chỉ số.
  **Luật của bộ dùng CHUNG khoá với `EFFECT_KEYS` của di vật** nên không phải
  viết hệ áp dụng thứ hai — `_apply_selected_deck()` ghi thẳng vào `relic_*`.

*Năm bẫy đã dính trong đợt này:*
- **`match` của GDScript không cho pattern xuống dòng.** `"a", "b",
"c":` là
  lỗi parse "Expected expression for match pattern". Phải gộp một dòng.
- **KHÔNG dùng 0 làm cờ "tắt" cho pattern** — 0 là `Kind.ROOK` hợp lệ. Dùng -1.
- **`EquipmentSystem._apply` thoát sớm** khi tháp chưa lắp gì ⇒ di vật "Kho Vũ
  Khí" (trang bị dùng chung) không bao giờ chạm tới được.
- **Sát thương có thể ÂM.** Repeater (-40% sát lấy +50% tốc) × di vật Song Thủ
  = đo được **-9** ⇒ quái được HỒI MÁU khi bị bắn. Nay `current_damage` có
  sàn 1. Lỗi này tồn tại độc lập với di vật, chỉ là chưa ai chạm tới.
- **Trần tầm 7 của `check_content.py` áp sai cho nước đi một hướng.** Hương Xa
  tầm 8 chỉ phủ 8 ô, ít hơn Xe tầm 5 (20 ô). Luật giờ biết đọc `attack_pattern`.

*Bốn lỗi từ phản hồi "chồng ô không thấy gì, +1 tầm không thấy gì" (2026-08-04):*
- **Panel ô nguyên tố CHẾT CÂM.** `hud_tower_panel._find_territory_manager()`
  dùng `get_parent()` — nhưng component HUD gắn bằng `X.attach(hud)` nên cha nó
  là HUD (CanvasLayer), KHÔNG phải game_map. Hàm luôn trả null ⇒ **cả mục nguyên
  tố** (cấp ô · Dấu kéo dài · phản ứng · thưởng tháp · xem trước cấp kế) **và nút
  bán ô** đều không render. Xếp chồng ô lên Lv3 vẫn chạy đúng ở tầng logic
  (đo được cấp 1→2→3, thưởng đổi thật) nhưng người chơi không thấy gì.
  Panel từ 5 dòng lên 16 sau khi sửa. Ba hàm cùng lỗi này → gom vào `_map()`.
- **`+1 tầm bắn` là SỐ CHẾT với 6/13 nước đi.** Nước NHẢY là tập ô cố định nên
  `max_range` không ảnh hưởng — đo được Mã/Tốt/Vua/Kim Tướng/Tượng Điền phủ y hệt
  ở tầm 3, 4 và 6. Mọi nguồn +tầm (perk, trang bị, ô Băng, ★3, Hàng Long) vô
  nghĩa với chúng.
  Sửa: **TẦM = SỐ VÒNG**. Vòng k = bước gốc × k. Đọc được bằng một câu, và mọi
  +1 đều đổi. Bậc phải là **1**, không phải 2-3 — bậc thưa thì phân nửa số lần
  nhặt +1 vẫn không đổi gì (đã thử bậc 2/3 rồi bỏ).
  Tầm gốc hạ theo: Mã 4→2, Tốt 3→2, Tượng Điền giữ 2 (Xe tầm 5 = 20 ô làm mốc).
- **`cells()` và `covers()` lệch nhau** — hai điểm vào của cùng một luật:
  (1) `_clear_line` duyệt HỞ hai đầu nên `covers()` chấp nhận chính ô CÓ QUÂN
	  đứng, còn `cells()` loại nó ra;
  (2) Kim Tướng so `d.y == FORWARD.y` thay vì so DẤU — ở vòng 2 thì d.y = 2 nên
	  mọi ô chéo trước vòng ≥2 bị loại.
  Test giờ quét TOÀN BỘ nước đi × tầm × ô và bắt mọi chỗ lệch.
- **`CoverageOverlay`** — click vào quân thì tô đúng ô nó với tới (ô ĐƯỜNG vàng
  đậm, ô thường xanh nhạt, ô của chính nó xanh lá). Với mô hình nước đi, "tầm
  bắn 5" không nói lên gì: Xe/Mã/Tốt cùng tầm 5 phủ ba hình khác hẳn nhau.
  Panel cũng hiện **tầm HIỆU DỤNG** (kèm tầm gốc nếu khác) thay vì chỉ tầm .tres.
  Cao độ y = 0.14, trên overlay hình thế nguyên tố (0.12) và thế cờ (0.13).

*"Không đặt được quân" — chọn ô bằng chuột (2026-08-05):*
- **Chế độ ĐẶT dùng `GridUtil` (mặt đất), KHÔNG dùng `PickUtil`.** PickUtil bắn
  tia vào `PickArea` của quân — hộp cao **1.5 m**, mà camera nghiêng −50° nên
  trên màn hình nó phủ luôn **hai ô phía trước** con quân.
  Đo được (`root.get_camera_3d().unproject_position` rồi hỏi ngược lại): quân ở
  (2,2) → trỏ chuột vào GIỮA ô trống (2,1) và (2,0) đều trả về (2,2).
  Cú click đó rơi vào nhánh "ô đã có quân" và bị bỏ qua IM LẶNG.
- Triệu chứng: **bàn càng nhiều quân càng khó đặt**, và không có thông báo gì —
  giống hệt "game hỏng". Nặng thêm từ bản Balatro-hoá vì thế cờ khuyến khích
  xếp quân SÁT NHAU.
- `tower_placer.update_preview` phải dùng CÙNG cách giải toạ độ, nếu không bóng
  ma một nơi mà click rơi một nẻo.
- **PickUtil vẫn đúng cho info / sa thải / overcharge** — ở đó người chơi nhắm
  vào CON QUÂN. Ở chế độ đặt họ nhắm vào Ô. Đừng gộp hai thứ này lại.

*Không được từ chối trong im lặng (2026-08-05):*
- `place()` từng có **ba** đường trả về không nói gì: thiếu Sắc Lệnh · hết kho ·
  ô đã có quân khác loại. Chỉ trần số quân là có báo.
  `push_warning` CHỈ ra console — với người chơi thì cú click biến mất không dấu
  vết. Nay mọi nhánh đều phát `place_rejected` (hoặc `phase_message`).
- **Đặt quân còn tốn SẮC LỆNH** ngoài số vàng đã trả ở shop (Tốt 1.0 → Hậu 4.0).
  Đây là cổng thứ hai mà thẻ hàng trong shop không nói rõ — nếu sau này còn báo
  "không đặt được", kiểm chỗ này trước.
- Test batch 12 kiểm NỘI DUNG thông báo, không chỉ kiểm "có báo". Bản đầu xanh
  vì lý do sai: bàn đang đầy nên trần số quân bắn trước hai nhánh cần kiểm.

*BỘI THÀNH THẬT (2026-08-05) — ĐỌC TRƯỚC KHI THÊM NGUỒN BỘI MỚI:*
- **Lỗi gốc**: cả lớp "Bội" chỉ sống trong `board_score.mult_breakdown()`, mà
  file đó CHỈ có HUD đọc. Đo được: hai Xe cùng hàng (Trận Pháo) làm Bội trên HUD
  nhảy 1.00 → 2.00 trong khi `tower.current_damage` đứng nguyên 34. **7 thế cờ
  và 9 di vật** (Vương Miện Gãy · Cờ Tàn · Vua Đơn Độc · Con Tốt Thí · Đất Cằn ·
  Vây Bắt · Trống Trận · Đại Cục · Long Mạch Lan) đổi một con số trên màn hình
  và không làm gì khác. Câu đố xếp quân — thứ mà bàn 8×8 khoá cứng và trần số
  quân sinh ra để ép người chơi giải — được thưởng đúng BẰNG KHÔNG.
- **`audit_wiring.py` không bắt được**: mấy khoá đó CÓ người đọc (board_score),
  chỉ là không đến được chỗ gây sát thương. Thêm khoá Bội mới thì phải tự hỏi
  "ai NHÂN nó vào sát thương?", không chỉ "ai đọc nó?".
- **Cách sửa**: mỗi dòng trong `mult_breakdown` mang cờ `combat`.
  `combat_mult()` = tích các dòng `combat` → `Tower.formation_damage_mult`, nhân
  trong `recalculate_stats` cùng chỗ với `star_damage_mult`.
  `residual_mult()` = phần còn lại (khuếch đại PHẢN ỨNG — đã áp thật ở
  ReactionTable/BuffLayer). **Bất biến: `cell_mult = combat_mult × residual_mult`**
  — có test chốt. Thêm dòng mới mà quên gắn cờ thì nó rơi vào residual và lại
  thành số chết.
- **`avg_mult_on_path` PHẢI dùng `residual_mult`**: `tower_dps()` đọc thẳng
  `current_damage` vốn đã gồm phần combat ⇒ nhân `cell_mult` vào nữa là đếm hai
  lần, và phồng gấp đôi đúng ở những bàn xếp hình tốt nhất.
- **`formation_damage_mult` là hệ số DẪN XUẤT**, không cộng dồn — đọc lại từ bàn
  mỗi lần `refresh_formation_mult()`. Gọi bao nhiêu lần cũng ra một kết quả.
- **Phải gọi `game_map.refresh_formation_mults()` ở MỌI chỗ đổi Bội**, không chỉ
  khi thế cờ đổi: ô nguyên tố mua/bán (Đất Cằn, Long Mạch Lan đảo chiều), di vật
  mua/bán, và luật Rival King bật/tắt mỗi lần đổi pha.
- **BẪY đã dính (lỗi CÓ SẴN, chỉ lộ ra khi Bội thành thật)**: `queue_free()` để
  node nằm trong cây tới CUỐI FRAME, mà `tower_dismissed` xử lý ĐỒNG BỘ ngay lúc
  đó ⇒ đếm lại vẫn thấy con vừa gỡ. Gỡ một Xe khỏi Trận Pháo thì thế cờ vẫn báo
  còn, và quân còn lại giữ ×1.3 VĨNH VIỄN. `_towers()` của cả ChessFormations lẫn
  BoardScore nay lọc `is_queued_for_deletion()`. Cùng lớp lỗi với dải chip HUD.
- **Hệ số thế cờ nén từ 1.8-3.0 xuống 1.25-1.60** (`1 + (cũ-1)×0.3`). Bảng cũ
  viết khi chúng chỉ là số trên HUD — to cho đã mắt, không ai trả giá. Điều kiện
  của MỌI thế đều rất dễ (hai Xe cùng hàng là xong) nên phần thưởng phải khiêm
  tốn. Muốn hệ số to trở lại thì SIẾT ĐIỀU KIỆN trước, không phải nâng số.
  Chúng NHÂN với nhau khi một quân nằm trong nhiều thế.
- **Cân bằng đo lại** (bot n=5, 30 ván): thắng **50%**, chênh lệch bộ bài
  **1.3×** (chặt nhất từ trước). Đường cong phải nâng theo:
  `WAVE_HP_BASE` 620→900 · `WAVE_HP_GROWTH` 1.26→1.285 · `BOSS_HP_BASE` 215→345.

*Hiệu chỉnh bảng số bằng bot (2026-08-05):*
- `tools/bot_bench.py` nay in mục **"hieu chinh bang so"**: ratio trung bình ở
  wave THUA so với wave SỐNG QUA, và một mục RIÊNG cho wave boss. Đây là cách
  duy nhất biết bảng đang nói dối hay không — cân bằng có thể đúng trong khi
  con số hiển thị vẫn sai.
- Đo được sau khi Bội thành thật: ranh giới thật của wave boss nằm ở **0.25**
  chứ không phải 1.0 ⇒ mô hình boss hụt ~4 lần. Hai nguyên nhân, sửa riêng từng
  cái thay vì bịa một hệ số:
  (1) `BOSS_ESCORT_OVERLAP` 0.8 → **0.25** — hộ vệ là lính thường, chúng chết
	  trong khoảng một phần ba đầu quãng đường chứ không sống tới cuối;
  (2) `BOSS_EXTRA_SOURCES` = **1.8** — sát thương mô hình KHÔNG nhìn thấy (phản
	  ứng nguyên tố, DoT của Dấu, splash). Boss sống lâu nên ăn đủ mọi tầng DoT.
- Sau khi sửa: tỉ lệ boss khi QUA được **1.53**, khi THUA **0.44** → 1.0 nằm
  gọn giữa. Đo lại khi đổi số hộ vệ, máu boss, hoặc sức mạnh hệ nguyên tố.

*Bot chơi trọn ván + đường cong độ khó (2026-08-04) — ĐỌC TRƯỚC KHI SỬA SỐ:*
- **`python tools/bot_bench.py [n] [bo...]`** chạy `tools/bot_run.gd` nhiều lần
  mỗi bộ bài rồi tóm tắt. Bot chơi trên GAME THẬT: mua hết những gì mua được,
  đặt vào ô phủ nhiều ô đường nhất, bấm START WAVE. Nó là **ngưỡng SÀN** —
  không dùng thuốc, không tính perk, không bán quân. Người chơi phải hơn nó.
- **Ngẫu nhiên rất lớn: n=3 có sai số ±20 điểm phần trăm.** Một lần chạy không
  kết luận được gì. Muốn chốt một hằng số thì chạy n≥5.
- Mốc hiện tại: **mọi bộ tới wave 12**, bot thắng ~35-45%, chênh lệch giữa bộ
  mạnh nhất và yếu nhất còn **2.6×** (từng là 67×).
- **Ba wave boss là bài kiểm tra, wave thường là giai đoạn dựng bàn.** Tỉ lệ
  boss lành mạnh ≈ 1.0-1.3. Máu người chơi đứng yên gần hết ván là BÌNH THƯỜNG
  ở thể loại này — sức ép nằm ở con số dưới màn hình, không ở thanh máu.
- `tools/bot_run.gd` in CSV mỗi wave: `wave,hp,vàng,quân,ratio,rd,dmg1t,hp_mất,lọt`.
  Cột `dmg1t` (sát thương lên MỘT mục tiêu) là thứ để chỉnh máu boss;
  cột `lọt=n/Xdmg BOSS_THOAT` phân biệt "thua vì rò rỉ dần" với "thua vì boss thoát".
- **BẪY khi viết bot**: (1) `tower_placer.is_buildable()` KHÔNG kiểm ô đã có
  quân — bot dồn hết vào một ô rồi ghép sao, cả ván chỉ có 1 quân; (2) **thắng
  đi qua `force_victory()` mà pha VẪN ở WAVE** (`enter_shop_phase` return ngay
  sau khi báo thắng) nên phải kiểm `gm.current_state == VICTORY`, nếu không mọi
  ván THẮNG bị đếm thành "treo"; (3) ngân sách phải tính bằng GIÂY TRONG GAME,
  headless chạy frame rỗng rất nhanh nên 150k frame có khi chỉ vài chục giây.

*Đường cong độ khó ĐƯỢC THIẾT KẾ (2026-08-04):*
- `WaveSpawner.target_wave_hp(w)` = `WAVE_HP_BASE × WAVE_HP_GROWTH^(w-1)`, wave
  boss ×`BOSS_WAVE_HP_MULT`. `get_health_multiplier` giờ là hệ số **NẮN** tổng
  máu về đường cong đó, KHÔNG còn là đường cong độ khó. Wave boss chỉ có 6 lính
  nên hệ số của nó to gấp ba wave thường — đó là đúng, đừng "sửa".
- Bản cũ để tổng máu tự nảy ra: đo được 433 581 767 1476 2452 **2221** 4524 5578
  6370 **13580** 16443 **13913** — hai wave TỤT, ba wave nhân đôi, wave cuối nhẹ
  hơn wave 11. Nguồn nhảy là (a) đổi mùa làm bể loài nhảy máu trung bình,
  (b) wave boss ít lính nên wave sau vọt lên. Cả hai vô hình với người chơi.
- **Máu Rival King có đường cong RIÊNG** (`BOSS_HP_BASE`/`BOSS_HP_GROWTH`) và
  chia cho tốc độ của chính hắn. Lý do là bất đối xứng cấu trúc: dọn cả wave thì
  thêm quân ở đâu cũng có ích, còn hạ MỘT con boss thì chỉ quân phủ đúng đường
  hắn đi mới tính ⇒ sát thương đơn-mục-tiêu tăng ~×1.25/wave còn máu wave tăng
  ×1.26 nhưng theo cách khác hẳn. Buộc chung một đường thì boss bỏ xa người chơi.
  Và ba Rival King tốc độ 9.9/13.2/11.0 nên độ khó từng do THỨ TỰ TÌNH CỜ của
  `BOSS_IDS` quyết định (wave 5 tỉ lệ 3.92, wave 9 tỉ lệ 0.84).
- **Máu Vua ×2.5** (Iron 20→50). Cũ: 20 máu / 2-5 sát thương mỗi lần lọt = cả
  ván chịu được 4-10 lần lọt ⇒ thất bại một phần không hiện ra dần mà giáng
  xuống một phát. Test batch 4 chốt: mọi Vua phải chịu ≥6 lần lọt của con nặng nhất.

*BoardScore từng nói dối ở ba chỗ (2026-08-04) — con số dưới màn hình:*
- `wave_total_hp` chỉ nắn số địch theo MỘT chiều (`real > listed`). Wave boss có
  6 hộ vệ mà bể loài liệt kê 17 dòng ⇒ ngưỡng cao gấp ~3 lần, đúng ở ba wave
  quan trọng nhất. `enemy_groups()` ngay bên dưới vốn đã nắn hai chiều.
- Mô hình **bỏ qua GIÁP**. Giáp trừ phẳng mỗi phát (sàn 1): Rival King giáp 10
  nuốt 83% sát thương của Tốt (12→2) nhưng chỉ 12% của Ballista (85→75).
  Dùng `tower_dps_vs_armor()` khi mục tiêu đã biết; `tower_dps()` chỉ cho đàn lính.
- Mô hình tính như thể **boss là mục tiêu duy nhất**. Hắn đi cùng 6 hộ vệ và
  tháp nhắm con VÀO TẦM TRƯỚC. Đo ở wave 12: bảng báo 5.17 ("hạ thừa 5 lần")
  trong khi boss đi thẳng tới King ⇒ THUA NGAY, cả wave chỉ lọt 2 con/8 sát
  thương. `_boss_focus()` = 0.17. Thêm cơ chế mới quanh boss thì phải xem lại nó.

*Van xả vàng dư — "War Levy" (2026-08-04):*
- Đo được vàng dồn 749 → 1097 → 1333 từ wave 10 khi bàn đã kín quân. Không phải
  "nhiều vàng thì vui": nghĩa là từ giữa ván MỌI quyết định trong shop đều miễn
  phí, kinh tế thôi không còn là một hệ chơi.
- Gốc: thứ đáng mua nhất về cuối (ô nguyên tố — cho BỘI, không tốn ô bàn) tính
  bằng SẮC LỆNH; hai đồng tiền không có đường nối. `ItemType.LEVY` nối chúng.
- **Chỉ bày khi vàng ≥ 2× giá.** Bày mọi lượt thì từ wave 5 quầy toàn hàng cố
  định (quân bảo đảm + bộ + ô pity + thuế + trang bị + di vật = 6 món trên
  `SHOP_SLOT_COUNT` 5) và hết sạch chỗ cho hàng ngẫu nhiên. Thêm loại hàng mới
  vào quầy thì PHẢI đếm lại chỗ này.

*Panel quân nói được VÌ SAO nó không bắn (2026-08-04):*
- `hud_tower_panel._coverage_diagnosis()`. "0 squares (0 on path)" là ngõ cụt:
  người chơi thấy số nhưng không biết nguyên nhân lẫn cách sửa. Nặng nhất là
  **Pháo** (cờ tướng) — luật "phải có ĐÚNG một quân làm ngòi" không ai đoán ra,
  mà triệu chứng lại giống hệt một quân bị hỏng. Thêm kiểu quân mới có điều kiện
  lạ thì thêm một nhánh ở đây.

*Đổi ngôn ngữ game sang TIẾNG ANH (2026-08-04):*
- **1568 chuỗi người chơi nhìn thấy → còn ~50** (phần dư là chuỗi nằm trong chú
  thích `#`, không hiện trong game). Cảnh báo `push_warning`/`push_error` (130
  chuỗi) GIỮ tiếng Việt — chúng chỉ ra console cho lập trình viên.
- **Làm bằng công cụ, không sửa tay**: `tools/i18n_scan.py` (đo) ·
  `i18n_split.py` (tách người-chơi / dev) · `i18n_apply.py` (áp bảng dịch) ·
  `i18n_final.py` (regex cho chuỗi có ký tự PUA đứng đầu).
  Bảng dịch ở `tools/i18n_map_{1..12}.py`, mỗi bảng một nhóm nội dung.
  Sửa tay 1175 chuỗi duy nhất rải ở 28 thư mục thì chắc chắn bỏ sót.
- **`i18n_apply.py` thay chuỗi DÀI trước chuỗi NGẮN** — nếu không, một chuỗi
  ngắn là con của chuỗi dài sẽ ăn mất một đoạn và phần còn lại thành rác.
- **BẪY: chuỗi bắt đầu bằng ký hiệu PUA** (glyph tự vẽ ``…) không khớp
  được khi gõ bằng phím thường ⇒ `i18n_apply` báo "không tìm thấy". Phải thay
  bằng regex trên phần SAU của chuỗi. Khoảng 50 chuỗi rơi vào lớp này.
- **Tên riêng dịch theo NGUỒN GỐC**, không dịch nghĩa: Hương Xa → *Lance*,
  Kim Tướng → *Gold General*, Tượng Điền → *Xiangqi Elephant*. Người chơi tra
  Google ra đúng quân cờ đó.
- Thế cờ ưu tiên thuật ngữ cờ vua CÓ THẬT: Trận Pháo → *Battery*, Giao Hoả →
  *Crossfire*, Tường Tốt → *Pawn Wall*, Nước Chĩa → *Fork*.
- Font pixel tự vẽ đã có đủ ASCII nên tiếng Anh chạy ngay, không phải dựng lại.
- **Test kiểm tutorial phải đổi từ khoá theo**: batch 9 và 12 tìm chuỗi tiếng
  Việt trong `tutorial_overlay.gd` — sau khi dịch thì phải tìm "rook"/"bishop"/
  "formation"/"your set" thay vì "xe"/"tượng"/"thế"/"bộ".

*Bảy sửa theo phản hồi chơi thử (2026-08-02):*
- **Pha chuẩn bị KHÔNG còn đếm ngược.** `PhaseController.request_start_wave()` là
  đường DUY NHẤT vào wave; `_tick_prepare` nay rỗng. Đồng hồ 30 giây cũ vừa sinh
  lỗi tranh chấp lúc đặt tháp đúng lúc hết giờ, vừa biến quyết định bố trí thành
  cuộc đua bấm nhanh. Nút "⚔ BẮT ĐẦU WAVE" ở đáy màn, bật/tắt qua signal
  `prep_ready_changed`. `_start_wave_phase()` phát `false` ở MỌI đường vào wave.
- **Nâng sao bằng vàng đã GỠ** (`star_up_cost` / `try_star_up_with_gold` không
  còn tồn tại). Sao chỉ lên bằng ghép quân trùng. Test kiểm NGƯỢC: hai API đó
  phải không còn `has_method`, còn đường ghép quân vẫn phải lên ★2 → ★3.
- **Kinh tế siết theo SỐ ĐO, không phải cảm giác.** Bot tiêu sạch vàng qua 15
  wave: bản cũ tồn **5894 vàng** ở wave 15 và HP đứng yên 20 suốt 14 wave rồi
  rơi thẳng. Nay đỉnh **790**, HP bắt đầu tụt từ wave 10.
  Ba đòn bẩy: `STARTING_GOLD` 100→60 · `gold_reward` ×0.40 toàn bảng (boss giữ
  nguyên — đó là thưởng mốc, không phải thu nhập đều) · `DEFAULT_INTEREST_CAP`
  15→6. Quân khởi đầu: Vua Thép 8 Tốt → 4, mọi vua ≤ 5 quân.
  **Lãi cuối wave trả tiền cho việc KHÔNG tiêu** — nó chính là nguồn dồn vàng.
- **Ô nguyên tố Lv2/Lv3 vốn CÓ tác dụng** (đo được: sát thương 16→18, Dấu +4s,
  phản ứng ×1.0→×1.6). Lỗi là ở HIỂN THỊ: `tower_damage_pct` chưa từng được in
  ra, và ba dòng thưởng chỉ hiện khi > ngưỡng nên ô Lv1 trông y hệt ô thường.
  Nay LUÔN in cả ba, kèm dòng **xem trước cấp kế tiếp** — không có nó thì phần
  thưởng chỉ lộ ra SAU khi đã tiêu tài nguyên, nên không ai có lý do chồng ô.
- **Mọi ô đều click xem được.** Ô Phước/Nguyền sinh lúc tạo map nằm ở
  `grid_controller.special_tiles`, KHÔNG phải `territory_manager.biome_tiles`,
  nên trước đây rơi vào nhánh `else` và click không hiện gì — trong khi chúng có
  rune riêng trên bàn nên trông y như ô bấm được. `game_map._describe_cell()`
  dựng dữ liệu, `hud.show_cell_info()` dựng panel (ô trống · đường đi · Phước ·
  Nguyền, luôn kèm vùng biome + toạ độ).
- **Panel quân thêm mục "Đang hưởng"**: đọc THẲNG `_dmg_bonus`/`_spd_bonus`/
  `_rng_bonus` của tháp rồi liệt kê từng lớp buff bằng tên tiếng Việt, cộng dòng
  sao (phép NHÂN, áp sau cùng), DPS ước tính và tổng sát thương đã gây. Đọc
  trạng thái thật nên không bao giờ lệch với chỉ số hiển thị.
- **14 nâng cấp meta** thay cho 3, chia 5 trục: Kinh tế · Sinh tồn · Sắc Lệnh ·
  Nguyên tố · Đội hình. **Mỗi `id` trong `META_UPGRADES` PHẢI có nhánh trong
  `GameManager.start_run()`** — thiếu nhánh thì nâng cấp vẫn mua được, vẫn hiện
  cấp, nhưng không làm gì. Test batch 5 mua từng cái một rồi so 14 field
  trước/sau, cái nào không làm đổi field nào là LỖI.
  Ba field mới `meta_tower_damage_pct` / `meta_tower_speed_pct` /
  `meta_bonus_territories` phải reset về 0 TRƯỚC khi cộng lại, nếu không ván thứ
  hai trong cùng phiên cộng dồn gấp đôi.
- Màn Tiến Trình cũng QUÉT `res/kings/` thay cho mảng cứng.
- Tên quân tiếng Việt qua `UIStyle.UNIT_NAMES_VI` ở CẢ ba chỗ (panel thông tin,
  kho triển khai, thẻ shop) — trước đây ba chỗ gọi tên khác nhau.

*Chữ ba cỡ + 6 Rival King (2026-08-02):*
- **`font_size` từng bị BỎ QUA hoàn toàn.** Đo được: cỡ 10 và cỡ 42 render ra y
  hệt 112 pixel. Font bitmap không khai `fixed_size` thì Godot lờ `font_size` —
  cả game một cỡ chữ, phân cấp tiêu đề/thân bài mất sạch từ lúc đổi sang font
  pixel tự vẽ. Không ai thấy vì chữ vẫn hiện bình thường.
- Hai cách sửa **đã thử và bỏ**: (1) `fixed_size` + để Godot tự phóng → chữ nhoè,
  đo được 11 màu ở cỡ 28 thay vì 1; (2) nhồi cache 28/42 vào cùng một FontFile
  bằng `set_glyph_*` → vẽ ra sắc nét thật nhưng `get_string_size()` trả rác,
  **mọi ký tự đều báo advance 18, kể cả `a`** ⇒ mọi bố cục tính theo bề rộng chữ
  đều lệch mà không báo lỗi.
- **Cách đang dùng**: `make_font.py` sinh thêm atlas `@2x`/`@3x` bằng cách NHÂN
  toạ độ (không nội suy); mỗi bản nạp qua `load_bitmap_font` thành một FontFile
  riêng → `pixel_font{,_2x,_3x}.tres`. `UIStyle.font_for(size)` chọn FONT theo
  cỡ, `snap_font_size()` nắn về **14 / 28 / 42**. Chỉ đặt `font_size` là KHÔNG
  đủ — phải đặt cả `font`.
- Đo lại sau khi sửa: 1 màu ở cả ba cỡ, advance 6/12/18, cao 14/28/42.
  `check_art.py` giờ quét cả `.fnt` — nếu không nó báo ba atlas font là "không
  ai tham chiếu", đúng lớp bẫy từng làm chết 45 model.
- **Cỡ trung gian tự nắn xuống**: 15..19 đều thành 14. Nghĩa là mọi chỗ trước
  đây viết `body(lbl, 17)` để "hơi to hơn" nay bằng hệt `body(lbl, 14)` — muốn
  to thật thì phải viết 28.
- **Dải wave đè lên số Sắc Lệnh**: panel tài nguyên không nằm trong container
  nên nở theo nội dung rộng nhất (dải chip kéo ra 869px), trong khi dải wave neo
  theo hằng `RESOURCE_PANEL_WIDTH`. Nhìn ra như "chữ bị cắt", thực ra bị che.
  Nay kẹp `RESOURCE_PANEL_MAX_WIDTH` rồi neo theo `size.x` THẬT, gọi lại mỗi lần
  dải chip đổi.
- **6 King** (thêm `king_storm` · `king_frost` · `king_merchant`). Ba vua gốc đều
  quy Sắc Lệnh thành sát thương nên Sắc Lệnh chỉ có một công dụng; ba vua mới mở
  trục nguyên tố (gắn Dấu Lôi toàn bàn), trục phòng thủ (chậm 80% + Dấu Băng) và
  trục kinh tế (vàng theo wave + reset giá xáo).
- Màn chọn vua **QUÉT `res/kings/`** thay cho mảng cứng → thêm vua = thả một
  `.tres`. `ShopPanelManager` vào group `"shop_managers"` để ability với tới được
  (ctx chỉ đưa SceneTree, đi đường vòng qua tên node là gãy khi cây scene đổi).
- **Chân dung 6 vua vẽ bằng Aseprite** (`assets/ui/kings/<id>.png`, 64×64, 8–12
  màu). Trước đó cả 6 vua render CÙNG model `king.gltf` — thêm vua mới vô nghĩa
  về mặt hình ảnh. Test có assert **mỗi vua một ảnh riêng, trùng nhau là lỗi**.
- Bài học vẽ ở 64px (phải vẽ lại storm/frost hai lần): các đoạn zigzag vẽ bằng
  `rect` CHỒNG nhau thì gộp thành một cục — tia sét phải để từng đoạn rời hẳn.
  Và **đọc ra hay không là do CHÊNH SÁNG TỐI**, không phải do thêm chi tiết: mặt
  và râu Vua Băng Hà cùng tông nhạt thì cả chân dung chỉ là một khối trắng.

*Save meta chống hỏng (2026-07-29) — lỗi CHẶN PHÁT HÀNH đã sửa:*
- `MetaProgress.load_or_create()` từng là `return load(SAVE_PATH) as MetaProgress`.
  File hỏng → `load()` null → cast null → `GameManager.meta_progress` đứng NULL
  VĨNH VIỄN. Không crash (mọi nơi có guard) nên KHÔNG AI BIẾT, nhưng tiến trình
  meta chết câm và không bao giờ tự phục hồi. Mất điện lúc ghi save là đủ.
- Nay: luôn trả về MetaProgress dùng được; file hỏng đổi tên sang
  `meta_progress.corrupt.tres` (không xoá — còn mẫu để truy nguyên).
- `save()` ghi file TẠM rồi rename đè. **Tên tạm PHẢI giữ đuôi `.tres`**:
  ResourceSaver suy định dạng từ phần mở rộng, `.tres.tmp` trả lỗi 15
  (ERR_FILE_UNRECOGNIZED). Đã dính.
- Test batch 5 phủ 3 dạng hỏng: rác · rỗng · resource sai kiểu.

*Đánh giá phát hành — xem docs/RELEASE_READINESS.md (2026-07-29):*
- Bot chơi ngẫu nhiên (mua 3 tháp/wave, đặt bừa) vẫn THẮNG wave 10 với 17/45 HP
  và tồn 2095 vàng ⇒ độ khó thấp + kinh tế thiếu chỗ tiêu cuối ván.
- Chưa từng export (`export_presets.cfg` không tồn tại) → chưa biết bản build ra sao.
- Không có tutorial. Bất biến "nguyên tố đến từ Ô" không ai tự đoán ra được.
- `MAX_WAVES = 10`, một boss duy nhất — GDD hứa nhiều Rival King.

*Mũi tên chỉ hướng đường đi (2026-07-28):*
- `scripts/map/path_arrows.gd` (`PathArrows`) rải chevron vàng dọc `current_path_grid`,
  mỗi mũi tên xoay về ô kế tiếp. MultiMesh → cả đường 100+ ô vẫn MỘT draw call.
- **Không nhét vào MapOverlayDrawer**: drawer đó `free()` toàn bộ con mỗi khi state
  key đổi, mà key có cả ô đang hover → rebuild liên tục lúc rê chuột. Đường đi chỉ
  đổi vài lần mỗi ván nên tách riêng.
- Cao độ `ARROW_Y = 0.07` — trên overlay quad (0.06) và mesh ô lãnh thổ (0.052).
  `no_depth_test` vì ô đường có vệt bánh xe dày lên sẽ cắt mất mũi tên.
- Phải `rebuild()` ở CẢ `map_chunk_created`, `map_expanded` và `map_rebased` —
  mũi tên đặt theo toạ độ thế giới nên rebase là lệch hết.

*Khảo sát hình ảnh (2026-07-28) — xem docs/ART_STATUS.md:*
- **Không có font nào được đóng gói.** `ThemeDB.fallback_font` = Open Sans SemiBold,
  `has_char()` trả FALSE cho cả 35 ký hiệu đang dùng (★ ⚔ ✓ ♥ ⚡ 🌍 …). Nhưng render
  ra ảnh rồi đếm pixel thì chúng VẪN HIỆN — Godot fallback sang font hệ thống
  Windows. Nghĩa là export sang máy khác sẽ thành ô tofu. `has_char()` KHÔNG phải
  bằng chứng đủ; phải render rồi đếm pixel (tofu chuẩn U+E000 = 855px ở cỡ 48).
- **Thước đo art thật vs programmer art: SỐ MÀU.** Pixel art vẽ tay 5–15 màu;
  ảnh sinh bằng script jitter từng pixel ra 48–142 màu cùng kích thước. Khoảng
  trống giữa hai nhóm rất rộng (14 vs 48) nên ngưỡng 40 tách sạch.
  `python tools/check_art.py` quét toàn bộ.
- Đang là programmer art: **32 texture địa hình** (48–142 màu — chiếm phần lớn
  diện tích màn hình) và **11 panel/nút UI** (48–127 màu).
- Hoàn toàn do code, KHÔNG có file ảnh: viên đạn (`BoxMesh`), nền menu (2 ColorRect
  phẳng), mọi mesh bàn cờ/overlay/vòng nguyên tố, số sát thương (`Label3D`).
- Mọi màn UI trừ HUD dựng 100% bằng code — file `.tscn` chỉ có 1 node gốc. Sửa bố
  cục menu là sửa code, mở editor kéo thả không thấy gì.
- Đã dọn **316 file asset chết**, còn trong git history (`2aaf152`).
- **KHÔNG BAO GIỜ xoá `assets/models/<id>_N.png`.** Trông như rác export
  Blockbench (mọi `.gltf` nhúng texture base64, không file nào trỏ texture ngoài)
  nhưng Godot khi import glTF **trích xuất** texture nhúng ra chính các PNG đó, và
  `.godot/imported/*.scn` phụ thuộc vào chúng. Xoá → **cả 45 model chết**, mà
  `--import` VẪN BÁO SẠCH vì phụ thuộc chỉ kiểm lúc LOAD. Đã dính và phải khôi phục.
- **Trước khi xoá asset phải GREP tham chiếu, không chỉ so tên với id.**
  `Tower.png`/`Wisp.png`/`horse.png` không khớp id nào nhưng `rook`/`ice_guardian`/
  `knight` .tres dùng làm `texture`. Shop `if stats:` nuốt lỗi nên test vẫn xanh.
- `check_content.py` giờ kiểm mọi `path="res://…"` trong `.tres`/`.tscn` phải tồn
  tại; `run_tests.py` đếm cả `ERROR: Failed loading resource` (trước chỉ đếm
  `SCRIPT ERROR`, nên lớp lỗi này lọt lưới).
- **BẪY: tên file lệch hoa–thường.** `Pawn.png` / `Orc.png` trong khi id là
  `pawn` / `orc`. Windows không phân biệt hoa thường nên chạy tốt, export Linux
  là hỏng. `check_art.py` giờ bắt lớp lỗi này.
- `check_art.py` cũng liệt kê ảnh không ai tham chiếu — quét CẢ `.gltf`, và loại
  trừ `assets/textures/terrain` vì nó nạp bằng chuỗi ghép qua `BiomeLibrary.tex_path()`
  nên tìm theo tên file sẽ báo nhầm 25 file đang sống.

*Đường hiển thị của nội dung (2026-07-28) — ĐỌC TRƯỚC KHI THÊM LOẠI HÀNG MỚI:*
- **Tên file ảnh = `id`**, code ghép chuỗi `thư_mục % id`, KHÔNG có bảng ánh xạ.
  `HudIcons` là điểm nạp duy nhất: `potion/relic/equipment/perk/tower/enemy`.
- Đã vá 3 lỗ thật: card shop **trang bị và di vật chưa bao giờ có icon** (32 file
  icon nằm sẵn trên đĩa mà `_make_equipment_offer`/`_make_relic_offer` không gán
  `item.icon`); **perk không đọc được PNG** (chỉ ModelIcon hoặc glyph); **quân cờ
  không gán `texture` trong .tres thì card shop trống trơn** — nay tự thử
  `assets/towers/<id>.png` ở giữa.
- Thứ tự dự phòng card shop quân cờ: `stats.texture` → `assets/towers/<id>.png`
  → `stats.projectile_texture`. Bước giữa là lý do KHÔNG cần mở editor gán texture.
- Card perk: PNG 48×48 → ModelIcon (nếu perk có `unit_id`) → ký hiệu `icon` → ◆.
- `check_content.py` giờ đọc header PNG (không cần thư viện) để kiểm kích thước,
  và **báo LỖI khi một quân cờ không có ảnh nào cả**.
- `tools/new_content.py <loại> <id>` sinh khung .tres/JSON rồi in danh sách ảnh
  cần vẽ kèm cỡ. `--list` liệt kê mọi id đã dùng (gồm cả món built-in trong .gd).

*Tách game_map.gd (2026-07-28): 1557 → 1094 dòng*
- `scripts/map/potion_controller.gd` (367) — vòng ngắm 3D, wiring HUD, nguồn rơi thuốc,
  hồi máu Vua, khiên chặn một đòn. Hằng số `POTION_*` chuyển theo luôn.
- `scripts/map/boss_controller.gd` (189) — thanh máu boss, đổi pha, thưởng hạ boss.
- Cùng khuôn với component HUD: `extends Node`, gắn bằng `X.attach(game_map)`, giữ
  `var map: Node3D`. game_map giữ NGUYÊN tên hàm công khai (`potion_heal_king`,
  `_on_boss_spawned`…) dưới dạng uỷ quyền → PotionSystem/WaveSpawner/HUD không đổi.
- **Signal phải connect vào CONTROLLER, không phải game_map**: `bag_changed`,
  `relics_changed`, `potion_aim_requested/cancelled` nay trỏ thẳng
  `potion_controller._on_*`. Quên chỗ này thì parse vẫn sạch mà tính năng chết.

*Bộ test chức năng — `python tools/run_tests.py` (2026-07-28):*
- **`run_tests.py` đếm mọi dòng `SCRIPT ERROR:` trong log là LỖI.** Bài học từ chính
  đợt tách này: đổi lời gọi thành `potion_controller.tick(delta)` nhưng hàm vẫn tên
  `_tick_potion_systems` → lỗi runtime MỖI FRAME, parse không bắt được (call động),
  và mọi khẳng định vẫn xanh. Không soi log thì bug đó trôi thẳng vào build.
- **Bẫy test thứ tư**: đường mở rộng được phép ĐÈ LÊN ô lãnh thổ (signal
  `territory_overwritten_on_expand` dọn mesh + hoàn kho). Assert "ô còn nguyên sau
  rebase" mà không tính nhánh này thì flaky theo hướng mở rộng ngẫu nhiên.
- 6 batch trong `tests/`, **176 khẳng định**, chạy TRÊN GAME THẬT (dựng game_map, đặt tháp,
  mua đồ, nổ phản ứng) chứ không mock: `test_1_core_loop` (đặt/ghép ★/sa thải/shop/ô) ·
  `test_2_elements` (Dấu, 10 phản ứng, khắc-kháng, cấp ô, hình thế, synergy) ·
  `test_3_items` (thuốc/trang bị/di vật) · `test_4_waves_map` (wave, boss, ascension,
  mở rộng + rebase) · `test_5_meta_ui` (perk, King, encounter, meta-save, 8 màn UI) ·
  `test_6_combat_economy` (buff stacking 13 lớp, sao là phép NHÂN, trần tầm/sàn hồi
  chiêu, giáp phẳng, máy trạng thái pha, kinh tế, hai controller vừa tách).
- Chạy `python tools/run_tests.py` (hoặc `... 2 4` để chọn batch). Batch 4 lâu nhất
  (DFS mở rộng trên bàn 24×24) nên timeout đặt 420s.
- Không dùng framework test: game cần SceneTree THẬT (Node3D, tween, autoload) —
  `godot --script res://tests/...` là cách rẻ nhất để có đúng môi trường đó.
- **Chạy lặp lại vài lần**: hướng mở rộng bản đồ và nội dung quầy shop là ngẫu nhiên,
  test chỉ chạy một lần thì bỏ lọt lỗi phụ thuộc may rủi (đã bắt được 2 lỗi kiểu này).
- Thỉnh thoảng một batch **không khởi động được** giữa chuỗi 7 lần chạy Godot liên
  tiếp (cho ra 0 khẳng định, không phải chết giữa chừng — chạy riêng batch đó 9 lần
  đều sạch). Runner thử lại MỘT lần và in `! batch khong khoi dong duoc` để flaky
  vẫn nhìn thấy được. Nếu lần thứ hai cũng hỏng thì đó là lỗi thật.

*Ba cái bẫy khi VIẾT test cho dự án này (2026-07-28):*
- **Lambda GDScript bắt biến local theo GIÁ TRỊ.** `var got := ""` rồi
  `sig.connect(func(x): got = x)` thì `got` NGOÀI lambda không bao giờ đổi — test sẽ báo
  "signal không bắn" trong khi nó bắn đúng. Dùng `Array`/`Dictionary` (object, bắt theo
  tham chiếu) hoặc biến THÀNH VIÊN.
- **`grid_data` chứa lẫn `Node` và `String`** (marker ô đặc biệt) → so sánh thẳng
  `grid_data[c] == tower` ném lỗi kiểu. Lọc `if v is Node` trước.
- Đọc `gm.current_wave` TRƯỚC wave đầu ra 0, nên `EncounterManager._get_available_encounters()`
  trả rỗng — không phải lỗi, encounter chỉ trigger từ wave 3 (lúc đó 15-16/18 khả dụng).

*Công cụ kiểm đấu nối — `python tools/audit_wiring.py` (2026-07-27):*
- Lớp lỗi hay gặp nhất ở dự án này KHÔNG phải crash mà là **tính năng chết âm thầm**: khoá dữ
  liệu / field / signal được khai và GHI ra nhưng không ai ĐỌC. Game vẫn chạy, test vẫn xanh,
  món đồ đó chẳng làm gì. Đã dính: thưởng hình thế · `reaction_mult` cấp ô · `projectile_bonus`
  của thuốc · `rotate_marks` của Trận Vòng · `relic_tile_merge_anywhere`.
- Script quét 7 nhóm: signal không người nghe · field GameManager ghi mà không đọc · khoá
  EFFECT_KEYS không tiêu thụ · thưởng hình thế chết · chuỗi `%%` sai · card thiếu
  `make_click_target` · chỗ nhắm tháp còn dùng `GridUtil` thay vì `PickUtil`.
- **Chạy sau mỗi lần thêm cơ chế mới.** Kết quả là NGHI VẤN, không phải kết luận — nhiều chỗ
  đọc field qua chuỗi (`gm.get("x")`, `_perk_float("x")`), phải soi tay xác nhận.

*Chọn mục tiêu bằng chuột — HAI bẫy đã sửa (2026-07-27):*
- **3D**: `GridUtil.mouse_to_cell` cắt ray với mặt phẳng y=0. Camera nghiêng −50°, model tháp
  cao ~1.2 m ⇒ THÂN tháp trên màn hình lệch khỏi ô của nó ~1.2/tan(50°) ≈ **trọn một ô**;
  click vào thân trúng ô phía sau. Nay mỗi tháp mang `PickArea` (Area3D, hộp 1×1.5×1,
  `collision_layer = 8` = layer "Pick"), và **`PickUtil.mouse_to_cell` thay cho
  `GridUtil.mouse_to_cell` ở MỌI chỗ nhắm vào tháp**: game_map click chính, overcharge,
  hover của overlay drawer, preview của tower_placer. Trượt raycast thì tự rơi về ray-plane
  nên ô trống vẫn chọn bình thường.
  → Thêm chỗ nhắm tháp mới thì dùng `PickUtil`, đừng dùng `GridUtil`.
- **UI**: mọi `Control` mặc định `MOUSE_FILTER_STOP`, nên PanelContainer/TextureRect bên trong
  một card NUỐT click trước khi tới `card.gui_input` — chỉ dải viền mỏng bấm được.
  `UIStyle.make_click_target(card)` đặt toàn bộ Control con thành IGNORE (chừa BaseButton /
  Range / LineEdit / TextEdit / ScrollContainer). **Gọi nó sau khi dựng xong mọi card có
  `gui_input`** — hiện có 7 chỗ: shop item, tower button, territory, dismiss, meta shop,
  perk card, ô túi thuốc.

*Sách Nguyên Tố — codex (phím F1, từ 2026-07-27):*
- `game_hud.toggle_codex()` / `_build_codex()`. Overlay `PROCESS_MODE_ALWAYS` nên tra cứu được
  khi pause. F1 và ESC đều đóng (ESC được kiểm TRƯỚC nhánh menu tạm dừng).
- Nội dung sinh từ NGUỒN SỰ THẬT: `ElementTypes.SPEC`, `ReactionTable.TABLE` + các hằng
  (`MELT_ARMOR_SHRED`, `CONDUCT_MAX_TARGETS`…), `FormationDetector.ALL_IDS/INFO`,
  `TerritoryManager.LEVEL_BONUS`. Thêm phản ứng mới chỉ cần thêm một nhánh mô tả trong
  `_codex_reaction_desc` — phần còn lại tự có.
- **Bẫy**: chuỗi KHÔNG đi qua toán tử `%` thì viết một dấu `%`, không phải `%%`
  (đã dính lỗi này ở mô tả Bốc Hơi).

*Vật phẩm (từ 2026-07-26):*
- **Thuốc** `scripts/items/potion_system.gd` + `data/potions/core.json` — túi 3 ô, ném theo vùng,
  dùng được GIỮA TRẬN. Phím **Z/X/C** (KHÔNG phải Q/W/E: `camera_controller` poll thẳng
  `Input.is_key_pressed(KEY_W)` nên `set_input_as_handled()` không chặn được).
- **Trang bị** `scripts/items/equipment_system.gd` + `data/equipment/*.json` — 20 món, 2 ô/tháp
  (di vật "Đe Của Thần" → 3). Gộp mọi món thành MỘT dict rồi mới gọi `tower.apply_equipment_buff()`:
  tháp chỉ có một `BuffLayer.EQUIP`, gọi hai lần thì món sau ghi đè món trước.
  `tower_placer.dismiss_at` gọi `release_tower()` TRƯỚC `queue_free` (sau đó instance_id chết).
- **Di vật** `scripts/items/relic_system.gd` + `data/relics/*.json` — 12 món, 5 ô, cả run.
  Không giữ buff riêng: `_apply_all()` tính lại từ đầu rồi GHI ĐÈ vào `GameManager.relic_*`,
  `EquipmentSystem.slots_per_tower`, `PotionSystem.max_slots/radius_override/duration_bonus`.
  Bán một món là giá trị tự về mặc định — không cần undo riêng.
- Cả hai bán trong shop qua `ShopItemData.ItemType.EQUIPMENT` / `RELIC` (offer sinh động mỗi lần
  roll). Shop tiêu Royal Decree, catalog ghi giá VÀNG → quy đổi bằng `EQUIP_GOLD_PER_RD`/`RELIC_GOLD_PER_RD`.
- UI: ô trang bị nằm trong `game_hud.show_tower_info` (kèm dòng "Nguyên tố");
  thanh di vật 5 ô góc trên-phải (`_build_relic_bar`, bấm để bán).

*Mechanics mới (đợt 3, 2026-07-24):*
- **Crit**: GameManager.crit_chance 5% ×2.0, roll trong projectile.hit_target
- **Elite**: wave≥3, 10% — enemy.make_elite() ×3 HP, ×2.5 gold, scale 1.35, tint vàng
- **Ô Phước/Nguyền**: grid_controller.special_tiles (2 phước + 1 nguyền/region 8 hàng), tower buff qua BuffLayer.TILE (+20%/-15%), chết trên ô nguyền +2 vàng
- **Overcharge**: right-click tower ngoài mọi mode, 30 vàng → cooldown ×0.5 trong 5s (tower.overcharge())
- **Kill combo**: GameManager.register_kill(), cửa sổ 2.5s, gold mult 1.1/1.25/1.5 tại 5/10/20 kills
- **Damage numbers**: FX.damage_number (Label3D, cap 60), FX.spawn_click_ring (click magic)
- **Content authoring**: docs/CONTENT_AUTHORING.md — perk = JSON, quân/địch = copy .tres template (res/towers/_template_tower.txt, res/enemy/_template_enemy.txt), model = assets/models/<id>.gltf

*Tower/Unit (cố định, auto-attack):*
- 15 loại unit: Pawn, Knight, Rook, Bishop, Queen, Commander, Crossbowman, Catapult, Warlock, Dark Mage, Longbowman, Paladin, Alchemist, Ice Guardian, Ballista
- Stats: base_damage, attack_speed, attack_range, cost, decree_cost
- Buff stacking 6 lớp: Base → Upgrade → Biome → King's Favor → Crown's Boon → Synergy
- Drag-and-drop placement, dismiss 50% refund
- Multishot (`projectile_count`), slow, splash, burn effects

*Enemy:*
- 10 loại: Orc, Goblin, Skeleton, Dark Knight, Demon Imp, Troll (regen 8HP/s), Wraith (90px/s), Shaman (heal aura), Golem (armor 6), Bat (swarm)
- Scale per wave: +12% HP, +3% speed
- Debuff: Slow, Burn (DoT); cơ chế đặc biệt: armor (flat reduction, min 1), regen, heal aura — fields trong EnemyStats

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
- ~~King Ability execution~~ ĐÃ XONG: `KingAbilityExecutor` (scripts/map/king_ability_executor.gd)
  chạy `KingStats.ability_script` (data-driven), thiếu/hỏng script mới rơi về nhánh hardcoded
  theo `king_id`. Luồng: `king_manager.use_ability()` → signal `ability_activated` →
  `game_map._on_king_ability_activated` → `executor.execute()` → signal `ability_executed`.
  **KHÔNG còn `game_map.execute_king_ability()`.**
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
