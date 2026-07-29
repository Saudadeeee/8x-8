# -*- coding: utf-8 -*-
"""Ve lai panel + nut 9-patch bang palette nho.

    python tools/make_panels.py

Bo cu duoc sinh bang jitter tung pixel: 80-127 mau tren mot anh 48x48. Day la
khung bao MOI panel va MOI nut trong game nen no quyet dinh cam giac ca giao
dien — de nhieu nhu vay thi UI trong ban do.

Rang buoc quan trong: KICH THUOC va BIEN 9-PATCH phai giu nguyen, vi ui_style.gd
da khai san (stone/wood margin 8, parchment 10, nut 6, thanh 4). Doi kich thuoc
la goc panel bi keo gian.

Nguyen tac ve:
  - 4-6 mau moi anh, lay tu palette du an.
  - Vien ngoai 1px toi + vien trong 1px sang => cam giac khoi noi (bevel).
  - Ruot phang, chi vai net van CO CHU DICH (via go, ranh da) o vung KHONG bi
    9-patch keo gian — tuc trong pham vi bien goc.
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'ui', 'panels')


def blank(w, h, rgb):
    return [[rgb for _ in range(w)] for _ in range(h)]


def rect(px, x0, y0, x1, y1, rgb):
    for y in range(max(0, y0), min(len(px), y1 + 1)):
        for x in range(max(0, x0), min(len(px[0]), x1 + 1)):
            px[y][x] = rgb


def frame(px, inset, rgb):
    w, h = len(px[0]), len(px)
    for x in range(inset, w - inset):
        px[inset][x] = rgb
        px[h - 1 - inset][x] = rgb
    for y in range(inset, h - inset):
        px[y][inset] = rgb
        px[y][w - 1 - inset] = rgb


def bevel(px, dark, lite):
    """Vien ngoai toi + vien trong sang => khoi noi len."""
    w, h = len(px[0]), len(px)
    frame(px, 0, dark)
    for x in range(1, w - 1):
        px[1][x] = lite
    for y in range(1, h - 1):
        px[y][1] = lite
    for x in range(1, w - 1):
        px[h - 2][x] = dark
    for y in range(1, h - 1):
        px[y][w - 2] = dark


def corner_studs(px, rgb, margin):
    """Dinh tan o bon goc — chi nam TRONG bien 9-patch nen khong bi keo gian."""
    w, h = len(px[0]), len(px)
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            if 0 <= cy + dy < h and 0 <= cx + dx < w:
                px[cy + dy][cx + dx] = rgb


# ── Panel ────────────────────────────────────────────────────────────────────

def panel_stone():
    # Da AM TONG chu khong xam trung tinh: palette du an la nau dat / vang dong,
    # panel xam lech han ra va trong nhu chua to mau.
    bg = (0x2e, 0x28, 0x21)
    mid = (0x3d, 0x35, 0x2b)
    dark = (0x18, 0x14, 0x10)
    lite = (0x5e, 0x51, 0x40)
    px = blank(48, 48, bg)
    rect(px, 2, 2, 45, 45, mid)
    # Manh da: ranh ngang + ranh doc so le, chi nam trong bien 9-patch (8px)
    # nen khong bi keo gian khi panel phong to.
    rect(px, 3, 6, 44, 6, bg)
    rect(px, 3, 41, 44, 41, bg)
    for x in (14, 33):
        rect(px, x, 3, x, 6, bg)
    for x in (22, 40):
        rect(px, x, 41, x, 44, bg)
    bevel(px, dark, lite)
    corner_studs(px, (0x8a, 0x6a, 0x1a), 8)
    return px


def panel_wood():
    bg = (0x3b, 0x2a, 0x1c)
    mid = (0x4e, 0x37, 0x24)
    dark = (0x20, 0x16, 0x0e)
    lite = (0x7a, 0x58, 0x36)
    px = blank(48, 48, bg)
    rect(px, 2, 2, 45, 45, mid)
    # Via go doc — thua, chi o vung goc
    for x in (5, 12, 35, 42):
        rect(px, x, 3, x, 44, bg)
    bevel(px, dark, lite)
    corner_studs(px, (0x8a, 0x6a, 0x1a), 8)
    return px


def panel_parchment():
    bg = (0x54, 0x44, 0x30)
    mid = (0x6b, 0x57, 0x3d)
    dark = (0x2c, 0x22, 0x17)
    lite = (0x9a, 0x80, 0x59)
    px = blank(52, 52, bg)
    rect(px, 2, 2, 49, 49, mid)
    # Vien vang trong (khung giay da co)
    frame(px, 4, (0x8a, 0x6a, 0x1a))
    bevel(px, dark, lite)
    return px


def frame_gold():
    dark = (0x3a, 0x2c, 0x08)
    gold = (0xc8, 0xa0, 0x00)
    lite = (0xf0, 0xd0, 0x50)
    px = blank(48, 48, (0, 0, 0))
    # Chi ve VIEN — ruot trong suot de long panel ben trong hien ra
    frame(px, 0, dark)
    frame(px, 1, gold)
    frame(px, 2, lite)
    frame(px, 3, gold)
    frame(px, 4, dark)
    return px, True     # True = ruot trong suot


def button(state):
    if state == 'normal':
        bg, mid, dark, lite = (0x3d, 0x2c, 0x1a), (0x52, 0x3b, 0x22), \
                              (0x1e, 0x15, 0x0c), (0x7d, 0x5d, 0x34)
    elif state == 'hover':
        bg, mid, dark, lite = (0x4c, 0x37, 0x1f), (0x66, 0x4a, 0x2a), \
                              (0x26, 0x1b, 0x0f), (0x9c, 0x76, 0x42)
    elif state == 'pressed':
        bg, mid, dark, lite = (0x2c, 0x1f, 0x12), (0x3c, 0x2b, 0x19), \
                              (0x17, 0x10, 0x09), (0x5c, 0x44, 0x26)
    else:   # disabled
        bg, mid, dark, lite = (0x33, 0x2f, 0x2a), (0x40, 0x3c, 0x36), \
                              (0x1c, 0x1a, 0x17), (0x55, 0x50, 0x49)
    px = blank(36, 36, bg)
    rect(px, 2, 2, 33, 33, mid)
    if state == 'pressed':
        # Dao bevel: sang o duoi => nut lun xuong
        frame(px, 0, dark)
        for x in range(1, 35):
            px[34][x] = lite
        for y in range(1, 35):
            px[y][34] = lite
    else:
        bevel(px, dark, lite)
    return px


def bar(kind):
    if kind == 'bg':
        bg, dark = (0x1e, 0x1a, 0x16), (0x0e, 0x0c, 0x0a)
        px = blank(24, 16, bg)
        frame(px, 0, dark)
        return px
    bg, lite = (0x8b, 0x1a, 0x1a), (0xc4, 0x3a, 0x2a)
    px = blank(24, 16, bg)
    for x in range(24):
        px[2][x] = lite
        px[3][x] = lite
    frame(px, 0, (0x4a, 0x0d, 0x0d))
    return px


def write_png(path, px, transparent_inside=False, inset=5):
    h, w = len(px), len(px[0])
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b = px[y][x]
            a = 255
            if transparent_inside and inset <= x < w - inset and inset <= y < h - inset:
                a = 0
            raw += bytes([r, g, b, a])

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    out = bytes([137, 80, 78, 71, 13, 10, 26, 10])
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    out += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(out)


def colors(px):
    return len({px[y][x] for y in range(len(px)) for x in range(len(px[0]))})


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = [
        ('panel_stone.png', panel_stone(), False),
        ('panel_wood.png', panel_wood(), False),
        ('panel_parchment.png', panel_parchment(), False),
        ('btn_normal.png', button('normal'), False),
        ('btn_hover.png', button('hover'), False),
        ('btn_pressed.png', button('pressed'), False),
        ('btn_disabled.png', button('disabled'), False),
        ('bar_bg.png', bar('bg'), False),
        ('bar_fill.png', bar('fill'), False),
    ]
    gold_px, gold_trans = frame_gold()
    jobs.append(('frame_gold.png', gold_px, gold_trans))

    worst = 0
    for name, px, trans in jobs:
        write_png(os.path.join(OUT, name), px, trans)
        c = colors(px)
        worst = max(worst, c)
        print('  %-22s %2dx%-2d  %2d mau' % (name, len(px[0]), len(px), c))
    print('da ve %d file, so mau cao nhat = %d' % (len(jobs), worst))
    return 0


if __name__ == '__main__':
    sys.exit(main())
