"""
Sprite regeneration script for 8x-8 game.
Redraws warlock, dark_mage, crossbowman, catapult (32x32)
and all 6 territory tiles (16x16) matching the project's visual style.

Palette extracted from user's Pawn/Knight/Queen sprites.
"""
from PIL import Image

# ── Helper functions ──────────────────────────────────────────────────────────
def mk(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))
def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height: img.putpixel((x, y), c)
def hline(img, y, x1, x2, c):
    for x in range(x1, x2+1): px(img, x, y, c)
def vline(img, x, y1, y2, c):
    for y in range(y1, y2+1): px(img, x, y, c)
def rect(img, x1, y1, x2, y2, c):
    for y in range(y1, y2+1):
        for x in range(x1, x2+1): px(img, x, y, c)
def draw_rows(img, rows_map, palette, ox=0, oy=0):
    """Draw sprite from list of row strings using palette dict."""
    for y, row in enumerate(rows_map):
        for x, ch in enumerate(row):
            if ch in palette and ch != '.':
                px(img, ox+x, oy+y, palette[ch])

# ── Master palette (from Pawn/Knight/Queen analysis) ─────────────────────────
OL = (21,  15,  10,  255)  # #150f0a – main outline (near-black)
D1 = (48,  15,  10,  255)  # #300f0a – deep shadow
D2 = (85,  15,  10,  255)  # #550f0a – dark base
R1 = (155, 26,  10,  255)  # #9b1a0a – mid red
R2 = (239, 58,  12,  255)  # #ef3a0c – bright red
GD = (239, 172, 40,  255)  # #efac28 – bright gold
GS = (165, 140, 39,  255)  # #a58c27 – dark gold
SK = (239, 183, 117, 255)  # #efb775 – skin
SH = (239, 216, 161, 255)  # #efd8a1 – skin highlight
SS = (165, 98,  67,  255)  # #a56243 – skin shadow
BR = (57,  42,  28,  255)  # #392a1c – dark brown
BM = (104, 76,  60,  255)  # #684c3c – mid brown
BL = (146, 126, 106, 255)  # #927e6a – light brown
TR = (0, 0, 0, 0)           # transparent

# Extra colours for specific units
PD = (45,  10,  74,  255)  # dark purple  (warlock hat/robe base)
PM = (90,  26,  128, 255)  # mid purple
PL = (128, 48,  168, 255)  # light purple
TE = (40,  160, 176, 255)  # teal (staff orb)
TH = (120, 220, 232, 255)  # teal highlight

ND = (20,  20,  40,  255)  # dark mage hood/robe
NM = (50,  20,  90,  255)  # dark mage robe mid
NR = (120, 20,  40,  255)  # blood-red trim
NK = (210, 200, 175, 255)  # pale/bone skin
EN = (70,  0,   150, 255)  # dark energy
EH = (170, 80,  255, 255)  # energy highlight

HD = (58,  45,  30,  255)  # hood/leather dark
HM = (88,  66,  44,  255)  # hood mid
HL = (130, 100, 68,  255)  # hood light
CB = (45,  28,   8,  255)  # crossbow dark wood
CM = (128, 112, 96,  255)  # crossbow metal

# ── WARLOCK (32×32) ───────────────────────────────────────────────────────────
# Tall wizard hat, purple robe, glowing staff+orb (right side)
W = mk(32, 32)

# Staff body (col 24, rows 4–31)
vline(W, 24, 4, 31, BR)
px(W, 24, 8, BL); px(W, 24, 14, BL); px(W, 24, 20, BL); px(W, 24, 26, BL)
vline(W, 23, 4, 31, OL)
vline(W, 25, 4, 31, OL)

# Staff orb (rows 1–5, centered on col 24)
for dy, xs in [
    (1, [23,24,25]),
    (2, [22,23,24,25,26]),
    (3, [22,23,24,25,26]),
    (4, [23,24,25]),
]:
    for x in xs: px(W, x, dy, TE)
px(W, 24, 2, TH); px(W, 23, 2, TH); px(W, 24, 3, TH)  # bright core
# orb outline
for x in [22,23,24,25,26]: px(W, x, 0, OL)
for x in [22,23,24,25,26]: px(W, x, 5, OL)
px(W, 21, 1, OL); px(W, 27, 1, OL)
px(W, 21, 2, OL); px(W, 27, 2, OL)
px(W, 21, 3, OL); px(W, 27, 3, OL)
px(W, 21, 4, OL); px(W, 27, 4, OL)

