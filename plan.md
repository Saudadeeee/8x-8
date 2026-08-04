# Plan hoàn thiện 8x-8 (3D) — 2026-07-24

## J. Boss + chiều sâu build + QoL (đợt 7) — HOÀN THÀNH
- [x] **Boss Rival King** ở wave 10: `BossEnemy extends Enemy` (KHÔNG sửa enemy.gd), 3 pha theo %máu
      (mỗi pha +12% tốc, giáp mỏng dần, cooldown kỹ năng ngắn lại), chặn 1 đòn > 25% máu tối đa
      - Vua Hoang Dã 1400HP — triệu hồi 3 quái mỗi 8s
      - Vua Địa Ngục 1200HP — vô hiệu hoá tháp trong 2.5m suốt 3s mỗi 6s
      - Vua Băng Giá 1600HP, giáp 10 — tháp trong 3m +0.25s hồi chiêu, boss tự hồi 3% máu
      - 3 model Blockbench mới, cao 2.1–2.25m
- [x] **Điều kiện thắng mới**: wave 10 chỉ thắng khi HẠ được boss; hết quái thường không đủ
- [x] Boss chạm King = **THUA NGAY** (sửa hành vi cũ: agent để boss thoát vẫn tính thắng)
- [x] **Hợp nhất tháp ★**: đặt tháp lên ô cùng loại → ★2 (×1.8 dmg) → ★3 (×3.2 dmg, +1 tầm);
      sao là phép NHÂN tách khỏi buff layer nên không bị nhân chồng; ghost vàng báo ô merge được;
      hoàn tiền khi bán scale theo sao (tôi sửa: trước đó bán ★3 chỉ hoàn 1 quân)
- [x] **Ưu tiên mục tiêu** 4 chế độ (đầu hàng / khoẻ nhất / gần nhất / yếu nhất)
- [x] **Tốc độ game 1×/2×/3× + pause** (`tree.paused`, không set time_scale=0), phím Space/1/2/3,
      HUD `PROCESS_MODE_ALWAYS` nên bấm được lúc dừng
- [x] **Ascension 5 bậc** mở dần sau mỗi lần thắng (máu +15%/bậc, tốc +4%, vàng đầu −10, thưởng meta +25%),
      chọn ở màn King. Tôi nối tiếp vào wave_spawner (agent chỉ expose hàm, chưa ai đọc)
- [x] **Bảng đóng góp sát thương** top 5 tháp ở màn thắng/thua + combo cao nhất + bậc Ascension
- [x] Dọn nợ kỹ thuật: gỡ `_unhandled_input` cầu tạm trong tower_placer, nới gate trong game_map
      → chỉ còn MỘT luồng xử lý click
- [x] Kiểm: boss spawn/3 pha/thắng-thua đúng · merge ★1→★2 dmg 31 · Ascension A2 áp thật
      (máu ×1.30, vàng đầu 330) · regression 10 wave **FAIL=0**, 0 lỗi script

## I. Hệ BIOME đa môi trường (đợt 6) — HOÀN THÀNH
- [x] 5 môi trường: **Hoang Mạc / Băng Nguyên / Hoả Diệm / Đầm Lầy / Rừng Thẳm**
- [x] 25 texture địa hình sinh thủ tục (5 biome × light/dark/road/cliff_side/cliff_top),
      mỗi biome giữ tương phản sáng-tối để checkerboard vẫn đọc được
- [x] 9 prop 3D mới: ice_spike, frozen_tree, snow_rock, lava_rock, obelisk, charred_stump,
      reed, mushroom, jungle_tree (kho prop: 15)
- [x] `BiomeLibrary` (scripts/map/biome_library.gd) — spec màu/prop/ánh sáng/sương/mod cho từng biome
- [x] **Biome theo VÙNG**: `cell_biome` per ô; chunk đầu random 1 biome, MỖI lần mở rộng vùng mới
      nhận biome khác → bản đồ chắp vá nhiều khí hậu. Rebase dịch `cell_biome` như mọi state khác
- [x] Chuyển cảnh mượt: tween 1.2s ánh sáng/sương/nền khi Vua bước sang vùng khí hậu mới
      (Environment được duplicate để không ghi đè .tscn gốc)
