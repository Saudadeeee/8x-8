# -*- coding: utf-8 -*-
"""Bang dich dot 11 — phan ung, hinh the o, nhan Inspector, chuoi le con lai."""
MAP = {
    # ── Ten phan ung ───────────────────────────────────────────────────────
    "Tan Chảy": "Melt",
    "Quá Tải": "Overload",
    "Siêu Dẫn": "Superconduct",
    "Kết Tinh": "Crystallize",
    "Lan Truyền": "Contagion",

    # ── Hinh the o nguyen to ───────────────────────────────────────────────
    "Lưỡng Nghi Song Cực": "Dual Poles",
    "Tứ Trụ Kình Thiên": "Four Pillars",
    "Tứ Tinh Củng Nguyệt": "Ring of Four",
    "Long khí bộc phát, 3 ô cùng hệ xếp thẳng hàng — tháp ngự phía trên được tăng cường 1 tầm đánh.":
        "Dragon breath surges: 3 matching veins in a straight line - pieces above them gain +1 reach.",
    "Khí trường giao thoa, 2 ô mang nguyên tố sinh phản ứng xếp liền kề — tự động kích hoạt bùng phát mỗi 4 giây.":
        "Crossing fields: 2 adjacent veins whose elements react - they detonate on their own every 4 seconds.",
    "Trấn giữ tứ phương, ngưng tụ thành khối 2×2 cùng hệ — uy lực phản ứng từ trận đồ bùng nổ thêm 40%.":
        "Holding all four quarters: a 2x2 block of matching veins - reactions from this formation hit 40% harder.",
    "Vạn pháp quy tông, 4 ô cùng hệ bao bọc 1 ô thường (trận nhãn) — ô trung tâm hội tụ trọn vẹn 4 tầng Ấn ký.":
        "All paths converge: 4 matching veins surrounding 1 plain square - the centre holds all 4 Mark layers at once.",

    # ── Chuoi le ───────────────────────────────────────────────────────────
    "Kho Báu Chiến Tranh": "Spoils of War",
    "Long Mạch %s": "%s Ley Line",
    "Mạch %s": "%s Vein",
    "Tro nóng nuôi lửa: đòn đánh rực hơn, địch cũng liều hơn.":
        "Hot ash feeds the fire: your hits burn brighter, and the enemy fights harder.",
    "+12% chí mạng.": "+12% critical chance.",
    "Làm chậm 25%, địch chết để lại mảnh vàng": "Slows by 25%; slain enemies drop gold shards",
    "Nhận %d ô %s — đặt chồng lên nhau để lên Lv2 ngay.":
        "Gain %d %s veins - stack them to reach Lv2 immediately.",
    "Nhận %d ô %s — mở hướng đi mới.": "Gain %d %s veins - opening a new direction.",
    "Sát thương lên RIÊNG Rival King / máu hắn": "Damage to the Rival King alone / his HP",
    "Đủ %d nguyên tố khác nhau trên bàn: %.0f%% mỗi phản ứng thăng cấp thành NGUYÊN SƠ — nổ %.0f%% trong %.1fm.":
        "With %d different elements on the board: %.0f%% of reactions upgrade to PRIMAL - a %.0f%% blast within %.1fm.",
    " %d tháp": " %d pieces",
    " %d địch": " %d enemies",
    "chậm": "slower",
    "nhanh": "faster",

    # ── Nhan Inspector (tac gia noi dung nhin thay) ────────────────────────
    "Hoàng Lệnh": "Royal Command",
    "Lựa chọn...": "Choice...",
    "Tên Vua": "King Name",
    "Tên Đơn Vị": "Unit Name",
    "Tên Quân": "Soldier Name",
    "Tên Lãnh Thổ": "Territory Name",
    "Tên Sự Kiện": "Event Name",
    "Tiền Quân": "Vanguard",
    "Quân Tinh Nhuệ": "Elite Guard",
    "Kênh tác dụng — điền ÍT NHẤT một nhóm": "Effect channel - fill in AT LEAST one group",
    "Tác dụng — điền ÍT NHẤT một nhóm": "Effect - fill in AT LEAST one group",
    "Nhận dạng": "Identity",
    "Tác dụng": "Effect",
    "Vùng ném": "Throw area",
    "Xe (dọc+ngang)": "Rook (rank + file)",
    "Tượng (chéo)": "Bishop (diagonal)",
    "Mã (chữ L)": "Knight (L-jump)",
    "Tốt (4 chéo kề)": "Pawn (4 diagonals)",
    "Vua (8 ô kề)": "King (8 adjacent)",
    "Toả tròn (mọi hướng)": "Radial (all directions)",
}
