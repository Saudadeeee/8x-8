# -*- coding: utf-8 -*-
"""Bang dich dot 4 — PERK (ten + mo ta)."""
MAP = {
    "Dầu Bôi Trơn": "Lubricant",
    "Địa Chủ": "Landlord",
    "Độc Sư": "Toxicologist",
    "Hầm Vàng": "Vault",
    "Hàn Băng Quyết": "Deep Freeze",
    "Hiến Tế": "Blood Offering",
    "Hoả Sư": "Pyromancer",
    "Lò Rèn Hoàng Gia": "Royal Forge",
    "Lôi Đình": "Thunderclap",
    "Lưỡi Giáo Tiền Tuyến": "Frontline Spears",
    "Mắt Đại Bàng": "Eagle Eye",
    "Ngân Khố": "Treasury",
    "Nhà Giả Kim": "Alchemist's Craft",
    "Quân Sư Hoàng Triều": "Royal Strategist",
    "Quyền Uy": "Authority",
    "Rèn Vũ Khí": "Weaponsmith",
    "Sắc Lệnh Khẩn": "Urgent Decree",
    "Thần Chiến Tranh": "War God",
    "Thợ Ghép Mạch": "Ley Weaver",
    "Thợ Rèn Lang Thang": "Wandering Smith",
    "Thuần Vật Lý": "Pure Steel",
    "Thuế Chư Hầu": "Vassal Tribute",
    "Thuế Máu": "Blood Tax",
    "Thuỷ Mạch": "Water Vein",
    "Tường Thành": "Rampart",

    "Giảm 0.08s thời gian hồi đòn của toàn bộ tháp.":
        "Cut 0.08s from every piece's cooldown.",
    "Ô nguyên tố trong shop rẻ hơn 25%.":
        "Element veins cost 25% less in the shop.",
    "Dấu Độc cộng dồn tối đa 8 tầng thay vì 5.":
        "Poison Marks stack up to 8 times instead of 5.",
    "Lãi suất vàng cuối wave tăng từ 10% lên 15%.":
        "End-of-wave interest rises from 10% to 15%.",
    "Phản ứng Đóng Băng kéo dài 3s thay vì 2s.":
        "The Freeze reaction lasts 3s instead of 2s.",
    "Mất 10 máu, nhận ngay 60 vàng.":
        "Lose 10 HP, gain 60 gold immediately.",
    "Thiêu đốt của Dấu Hoả mạnh thêm 50%. Nền của mọi lối chơi Hoả.":
        "Fire Mark burn deals 50% more. The foundation of every Fire build.",
    "+20% sát thương cho toàn bộ tháp.":
        "+20% damage for every piece.",
    "Phản ứng Dẫn Điện lan thêm 2 mục tiêu (4 → 6).":
        "The Conduct reaction chains to 2 more targets (4 -> 6).",
    "Thợ rèn mài lại toàn bộ khí giới: +8% sát thương cho toàn bộ tháp.":
        "The smiths regrind every blade: +8% damage for every piece.",
    "+1 tầm bắn cho toàn bộ tháp.":
        "+1 reach for every piece.",
    "Trần lãi vàng cuối wave tăng từ 15 lên 25.":
        "The end-of-wave interest cap rises from 15 to 25.",
    "Cứ 15 phản ứng nguyên tố nổ ra thì nhận 1 bình thuốc ngẫu nhiên.":
        "Every 15 elemental reactions grant a random potion.",
    "Quân sư dâng kế sách: +12% sát thương toàn bộ tháp và +3 Sắc Lệnh Hoàng Gia mỗi khi wave mới bắt đầu.":
        "The strategist offers a plan: +12% damage for every piece, and +3 Royal Decree at the start of each wave.",
    "Sắc Lệnh Hoàng Gia nhận được khi thắng wave tăng 50%.":
        "Royal Decree earned from clearing a wave increases by 50%.",
    "+10% sát thương cho toàn bộ tháp.":
        "+10% damage for every piece.",
    "+5 Sắc Lệnh Hoàng Gia mỗi khi wave mới bắt đầu.":
        "+5 Royal Decree at the start of each wave.",
    "+30% sát thương, -0.1s hồi đòn và +1 tầm bắn cho toàn bộ tháp.":
        "+30% damage, -0.1s cooldown and +1 reach for every piece.",
    "Ô nguyên tố rẻ hơn 15% và mọi Dấu Thổ gây thêm 30% sát thương.":
        "Element veins cost 15% less and every Earth Mark deals 30% more damage.",
    "Trang bị trong shop rẻ hơn 30%.":
        "Equipment costs 30% less in the shop.",
    "Tháp KHÔNG đứng trên ô nguyên tố nhận +35% sát thương. Phần thưởng cho lối chơi Thép Nguyên Bản.":
        "Pieces NOT standing on an element vein gain +35% damage. The reward for a Pure Steel build.",
    "Các lãnh chúa chư hầu cống nạp: +2 vàng mỗi khi tiêu diệt một địch.":
        "Vassal lords pay tribute: +2 gold per enemy killed.",
    "+1 vàng mỗi khi tiêu diệt một địch.":
        "+1 gold per enemy killed.",
    "Dấu Thuỷ tự lan sang 1 địch kề bên — mồi phản ứng cho cả bầy.":
        "Water Marks spread to 1 adjacent enemy - priming a reaction across the pack.",
    "+5 máu ngay lập tức.":
        "+5 HP immediately.",
}