- [x] `BiomeEffects` (scripts/map/biome_effects.gd) — mod gameplay qua `BuffLayer.BIOME_CLIMATE` riêng:
      Băng Nguyên (địch −15% tốc, tháp +0.08s hồi chiêu) · Hoả Diệm (+10% dmg, cháy ×1.5, địch +8% tốc)
      · Đầm Lầy (địch −20% tốc, tháp −8% dmg) · Rừng Thẳm (+1 vàng/kill, địch +8% máu)
      Mod THAY THẾ chứ không cộng dồn; áp cả cho tháp đặt sau
- [x] HUD: banner khi vào vùng mới + chỉ báo "🌍 &lt;tên vùng&gt;" + tooltip mod + dòng biome trong Trinh Sát
- [x] Sửa sương quá dày ở tundra/volcanic/swamp (0.022–0.026 → 0.011–0.013) làm mất hình bàn cờ
- [x] Kiểm: mọi ô đều có biome qua 4 lần mở rộng (FAIL=0); regression 10 wave đủ hệ
      (lãnh thổ + perk + encounter + expand) **FAIL=0**, gặp 3 biome trong 1 run

## G. UI 3D + Map mở rộng 4 hướng (đợt 5) — HOÀN THÀNH
- [x] 11 texture UI 9-patch sinh thủ tục: panel đá/gỗ (có đinh tán)/da thuộc/tối,
      nút vát 3D (pressed đảo chiều vát), khung vàng rỗng, bar lõm + fill gradient
- [x] `UIStyle` (scripts/ui/ui_style.gd): tập trung StyleBox + animation
      (pop_in stagger, slide_in, pulse, breathe, shake, hover_lift, count_to, flash)
- [x] `ModelIcon` (scripts/ui/model_icon.gd): SubViewport render **model 3D xoay** làm icon
      — shop card 46px, tower info 112px, king select 150px; auto-fit AABB; cap 8 icon sống
- [x] Áp style mới cho 8 màn: HUD, main_menu, king_select, victory, game_over, settings,
      meta_progression, encounter; HP/RD có ProgressBar lõm tween mượt
- [x] **Map mở rộng 4 hướng** (NORTH/SOUTH/WEST/EAST) bằng **rebase toạ độ** (mở về tây/bắc
      thì dịch toàn bộ dữ liệu +8 → ô luôn ≥ 0, các file khác không cần sửa bounds)
- [x] Chọn hướng có tính toán: điểm = khoảng cách King tới biên + phạt hướng vừa dùng
      (REPEAT_DIR_PENALTY = 7) → mở đa hướng thật, đường mới luôn ngắn và nối được
- [x] Đích DFS = biên ngoài vùng mới → King vào sâu lãnh thổ mới, spawn giữ nguyên,
      đoạn mới không cắt/dán sát đường cũ; tháp bị đè được hoàn 50% + gỡ synergy
- [x] Generator giữ **đoạn ngắn nhất** trong nhiều lượt + ngân sách thời gian
      (SHORTEN 120ms / SEARCH 450ms) → hết cảnh path nhảy +59 ô, không treo frame
- [x] Cadence `EXPAND_EVERY_N_WAVES = 3` → mở trước wave 4, 7, 10; cap 24 ô/trục
- [x] Kiểm: 5 lần expand liên tiếp FAIL=0; test cưỡng bức WEST+NORTH (rebase) FAIL=0;
      6 wave gameplay thật xác nhận đúng cadence (8x8 → wave 4: 8x16 → wave 7: 16x16)

## H. Lượt kiểm tra + khắc phục (2026-07-24, sau đợt 5)
- [x] Audit full-run 10 wave chạm mọi hệ thống: **0 VERIFY FAIL, 0 lỗi script**
      (7 bất biến kiểm mỗi wave: path liền mạch · nhãn path · bounds · tháp khớp ô ·
      ô đặc biệt không trên đường · prop không dưới tháp · lãnh thổ + mesh khớp)