# Hat (pointed, centered on x=13)
# Tip: row 2
px(W, 13, 2, PM)
# row 3
hline(W, 3, 12, 14, PD); px(W, 13, 3, PM)
# rows 4–8 (widening)
hat_data = [
    (4,  11, 15, [13, PL]),
    (5,  10, 16, [12,14, PL]),
    (6,   9, 17, [12,13,14, PL]),
    (7,   8, 18, [12,13,14,15, PL]),
    (8,   7, 19, [12,13,14,15,16, PL]),
]
for y, xl, xr, highs in hat_data:
    px(W, xl-1, y, OL); px(W, xr+1, y, OL)
    hline(W, y, xl, xr, PM)
    hline(W, y, xl, xl+1, PD)
    hline(W, y, xr-1, xr, PD)
    # highlights
    for x in highs[:-1]: px(W, x, y, PL)

# Hat brim shadow (row 9)
px(W, 6, 9, OL); hline(W, 9, 7, 19, PD); px(W, 20, 9, OL)

# Head (rows 10–17, cols 9–19)
for y in range(10, 17):
    xl, xr = 9, 19
    if y == 10: xl, xr = 10, 18
    if y in [16,17]: xl, xr = 11, 17
    px(W, xl-1, y, OL); px(W, xr+1, y, OL)
    hline(W, y, xl, xr, SK)
    px(W, xl, y, SS); px(W, xr, y, SS)

# Eyes row 12
px(W, 12, 12, R2); px(W, 13, 12, R2)
px(W, 16, 12, R2); px(W, 17, 12, R2)

# Nose row 13
px(W, 14, 13, SS)

# Beard rows 14–16
hline(W, 14, 12, 17, BM)
hline(W, 15, 12, 17, BM); px(W, 11, 15, OL); px(W, 18, 15, OL)
hline(W, 16, 13, 16, BR)

# Collar row 17
hline(W, 17, 12, 16, PM); px(W, 11, 17, OL); px(W, 17, 17, OL)

# Right arm (rows 18–21, cols 20–22)
for y in range(18, 22):
    px(W, 20, y, OL); px(W, 21, y, PM); px(W, 22, y, PD)

# Robe body (rows 18–26)
robe_extents = [
    (18, 10, 19), (19, 9, 20), (20, 8, 20), (21, 8, 21),
    (22, 7, 21),  (23, 7, 21), (24, 7, 21), (25, 8, 20), (26, 9, 19),
]
for y, xl, xr in robe_extents:
    px(W, xl-1, y, OL); px(W, xr+1, y, OL)
    hline(W, y, xl, xr, PM)
    px(W, xl, y, PD); px(W, xl+1, y, PD)
    px(W, xr, y, PD); px(W, xr-1, y, PD)

# Gold belt (row 19)
hline(W, 19, 12, 16, GD); px(W, 12, 19, GS); px(W, 16, 19, GS)

# Robe highlight (centre column)
for y in range(18, 27): px(W, 14, y, PL)

# Robe folds (vertical shadow lines)
for y in range(20, 27):
    px(W, 11, y, PD); px(W, 17, y, PD)

# Robe hem (rows 27–28) – alternating
for y in [27, 28]:
    for x in range(10, 20):
        px(W, x, y, PD if x % 2 == 0 else PM)
    px(W, 9, y, OL); px(W, 20, y, OL)

# Boots (rows 29–31)
for y in [29, 30]:
    px(W, 9, y, OL); hline(W, y, 10, 12, D1); px(W, 13, y, OL)
    px(W, 16, y, OL); hline(W, y, 17, 19, D1); px(W, 20, y, OL)
for x in [9, 10, 11, 12, 13, 16, 17, 18, 19, 20]: px(W, x, 31, OL)

W.save('D:/Code/SourceCode/GameDev/8x-8/assets/towers/warlock.png')
print("✓ warlock.png")


# ── DARK MAGE (32×32) ─────────────────────────────────────────────────────────
# Deep necromancer hood, pale hollow face, blood-red trim, dark energy hands
DM = mk(32, 32)

# Hood (wide, rows 1–14, centered ~x=14)
hood_extents = [
    (1,  11, 16), (2,  10, 17), (3,   9, 18), (4,  8, 19),
    (5,  8, 19),  (6,  8, 19), (7,   8, 19), (8,  8, 19),
    (9,  8, 19),  (10, 8, 19), (11, 8, 19), (12, 8, 19),
    (13, 9, 18),  (14, 10, 17),
]
for y, xl, xr in hood_extents:
    px(DM, xl-1, y, OL); px(DM, xr+1, y, OL)
    hline(DM, y, xl, xr, ND)
    px(DM, xl, y, NM); px(DM, xr, y, NM)

