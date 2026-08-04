# -*- coding: utf-8 -*-
"""Bang dich dot 7 — UI: nut, nhan, tieu de, tooltip, tutorial, codex."""
MAP = {
    # ── Nut & tieu de man hinh ─────────────────────────────────────────────
    "⚔  BẮT ĐẦU": "⚔  START",
    "⚔  BẮT ĐẦU WAVE": "⚔  START WAVE",
    "⚔  Ván Mới": "⚔  New Run",
    "⚔  Chơi Lại": "⚔  Play Again",
    "⚔  TẠM DỪNG": "⚔  PAUSED",
    "⏸  TẠM DỪNG": "⏸  PAUSED",
    "▶  Chơi Tiếp": "▶  Continue",
    "▶  Tiếp tục  (ESC)": "▶  Resume  (ESC)",
    "▶  WAVE KẾ": "▶  NEXT WAVE",
    "★  Tiến Trình": "★  Progress",
    "★  TIẾN TRÌNH": "★  PROGRESS",
    "⚙  Cài đặt": "⚙  Settings",
    "⚙  Cài Đặt": "⚙  Settings",
    "⚙  CÀI ĐẶT": "⚙  SETTINGS",
    "✖  Thoát": "✖  Quit",
    "✖  Thoát game": "✖  Quit Game",
    "✖  Bỏ qua": "✖  Skip",
    "←  Quay Lại": "←  Back",
    "← Quay lại": "← Back",
    "♛  CHỌN VUA": "♛  CHOOSE YOUR KING",
    "♛  VUA ĐÃ MỞ": "♛  KINGS UNLOCKED",
    "⚒  CỬA HÀNG HOÀNG GIA": "⚒  ROYAL SHOP",
    "⚒  NÂNG CẤP VĨNH VIỄN": "⚒  PERMANENT UPGRADES",
    "◆  BỘ KHAI CUỘC": "◆  STARTING SETS",
    "◆  BỘ QUÂN": "◆  YOUR SET",
    "▣  LÃNH THỔ": "▣  VEINS",
    "🗡  GIẢI TÁN": "🗡  DISMISS",
    "Giải Tán": "Dismiss",
    "⚔  SẴN SÀNG CHIẾN ĐẤU!": "⚔  READY TO FIGHT!",
    "⚔  TRINH SÁT — WAVE %d": "⚔  SCOUTING — WAVE %d",
    "⚔  ĐÓNG GÓP SÁT THƯƠNG": "⚔  DAMAGE CONTRIBUTION",
    "Đóng góp sát thương": "Damage contribution",
    "☠  KẺ THÙ HÙNG MẠNH XUẤT HIỆN  ☠": "☠  A MIGHTY FOE APPEARS  ☠",
    "CHIẾN THẮNG!": "VICTORY!",
    "THẤT THỦ": "DEFEAT",
    "Vương quốc đứng vững!": "The kingdom holds!",
    "Vương quốc đã sụp đổ...": "The kingdom has fallen...",
    "SÁCH NGUYÊN TỐ": "CODEX",
    "Thủ Thành Cờ · Roguelike": "Chess Tower Defense · Roguelike",
    "v0.1 Truy Cập Sớm": "v0.1 Early Access",
    "  Menu chính": "  Main Menu",
    "  Về Menu Chính": "  Back to Menu",
    "  Lưu cài đặt": "  Save Settings",
    "✓ Đã lưu!": "✓ Saved!",
    "  CHỌN 1 ĐẶC QUYỀN": "  CHOOSE 1 PERK",
    "Chọn": "Choose",
    "CHỌN": "CHOOSE",
    "Mở khoá": "Unlock",
    "Nâng cấp": "Upgrade",
    "Bắt đầu chơi": "Start playing",
    "Bỏ qua": "Skip",
    "Tiếp ›": "Next ›",
    "Bước %d / %d": "Step %d of %d",
    "MIỄN PHÍ": "FREE",
    " Xáo": " Reroll",

    # ── Cai dat ────────────────────────────────────────────────────────────
    "Âm lượng Master": "Master Volume",
    "Âm nhạc": "Music",
    "Hiệu ứng âm thanh": "Sound Effects",
    "Toàn màn hình": "Fullscreen",
    "Tốc độ": "Speed",
    "Tốc độ %d×  (phím %d)": "Speed %d×  (key %d)",
    "Tạm dừng / Tiếp tục  (Space)": "Pause / Resume  (Space)",

    # ── Chi so & bang ──────────────────────────────────────────────────────
    "⚔ Sát thương": "⚔ Damage",
    " Tốc đánh": " Attack Speed",
    " Hồi chiêu": " Cooldown",
    "◎ Tầm bắn": "◎ Reach",
    "◎ Tầm hiệu dụng": "◎ Effective Reach",
    "◎ Ô đang phủ": "◎ Squares Covered",
    "%s Nước đi": "%s Movement",
    "❄ Làm chậm": "❄ Slow",
    " Thiêu đốt": " Burn",
    " Số đạn": " Projectiles",
    " AoE Splash": " AoE Splash",
    " DPS (ước tính)": " DPS (estimated)",
    "⚔ Tổng đã gây (cả loại)": "⚔ Total dealt (this type)",
    "⚔ Tháp trên ô": "⚔ Piece on square",
    "✦ Đang hưởng": "✦ Active Bonuses",
    "✦ Nguyên tố": "✦ Element",
    "✷ Phản ứng": "✷ Reaction",
    "⏱ Dấu kéo dài": "⏱ Mark Duration",
    "◈ Cấp ô": "◈ Vein Level",
    "◈ Ô đã đạt cấp tối đa.": "◈ This vein is at max level.",
    "⬢ Hình thế: ": "⬢ Formation: ",
    "[Lãnh thổ]": "[Vein]",
    "Điểm ô": "Square Score",
    "Nền × Bội": "Base × Mult",
    "NỀN của một ô": "BASE of a square",
    "BỘI của một ô": "MULT of a square",
    "Ngưỡng phải vượt": "Threshold to beat",
    "Sát thương cả wave / Tổng máu wave": "Wave damage / Total wave HP",
    "THIẾU %s — sửa bố cục trước khi bắt đầu": "SHORT BY %s — fix your board before starting",
    "☠ KHÔNG hạ nổi Rival King — hắn chạm Vua là thua ngay":
        "☠ You cannot kill the Rival King — if he reaches your King you lose instantly",
    "Ô này KHÔNG nằm trên đường — không sinh sát thương":
        "This square is NOT on the path — it deals no damage",
    "⚠ Quân này không phủ ô đường nào — nó không gây sát thương.":
        "⚠ This piece covers no path squares — it deals no damage.",
    "Ô vàng trên bàn = ô đường quân này với tới. Chỉ ô đó sinh sát thương.":
        "Gold squares on the board are path squares this piece reaches. Only those deal damage.",
    "%d ô (%d trên đường)": "%d squares (%d on path)",
    "  (gốc %d)": "  (base %d)",
    "+1 tầm": "+1 reach",
    "%+d tầm": "%+d reach",
    "%+.0f sát thương": "%+.0f damage",
    "%s%.2fs hồi chiêu": "%s%.2fs cooldown",
    "%+d vàng mỗi kill": "%+d gold per kill",
    "%.1f ô": "%.1f squares",
    "%.1f ô/s": "%.1f sq/s",
    "%.0f sát thương/giây": "%.0f damage/sec",
    "• Sao ★%d: ×%.2f sát thương (phép NHÂN, áp sau cùng)":
        "• Star ★%d: ×%.2f damage (MULTIPLIED, applied last)",
    "Sao tối đa": "Max stars",
    "Đặt thêm 1 %s lên ô này để lên ★%d": "Place 1 more %s here to reach ★%d",
    "Bán ô (+%d vàng)": "Sell vein (+%d gold)",
    "Bán món này, hoàn %d vàng.": "Sell this, refund %d gold.",
    "Hoàn 60% giá trị. Dùng khi cần đổi hướng build.":
        "Refunds 60% of its value. Use it when you need to change direction.",
    " Trang bị (%d/%d)": " Equipment (%d/%d)",
    "Chọn một món trong kho bên dưới.": "Pick an item from the inventory below.",
    "Ô túi trống — hạ Elite hoặc Rival King để nhận thuốc (%s)":
        "Empty slot — kill an Elite or a Rival King to earn a potion (%s)",
    "Đặt tower lên ô này để nhận buff.": "Place a piece here to gain its buff.",
    "◈ Đặt thêm 1 ô %s lên đây → Lv%d: Dấu +%.0fs · Phản ứng ×%.2f · Tháp +%.0f%%":
        "◈ Place 1 more %s vein here → Lv%d: Mark +%.0fs · Reaction ×%.2f · Piece +%.0f%%",

    # ── Nguon buff (bang "Dang huong") ─────────────────────────────────────
    "Nâng cấp": "Upgrade",
    "Vùng đất": "Terrain",
    "Sủng ái Vua": "King's Favor",
    "Ân Vương Miện": "Crown's Boon",
    "Hào quang": "Aura",
    "Đồng đội cùng loại": "Same-type allies",
    "Đồng đội cùng hệ": "Same-element allies",
    "Ô Phước/Nguyền": "Blessed/Cursed square",
    "Khí hậu vùng": "Regional climate",
    "Trang bị": "Equipment",
    "Thuốc": "Potion",
    "Ô nguyên tố": "Element vein",
    "Lớp %s": "Layer %s",
    "Đội hình": "Formation",
    "Kinh tế": "Economy",
    "Sinh tồn": "Survival",
    "Sắc Lệnh": "Decree",
    "Nguyên tố": "Element",
    "Năng lực": "Ability",
    "Quân địch": "Enemies",
    "Vật lý": "Physical",
    "Không có": "None",
    "Khắc / Kháng": "Weak / Resist",
    "Sự Kiện": "Event",
    "Bát Quái": "Bagua",
    "Không có ảnh hưởng đặc biệt.": "No special effect.",
    "Chưa có bộ quân.": "No set yet.",
    "— Chưa ghi nhận sát thương —": "— No damage recorded yet —",
    "×%d còn lại": "×%d left",
    "×%d lượt": "×%d uses",
    "bán kính %.1fm": "%.1fm radius",

    # ── Man ket thuc / meta ────────────────────────────────────────────────
    "Tới wave: %d": "Reached wave: %d",
    "Tới wave: 0": "Reached wave: 0",
    "Đã hạ: %d địch": "Enemies killed: %d",
    "Đã hạ: 0 địch": "Enemies killed: 0",
    "Vàng kiếm được: %d": "Gold earned: %d",
    "Vàng kiếm được: 0": "Gold earned: 0",
    "Điểm tích luỹ: %d ★": "Meta points: %d ★",
    "Điểm tích luỹ: 0 ★": "Meta points: 0 ★",
    "Combo cao nhất: %d": "Best combo: %d",
    "★ Đặc quyền: %d": "★ Perks: %d",
    "☠  Ascension cao nhất: A%d": "☠  Highest Ascension: A%d",
    "Thăng Cấp A%d": "Ascension A%d",
    "Độ khó thường  ·  đã mở tới A%d": "Normal difficulty  ·  unlocked up to A%d",
    "Độ khó thường. Thắng một ván để mở khoá A1.":
        "Normal difficulty. Win a run to unlock A1.",
    "Máu địch +%d%%  ·  Tốc độ địch +%d%%  ·  Vàng khởi đầu %d  ·  Thưởng meta +%d%%":
        "Enemy HP +%d%%  ·  Enemy speed +%d%%  ·  Starting gold %d  ·  Meta reward +%d%%",
    "Máu: %d  |  Sắc Lệnh: %.0f/%.0f  |  Hồi: %.1f/giây  |  Ô đất: %d":
        "HP: %d  |  Decree: %.0f/%.0f  |  Regen: %.1f/s  |  Veins: %d",
    "Sủng ái: %s  |  Sát thương +%.0f%%  Tốc độ +%.0f%%  Tầm +%.0f%%":
        "Favors: %s  |  Damage +%.0f%%  Speed +%.0f%%  Reach +%.0f%%",
    "[%s]\\n%s\\n(Hồi chiêu %.0f giây  |  Tốn %.0f Sắc Lệnh)":
        "[%s]\\n%s\\n(Cooldown %.0fs  |  Costs %.0f Decree)",
    "Chọn một vị Vua": "Choose a King",
    " CHƯA MỞ — cần %d điểm tích luỹ": " LOCKED — needs %d meta points",
    "Đã mở: %s": "Unlocked: %s",
    "Đặc quyền đã chọn:\\n": "Perks chosen:\\n",
    "Không đủ Royal Decree hoặc đã mua": "Not enough Royal Decree, or already owned",
    "%s  [%s]  —  %d điểm": "%s  [%s]  —  %d pts",
    "%d quân trong bộ. Loại bớt quân yếu → tỉ lệ rút quân mạnh tăng lên.":
        "%d pieces in your set. Remove weak ones → your odds of drawing strong ones rise.",
    "Mỗi bộ lấy cảm hứng từ một loại cờ và mang luật riêng của loại đó.":
        "Each set draws on a different chess tradition and brings that tradition's rule.",
    "Shop bán thao tác lên bộ: loại quân · nâng sao vĩnh viễn · phong Hậu.":
        "The shop sells set operations: remove a piece · permanent star-up · promote to Queen.",

    # ── Nang cap meta ──────────────────────────────────────────────────────
    "Hầu bao dày (+30 vàng đầu ván)": "Deep Purse (+30 starting gold)",
    "Ngân khố sâu (+2 trần lãi)": "Deep Vault (+2 interest cap)",
    "Thuế máu (+1 vàng mỗi kill)": "Blood Tax (+1 gold per kill)",
    "Thành luỹ (+4 máu Vua)": "Bastion (+4 King HP)",
    "Đất phong (+1 ô lãnh thổ đầu ván)": "Fiefdom (+1 starting vein)",
    "Ấn tín lớn (+10 trần Sắc Lệnh)": "Great Seal (+10 Decree cap)",
    "Chiếu chỉ sẵn (+8 Sắc Lệnh đầu ván)": "Standing Edict (+8 starting Decree)",
    "Sắc lệnh khẩn (+1 Sắc Lệnh mỗi wave)": "Urgent Decree (+1 Decree per wave)",
    "Cộng hưởng (+6% sát thương phản ứng)": "Resonance (+6% reaction damage)",
    "Khắc sâu (+1 Dấu giữ được)": "Deep Etching (+1 Mark capacity)",
    "Địa chủ (ô nguyên tố rẻ 8%)": "Landlord (veins 8% cheaper)",
    "Rèn vũ khí (+4% sát thương mọi quân)": "Weaponsmith (+4% damage, all pieces)",
    "Luyện tay (+3% tốc đánh mọi quân)": "Drilling (+3% attack speed, all pieces)",
    "Thợ rèn quen (trang bị rẻ 10%)": "Familiar Smith (equipment 10% cheaper)",

    # ── Nhac viec ──────────────────────────────────────────────────────────
    "Click để đặt %s lên bản đồ": "Click to place %s on the board",
    "Click để chọn tháp cần giải tán (hoàn 50% vàng)":
        "Click a piece to dismiss it (refunds 50% gold)",
    "%s — Chọn vùng thả (%s) · Chuột phải để huỷ":
        "%s — Pick a target area (%s) · Right-click to cancel",
    "F1 — Sách Nguyên Tố": "F1 — Codex",
    "F1 hoặc ESC để đóng · B để xem bộ quân": "F1 or ESC to close · B for your set",
    "Bấm B để xem bộ quân và tỉ lệ rút từng loại":
        "Press B to see your set and each piece's draw odds",
    "Phần thưởng sau wave — hiệu lực đến hết ván":
        "Post-wave reward — lasts the rest of the run",
    "Tổng: %d địch phải tiêu diệt": "Total: %d enemies to kill",
    "Vùng môi trường: %s": "Region: %s",
    " Vùng: %s": " Region: %s",
    " Vùng: %s  —  %s": " Region: %s  —  %s",
    "Máu địch %s%d%%": "Enemy HP %s%d%%",
    "Địch %s %d%%": "Enemies %s %d%%",
    "Tháp %s%d%% sát thương": "Pieces %s%d%% damage",
    "Tháp bắn %s %.2fs": "Pieces fire %s %.2fs",
    "tháp trên ô +%.0f%% sát thương": "piece on square +%.0f%% damage",
    "Thiêu đốt ×%.2f": "Burn ×%.2f",
    "phản ứng ×%.2f": "reaction ×%.2f",
    "Dấu +%.0fs": "Mark +%.0fs",
    "chậm %.0f%%": "%.0f%% slow",
    "＋ ô trống": "＋ empty square",
    "Ô": "Square",

    # ── Codex ──────────────────────────────────────────────────────────────
    "◆ CÔNG THỨC — mọi thứ trong game chỉ sửa một trong hai số":
        "◆ THE FORMULA — everything in this game edits one of two numbers",
    "＋ NƯỚC ĐI — quân đánh theo luật cờ, không theo bán kính":
        "＋ MOVEMENT — pieces attack by chess rules, not by radius",
    "⬢ THẾ CỜ — nguồn BỘI lớn nhất, xếp chồng được":
        "⬢ FORMATIONS — your biggest MULT source, and they stack",
    "☠ RIVAL KING — mỗi vua đổi MỘT luật của bàn cờ":
        "☠ RIVAL KINGS — each one changes ONE rule of the board",
    "◆ SÁU NGUYÊN TỐ — địch mang tối đa %d Dấu cùng lúc":
        "◆ SIX ELEMENTS — an enemy carries at most %d Marks at once",
    "✷ PHẢN ỨNG — hai Dấu ghép được thì NỔ và tiêu thụ cả hai":
        "✷ REACTIONS — two matching Marks DETONATE and consume both",
    "⬢ HÌNH THẾ — bố cục ô có ý nghĩa": "⬢ VEIN PATTERNS — vein layout matters",
    "◈ CẤP Ô — đặt ô cùng loại lên chính nó để nâng cấp":
        "◈ VEIN LEVELS — place a matching vein on itself to upgrade",
    "⚔ KHẮC CHẾ — Dấu và phản ứng ăn ×%.1f khi khắc, ×%.1f khi bị kháng":
        "⚔ AFFINITY — Marks and reactions deal ×%.1f when strong, ×%.1f when resisted",
    "Tổng sát-thương-mỗi-giây của MỌI quân đang phủ ô đó. ":
        "Total damage-per-second of EVERY piece covering that square. ",
    "Quân không phủ ô nào trên ĐƯỜNG ĐI thì không đóng góp gì.":
        "A piece covering no PATH square contributes nothing.",
    "Thế cờ × cấp ô nguyên tố × di vật × luật Rival King. Các nguồn NHÂN ":
        "Formations × vein level × relics × Rival King rule. Sources MULTIPLY ",
    "với nhau, nên chồng được nhiều nguồn là con đường phá vỡ ván đấu.":
        "together, so stacking many sources is how you break the run open.",
    "NỀN × BỘI. Rê chuột lên ô để xem từng dòng góp vào.":
        "BASE × MULT. Hover a square to see every line that feeds it.",
    "Tổng máu cả wave. Thanh dưới đáy màn xanh là đủ, đỏ là biết trước sẽ thủng.":
        "Total HP of the whole wave. The bar at the bottom is green if you can clear it, red if you already know you cannot.",
    "⚠ Bị chặn": "⚠ Blocked",
    "Xe, Tượng và Hậu TRƯỢT — quân CỦA BẠN đứng chắn sẽ cắt đường bắn. ":
        "Rooks, Bishops and Queens SLIDE — YOUR OWN pieces in the way cut the line. ",
    "Mã nhảy qua được, không ai chặn nổi.": "Knights jump over everything; nothing blocks them.",
    "Lv1 Mạch": "Lv1 Vein",
    "Lv2 Nguồn": "Lv2 Source",
    "Lv3 Long Mạch": "Lv3 Ley Line",

    # ── Tutorial ───────────────────────────────────────────────────────────
    "Một con số phải vượt": "One number to beat",
    "Quân đánh theo nước đi thật": "Pieces move by real chess rules",
    "Thế cờ nhân sát thương": "Formations multiply your damage",
    "Bộ quân là build của bạn": "Your set is your build",
    "Nhịp một ván": "The rhythm of a run",
    "Đáy màn hình có hai con số: SÁT THƯƠNG đội hình bạn gây ra trong wave,":
        "Two numbers sit at the bottom of the screen: the DAMAGE your board deals this wave,",
    "và TỔNG MÁU của wave đó.": "and the TOTAL HP of that wave.",
    "Xanh = đủ sức. Đỏ = biết trước sẽ thủng, hãy sửa bố cục rồi hãy bấm.":
        "Green means you can clear it. Red means you already know you cannot — fix your board first.",
    "Không có đồng hồ đếm ngược — bạn có bao nhiêu thời gian tuỳ ý.":
        "There is no countdown. Take as long as you want.",
    "Rê chuột lên một ô để xem Nền × Bội của ô đó đến từ đâu":
        "Hover any square to see where its Base × Mult comes from",
    "Xe bắn dọc hàng và cột. Tượng bắn hai đường chéo. Mã nhảy chữ L.":
        "Rooks fire along ranks and files. Bishops fire on both diagonals. Knights jump in an L.",
    "Tốt đánh bốn ô chéo kề. Bạn đã biết những luật này rồi.":
        "Pawns hit the four adjacent diagonals. You already know these rules.",
    "Quân CỦA BẠN chắn đường trượt của Xe và Tượng — đứng sai chỗ là tự":
        "YOUR OWN pieces block a Rook's or Bishop's line — a bad placement",
    "bịt đường bắn của mình. Ô sáng vàng lúc đặt là ô ĐƯỜNG ĐI bạn phủ được;":
        "seals off your own fire. The gold squares shown while placing are PATH squares you cover;",
    "chỉ ô đường mới sinh sát thương.": "only path squares deal damage.",
    "Bàn khoá 8×8 cả ván và có trần số quân — chọn chỗ đứng là quyết định lớn nhất":
        "The board stays 8×8 all run and your unit count is capped — placement is your biggest decision",
    "Xếp quân thành thế có tên để nhân BỘI cho cả vùng:":
        "Arrange pieces into named formations to multiply MULT across an area:",
    "Trận Pháo — hai Xe cùng hàng hoặc cùng cột (×2.0)":
        "Battery — two Rooks on the same rank or file (×2.0)",
    "Giao Hoả — một ô bị cả Xe lẫn Tượng phủ (×2.2)":
        "Crossfire — a square covered by both a Rook and a Bishop (×2.2)",
    "Tường Tốt — ba Tốt liền nhau một hàng (×2.2)":
        "Pawn Wall — three Pawns side by side on one rank (×2.2)",
    "Nước Chĩa — một Mã phủ từ 3 ô đường trở lên (×3.0)":
        "Fork — one Knight covering 3 or more path squares (×3.0)",
    "Thế chồng lên nhau thì BỘI nhân với nhau. Đó là đường phá vỡ ván đấu.":
        "Overlapping formations MULTIPLY together. That is how a run breaks open.",
    "Nguồn BỘI thứ hai là Ô NGUYÊN TỐ mua trong shop: quân đứng trên ô nào":
        "Your second MULT source is the ELEMENT VEIN bought in the shop: a piece takes",
    "thì mang nguyên tố của ô đó, và ô lên cấp thì Bội tăng theo.":
        "the element of the square it stands on, and levelling that vein raises the Mult.",
    "Ô thuộc một thế được tô màu · vòng sáng dưới chân là nguyên tố của ô":
        "Squares in a formation are tinted · the glowing ring underfoot is the square's element",
    "Bạn khởi đầu với một bộ cờ thật. Shop RÚT quân từ bộ đó — muốn thấy Xe":
        "You start with a real chess set. The shop DRAWS from it — to see Rooks",
    "thường xuyên hơn thì phải LOẠI bớt Tốt khỏi bộ.":
        "more often, you must REMOVE Pawns from the set.",
    "Shop cũng bán: nâng sao vĩnh viễn cho một loại quân, và phong Hậu cho":
        "The shop also sells: a permanent star-up for one piece type, and promotion to Queen for",
    "toàn bộ Tốt. Bộ mỏng và nặng ký thắng bộ dày và loãng.":
        "all your Pawns. A thin, heavy set beats a thick, diluted one.",
    "Chuẩn bị → bấm BẮT ĐẦU WAVE → Shop → chọn 1 trong 3 Perk → lặp lại.":
        "Prepare → press START WAVE → Shop → pick 1 of 3 Perks → repeat.",
    "12 wave. Rival King ở wave 5, 9 và 12 — mỗi vua ĐỔI MỘT LUẬT của bàn cờ":
        "12 waves. Rival Kings at waves 5, 9 and 12 — each one CHANGES ONE RULE of the board",
    "(khoá Tượng, chỉ tính nửa bàn, cấm thế cờ cộng dồn…). Đọc luật rồi xếp lại.":
        "(silencing Bishops, counting only half the board, banning formation stacking...). Read the rule, then rebuild.",
    "Sao chỉ lên bằng cách đặt quân CÙNG LOẠI chồng lên nhau.":
        "Stars only come from stacking pieces of the SAME type on each other.",
    "F1 mở Sách tra cứu · Z/X/C ném thuốc giữa trận":
        "F1 opens the Codex · Z/X/C throw potions mid-fight",
}