- [x] Smoke test 7 màn UI, bấm ~100 button: 0 lỗi handler
- [x] **[HIGH] Lãnh thổ bị đường mở rộng cán qua** (reviewer tìm ra): mesh biome nổi trên
      mặt đường, buff chết vĩnh viễn, HUD vẫn đếm. Sửa 2 lớp:
      (1) chặn — `grid_controller.protected_cells_provider` trỏ tới `owned_tiles`, DFS tránh ra;
      (2) lưới an toàn — signal `territory_overwritten_on_expand` →
      `TerritoryManager.remove_territories_at()` xoá state + mesh + hoàn kho + gỡ khỏi King.
      Kiểm 4/4 lần: 20/20 ô lãnh thổ được bảo toàn qua 4 lần mở rộng
- [x] **[CRITICAL tự phát hiện] DFS treo vô hạn**: `_dfs_step` là DFS self-avoiding có
      backtracking → số đường đơn bùng nổ tổ hợp. Ngân sách thời gian chỉ kiểm GIỮA các lượt
      nên một lượt "xấu" chạy mãi (expand không bao giờ trả về — từng treo 7 phút).
      Thêm `MAX_DFS_STEPS = 40000` cho mỗi lượt → mọi lượt đều kết thúc, expand 18-30ms
- [x] Sửa lỗi thứ tự trong bản fix của chính mình: lưới an toàn so toạ độ SAU rebase với dữ
      liệu lãnh thổ CHƯA rebase → báo dọn sai. Giờ dùng tập đã dịch sẵn + phát signal sau `map_rebased`
- [x] 2 asset lỗi: `victory_banner.png` / `defeat_banner.png` vốn là hình placeholder vô nghĩa
      → vẽ lại vương miện vàng + nguyệt quế / vương miện sắt nứt đôi

### Bug sửa trong đợt trước
- `UIStyle._fresh_tween` / `game_hud` dùng `get_meta(key, null)` — Godot vẫn báo lỗi khi
  thiếu key (default null == Variant()) → phải `has_meta` trước
- `slide_in`/`shake` tween `position` trên **con của Container** → Container chưa sort,
  target đọc ra (0,0) nên panel bị ghim sai chỗ, đè lên danh sách King. Giờ con Container
  chỉ fade/scale
- `king_manager.get_territory_summary()` in ra "path, path, path…" (liệt kê cả ô đường)
  → gộp theo biome kèm số lượng, bỏ ô đường
- Panel tower info kéo suốt chiều cao màn hình → co theo nội dung, dời xuống dưới panel HP
- Parchment sinh ra quá sáng khiến chữ sáng khó đọc → đổi sang tông da thuộc tối

## F. Địa hình thật thay bàn cờ phẳng (đợt 4) — HOÀN THÀNH
- [x] 7 texture đất khô nứt 32×32 sinh thủ tục (terrain_light/dark/road/blessed/cursed, cliff_side/top),
      mipmap + NEAREST_WITH_MIPMAPS; ô sáng/tối vẫn tương phản rõ → checkerboard đọc được
- [x] Rune tương phản cao (viền tối) cho ô Phước (mặt trời vàng) / Nguyền (rune gai tím)
- [x] 6 prop 3D Blockbench: tree_pine, tree_dead, bush, rock, grass_tuft, stump (assets/models/props/)
- [x] Renderer: tile có texture + xoay ngẫu nhiên chống lặp; scatter cỏ/đá/bụi ra rìa ô (không chắn tower),
      path chỉ có đá nhỏ, ô đặc biệt để trống cho rune
- [x] Skirt 4 ô quanh grid: đất sẫm liền mạch (KHÔNG kẻ ô) + cây cối → ranh vùng chơi rõ, thành đảo diorama
- [x] Vách đá bao quanh thay khung gỗ + đỉnh vách rêu + đáy bịt kín; GroundPlane hạ y=-6
- [x] Đèn mặt trời ngả vàng + sương bụi nâu → cảm giác khô cằn
- [x] Deterministic theo _map_seed: expand chỉ thêm hàng mới, vùng cũ giữ nguyên cây/cỏ/xoay tile
- [x] clear_props_at/restore_props_at: prop tự ẩn khi đặt tower, trả lại khi dismiss
- [x] Camera framing chừa lề 3 ô để thấy địa hình quanh board
- [x] Verify: mouse picking roundtrip đúng ô, y=0 nguyên vẹn, 2 wave + expand chạy sạch

