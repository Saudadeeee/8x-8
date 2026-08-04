# -*- coding: utf-8 -*-
"""Quet cuoi — thay theo REGEX cho chuoi co ky tu PUA dung dau.

Bang `i18n_apply.py` khop chuoi CHINH XAC nen chuoi bat dau bang mot ky hieu
Private Use Area (glyph tu ve) khong khop duoc khi minh go bang phim thuong.
O day thay theo phan sau cua chuoi.
"""
import glob
import io
import re
import sys

# (regex, thay the) — chi doi phan tieng Viet, giu nguyen glyph dung truoc
RULES = [
    (r'(%d) tháp"', r'\1 pieces"'),
    (r'(%d) địch"', r'\1 enemies"'),
    (r'Khẩn cấp"', r'Emergency"'),
    (r'Tốc đánh"', r'Attack Speed"'),
    (r'Thiêu đốt"', r'Burn"'),
    (r'Số đạn"', r'Projectiles"'),
    (r'Hồi chiêu"', r'Cooldown"'),
    (r'Menu chính"', r'Main Menu"'),
    (r'CHƯA MỞ — cần %d điểm tích luỹ"', r'LOCKED - needs %d meta points"'),
    (r'%s — Chọn vùng thả \(%s\) · Chuột phải để huỷ"',
     r'%s - Pick a target area (%s) · Right-click to cancel"'),
    (r'%s  \[%s\]  —  %d điểm', r'%s  [%s]  —  %d pts'),
    (r'Chuẩn bị %ds%s"', r'Preparing %ds%s"'),
    (r'Chuẩn bị %ds \| %s"', r'Preparing %ds | %s"'),
    (r'Mọi %s rút ra từ nay đều mang thêm một sao\.',
     r'Every %s you draw from now on carries an extra star.'),
    (r'Loại %s khỏi bộ"', r'Remove %s from your set"'),
    (r'%s lên sao vĩnh viễn"', r'%s gains a permanent star"'),
    (r'Phong Hậu toàn bộ Tốt"', r'Promote every Pawn to Queen"'),
    (r'Mọi Tốt trong bộ hoá thành Hậu\. Bộ ít quân nhưng nặng ký\.',
     r'Every Pawn in your set becomes a Queen. Fewer pieces, far heavier.'),
    (r'Shop bán thao tác lên bộ: loại quân · nâng sao vĩnh viễn · phong Hậu\.',
     r'The shop sells set operations: remove a piece · permanent star-up · promote to Queen.'),
    (r'D hoặc ESC để đóng\.', r'Press B or ESC to close.'),
    (r'Nhấn %s để', r'Press %s to'),
]


def main() -> int:
    files = []
    for pat in ['scripts/**/*.gd', 'res/**/*.tres', 'data/**/*.json']:
        files.extend(glob.glob(pat, recursive=True))
    total = 0
    touched = 0
    for f in sorted(set(files)):
        try:
            src = io.open(f, encoding='utf-8').read()
        except Exception:
            continue
        out = src
        for pat, rep in RULES:
            out, n = re.subn(pat, rep, out)
            total += n
        if out != src:
            io.open(f, 'w', encoding='utf-8', newline='').write(out)
            touched += 1
    print('  da doi %d cho trong %d file' % (total, touched))
    return 0


if __name__ == '__main__':
    sys.exit(main())