# Face opening inside hood (rows 5–12, cols 11–17)
for y in range(5, 13):
    hline(DM, y, 11, 17, NK)
    px(DM, 11, y, (150, 140, 120, 255))  # shadow edge
    px(DM, 17, y, (150, 140, 120, 255))

# Glowing eyes (rows 7–8)
for x in [12, 13]: px(DM, x, 7, R2); px(DM, x, 8, R1)
for x in [15, 16]: px(DM, x, 7, R2); px(DM, x, 8, R1)
# Eye glow halo (dim orange around)
for x in [11, 14]: px(DM, x, 7, (180, 40, 20, 200))
for x in [14, 17]: px(DM, x, 7, (180, 40, 20, 200))

# Skull teeth hint (row 11)
for x in range(12, 17, 2): px(DM, x, 11, OL)
for x in [13, 15]: px(DM, x, 11, NK)

# Collar + blood-red trim (rows 14–16)
hline(DM, 14, 10, 18, NR)
px(DM, 9, 14, OL); px(DM, 19, 14, OL)
hline(DM, 15, 10, 18, NM)
hline(DM, 16, 9, 19, NM)
px(DM, 8, 16, OL); px(DM, 20, 16, OL)

# Robe body (rows 17–26)
robe_dm = [
    (17, 8, 19), (18, 7, 20), (19, 7, 20), (20, 6, 21),
    (21, 6, 21), (22, 6, 21), (23, 6, 21), (24, 7, 20),
    (25, 8, 19), (26, 9, 18),
]
for y, xl, xr in robe_dm:
    px(DM, xl-1, y, OL); px(DM, xr+1, y, OL)
    hline(DM, y, xl, xr, ND)
    px(DM, xl, y, NM); px(DM, xr, y, NM)

# Blood-red robe accents (vertical trim lines at edges)
for y in range(17, 27):
    px(DM, 9, y, NR) if y % 2 == 0 else None
    px(DM, 18, y, NR) if y % 2 == 0 else None

# Skull belt buckle (rows 19–21, center)
belt_skull = [
    (19, [12,13,14,15,16]),
    (20, [11,12,13,14,15,16,17]),
    (21, [12,13,14,15,16]),
]
for y, xs in belt_skull:
    for x in xs: px(DM, x, y, (190, 180, 150, 255))  # bone
px(DM, 12, 20, R1); px(DM, 16, 20, R1)  # eye sockets
px(DM, 14, 21, OL)                        # nose gap

# Dark energy hands (rows 20–23, far left & far right)
for y in range(20, 24):
    # Left hand
    px(DM, 4, y, EN); px(DM, 5, y, EH if y == 21 else EN)
    px(DM, 3, y, OL); px(DM, 6, y, OL)
    # Right hand
    px(DM, 23, y, EN); px(DM, 22, y, EH if y == 21 else EN)
    px(DM, 21, y, OL); px(DM, 24, y, OL)
# Energy glow orbs at hands
for dx, cy in [(-1, 21), (1, 21)]:
    cx = 4 if dx == -1 else 23
    for (dy, ddx) in [(-1,0),(0,-1),(0,1),(1,0)]:
        px(DM, cx+ddx, cy+dy, (60, 0, 120, 180))

# Robe hem (rows 27–28)
for y in [27, 28]:
    hline(DM, y, 9, 19, D1)
    px(DM, 8, y, OL); px(DM, 20, y, OL)
    # Red hem trim
    for x in range(9, 20, 3): px(DM, x, y, NR)

# Boots (rows 29–31)
for y in [29, 30]:
    px(DM, 9, y, OL); hline(DM, y, 10, 12, D1); px(DM, 13, y, OL)
    px(DM, 15, y, OL); hline(DM, y, 16, 18, D1); px(DM, 19, y, OL)
for x in range(9, 20): px(DM, x, 31, OL)

DM.save('D:/Code/SourceCode/GameDev/8x-8/assets/towers/dark_mage.png')
print("✓ dark_mage.png")


# ── CROSSBOWMAN (32×32) ───────────────────────────────────────────────────────
# Ranger hood, leather armour, crossbow clearly held at chest level
CW = mk(32, 32)

# Hood (rows 1–8, centered ~x=14)
hood_cw = [
    (1,  12, 16), (2,  11, 17), (3,  10, 18), (4, 10, 18),
    (5,  10, 18), (6,  10, 18), (7,  10, 18), (8, 10, 18),
]
for y, xl, xr in hood_cw:
    px(CW, xl-1, y, OL); px(CW, xr+1, y, OL)
    hline(CW, y, xl, xr, HD)
    px(CW, xl, y, HM); px(CW, xr, y, HM)
    if y in [2, 3]: px(CW, xl+1, y, HL)  # highlight on hood

