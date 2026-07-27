#!/usr/bin/env python3
"""Kiểm tra "đấu nối" của dự án 8x-8 — chạy: python tools/audit_wiring.py

VÌ SAO TỒN TẠI
Lớp lỗi hay gặp nhất ở dự án này KHÔNG phải crash mà là **tính năng chết âm
thầm**: một khoá dữ liệu / field / signal được KHAI BÁO và GHI ra, nhưng không
có ai ĐỌC. Game vẫn chạy, test vẫn xanh, chỉ là món đồ đó chẳng làm gì cả.
Đã dính nhiều lần: thưởng hình thế, `reaction_mult` của cấp ô, `projectile_bonus`
của thuốc, `rotate_marks` của Trận Vòng, `relic_tile_merge_anywhere`.

Script này quét tĩnh và in ra NGHI VẤN — không phải kết luận. Mỗi mục phải soi
tay để xác nhận (nhiều chỗ đọc field qua CHUỖI như `gm.get("x")` hoặc
`_perk_float("x")`, script đã tính tới nhưng vẫn có thể sót).

Chạy sau mỗi lần thêm cơ chế mới. Không thay thế test hành vi.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "scripts")

files = {}
for dirpath, _dirs, names in os.walk(SRC):
    for n in names:
        if n.endswith(".gd"):
            p = os.path.join(dirpath, n)
            files[p] = io.open(p, encoding="utf-8").read()

if not files:
    print("Không tìm thấy file .gd nào trong", SRC)
    sys.exit(1)

ALL = "\n".join(files.values())
findings = 0


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def report(title, rows):
    global findings
    print("\n" + "=" * 78)
    print(title)
    print("=" * 78)
    if not rows:
        print("  (sạch)")
        return
    findings += len(rows)
    for r in rows:
        print("  " + r)


def is_read_anywhere(name, exclude=None):
    """Field có bị ĐỌC ở đâu không — tính cả đọc qua chuỗi.

    Ba dạng đọc trong dự án:
      obj.field          (truy cập trực tiếp)
      obj.get("field")   (duck typing qua Node)
      _perk_float("field") / for f in ["field", ...]   (chuỗi trong helper/mảng)
    """
    for p, s in files.items():
        if exclude and p.endswith(exclude):
            continue
        if re.search(r'"%s"' % re.escape(name), s):
            return True
        if re.search(r"\.%s\b(?!\s*=[^=])" % re.escape(name), s):
            return True
    return False


# ── 1. Signal có emit nhưng không ai connect ─────────────────────────────
rows = []
for p, s in files.items():
    for m in re.finditer(r"^signal\s+(\w+)", s, re.M):
        name = m.group(1)
        connected = (re.search(r"\.%s\.connect" % name, ALL)
                     or re.search(r'connect\(\s*"%s"' % name, ALL))
        emitted = re.search(r"%s\.emit\(" % name, ALL)
        if emitted and not connected:
            rows.append("%-44s signal '%s' CÓ emit, KHÔNG ai nghe" % (rel(p), name))
report("1. Signal phát ra nhưng không có người nghe", rows)

# ── 2. Field GameManager do hệ khác ghi mà không ai đọc ──────────────────
rows = []
gm_path = os.path.join(SRC, "managers", "GameManager.gd")
if gm_path in files:
    gm = files[gm_path]
    prefixes = ("perk_", "relic_", "syn_", "biome_", "crystal_", "global_", "bagua")
    for m in re.finditer(r"^var\s+(\w+)", gm, re.M):
        f = m.group(1)
        if not f.startswith(prefixes):
            continue
        if not is_read_anywhere(f, exclude="GameManager.gd"):
            rows.append("GameManager.%s — được ghi nhưng KHÔNG nơi nào đọc" % f)
report("2. Field GameManager ghi mà không ai đọc", rows)

# ── 3. Khoá EFFECT_KEYS (trang bị / di vật) không có nơi tiêu thụ ────────
rows = []
for fname, label in [("items/equipment_system.gd", "TRANG BỊ"),
                     ("items/relic_system.gd", "DI VẬT")]:
    p = os.path.join(SRC, *fname.split("/"))
    if p not in files:
        continue
    s = files[p]
    m = re.search(r"const EFFECT_KEYS[^=]*=\s*\[(.*?)\]", s, re.S)
    if not m:
        continue
    for k in re.findall(r'"(\w+)"', m.group(1)):
        # tiêu thụ = xuất hiện ngoài chính danh sách khai báo
        occurrences = len(re.findall(r'"%s"' % k, ALL))
        if occurrences <= 1:
            rows.append("%s: khoá '%s' khai trong EFFECT_KEYS mà không nơi nào dùng"
                        % (label, k))
report("3. Khoá vật phẩm khai mà không tiêu thụ", rows)

# ── 4. Bảng BONUS của hình thế: khoá không ai đọc ────────────────────────
rows = []
p = os.path.join(SRC, "elements", "formation_detector.gd")
if p in files:
    m = re.search(r"const BONUS[^=]*=\s*\{(.*?)\n\}", files[p], re.S)
    if m:
        for k in sorted(set(re.findall(r'"(\w+)"\s*:', m.group(1)))):
            if k in ("dragon_line", "four_pillar", "dual_pole", "ring"):
                continue   # id hình thế, không phải khoá thưởng
            readers = [rel(q) for q, t in files.items()
                       if q != p and (re.search(r'get\(\s*"%s"' % k, t)
                                      or re.search(r'\["%s"\]' % k, t))]
            if not readers:
                rows.append("BONUS['%s'] không ai đọc → hình thế không có hiệu lực" % k)
report("4. Thưởng hình thế khai mà không có hiệu lực", rows)

# ── 5. Chuỗi có '%%' mà không đi qua toán tử % ───────────────────────────
rows = []
for p, s in files.items():
    lines = s.split("\n")
    for i, line in enumerate(lines):
        if "%%" not in line or line.strip().startswith("#"):
            continue
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        has_op = (re.search(r'"\s*%\s*[\[\(a-zA-Z_]', line)
                  or line.rstrip().endswith("\\")
                  or re.search(r"%\s*$", line)
                  or re.match(r"\s*%\s*[\[\(a-zA-Z_]", nxt))
        if not has_op:
            rows.append("%s:%d  %s" % (rel(p), i + 1, line.strip()[:80]))
report("5. Chuỗi '%%' không có toán tử % (sẽ in ra hai dấu %)", rows)

# ── 6. Widget gui_input thiếu make_click_target ──────────────────────────
rows = []
for p, s in files.items():
    lines = s.split("\n")
    for i, line in enumerate(lines):
        if ".gui_input.connect" not in line:
            continue
        obj = line.strip().split(".gui_input")[0]
        window = "\n".join(lines[max(0, i - 30): i + 30])
        if "make_click_target(%s)" % obj not in window:
            rows.append("%s:%d  '%s' — thiếu UIStyle.make_click_target → chỉ viền ăn click"
                        % (rel(p), i + 1, obj))
report("6. Card UI có gui_input mà thiếu make_click_target", rows)

# ── 7. Nhắm vào tháp bằng GridUtil thay vì PickUtil ──────────────────────
rows = []
for p, s in files.items():
    if p.endswith("grid_util.gd") or p.endswith("pick_util.gd"):
        continue
    for m in re.finditer(r"GridUtil\.mouse_to_cell\(", s):
        line = s[:m.start()].count("\n") + 1
        rows.append("%s:%d  GridUtil.mouse_to_cell — nếu chỗ này nhắm vào THÁP thì phải "
                    "dùng PickUtil (ray-plane lệch một ô ở thân model)" % (rel(p), line))
report("7. Chọn ô bằng ray-plane (kiểm xem có nhắm tháp không)", rows)

print("\n" + "-" * 78)
print("Tổng: %d nghi vấn. Mỗi mục phải soi tay — nhiều chỗ đọc field qua chuỗi." % findings)
