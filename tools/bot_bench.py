# -*- coding: utf-8 -*-
"""Chay bot nhieu lan moi bo bai roi tom tat.

    python tools/bot_bench.py            # tat ca bo, 3 lan moi bo
    python tools/bot_bench.py 5          # 5 lan moi bo
    python tools/bot_bench.py 3 deck_shogi deck_xiangqi

Ket qua ngau nhien theo tung van (huong mo rong ban do, hang trong shop) nen
MOT lan chay khong ket luan duoc gi. Doc cot "wave TB" va "thang".
"""
import concurrent.futures as cf
import glob
import os
import re
import subprocess
import sys

GODOT = os.environ.get(
    "GODOT_BIN",
    r"D:/Games/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RE_RESULT = re.compile(r"BOT_RESULT (\S+)(?: wave (\d+))? hp=(-?\d+) wave=(\d+)")
RE_ROW = re.compile(r"^(\d+),(-?\d+),(-?\d+),(\d+),([\d.]+),")
RE_BOSS = re.compile(r"^(\d+),.*BOSS ([\d.]+)/([\d.]+)=([\d.]+).*?,(-?\d+),lot=")


def one_run(deck: str, i: int) -> dict:
    """Mot van. Tra ve ket qua + duong cong HP."""
    try:
        p = subprocess.run(
            [GODOT, "--headless", "--script", "res://tools/bot_run.gd",
             "--", "deck=" + deck],
            cwd=ROOT, capture_output=True, text=True, timeout=900,
            encoding="utf-8", errors="replace")
        out = p.stdout or ""
    except subprocess.TimeoutExpired:
        return {"deck": deck, "res": "HANG", "wave": 0, "hp": 0, "curve": [], "boss": []}
    m = RE_RESULT.search(out)
    curve = []
    boss = []
    for line in out.splitlines():
        bm = RE_BOSS.match(line.strip())
        if bm:
            # (wave, ti le boss theo mo hinh, mau da mat trong wave do)
            boss.append((int(bm.group(1)), float(bm.group(4)), int(bm.group(5))))
        r = RE_ROW.match(line.strip())
        if r:
            curve.append((int(r.group(1)), int(r.group(2)),
                          int(r.group(3)), int(r.group(4)), float(r.group(5))))
    if not m:
        return {"deck": deck, "res": "ERR", "wave": 0, "hp": 0, "curve": curve, "boss": boss}
    return {"deck": deck, "res": m.group(1), "wave": int(m.group(4)),
            "hp": int(m.group(3)), "curve": curve, "boss": boss, "run": i}


def main() -> int:
    args = sys.argv[1:]
    n = 3
    if args and args[0].isdigit():
        n = int(args[0])
        args = args[1:]
    decks = args or sorted(
        os.path.splitext(os.path.basename(f))[0]
        for f in glob.glob(os.path.join(ROOT, "res/decks/*.tres")))

    jobs = [(d, i) for d in decks for i in range(n)]
    print("chay %d van (%d bo x %d lan)..." % (len(jobs), len(decks), n))
    results = []
    with cf.ThreadPoolExecutor(max_workers=4) as ex:
        futs = {ex.submit(one_run, d, i): (d, i) for d, i in jobs}
        for f in cf.as_completed(futs):
            r = f.result()
            results.append(r)
            print("  %-18s %-10s wave %2d  hp %4d"
                  % (r["deck"], r["res"], r["wave"], r["hp"]))

    print("\n%-18s %5s %6s %6s %8s %8s" %
          ("bo bai", "thang", "waveTB", "hpTB", "ratioTB", "ratioMax"))
    print("-" * 60)
    rows = []
    for d in decks:
        rs = [r for r in results if r["deck"] == d]
        if not rs:
            continue
        wins = sum(1 for r in rs if r["res"] == "THANG")
        wave = sum(r["wave"] for r in rs) / len(rs)
        hp = sum(r["hp"] for r in rs) / len(rs)
        ratios = [c[4] for r in rs for c in r["curve"]]
        rt = sum(ratios) / len(ratios) if ratios else 0.0
        rmax = max(ratios) if ratios else 0.0
        rows.append((d, wins, len(rs), wave, hp, rt, rmax))
        print("%-18s %2d/%-2d %6.1f %6.1f %8.2f %8.2f"
              % (d, wins, len(rs), wave, hp, rt, rmax))

    if len(rows) > 1:
        lo = min(r[5] for r in rows if r[5] > 0)
        hi = max(r[5] for r in rows)
        print("\nchenh lech ratio giua bo manh nhat va yeu nhat: %.1fx" % (hi / lo))

    # HIEU CHINH: ratio 1.0 phai trung ranh gioi song/chet. So ratio o wave THUA
    # voi ratio o cac wave SONG QUA. Neu hai con so nay khong kep lay 1.0 thi
    # bang so dang noi doi, du can bang co the van dung.
    died, lived = [], []
    for r in results:
        if not r["curve"]:
            continue
        last = r["curve"][-1][0]
        for c in r["curve"]:
            (died if (r["res"].startswith("THUA") and c[0] == last) else lived).append(c[4])
    if died and lived:
        dm = sum(died) / len(died)
        lm = sum(lived) / len(lived)
        print("\n--- hieu chinh bang so ---")
        print("ratio TB o wave THUA      : %.2f  (n=%d)  <- nen ~1.0" % (dm, len(died)))
        print("ratio TB o wave SONG QUA  : %.2f  (n=%d)  <- nen > 1.0" % (lm, len(lived)))
        if dm > 1.35:
            print("=> bang LAC QUAN %.1fx: no bao 'du suc' roi nguoi choi van thua." % dm)
        elif dm < 0.75:
            print("=> bang BI QUAN %.1fx: no bao 'thieu' roi nguoi choi van song." % (1.0 / max(dm, 0.01)))
        else:
            print("=> nguong 1.0 khop thuc te.")

    # WAVE BOSS tinh rieng: dieu kien thang cua no khac han (boss cham King =
    # THUA NGAY, khong lien quan mau con lai), va mo hinh phai chia hoa luc cho
    # dan ho ve. Hai thu do lam ti le boss lech khoi ti le wave thuong.
    ok_b, bad_b = [], []
    for r in results:
        for (w, ratio, hp_lost) in r.get("boss", []):
            (bad_b if hp_lost >= 20 else ok_b).append(ratio)
    if ok_b or bad_b:
        print("\n--- rieng WAVE BOSS ---")
        if ok_b:
            print("ti le boss khi QUA duoc : %.2f (n=%d)" % (sum(ok_b)/len(ok_b), len(ok_b)))
        if bad_b:
            print("ti le boss khi THUA     : %.2f (n=%d)" % (sum(bad_b)/len(bad_b), len(bad_b)))
        if ok_b and sum(ok_b)/len(ok_b) < 1.0:
            print("=> mo hinh boss BI QUAN: bao khong ha noi ma van ha duoc.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
