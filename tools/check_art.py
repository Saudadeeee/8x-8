# -*- coding: utf-8 -*-
"""Quet moi PNG trong assets/ va do SO MAU de tim anh sinh bang script.

    python tools/check_art.py

Tin hieu: pixel art VE TAY dung it mau (5-15). Anh SINH BANG SCRIPT co jitter
ngau nhien tung pixel nen ra hang tram mau tren cung kich thuoc — do la
programmer art, can ve lai.

Nguong: >40 mau tren anh <=64px. Nguong nay tach sach hai nhom trong du lieu
hien tai (art ve tay cao nhat 14 mau, anh sinh script thap nhat 48 mau) nen
khong lo bao nham.

Doc PNG bang zlib + tay — khong can thu vien ngoai.
Bao cao chi tiet: docs/ART_STATUS.md
"""
import os
import re
import struct
import sys
import zlib

PNG_MAGIC = bytes([137, 80, 78, 71, 13, 10, 26, 10])


def png_info(path):
    data = open(path, 'rb').read()
    if data[:8] != PNG_MAGIC:
        return None
    w, h = struct.unpack('>II', data[16:24])
    bit_depth, color_type = data[24], data[25]
    if bit_depth != 8 or color_type not in (6, 2):
        return (w, h, -1)
    ch = 4 if color_type == 6 else 3
    idat = b''
    i = 8
    while i < len(data):
        ln = struct.unpack('>I', data[i:i + 4])[0]
        typ = data[i + 4:i + 8]
        if typ == b'IDAT':
            idat += data[i + 8:i + 8 + ln]
        i += 12 + ln
    try:
        raw = zlib.decompress(idat)
    except Exception:
        return (w, h, -1)
    stride = w * ch
    prev = bytearray(stride)
    colors = set()
    pos = 0
    for _ in range(h):
        filt = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        for x in range(stride):
            a = line[x - ch] if x >= ch else 0
            b = prev[x]
            c = prev[x - ch] if x >= ch else 0
            if filt == 1:
                line[x] = (line[x] + a) & 255
            elif filt == 2:
                line[x] = (line[x] + b) & 255
            elif filt == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 255
        for x in range(0, stride, ch):
            px = line[x:x + ch]
            if ch == 4 and px[3] < 8:
                continue
            colors.add(bytes(px[:3]))
        prev = line
    return (w, h, len(colors))


def main():
    rows = []
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(base)
    for root, _, files in os.walk('assets'):
        if 'models' in root or '_src' in root:
            continue
        for f in sorted(files):
            if not f.endswith('.png'):
                continue
            p = os.path.join(root, f).replace(os.sep, '/')
            info = png_info(p)
            if info:
                rows.append((p,) + info)

    print('PNG quet: %d' % len(rows))
    noisy = [r for r in rows if r[3] > 40 and r[2] <= 64]
    print('\n== NGHI SINH BANG SCRIPT (>40 mau tren anh <=64px) ==')
    for p, w, h, c in sorted(noisy, key=lambda r: -r[3]):
        print('  %-52s %3dx%-3d %4d mau' % (p, w, h, c))
    print('\n== ANH LON (>64px) ==')
    for p, w, h, c in sorted([r for r in rows if r[2] > 64]):
        print('  %-52s %3dx%-4d %4d mau' % (p, w, h, c))
    clean = [r for r in rows if r[3] <= 40 and r[2] <= 64]
    print('\n== PIXEL ART SACH (<=40 mau): %d file ==' % len(clean))

    check_case()
    check_unused()


def check_case():
    """Ten file phai trung DUNG hoa-thuong voi id.

    Windows khong phan biet hoa thuong nen assets/towers/Pawn.png van nap duoc
    khi code hoi pawn.png — nhung export sang Linux thi hong. Da dinh that voi
    Pawn.png va Orc.png.
    """
    ids = set()
    for d in ('res/towers', 'res/enemy'):
        if not os.path.isdir(d):
            continue
        for f in os.listdir(d):
            if not f.endswith('.tres'):
                continue
            txt = open(os.path.join(d, f), encoding='utf-8').read()
            m = re.search(r'^id\s*=\s*"([^"]+)"', txt, re.M)
            if m:
                ids.add(m.group(1))
    bad = []
    for d in ('assets/towers', 'assets/enemy'):
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if not f.endswith('.png'):
                continue
            stem = f[:-4]
            if stem not in ids and stem.lower() in ids:
                bad.append('%s/%s  ->  nen la %s.png' % (d, f, stem.lower()))
    print()
    print('== TEN FILE LECH HOA-THUONG (hong khi export Linux) ==')
    for b in bad:
        print('  LOI  ' + b)
    if not bad:
        print('  (sach)')


def check_unused():
    """Anh khong dong code/scene/resource nao tham chieu."""
    refs = ''
    for root, _, files in os.walk('.'):
        if '.git' in root:
            continue
        for f in files:
            # .gltf PHAI co trong danh sach: model tham chieu texture cua no
            # (`<id>_0.png`…) tu ben trong file gltf, khong phai tu code.
            if not f.endswith(('.gd', '.tscn', '.tres', '.godot', '.json', '.gltf')):
                continue
            try:
                refs += open(os.path.join(root, f), encoding='utf-8',
                             errors='ignore').read()
            except Exception:
                pass
    # Thu muc nap bang CHUOI GHEP nen khong the tim theo ten file:
    #   BiomeLibrary.tex_path() dung "%s%s_%s.png" % [dir, tex_prefix, kind]
    # Bo qua de khong bao nham 25 texture dia hinh dang song.
    # KHONG BAO GIO liet ke la "chet":
    #
    # assets/textures/terrain — nap bang CHUOI GHEP, khong tim theo ten file duoc:
    #   BiomeLibrary.tex_path() dung "%s%s_%s.png" % [dir, tex_prefix, kind]
    #
    # assets/models/<id>_N.png — texture Godot TRICH XUAT khi import glTF.
    #   Khong dong code nao tro toi, nhung file .scn bien dich trong
    #   .godot/imported/ PHU THUOC vao chung. Xoa di thi CA 45 MODEL CHET, ma
    #   `--import` van bao sach vi phu thuoc chi kiem luc LOAD. Da dinh that
    #   ngay 2026-07-28 va phai khoi phuc tu git. DUNG XOA.
    BUILT_AT_RUNTIME = ('assets/textures/terrain', 'assets/models')
    dead = []
    for root, _, files in os.walk('assets'):
        if '_src' in root:
            continue
        if any(root.replace(os.sep, '/').startswith(d) for d in BUILT_AT_RUNTIME):
            continue
        for f in sorted(files):
            if not f.endswith('.png'):
                continue
            # Nhieu anh nap bang chuoi ghep `thu_muc % id` nen chi can tim ten
            # file hoac ten khong duoi la du; tim duong dan day du se bao nham.
            if f not in refs and f[:-4] not in refs:
                dead.append(os.path.join(root, f).replace(os.sep, '/'))
    print()
    print('== ANH KHONG AI THAM CHIEU: %d ==' % len(dead))
    for d in dead[:40]:
        print('  CANH  ' + d)
    if len(dead) > 40:
        print('  ... con %d file nua' % (len(dead) - 40))


if __name__ == '__main__':
    sys.exit(main())
