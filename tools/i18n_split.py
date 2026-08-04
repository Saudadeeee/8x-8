# -*- coding: utf-8 -*-
"""Tach chuoi tieng Viet thanh HAI nhom: nguoi choi thay vs chi lap trinh vien thay.

    python tools/i18n_split.py           # dem
    python tools/i18n_split.py --player  # in chuoi nguoi choi thay

Cảnh báo `push_warning` / `push_error` / `print` khong bao gio hien trong game
nen khong tinh la "ngon ngu game".
"""
import io
import re
import sys

sys.path.insert(0, 'tools')
from i18n_scan import scan  # noqa: E402

DEV = re.compile(r'push_warning|push_error|printerr|print\(')


def classify():
    player, dev = [], []
    cache = {}
    for f, line, text in scan():
        if f not in cache:
            try:
                cache[f] = io.open(f, encoding='utf-8').read().split('\n')
            except Exception:
                cache[f] = []
        lines = cache[f]
        ctx = lines[line - 1] if 0 < line <= len(lines) else ''
        (dev if DEV.search(ctx) else player).append((f, line, text))
    return player, dev


def main():
    player, dev = classify()
    if '--player' in sys.argv:
        for f, line, text in player:
            print('%s:%d\t%s' % (f, line, text))
        return 0
    print('  NGUOI CHOI thay : %d chuoi' % len(player))
    print('  chi DEV thay    : %d chuoi' % len(dev))
    per = {}
    for f, _l, _t in player:
        parts = f.split('/')
        key = '/'.join(parts[:2]) if len(parts) > 1 else parts[0]
        per[key] = per.get(key, 0) + 1
    for k in sorted(per, key=lambda x: -per[x])[:14]:
        print('    %-32s %4d' % (k, per[k]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
