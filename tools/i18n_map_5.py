# -*- coding: utf-8 -*-
"""Bang dich dot 5 — THUOC + TRANG BI (ten + mo ta)."""
MAP = {
    # ── Thuoc ──────────────────────────────────────────────────────────────
    "Rượu Cường Lực": "Strength Brew",
    "Dầu Nhanh Tay": "Quickhand Oil",
    "Nước Mắt Đại Bàng": "Eagle's Tear",
    "Bình Nước Bẩn": "Murky Flask",
    "Bom Lửa": "Firebomb",
    "Bùa Đa Thủ": "Manyhands Charm",
    "Cát Thời Gian": "Sands of Time",
    "Cầu Băng": "Ice Orb",
    "Khí Độc": "Toxic Cloud",
    "Khiên Vương Triều": "Royal Aegis",
    "Lọ Sét": "Bottled Bolt",
    "Máu Rồng": "Dragon Blood",
    "Máu Vua": "King's Blood",
    "Nọc Rắn": "Serpent Venom",
    "Nước Ép Đa Sắc": "Prismatic Juice",
    "Nước Thánh": "Holy Water",
    "Sương Băng Giá": "Hoarfrost",
    "Tia Sét Đóng Chai": "Bottled Lightning",
    "Tinh Dầu Xuyên Giáp": "Armor-Piercing Oil",
    "Vụn Đá": "Stone Shards",

    "Tháp trong vùng +40% sát thương trong 12 giây.":
        "Pieces in the area gain +40% damage for 12 seconds.",
    "Tháp trong vùng giảm 0.35s hồi chiêu trong 12 giây.":
        "Pieces in the area lose 0.35s cooldown for 12 seconds.",
    "Tháp trong vùng +2 tầm bắn trong 12 giây.":
        "Pieces in the area gain +2 reach for 12 seconds.",
    "Không gây sát thương — gắn Dấu Thuỷ cho TOÀN BỘ địch trên màn.":
        "Deals no damage - applies a Water Mark to EVERY enemy on screen.",
    "120 sát thương trong vùng 2m và gắn Dấu Hoả.":
        "120 damage in a 2m area and applies a Fire Mark.",
    "Tháp trong vùng bắn thêm 1 mũi đạn mỗi đòn trong 12 giây.":
        "Pieces in the area fire 1 extra projectile per shot for 12 seconds.",
    "Toàn bộ địch trên bản đồ bị chậm 60% trong 5 giây.":
        "Every enemy on the map is slowed by 60% for 5 seconds.",
    "60 sát thương, gắn Dấu Băng và làm chậm 50% trong 5 giây.":
        "60 damage, applies an Ice Mark and slows by 50% for 5 seconds.",
    "Vùng khí độc tồn tại 8 giây — địch đi vào dính 3 tầng Độc.":
        "A toxic cloud lingers for 8 seconds - enemies entering take 3 Poison stacks.",
    "Nhà Vua miễn mọi sát thương trong 10 giây.":
        "The King is immune to all damage for 10 seconds.",
    "80 sát thương xuyên giáp và gắn Dấu Lôi.":
        "80 armor-piercing damage and applies a Thunder Mark.",
    "Tháp trong vùng gắn Dấu Hoả trong 12 giây.":
        "Pieces in the area apply Fire Marks for 12 seconds.",
    "Hồi ngay 5 máu cho Nhà Vua.":
        "Instantly restore 5 HP to the King.",
    "Tháp trong vùng gắn Dấu Độc trong 12 giây.":
        "Pieces in the area apply Poison Marks for 12 seconds.",
    "Mỗi tháp trong vùng gắn một Dấu NGẪU NHIÊN trong 12 giây, kể cả khi đứng ô thường.":
        "Each piece in the area applies a RANDOM Mark for 12 seconds, even on a plain square.",
    "Tháp trong vùng gắn Dấu Thuỷ trong 12 giây.":
        "Pieces in the area apply Water Marks for 12 seconds.",
    "Tháp trong vùng gắn Dấu Băng trong 12 giây.":
        "Pieces in the area apply Ice Marks for 12 seconds.",
    "Tháp trong vùng gắn Dấu Lôi trong 12 giây.":
        "Pieces in the area apply Thunder Marks for 12 seconds.",
    "Tháp trong vùng bỏ qua hoàn toàn giáp trong 12 giây.":
        "Pieces in the area ignore armor entirely for 12 seconds.",
    "Gắn Dấu Thổ và làm chậm 40% trong 6 giây.":
        "Applies an Earth Mark and slows by 40% for 6 seconds.",
}