# Face opening (rows 4–10, cols 11–17)
for y in range(4, 11):
    hline(CW, y, 11, 17, SK)
    px(CW, 11, y, SS); px(CW, 17, y, SS)

# Eyes (row 6)
px(CW, 12, 6, BR); px(CW, 13, 6, BR)
px(CW, 15, 6, BR); px(CW, 16, 6, BR)
px(CW, 14, 6, SK)  # nose bridge

# Nose (row 7–8)
px(CW, 14, 8, SS)

# Mouth (row 9)
hline(CW, 9, 13, 15, (180, 100, 60, 255))

# Chin (row 10)
hline(CW, 10, 12, 16, SS)

# Neck (row 11)
px(CW, 12, 11, OL); hline(CW, 11, 13, 15, SK); px(CW, 16, 11, OL)

# Shoulder pad + body (rows 12–18)
# Leather shoulder left
px(CW, 6, 12, OL)
hline(CW, 12, 7, 10, BM); px(CW, 7, 12, BR); px(CW, 11, 12, OL)
# Main body
px(CW, 11, 12, OL)
hline(CW, 12, 12, 20, HM)
px(CW, 12, 12, HD); px(CW, 20, 12, HD)
px(CW, 21, 12, OL)
# Shoulder pad right
px(CW, 21, 12, OL)
hline(CW, 12, 22, 24, BM); px(CW, 24, 12, BR); px(CW, 25, 12, OL)

# ── CROSSBOW (rows 13–15, horizontal, the key feature!) ──
# Stock (centre, cols 9–22), bow arms (cols 4–8 and 23–27)
# Prod (bow arms) – top part row 12
for y in [12, 13]:
    # Left arm prod (vertical curve effect)
    hline(CW, y, 4, 8, CM)
    px(CW, 4, y, OL); px(CW, 8, y, OL)
    # Right arm prod
    hline(CW, y, 23, 27, CM)
    px(CW, 23, y, OL); px(CW, 27, y, OL)

# Crossbow stock body (rows 13–15)
for y in range(13, 16):
    hline(CW, y, 9, 22, CB)
    px(CW, 9, y, OL); px(CW, 22, y, OL)

# String running from left arm tip to right arm tip (row 11)
for x in range(4, 28): px(CW, x, 11, OL)
hline(CW, 11, 5, 8, (180, 160, 120, 255))   # string left
hline(CW, 11, 23, 26, (180, 160, 120, 255)) # string right
# Stock handle detail
px(CW, 14, 14, BM); px(CW, 15, 14, HL)  # highlight on stock
# Trigger guard
px(CW, 17, 16, OL); px(CW, 17, 15, BR)

# Arms below crossbow (rows 16–17)
# Left arm holding stock
px(CW, 9, 16, OL); hline(CW, 16, 10, 12, HM); px(CW, 13, 16, OL)
# Right arm holding trigger
px(CW, 19, 16, OL); hline(CW, 16, 20, 21, HM); px(CW, 22, 16, OL)

# Body/torso (rows 17–24)
body_cw = [
    (17, 11, 20), (18, 10, 21), (19, 10, 21), (20, 10, 21),
    (21, 11, 20), (22, 11, 20), (23, 12, 19), (24, 12, 19),
]
for y, xl, xr in body_cw:
    px(CW, xl-1, y, OL); px(CW, xr+1, y, OL)
    hline(CW, y, xl, xr, HM)
    px(CW, xl, y, HD); px(CW, xl+1, y, HD)
    px(CW, xr, y, HD); px(CW, xr-1, y, HD)

# Belt (row 20)
hline(CW, 20, 11, 20, BR); px(CW, 15, 20, GS); px(CW, 16, 20, GD)  # buckle

# Leather highlight stripe
for y in range(17, 25): px(CW, 15, y, HL)

# Legs (rows 25–31)
for y in range(25, 30):
    px(CW, 11, y, OL); hline(CW, y, 12, 14, HD); px(CW, 15, y, OL)
    px(CW, 16, y, OL); hline(CW, y, 17, 19, HD); px(CW, 20, y, OL)

# Boots (rows 30–31)
for y in [30, 31]:
    px(CW, 10, y, OL); hline(CW, y, 11, 15, BR); px(CW, 16, y, OL)
    px(CW, 16, y, OL); hline(CW, y, 17, 21, BR); px(CW, 22, y, OL)

CW.save('D:/Code/SourceCode/GameDev/8x-8/assets/towers/crossbowman.png')
print("✓ crossbowman.png")


# ── CATAPULT (32×32) ──────────────────────────────────────────────────────────
# Side-view wooden siege catapult, arm raised, stone ready
CA = mk(32, 32)

