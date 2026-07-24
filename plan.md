# Plan hoàn thiện 8x-8 (3D) — 2026-07-24

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
