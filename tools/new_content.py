# -*- coding: utf-8 -*-
"""Tao khung file cho noi dung moi cua 8x-8, va noi ro can ve nhung anh nao.

    python tools/new_content.py tower  halberdier
    python tools/new_content.py enemy  snow_wolf
    python tools/new_content.py perk   loi_the_ho
    python tools/new_content.py potion binh_khoi_den
    python tools/new_content.py equip  giap_gai
    python tools/new_content.py relic  vuong_mien_vo
    python tools/new_content.py --list                # xem id da dung

Vi sao co script nay: mot mon noi dung khong chi la file du lieu — no con can
dung ten file, dung thu muc, dung kich thuoc anh. Nho mot trong ba thi mon do
"co ma khong chay" hoac hien ra o trong. Script viet san phan khung, roi in ra
danh sach anh phai ve kem kich thuoc.

Script KHONG ghi de file da ton tai.
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TOWER_STATS_UID = "uid://b7lp8i4x25fsm"
ENEMY_STATS_UID = "uid://bi0pqpxwqmdy5"


def path(*parts):
    return os.path.join(ROOT, *parts)


def write(rel, text):
    full = path(rel)
    if os.path.exists(full):
        print("  BO QUA (da co): %s" % rel)
        return False
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with io.open(full, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("  TAO: %s" % rel)
    return True


def append_json(rel, entry, note):
    """Them mot entry vao file JSON array. Tao file neu chua co."""
    full = path(rel)
    if os.path.exists(full):
        with io.open(full, encoding="utf-8") as f:
            data = json.load(f)
        if any(e.get("id") == entry["id"] for e in data):
            print("  BO QUA: id '%s' da co trong %s" % (entry["id"], rel))
            return False
        data.append(entry)
        print("  THEM VAO: %s" % rel)
    else:
        data = [entry]
        os.makedirs(os.path.dirname(full), exist_ok=True)
        print("  TAO: %s" % rel)
    with io.open(full, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    if note:
        print("  " + note)
    return True


# ── Khung tung loai ──────────────────────────────────────────────────────────

def make_tower(cid):
    write("res/towers/%s.tres" % cid, '''[gd_resource type="Resource" script_class="TowerStats" format=3]

[ext_resource type="Script" uid="%s" path="res://scripts/towers/TowerStats.gd" id="1_new"]

[resource]
script = ExtResource("1_new")
id = "%s"
name = "%s"
description = "TODO: mo ta hien trong shop va panel thap."
cost = 20
decree_cost = 1.5
base_damage = 18
attack_speed = 1.2
attack_range = 4
attack_style = 1
type = 0
element = 0
faction = "iron"
slow_amount = 0.0
slow_duration = 0.0
splash_radius = 0.0
burn_dps = 0
burn_duration = 0.0
projectile_count = 1
''' % (TOWER_STATS_UID, cid, cid.replace("_", " ").title()))
    return [
        ("assets/models/%s.gltf" % cid,
         "model 3D — 16 don vi Blockbench = 1 m = 1 o; thap cao ~18-29 don vi. KHONG BAT BUOC."),
        ("assets/towers/%s.png" % cid,
         "anh 2D 32x32 — card shop + billboard du phong khi chua co model. NEN CO."),
    ]


def make_enemy(cid):
    write("res/enemy/%s.tres" % cid, '''[gd_resource type="Resource" script_class="EnemyStats" format=3]

[ext_resource type="Script" uid="%s" path="res://scripts/enemy/EnemyStats.gd" id="1_new"]

[resource]
script = ExtResource("1_new")
id = "%s"
display_name = "%s"
ability_note = "TODO: mot dong nang luc, hien o popup trinh sat."
max_hp = 80
speed = 55.0
damage_to_base = 1
gold_reward = 9
armor = 0
regen_per_sec = 0.0
heal_aura_amount = 0
heal_aura_radius = 0.0
weak_element = ""
weak_element_2 = ""
resist_element = ""
spawn_seasons = Array[int]([0, 1])
spawn_weight = 2
''' % (ENEMY_STATS_UID, cid, cid.replace("_", " ").title()))
    print("  LUU Y: spawn_seasons 0=Xuan 1=Ha 2=Thu 3=Dong. De RONG = khong bao gio spawn.")
    print("  LUU Y: nen dat weak_element — khong co diem yeu thi moi he danh no nhu nhau.")
    return [
        ("assets/models/%s.gltf" % cid, "model 3D low-poly. KHONG BAT BUOC."),
        ("assets/enemy/%s.png" % cid,   "anh 2D 32x32 du phong. NEN CO."),
    ]


def make_perk(cid):
    append_json("data/perks/custom_perks.json", {
        "id": cid,
        "name": cid.replace("_", " ").title(),
        "desc": "TODO: mo ta hien tren card.",
        "rarity": "common",
        "icon": "✦",
        "tower": {"damage_bonus": 0.10},
    }, "rarity quyet dinh wave som nhat perk xuat hien: "
       "thuong 1 - hiem 3 - su thi 5 - huyen thoai 8.")
    return [("assets/ui/perks/%s.png" % cid,
             "icon 48x48 — thieu thi card dung ky hieu trong field `icon`. KHONG BAT BUOC.")]


def make_potion(cid):
    append_json("data/potions/core.json", {
        "id": cid,
        "name": cid.replace("_", " ").title(),
        "rarity": "common",
        "desc": "TODO: mo ta.",
        "target": "allies",
        "radius": 2.5,
        "duration": 12.0,
        "buff": {"damage_pct": 0.25},
    }, "kenh tac dung: `buff` (buff thap trong vung) / `strike` (danh dich) / "
       "`special`. Thieu ca ba thi nem ra khong lam gi.")
    return [("assets/ui/potions/%s.png" % cid, "icon 32x32. Thieu thi hien nhan chu viet tat.")]


def make_equip(cid):
    append_json("data/equipment/custom_equipment.json", {
        "id": cid,
        "name": cid.replace("_", " ").title(),
        "desc": "TODO: mo ta.",
        "cost": 80,
        "effect": {"damage_pct": 0.15},
    }, "khoa trong `effect` phai nam trong EFFECT_KEYS cua equipment_system.gd, "
       "va phai co noi DOC gia tri do.")
    return [("assets/ui/equipment/%s.png" % cid, "icon 32x32. Hien tren card shop + o trang bi.")]


def make_relic(cid):
    append_json("data/relics/custom_relics.json", {
        "id": cid,
        "name": cid.replace("_", " ").title(),
        "desc": "TODO: mo ta.",
        "cost": 200,
        "effect": {"reaction_mult": 1.15},
    }, "di vat ap hieu ung CA RUN qua RelicSystem._apply_all().")
    return [("assets/ui/relics/%s.png" % cid, "icon 32x32. Hien tren card shop + thanh di vat.")]


KINDS = {
    "tower":  make_tower,
    "enemy":  make_enemy,
    "perk":   make_perk,
    "potion": make_potion,
    "equip":  make_equip,
    "relic":  make_relic,
}


def list_ids():
    def tres_ids(folder):
        out = []
        d = path(folder)
        if not os.path.isdir(d):
            return out
        for name in sorted(os.listdir(d)):
            if not name.endswith(".tres"):
                continue
            with io.open(path(folder, name), encoding="utf-8") as f:
                m = re.search(r'^id\s*=\s*"([^"]+)"', f.read(), re.M)
            if m:
                out.append(m.group(1))
        return out

    def builtin_ids(gd_rel):
        """Mon khai thang trong .gd (ban du phong khi thieu JSON)."""
        full = path(gd_rel)
        if not os.path.isfile(full):
            return []
        with io.open(full, encoding="utf-8") as f:
            return sorted(set(re.findall(r'"id"\s*:\s*"(\w+)"', f.read())))

    def json_ids(folder):
        out = []
        d = path(folder)
        if not os.path.isdir(d):
            return out
        for name in sorted(os.listdir(d)):
            if not name.endswith(".json"):
                continue
            with io.open(path(folder, name), encoding="utf-8") as f:
                try:
                    data = json.load(f)
                except Exception:
                    continue
            out += [e["id"] for e in data if isinstance(e, dict) and e.get("id")]
        return out

    for label, ids in [
        ("quan co",  tres_ids("res/towers")),
        ("dich",     tres_ids("res/enemy")),
        ("perk",     json_ids("data/perks")),
        ("thuoc",    sorted(set(json_ids("data/potions")
                     + builtin_ids("scripts/items/potion_system.gd")))),
        ("trang bi", sorted(set(json_ids("data/equipment")
                     + builtin_ids("scripts/items/equipment_system.gd")))),
        ("di vat",   sorted(set(json_ids("data/relics")
                     + builtin_ids("scripts/items/relic_system.gd")))),
    ]:
        print("%-9s (%2d): %s" % (label, len(ids), ", ".join(ids) or "-"))


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if args[0] == "--list":
        list_ids()
        return 0
    if len(args) < 2 or args[0] not in KINDS:
        print("Dung: python tools/new_content.py <%s> <id>" % "|".join(KINDS))
        return 2

    kind, cid = args[0], args[1]
    if not re.match(r"^[a-z][a-z0-9_]*$", cid):
        print("id phai la snake_case, bat dau bang chu thuong: %s" % cid)
        return 2

    print("\n== TAO %s '%s' ==" % (kind.upper(), cid))
    art = KINDS[kind](cid)

    print("\n-- ANH CAN VE --")
    for rel, note in art:
        mark = "da co " if os.path.exists(path(rel)) else "THIEU "
        print("  [%s] %s\n           %s" % (mark, rel, note))

    print("\n-- BUOC TIEP --")
    print("  1. Mo file vua tao, thay cac cho ghi TODO.")
    print("  2. Ve anh o tren (ten file phai TRUNG DUNG id).")
    print("  3. python tools/check_content.py")
    print("  4. python tools/run_tests.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
