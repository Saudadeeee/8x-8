# -*- coding: utf-8 -*-
"""Bang dich dot 2 — MO TA noi dung: quan co, Vua, Bo Khai Cuoc, luat Rival King.

Giu nguyen giong van: cau ngan, noi thang cong dung, khong hoa my.
"""
MAP = {
    # ── Mo ta quan co ──────────────────────────────────────────────────────
    "Lính bắn cơ bản. Bắn đều, rẻ, dễ ghép sao. Nền của mọi đội hình.":
        "Basic shooter. Steady, cheap, easy to star up. The backbone of any board.",
    "Cận chiến, tầm rất ngắn nhưng sát thương một đòn cao. Đặt sát đường.":
        "Melee. Very short reach but heavy per-hit damage. Place right beside the path.",
    "Bắn xuyên hàng, hợp với đoạn đường thẳng dài.":
        "Pierces along a line. Best on long straight stretches of path.",
    "Chịu đòn tốt, tầm trung. Trụ giữ một ngã rẽ.":
        "Tough, medium reach. Anchors a corner.",
    "Tầm xa, sát thương lớn. Đắt — chỉ đáng khi có ô tốt để đứng.":
        "Long reach, heavy damage. Expensive - only worth it on a good square.",
    "Tăng sức cho quân quanh mình. Đặt giữa cụm, không đặt rìa bàn.":
        "Buffs nearby pieces. Place inside a cluster, never on the edge.",
    "Bắn nhanh, tầm khá. Ăn theo mọi buff tốc đánh.":
        "Fast shots, decent reach. Scales with every attack-speed buff.",
    "Đạn nổ theo vùng. Mạnh nhất khi địch đi thành đàn.":
        "Splash damage. Strongest when enemies come in packs.",
    "Gây sát thương theo thời gian. Hợp ô Độc và ô Hoả.":
        "Damage over time. Pairs with Poison and Fire veins.",
    "Sát thương phép diện rộng, hồi chiêu chậm.":
        "Wide magical damage, slow cooldown.",
    "Bắn tỉa tầm xa nhất nhì bàn. Đặt sau, phủ nhiều khúc đường.":
        "One of the longest reaches on the board. Place back, cover many path segments.",
    "Bền, có hào quang hỗ trợ. Neo giữ tuyến đầu.":
        "Durable, with a support aura. Anchors the front line.",
    "Yếu về sát thương thuần nhưng khuếch đại phản ứng nguyên tố.":
        "Weak raw damage but amplifies elemental reactions.",
    "Làm chậm địch trong tầm. Ghì đàn quái lại cho quân khác dọn.":
        "Slows enemies in reach. Holds the pack while others clean up.",
    "Một phát cực nặng, hồi chiêu rất chậm. Trị mục tiêu máu dày.":
        "One crushing shot, very slow cooldown. For high-HP targets.",
    "Cờ tướng. Bắn dọc hàng và cột NHƯNG phải có ĐÚNG MỘT quân của bạn nằm giữa làm ngòi. Không ngòi thì không bắn được ô nào.":
        "Xiangqi. Fires along ranks and files BUT needs EXACTLY ONE of your pieces in between as a screen. No screen, no shots at all.",
    "Shogi. Chỉ bắn thẳng MỘT hướng xuôi bàn, nhưng đi rất xa và xuyên hết hàng.":
        "Shogi. Fires straight in ONE direction only, but reaches very far down the file.",
    "Shogi. Phủ sáu ô kề: bốn hướng thẳng và hai chéo phía trước. Bền, hợp làm ngòi cho Pháo.":
        "Shogi. Covers six adjacent squares: four straight and two forward diagonals. Sturdy - a good screen for a Cannon.",
    "Cờ tướng. Nhảy chéo ĐÚNG hai ô. Bị cản tâm: ô chéo kề có quân thì hướng đó tắc.":
        "Xiangqi. Jumps EXACTLY two diagonal squares. Blocked at the midpoint: a piece on the adjacent diagonal shuts that direction down.",
    "Cá ngựa. Phủ rộng mọi hướng, sát thương lớn nhưng hồi chiêu rất chậm.":
        "Ludo. Covers a wide area in all directions, heavy damage but a very slow cooldown.",

    # ── Lore Vua ───────────────────────────────────────────────────────────
    "Ngài dựng vương quốc bằng kỷ luật và thép. Tốt của ngài không mạnh, nhưng chúng không bao giờ lùi — và chúng đông.":
        "He built his kingdom on discipline and steel. His Pawns are not strong, but they never step back - and there are many of them.",
    "Một quân vương không ai thấy mặt. Tượng và Mã của ngài đánh ra từ bóng tối, nhằm đúng kẻ vừa tin rằng mình đã an toàn.":
        "A sovereign no one has ever seen. His Bishops and Knights strike from the dark, at whoever just decided they were safe.",
    "Nữ hoàng cai trị bằng sự tàn phá. Hậu và Tượng của bà trút lửa xuống bất cứ ai dám cản đường.":
        "She rules through devastation. Her Queens and Bishops rain fire on anyone who stands in the way.",
    "Ngài không chờ kẻ địch tới gần. Cung thủ của ngài phủ sét lên chiến trường, để mặt đất tự quyết định điều gì sẽ nổ.":
        "He does not wait for the enemy to arrive. His archers blanket the field in lightning and let the ground decide what explodes.",
    "Ngài chưa từng thắng nhanh trận nào. Ngài chỉ khiến kẻ địch chậm lại, chậm mãi, cho tới khi mùa đông làm nốt phần còn lại.":
        "He has never won a battle quickly. He only makes the enemy slower, and slower, until winter finishes the job.",
    "Ngài chưa bao giờ rút kiếm. Ngài mua đội quân mạnh hơn đội quân đang tiến đến — và trả bằng tiền của chính kẻ đã thuê chúng.":
        "He has never drawn a sword. He buys an army stronger than the one marching at him - paid for with the coin of whoever hired it.",

    # ── Mo ta chieu Vua ────────────────────────────────────────────────────
    "Hồi ngay 30 Sắc Lệnh và tăng 50% tốc đánh cho toàn bộ Tốt trong 8 giây.":
        "Instantly restore 30 Decree and grant every Pawn +50% attack speed for 8 seconds.",
    "Toàn bộ quân tàng hình trước địch trong 5 giây và được xoá sạch hồi chiêu.":
        "Every piece turns invisible to enemies for 5 seconds and has its cooldown wiped.",
    "Gây 50 sát thương lên toàn bộ địch. Hậu gây sát thương gấp đôi trong 10 giây.":
        "Deal 50 damage to every enemy. Queens deal double damage for 10 seconds.",
    "Gây 24 sát thương và gắn Dấu Lôi lên toàn bộ địch. Dấu kéo dài thêm 3 giây — đủ để tháp kịp kích phản ứng.":
        "Deal 24 damage and apply a Thunder Mark to every enemy. Marks last 3 seconds longer - long enough for your pieces to trigger reactions.",
    "Làm chậm 80% toàn bộ địch trong 6 giây và gắn Dấu Băng. Chiêu cứu wave, không phải chiêu dọn wave.":
        "Slow every enemy by 80% for 6 seconds and apply an Ice Mark. This saves a wave; it does not clear one.",
    "Nhận 60 vàng + 22 mỗi wave đã qua, và trả giá xáo shop về mức đáy. Đổi Sắc Lệnh lấy quyền chọn hàng.":
        "Gain 60 gold plus 22 per wave survived, and reset the reroll price to its floor. Trade Decree for the right to pick your stock.",

    # ── Mo ta Bo Khai Cuoc ─────────────────────────────────────────────────
    "Bộ cờ vua tiêu chuẩn. Cân bằng, không có luật riêng — nền tảng để so mọi bộ khác.":
        "The standard chess set. Balanced, no special rule - the baseline every other set is measured against.",
    "Mười hai Tốt, không một quân lớn. Bù lại mỗi Tốt trên bàn cộng Bội cho toàn bàn, và Tốt đánh cả tám ô kề.":
        "Twelve Pawns, not a single major piece. In exchange every Pawn on the board adds Mult for the whole board, and Pawns hit all eight adjacent squares.",
    "Có Pháo ngay từ đầu. Mọi Xe cũng đánh theo luật Pháo — phải có ngòi, bù lại sát thương ×2.5. Cách nghĩ hoàn toàn khác.":
        "Cannons from the very first wave. Every Rook also fires by Cannon rules - needs a screen, deals x2.5 damage. A completely different way of thinking.",
    "Quân bất đối xứng: Hương Xa bắn xa một hướng, Kim Tướng phủ sáu ô kề. Quân ★3 phong cấp thành nước Hậu.":
        "Asymmetric pieces: the Lance fires far in one direction, the Gold General covers six adjacent squares. Any 3-star piece promotes to Queen movement.",
    "Rất ít quân nhưng mỗi con đánh cực mạnh. Trần quân thấp hơn 4, vàng khởi đầu gấp đôi.":
        "Very few pieces, each hitting extremely hard. Unit cap is 4 lower, starting gold is doubled.",
    "Bộ chuẩn nhưng vàng khởi đầu chỉ còn một nửa. Bù lại ô KHÔNG có nguyên tố cộng +45% Bội — không cần mua ô.":
        "The standard set on half the starting gold. In exchange, squares WITHOUT an element add +45% Mult - you never need to buy veins.",

    # ── Mo ta luat Rival King ──────────────────────────────────────────────
    "Tượng không bắn trong wave này. Đường chéo của ngươi vô dụng.":
        "Bishops do not fire this wave. Your diagonals are useless.",
    "Xe không bắn trong wave này. Cột và hàng im lặng.":
        "Rooks do not fire this wave. Ranks and files fall silent.",
    "Chỉ quân ở nửa bàn BÊN TRÁI được tính Bội đầy đủ.":
        "Only pieces on the LEFT half of the board get full Mult.",
    "Mỗi loại thế cờ chỉ tính MỘT lần, dù ngươi xếp được bao nhiêu.":
        "Each formation type counts ONCE, no matter how many you build.",
    "Quân của hắn đi nhanh 60%. Bù lại ngươi được thêm 3 lượt đặt.":
        "His troops move 60% faster. In exchange you get 3 extra placements.",
    "Mỗi quân trên bàn làm Bội toàn cục giảm 3%. Đông chưa chắc mạnh.":
        "Every piece on the board cuts global Mult by 3%. More is not always stronger.",
}
