# -*- coding: utf-8 -*-
"""Bang dich dot 8 — HE THONG: thong bao, phan ung, hinh the, o nguyen to, vung dat."""
MAP = {
    # ── Thong bao trong tran ───────────────────────────────────────────────
    "⚠ Không đủ vàng! Cần %d": "⚠ Not enough gold! Need %d",
    "⚠ Không đủ vàng.": "⚠ Not enough gold.",
    "⚠ Không đủ vàng để xáo! Cần %d G": "⚠ Not enough gold to reroll! Need %d G",
    "⚠ Không đủ vàng Overcharge! Cần %d G": "⚠ Not enough gold to Overcharge! Need %d G",
    "⚠ Không đủ Royal Decree! Cần %.1f RD": "⚠ Not enough Royal Decree! Need %.1f RD",
    "⚠ Không thể mua hàng trong lúc chiến đấu!": "⚠ You cannot shop mid-battle!",
    "⚠ Không thể xáo shop trong lúc chiến đấu!": "⚠ You cannot reroll mid-battle!",
    "⚠ Không thực hiện được thao tác này.": "⚠ That operation is not possible.",
    "Đã đủ %d quân trên bàn — bán bớt hoặc ghép sao.":
        "You already have %d pieces on the board - sell some or merge for stars.",
    "☠ %s đã xuất trận! Hạ hắn để thống nhất vương quốc.":
        "☠ %s has taken the field! Bring him down to unite the kingdom.",
    "☠ Rival King bước sang PHA %d — hắn mạnh hơn!":
        "☠ The Rival King enters PHASE %d - he grows stronger!",
    "☠ Rival King vẫn đứng vững — hạ hắn để thống nhất vương quốc!":
        "☠ The Rival King still stands - bring him down to unite the kingdom!",
    "☠ RIVAL KING xuất trận — hạ hắn mới thắng!":
        "☠ A RIVAL KING takes the field - killing him is the only way to win!",
    "☠ WAVE BOSS %d (%s) — Một RIVAL KING xuất trận cùng %d hộ vệ: %s  |  %s":
        "☠ BOSS WAVE %d (%s) — A RIVAL KING marches with %d guards: %s  |  %s",
    "† RIVAL KING %d/%d ĐÃ GỤC NGÃ! +%d vàng":
        "† RIVAL KING %d/%d HAS FALLEN! +%d gold",
    "%s GỤC NGÃ!": "%s HAS FALLEN!",
    "⛁ Kho Báu Chiến Tranh: +%d vàng!": "⛁ Spoils of War: +%d gold!",
    "★ Nhận di vật: %s": "★ Relic gained: %s",
    "★ Đủ 5 di vật — bán bớt để đổi!": "★ All 5 relic slots full - sell one to swap!",
    "✦ Nhận %d ô %s!": "✦ Gained %d %s veins!",
    "✦ Nhận %d ô %s từ sự kiện!": "✦ Gained %d %s veins from the event!",
    "✦ Vùng đất mới tặng %d ô %s!": "✦ The new region grants %d %s veins!",
    "❤ Máu Vua: +%d máu!": "❤ King's Blood: +%d HP!",
    "◈ Mảnh %s!": "◈ %s shard!",
    "%s lên sao vĩnh viễn": "%s gains a permanent star",
    "Bộ mỏng đi → lượt sau dễ rút trúng quân mạnh hơn.":
        "A thinner set means better odds of drawing a strong piece next time.",
    "Đọc thông tin wave rồi xác nhận để bắt đầu chuẩn bị...":
        "Read the wave intel, then confirm to begin preparing...",
    "Bố trí xong thì bấm BẮT ĐẦU WAVE | %s":
        "When your board is ready, press START WAVE | %s",
    "BẮT ĐẦU WAVE": "START WAVE",
    "Giải tán một tháp, hoàn trả 50% giá trị Vàng.":
        "Dismiss a piece, refunding 50% of its gold value.",
    "[DISMISS] Click tháp để giải tán (RMB để hủy)":
        "[DISMISS] Click a piece to dismiss it (RMB to cancel)",
    "Đủ hạ Rival King (×%.1f) — chỗ nghẽn là đám hộ vệ":
        "Enough to kill the Rival King (×%.1f) - his guards are the bottleneck",
    " | Lãi: +%d vàng": " | Interest: +%d gold",
    " Địch chết tại đây": " Enemies dying here",
    "+%d vàng": "+%d gold",
    "+%d vàng ngay lập tức.": "+%d gold immediately.",
    "+1 tầm bắn": "+1 reach",
    "+6 Sát thương": "+6 Damage",
    "Chưa chọn vua.": "No king selected.",
    "Câu chuyện của vua...": "The king's story...",
    "Giá": "Cost",
    "Đầu hàng": "Surrender",
    "Gần nhất": "Nearest",

    # ── O tren ban ─────────────────────────────────────────────────────────
    "[Đất thường]": "[Plain ground]",
    "[Lối quái]": "[Enemy path]",
    "[Ô đặc biệt]": "[Special square]",
    "Đường đi": "Path",
    "◈ Vùng": "◈ Region",
    "◎ Toạ độ": "◎ Coordinates",
    "Đặt quân lên đây, hoặc mua ô nguyên tố để biến nó thành ô có hệ.":
        "Place a piece here, or buy an element vein to give this square an element.",
    "Đặt quân mạnh nhất lên đây. Ô này sinh sẵn khi tạo bản đồ.":
        "Put your strongest piece here. This square is generated with the map.",

    # ── Hinh the o nguyen to ───────────────────────────────────────────────
    "Hàng Long Trận": "Dragon Line",
    "Đại Pháo Đài": "Great Fortress",
    "Hai Xe trở lên cùng một hàng hoặc một cột.":
        "Two or more Rooks on the same rank or file.",
    "Một ô bị cả Xe lẫn Tượng phủ cùng lúc.":
        "A square covered by a Rook and a Bishop at once.",
    "Hai Mã phủ chung ít nhất một ô.":
        "Two Knights sharing at least one covered square.",
    "Ba Tốt trở lên đứng liền nhau trên cùng một hàng.":
        "Three or more Pawns side by side on one rank.",
    "Hậu có ít nhất hai quân kề bảo vệ.":
        "A Queen guarded by at least two adjacent pieces.",
    "Ba quân trở lên nằm trên cùng một đường chéo.":
        "Three or more pieces on the same diagonal.",
    "Một Mã phủ từ 3 ô đường đi trở lên.":
        "One Knight covering 3 or more path squares.",
    "Hai ô chồng lên nhau thành một Nguồn Lv2.":
        "Two stacked veins become a Level 2 Source.",
    "Ba ô cùng loại xếp chồng thành một Long Mạch Lv3.":
        "Three matching veins stacked become a Level 3 Ley Line.",

    # ── Mo ta o nguyen to ──────────────────────────────────────────────────
    "+25% Sát thương · Dấu Hoả": "+25% Damage · Fire Mark",
    "−15% Hồi chiêu · Dấu Thuỷ": "-15% Cooldown · Water Mark",
    "+1 Tầm bắn / +8% Sát thương · Dấu Băng": "+1 Reach / +8% Damage · Ice Mark",
    "+12% Sát thương / −8% Hồi chiêu · Dấu Độc": "+12% Damage / -8% Cooldown · Poison Mark",
    "+18% Sát thương · Dấu Thổ": "+18% Damage · Earth Mark",
    "+10% Sát thương / +1 Tầm · Dấu Lôi": "+10% Damage / +1 Reach · Thunder Mark",

    # ── Vung dat ───────────────────────────────────────────────────────────
    "Đất nứt nẻ, cằn cỗi. Không gì ưu ái, không gì cản trở.":
        "Cracked, barren ground. It favours nothing and hinders nothing.",
    "Giá buốt ghì chân địch — và cả tay xạ thủ.":
        "The cold drags at the enemy's feet - and at your archers' hands.",
    "Bùn níu từng bước chân — thép cũng rỉ theo hơi nước.":
        "Mud clings to every step - and steel rusts in the damp.",
    "Đất trù phú: vàng về nhiều hơn, thú dữ cũng dai hơn.":
        "Rich land: more gold comes in, and the beasts are hardier.",
    "Vùng Đất Vô Danh": "Unnamed Region",
    "Rừng Rậm": "Deep Forest",
    "Sa Mạc": "Desert",
    "Hoang Thổ": "Wastes",
    "Đầm Lầy Độc": "Toxic Swamp",
    "Lôi Vực": "Thunder Reach",
    "Hỏa Địa": "Fireland",
    "Vùng Hỏa Diệm": "Volcanic Region",
    "Lục Địa Xanh": "Green Continent",

    # ── Phan ung nguyen to ─────────────────────────────────────────────────
    "Bốc Hơi": "Vaporize",
    "Dẫn Điện": "Conduct",
    "Đóng Băng": "Freeze",
    "ĐÓNG BĂNG": "FROZEN",
    "Chấn Địa": "Quake",
    "Cháy Độc": "Toxic Burn",
    "Địa Chấn": "Seismic",
    "Đại Dịch": "Plague",
    "Biển Lửa": "Sea of Flame",
    "Băng Vĩnh Cửu": "Eternal Ice",
    "Cuồng Lôi Chấn Thiên": "Thunderstorm",
    "Băng Sơn Liệt Địa": "Glacier Split",
    "Dầu Dẫn": "Conductive Oil",
    "Dấu Nguyên Tố": "Element Mark",
    "Dấu mới được thêm": "the newest Mark added",
    "☯ Bát Quái": "☯ Bagua",

    # ── Mo ta dich ─────────────────────────────────────────────────────────
    "Bầy đàn yếu, bay nhanh": "Weak swarm, flies fast",
    "Di chuyển rất nhanh": "Moves very fast",
    "Đòn đánh mạnh": "Heavy hits",
    "Cực nhanh, máu giấy": "Extremely fast, paper HP",
    "Giáp 6: đòn nhẹ gần như vô dụng": "Armor 6: light hits are nearly useless",
    "6 sát thương/giây, cộng dồn tối đa 5 tầng": "6 damage/sec, stacks up to 5 times",
    "Cháy 12 sát thương/giây": "Burns for 12 damage/sec",
    "Giật 8 sát thương/giây, bỏ qua giáp": "Shocks for 8 damage/sec, ignores armor",
    "Địch nhẹ, nhanh: Dơi Quỷ và Goblin.":
        "Light, fast enemies: Bat Swarms and Goblins.",
    "Orc và Skeleton — đông và đều.": "Orcs and Skeletons - many and steady.",
    "Dark Knight và Demon Imp — dày máu hơn.":
        "Dark Knights and Demon Imps - thicker HP.",
    "Loài cứng nhất: Troll, Golem, Dark Knight.":
        "The toughest of all: Trolls, Golems, Dark Knights.",

    # ── Moc synergy nguyen to ──────────────────────────────────────────────
    "Hỏa Ấn bùng phát, mỗi nhịp thiêu đốt lan truyền sang kẻ địch trong phạm vi 1.5m.":
        "Fire Marks erupt: each burn tick spreads to enemies within 1.5m.",
    "Hàn khí thấu xương, trạng thái Đóng Băng gỡ bỏ hoàn toàn thời gian cooldown ẩn.":
        "Bone-deep cold: Freeze loses its hidden cooldown entirely.",
    "Đại địa sinh kim, trạng thái Kết Tinh ngưng tụ 40 vàng thay vì 15.":
        "The earth breeds gold: Crystallize condenses 40 gold instead of 15.",

    # ── Nuoc di (nhan phu) ─────────────────────────────────────────────────
    "Hậu (8 hướng)": "Queen (8 directions)",
    "Công thành (vành khuyên)": "Siege (ring)",
    "Đất phong": "Fiefdom",
}
