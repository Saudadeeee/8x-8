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
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PNG_MAGIC = bytes([137, 80, 78, 71, 13, 10, 26, 10])

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

def png_size(rel_path):
    """(rong, cao) cua mot PNG, doc thang tu header IHDR — khong can thu vien."""
    full = os.path.join(ROOT, rel_path)
    if not os.path.isfile(full):
        return None
    try:
        with open(full, 'rb') as f:
            head = f.read(24)
        if head[:8] != PNG_MAGIC:
            return None
        return struct.unpack('>II', head[16:24])
    except Exception:
        return None


def check_size(rel_path, want_w, want_h, label):
    """Canh bao neu anh sai kich thuoc chuan. Sai co la UI ra to/nho bat thuong
    hoac bi mo — pixel art phong to khong phai boi so nguyen se nhoe."""
    size = png_size(rel_path)
    if size is None:
        return
    if size != (want_w, want_h):
        warn('%s: %s la %dx%d, chuan la %dx%d'
             % (label, rel_path, size[0], size[1], want_w, want_h))




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

    has_model = has_asset('assets/models/%s.gltf' % tid)
    has_sprite = has_asset('assets/towers/%s.png' % tid)
    has_tex_field = 'texture' in f
    if not has_model:
        warn('%s: chua co assets/models/%s.gltf — se dung sprite 2D thay the'
             % (base, tid))
    if not (has_model or has_sprite or has_tex_field):
        err('%s: khong co model .gltf, khong co assets/towers/%s.png, .tres cung '
            'khong gan `texture` — card shop se TRONG TRON' % (base, tid))
    check_size('assets/towers/%s.png' % tid, 32, 32, 'quan co')

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
    check_size('assets/enemy/%s.png' % eid, 32, 32, 'dich')

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
        rel = '%s/%s.png' % (icon_dir, item_id)
        if not has_asset(rel):
            warn('%s "%s": thieu icon %s — o se hien nhan chu viet tat'
                 % (label, item_id, rel))
        else:
            check_size(rel, 32, 32, '%s "%s"' % (label, item_id))

# ── 5. ANH DUNG CHUNG: perk / o nguyen to / crest shop ──────────────────────
# Perk khong bat buoc co PNG (card tu roi ve ky hieu ◆), nhung neu CO thi phai
# dung 48x48 — card danh o vuong 76px, anh lech cỡ se bi keo mo.
for pid in sorted(seen_perk_ids):
    check_size('assets/ui/perks/%s.png' % pid, 48, 48, 'perk "%s"' % pid)

# O nguyen to va crest shop PHAI dung mot rune — nguoi choi doi chieu
# "icon trong shop = o tren ban". Thieu mot trong hai la mat lien ket do.
TILE_KEYS = ['fire', 'ice', 'thunder', 'swamp', 'forest', 'desert']
for key in TILE_KEYS:
    tile = 'assets/tiles/territory_%s.png' % key
    crest = 'assets/ui/shop_icons/icon_%s.png' % key
    if not has_asset(tile):
        err('thieu texture o nguyen to: %s' % tile)
    else:
        check_size(tile, 32, 32, 'o nguyen to')
    if not has_asset(crest):
        err('thieu crest shop: %s' % crest)
    else:
        check_size(crest, 32, 32, 'crest shop')

# ── 6. MOI DUONG DAN TRONG .tres/.tscn PHAI TON TAI ─────────────────────────
# Xoa nham mot file ma resource van tro toi thi Godot chi in "ERROR: Failed
# loading resource" roi bo qua — shop lang le thieu mot thap, test van xanh.
# Da dinh that khi don asset: Tower.png / Wisp.png / horse.png bi xoa nhung
# rook / ice_guardian / knight van dung chung lam `texture`.
for folder in ('res', 'res/towers', 'res/enemy', 'res/kings', 'scenes',
               'scenes/map', 'scenes/ui', 'scenes/tower', 'scenes/enemy',
               'scenes/projectile'):
    d = os.path.join(ROOT, folder)
    if not os.path.isdir(d):
        continue
    for name in sorted(os.listdir(d)):
        if not name.endswith(('.tres', '.tscn')):
            continue
        rel = '%s/%s' % (folder, name)
        for m in re.finditer(r'path="res://([^"]+)"', read(os.path.join(ROOT, folder, name))):
            target = m.group(1)
            if not has_asset(target):
                err('%s tro toi file KHONG TON TAI: res://%s' % (rel, target))

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
