# -*- coding: utf-8 -*-
"""Sinh file .tres cho di vat tu MOT BANG.

    python tools/make_relics.py

Vi sao sinh bang script: 70 di vat viet tay la 70 co hoi go nham id, quen
`rarity`, lech gia so voi do manh. O day gia duoc TINH tu do manh, va id duy
nhat duoc kiem tu dong.

Moi dong: (id, ten, bac, hieu_ung, mo_ta)
`hieu_ung` chi dung hai khoa tong quat `cond_mult` / `per_mult` (xem
scripts/items/relic_conditions.gd) tru khi mon do can mot co che rieng.
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "res", "relics")

# Gia goc theo bac. Do manh nhan them (xem `price`).
BASE_COST = {"rare": 150, "epic": 230, "legendary": 320}

# ── DI VAT DIEU KIEN: manh khi mot dieu kien dung ───────────────────────────
# (id, ten, bac, dieu_kien, cong_them, mo_ta)
COND = [
    ("rl_lean_army",   "Lean Army",        "rare",      "few_pieces",      0.45,
     "A small board hits harder - your officers are not tripping over each other."),
    ("rl_horde",       "The Horde",        "rare",      "many_pieces",     0.30,
     "Numbers win wars. A crowded board rewards you for every extra body."),
    ("rl_full_muster", "Full Muster",      "epic",      "full_board",      0.60,
     "When the army is at its legal cap, every piece fights like two."),
    ("rl_scorched",    "Scorched Earth",   "epic",      "no_veins",        0.55,
     "Refuse the elements entirely and the land itself stops slowing you down."),
    ("rl_leyweaver",   "Ley Weaver",       "epic",      "many_veins",      0.50,
     "Six veins or more and the network starts feeding itself."),
    ("rl_drillmaster", "Drillmaster",      "rare",      "has_formation",   0.35,
     "Any formation at all sharpens the whole army."),
    ("rl_grand_march", "Grand March",      "legendary", "three_formations", 0.90,
     "Three different formations at once - the board reads like a real battle plan."),
    ("rl_regicide",    "Regicide",         "epic",      "boss_wave",       0.75,
     "Your army saves its best work for kings."),
    ("rl_odd_omen",    "Odd Omen",         "rare",      "odd_wave",        0.40,
     "The odd waves belong to you."),
    ("rl_even_keel",   "Even Keel",        "rare",      "even_wave",       0.40,
     "The even waves belong to you."),
    ("rl_war_chest",   "War Chest",        "rare",      "rich",            0.40,
     "Gold in the vault is confidence in the ranks."),
    ("rl_desperation", "Desperation",      "epic",      "broke",           0.65,
     "Nothing left to spend, nothing left to lose."),
    ("rl_veterans",    "Veterans",         "epic",      "all_star2",       0.55,
     "An army with no raw recruits."),
    ("rl_champion",    "Champion",         "rare",      "has_star3",       0.35,
     "One ★3 piece sets the standard for everyone else."),
    ("rl_monoculture", "Monoculture",      "epic",      "single_kind",     0.70,
     "Every piece moving the same way makes one perfectly drilled machine."),
    ("rl_grand_court", "Grand Court",      "epic",      "five_kinds",      0.55,
     "Five different movement types - a court of specialists."),
    ("rl_last_stand",  "Last Stand",       "legendary", "king_hurt",       1.00,
     "With the King bleeding, the army fights like it means it."),
    ("rl_unbroken",    "Unbroken Line",    "epic",      "full_hp",         0.45,
     "An untouched King is a rallying banner."),
    ("rl_honed_set",   "Honed Set",        "epic",      "deck_thin",       0.50,
     "A thin set means every draw is a good one."),
    ("rl_long_war",    "The Long War",     "epic",      "late_wave",       0.55,
     "From wave 8 on, your army has learned the enemy's habits."),
]

# ── DI VAT BO DEM: manh theo so luong ───────────────────────────────────────
# (id, ten, bac, bo_dem, moi_don_vi, mo_ta)
PER = [
    ("rl_muster_horn",  "Muster Horn",      "rare",      "pieces",          0.035,
     "Every piece on the board lends a little strength to the rest."),
    ("rl_open_ground",  "Open Ground",      "rare",      "empty_squares",   0.030,
     "Room to manoeuvre. Empty squares are not wasted squares."),
    ("rl_banner_line",  "Banner Line",      "epic",      "formations",      0.10,
     "Each active formation raises another banner."),
    ("rl_war_college",  "War College",      "epic",      "formation_kinds", 0.20,
     "Breadth of doctrine, not depth."),
    ("rl_vein_tithe",   "Vein Tithe",       "rare",      "veins",           0.05,
     "The land pays tribute for every vein you hold."),
    ("rl_deep_roots",   "Deep Roots",       "epic",      "vein_levels",     0.045,
     "Levelled veins run deeper than wide ones."),
    ("rl_prism",        "Prism",            "epic",      "elements",        0.13,
     "Each distinct element refracts into the others."),
    ("rl_constellation","Constellation",    "epic",      "stars",           0.09,
     "Every star above the first burns for the whole board."),
    ("rl_pawn_choir",   "Pawn Choir",       "rare",      "pawns",           0.07,
     "Pawns sing loudest in numbers."),
    ("rl_siege_train",  "Siege Train",      "rare",      "rooks",           0.09,
     "Rooks roll better in company."),
    ("rl_cavalry_horn", "Cavalry Horn",     "rare",      "knights",         0.11,
     "Knights answer each other across the board."),
    ("rl_cloister",     "Cloister",         "rare",      "bishops",         0.11,
     "Bishops pray in chorus."),
    ("rl_court_of_queens","Court of Queens","legendary", "queens",          0.30,
     "Queens do not share power gladly - but they do share strength."),
    ("rl_powder_line",  "Powder Line",      "epic",      "cannons",         0.16,
     "One Cannon is a threat. Several are a doctrine."),
    ("rl_hoard",        "Reliquary",        "epic",      "relics",          0.12,
     "Relics resonate with one another in the vault."),
    ("rl_momentum",     "Momentum",         "epic",      "wave",            0.05,
     "Every wave survived is one more the army has learned from."),
    ("rl_field_control","Field Control",    "epic",      "path_covered",    0.035,
     "The more of the road you watch, the harder every watcher hits."),
]


# ── DI VAT DANH DOI: thuong lon KEM mat trai that ───────────────────────────
# Day la lop lam Joker cua Balatro dang nho: no khong chi manh hon, no bat ban
# CHOI KHAC DI. `cond_mult` nhan gia tri AM nen mat trai khong can co che rieng.
# (id, ten, bac, {dieu_kien: gia_tri}, mo_ta)
TRADE = [
    ("rl_glass_army",  "Glass Army",       "legendary",
     {"few_pieces": 1.20, "many_pieces": -0.35},
     "Keep the army small and it is devastating. Let it swell and it shatters."),
    ("rl_hoarder",     "Hoarder's Curse",  "epic",
     {"rich": 0.85, "broke": -0.40},
     "Wealth is power - and spending it is weakness."),
    ("rl_spendthrift", "Spendthrift",      "epic",
     {"broke": 0.90, "rich": -0.35},
     "An empty purse means everything went into the war."),
    ("rl_martyr",      "Martyr's Banner",  "legendary",
     {"king_hurt": 1.30, "full_hp": -0.30},
     "Your army only truly wakes when the King is bleeding."),
    ("rl_purist",      "Purist",           "legendary",
     {"single_kind": 1.40, "five_kinds": -0.45},
     "One doctrine, mastered. Variety is dilution."),
    ("rl_dilettante",  "Dilettante",       "epic",
     {"five_kinds": 0.95, "single_kind": -0.50},
     "A wide court, thinly spread - unless you go wide enough."),
    ("rl_barren_oath", "Barren Oath",      "legendary",
     {"no_veins": 1.25, "many_veins": -0.40},
     "Swear off the elements entirely, or do not swear at all."),
    ("rl_ley_addict",  "Ley Addiction",    "epic",
     {"many_veins": 0.90, "no_veins": -0.45},
     "The network sustains you. Without it you are hollow."),
    ("rl_slow_burn",   "Slow Burn",        "epic",
     {"late_wave": 1.05, "odd_wave": -0.20},
     "Weak early, terrifying late - if you live that long."),
    ("rl_blitz",       "Blitz Doctrine",   "epic",
     {"odd_wave": 0.70, "late_wave": -0.35},
     "Win it fast. The long war is not yours."),
    ("rl_kingslayer",  "Kingslayer's Oath", "legendary",
     {"boss_wave": 1.35, "even_wave": -0.25},
     "You saved everything for the three that matter."),
    ("rl_drill_tyrant","Drill Tyrant",     "legendary",
     {"three_formations": 1.30, "has_formation": -0.15},
     "Any formation is sloppy. THREE is discipline."),
    ("rl_recruiter",   "Iron Recruiter",   "epic",
     {"many_pieces": 0.80, "few_pieces": -0.40},
     "A real army, not a duelling club."),
    ("rl_perfectionist","Perfectionist",   "legendary",
     {"all_star2": 1.20, "has_star3": -0.20},
     "Uniform excellence beats one prodigy surrounded by recruits."),
    ("rl_gambler",     "Gambler's Coin",   "epic",
     {"odd_wave": 0.85, "even_wave": -0.30},
     "Heads you dominate, tails you hold on."),
]

# ── DI VAT LAI: dieu kien + bo dem cung mot mon ─────────────────────────────
# (id, ten, bac, {dieu_kien: gt}, {bo_dem: gt}, mo_ta)
HYBRID = [
    ("rl_siege_doctrine","Siege Doctrine", "epic",
     {"has_formation": 0.25}, {"rooks": 0.07},
     "Rooks in formation are a doctrine, not a pile of towers."),
    ("rl_wild_hunt",   "Wild Hunt",        "epic",
     {"few_pieces": 0.35}, {"knights": 0.10},
     "A small pack of Knights runs faster than a crowd."),
    ("rl_cathedral",   "Cathedral",        "epic",
     {"many_veins": 0.30}, {"bishops": 0.09},
     "Bishops draw power from consecrated ground."),
    ("rl_levy_mass",   "Mass Levy",        "rare",
     {"many_pieces": 0.20}, {"pawns": 0.05},
     "Pawns are worthless alone and decisive together."),
    ("rl_royal_court", "Royal Court",      "legendary",
     {"has_star3": 0.40}, {"queens": 0.22},
     "A crowned court answers only to itself."),
    ("rl_artillery",   "Artillery Command", "epic",
     {"three_formations": 0.35}, {"cannons": 0.13},
     "Cannons need a plan behind them."),
    ("rl_deep_survey", "Deep Survey",      "epic",
     {"many_veins": 0.25}, {"vein_levels": 0.035},
     "Depth beats breadth once the survey is done."),
    ("rl_grand_design","Grand Design",     "legendary",
     {"full_board": 0.45}, {"formations": 0.08},
     "A full board is only worth it if it is ARRANGED."),
    ("rl_veteran_core","Veteran Core",     "epic",
     {"all_star2": 0.35}, {"stars": 0.06},
     "Every star compounds when nobody is raw."),
    ("rl_frontier",    "Frontier Watch",   "epic",
     {"few_pieces": 0.30}, {"path_covered": 0.030},
     "Few watchers, but each one watches a lot of road."),
    ("rl_quartermaster","Quartermaster",   "rare",
     {"rich": 0.25}, {"pieces": 0.025},
     "Paid troops fight better, and there are a lot of them."),
    ("rl_last_march",  "The Last March",   "legendary",
     {"king_hurt": 0.60}, {"wave": 0.045},
     "Everything you have learned, spent at once."),
    ("rl_open_field",  "Open Field",       "rare",
     {"few_pieces": 0.25}, {"empty_squares": 0.025},
     "Room to swing, room to ride."),
    ("rl_conclave",    "Conclave",         "epic",
     {"five_kinds": 0.30}, {"formation_kinds": 0.16},
     "Many voices, many doctrines, one board."),
    ("rl_relic_hunter","Relic Hunter",     "epic",
     {"late_wave": 0.30}, {"relics": 0.10},
     "The vault gets louder the longer the war runs."),
    ("rl_elementalist","Elementalist",     "legendary",
     {"many_veins": 0.35}, {"elements": 0.11},
     "Command every element, not just a lot of one."),
    ("rl_iron_wall",   "Iron Wall",        "epic",
     {"full_hp": 0.30}, {"pawns": 0.06},
     "An untouched King behind a wall of Pawns."),
]


def price(rarity: str, strength: float) -> int:
    """Gia = gia goc x do manh. Tranh chuyen mon manh nhat lai re nhat."""
    return int(round((BASE_COST[rarity] * (0.75 + strength)) / 10.0) * 10)


def tres(rid, name, rarity, cost, desc, effect_lines) -> str:
    return (
        '[gd_resource type="Resource" script_class="RelicData" format=3]\n\n'
        '[ext_resource type="Script" path="res://scripts/resources/RelicData.gd" id="1_gen"]\n\n'
        '[resource]\n'
        'script = ExtResource("1_gen")\n'
        'id = "%s"\n'
        'name = "%s"\n'
        'rarity = "%s"\n'
        'desc = "%s"\n'
        'cost = %d\n'
        'effect = {\n%s\n}\n' % (rid, name, rarity, desc.replace('"', "'"), cost, effect_lines)
    )


def main() -> int:
    if not os.path.isdir(OUT):
        print("khong thay %s" % OUT)
        return 1
    seen = set()
    for f in os.listdir(OUT):
        if f.endswith(".tres"):
            src = io.open(os.path.join(OUT, f), encoding="utf-8").read()
            for line in src.splitlines():
                if line.startswith("id = "):
                    seen.add(line.split('"')[1])

    made = 0
    dupes = []
    for rid, name, rarity, cond, val, desc in COND:
        if rid in seen:
            dupes.append(rid)
            continue
        eff = '"cond_mult": {\n"%s": %s\n}' % (cond, val)
        full = "%s +%d%% damage %s." % (
            desc, round(val * 100), _COND_TEXT.get(cond, cond))
        io.open(os.path.join(OUT, rid + ".tres"), "w", encoding="utf-8", newline="").write(
            tres(rid, name, rarity, price(rarity, val), full, eff))
        seen.add(rid)
        made += 1

    for rid, name, rarity, counter, val, desc in PER:
        if rid in seen:
            dupes.append(rid)
            continue
        eff = '"per_mult": {\n"%s": %s\n}' % (counter, val)
        full = "%s +%.1f%% damage per %s." % (
            desc, val * 100, _COUNT_TEXT.get(counter, counter))
        io.open(os.path.join(OUT, rid + ".tres"), "w", encoding="utf-8", newline="").write(
            tres(rid, name, rarity, price(rarity, val * 6), full, eff))
        seen.add(rid)
        made += 1

    for rid, name, rarity, conds, desc in TRADE:
        if rid in seen:
            dupes.append(rid)
            continue
        body = ",\n".join('"%s": %s' % (k, v) for k, v in conds.items())
        eff = '"cond_mult": {\n%s\n}' % body
        bits = []
        for k, v in conds.items():
            bits.append("%+d%% damage %s" % (round(v * 100), _COND_TEXT.get(k, k)))
        strength = max(conds.values())
        io.open(os.path.join(OUT, rid + ".tres"), "w", encoding="utf-8", newline="").write(
            tres(rid, name, rarity, price(rarity, strength * 0.55),
                 "%s %s." % (desc, ", ".join(bits)), eff))
        seen.add(rid)
        made += 1

    for rid, name, rarity, conds, counts, desc in HYBRID:
        if rid in seen:
            dupes.append(rid)
            continue
        cbody = ",\n".join('"%s": %s' % (k, v) for k, v in conds.items())
        pbody = ",\n".join('"%s": %s' % (k, v) for k, v in counts.items())
        eff = '"cond_mult": {\n%s\n},\n"per_mult": {\n%s\n}' % (cbody, pbody)
        bits = ["+%d%% %s" % (round(v * 100), _COND_TEXT.get(k, k)) for k, v in conds.items()]
        bits += ["+%.1f%% per %s" % (v * 100, _COUNT_TEXT.get(k, k)) for k, v in counts.items()]
        strength = max(conds.values()) + max(counts.values()) * 5
        io.open(os.path.join(OUT, rid + ".tres"), "w", encoding="utf-8", newline="").write(
            tres(rid, name, rarity, price(rarity, strength),
                 "%s %s." % (desc, ", ".join(bits)), eff))
        seen.add(rid)
        made += 1

    print("da sinh %d di vat moi (%d dieu kien + %d bo dem + %d danh doi + %d lai)"
          % (made, len(COND), len(PER), len(TRADE), len(HYBRID)))
    if dupes:
        print("bo qua vi trung id: %s" % ", ".join(dupes))
    print("tong so .tres trong res/relics: %d"
          % len([f for f in os.listdir(OUT) if f.endswith(".tres")]))
    return 0


# Van ban mo ta — PHAI khop voi COND_LABELS/COUNT_LABELS ben relic_conditions.gd.
_COND_TEXT = {
    "few_pieces": "with 8 or fewer pieces",
    "many_pieces": "with 15 or more pieces",
    "full_board": "when your army is at its cap",
    "no_veins": "while you own no elemental veins",
    "many_veins": "with 6 or more veins",
    "has_formation": "while any formation is active",
    "three_formations": "with 3+ different formations",
    "boss_wave": "on Rival King waves",
    "odd_wave": "on odd-numbered waves",
    "even_wave": "on even-numbered waves",
    "rich": "while holding 300+ gold",
    "broke": "while holding 30 gold or less",
    "has_star3": "while any piece is *3",
    "all_star2": "while every piece is *2 or better",
    "single_kind": "while every piece moves the same way",
    "five_kinds": "with 5+ different movement types",
    "king_hurt": "while your King is below half HP",
    "full_hp": "while your King is at full HP",
    "deck_thin": "while your set holds 10 pieces or fewer",
    "late_wave": "from wave 8 onward",
}
_COUNT_TEXT = {
    "pieces": "piece on the board",
    "empty_squares": "empty square",
    "formations": "active formation",
    "formation_kinds": "different formation type",
    "veins": "elemental vein",
    "vein_levels": "vein level",
    "elements": "different element on the board",
    "stars": "star above *1",
    "pawns": "Pawn", "rooks": "Rook", "knights": "Knight",
    "bishops": "Bishop", "queens": "Queen", "cannons": "Cannon",
    "relics": "relic you own",
    "wave": "wave survived",
    "path_covered": "path square your army covers",
}


if __name__ == "__main__":
    sys.exit(main())
