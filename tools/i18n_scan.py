# -*- coding: utf-8 -*-
"""Quet chuoi tieng Viet trong ma nguon va .tres.

    python tools/i18n_scan.py            # dem theo thu muc
    python tools/i18n_scan.py --list     # in tung chuoi (de dich)

Dung de do khoi luong truoc khi doi ngon ngu, va de kiem lai sau khi doi.
"""
import glob
import io
import os
import re
import sys
import unicodedata

STR = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
PATTERNS = ['scripts/**/*.gd', 'res/**/*.tres', 'tests/**/*.gd', 'data/**/*.json']


def has_vn(text: str) -> bool:
    """Chuoi co ky tu Latin mang dau (dac trung tieng Viet) khong."""
    for ch in text:
        if ord(ch) > 127:
            name = unicodedata.name(ch, '')
            if 'LATIN' in name and ('WITH' in name or 'DONG' in name):
                return True
    return False


def scan():
    files = []
    for pat in PATTERNS:
        files.extend(glob.glob(pat, recursive=True))
    out = []
    for f in sorted(set(files)):
        try:
            src = io.open(f, encoding='utf-8').read()
        except Exception:
            continue
        for m in STR.finditer(src):
            if has_vn(m.group(1)):
                line = src[:m.start()].count('\n') + 1
                out.append((f.replace(os.sep, '/'), line, m.group(1)))
    return out


def main():
    rows = scan()
    if '--list' in sys.argv:
        for f, line, text in rows:
            print('%s:%d\t%s' % (f, line, text))
        return 0
    per = {}
    for f, _line, _t in rows:
        parts = f.split('/')
        key = '/'.join(parts[:2]) if len(parts) > 1 else parts[0]
        per[key] = per.get(key, 0) + 1
    print('  %d chuoi tieng Viet trong %d thu muc'
          % (len(rows), len(per)))
    for k in sorted(per, key=lambda x: -per[x]):
        print('    %-32s %4d' % (k, per[k]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
