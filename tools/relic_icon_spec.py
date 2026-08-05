# -*- coding: utf-8 -*-
"""Sinh bang spec cho bo icon di vat, de Aseprite ve.

    python tools/relic_icon_spec.py
    # roi qua Aseprite MCP:
    #   dofile("D:/Code/SourceCode/GameDev/8x-8/tools/relic_icons.lua")
    # roi:
    #   godot --headless --import

Script nay CHI doc du lieu va suy ra hinh/mau — no KHONG ve pixel nao. Viec ve
do Aseprite lam (art phai di qua gamedev toolkit MCP).

Hinh nen noi ngay CO CHE, doc duoc truoc khi doc chu:
  KHIEN      dieu kien   ("khi ... thi ...")
  CHONG DIA  bo dem      ("moi ... thi ...")
  CAN CONG   danh doi    (co mat trai)
  DA QUY     lai         (dieu kien + bo dem)
  CHIA KHOA  doi luat    (khong dung engine, sua CACH choi)
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "res", "relics")
OUT = os.path.join(ROOT, "tools", "relic_icon_spec.lua")
NL = chr(10)
PAT = chr(34) + "([a-z_0-9]+)" + chr(34) + ":" + chr(92) + "s*(-?" + chr(92) + "d*" + chr(92) + ".?" + chr(92) + "d+)"

THEME = {
    "piece":  ((0x9a, 0xa2, 0xac), (0xd8, 0xe0, 0xe8), (0x56, 0x5e, 0x68)),
    "vein":   ((0x2f, 0x9e, 0x6a), (0x7a, 0xe0, 0xac), (0x1c, 0x6b, 0x46)),
    "gold":   ((0xc8, 0xa0, 0x00), (0xf4, 0xdc, 0x70), (0x8a, 0x6e, 0x00)),
    "blood":  ((0x8b, 0x1a, 0x1a), (0xd8, 0x54, 0x4c), (0x5a, 0x0f, 0x0f)),
    "banner": ((0xc0, 0x6a, 0x20), (0xf0, 0xa8, 0x50), (0x7d, 0x42, 0x10)),
    "star":   ((0xe0, 0xc0, 0x40), (0xff, 0xf0, 0xa0), (0x96, 0x7c, 0x1c)),
    "time":   ((0x4a, 0x86, 0xc8), (0x8c, 0xc4, 0xf0), (0x2c, 0x56, 0x87)),
    "tool":   ((0x6b, 0x47, 0x28), (0xa8, 0x79, 0x4a), (0x43, 0x2b, 0x17)),
    "stone":  ((0x7a, 0x6a, 0x58), (0xb8, 0xa8, 0x90), (0x4c, 0x40, 0x34)),
}
RIM = {
    "rare":      ((0x4a, 0x86, 0xc8), (0x8c, 0xc4, 0xf0)),
    "epic":      ((0x7a, 0x46, 0xb0), (0xc0, 0x92, 0xe8)),
    "legendary": ((0xc8, 0xa0, 0x00), (0xf4, 0xdc, 0x70)),
}
KIND2FN = {"cond": "shield", "per": "coins", "trade": "scales",
           "hybrid": "gem", "rule": "key"}


def _sub(block: str, key: str) -> dict:
    if '"%s"' % key not in block:
        return {}
    tail = block.split('"%s"' % key, 1)[1].split("}", 1)[0]
    return dict(re.findall(r'"([a-z_0-9]+)":\s*(-?[\d.]+)', tail))


def classify(src: str):
    eff = src[src.index("effect = {"):] if "effect = {" in src else ""
    cond = _sub(eff, "cond_mult")
    per = _sub(eff, "per_mult")
    # `always` la MAT TRAI co dinh cua di vat bo dem — khong tinh la dieu kien,
    # neu khong moi di vat bo dem deu bi xep nham vao nhom "lai".
    real = {k: v for k, v in cond.items() if k != "always"}
    if per and not real:
        return "per"
    if per and real:
        return "hybrid"
    if any(float(v) < 0 for v in real.values()):
        return "trade"
    if real:
        return "cond"
    return "rule"


def theme(blob: str) -> str:
    def has(*w):
        return any(x in blob for x in w)
    if has("vein", "element", "ley", "tile", "prism", "geoman", "barren", "scorch"):
        return "vein"
    if has("pawn", "rook", "knight", "bishop", "queen", "cannon", "kind", "piece",
           "army", "horde", "muster", "cavalry", "cloister", "siege", "powder",
           "lance", "promotion", "fortress"):
        return "piece"
    if has("gold", "rich", "broke", "tithe", "coin", "chest", "purse", "levy", "quarter"):
        return "gold"
    if has("king", "hp", "martyr", "blood", "last stand", "regicide", "slayer"):
        return "blood"
    if has("formation", "banner", "drill", "march", "college", "doctrine",
           "strategy", "crown"):
        return "banner"
    if has("star", "constellation", "champion", "veteran", "perfection"):
        return "star"
    if has("wave", "boss", "late", "odd", "even", "endgame", "momentum",
           "blitz", "long war", "gambler"):
        return "time"
    if has("potion", "satchel", "spyglass", "apothec", "reactor", "anvil",
           "equip", "armory", "grip"):
        return "tool"
    return "stone"


def main() -> int:
    rows = []
    for f in sorted(os.listdir(SRC)):
        if not f.endswith(".tres"):
            continue
        s = io.open(os.path.join(SRC, f), encoding="utf-8").read()

        def g(k, d=""):
            m = re.search(r'^%s = "([^"]*)"' % k, s, re.M)
            return m.group(1) if m else d

        rid, rar = g("id"), g("rarity", "epic")
        blob = (rid + " " + g("name") + " " + g("desc")).lower()
        b, l, d = THEME[theme(blob)]
        rb, rl = RIM.get(rar, RIM["epic"])
        rows.append('{id="%s",fn="%s",b={%d,%d,%d},l={%d,%d,%d},d={%d,%d,%d},'
                    'rb={%d,%d,%d},rl={%d,%d,%d}}'
                    % ((rid, KIND2FN[classify(s)]) + b + l + d + rb + rl))
    payload = "return {" + NL + ("," + NL).join(rows) + NL + "}" + NL
    io.open(OUT, "w", encoding="ascii").write(payload)
    print("sinh %d dong spec -> %s" % (len(rows), OUT))
    print("buoc tiep: Aseprite MCP dofile tools/relic_icons.lua, roi godot --headless --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())