## E. UX / Audio / Mechanics mới (đợt 3)
- [x] SFX: 18 âm chiptune synth thủ tục (shoot/hit/crit/death/place/perk/wave/victory...) + music loop ambient
      + AudioManagerSingleton autoload (pool 12 player, pitch jitter ±7%)
- [x] UI: wave banner, combo meter, perk card hover/pick juice, button sfx, gold flash
- [x] Authoring đơn giản: perk qua JSON (data/perks/*.json — verified 3 custom perks nạp vào pool),
      template .tres (res/towers/_template_tower.txt, res/enemy/_template_enemy.txt), docs/CONTENT_AUTHORING.md
- [x] Damage numbers 3D (trắng/vàng crit/cam burn/xanh heal, cap 60 label), crit 5% ×2
- [x] Elite enemies (10% từ wave 3: ×3 HP, ×2.5 gold, scale 1.35, tint vàng pulse)
- [x] Ô Phước/Nguyền (+20%/-15% dmg qua BuffLayer.TILE; chết trên ô nguyền +2 vàng; roll theo region khi expand)
- [x] Overcharge: right-click tower, 30 vàng → ×2 tốc bắn 5s, tint cyan + emission
- [x] Kill combo: cửa sổ 2.5s, mult 1.1/1.25/1.5 tại 5/10/20 — test thấy ×10 → 1.25
- [x] Integration test v4: audio + music + special tiles + combo + overcharge + JSON perks đều pass

## D. Roguelike expansion (đợt 2) — HOÀN THÀNH
- [x] **Perk system**: draft 3-chọn-1 sau mỗi wave (scripts/perks/perk_system.gd), 12 perks 4 rarity,
      stack qua PERK buff layer + kinh tế (gold/kill, interest cap/rate) + HP + RD; UI card viền màu rarity
- [x] **5 enemy mới**: troll (regen 8/s), wraith (90px/s), shaman (heal aura 6HP/1.5s), golem (armor 6), bat (swarm)
- [x] **5 quân mới**: longbowman (range 6), paladin (splash+slow cận), alchemist (poison DoT),
      ice_guardian (slow 55%), ballista (60 dmg đơn mục tiêu) — đủ synergy riêng + shop pool wave 2+
- [x] Wave composition 4 season có enemy mới (Spring +bat, Summer +troll, Autumn +shaman/wraith/golem, Winter all)
- [x] 10 model Blockbench mới (27 model tổng) + HUD ability notes
- [x] Integration test: 10 wave → Victory, 9 perks picked, HP stack +5 đúng, 8 synergy active đồng thời

## A. Visual / Game-feel (juice)
- [x] Enemy: bob khi đi, HP bar billboard, flash khi trúng đòn, tint theo debuff (burn cam / slow xanh), hiệu ứng chết (squash + particles)
- [x] Tower: pop khi đặt, xoay mặt về target, recoil khi bắn
- [x] Projectile: mesh 3D phát sáng theo màu tower (bỏ billboard), particles khi trúng
- [x] King base: camera shake khi mất máu
- [x] Preview ghost: model 3D trong suốt xanh/đỏ thay billboard 2D
- [x] Board: khung viền gỗ tối quanh grid, rebuild khi expand
- [x] Environment: fog + glow nhẹ cho projectile emissive
- [x] FX helper dùng chung (CPUParticles3D one-shot)

## B. Mechanics còn thiếu
- [x] King Ability data-driven: `KingStats.ability_script` load + execute, fallback hardcoded match cũ
      (3 script mới trong scripts/king/abilities/, .tres 3 kings đã trỏ)
- [x] Encounter: đủ 4 type hoạt động + 6 encounter mới; fix bug encounter result bị game_map.update_ui() ghi đè
- [x] HUD: px/s → ô/s (2 chỗ: wave intel + tower info AoE)
- [x] Victory (wave 10) + Game Over (HP=0) verified end-to-end; fix victory stats hiện 0 + wave đếm thiếu

## C. Kiểm chứng
- [x] Integration test: full run 10 wave → VictoryScreen (187 kills, 495 meta points);
      run thua → GameOverScreen; ability +30RD wave 2; 3 encounter/run; expand tới max 32
- [x] Screenshot nghiệm thu: HP bar, bolt, khung board, ghost, camera focus
wwwd