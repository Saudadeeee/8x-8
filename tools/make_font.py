# -*- coding: utf-8 -*-
"""Sinh font pixel cho 8x-8: atlas PNG + file .fnt (AngelCode).

    python tools/make_font.py

Vi sao tu lam font: font mac dinh cua Godot (Open Sans) khong hop chu de pixel
art trung co, va no KHONG CO cac ky hieu game dang dung (sao, kiem, so dua...).
Tren Windows chung van hien nho Godot muon font he thong — nhung export sang
Linux/macOS la thanh o vuong rong.

Font nay giai quyet ca hai: dung phong cach pixel, va CHUA SAN moi ky hieu game
can nen khong con phu thuoc font he thong.

Thiet ke:
  - Than chu 5x7 pixel, kieu bitmap co dien, net 1px — doc duoc o co nho.
  - O chua 9 rong x 14 cao: chua 3 hang TREN cho dau tieng Viet chong nhau
    (vd "e" + dau mu + dau sac) va 2 hang DUOI cho dau nang / duoi chu g,y.
  - Chu Viet co dau duoc GHEP tu chu goc + dau, khong ve tay 134 lan.
  - Be rong moi chu tinh theo vung muc that (variable width), khong monospace.

Xuat ra:
  assets/fonts/pixel_8x8.png   — atlas
  assets/fonts/pixel_8x8.fnt   — mo ta AngelCode, Godot doc bang
                                 FontFile.load_bitmap_font()
"""
import io
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, 'assets', 'fonts')
PNG_PATH = os.path.join(OUT_DIR, 'pixel_8x8.png')
FNT_PATH = os.path.join(OUT_DIR, 'pixel_8x8.fnt')

CELL_W, CELL_H = 9, 14
# Than chu chiem hang 4..10 (7 hang). Tren no la vung dau, duoi la vung duoi chu.
BODY_TOP = 4
BASELINE = BODY_TOP + 7        # hang ngay duoi than chu = 11
COLS = 24                       # so o moi hang trong atlas


def G(*rows):
    """Chuyen cac dong '.#' thanh danh sach toa do pixel."""
    out = []
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '#':
                out.append((x, y))
    return out


# ── CHU HOA ──────────────────────────────────────────────────────────────────
UPPER = {
 'A': G('.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'),
 'B': G('####.', '#...#', '####.', '#...#', '#...#', '#...#', '####.'),
 'C': G('.####', '#....', '#....', '#....', '#....', '#....', '.####'),
 'D': G('####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'),
 'E': G('#####', '#....', '####.', '#....', '#....', '#....', '#####'),
 'F': G('#####', '#....', '####.', '#....', '#....', '#....', '#....'),
 'G': G('.####', '#....', '#....', '#..##', '#...#', '#...#', '.####'),
 'H': G('#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'),
 'I': G('.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'),
 'J': G('..###', '...#.', '...#.', '...#.', '...#.', '#..#.', '.##..'),
 'K': G('#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'),
 'L': G('#....', '#....', '#....', '#....', '#....', '#....', '#####'),
 'M': G('#...#', '##.##', '#.#.#', '#...#', '#...#', '#...#', '#...#'),
 'N': G('#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'),
 'O': G('.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'),
 'P': G('####.', '#...#', '#...#', '####.', '#....', '#....', '#....'),
 'Q': G('.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'),
 'R': G('####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'),
 'S': G('.####', '#....', '#....', '.###.', '....#', '....#', '####.'),
 'T': G('#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'),
 'U': G('#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'),
 'V': G('#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'),
 'W': G('#...#', '#...#', '#...#', '#...#', '#.#.#', '##.##', '#...#'),
 'X': G('#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'),
 'Y': G('#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'),
 'Z': G('#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'),
}

