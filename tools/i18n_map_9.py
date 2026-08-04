# -*- coding: utf-8 -*-
"""Bang dich dot 9 — ENCOUNTER (tieu de, van tu su, lua chon, ket qua)."""
NL = "\\n"
MAP = {
    # ── Tieu de encounter ──────────────────────────────────────────────────
    "Bàn Thờ Lửa Thiêng": "Altar of Sacred Flame",
    "Bầy Quạ Đen": "Murder of Crows",
    "Bóng Ma Chiến Trường": "Battlefield Wraith",
    "Cống Phẩm Hoàng Gia": "Royal Tribute",
    "Đền Thờ Bị Nguyền": "Cursed Shrine",
    "Đồn Tiền Tiêu Bỏ Hoang": "Abandoned Outpost",
    "Giao Ước Bóng Tối": "Dark Bargain",
    "Kho Báu Cổ Đại": "Ancient Vault",
    "Lão Binh Kể Chuyện": "The Old Soldier",
    "Lễ Hội Mùa Gặt": "Harvest Festival",
    "Lò Rèn Cổ Đại": "Ancient Forge",
    "Long Mạch Lộ Thiên": "Exposed Ley Line",
    "Tấm Gương Bóng Tối": "Mirror of Shadows",
    "Thi Sĩ Lang Thang": "Wandering Bard",
    "Thợ Khắc Đá Câm": "The Silent Stonecutter",
    "Thương Nhân Lang Thang": "Wandering Merchant",
    "Trạm Quân Y Chiến Trường": "Field Infirmary",
    "Vị Vua Lang Thang": "The Wandering King",

    # ── Van tu su ──────────────────────────────────────────────────────────
    "Ngọn lửa trên bàn thờ cổ bùng lên khi Nữ Hoàng đến gần — nó nhận ra dòng máu của chủ nhân. Lửa thiêng đòi lễ vật.":
        "The flame on the old altar surges as the Queen draws near - it knows its mistress's blood. The sacred fire demands an offering.",
    "Nghìn con quạ đổ xuống như bóng tối. Chúng mang điềm báo — và cả vũ khí rơi của lính chết.":
        "A thousand crows fall like nightfall. They carry an omen - and the weapons of the dead.",
    "Linh hồn chiến binh tử trận còn vương vấn. Nó chứa năng lượng — và cả ký ức về những trận thắng.":
        "The spirit of a fallen warrior still lingers. It holds power - and the memory of victories.",
    "Dân làng vùng biên mang cống phẩm tạ ơn ngươi đã bảo vệ họ. Họ chỉ đủ sức dâng một món.":
        "Border villagers bring tribute for your protection. They can spare only one gift.",
    "Ánh sáng tím bốc ra từ bàn thờ. Lời thì thầm hứa hẹn vàng bạc đổi lấy máu.":
        "Violet light pours from the shrine. A whisper promises gold in exchange for blood.",
    "Vũ khí và vàng vẫn còn trong đồn — nhưng bẫy cũ chưa chắc đã hết tác dụng.":
        "Weapons and gold still sit in the outpost - but the old traps may not be dead yet.",
    "Bóng hình không mặt đặt hợp đồng trước mặt ngươi. 100 vàng đổi 15 máu. Mực đã chuẩn bị sẵn.":
        "A faceless shape lays a contract before you. A hundred gold for fifteen life. The ink is already mixed.",
    "Hầm kho phong kín bao năm. Vàng bên trong rất nhiều — nhưng bẫy chưa chắc đã hỏng.":
        "A vault sealed for years. There is a great deal of gold inside - and the traps may still work.",
    "Bên đống lửa tàn, một lão binh từng phụng sự tiên vương kể lại trận đánh năm xưa. Giọng ông run run nhưng ánh mắt vẫn rực lửa.":
        "By the dying fire, an old soldier who served the late king recounts a battle from long ago. His voice shakes; his eyes do not.",
    "Vụ mùa bội thu. Dân chúng mở hội ăn mừng và mời Đức Vua ngự giá. Ngươi chọn cách chia phần.":
        "The harvest is rich. The people hold a festival and invite the King. You decide how the share is split.",
    "Lò rèn cổ đại vẫn còn nhiệt. Kẻ nào đủ kiên nhẫn có thể đúc lại bản thân — hoặc bán phế liệu.":
        "The ancient forge still holds its heat. Anyone patient enough could reforge themselves - or sell the scrap.",
    "Mặt đất nứt ra, để lộ mạch nguyên tố đang chảy bên dưới. Khai thác nó không miễn phí.":
        "The ground splits open, exposing an elemental vein flowing beneath. Mining it is not free.",
    "Trong tàn tích, một tấm gương đen không phản chiếu ánh đuốc — nó phản chiếu chính bóng tối trong ngươi. Nó thì thầm bằng giọng của Phantom King.":
        "Among the ruins, a black mirror reflects no torchlight - it reflects the dark in you. It whispers in the Phantom King's voice.",
    "Một thi sĩ ôm đàn xin hát trường ca về cuộc chiến của ngươi. Lời ca sẽ bay xa hơn mọi lá cờ — nếu ngươi trả công xứng đáng.":
        "A poet with a lute asks to sing an epic of your war. The song will travel further than any banner - if you pay what it is worth.",
    "Một ông lão không nói được, tay chai sạn, bày ra mấy phiến đá khắc rune nguyên tố.":
        "A mute old man with calloused hands lays out several stone slabs carved with elemental runes.",
    "Một thương nhân bị thương đang rao bán hàng hoá. Có gì đó hữu ích — nhưng không rẻ.":
        "A wounded merchant is selling his stock. Something here is useful - none of it is cheap.",
    "Một vị vua đã mất ngai vàng đề nghị chia sẻ kiến thức. Ông ta có nhiều thứ để dạy — không miễn phí.":
        "A king who lost his throne offers to share what he knows. He has much to teach - none of it free.",
    "Bác sĩ quân y có thể hồi phục vết thương — nhưng phẫu thuật chiến trường không rẻ.":
        "The field surgeon can close your wounds - but battlefield surgery is not cheap.",

    # ── Lua chon ───────────────────────────────────────────────────────────
    "Hiến tế bằng máu" + NL + "[-6 HP  →  +60 Vàng (lửa nhả vàng nung chảy)]":
        "Offer blood" + NL + "[-6 HP  →  +60 Gold (the fire spits molten coin)]",
    "Dâng vàng vào ngọn lửa" + NL + "[-30 Vàng  →  +5 HP (lửa phù hộ)]":
        "Feed gold to the flame" + NL + "[-30 Gold  →  +5 HP (the fire blesses you)]",
    "Ra lệnh dập tắt bàn thờ" + NL + "[Không có gì — lửa tắt, im lặng đến lạnh người]":
        "Order the altar doused" + NL + "[Nothing - the fire dies, and the silence is cold]",
    "Chiến đấu với bầy quạ" + NL + "[+25 Vàng (vũ khí thu hồi)  →  -5 HP]":
        "Fight the flock" + NL + "[+25 Gold (recovered weapons)  →  -5 HP]",
    "Đốt lửa xua đuổi" + NL + "[+10 Vàng (nguyên liệu cháy)  →  -3 HP (khói độc)]":
        "Burn them off" + NL + "[+10 Gold (salvaged fuel)  →  -3 HP (toxic smoke)]",
    "Rút lui nhường đường" + NL + "[-15 Vàng (mất trang bị)  →  Không mất HP]":
        "Fall back and let them pass" + NL + "[-15 Gold (lost gear)  →  No HP lost]",
    "Lắng nghe ký ức chiến trận" + NL + "[-8 HP (ám ảnh tâm lý)  →  +50 Vàng]":
        "Listen to its memories" + NL + "[-8 HP (the visions haunt you)  →  +50 Gold]",
    "Hấp thụ năng lượng ma" + NL + "[-10 HP  →  +45 RD tối đa vĩnh viễn]":
        "Absorb its energy" + NL + "[-10 HP  →  +45 permanent max Decree]",
    "Quay đi không nhìn lại" + NL + "[Không có gì — bóng tối vẫn ngủ yên]":
        "Turn away without looking back" + NL + "[Nothing - the dark stays asleep]",
    "Nhận rương vàng" + NL + "[+30 Vàng]": "Take the chest of gold" + NL + "[+30 Gold]",
    "Nhận quân nhu và lương thực" + NL + "[+3 HP]": "Take supplies and food" + NL + "[+3 HP]",
    "Nhận cuộn sắc lệnh cổ" + NL + "[+15 RD tối đa vĩnh viễn]":
        "Take the ancient decree scroll" + NL + "[+15 permanent max Decree]",
    "Cầu nguyện và nhận lời nguyền" + NL + "[+50 Vàng  →  -8 HP]":
        "Pray and accept the curse" + NL + "[+50 Gold  →  -8 HP]",
    "Phá hủy đền thờ" + NL + "[+10 Vàng (mảnh vỡ)  →  -3 HP (đá bắn)]":
        "Destroy the shrine" + NL + "[+10 Gold (fragments)  →  -3 HP (flying stone)]",
    "Rời đi ngay" + NL + "[Không có gì — không mất, không được]":
        "Leave at once" + NL + "[Nothing - no loss, no gain]",
    "Lục soát toàn bộ" + NL + "[+35 Vàng  →  -5 HP (bẫy cũ kích hoạt)]":
        "Search everything" + NL + "[+35 Gold  →  -5 HP (an old trap fires)]",
    "Kiểm tra những gì rõ ràng" + NL + "[+15 Vàng  →  Không mất HP]":
        "Check only the obvious" + NL + "[+15 Gold  →  No HP lost]",
    "Bỏ qua đồn" + NL + "[Không có gì — tiếp tục nhiệm vụ]":
        "Skip the outpost" + NL + "[Nothing - press on]",
    "Ký giao ước" + NL + "[+100 Vàng  →  -15 HP (vĩnh viễn trong run này)]":
        "Sign the contract" + NL + "[+100 Gold  →  -15 HP (for the rest of this run)]",
    "Phủ nhận bằng vàng" + NL + "[-25 Vàng  →  Thoát an toàn hoàn toàn]":
        "Buy your way out" + NL + "[-25 Gold  →  Walk away clean]",
    "Bỏ chạy" + NL + "[-5 HP (bị tấn công khi chạy)  →  Không mất vàng]":
        "Run" + NL + "[-5 HP (struck while fleeing)  →  No gold lost]",
    "Phá khóa vào ngay" + NL + "[+80 Vàng  →  -8 HP (bẫy kích hoạt)]":
        "Break the lock now" + NL + "[+80 Gold  →  -8 HP (traps fire)]",
    "Mở cẩn thận từng phần" + NL + "[+40 Vàng  →  -2 HP (cạm bẫy nhỏ)]":
        "Open it carefully, piece by piece" + NL + "[+40 Gold  →  -2 HP (a small trap)]",
    "Không đáng liều" + NL + "[Bỏ qua — không mất gì, không được gì]":
        "Not worth the risk" + NL + "[Skip - nothing lost, nothing gained]",
    "Ngồi xuống lắng nghe trọn đêm" + NL + "[+10 RD tối đa vĩnh viễn (binh pháp cổ)]":
        "Sit and listen all night" + NL + "[+10 permanent max Decree (old doctrine)]",
    "Biếu vàng để ông an dưỡng tuổi già" + NL + "[-15 Vàng  →  +3 HP (lòng quân cảm phục)]":
        "Give him gold for his old age" + NL + "[-15 Gold  →  +3 HP (the troops take note)]",
    "Gật đầu chào rồi rời đi" + NL + "[Không mất gì — không được gì]":
        "Nod and move on" + NL + "[Nothing lost - nothing gained]",
    "Thu thuế mùa vụ" + NL + "[+25 Vàng]": "Collect the harvest tax" + NL + "[+25 Gold]",
    "Trưng thu lương thực cho quân đội" + NL + "[+4 HP]":
        "Requisition food for the army" + NL + "[+4 HP]",
    "Chung vui cùng dân" + NL + "[+10 Vàng (quà mừng)  →  +2 HP (sĩ khí)]":
        "Celebrate with them" + NL + "[+10 Gold (gifts)  →  +2 HP (morale)]",
    "Thu nhặt và bán phế liệu" + NL + "[-3 HP (bỏng tay)  →  +25 Vàng]":
        "Gather and sell the scrap" + NL + "[-3 HP (burned hands)  →  +25 Gold]",
    "Tôi luyện ý chí chiến lược" + NL + "[-60 Vàng  →  +50 RD tối đa vĩnh viễn]":
        "Temper your strategic will" + NL + "[-60 Gold  →  +50 permanent max Decree]",
    "Bỏ qua lò rèn" + NL + "[Không mất gì — không được gì]":
        "Skip the forge" + NL + "[Nothing lost - nothing gained]",
    "Đào sâu theo mạch" + NL + "[-8 HP  →  3 ô cùng hệ ngươi đang mạnh nhất]":
        "Dig deep along the vein" + NL + "[-8 HP  →  3 veins of your strongest element]",
    "Khoan ngang tìm mạch lạ" + NL + "[-70 Vàng  →  2 ô nguyên tố ngẫu nhiên]":
        "Bore sideways for a stranger vein" + NL + "[-70 Gold  →  2 random element veins]",
    "Bịt mạch lại và đi tiếp" + NL + "[+35 Vàng (bán quặng vụn) — không có ô]":
        "Seal the vein and move on" + NL + "[+35 Gold (ore scraps) - no veins]",
    "Nhìn thẳng vào gương" + NL + "[-5 HP  →  +40 RD tối đa vĩnh viễn]":
        "Look straight into the mirror" + NL + "[-5 HP  →  +40 permanent max Decree]",
    "Đập vỡ tấm gương" + NL + "[+20 Vàng (mảnh bạc đen quý hiếm)]":
        "Shatter the mirror" + NL + "[+20 Gold (rare black silver)]",
    "Xua đuổi bằng nghi lễ" + NL + "[-20 Vàng  →  Thoát an toàn hoàn toàn]":
        "Banish it with a rite" + NL + "[-20 Gold  →  Walk away clean]",
    "Bảo trợ trọn trường ca" + NL + "[-20 Vàng  →  +15 RD tối đa vĩnh viễn (danh tiếng)]":
        "Fund the whole epic" + NL + "[-20 Gold  →  +15 permanent max Decree (renown)]",
    "Nghe một khúc ngắn, thưởng ít bạc" + NL + "[-5 Vàng  →  +1 HP (khích lệ ba quân)]":
        "Hear one short verse, pay a little" + NL + "[-5 Gold  →  +1 HP (the troops cheer)]",
    "Đuổi hắn đi" + NL + "[Không mất gì — lời ca cũng chẳng nuôi nổi ai]":
        "Send him away" + NL + "[Nothing lost - songs feed no one]",
    "Mua hai phiến cùng loại" + NL + "[-90 Vàng  →  2 ô cùng hệ đang mạnh nhất]":
        "Buy two matching slabs" + NL + "[-90 Gold  →  2 veins of your strongest element]",
    "Mua một phiến bất kỳ" + NL + "[-40 Vàng  →  1 ô ngẫu nhiên]":
        "Buy one slab, any kind" + NL + "[-40 Gold  →  1 random vein]",
    "Chỉ ngắm rồi đi" + NL + "[Miễn phí — ông lão gật đầu]":
        "Just look, then leave" + NL + "[Free - the old man nods]",
    "Mua thuốc hồi phục" + NL + "[-40 Vàng  →  +5 HP]":
        "Buy healing supplies" + NL + "[-40 Gold  →  +5 HP]",
    "Mua bản đồ chiến thuật" + NL + "[-30 Vàng  →  +25 RD tối đa vĩnh viễn]":
        "Buy the tactical maps" + NL + "[-30 Gold  →  +25 permanent max Decree]",
    "Từ chối lịch sự" + NL + "[Không mất gì — không được gì]":
        "Decline politely" + NL + "[Nothing lost - nothing gained]",
    "Ký liên minh chiến lược" + NL + "[-50 Vàng  →  +50 RD tối đa vĩnh viễn]":
        "Sign a strategic alliance" + NL + "[-50 Gold  →  +50 permanent max Decree]",
    "Chỉ đường cho hắn" + NL + "[Miễn phí  →  +20 Vàng (ông ta trả ơn)]":
        "Point him the way" + NL + "[Free  →  +20 Gold (he repays you)]",
    "Điều trị đầy đủ" + NL + "[-40 Vàng  →  +8 HP]":
        "Full treatment" + NL + "[-40 Gold  →  +8 HP]",
    "Trao đổi bí quyết chữa thương" + NL + "[-20 Vàng  →  +4 HP]":
        "Trade healing knowledge" + NL + "[-20 Gold  →  +4 HP]",
    "Sơ cứu nhanh" + NL + "[-15 Vàng  →  +3 HP]":
        "Quick first aid" + NL + "[-15 Gold  →  +3 HP]",
    "Từ chối điều trị" + NL + "[Tiết kiệm vàng — HP thấp về sau là vấn đề của ngươi]":
        "Refuse treatment" + NL + "[Save the gold - low HP later is your problem]",

    # ── Ket qua / binh luan ────────────────────────────────────────────────
    "Lửa thiêng trả công hậu hĩnh — nhưng nó chỉ nhận máu.":
        "The sacred fire pays well - but it takes only blood.",
    "Đổi của lấy sự che chở. Ngọn lửa hài lòng.":
        "Wealth traded for protection. The flame is satisfied.",
    "Nữ Hoàng không quỳ trước bất kỳ ngọn lửa nào.":
        "The Queen kneels to no flame.",
    "Đánh bại chúng mang lại chiến lợi phẩm — nhưng vẫn bị thương.":
        "Beating them yields spoils - and wounds.",
    "Hủy diệt mang lại ít vàng nhưng vẫn có giá.":
        "Destruction pays a little, and still costs something.",
    "An toàn hơn nhưng vẫn không thoát hoàn toàn.":
        "Safer, but not entirely clean.",
    "Kinh nghiệm trăm trận của ông là kho báu không vàng nào mua nổi.":
        "A hundred battles of experience is a treasure no gold can buy.",
    "Binh sĩ nhìn thấy — và họ biết vua của mình trọng nghĩa.":
        "The soldiers saw it - and they know their king values honour.",
    "Chiến tranh không chờ những câu chuyện cũ.":
        "War does not wait on old stories.",
    "Quốc khố đầy thêm. Dân hơi tiếc nhưng vẫn cúi đầu.":
        "The treasury grows. The people mind, but they bow.",
    "Thành lũy được gia cố, binh sĩ no bụng.":
        "The walls are reinforced and the soldiers are fed.",
    "Vua gần dân, lòng quân thêm vững.":
        "A king close to his people has a steadier army.",
    "Kho lương đầy — thành lũy trụ vững hơn.":
        "Full granaries make for a sturdier hold.",
    "Uy quyền của ngươi lan xa hơn một chút.":
        "Your authority reaches a little further.",
    "Kiến thức này sẽ nâng cao khả năng chỉ huy của ngươi.":
        "This knowledge sharpens your command.",
    "Khắp vương quốc sẽ truyền tụng tên ngươi. Uy quyền theo đó mà lớn.":
        "The whole kingdom will pass your name along. Authority grows with it.",
    "Một khúc quân hành cũng đủ ấm lòng lính thú đêm sương.":
        "One marching song is enough to warm sentries in the night mist.",
    "Chiến trường không cần thơ. Có lẽ vậy.":
        "The battlefield has no use for poetry. Perhaps.",
    "Có những cánh cửa không nên mở. Bán mảnh vỡ cũng được giá.":
        "Some doors are better left shut. The shards still fetch a price.",
    "Đối diện bóng tối của chính mình — và thu phục nó.":
        "Face your own darkness - and take it for your own.",
    "Ngươi biết rõ hơn ai hết: bóng tối luôn đòi giá.":
        "You know better than anyone: the dark always charges.",
    "Vàng bạc đổi bằng sinh mệnh. Ngươi có sẵn sàng?":
        "Gold bought with life. Are you willing?",
    "Lợi nhuận cao nhất. Nhưng 15 HP không bao giờ quay lại.":
        "The biggest payout. But those 15 HP never come back.",
    "Trả tiền để thoát. Đắt nhưng sạch tay.":
        "Pay your way out. Expensive, but clean.",
    "Rẻ hơn nhưng không miễn phí. Bóng hình không thích bị phớt lờ.":
        "Cheaper, but not free. The shape dislikes being ignored.",
    "Miễn phí hôm nay. Nhưng HP thấp trong tương lai sẽ đắt hơn nhiều.":
        "Free today. But low HP later costs far more.",
    "Tham lam nhưng hữu lý. Chỉ mất 5 HP cho 35 vàng.":
        "Greedy but reasonable. Only 5 HP for 35 gold.",
    "Tham lam? Chắc chắn. Nhưng 80 vàng không phải con số nhỏ.":
        "Greedy? Certainly. But 80 gold is not a small number.",
    "Nguy hiểm nhỏ, lợi nhuận vừa phải. Không cần vốn.":
        "Small risk, modest profit. No capital required.",
    "Phần thưởng nhỏ. Không có gì mất đi.":
        "A small reward. Nothing lost.",
    "Vàng nhiều nhưng vẫn mất HP. Không có gì là miễn phí.":
        "Plenty of gold, but HP all the same. Nothing here is free.",
    "Bảo tồn vàng. Cơ hội khác sẽ đến.":
        "Keep the gold. Another chance will come.",
    "An toàn tuyệt đối. Cơ hội này không phải lần cuối.":
        "Perfectly safe. This is not the last chance.",
    "An toàn. Ít hơn nhưng chắc chắn.": "Safe. Less, but certain.",
    "Không mất gì. Cũng không được gì.": "Nothing lost. Nothing gained either.",
    "Không phải lúc nào cũng cần đào sâu.": "You do not always need to dig deep.",
    "Không phải lúc này.": "Not this time.",
    "Đôi khi khôn ngoan nhất là không làm gì.":
        "Sometimes the wisest move is to do nothing.",
    "Thời gian là tài nguyên.": "Time is a resource.",
    "Vàng luôn hữu dụng. Không có gì phải bàn.":
        "Gold is always useful. Nothing to debate.",
    "Bền bỉ hơn nhưng vẫn có giá phải trả.":
        "More durable, and still not free.",
    "Kinh tế hơn. Đủ để trụ thêm vài đợt tấn công.":
        "More economical. Enough to hold a few more assaults.",
    "Rẻ hơn. HP là nguồn lực quý giá.": "Cheaper. HP is a precious resource.",
    "Đắt nhất nhưng hồi phục nhiều nhất. Đáng giá khi HP thấp.":
        "The most expensive, and the most healing. Worth it when HP is low.",
    "Đắt nhưng HP là thứ không thể mua lại dễ dàng.":
        "Expensive - but HP is not easily bought back.",
    "Đắt nhất. Nhưng RD tối đa là lợi thế lâu dài không thể bỏ qua.":
        "The most expensive. But max Decree is a long-term edge you cannot ignore.",
    "Đau nhưng xứng đáng. RD max +45 là lợi thế cực lớn.":
        "It hurts, and it is worth it. +45 max Decree is an enormous edge.",
    "Đầu tư dài hạn. Tốn nhiều vàng nhưng RD max tăng mạnh.":
        "A long-term investment. Costly in gold, but max Decree climbs sharply.",
    "Tốn vàng nhưng HP nguyên vẹn. Lựa chọn của kẻ thận trọng.":
        "Costs gold, keeps your HP intact. The careful choice.",
    "Tính mạng quan trọng hơn vàng — nhưng vàng không phải rẻ.":
        "Life matters more than gold - but gold is not cheap either.",
    "Mở đường sang một nguyên tố khác — rủi ro, nhưng biết đâu.":
        "Opens a path to a different element - risky, but who knows.",
    "Rẻ, và biết đâu lại là mảnh còn thiếu của Bát Quái.":
        "Cheap, and it might be the missing piece of your Bagua.",
}