# Ground shadow (row 30–31, narrow base)
hline(CA, 30, 2, 29, D1); hline(CA, 31, 2, 29, OL)

# WHEELS: left wheel (center 6,25, r=4), right wheel (center 24,25, r=4)
def draw_wheel(img, cx, cy, r):
    # Filled circle
    for dy in range(-r, r+1):
        for dx in range(-r, r+1):
            if dx*dx + dy*dy <= r*r:
                px(img, cx+dx, cy+dy, BR)
    # Spokes
    for d in range(-r+1, r): px(img, cx+d, cy, BM)  # horizontal
    for d in range(-r+1, r): px(img, cx, cy+d, BM)  # vertical
    px(img, cx, cy, BL)  # hub
    # Rim (dark outline)
    for dy in range(-r, r+1):
        for dx in range(-r, r+1):
            dist_sq = dx*dx + dy*dy
            if r*r - 2*r < dist_sq <= r*r:
                px(img, cx+dx, cy+dy, OL)

draw_wheel(CA, 6,  25, 4)
draw_wheel(CA, 24, 25, 4)

# Axle (connecting both wheels, row 25)
hline(CA, 25, 10, 20, BR); hline(CA, 25, 10, 20, BM)
px(CA, 10, 25, OL); px(CA, 20, 25, OL)

# FRAME: A-frame structure
# Left leg (x=7–9, rows 17–25)
for y in range(17, 26):
    hline(CA, y, 7, 9, BM)
    px(CA, 6, y, OL); px(CA, 10, y, OL)
# Right leg (x=21–23, rows 17–25)
for y in range(17, 26):
    hline(CA, y, 21, 23, BM)
    px(CA, 20, y, OL); px(CA, 24, y, OL)
# Cross-brace (diagonal, rows 18–22)
for i, y in enumerate(range(18, 23)):
    x = 9 + i*3
    hline(CA, y, x, x+2, BR)
    px(CA, x-1, y, OL); px(CA, x+3, y, OL)
# Top cross-beam (row 17)
hline(CA, 17, 7, 23, BM); px(CA, 6, 17, OL); px(CA, 24, 17, OL)
hline(CA, 16, 7, 23, BR)  # top edge of beam

# PIVOT POST (col 15, rows 10–17)
vline(CA, 14, 10, 17, BM); vline(CA, 15, 10, 17, BL); vline(CA, 16, 10, 17, BR)
px(CA, 13, 10, OL); px(CA, 17, 10, OL)
for y in range(10, 18): px(CA, 13, y, OL); px(CA, 17, y, OL)

# CATAPULT ARM: long arm angled up-right (the arm is raised, ready to fire)
# Arm goes from counterweight (left, row 22, col 5) through pivot (col 15, row 17)
# to bucket end (upper right, row 3, col 26)
# Draw as thick diagonal line
arm_points = [
    (22, 5), (21, 7), (20, 8), (19, 10), (18, 11),
    (17, 12), (16, 13), (15, 15),  # pivot area
    (14, 16), (13, 17), (12, 18), (11, 20),
    (10, 21), (9, 22), (8, 23),
]
# Rethink: arm goes from low-left to high-right (arm raised to release position)
arm_up_points = [
    # (y, x_left, x_right) for each thick segment
    (15, 15, 16), (14, 16, 17), (13, 18, 19), (12, 19, 20),
    (11, 21, 22), (10, 22, 23), (9, 24, 25), (8, 25, 26),
    (7, 26, 27), (6, 27, 28), (5, 27, 28), (4, 28, 29),
]
# Pivot fulcrum side (short end going down-left)
arm_down_points = [
    (16, 13, 14), (17, 12, 13), (18, 11, 12), (19, 10, 11),
    (20, 9, 10),
]
for y, xl, xr in arm_up_points:
    hline(CA, y, xl, xr, BL)
    px(CA, xl-1, y, OL); px(CA, xr+1, y, OL)
for y, xl, xr in arm_down_points:
    hline(CA, y, xl, xr, BM)
    px(CA, xl-1, y, OL); px(CA, xr+1, y, OL)

# Counterweight (box at bottom of short arm, rows 20–23, cols 7–11)
rect(CA, 7, 20, 11, 23, BR)
rect(CA, 8, 21, 10, 22, BM)
for x in range(6, 13): px(CA, x, 19, OL); px(CA, x, 24, OL)
vline(CA, 6, 20, 23, OL); vline(CA, 12, 20, 23, OL)