# ── CHU THUONG ───────────────────────────────────────────────────────────────
# Cao 5 hang (hang 2..6 cua than), tru chu co net vuot len/xuong.
LOWER = {
 'a': G('.....', '.###.', '....#', '.####', '#...#', '#...#', '.####'),
 'b': G('#....', '#....', '####.', '#...#', '#...#', '#...#', '####.'),
 'c': G('.....', '.....', '.####', '#....', '#....', '#....', '.####'),
 'd': G('....#', '....#', '.####', '#...#', '#...#', '#...#', '.####'),
 'e': G('.....', '.....', '.###.', '#...#', '#####', '#....', '.####'),
 'f': G('..##.', '.#...', '.#...', '####.', '.#...', '.#...', '.#...'),
 'g': G('.....', '.####', '#...#', '#...#', '.####', '....#', '.###.'),
 'h': G('#....', '#....', '####.', '#...#', '#...#', '#...#', '#...#'),
 'i': G('..#..', '.....', '.##..', '..#..', '..#..', '..#..', '.###.'),
 'j': G('...#.', '.....', '..##.', '...#.', '...#.', '#..#.', '.##..'),
 'k': G('#....', '#....', '#..#.', '#.#..', '##...', '#.#..', '#..#.'),
 'l': G('.##..', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'),
 'm': G('.....', '.....', '##.#.', '#.#.#', '#.#.#', '#.#.#', '#.#.#'),
 'n': G('.....', '.....', '####.', '#...#', '#...#', '#...#', '#...#'),
 'o': G('.....', '.....', '.###.', '#...#', '#...#', '#...#', '.###.'),
 'p': G('.....', '####.', '#...#', '#...#', '####.', '#....', '#....'),
 'q': G('.....', '.####', '#...#', '#...#', '.####', '....#', '....#'),
 'r': G('.....', '.....', '#.##.', '##...', '#....', '#....', '#....'),
 's': G('.....', '.....', '.####', '#....', '.###.', '....#', '####.'),
 't': G('.#...', '.#...', '####.', '.#...', '.#...', '.#..#', '..##.'),
 'u': G('.....', '.....', '#...#', '#...#', '#...#', '#...#', '.####'),
 'v': G('.....', '.....', '#...#', '#...#', '#...#', '.#.#.', '..#..'),
 'w': G('.....', '.....', '#...#', '#.#.#', '#.#.#', '#.#.#', '.#.#.'),
 'x': G('.....', '.....', '#...#', '.#.#.', '..#..', '.#.#.', '#...#'),
 'y': G('.....', '#...#', '#...#', '#...#', '.####', '....#', '.###.'),
 'z': G('.....', '.....', '#####', '...#.', '..#..', '.#...', '#####'),
}

DIGITS = {
 '0': G('.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'),
 '1': G('..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'),
 '2': G('.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'),
 '3': G('####.', '....#', '....#', '.###.', '....#', '....#', '####.'),
 '4': G('...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'),
 '5': G('#####', '#....', '####.', '....#', '....#', '#...#', '.###.'),
 '6': G('..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.'),
 '7': G('#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'),
 '8': G('.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'),
 '9': G('.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..'),
}

PUNCT = {
 ' ': [],
 '!': G('..#..', '..#..', '..#..', '..#..', '..#..', '.....', '..#..'),
 '"': G('.#.#.', '.#.#.', '.....', '.....', '.....', '.....', '.....'),
 '#': G('.#.#.', '#####', '.#.#.', '#####', '.#.#.', '.....', '.....'),
 '$': G('..#..', '.####', '#.#..', '.###.', '..#.#', '####.', '..#..'),
 '%': G('##..#', '##.#.', '..#..', '.#...', '#.##.', '#.##.', '.....'),
 '&': G('.##..', '#..#.', '.##..', '#..#.', '#...#', '#..#.', '.##.#'),
 "'": G('..#..', '..#..', '.....', '.....', '.....', '.....', '.....'),
 '(': G('...#.', '..#..', '.#...', '.#...', '.#...', '..#..', '...#.'),
 ')': G('.#...', '..#..', '...#.', '...#.', '...#.', '..#..', '.#...'),
 '*': G('.....', '#.#.#', '.###.', '#####', '.###.', '#.#.#', '.....'),
 '+': G('.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'),
 ',': G('.....', '.....', '.....', '.....', '.....', '..#..', '.#...'),
 '-': G('.....', '.....', '.....', '#####', '.....', '.....', '.....'),
 '.': G('.....', '.....', '.....', '.....', '.....', '.....', '..#..'),
 '/': G('....#', '....#', '...#.', '..#..', '.#...', '#....', '#....'),
 ':': G('.....', '..#..', '.....', '.....', '.....', '..#..', '.....'),
 ';': G('.....', '..#..', '.....', '.....', '..#..', '..#..', '.#...'),
 '<': G('...#.', '..#..', '.#...', '#....', '.#...', '..#..', '...#.'),
 '=': G('.....', '.....', '#####', '.....', '#####', '.....', '.....'),
 '>': G('.#...', '..#..', '...#.', '....#', '...#.', '..#..', '.#...'),
 '?': G('.###.', '#...#', '....#', '...#.', '..#..', '.....', '..#..'),
 '@': G('.###.', '#...#', '#.###', '#.#.#', '#.###', '#....', '.###.'),
 '[': G('.###.', '.#...', '.#...', '.#...', '.#...', '.#...', '.###.'),
 '\\': G('#....', '#....', '.#...', '..#..', '...#.', '....#', '....#'),
 ']': G('.###.', '...#.', '...#.', '...#.', '...#.', '...#.', '.###.'),
 '^': G('..#..', '.#.#.', '#...#', '.....', '.....', '.....', '.....'),
 '_': G('.....', '.....', '.....', '.....', '.....', '.....', '#####'),
 '`': G('.#...', '..#..', '.....', '.....', '.....', '.....', '.....'),
 '{': G('..##.', '..#..', '..#..', '.#...', '..#..', '..#..', '..##.'),
 '|': G('..#..', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'),
 '}': G('.##..', '..#..', '..#..', '...#.', '..#..', '..#..', '.##..'),
 '~': G('.....', '.....', '.##.#', '#..#.', '.....', '.....', '.....'),
}

# ── KY HIEU GAME ─────────────────────────────────────────────────────────────
# Ve theo phong cach trung co: net day, doc duoc o co nho.
SYMBOLS = {
 '★': G('..#..', '..#..', '#####', '.###.', '.###.', '#...#', '.....'),
 '♥': G('.#.#.', '#####', '#####', '#####', '.###.', '..#..', '.....'),
 '❤': G('.#.#.', '#####', '#####', '#####', '.###.', '..#..', '.....'),
 '◆': G('..#..', '.###.', '#####', '#####', '#####', '.###.', '..#..'),
 '◈': G('..#..', '.#.#.', '#.#.#', '##.##', '#.#.#', '.#.#.', '..#..'),
 '●': G('.....', '.###.', '#####', '#####', '#####', '.###.', '.....'),
 '◎': G('.....', '.###.', '#...#', '#.#.#', '#...#', '.###.', '.....'),
 '⬢': G('.....', '.###.', '#####', '#####', '#####', '.###.', '.....'),
 '▣': G('#####', '#...#', '#.#.#', '#.#.#', '#.#.#', '#...#', '#####'),
 '•': G('.....', '.....', '..#..', '.###.', '..#..', '.....', '.....'),
 '·': G('.....', '.....', '.....', '..#..', '.....', '.....', '.....'),
 '∈': G('..###', '.#...', '.#...', '.####', '.#...', '.#...', '..###'),
 '✦': G('..#..', '..#..', '#.#.#', '.###.', '#.#.#', '..#..', '..#..'),
 '✷': G('#.#.#', '.###.', '..#..', '#####', '..#..', '.###.', '#.#.#'),
 '☯': G('.###.', '#.#.#', '#.#.#', '#...#', '#.#.#', '#.#.#', '.###.'),
 '⚔': G('#...#', '.#.#.', '..#..', '.###.', '..#..', '.#.#.', '#...#'),
 '🗡': G('...##', '..##.', '.##..', '###..', '##...', '#....', '.....'),
 '✕': G('#...#', '.#.#.', '..#..', '.#.#.', '#...#', '.....', '.....'),
 '✖': G('#...#', '.#.#.', '..#..', '.#.#.', '#...#', '.....', '.....'),
 '×': G('.....', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '.....'),
 '✓': G('....#', '...#.', '#..#.', '#.#..', '.##..', '.#...', '.....'),
 '☠': G('.###.', '#.#.#', '#####', '.###.', '#.#.#', '#####', '.....'),
 '⚠': G('..#..', '..#..', '.#.#.', '.#.#.', '#..##', '#####', '.....'),
 '⚑': G('#####', '#####', '#####', '#....', '#....', '#....', '#....'),
 '▶': G('#....', '##...', '###..', '####.', '###..', '##...', '#....'),
 '◀': G('....#', '...##', '..###', '.####', '..###', '...##', '....#'),
 '▸': G('.....', '.#...', '.##..', '.###.', '.##..', '.#...', '.....'),
 '›': G('.....', '.#...', '..#..', '...#.', '..#..', '.#...', '.....'),
 '‹': G('.....', '...#.', '..#..', '.#...', '..#..', '...#.', '.....'),
 '»': G('.....', '#.#..', '.#.#.', '..#.#', '.#.#.', '#.#..', '.....'),
 '«': G('.....', '..#.#', '.#.#.', '#.#..', '.#.#.', '..#.#', '.....'),
 '…': G('.....', '.....', '.....', '.....', '.....', '.....', '#.#.#'),
 '‡': G('..#..', '#####', '..#..', '#####', '..#..', '..#..', '.....'),
 '†': G('..#..', '#####', '..#..', '..#..', '..#..', '..#..', '.....'),
 '°': G('.##..', '#..#.', '.##..', '.....', '.....', '.....', '.....'),
 '·': G('.....', '.....', '.....', '..#..', '.....', '.....', '.....'),
 '▲': G('..#..', '..#..', '.###.', '.###.', '#####', '#####', '.....'),
 '▼': G('.....', '#####', '#####', '.###.', '.###.', '..#..', '..#..'),
 '⏸': G('.#.#.', '.#.#.', '.#.#.', '.#.#.', '.#.#.', '.#.#.', '.....'),
 '⏱': G('..#..', '.###.', '#.#.#', '#.##.', '#...#', '.###.', '.....'),
 '♛': G('#.#.#', '#####', '#####', '.###.', '.###.', '#####', '.....'),
 '🛡': G('#####', '#...#', '#...#', '#...#', '.#.#.', '..#..', '.....'),
 '❄': G('#.#.#', '.###.', '#####', '.###.', '#.#.#', '.....', '.....'),
 '⛁': G('.###.', '#####', '.###.', '#####', '.###.', '.....', '.....'),
 '⚙': G('#.#.#', '.###.', '##.##', '.###.', '#.#.#', '.....', '.....'),
 '⚒': G('###..', '.#.##', '.###.', '###..', '#..##', '.....', '.....'),
 '—': G('.....', '.....', '.....', '#####', '.....', '.....', '.....'),
 '−': G('.....', '.....', '.....', '#####', '.....', '.....', '.....'),
 '→': G('.....', '..#..', '...#.', '#####', '...#.', '..#..', '.....'),
 '←': G('.....', '..#..', '.#...', '#####', '.#...', '..#..', '.....'),
 '＋': G('.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'),
}


# ── KY HIEU GAME DAT TRONG PRIVATE USE AREA (U+E0xx) ─────────────────────────
# 16 ky tu duoi day co thuoc tinh Unicode `Emoji_Presentation=Yes` (⚡ 🔥 🌍 …).
# HarfBuzz/TextServer se ep chung sang FONT EMOJI CUA HE THONG bat ke font chinh
# co glyph hay khong — do bang advance: 19px thay vi 6px, va ve ra mau cam.
# PUA khong co thuoc tinh Unicode nao nen khong bao gio bi dinh sang font khac.
# Ten hang so tuong ung nam trong scripts/ui/glyphs.gd.
PUA = {
 0xE001: G('..#..', '..##.', '.###.', '.####', '#####', '#####', '.###.'),  # lua
 0xE002: G('...##', '..##.', '.##..', '#####', '..##.', '.##..', '##...'),  # set
 0xE003: G('.###.', '#.#.#', '##..#', '#.###', '#.#.#', '.###.', '.....'),  # vung dat
 0xE004: G('.###.', '#...#', '#.#.#', '#.#.#', '#...#', '.###.', '.....'),  # ngam
 0xE005: G('.###.', '..#..', '..#..', '.###.', '#####', '#####', '.###.'),  # binh thuoc
 0xE006: G('..#..', '.###.', '#####', '#...#', '#.#.#', '#.#.#', '.....'),  # nha
 0xE007: G('.###.', '#...#', '#####', '#.#.#', '#####', '.....', '.....'),  # khoa
 0xE008: G('#.#.#', '#####', '#####', '.###.', '.###.', '#####', '.....'),  # vuong mien
 0xE009: G('##...', '###..', '.###.', '..###', '...##', '.....', '.....'),  # co le
 0xE00A: G('#####', '#.#.#', '#...#', '#####', '#.###', '#####', '.....'),  # luu
 0xE00B: G('..#..', '..#..', '.###.', '#####', '#####', '.###.', '.....'),  # giot nuoc
 0xE00C: G('.....', '.###.', '#####', '#####', '#####', '.....', '.....'),  # da
 0xE00D: G('#####', '.###.', '..#..', '.#.#.', '#####', '.....', '.....'),  # dong ho cat
 0xE00E: G('#####', '#.#.#', '#...#', '#.#.#', '#####', '.....', '.....'),  # xuc xac
 0xE00F: G('..#..', '..#..', '#####', '.###.', '.###.', '#...#', '.....'),  # sao
 0xE010: G('#.#.#', '.###.', '##.##', '.###.', '#.#.#', '.....', '.....'),  # no
}

# ── DAU TIENG VIET ───────────────────────────────────────────────────────────
# Toa do tinh tu goc tren-trai cua THAN chu; y am = nam tren than.
MARK_ABOVE = {
 'grave':  G('.#...', '..#..'),
 'acute':  G('...#.', '..#..'),
 'hook':   G('..##.', '..#..'),
 'tilde':  G('.##.#', '#..##'),
 'circ':   G('..#..', '.#.#.'),
 'breve':  G('#...#', '.###.'),
}
DOT_BELOW = G('..#..')
HORN = G('...##', '....#')

# Chu goc + dau nao. Khoa = ky tu tieng Viet precomposed.
VN = {
 'a': {'à':['grave'], 'á':['acute'], 'ả':['hook'], 'ã':['tilde'], 'ạ':['dot'],
       'â':['circ'], 'ầ':['circ','grave'], 'ấ':['circ','acute'],
       'ẩ':['circ','hook'], 'ẫ':['circ','tilde'], 'ậ':['circ','dot'],
       'ă':['breve'], 'ằ':['breve','grave'], 'ắ':['breve','acute'],
       'ẳ':['breve','hook'], 'ẵ':['breve','tilde'], 'ặ':['breve','dot']},
 'e': {'è':['grave'], 'é':['acute'], 'ẻ':['hook'], 'ẽ':['tilde'], 'ẹ':['dot'],
       'ê':['circ'], 'ề':['circ','grave'], 'ế':['circ','acute'],
       'ể':['circ','hook'], 'ễ':['circ','tilde'], 'ệ':['circ','dot']},
 'i': {'ì':['grave'], 'í':['acute'], 'ỉ':['hook'], 'ĩ':['tilde'], 'ị':['dot']},
 'o': {'ò':['grave'], 'ó':['acute'], 'ỏ':['hook'], 'õ':['tilde'], 'ọ':['dot'],
       'ô':['circ'], 'ồ':['circ','grave'], 'ố':['circ','acute'],
       'ổ':['circ','hook'], 'ỗ':['circ','tilde'], 'ộ':['circ','dot'],
       'ơ':['horn'], 'ờ':['horn','grave'], 'ớ':['horn','acute'],
       'ở':['horn','hook'], 'ỡ':['horn','tilde'], 'ợ':['horn','dot']},
 'u': {'ù':['grave'], 'ú':['acute'], 'ủ':['hook'], 'ũ':['tilde'], 'ụ':['dot'],
       'ư':['horn'], 'ừ':['horn','grave'], 'ứ':['horn','acute'],
       'ử':['horn','hook'], 'ữ':['horn','tilde'], 'ự':['horn','dot']},
 'y': {'ỳ':['grave'], 'ý':['acute'], 'ỷ':['hook'], 'ỹ':['tilde'], 'ỵ':['dot']},
}
D_STROKE = G('.....', '.....', '.....', '###..', '.....', '.....', '.....')


def compose(base_pixels, marks):
    """Ghep chu goc voi cac dau. Tra ve danh sach pixel trong he toa do than chu
    (y co the AM = nam tren than, hoac > 6 = nam duoi)."""
    out = list(base_pixels)
    above_level = 0
    for m in marks:
        if m == 'dot':
            out += [(x, 8 + y) for x, y in DOT_BELOW]
        elif m == 'horn':
            out += HORN
        else:
            rows = MARK_ABOVE[m]
            # Dau thu hai xep CAO hon dau thu nhat
            dy = -2 - (2 * above_level)
            out += [(x, y + dy) for x, y in rows]
            above_level += 1
    return out


def build_glyphs():
    """Tra ve dict codepoint -> danh sach pixel (he toa do than chu)."""
    glyphs = {}
    for table in (UPPER, LOWER, DIGITS, PUNCT, SYMBOLS):
        for ch, px in table.items():
            glyphs[ord(ch)] = px
    glyphs.update(PUA)

    # Chu Viet co dau: thuong va HOA
    for base, mapping in VN.items():
        for ch, marks in mapping.items():
            glyphs[ord(ch)] = compose(LOWER[base], marks)
            up = ch.upper()
            if len(up) == 1:
                glyphs[ord(up)] = compose(UPPER[base.upper()], marks)
    # đ / Đ
    glyphs[ord('đ')] = list(LOWER['d']) + D_STROKE
    glyphs[ord('Đ')] = list(UPPER['D']) + G('.....', '.....', '.....', '###..',
                                            '.....', '.....', '.....')
    return glyphs


def write_png(path, width, height, pixels):
    """Ghi PNG RGBA8. `pixels` la set (x, y) mau trang duc."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            if (x, y) in pixels:
                raw += bytes([255, 255, 255, 255])
            else:
                raw += bytes([255, 255, 255, 0])

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    png = bytes([137, 80, 78, 71, 13, 10, 26, 10])
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


def _scaled_path(path, k):
    base, ext = os.path.splitext(path)
    return '%s@%dx%s' % (base, k, ext)


def _write_fnt(fnt_path, png_path, entries, atlas_w, atlas_h, k):
    """Ghi .fnt cho ban phong k lan — moi so do deu nhan k."""
    lines = [
        'info face="8x8 Pixel" size=%d bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1' % (CELL_H * k),
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0'
        % (CELL_H * k, BASELINE * k, atlas_w, atlas_h),
        'page id=0 file="%s"' % os.path.basename(png_path),
        'chars count=%d' % len(entries),
    ]
    for cp, cx, cy, advance, x_off in entries:
        lines.append(
            'char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=0 '
            'xadvance=%d page=0 chnl=15'
            % (cp, cx * k, cy * k, CELL_W * k, CELL_H * k, x_off * k, advance * k))
    with io.open(fnt_path, 'w', encoding='utf-8', newline=chr(10)) as f:

        f.write(chr(10).join(lines) + chr(10))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    glyphs = build_glyphs()
    codes = sorted(glyphs)
    rows = (len(codes) + COLS - 1) // COLS
    atlas_w, atlas_h = COLS * CELL_W, rows * CELL_H

    pixels = set()
    entries = []
    for idx, cp in enumerate(codes):
        cx = (idx % COLS) * CELL_W
        cy = (idx // COLS) * CELL_H
        body = glyphs[cp]
        min_x, max_x = 99, -1
        for gx, gy in body:
            px = cx + 1 + gx
            py = cy + BODY_TOP + gy
            if 0 <= py - cy < CELL_H and 0 <= px - cx < CELL_W:
                pixels.add((px, py))
                min_x = min(min_x, gx)
                max_x = max(max_x, gx)
        # Khoang trang: khong co muc thi cho be rong co dinh
        advance = 4 if max_x < 0 else (max_x - min_x) + 2
        x_off = 0 if max_x < 0 else -min_x
        entries.append((cp, cx, cy, advance, x_off))

    write_png(PNG_PATH, atlas_w, atlas_h, pixels)

    # ── Ban PHONG TO nguyen ban ──────────────────────────────────────────────
    # Vi sao can: Godot noi suy khi phong font bitmap len — do duoc 11 mau khac
    # nhau o co 28 thay vi 1. Voi game pixel art thi do la chu nhoe. Nuong san
    # atlas 2x/3x bang cach NHAN toa do (moi pixel thanh khoi k x k) nen khong
    # co mot buoc noi suy nao. rebuild_font_resource.gd nap ca ba vao MOT
    # FontFile lam ba co cache 14 / 28 / 42.
    for k in (2, 3):
        big = set()
        for px, py in pixels:
            for dy in range(k):
                for dx in range(k):
                    big.add((px * k + dx, py * k + dy))
        write_png(_scaled_path(PNG_PATH, k), atlas_w * k, atlas_h * k, big)
        _write_fnt(_scaled_path(FNT_PATH, k), _scaled_path(PNG_PATH, k),
                   entries, atlas_w * k, atlas_h * k, k)

    lines = [
        'info face="8x8 Pixel" size=%d bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1' % CELL_H,
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0'
        % (CELL_H, BASELINE, atlas_w, atlas_h),
        'page id=0 file="%s"' % os.path.basename(PNG_PATH),
        'chars count=%d' % len(entries),
    ]
    for cp, cx, cy, advance, x_off in entries:
        lines.append(
            'char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=0 '
            'xadvance=%d page=0 chnl=15'
            % (cp, cx, cy, CELL_W, CELL_H, x_off, advance))
    with io.open(FNT_PATH, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')

    print('atlas : %s  (%dx%d, %d glyph)' % (PNG_PATH, atlas_w, atlas_h, len(codes)))
    print('mo ta : %s' % FNT_PATH)
    print()
    print('!! CHUA XONG — .tres la SNAPSHOT cua .fnt, khong tu doc lai. Chay tiep:')
    print('   godot --headless --path . --script res://tools/rebuild_font_resource.gd')
    return 0


if __name__ == '__main__':
    sys.exit(main())
