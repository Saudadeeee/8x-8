# -*- coding: utf-8 -*-
"""Ve 13 icon perk 48x48, moi icon mot bieu tuong rieng.

    python tools/make_perk_icons.py

Thu muc assets/ui/perks/ dang RONG nen moi card perk deu hien cung mot ky hieu
‡ theo bac hiem — 13 perk trong y het nhau.

Quy uoc (giong bo icon vat pham 32x32 da co):
  - Outline #14100c kin, nguon sang co dinh TREN-TRAI, bong duoi-phai.
  - 4-6 mau moi icon, lay tu palette du an.
  - Hinh phai doc duoc o 48px: net day, khong chi tiet manh.
  - Mau chu dao gan voi KENH hieu ung cua perk (thap = thep, kinh te = vang,
    nguyen to = mau nguyen to do) de nguoi choi doan duoc tac dung.
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'ui', 'perks')
S = 48

OUTLINE = (0x14, 0x10, 0x0c)
STEEL   = (0x9a, 0xa2, 0xac)
STEEL_D = (0x5e, 0x66, 0x70)
WOOD    = (0x6b, 0x47, 0x28)
GOLD    = (0xc8, 0xa0, 0x00)
GOLD_L  = (0xf0, 0xd0, 0x50)
FIRE    = (0xff, 0x6a, 0x12)
FIRE_D  = (0xb0, 0x3a, 0x08)
ICE     = (0x8f, 0xd0, 0xee)
ICE_D   = (0x4e, 0x8f, 0xb4)
BOLT    = (0xc8, 0x6a, 0xff)
BOLT_D  = (0x7a, 0x3a, 0xa8)
WATER   = (0x3a, 0x7a, 0xb0)
WATER_L = (0x6a, 0xb0, 0xdc)
POISON  = (0x66, 0xe0, 0x3a)
POISON_D = (0x2f, 0x8a, 0x1c)
EARTH   = (0x8a, 0x75, 0x50)
EARTH_D = (0x55, 0x46, 0x2e)
PARCH   = (0xd8, 0xc0, 0x92)


def blank():
    return [[None for _ in range(S)] for _ in range(S)]


def rect(px, x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(S, y1 + 1)):
        for x in range(max(0, x0), min(S, x1 + 1)):
            px[y][x] = c


def disc(px, cx, cy, r, c):
    for y in range(max(0, cy - r), min(S, cy + r + 1)):
        for x in range(max(0, cx - r), min(S, cx + r + 1)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px[y][x] = c


def line(px, x0, y0, x1, y1, c, thick=2):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        x = round(x0 + (x1 - x0) * i / steps)
        y = round(y0 + (y1 - y0) * i / steps)
        rect(px, x, y, x + thick - 1, y + thick - 1, c)


def tri(px, pts, c):
    """To tam giac bang quet hang."""
    ys = [p[1] for p in pts]
    for y in range(max(0, min(ys)), min(S, max(ys) + 1)):
        xs = []
        for i in range(3):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % 3]
            if y0 == y1:
                continue
            if min(y0, y1) <= y <= max(y0, y1):
                xs.append(x0 + (x1 - x0) * (y - y0) / (y1 - y0))
        if len(xs) >= 2:
            rect(px, int(min(xs)), y, int(max(xs)), y, c)


def outline(px):
    """Vien 1px quanh moi vung co muc — ve CUOI cung."""
    mask = [[px[y][x] is not None for x in range(S)] for y in range(S)]
    for y in range(S):
        for x in range(S):
            if mask[y][x]:
                continue
            near = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < S and 0 <= ny < S and mask[ny][nx]:
                    near = True
                    break
            if near:
                px[y][x] = OUTLINE


def shade(px, c_from, c_to, side='br'):
    """To toi nua duoi-phai cua mot mau => khoi tron."""
    for y in range(S):
        for x in range(S):
            if px[y][x] == c_from and (x + y) > S:
                px[y][x] = c_to


# ── Tung icon ────────────────────────────────────────────────────────────────

def spear():             # luoi_giao_tien_tuyen — mui giao cheo
    px = blank()
    line(px, 10, 36, 32, 14, WOOD, 3)
    tri(px, [(36, 8), (30, 20), (40, 18)], STEEL)
    tri(px, [(36, 10), (32, 18), (37, 17)], (0xd0, 0xd8, 0xe0))
    rect(px, 27, 19, 33, 22, STEEL_D)
    outline(px)
    return px


def tax():               # thue_chu_hau — tui vang co dau tien
    px = blank()
    disc(px, 24, 30, 13, WOOD)
    shade(px, WOOD, (0x4a, 0x30, 0x1a))
    rect(px, 18, 13, 30, 18, (0x4a, 0x30, 0x1a))
    disc(px, 24, 30, 6, GOLD)
    disc(px, 22, 28, 3, GOLD_L)
    outline(px)
    return px


def strategist():        # quan_su_hoang_trieu — cuon giay + vuong mien
    px = blank()
    rect(px, 10, 16, 38, 38, PARCH)
    shade(px, PARCH, (0xb0, 0x9a, 0x70))
    rect(px, 10, 16, 38, 18, (0xb0, 0x9a, 0x70))
    for y in (24, 29, 34):
        rect(px, 15, y, 33, y + 1, (0x6b, 0x5a, 0x3c))
    tri(px, [(24, 4), (18, 14), (30, 14)], GOLD)
    rect(px, 16, 12, 32, 15, GOLD)
    outline(px)
    return px


def elemental(main, dark, shape):
    """Icon nguyen to: vien tron + hinh loi ben trong."""
    px = blank()
    disc(px, 24, 24, 17, dark)
    disc(px, 24, 24, 14, main)
    if shape == 'flame':
        tri(px, [(24, 10), (17, 30), (31, 30)], (0xff, 0xc0, 0x40))
        tri(px, [(24, 17), (20, 30), (28, 30)], (0xff, 0xf0, 0xa0))
    elif shape == 'ice':
        line(px, 24, 12, 24, 34, (0xe8, 0xf8, 0xff), 2)
        line(px, 14, 18, 34, 30, (0xe8, 0xf8, 0xff), 2)
        line(px, 14, 30, 34, 18, (0xe8, 0xf8, 0xff), 2)
    elif shape == 'bolt':
        tri(px, [(28, 10), (18, 26), (26, 26)], (0xf0, 0xd0, 0xff))
        tri(px, [(22, 38), (30, 22), (22, 22)], (0xf0, 0xd0, 0xff))
    elif shape == 'drop':
        tri(px, [(24, 10), (16, 26), (32, 26)], (0xa8, 0xd8, 0xf0))
        disc(px, 24, 27, 8, (0xa8, 0xd8, 0xf0))
    elif shape == 'skull':
        disc(px, 24, 22, 9, (0xe0, 0xf8, 0xc8))
        rect(px, 20, 30, 28, 34, (0xe0, 0xf8, 0xc8))
        rect(px, 19, 20, 22, 24, OUTLINE)
        rect(px, 26, 20, 29, 24, OUTLINE)
    elif shape == 'rock':
        tri(px, [(24, 12), (12, 32), (36, 32)], (0xc0, 0xa8, 0x78))
        rect(px, 12, 30, 36, 35, (0xa0, 0x88, 0x5c))
    outline(px)
    return px


def landlord():          # dia_chu — o dat co cam co
    px = blank()
    rect(px, 8, 24, 40, 38, EARTH)
    shade(px, EARTH, EARTH_D)
    rect(px, 8, 24, 40, 26, (0xa8, 0x92, 0x66))
    rect(px, 22, 8, 24, 26, WOOD)
    tri(px, [(25, 9), (25, 19), (38, 14)], (0x8b, 0x1a, 0x1a))
    outline(px)
    return px


def smith():             # tho_ren_lang_thang — bua ren
    px = blank()
    line(px, 14, 38, 30, 20, WOOD, 4)
    rect(px, 24, 8, 40, 20, STEEL)
    shade(px, STEEL, STEEL_D)
    rect(px, 26, 10, 32, 14, (0xc0, 0xc8, 0xd0))
    outline(px)
    return px


def alchemist():         # nha_gia_kim — binh chung cat
    px = blank()
    tri(px, [(24, 12), (12, 38), (36, 38)], (0x7a, 0xd8, 0xc8))
    rect(px, 20, 6, 28, 14, (0x9a, 0xe8, 0xd8))
    rect(px, 14, 30, 34, 38, POISON)
    disc(px, 20, 33, 2, (0xc8, 0xff, 0x9a))
    disc(px, 28, 35, 2, (0xc8, 0xff, 0x9a))
    outline(px)
    return px


def physical():          # thuan_vat_ly — kiem cheo
    px = blank()
    line(px, 10, 38, 36, 10, STEEL, 4)
    line(px, 38, 38, 12, 10, STEEL_D, 4)
    rect(px, 20, 20, 28, 26, GOLD)
    outline(px)
    return px


def vein_smith():        # tho_ghep_mach — hai o long vao nhau
    px = blank()
    rect(px, 8, 12, 26, 30, FIRE)
    shade(px, FIRE, FIRE_D)
    rect(px, 22, 20, 40, 38, ICE)
    shade(px, ICE, ICE_D)
    rect(px, 22, 20, 26, 30, GOLD)
    outline(px)
    return px




# ── 12 perk built-in khai trong perk_system.gd ───────────────────────────────

def anvil():             # ren_vu_khi — de ren + bua
    px = blank()
    rect(px, 8, 26, 40, 34, STEEL_D)
    rect(px, 14, 20, 34, 26, STEEL)
    rect(px, 12, 34, 36, 40, STEEL_D)
    line(px, 30, 18, 40, 8, WOOD, 3)
    rect(px, 34, 6, 44, 14, STEEL)
    outline(px)
    return px


def oil():               # dau_boi_tron — binh dau nho giot
    px = blank()
    disc(px, 22, 30, 11, (0x6b, 0x47, 0x28))
    shade(px, (0x6b, 0x47, 0x28), (0x42, 0x2c, 0x18))
    rect(px, 18, 14, 26, 20, (0x42, 0x2c, 0x18))
    line(px, 30, 22, 42, 14, STEEL, 3)
    disc(px, 42, 20, 3, GOLD_L)
    outline(px)
    return px


def eagle_eye():         # mat_dai_bang — mat trong vong ngam
    px = blank()
    disc(px, 24, 24, 16, STEEL_D)
    disc(px, 24, 24, 13, (0xd8, 0xe4, 0xf0))
    disc(px, 24, 24, 7, (0x2a, 0x5a, 0x8a))
    disc(px, 24, 24, 3, OUTLINE)
    rect(px, 24, 4, 25, 12, STEEL)
    rect(px, 24, 36, 25, 44, STEEL)
    rect(px, 4, 24, 12, 25, STEEL)
    rect(px, 36, 24, 44, 25, STEEL)
    outline(px)
    return px


def royal_forge():       # lo_ren_hoang_gia — lo lua co vuong mien
    px = blank()
    rect(px, 8, 22, 40, 40, (0x4a, 0x42, 0x3c))
    shade(px, (0x4a, 0x42, 0x3c), (0x2c, 0x27, 0x22))
    tri(px, [(24, 24), (16, 38), (32, 38)], FIRE)
    tri(px, [(24, 29), (20, 38), (28, 38)], (0xff, 0xd0, 0x60))
    tri(px, [(24, 4), (16, 18), (32, 18)], GOLD)
    outline(px)
    return px


def war_god():           # than_chien_tranh — kiem lon co hao quang
    px = blank()
    for r in (20, 17):
        disc(px, 24, 24, r, GOLD if r == 20 else (0x2c, 0x22, 0x10))
    line(px, 24, 8, 24, 34, STEEL, 4)
    rect(px, 16, 30, 32, 34, GOLD)
    rect(px, 22, 34, 27, 42, WOOD)
    outline(px)
    return px


def blood_tax():         # thue_mau — dong xu nho mau
    px = blank()
    disc(px, 24, 22, 14, GOLD)
    shade(px, GOLD, (0x8a, 0x6a, 0x10))
    disc(px, 22, 20, 5, GOLD_L)
    tri(px, [(24, 32), (18, 44), (30, 44)], (0x8b, 0x1a, 0x1a))
    outline(px)
    return px


def treasury():          # ngan_kho — ruong bau
    px = blank()
    rect(px, 8, 22, 40, 40, WOOD)
    shade(px, WOOD, (0x42, 0x2c, 0x18))
    rect(px, 8, 22, 40, 26, GOLD)
    rect(px, 21, 26, 27, 34, GOLD)
    rect(px, 8, 16, 40, 22, (0x42, 0x2c, 0x18))
    outline(px)
    return px


def gold_vault():        # ham_vang — dong vang xep chong
    px = blank()
    for i, y in enumerate((34, 26, 18)):
        w = 16 - i * 3
        rect(px, 24 - w, y, 24 + w, y + 7, GOLD)
        rect(px, 24 - w, y, 24 + w, y + 1, GOLD_L)
    outline(px)
    return px


def rampart():           # tuong_thanh — tuong thanh co lo chau mai
    px = blank()
    rect(px, 6, 18, 42, 40, (0x6a, 0x67, 0x61))
    shade(px, (0x6a, 0x67, 0x61), (0x3e, 0x3c, 0x38))
    for x in (6, 16, 26, 36):
        rect(px, x, 12, x + 6, 18, (0x6a, 0x67, 0x61))
    for y in (26, 33):
        rect(px, 7, y, 41, y + 1, (0x3e, 0x3c, 0x38))
    outline(px)
    return px


def sacrifice():         # hien_te — dao te tren ban tho
    px = blank()
    rect(px, 8, 34, 40, 42, (0x4a, 0x42, 0x3c))
    line(px, 24, 6, 24, 30, STEEL, 4)
    tri(px, [(24, 4), (20, 12), (28, 12)], (0xd0, 0xd8, 0xe0))
    rect(px, 17, 26, 31, 30, GOLD)
    disc(px, 24, 38, 4, (0x8b, 0x1a, 0x1a))
    outline(px)
    return px


def urgent_decree():     # sac_lenh_khan — cuon chieu chi co dau
    px = blank()
    rect(px, 12, 10, 36, 38, PARCH)
    shade(px, PARCH, (0xb0, 0x9a, 0x70))
    for y in (18, 23, 28):
        rect(px, 17, y, 31, y + 1, (0x6b, 0x5a, 0x3c))
    disc(px, 24, 36, 6, (0x8b, 0x1a, 0x1a))
    rect(px, 10, 8, 38, 12, WOOD)
    rect(px, 10, 36, 38, 40, WOOD)
    outline(px)
    return px


def authority():         # quyen_uy — quyen truong
    px = blank()
    line(px, 24, 16, 24, 44, WOOD, 4)
    disc(px, 24, 14, 9, GOLD)
    disc(px, 22, 12, 4, GOLD_L)
    tri(px, [(24, 2), (18, 10), (30, 10)], GOLD)
    outline(px)
    return px


ICONS = {
    'luoi_giao_tien_tuyen': spear,
    'thue_chu_hau': tax,
    'quan_su_hoang_trieu': strategist,
    'hoa_su': lambda: elemental(FIRE, FIRE_D, 'flame'),
    'han_bang_quyet': lambda: elemental(ICE, ICE_D, 'ice'),
    'loi_dinh': lambda: elemental(BOLT, BOLT_D, 'bolt'),
    'thuy_mach': lambda: elemental(WATER, (0x24, 0x4e, 0x74), 'drop'),
    'doc_su': lambda: elemental(POISON_D, (0x1c, 0x55, 0x10), 'skull'),
    'dia_chu': landlord,
    'tho_ren_lang_thang': smith,
    'nha_gia_kim': alchemist,
    'thuan_vat_ly': physical,
    'tho_ghep_mach': vein_smith,
    # 12 perk built-in
    'ren_vu_khi': anvil,
    'dau_boi_tron': oil,
    'mat_dai_bang': eagle_eye,
    'lo_ren_hoang_gia': royal_forge,
    'than_chien_tranh': war_god,
    'thue_mau': blood_tax,
    'ngan_kho': treasury,
    'ham_vang': gold_vault,
    'tuong_thanh': rampart,
    'hien_te': sacrifice,
    'sac_lenh_khan': urgent_decree,
    'quyen_uy': authority,
}


def write_png(path, px):
    raw = bytearray()
    for y in range(S):
        raw.append(0)
        for x in range(S):
            c = px[y][x]
            if c is None:
                raw += bytes([0, 0, 0, 0])
            else:
                raw += bytes([c[0], c[1], c[2], 255])

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    out = bytes([137, 80, 78, 71, 13, 10, 26, 10])
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', S, S, 8, 6, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    out += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(out)


def main():
    os.makedirs(OUT, exist_ok=True)
    worst = 0
    for pid, fn in ICONS.items():
        px = fn()
        write_png(os.path.join(OUT, '%s.png' % pid), px)
        n = len({px[y][x] for y in range(S) for x in range(S) if px[y][x]})
        worst = max(worst, n)
        print('  %-24s %2d mau' % (pid, n))
    print('da ve %d icon perk 48x48, so mau cao nhat = %d' % (len(ICONS), worst))
    return 0


if __name__ == '__main__':
    sys.exit(main())
