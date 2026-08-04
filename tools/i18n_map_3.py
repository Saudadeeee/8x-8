# -*- coding: utf-8 -*-
"""Bang dich dot 3 — DI VAT (ten + mo ta)."""
MAP = {
    # ── Ten di vat ─────────────────────────────────────────────────────────
    "Sách Giả Kim": "Alchemist's Tome",
    "Bàn Tay Dược Sư": "Apothecary's Hand",
    "Túi Thuốc Rộng": "Deep Satchel",
    "Vương Miện Gãy": "Broken Crown",
    "Cờ Tàn": "Endgame",
    "Đại Cục": "Grand Strategy",
    "Vó Ngựa": "Horseshoe",
    "Vua Đơn Độc": "Lone King",
    "Con Tốt Thí": "Sacrificial Pawn",
    "Mũi Khoan Công Thành": "Siege Bore",
    "Mũi Giáo Xuyên": "Spearhead",
    "Trống Trận": "War Drum",
    "Bánh Xe Nguyên Tố": "Elemental Wheel",
    "Địa Chất Sư": "Geomancer",
    "Đe Của Thần": "Anvil of the Gods",
    "Vòng Cổ Thợ Săn": "Hunter's Collar",
    "Long Mạch Sống": "Living Ley Line",
    "Trái Tim Nguyên Sơ": "Primal Heart",
    "Lò Phản Ứng": "Reactor Core",
    "Kho Vũ Khí": "Armory",
    "Đất Cằn": "Barren Ground",
    "Vây Bắt": "Encirclement",
    "Pháo Đài": "Fortress",
    "Đường Kim Tướng": "Gold Road",
    "Long Mạch Lan": "Spreading Ley Line",
    "Tốt Nổ": "Bursting Pawn",
    "Tốt Trường Thương": "Pikeman Pawn",
    "Phong Cấp Shogi": "Shogi Promotion",
    "Song Thủ": "Twin Grip",
    "Ống Nhòm": "Spyglass",
    "Bản Đồ Kho Báu": "Treasure Map",

    # ── Mo ta di vat ───────────────────────────────────────────────────────
    "Mọi phản ứng nguyên tố +40% sát thương.":
        "All elemental reactions deal +40% damage.",
    "Thuốc buff kéo dài thêm 20 giây.":
        "Potion buffs last 20 seconds longer.",
    "Túi thuốc +2 ô.":
        "+2 potion slots.",
    "Mỗi LOẠI thế cờ khác nhau trên bàn cộng +0.22 Bội cho toàn bàn. Thưởng cho đội hình đa dạng, không phải đội hình dồn một kiểu.":
        "Each DIFFERENT formation type on the board adds +0.22 Mult board-wide. Rewards variety, not stacking one shape.",
    "Mỗi ô trống dưới trần quân cộng +0.035 Bội. Bàn thưa thì mỗi quân đáng giá hơn — đi ngược với lối lấp đầy.":
        "Each empty slot under your unit cap adds +0.035 Mult. A thin board makes every piece worth more - the opposite of filling up.",
    "Cộng gộp: mọi thế +0.25 Bội, và mỗi loại thế khác nhau thêm +0.2 nữa.":
        "Both at once: every formation gets +0.25 Mult, and each different formation type adds another +0.2.",
    "Mã nhảy thêm một vòng chữ L xa hơn — phủ tới 16 ô thay vì 8.":
        "Knights gain one more L-ring - covering up to 16 squares instead of 8.",
    "Bàn càng thưa càng mạnh (+0.045 mỗi ô trống) nhưng phải trả bằng chỗ: không cộng gì nếu bàn đã kín.":
        "The thinner the board the stronger you get (+0.045 per empty slot) - but it pays nothing on a full board.",
    "Mỗi Tốt đứng trên bàn cộng +0.08 Bội cho toàn bàn. Tường Tốt bỗng thành nền móng.":
        "Every Pawn on the board adds +0.08 Mult board-wide. Suddenly the Pawn Wall is a foundation.",
    "Đường trượt xuyên qua HAI quân của mình, và mọi thế cờ mạnh thêm +0.2 Bội. Riêng lượt xuyên thứ hai chỉ đáng ~7% — phần giá trị thật nằm ở thế cờ.":
        "Sliding lines pass through TWO of your own pieces, and every formation gains +0.2 Mult. The second pierce alone is worth only ~7% - the real value is in the formations.",
    "Xe, Tượng và Hậu bắn XUYÊN QUA một quân của mình rồi mới dừng. Bàn càng chật càng đáng giá — với 7 quân đã mất 19% tầm phủ vì bị chắn.":
        "Rooks, Bishops and Queens fire THROUGH one of your own pieces before stopping. The tighter the board the better - at 7 pieces you already lose 19% of your coverage to blocking.",
    "Mọi thế cờ mạnh thêm +0.35 Bội. Càng xếp được nhiều thế, càng lãi.":
        "Every formation gains +0.35 Mult. The more you build, the more it pays.",
    "Địch mang được 3 Dấu cùng lúc thay vì 2.":
        "Enemies can carry 3 Marks at once instead of 2.",
    "Ô nguyên tố rẻ 40% — xây mạng lưới nhanh gấp đôi.":
        "Element veins cost 40% less - build your network twice as fast.",
    "Mỗi tháp có thêm 1 ô trang bị (2 → 3).":
        "Every piece gains 1 more equipment slot (2 -> 3).",
    "Địch đang mang Dấu nhận +15% sát thương từ MỌI nguồn.":
        "Marked enemies take +15% damage from EVERY source.",
    "Ô Lv3 lan Dấu của nó sang 4 ô kề.":
        "Level 3 veins spread their Mark to the 4 adjacent squares.",
    "Đủ 6 nguyên tố trên bàn: mọi tháp +30% sát thương.":
        "With all 6 elements on the board, every piece deals +30% damage.",
    "20% phản ứng nổ mà KHÔNG tiêu thụ Dấu.":
        "20% of reactions fire WITHOUT consuming their Marks.",
    "Trang bị lắp trên một quân áp cho MỌI quân cùng loại. Chọn con nào để lắp thành chọn LOẠI nào để đầu tư.":
        "Equipment on one piece applies to EVERY piece of the same type. Choosing which unit to equip becomes choosing which TYPE to invest in.",
    "Ô KHÔNG có nguyên tố cộng +45% Bội. Mở lối chơi phản nguyên tố — dồn hết vàng vào quân thay vì vào ô.":
        "Squares WITHOUT an element add +45% Mult. Opens an anti-element line - pour every coin into pieces instead of veins.",
    "Cờ vây. Ô có từ ba quân kề trở lên cộng +0.25 Bội mỗi quân kề. Thưởng cho việc dồn cụm chật.":
        "Go. A square with three or more adjacent pieces gains +0.25 Mult per neighbour. Rewards packing tight.",
    "Mọi Xe đánh theo luật PHÁO cờ tướng: phải có đúng một quân của bạn làm ngòi. Bù lại sát thương ×2.5. Quân chắn đường từ tai hoạ thành tài nguyên.":
        "Every Rook fires by XIANGQI CANNON rules: it needs exactly one of your pieces as a screen. In exchange, x2.5 damage. Blocking pieces go from a disaster to a resource.",
    "Mọi Tốt đánh theo nước KIM TƯỚNG shogi: bốn hướng thẳng và hai chéo trước. Sáu ô thay vì bốn.":
        "Every Pawn moves as a shogi GOLD GENERAL: four straight and two forward diagonals. Six squares instead of four.",
    "Ô kề ô nguyên tố cũng được tính là có hệ (×1.15 Bội). Ba ô nguyên tố phủ được cả một vùng.":
        "Squares next to an element vein count as elemental too (x1.15 Mult). Three veins can cover a whole region.",
    "Mọi Tốt đánh CẢ TÁM ô kề thay vì bốn ô chéo. Tường Tốt từ hàng rào mỏng thành bức tường thật.":
        "Every Pawn hits ALL EIGHT adjacent squares instead of four diagonals. The Pawn Wall stops being a fence and becomes a wall.",
    "Mọi Tốt đánh thẳng một hướng xuôi bàn, tầm rất xa. Đổi phủ rộng lấy phủ sâu.":
        "Every Pawn fires straight down the board, very far. Trades width for depth.",
    "Mọi quân ★3 đánh theo nước HẬU — tám hướng, trượt. Shogi cho phong cấp gần như mọi quân, không riêng Tốt.":
        "Every 3-star piece moves as a QUEEN - eight directions, sliding. Shogi promotes almost every piece, not just Pawns.",
    "Hai trang bị TRÙNG loại thì hiệu ứng NHÂN đôi thay vì cộng.":
        "Two copies of the SAME equipment MULTIPLY instead of add.",
    "Bán kính mọi bình thuốc tăng lên 4m.":
        "Every potion's radius increases to 4m.",
    "Địch Elite LUÔN rơi thuốc.":
        "Elite enemies ALWAYS drop a potion.",
}