# Sling rope and PROJECTILE (stone at top of arm, rows 1–4, cols 28–31)
# Rope from arm tip to sling
vline(CA, 29, 4, 7, (180, 160, 120, 255))
# Stone (circle, center 30,3, r=2)
stone_pixels = [(1,29),(1,30),(1,31),(2,28),(2,29),(2,30),(2,31),(3,28),(3,29),(3,30),(3,31),(4,29),(4,30),(4,31)]
for y,x in stone_pixels: px(CA, x, y, (140, 130, 120, 255))
# Stone highlight and outline
px(CA, 29, 2, (180, 170, 160, 255)); px(CA, 30, 1, (200, 190, 180, 255))
for y,x in [(0,29),(0,30),(0,31),(1,28),(1,32),(2,27),(3,27),(4,28),(5,29),(5,30),(5,31)]:
    px(CA, x, y, OL)

CA.save('D:/Code/SourceCode/GameDev/8x-8/assets/towers/catapult.png')
print("✓ catapult.png")


# ── TERRITORY TILES (16×16) ───────────────────────────────────────────────────
# Each tile: 1px dark border, biome-coloured fill, 8×8 central icon

def make_tile(bg, icon_fn):
    t = mk(16, 16)
    # Border
    border_c = tuple(max(0, v-40) for v in bg[:3]) + (255,)
    for x in range(16): px(t, x, 0, border_c); px(t, x, 15, border_c)
    for y in range(16): px(t, 0, y, border_c); px(t, 15, y, border_c)
    # Fill
    rect(t, 1, 1, 14, 14, bg)
    # Icon (drawn at pixel level in icon_fn)
    icon_fn(t)
    return t

# FIRE TILE ── orange-red stone with flame icon
FIRE_BG  = (100, 25, 5, 255)
FIRE_BDR = (50,  10, 2, 255)
FLAME_C  = (239, 96, 12, 255)
FLAME_H  = (239, 172, 40, 255)
FLAME_B  = (180, 40, 5, 255)

def draw_fire(t):
    # Flame: narrow tip at top, wide base at bottom, centered col 7-8
    flame = [
        (3,  [8]),
        (4,  [7, 8, 9]),
        (5,  [6, 7, 8, 9, 10]),
        (6,  [6, 7, 8, 9, 10]),
        (7,  [5, 6, 7, 8, 9, 10, 11]),
        (8,  [5, 6, 7, 8, 9, 10, 11]),
        (9,  [5, 6, 7, 8, 9, 10, 11]),
        (10, [6, 7, 8, 9, 10]),
        (11, [6, 7, 8, 9, 10]),
        (12, [7, 8]),
    ]
    for y, xs in flame:
        for x in xs: px(t, x, y, FLAME_C)
    # Inner bright core
    for y, xs in [(5,[8]),(6,[7,8,9]),(7,[7,8,9]),(8,[7,8,9]),(9,[7,8])]:
        for x in xs: px(t, x, y, FLAME_H)
    # Base glow
    for y, xs in [(10,[7,8,9]),(11,[7,8])]:
        for x in xs: px(t, x, y, FLAME_B)
    # Outline
    outline_f = [
        (2,8),(3,7),(3,9),(4,6),(4,10),(5,5),(5,11),
        (6,5),(6,11),(7,4),(7,12),(8,4),(8,12),
        (9,4),(9,12),(10,5),(10,11),(11,5),(11,11),
        (12,6),(12,10),(13,7),(13,8),(13,9),
    ]
    for y,x in outline_f: px(t, x, y, OL)

ft = make_tile(FIRE_BG, draw_fire)
ft.save('D:/Code/SourceCode/GameDev/8x-8/assets/tiles/territory_fire.png')
print("✓ territory_fire.png")


# SWAMP TILE ── dark murky green with poison drip icon
SWAMP_BG  = (18, 40, 22, 255)
SWAMP_BDR = (8,  20, 10, 255)
SWAMP_G   = (40, 120, 50, 255)
SWAMP_PO  = (80, 200, 60, 255)
SWAMP_DARK = (15, 60, 20, 255)

