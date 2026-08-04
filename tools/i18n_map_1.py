# -*- coding: utf-8 -*-
"""Bang dich dot 1 — TEN RIENG cua noi dung: quan, dich, vua, bo khai cuoc,
nguyen to, o nguyen to, the co, nuoc di.

Nguyen tac dat ten tieng Anh:
  - Quan muon tu co khac giu ten GOC cua no (Lance, Gold General, Xiangqi
    Elephant) — nguoi choi tra Google ra dung thu do.
  - The co uu tien thuat ngu co vua CO THAT (Battery, Crossfire, Pawn Wall).
  - Nguyen to dung mot tu (Fire/Ice/Thunder/Water/Poison/Earth).
"""
MAP = {
    # ── Quan co ────────────────────────────────────────────────────────────
    "Pháo": "Cannon",
    "Hương Xa": "Lance",
    "Kim Tướng": "Gold General",
    "Tượng Điền": "Xiangqi Elephant",
    "Kỵ Xúc Xắc": "Dice Rider",
    "Tốt": "Pawn",
    "Mã": "Knight",
    "Tượng": "Bishop",
    "Xe": "Rook",
    "Hậu": "Queen",
    "Chủ Soái": "Commander",
    "Nỏ Thủ": "Crossbowman",
    "Máy Bắn Đá": "Catapult",
    "Pháp Sư Hắc Ám": "Warlock",
    "Ma Đạo Sĩ": "Dark Mage",
    "Cung Trường": "Longbowman",
    "Thánh Kỵ": "Paladin",
    "Luyện Kim Sư": "Alchemist",
    "Vệ Binh Băng": "Ice Guardian",
    "Nỏ Công Thành": "Ballista",

    # ── Dich ───────────────────────────────────────────────────────────────
    "Dơi Quỷ": "Bat Swarm",
    "Golem Đá": "Stone Golem",
    "Kỵ Sĩ Đen": "Dark Knight",
    "Oán Hồn": "Wraith",
    "Pháp Sư Tà Thuật": "Shaman",
    "Quỷ Con": "Demon Imp",
    "Xương Cốt": "Skeleton",
    "Vua Băng Giá": "The Frost King",
    "Vua Địa Ngục": "The Hell King",
    "Vua Hoang Dã": "The Wild King",

    # ── Vua choi duoc ──────────────────────────────────────────────────────
    "Vua Thép": "The Iron King",
    "Vua Bóng Ma": "The Phantom King",
    "Nữ Hoàng Lửa": "The Flame Queen",
    "Vua Bão Tố": "The Storm King",
    "Vua Băng Hà": "The Glacier King",
    "Vua Thương Hội": "The Merchant King",

    # ── Chieu cua Vua ──────────────────────────────────────────────────────
    "Sắc Lệnh Thép": "Iron Decree",
    "Màn Bóng Tối": "Shadow Veil",
    "Hoả Ngục Hoàng Gia": "Royal Inferno",
    "Thiên Lôi Trận": "Thunder Array",
    "Vĩnh Đông": "Endless Winter",
    "Kim Khố": "Golden Coffer",

    # ── Bo Khai Cuoc ───────────────────────────────────────────────────────
    "Bộ Chuẩn": "Standard Set",
    "Bộ Tốt Thí": "Pawn Storm",
    "Bộ Cờ Tướng": "Xiangqi Set",
    "Bộ Shogi": "Shogi Set",
    "Bộ Cá Ngựa": "Ludo Set",
    "Bộ Khổ Hạnh": "Ascetic Set",
    "Cờ vua": "Chess",
    "Cờ tướng": "Xiangqi",
    "Shogi": "Shogi",
    "Cá ngựa": "Ludo",

    # ── The co ─────────────────────────────────────────────────────────────
    "Trận Pháo": "Battery",
    "Giao Hoả": "Crossfire",
    "Song Mã": "Knight Pair",
    "Tường Tốt": "Pawn Wall",
    "Cấm Vệ": "Royal Guard",
    "Thê Đội": "Echelon",
    "Nước Chĩa": "Fork",

    # ── Luat Rival King ────────────────────────────────────────────────────
    "Vua Câm": "The Mute King",
    "Vua Nghẽn": "The Choked King",
    "Vua Nghiêng": "The Tilted King",
    "Vua Gương": "The Mirror King",
    "Vua Vội": "The Hasty King",
    "Vua Thuế": "The Toll King",

    # ── Nguyen to ──────────────────────────────────────────────────────────
    "Hoả": "Fire",
    "Băng": "Ice",
    "Lôi": "Thunder",
    "Thuỷ": "Water",
    "Độc": "Poison",
    "Thổ": "Earth",

    # ── O nguyen to ────────────────────────────────────────────────────────
    "Mạch Hoả": "Fire Vein",
    "Mạch Thuỷ": "Water Vein",
    "Mạch Băng": "Ice Vein",
    "Mạch Độc": "Poison Vein",
    "Mạch Thổ": "Earth Vein",
    "Mạch Lôi": "Thunder Vein",

    # ── Vung dat ───────────────────────────────────────────────────────────
    "Hoang Mạc": "Wasteland",
    "Băng Nguyên": "Tundra",
    "Hoả Diệm": "Volcanic",
    "Đầm Lầy": "Swamp",
    "Rừng Thẳm": "Verdant",

    # ── Bac hiem ───────────────────────────────────────────────────────────
    "Thường": "Common",
    "Hiếm": "Rare",
    "Sử Thi": "Epic",
    "Huyền Thoại": "Legendary",

    # ── Mua ────────────────────────────────────────────────────────────────
    "Mùa Xuân": "Spring",
    "Mùa Hè": "Summer",
    "Mùa Thu": "Autumn",
    "Mùa Đông": "Winter",
    "Mùa Xuân (Wild)": "Spring (Wild)",
    "Mùa Hè (Mixed)": "Summer (Mixed)",
    "Mùa Thu (Undead)": "Autumn (Undead)",
    "Mùa Đông (Hell)": "Winter (Hell)",

    # ── Nuoc di (nhan trong panel va codex) ────────────────────────────────
    "Dọc hàng & cột (trượt)": "Rank & file (sliding)",
    "Hai đường chéo (trượt)": "Both diagonals (sliding)",
    "Tám hướng (trượt)": "All eight directions (sliding)",
    "Nhảy chữ L (không bị chặn)": "L-jump (never blocked)",
    "Bốn ô chéo kề": "Four adjacent diagonals",
    "Tám ô kề": "Eight adjacent squares",
    "Vành khuyên (không đánh sát mình)": "Ring (cannot hit adjacent)",
    "Mọi hướng trong tầm": "All directions in range",
    "Pháo — phải có ĐÚNG 1 quân làm ngòi": "Cannon - needs EXACTLY 1 screen piece",
    "Hương Xa — một hướng, tầm rất xa": "Lance - one direction, very long reach",
    "Kim Tướng — 4 hướng + 2 chéo trước": "Gold General - 4 straight + 2 forward diagonals",
    "Tượng cờ tướng — chéo đúng 2 ô, bị cản tâm": "Xiangqi Elephant - exactly 2 diagonal, blockable at midpoint",
    "Cá Ngựa — vành khuyên rộng, sát thương lớn": "Dice Rider - wide ring, heavy damage",
}
