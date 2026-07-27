# -*- coding: utf-8 -*-
"""Kiem tra noi dung game 8x-8: quan co, dich, perk, vat pham.

Chay: python tools/check_content.py

Muc dich: bat nhung loi khien noi dung moi "co ma khong chay" TRUOC khi mo game.
Day la lop loi hay gap nhat o du an nay — file .tres thieu field, id trung, quen
ve icon, quen model .gltf. Game van chay, khong crash, mon do do chi la khong
lam gi ca.

Ket qua:
  LOI    = chac chan hong, phai sua
  CANH   = co the co y (vd chua ve icon) — doc roi tu quyet
Exit code 1 neu co LOI.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

errors = []
warns = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warns.append(msg)


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def tres_fields(text):
    """Doc cac dong `key = value` trong khoi [resource] cua file .tres."""
    out = {}
    body = text.split('[resource]', 1)[-1]
    for line in body.splitlines():
        m = re.match(r'^(\w+)\s*=\s*(.+)$', line.strip())
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def as_num(value, default=0.0):
    m = re.match(r'^-?\d+(\.\d+)?$', str(value).strip())
    return float(value) if m else default


def files(rel, ext):
    d = os.path.join(ROOT, rel)
    if not os.path.isdir(d):
        return []
    return [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(ext)]


def has_asset(rel_path):
    return os.path.isfile(os.path.join(ROOT, rel_path))


# ── 1. QUAN CO (res/towers/*.tres) ───────────────────────────────────────────
# Nguon su that cua tam ban va tran hoi chieu — phai khop hang so trong tower.gd.
MAX_RANGE = 7          # dai nhat cho phep: ban co khoi dau chi 8x8
MIN_RANGE = 1
seen_tower_ids = {}

for path in files('res/towers', '.tres'):
    base = os.path.basename(path)
    if base.startswith('_'):
        continue                      # file mau (_template_tower.txt)
    f = tres_fields(read(path))
    tid = f.get('id', '').strip('"')
    if not tid:
        err('%s: thieu field `id`' % base)
        continue
    if tid in seen_tower_ids:
        err('%s: id "%s" trung voi %s' % (base, tid, seen_tower_ids[tid]))
    seen_tower_ids[tid] = base

    for field in ('name', 'base_damage', 'attack_speed', 'attack_range', 'cost'):
        if field not in f:
            err('%s: thieu field `%s`' % (base, field))

    rng = as_num(f.get('attack_range', 0))
    if rng > MAX_RANGE:
        err('%s: attack_range=%d > %d — moi thap se phu tron ban co, dat o dau '
            'cung nhu nhau' % (base, rng, MAX_RANGE))
    elif rng < MIN_RANGE:
        err('%s: attack_range=%d < %d' % (base, rng, MIN_RANGE))

    if as_num(f.get('attack_speed', 0)) <= 0:
        err('%s: attack_speed phai > 0 (day la giay hoi chieu)' % base)
    if as_num(f.get('cost', 0)) <= 0:
        warn('%s: cost = 0 — quan nay se mien phi' % base)

    if not has_asset('assets/models/%s.gltf' % tid):
        warn('%s: chua co assets/models/%s.gltf — se dung sprite 2D thay the'
             % (base, tid))

# ── 2. DICH (res/enemy/*.tres) ───────────────────────────────────────────────
seen_enemy_ids = {}
spawnable = []

for path in files('res/enemy', '.tres'):
    base = os.path.basename(path)
    if base.startswith('_'):
        continue
    f = tres_fields(read(path))
    eid = f.get('id', '').strip('"')
    if not eid:
        err('%s: thieu field `id`' % base)
        continue
    if eid in seen_enemy_ids:
        err('%s: id "%s" trung voi %s' % (base, eid, seen_enemy_ids[eid]))
    seen_enemy_ids[eid] = base

    if as_num(f.get('max_hp', 0)) <= 0:
        err('%s: max_hp phai > 0' % base)
    if as_num(f.get('speed', 0)) <= 0:
        err('%s: speed phai > 0 — dich se dung yen' % base)

    seasons = f.get('spawn_seasons', '')
    if seasons and seasons not in ('Array[int]([])', '[]'):
        spawnable.append(eid)
    if not has_asset('assets/models/%s.gltf' % eid):
        warn('%s: chua co assets/models/%s.gltf' % (base, eid))

# Dich khong nam trong bang mua cung MA cung khong khai spawn_seasons thi khong
# bao gio xuat hien — day chinh la loai loi "co ma khong chay".
spawner = read(os.path.join(ROOT, 'scripts/map/wave_spawner.gd'))
hardcoded = set(re.findall(r'_get_enemy\("(\w+)"\)', spawner))
# Boss khong di qua bang mua — chung spawn rieng o wave boss qua BOSS_IDS.
hardcoded |= set(re.findall(r'"(boss_\w+)"', spawner))
for eid in seen_enemy_ids:
    if eid not in hardcoded and eid not in spawnable:
        err('res/enemy/%s: loai "%s" khong nam trong bang mua cua wave_spawner '
            'va cung khong khai `spawn_seasons` — se KHONG BAO GIO spawn'
            % (seen_enemy_ids[eid], eid))

# ── 3. PERK (data/perks/*.json) ──────────────────────────────────────────────
RARITIES = {'common', 'rare', 'epic', 'legendary'}
CHANNELS = {'tower', 'economy', 'instant', 'rd', 'element'}
seen_perk_ids = {}

for path in files('data/perks', '.json'):
    base = os.path.basename(path)
    try:
        data = json.loads(read(path))
    except Exception as exc:
        err('%s: JSON hong — %s' % (base, exc))
        continue
    if not isinstance(data, list):
        err('%s: file phai la MOT JSON array cac perk' % base)
        continue
    for perk in data:
        pid = perk.get('id', '')
        if not pid:
            err('%s: co perk thieu `id`' % base)
            continue
        if pid in seen_perk_ids:
            err('%s: perk id "%s" trung voi %s' % (base, pid, seen_perk_ids[pid]))
        seen_perk_ids[pid] = base
        if not perk.get('name'):
            err('%s [%s]: thieu `name`' % (base, pid))
        rarity = perk.get('rarity', '')
        if rarity not in RARITIES:
            err('%s [%s]: rarity "%s" khong hop le (%s)'
                % (base, pid, rarity, '/'.join(sorted(RARITIES))))
        if not any(k in perk for k in CHANNELS):
            err('%s [%s]: khong co kenh hieu ung nao (%s) — perk nay se khong '
                'lam gi ca' % (base, pid, '/'.join(sorted(CHANNELS))))

# ── 4. VAT PHAM: icon phai trung id ──────────────────────────────────────────
ITEM_SOURCES = [
    ('thuoc',    'data/potions',   'assets/ui/potions',   'scripts/items/potion_system.gd'),
    ('trang bi', 'data/equipment', 'assets/ui/equipment', 'scripts/items/equipment_system.gd'),
    ('di vat',   'data/relics',    'assets/ui/relics',    'scripts/items/relic_system.gd'),
]

for label, json_dir, icon_dir, gd_path in ITEM_SOURCES:
    ids = set()
    for path in files(json_dir, '.json'):
        try:
            data = json.loads(read(path))
        except Exception as exc:
            err('%s: JSON hong — %s' % (os.path.basename(path), exc))
            continue
        if isinstance(data, list):
            for item in data:
                if item.get('id'):
                    ids.add(item['id'])
    # Cac mon built-in khai thang trong .gd (ban du phong khi thieu JSON)
    gd_full = os.path.join(ROOT, gd_path)
    if os.path.isfile(gd_full):
        ids |= set(re.findall(r'"id"\s*:\s*"(\w+)"', read(gd_full)))
    for item_id in sorted(ids):
        if not has_asset('%s/%s.png' % (icon_dir, item_id)):
            warn('%s "%s": thieu icon %s/%s.png — o se hien nhan chu viet tat'
                 % (label, item_id, icon_dir, item_id))

# ── Bao cao ──────────────────────────────────────────────────────────────────
print('=' * 78)
print('  KIEM TRA NOI DUNG — %d quan co · %d dich · %d perk'
      % (len(seen_tower_ids), len(seen_enemy_ids), len(seen_perk_ids)))
print('=' * 78)
for m in errors:
    print('  LOI   ' + m)
for m in warns:
    print('  CANH  ' + m)
if not errors and not warns:
    print('  (sach)')
print()
print('Tong: %d loi, %d canh bao' % (len(errors), len(warns)))
sys.exit(1 if errors else 0)