def draw_swamp(t):
    # Skull with poison drip
    # Skull outline (rows 3–10, cols 5–10)
    skull = [
        (3,  [6,7,8,9]),
        (4,  [5,6,7,8,9,10]),
        (5,  [5,6,7,8,9,10]),
        (6,  [5,6,7,8,9,10]),
        (7,  [5,6,7,8,9,10]),
        (8,  [5,7,8,10]),         # eye sockets + nose
        (9,  [5,6,7,8,9,10]),
        (10, [6,7,8,9]),
    ]
    for y, xs in skull:
        for x in xs: px(t, x, y, SWAMP_G)
    # Eyes (hollows)
    px(t, 6, 7, SWAMP_DARK); px(t, 7, 7, SWAMP_DARK)
    px(t, 9, 7, SWAMP_DARK); px(t, 10, 7, SWAMP_DARK)
    # Nose
    px(t, 8, 8, SWAMP_DARK)
    # Teeth hint
    hline(t, 10, 6, 9, SWAMP_DARK)
    for x in [6, 8]: px(t, x, 10, SWAMP_G)
    # Poison drip (rows 11–13)
    for y in [11, 12]: px(t, 8, y, SWAMP_PO)
    px(t, 8, 13, SWAMP_PO); px(t, 7, 13, SWAMP_PO)
    # Skull outline
    for y,x in [(2,6),(2,7),(2,8),(2,9),(3,5),(3,10),(4,4),(4,11),(9,4),(9,11),
                (10,5),(10,10),(11,6),(11,9)]:
        px(t, x, y, OL)

st = make_tile(SWAMP_BG, draw_swamp)
st.save('D:/Code/SourceCode/GameDev/8x-8/assets/tiles/territory_swamp.png')
print("✓ territory_swamp.png")


# ICE TILE ── deep blue with crystal/snowflake icon
ICE_BG   = (15, 35, 75, 255)
ICE_BDR  = (8,  18, 40, 255)
ICE_C    = (100, 180, 230, 255)
ICE_H    = (200, 235, 255, 255)
ICE_DARK = (60, 120, 180, 255)

def draw_ice(t):
    # Snowflake / ice crystal (centered 7–8)
    cx, cy = 7, 7
    # Main axes
    for d in range(-5, 6):
        if d != 0: px(t, cx+d, cy, ICE_C); px(t, cx, cy+d, ICE_C)
    # Diagonal arms
    for d in range(-3, 4):
        if d != 0: px(t, cx+d, cy+d, ICE_DARK); px(t, cx+d, cy-d, ICE_DARK)
    # Arm ticks (perpendicular notches on main axes)
    for d in [-3, 3]:
        px(t, cx+d, cy-2, ICE_C); px(t, cx+d, cy+2, ICE_C)
        px(t, cx-2, cy+d, ICE_C); px(t, cx+2, cy+d, ICE_C)
    # Centre diamond
    for dy, xs in [(-1,[7]),(0,[6,7,8]),(1,[7])]:
        for x in xs: px(t, x, cy+dy, ICE_H)
    # Outline tips
    for d in [-5, 5]:
        px(t, cx+d, cy, OL); px(t, cx, cy+d, OL)
    for d in [-4, 4]:
        px(t, cx+d, cy+d, OL); px(t, cx+d, cy-d, OL)

it = make_tile(ICE_BG, draw_ice)
it.save('D:/Code/SourceCode/GameDev/8x-8/assets/tiles/territory_ice.png')
print("✓ territory_ice.png")


# FOREST TILE ── dark forest green with pine tree icon
FOREST_BG  = (14, 45, 14, 255)
FOREST_BDR = (6,  22, 6,  255)
FOREST_T   = (30, 100, 30, 255)
FOREST_TH  = (70, 160, 50, 255)
FOREST_TK  = (80, 50,  20, 255)  # trunk

def draw_forest(t):
    # Pine tree (three tiers + trunk)
    # Trunk (rows 11–13, cols 7–8)
    hline(t, 12, 7, 8, FOREST_TK); hline(t, 13, 7, 8, FOREST_TK)
    px(t, 6, 12, OL); px(t, 9, 12, OL)
    px(t, 6, 13, OL); px(t, 9, 13, OL)
    # Top tier (rows 3–6)
    for y, xs in [(3,[8]),(4,[7,8,9]),(5,[6,7,8,9,10]),(6,[6,7,8,9,10])]:
        for x in xs: px(t, x, y, FOREST_TH)
    # Mid tier (rows 6–9)
    for y, xs in [(6,[5,6,7,8,9,10,11]),(7,[5,6,7,8,9,10,11]),(8,[4,5,6,7,8,9,10,11,12]),(9,[4,5,6,7,8,9,10,11,12])]:
        for x in xs: px(t, x, y, FOREST_T)
    # Bottom tier (rows 9–12)
    for y, xs in [(9,[3,4,5,6,7,8,9,10,11,12,13]),(10,[3,4,5,6,7,8,9,10,11,12,13]),(11,[4,5,6,7,8,9,10,11,12])]:
        for x in xs: px(t, x, y, FOREST_T)
    # Highlights (top-left of each tier)
    px(t, 8, 3, FOREST_TH); px(t, 7, 4, FOREST_TH); px(t, 7, 7, FOREST_TH)
    # Outline tips
    for y,x in [(2,8),(3,7),(3,9),(4,6),(4,10),(5,5),(5,11),
                (8,3),(8,13),(9,2),(9,14),(10,2),(10,14),(11,3),(11,13),(12,4),(12,12)]:
        px(t, x, y, OL)

