# -*- coding: utf-8 -*-
"""Ve lai texture dia hinh 32x32 bang PALETTE NHO, moi pixel co chu dich.

    python tools/make_terrain.py

Bo texture cu duoc sinh bang jitter ngau nhien tung pixel: 48-142 mau tren mot o
32x32, trong khi pixel art ve tay chi dung 5-15 mau. Ket qua la bàn cờ trông lấm
tấm, phóng to thì nhòe thành mảng xám.

Cach lam o day:
  - Moi loai o chi dung 4-5 mau LAY TU PALETTE DU AN.
  - Hoa tiet la HOA VAN CO CHU DICH (khe nut, via da, vet banh xe, co) ve bang
    toa do co dinh, KHONG phai nhieu ngau nhien.
  - Nhieu duy nhat con lai la "cham" thua thot dat theo bang toa do co san —
    deterministic, chay lai cho ket qua y het.

Bo file moi biome: <prefix>_{light,dark,road,cliff_side,cliff_top}.png
prefix: terrain (mac dinh) - wasteland - tundra - volcanic - swamp - verdant
Cong terrain_blessed.png + terrain_cursed.png.
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'textures', 'terrain')
S = 32

# ── Palette moi biome: (nen, dam, nhat, diem_nhan) ───────────────────────────
# Lay tu palette du an: nau dat #3d2b1f, xam da #4a4a4a, do mau #8b1a1a,
# vang dong #c8a000, xanh reu #2d4a1e.
# `lite` va `base` phai CACH NHAU RO: chung la hai o xen ke cua ban co. Bien
# biome nhan mot lop mau len tren, neu hai ton qua gan thi ban co mat ke o.
# `acc` chi dung RAT IT (vet banh xe duong) — dung cho dom/khe nut thi ca ban
# lam tam mau nhan, da dinh voi volcanic (do mau).
BIOMES = {
    'terrain':   {'base': (0x5c, 0x48, 0x33), 'dark': (0x42, 0x33, 0x23),
                  'lite': (0x8e, 0x74, 0x53), 'acc':  (0x35, 0x26, 0x1a)},
    'wasteland': {'base': (0x69, 0x53, 0x38), 'dark': (0x4b, 0x3b, 0x27),
                  'lite': (0xa1, 0x85, 0x5d), 'acc':  (0x3d, 0x2e, 0x1d)},
    'tundra':    {'base': (0x8a, 0x99, 0xa4), 'dark': (0x66, 0x74, 0x80),
                  'lite': (0xd2, 0xdd, 0xe4), 'acc':  (0x53, 0x60, 0x6b)},
    'volcanic':  {'base': (0x40, 0x32, 0x2e), 'dark': (0x29, 0x1f, 0x1d),
                  'lite': (0x6d, 0x55, 0x4d), 'acc':  (0x23, 0x1a, 0x18)},
    'swamp':     {'base': (0x44, 0x4f, 0x33), 'dark': (0x30, 0x39, 0x24),
                  'lite': (0x71, 0x7f, 0x57), 'acc':  (0x28, 0x30, 0x1d)},
    'verdant':   {'base': (0x41, 0x5e, 0x2b), 'dark': (0x2e, 0x44, 0x1e),
                  'lite': (0x70, 0x96, 0x4d), 'acc':  (0x27, 0x3a, 0x18)},
}

# ── Hoa tiet co dinh ─────────────────────────────────────────────────────────
# Toa do viet tay: cham dat, via da, khe nut. Deterministic — chay lai y het.
SPECKS = [(6, 13), (19, 7), (25, 24), (9, 26), (14, 17)]

CRACKS = [
    [(5, 8), (6, 9), (7, 9), (8, 10), (9, 11)],
    [(20, 3), (21, 4), (21, 5), (22, 6)],
    [(12, 22), (13, 23), (14, 23), (15, 24), (16, 25), (17, 25)],
    [(26, 14), (27, 15), (28, 16)],
]

GRASS = [(4, 20), (5, 19), (4, 21), (12, 8), (13, 7), (12, 9),
         (22, 26), (23, 25), (22, 27), (28, 6), (29, 5)]


def blank(rgb):
    return [[rgb for _ in range(S)] for _ in range(S)]


def put(px, pts, rgb):
    for x, y in pts:
        if 0 <= x < S and 0 <= y < S:
            px[y][x] = rgb


def border(px, rgb, inset=0):
    """Vien o — giup doc duoc luoi ban co khi nhieu o canh nhau."""
    for i in range(inset, S - inset):
        px[inset][i] = rgb
        px[S - 1 - inset][i] = rgb
        px[i][inset] = rgb
        px[i][S - 1 - inset] = rgb


def make_ground(pal, light):
    """O nen. `light` = o sang cua ban co (checkerboard)."""
    base = pal['lite'] if light else pal['base']
    px = blank(base)
    # Via dat: mot dai cheo THUA, chi de be mat khong phang tuyet doi.
    # Mau via = ton ke ben (base/lite) chu khong phai mau nhan.
    grain = pal['base'] if light else pal['dark']
    for i in range(0, S, 2):
        px[(i * 3) % S][i] = grain
    for x, y in SPECKS:
        px[y][x] = grain
        if x + 1 < S:
            px[y][x + 1] = grain
    put(px, CRACKS[0], pal['dark'] if light else pal['acc'])
    border(px, pal['dark'] if light else pal['acc'])
    return px


def make_road(pal):
    """O duong quai di: vet banh xe doc + soi hai ben."""
    # Duong phan biet bang DO SANG (toi hon ca hai o nen), khong bang mau —
    # dung mau nhan thi duong "phat sang" va hut het chu y khoi quan co.
    px = blank(pal['dark'])
    for y in range(S):
        for x in range(5, 27):
            px[y][x] = pal['acc']
    # Hai vet banh xe: sang hon long duong mot chut
    for y in range(S):
        for x in (10, 11, 20, 21):
            px[y][x] = pal['dark']
    for x, y in SPECKS:
        if 7 <= x <= 24:
            px[y][x] = pal['base']
    return px


def make_cliff_side(pal):
    """Vach da nhin ngang: cac lop tram tich."""
    px = blank(pal['dark'])
    layer_rows = [0, 5, 11, 16, 22, 27]
    for i, y0 in enumerate(layer_rows):
        tone = pal['base'] if i % 2 == 0 else pal['acc']
        for y in range(y0, min(y0 + 4, S)):
            for x in range(S):
                px[y][x] = tone
        # Duong phan lop
        if y0 + 4 < S:
            for x in range(S):
                px[y0 + 4][x] = pal['dark']
    # Khe nut doc
    for line in CRACKS:
        put(px, line, pal['dark'])
    return px


def make_cliff_top(pal):
    """Mat tren vach da: da vun, sang hon."""
    px = blank(pal['base'])
    for x, y in SPECKS:
        put(px, [(x, y), (x + 1, y), (x, y + 1)], pal['lite'])
    for line in CRACKS[1:]:
        put(px, line, pal['dark'])
    border(px, pal['dark'])
    return px


def make_special(kind):
    """O Phuoc / Nguyen: nen rieng + rune don gian o giua."""
    if kind == 'blessed':
        base, glow, rim = (0x4a, 0x5e, 0x3c), (0xc8, 0xa0, 0x00), (0x2d, 0x4a, 0x1e)
    else:
        base, glow, rim = (0x3b, 0x2a, 0x33), (0x8b, 0x1a, 0x1a), (0x24, 0x18, 0x20)
    px = blank(base)
    # Vong tron rune
    ring = []
    for a in range(0, 360, 6):
        import math
        x = int(16 + 10 * math.cos(math.radians(a)))
        y = int(16 + 10 * math.sin(math.radians(a)))
        ring.append((x, y))
    put(px, ring, glow)
    # Dau cong / dau X o giua
    if kind == 'blessed':
        put(px, [(16, y) for y in range(11, 22)], glow)
        put(px, [(x, 16) for x in range(11, 22)], glow)
    else:
        put(px, [(11 + i, 11 + i) for i in range(11)], glow)
        put(px, [(21 - i, 11 + i) for i in range(11)], glow)
    border(px, rim)
    return px


def write_png(path, px):
    raw = bytearray()
    for y in range(S):
        raw.append(0)
        for x in range(S):
            r, g, b = px[y][x]
            raw += bytes([r, g, b, 255])

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    out = bytes([137, 80, 78, 71, 13, 10, 26, 10])
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', S, S, 8, 6, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    out += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(out)


def count_colors(px):
    return len({px[y][x] for y in range(S) for x in range(S)})


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, pal in BIOMES.items():
        prefix = name
        jobs = {
            'light': make_ground(pal, True),
            'dark': make_ground(pal, False),
            'road': make_road(pal),
            'cliff_side': make_cliff_side(pal),
            'cliff_top': make_cliff_top(pal),
        }
        for kind, px in jobs.items():
            # Bo mac dinh dung ten khong co tien to cho cliff (giu tuong thich)
            if prefix == 'terrain' and kind.startswith('cliff'):
                fname = '%s.png' % kind
            else:
                fname = '%s_%s.png' % (prefix, kind)
            path = os.path.join(OUT, fname)
            write_png(path, px)
            made.append((fname, count_colors(px)))

    for kind in ('blessed', 'cursed'):
        px = make_special(kind)
        fname = 'terrain_%s.png' % kind
        write_png(os.path.join(OUT, fname), px)
        made.append((fname, count_colors(px)))

    worst = max(c for _, c in made)
    print('da ve %d file, so mau cao nhat = %d' % (len(made), worst))
    for fname, c in sorted(made, key=lambda r: -r[1])[:6]:
        print('  %-30s %2d mau' % (fname, c))
    return 0


if __name__ == '__main__':
    sys.exit(main())
