# -*- coding: utf-8 -*-
"""Ap bang dich tieng Viet -> tieng Anh len ma nguon va .tres.

    python tools/i18n_apply.py tools/i18n_map_1.py

Bang dich la mot file Python khai `MAP = {"chuoi Viet": "English", ...}`.

Vi sao lam bang cong cu chu khong sua tay: 1175 chuoi duy nhat nam rai o 28 thu
muc; sua tay thi chac chan bo sot va chac chan go nham. Cong cu thay THEO CHUOI
CHINH XAC nen khong bao gio doi nham mot phan chuoi khac.

An toan:
  - Chi thay chuoi nam TRONG dau nhay kep (khong dung vao chu thich).
  - Chuoi dai duoc thay TRUOC chuoi ngan, tranh chuoi ngan an mot phan chuoi dai.
  - In ra chuoi trong bang MA KHONG TIM THAY trong ma nguon (bang da loi thoi).
"""
import glob
import io
import os
import re
import sys

PATTERNS = ['scripts/**/*.gd', 'res/**/*.tres', 'tests/**/*.gd', 'data/**/*.json']


def load_map(path: str) -> dict:
    ns = {}
    src = io.open(path, encoding='utf-8').read()
    exec(compile(src, path, 'exec'), ns)
    return ns['MAP']


def main() -> int:
    if len(sys.argv) < 2:
        print('dung: python tools/i18n_apply.py <file_bang_dich.py>')
        return 1
    table = load_map(sys.argv[1])
    # Chuoi DAI thay truoc: neu khong, mot chuoi ngan la con cua chuoi dai se
    # an mat mot doan va phan con lai thanh rac.
    keys = sorted(table.keys(), key=len, reverse=True)

    files = []
    for pat in PATTERNS:
        files.extend(glob.glob(pat, recursive=True))
    files = sorted(set(files))

    hits = {k: 0 for k in keys}
    changed = 0
    for f in files:
        try:
            src = io.open(f, encoding='utf-8').read()
        except Exception:
            continue
        out = src
        for k in keys:
            needle = '"' + k + '"'
            if needle in out:
                n = out.count(needle)
                out = out.replace(needle, '"' + table[k] + '"')
                hits[k] += n
        if out != src:
            io.open(f, 'w', encoding='utf-8', newline='').write(out)
            changed += 1

    total = sum(hits.values())
    missing = [k for k in keys if hits[k] == 0]
    print('  da doi %d cho trong %d file' % (total, changed))
    if missing:
        print('  %d muc trong bang KHONG tim thay (bang loi thoi?):' % len(missing))
        for k in missing[:20]:
            print('    %s' % k[:70])
    return 0


if __name__ == '__main__':
    sys.exit(main())
