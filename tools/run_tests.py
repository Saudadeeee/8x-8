# -*- coding: utf-8 -*-
"""Chay toan bo bo test chuc nang cua 8x-8.

    python tools/run_tests.py            # chay het
    python tools/run_tests.py 2 4        # chi chay batch 2 va 4

Moi file trong tests/ la mot SceneTree script chay THAT: no dung game_map,
dat thap, mua do, no phan ung... roi in "OK" / "FAIL" cho tung khang dinh
va ket thuc bang "== BATCH n FAIL=x ==".

Vi sao khong dung framework co san: game can mot SceneTree that (Node3D, tween,
physics, autoload). Chay bang `--script` la cach re nhat de co dung moi truong
do ma khong phai dung headless test harness rieng.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"D:/Games/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"

TESTS = [
    ("1", "tests/test_1_core_loop.gd", "Vong lap loi: dat thap, ghep sao, sa thai, shop, o lanh tho"),
    ("2", "tests/test_2_elements.gd", "He nguyen to: Dau, 10 phan ung, khac/khang, cap o, hinh the, synergy"),
    ("3", "tests/test_3_items.gd",    "Vat pham: thuoc, trang bi, di vat"),
    ("4", "tests/test_4_waves_map.gd", "Wave, boss, ascension, mo rong ban do + rebase"),
    ("5", "tests/test_5_meta_ui.gd",  "Perk, King, encounter, meta-save, moi man UI"),
    ("6", "tests/test_6_combat_economy.gd",
     "Buff stacking, sao, giap, may trang thai pha, kinh te, thua"),
    ("7", "tests/test_7_path_arrows.gd",
     "Mui ten vang chi huong dich di (so luong, huong, ton tai qua mo rong)"),
]

# Mo rong ban do chay DFS tren ban 24x24 nen batch 4 lau hon han cac batch khac.
TIMEOUT_SECONDS = 420


def run(path):
    """Chay mot file test, tra (so_fail, so_ok, log)."""
    try:
        proc = subprocess.run(
            [GODOT, "--path", ROOT, "--script", "res://" + path],
            capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return None, 0, "TIMEOUT sau %ds" % TIMEOUT_SECONDS
    out = (proc.stdout or "") + (proc.stderr or "")
    m = re.search(r"== BATCH \d+ FAIL=(\d+) ==", out)
    n_ok = len(re.findall(r"^  OK ", out, re.M))
    if m is None:
        return None, n_ok, out
    fails = int(m.group(1))
    # Loi RUNTIME khong lam khang dinh nao that bai nhung van la bug — vi du goi
    # mot ham khong ton tai moi frame. Parse khong bat duoc (call dong), nen phai
    # soi log. Da bat duoc that: potion_controller.tick() goi nham ten ham.
    # Ca hai loai: SCRIPT ERROR (loi GDScript luc chay) va ERROR resource
    # (thieu file .png/.tres). Loai thu hai da tung lot luoi: xoa nham mot
    # sprite ma .tres van tro toi, shop im lang bo qua thap do, test van xanh.
    runtime = sorted(set(
        re.findall(r"^SCRIPT ERROR: .*$", out, re.M)
        + re.findall(r"^ERROR: (?:Failed loading resource|Resource file not found).*$",
                     out, re.M)))
    if runtime:
        fails += len(runtime)
        header = chr(10) + "-- LOI RUNTIME (moi dong tinh la 1 loi) --" + chr(10)
        out += header + chr(10).join(
            "  FAIL runtime: " + r for r in runtime)
    return fails, n_ok, out


def main():
    wanted = set(sys.argv[1:])
    todo = [t for t in TESTS if not wanted or t[0] in wanted]
    if not os.path.isfile(GODOT):
        print("Khong tim thay Godot: %s" % GODOT)
        return 2

    total_fail = 0
    total_ok = 0
    broken = []
    for key, path, desc in todo:
        print("\n" + "=" * 78)
        print("  BATCH %s — %s" % (key, desc))
        print("=" * 78)
        fails, n_ok, log = run(path)
        total_ok += n_ok
        if fails is None:
            print("  KHONG CHAY XONG — xem log duoi:")
            print("\n".join(log.splitlines()[-25:]))
            broken.append(key)
            continue
        for line in log.splitlines():
            if line.startswith("  FAIL") or line.startswith("---") or line.startswith("     "):
                print(line)
        total_fail += fails
        print("  -> %d dat, %d loi" % (n_ok, fails))

    print("\n" + "=" * 78)
    print("  TONG: %d khang dinh dat, %d loi%s"
          % (total_ok, total_fail,
             ", %d batch khong chay xong" % len(broken) if broken else ""))
    print("=" * 78)
    return 1 if (total_fail or broken) else 0


if __name__ == "__main__":
    sys.exit(main())
