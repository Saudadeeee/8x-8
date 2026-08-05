# -*- coding: utf-8 -*-
"""Ve icon 32x32 cho di vat sinh bang bang (rl_*).

    python tools/make_relic_icons.py

Vi sao KHONG ve tay tung cai: 88 di vat moi. Ve tay thi vua lau vua khong nhat
quan. O day moi icon = mot HINH NEN theo NHOM (dieu kien / bo dem / danh doi /
lai) + mot DAU HIEU theo chu de (quan co, o nguyen to, kinh te, mau Vua...).

Nguoi choi doc duoc TRUOC khi doc chu:
  - vien theo BAC hiem (rare xanh, epic tim, legendary vang)
  - hinh nen: khien = dieu kien, chong dia = bo dem, can cong = danh doi,
    da quy = lai
  - mau loi theo chu de

Quy uoc chung voi bo icon cu: outline #14100c kin, nguon sang tren-trai.
"""
import io
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'res', 'relics')
OUT = os.path.join(ROOT, 'assets', 'ui', 'relics')
S = 32

OUTLINE = (0x14, 0x10, 0x0c)
RARITY = {
    'rare':      ((0x4a, 0x86, 0xc8), (0x8c, 0xc4, 0xf0)),
    'epic':      ((0x7a, 0x46, 0xb0), (0xc0, 0x92, 0xe8)),
    'legendary': ((0xc8, 0xa0, 0x00), (0xf4, 0xdc, 0x70)),
}
# Mau loi theo CHU DE — doan tu ten dieu kien / bo dem trong file .tres.
THEME = [
    (('pawn', 'rook', 'knight', 'bishop', 'queen', 'cannon', 'kinds', 'single_kind'),
     ((0x9a, 0xa2, 0xac), (0xd4, 0xdc, 0xe4))),                 # quan co: thep
    (('vein', 'element', 'ley'), ((0x2f, 0x9e, 0x6a), (0x7a, 0xe0, 0xac))),  # o: luc
    (('gold', 'rich', 'broke'), ((0xc8, 0xa0, 0x00), (0xf4, 0xdc, 0x70))),   # kinh te
    (('hp', 'king', 'full_hp'), ((0x8b, 0x1a, 0x1a), (0xd8, 0x54, 0x4c))),   # mau Vua
    (('formation',), ((0xc0, 0x6a, 0x20), (0xf0, 0xa8, 0x50))),             # the co
    (('wave', 'boss', 'late', 'odd', 'even'), ((0x4a, 0x86, 0xc8), (0x8c, 0xc4, 0xf0))),
    (('star',), ((0xe0, 0xc0, 0x40), (0xff, 0xf0, 0xa0))),
]
DEFAULT_CORE = ((0x7a, 0x6a, 0x58), (0xb8, 0xa8, 0x90))


def png(path, px):
    raw = b''
    for y in range(S):
        raw += b'\x00'
        for x in range(S):
            p = px[y][x]
            raw += bytes(p) if p else b'\x00\x00\x00\x00'

    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c))

    io.open(path, 'wb').write(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', S, S, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b''))


def blank():
    return [[None] * S for _ in range(S)]


def put(px, x, y, c):
    if 0 <= x < S and 0 <= y < S:
        px[y][x] = (c[0], c[1], c[2], 255)


def disc(px, cx, cy, r, c):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                put(px, x, y, c)


def rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(px, x, y, c)


def outline(px):
    """Vien kin theo mep mat na — tinh theo VIEN, khong ve halo tung pixel
    (halo 3x3 lap khe ho ben trong hinh, da dinh loi do o bo icon truoc)."""
    mask = [[px[y][x] is not None for x in range(S)] for y in range(S)]
    for y in range(S):
        for x in range(S):
            if mask[y][x]:
                continue
            touch = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    ny, nx = y + dy, x + dx
                    if 0 <= nx < S and 0 <= ny < S and mask[ny][nx]:
                        touch = True
                        break
                if touch:
                    break
            if touch:
                put(px, x, y, OUTLINE)


def shield(px, dark, lite):
    """Nen KHIEN — di vat dieu kien ("khi ... thi ...")."""
    for y in range(6, 27):
        w = 9 if y < 20 else max(0, 9 - (y - 20) * 2)
        for x in range(16 - w, 16 + w + 1):
            put(px, x, y, dark if (x - 16) + (y - 6) > 4 else lite)


def coins(px, dark, lite):
    """Nen CHONG DIA — di vat bo dem ("moi ... thi ...")."""
    for i, cy in enumerate((22, 17, 12)):
        disc(px, 16, cy, 9 - i, dark)
        disc(px, 15, cy - 1, 7 - i, lite)


def scales(px, dark, lite):
    """Nen CAN CONG — di vat danh doi (co mat trai)."""
    rect(px, 15, 6, 17, 26, dark)
    rect(px, 6, 10, 26, 12, dark)
    disc(px, 8, 17, 5, lite)
    disc(px, 24, 17, 5, dark)
    rect(px, 10, 25, 22, 27, dark)


def gem(px, dark, lite):
    """Nen DA QUY — di vat lai (dieu kien + bo dem)."""
    for y in range(5, 28):
        t = abs(y - 15) / 11.0
        w = int(11 * (1.0 - t * 0.85))
        for x in range(16 - w, 16 + w + 1):
            put(px, x, y, lite if x < 16 else dark)


SHAPES = {'cond': shield, 'per': coins, 'trade': scales, 'hybrid': gem}


def theme_for(text):
    for keys, colors in THEME:
        for k in keys:
            if k in text:
                return colors
    return DEFAULT_CORE


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    made = 0
    for f in sorted(os.listdir(SRC)):
        if not f.endswith('.tres') or not (f.startswith('rl_') or f.startswith('chess_')):
            continue
        rid = f[:-5]
        if os.path.exists(os.path.join(OUT, rid + '.png')) and not rid.startswith('chess_'):
            continue
        dst = os.path.join(OUT, rid + '.png')
        src = io.open(os.path.join(SRC, f), encoding='utf-8').read()
        m = re.search(r'rarity = "([^"]+)"', src)
        rarity = m.group(1) if m else 'epic'
        has_cond = '"cond_mult"' in src
        has_per = '"per_mult"' in src
        neg = re.search(r':\s*-[\d.]+', src) is not None
        if has_cond and has_per:
            kind = 'hybrid'
        elif neg:
            kind = 'trade'
        elif has_per:
            kind = 'per'
        else:
            kind = 'cond'

        px = blank()
        core_d, core_l = theme_for(src)
        SHAPES[kind](px, core_d, core_l)
        outline(px)
        # Vien theo BAC — ve SAU outline nen no nam ngoai cung, doc duoc ngay.
        rim_d, rim_l = RARITY.get(rarity, RARITY['epic'])
        for x in range(S):
            put(px, x, 0, rim_d); put(px, x, S - 1, rim_d)
        for y in range(S):
            put(px, 0, y, rim_d); put(px, S - 1, y, rim_d)
        for x in range(1, S - 1):
            put(px, x, 1, rim_l)
        png(dst, px)
        made += 1
    print('da ve %d icon di vat 32x32 vao %s' % (made, OUT))
    return 0


if __name__ == '__main__':
    sys.exit(main())