ff = make_tile(FOREST_BG, draw_forest)
ff.save('D:/Code/SourceCode/GameDev/8x-8/assets/tiles/territory_forest.png')
print("✓ territory_forest.png")


# DESERT TILE ── sand/gold with sun rays icon
DESERT_BG  = (90,  55, 15, 255)
DESERT_BDR = (50,  28, 6,  255)
SUN_Y      = (239, 172, 40, 255)
SUN_H      = (239, 216, 161, 255)
SUN_D      = (180, 120, 20, 255)

def draw_desert(t):
    cx, cy = 8, 8
    # Sun circle
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            if dx*dx + dy*dy <= 9: px(t, cx+dx, cy+dy, SUN_Y)
    # Centre highlight
    for dy, xs in [(-1,[8]),(0,[7,8,9]),(1,[8])]:
        for x in xs: px(t, x, cy+dy, SUN_H)
    # Rays (8 directions, length 2)
    for dx, dy in [(0,-5),(0,5),(-5,0),(5,0),(-4,-4),(4,-4),(-4,4),(4,4)]:
        px(t, cx+dx, cy+dy, SUN_Y)
        # Mid-ray
        if abs(dx)==4 and abs(dy)==4:
            px(t, cx+dx//2, cy+dy//2, SUN_D)
    # Ray outlines
    for dx, dy in [(0,-6),(0,6),(-6,0),(6,0),(-5,-5),(5,-5),(-5,5),(5,5)]:
        px(t, cx+dx, cy+dy, OL)
    # Sun outline ring
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            d = dx*dx + dy*dy
            if 9 < d <= 16: px(t, cx+dx, cy+dy, SUN_D)
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            d = dx*dx + dy*dy
            if 16 < d <= 18: px(t, cx+dx, cy+dy, OL)

df = make_tile(DESERT_BG, draw_desert)
df.save('D:/Code/SourceCode/GameDev/8x-8/assets/tiles/territory_desert.png')
print("✓ territory_desert.png")


# THUNDER TILE ── dark storm with lightning bolt icon
THUNDER_BG  = (20, 15, 45, 255)
THUNDER_BDR = (10, 7,  22, 255)
BOLT_Y      = (239, 220, 40, 255)
BOLT_H      = (255, 255, 160, 255)
BOLT_D      = (180, 140, 10, 255)

def draw_thunder(t):
    # Classic zigzag lightning bolt (centered)
    bolt = [
        (2, [9, 10, 11]),
        (3, [8, 9, 10]),
        (4, [7, 8, 9]),
        (5, [6, 7, 8, 9, 10, 11]),
        (6, [7, 8, 9, 10, 11]),
        (7, [6, 7, 8]),
        (8, [5, 6, 7]),
        (9, [4, 5, 6, 7, 8, 9, 10]),
        (10,[5, 6, 7, 8, 9, 10]),
        (11,[6, 7, 8]),
        (12,[7, 8]),
    ]
    for y, xs in bolt:
        for x in xs: px(t, x, y, BOLT_Y)
    # Bright inner core
    bolt_inner = [(3,[9]),(4,[8]),(5,[8,9]),(6,[9,10]),(7,[7]),(8,[6]),(9,[6,7]),(10,[7,8])]
    for y, xs in bolt_inner:
        for x in xs: px(t, x, y, BOLT_H)
    # Dark outer border on bolt
    outline_b = [
        (1,9),(1,10),(1,11),(1,12),(2,8),(2,12),(3,7),(3,11),
        (4,6),(4,10),(5,5),(5,12),(6,5),(6,12),(7,5),(7,9),
        (8,4),(8,8),(9,3),(9,11),(10,4),(10,11),(11,5),(11,9),
        (12,6),(12,9),(13,7),(13,8),
    ]
    for y, x in outline_b: px(t, x, y, OL)
    # Glow effect (dim yellow around bolt)
    for y, xs in bolt:
        for x in xs:
            for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                nx, ny = x+dx, y+dy
                from PIL import Image as _I
                if 1 <= nx <= 14 and 1 <= ny <= 14:
                    if t.getpixel((nx, ny)) == THUNDER_BG:
                        px(t, nx, ny, BOLT_D)

tf = make_tile(THUNDER_BG, draw_thunder)
tf.save('D:/Code/SourceCode/GameDev/8x-8/assets/tiles/territory_thunder.png')
print("✓ territory_thunder.png")

print("\nAll sprites regenerated successfully!")
