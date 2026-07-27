# futureplan.md — Nguyên Tố theo Ô, Vật Phẩm & 16 Lối Chơi
*Thiết kế 2026-07-25. Nền: xem `plan.md` (đợt 1–7), `CLAUDE.md`.*

> **Nguyên tắc gốc:** KHÔNG tạo thêm loại tháp nguyên tố (không có "tháp Hoả", "tháp Thuỷ").
> Nguyên tố đến từ **Ô** mà tháp đứng lên. Đặt quân ở đâu = chọn nguyên tố cho quân đó.
> Bàn cờ trở thành câu đố bố cục, đúng chất cờ.
>
> **Cam kết thiết kế:** mọi lối chơi đều thắng được — nhưng **chỉ bung hết sức khi nhặt đúng
> vật phẩm mở khoá**. Không có vật phẩm phù hợp thì đội hình chỉ ở mức "dùng tạm".

---

## 0. Tận dụng cái đã có

| Đã có trong code | Dùng làm |
|---|---|
| `TerritoryManager` — ô lãnh thổ mua bằng vàng, có kho, đặt lên bàn (Fire/Swamp/Ice/Forest/Desert/Thunder) | **Chính là Ô Nguyên Tố** — đổi tên & mở rộng, không viết lại |
| `burn_dps`/`burn_duration`, `slow_amount`/`slow_duration` | Dấu Hoả, Dấu Băng (phiên bản thô đã chạy) |
| `splash_radius` + `PhysicsShapeQueryParameters3D` | Vùng nổ phản ứng, vùng thuốc |
| `BuffLayer {UPGRADE, BIOME, FAVOR, BOON, AURA, SYNERGY, PERK, TILE, BIOME_CLIMATE}` | `TILE` đã dành sẵn cho ô — thêm `EQUIP`, `POTION` |
| `SynergyManager` ngưỡng 2/4/6 | Thêm trục đếm theo **nguyên tố** |
| `special_tiles` (Phước/Nguyền) | Cùng cơ chế cho ô nguyên tố cấp cao |
| Biome theo vùng (5 khí hậu) | Vùng cho **ô nguyên tố miễn phí** theo khí hậu |

---

## 1. HỆ NGUYÊN TỐ

### 1.1 Sáu nguyên tố & Dấu
| Nguyên tố | Dấu bám lên địch |
|---|---|
| 🔥 **Hoả** | Cháy 12 dmg/s trong 4s |
| ❄️ **Băng** | Chậm 35% trong 3s |
| ⚡ **Lôi** | Giật 8 dmg/s, **bỏ qua giáp** |
| 💧 **Thuỷ** | Ướt: +20% sát thương nhận từ Băng/Lôi. Tự nó **không gây dmg** |
| ☠️ **Độc** | 6 dmg/s trong 8s, **cộng dồn 5 tầng** |
| 🪨 **Thổ** | Chậm 25%, địch chết để lại mảnh vàng |

**Luật Dấu:** tối đa **2 Dấu**/địch · tồn tại 5s · Dấu thứ 3 đẩy Dấu cũ nhất ra ·
đủ cặp có phản ứng → **nổ ngay, tiêu thụ cả hai**.

### 1.2 Bảng phản ứng
| Phản ứng | Cặp | Hiệu ứng | Vai trò |
|---|---|---|---|
| **Bốc Hơi** | 🔥+💧 | 250% dmg đòn kích hoạt, đơn mục tiêu | Sát thương đơn |
| **Tan Chảy** | 🔥+❄️ | 200% dmg + **xoá sạch giáp 4s** | Phá giáp |
| **Đóng Băng** | ❄️+💧 | **Đứng yên 2s** (cooldown ẩn 6s/con) | Kiểm soát cứng |
| **Dẫn Điện** | ⚡+💧 | Lan 4 địch trong 2.5m, mỗi con 60% | Dọn bầy |
| **Siêu Dẫn** | ⚡+❄️ | −8 giáp mọi địch trong 2m, 6s | Phá giáp diện rộng |
| **Quá Tải** | ⚡+🔥 | Nổ 2.2m, 180% dmg, đẩy lùi 0.6m | Nổ + mua thời gian |
| **Cháy Độc** | 🔥+☠️ | Nhân đôi tầng Độc, lan 2 địch kề | DoT bùng |
| **Lan Truyền** | 💧+☠️ | Độc lây **mọi địch trong 3m**, giữ nguyên tầng | Xoá wave đông |
| **Kết Tinh** | 🪨+bất kỳ | Rơi tinh thể: nhặt +15 vàng | Kinh tế |
| **Chấn Địa** | 🪨+⚡ | Choáng 1s + ô đó thành **vết nứt** (địch qua chậm 40%, 8s) | Điều khiển địa hình |

---

## 2. Ô NGUYÊN TỐ — nguồn nguyên tố duy nhất

### 2.1 Luật cốt lõi
- Tháp đứng trên **Ô Nguyên Tố** → mọi đòn đánh của nó **gắn Dấu** của ô đó.
- Tháp đứng ô thường → đánh vật lý thuần, **không Dấu** (vẫn mạnh, xem lối chơi §7.13).
- Đổi nguyên tố cho một quân = **dời quân sang ô khác** hoặc **đổi ô dưới chân nó**.
- Tận dụng `TerritoryManager` sẵn có: mua bằng vàng, có kho, có preview đặt.

### 2.2 Ba cấp ô — chiều sâu đầu tư
| Cấp | Cách có | Hiệu lực |
|---|---|---|
| **Lv1 Mạch** | Mua shop 40–60 vàng | Gắn Dấu tiêu chuẩn |
| **Lv2 Nguồn** | Ghép 2 ô Lv1 cùng loại **kề nhau** | Dấu kéo dài +2s · phản ứng +25% |
| **Lv3 Long Mạch** | Ghép 3 ô Lv2 cùng loại | Dấu kéo dài +4s · phản ứng +60% · tháp trên ô +15% sát thương |

→ Ghép ô mượn đúng cơ chế merge ★ đã có: đặt ô cùng loại lên ô cùng loại.

### 2.3 Hình thế (bố cục ô có ý nghĩa — chất cờ)
| Hình thế | Điều kiện | Thưởng |
|---|---|---|
| **Hàng Long** | 3 ô cùng loại thẳng hàng | Tháp trên các ô đó +1 tầm bắn |
| **Tứ Trụ** | 4 ô cùng loại thành khối 2×2 | Phản ứng từ khối này +40% |
| **Song Cực** | 2 ô **khác loại có phản ứng** kề nhau | Tháp trên 2 ô này tự kích phản ứng mỗi 4s lên địch gần nhất |
| **Bát Quái** | 6 ô đủ 6 nguyên tố trên bàn | Mở phản ứng **Nguyên Sơ** (§8.3) |
| **Trận Vòng** | 4 ô cùng loại bao quanh 1 ô thường | Tháp ở ô giữa nhận **cả 4 Dấu luân phiên** |

### 2.4 Nguồn ô nguyên tố
| Nguồn | Cho gì |
|---|---|
| **Shop** mỗi wave | 2 ô ngẫu nhiên (giá 40–60) |
| **Khí hậu vùng** | Mở rộng sang vùng Hoả Diệm → tặng 2 ô Hoả miễn phí; Băng Nguyên → 2 ô Băng; Đầm Lầy → Thuỷ+Độc; Rừng Thẳm → Thổ; Hoang Mạc → 1 ô bất kỳ |
| **Encounter** | Đổi HP/vàng lấy ô cấp cao |
| **Boss** | 1 ô Lv2 tự chọn |
| **Phản ứng Kết Tinh** | 5% rơi mảnh đổi được ô Lv1 |

> Đây là chỗ hệ biome đã làm xong **ăn khớp hoàn hảo**: hướng mở rộng bản đồ quyết định
> nguyên tố bạn được tiếp cận → mỗi run có bản sắc riêng ngay từ đầu.

---

## 3. VẬT PHẨM — 4 lớp

### 3.1 THUỐC (túi 3 ô, ném theo **vùng 2.5m**, dùng được giữa trận)
**Tiếp sức — buff tháp trong vùng, 12 giây**
| Tên | Hiệu ứng |
|---|---|
| Rượu Cường Lực | +40% sát thương |
| Dầu Nhanh Tay | −0.35s hồi chiêu |
| Nước Mắt Đại Bàng | +2 tầm bắn |
| Bùa Đa Thủ | +1 mũi đạn mỗi đòn |
| Chén Thánh | Hồi chiêu ngay, bắn liền 1 phát |
| Tinh Dầu Xuyên Giáp | Bỏ qua hoàn toàn giáp |
| **Tinh Chất Cộng Hưởng** | Phản ứng do tháp trong vùng kích: **+80%** |
| **Dầu Dẫn Nguyên Tố** | Dấu gắn bởi tháp trong vùng **kéo dài gấp đôi** |
| **Nước Ép Đa Sắc** | Tháp trong vùng gắn **Dấu ngẫu nhiên** kể cả khi đứng ô thường |

**Tấn công — ném vào địch**
| Tên | Hiệu ứng |
|---|---|
| Bom Lửa | 120 dmg vùng 2m + Dấu Hoả |
| Cầu Băng | 60 dmg + Dấu Băng, chậm 50%/5s |
| Lọ Sét | 80 dmg + Dấu Lôi, ưu tiên địch máu cao nhất |
| **Bình Nước Bẩn** | 0 dmg, Dấu Thuỷ cho **toàn bộ địch trên màn** |
| Khí Độc | Vùng độc 8s, vào là dính 3 tầng |
| Vụn Đá | Dấu Thổ + chậm 40%/6s |

**Khẩn cấp:** Máu Vua (+5 HP) · Khiên Vương Triều (King miễn dmg 10s) · Cát Thời Gian (chậm toàn map 60%/5s) · Kèn Triệu Hồi (2 lính tạm).

### 3.2 TRANG BỊ (2 ô mỗi tháp, vĩnh viễn)
**Vũ khí — đổi cách đánh**
Cung Xuyên Táo (xuyên 2 địch) · Búa Chấn Động (20% choáng 0.5s) · Nỏ Liên Thanh (−40% dmg, ×2 tốc)
· Rìu Chém Giáp (bỏ qua 6 giáp) · Cây Lao Săn (+60% lên địch máu đầy) · Chuỳ Kết Liễu (+100% lên địch <25% máu)
· Kiếm Hút Máu (mỗi kill +1 HP King, tối đa 3/wave)

**Phụ kiện — khuếch đại nguyên tố** *(đây là nhóm mở khoá lối chơi)*
| Tên | Hiệu ứng |
|---|---|
| Nhẫn Cộng Hưởng | Phản ứng tháp này kích: **+50%** |
| Đá Dẫn Nguyên Tố | Dấu tháp này gắn kéo dài **gấp đôi** |
| Lăng Kính Đôi | 25% gắn **cả 2 Dấu** cùng lúc → **tự kích phản ứng một mình** |
| Hộ Phù Thợ Săn | +30% sát thương lên địch **đang mang Dấu** |
| Mắt Bão | Bán kính mọi phản ứng của tháp này +1m |
| Đồng Hồ Ngược | −0.1s hồi chiêu mỗi khi có phản ứng nổ gần |
| **Ống Dẫn Mạch** | Tháp này nhận Dấu của ô **kề bên** thay vì ô dưới chân |
| **Bình Chứa Kép** | Tháp trên ô Lv2+ gắn **2 Dấu cùng lúc** (Dấu ô + Dấu ô kề) |

**Nền tảng**
Bệ Đá Vững (miễn vô hiệu hoá của boss) · Chân Đế Xoay (+1 tầm, không bị dời) · Rễ Cây Cổ (+5 dmg vĩnh viễn mỗi wave sống sót) · Cột Thu Lôi (hút Dấu Lôi lân cận, đủ 3 thì nổ)

### 3.3 DI VẬT (5 ô, cả run, phải bán mới đổi)
Sách Giả Kim (mọi phản ứng +40%) · Bánh Xe Nguyên Tố (địch mang **3 Dấu**) · Lò Phản Ứng (20% phản ứng **không tiêu thụ Dấu**)
· Đe Của Thần (mỗi tháp +1 ô trang bị) · Túi Thuốc Rộng (+2 ô thuốc) · Ống Nhòm (bán kính thuốc → 4m)
· Bàn Tay Dược Sư (thuốc kéo dài 20s) · Bản Đồ Kho Báu (Elite luôn rơi thuốc)
· Vòng Cổ Thợ Săn (địch mang Dấu nhận +15% dmg từ **mọi** nguồn)
· **Địa Chất Sư** (ô nguyên tố rẻ 40%, ghép ô không cần kề nhau)
· **Long Mạch Sống** (ô Lv3 lan Dấu sang **4 ô kề**)
· **Trái Tim Nguyên Sơ** (đủ 6 nguyên tố trên bàn: mọi tháp +30% dmg)

### 3.4 PERK (draft sau mỗi wave — hệ đã có, mở rộng nội dung)
Perk hiện tại thiên về chỉ số chung. Bổ sung nhóm perk **gắn với lối chơi**:
| Perk | Hiệu ứng |
|---|---|
| Hoả Sư | Dấu Hoả +50% sát thương cháy |
| Hàn Băng Quyết | Đóng Băng kéo dài 3s thay vì 2s |
| Lôi Đình | Dẫn Điện lan thêm 2 mục tiêu |
| Thuỷ Mạch | Dấu Thuỷ tự lan sang 1 địch kề |
| Độc Sư | Độc cộng dồn tối đa 8 tầng |
| Địa Chủ | Ô nguyên tố rẻ hơn 25% |
| Thợ Ghép Mạch | Ghép ô Lv2 chỉ cần 1 ô cùng loại kề |
| Nhà Giả Kim | Mỗi 15 phản ứng: nhận 1 thuốc ngẫu nhiên |
| Thợ Rèn Lang Thang | Trang bị trong shop rẻ 30% |
| Thuần Vật Lý | Tháp **không đứng ô nguyên tố**: +35% sát thương |

---

## 4. 16 LỐI CHƠI — mỗi lối có vật phẩm mở khoá riêng

Ký hiệu: **[BẮT BUỘC]** = không có thì build không thành hình · **[TĂNG LỰC]** = có thì bung hết sức.

---

### NHÓM A — THUẦN MỘT NGUYÊN TỐ (mạnh sâu)

#### 4.1 🔥 HOẢ NGỤC — thiêu rụi theo thời gian
**Bàn cờ:** 6 ô Hoả, ưu tiên **Tứ Trụ** 2×2 ở khúc cua đông địch. Tháp bắn nhanh (Crossbowman, Alchemist, Nỏ Liên Thanh) để chồng Dấu liên tục.
**[BẮT BUỘC]** Perk *Hoả Sư* · Synergy Hoả ×6 (mở **Biển Lửa**: cháy lan 1.5m)
**[TĂNG LỰC]** Trang bị *Đá Dẫn Nguyên Tố* (cháy lâu gấp đôi) · Di Vật *Sách Giả Kim* · Thuốc *Máu Rồng*
**Mạnh:** wave đông, địch máu vừa. Sát thương cộng dồn không cần bắn trúng liên tục.
**Yếu:** boss giáp cao (cháy bị giáp chặn), địch chạy nhanh (Wraith chết trước khi cháy đủ lâu).
**Online:** wave 4–5 (khi đủ 4 ô Hoả).

#### 4.2 ❄️ VĨNH ĐÔNG — khoá cứng bản đồ
**Bàn cờ:** 4 ô Băng + 2 ô Thuỷ xen kẽ để tự kích **Đóng Băng**. Đặt ở **đầu đường** để khoá địch xa King.
**[BẮT BUỘC]** Perk *Hàn Băng Quyết* · ít nhất 2 ô Thuỷ (không có Thuỷ thì Băng chỉ là làm chậm)
**[TĂNG LỰC]** Synergy Băng ×6 (**Băng Vĩnh Cửu**: bỏ cooldown ẩn) · *Lăng Kính Đôi* trên tháp bắn nhanh · Di Vật *Bánh Xe Nguyên Tố*
**Mạnh:** boss (đứng yên = miễn phí sát thương), wave nguy hiểm.
**Yếu:** sát thương thấp — cần một nguồn dmg khác, dễ hết giờ wave.
**Online:** wave 6 (cần cả Băng lẫn Thuỷ).

#### 4.3 ⚡ LÔI ĐÌNH — xuyên giáp, dọn bầy
**Bàn cờ:** 5 ô Lôi + 1 ô Thuỷ. Tháp tầm xa (Longbowman, Ballista) trên ô Lôi bắn vào cụm.
**[BẮT BUỘC]** ≥1 ô Thuỷ (mồi cho Dẫn Điện) · Perk *Lôi Đình*
**[TĂNG LỰC]** Synergy Lôi ×6 (**Bão Sét**: lan 8 con) · *Cột Thu Lôi* · Thuốc *Bình Nước Bẩn* (bôi Thuỷ toàn màn → Dẫn Điện dây chuyền)
**Mạnh:** Bat/Goblin bầy đàn, Golem giáp dày (Lôi bỏ qua giáp).
**Yếu:** địch đi lẻ, boss đơn độc.
**Online:** wave 5.

#### 4.4 ☠️ ĐẠI DỊCH — càng lâu càng chết
**Bàn cờ:** 4 ô Độc + 2 ô Thuỷ. Alchemist + tháp bắn nhanh để chồng tầng.
**[BẮT BUỘC]** Perk *Độc Sư* (5→8 tầng) · ô Thuỷ để kích **Lan Truyền**
**[TĂNG LỰC]** Synergy Độc ×6 (**Đại Dịch**: 10 tầng) · *Hộ Phù Thợ Săn* · Di Vật *Vòng Cổ Thợ Săn*
**Mạnh:** wave dài, boss nhiều máu, Troll hồi máu (độc át hồi).
**Yếu:** wave ngắn, địch chết trước khi độc chín. Yếu nhất ở wave 1–3.
**Online:** wave 7 trở đi — **build "nở muộn"**, phải sống được tới đó.

#### 4.5 💧 THUỶ TRIỀU — không sát thương, nhưng khuếch đại tất cả
**Bàn cờ:** 3 ô Thuỷ ở **đầu đường** (bôi Dấu sớm) + 3 ô nguyên tố khác ở giữa/cuối để kích nổ.
**[BẮT BUỘC]** Perk *Thuỷ Mạch* · phải có nguyên tố thứ hai — Thuỷ đơn độc **không gây dmg**
**[TĂNG LỰC]** Synergy Thuỷ ×6 (**Thuỷ Triều**: địch mới spawn tự mang Dấu Thuỷ — cực mạnh) · *Ống Dẫn Mạch*
**Mạnh:** làm nền cho mọi build khác; wave đông.
**Yếu:** không thể chơi thuần; boss miễn nhiễm Thuỷ nếu thiết kế sau này thêm.
**Online:** wave 3 (rẻ, sớm), nhưng cần bạn đời.

#### 4.6 🪨 THẠCH VƯƠNG — kinh tế & địa hình
**Bàn cờ:** 4 ô Thổ + 2 ô Lôi (kích **Chấn Địa**). Catapult/Ballista.
**[BẮT BUỘC]** Đủ ô Lôi để kích phản ứng · Perk *Địa Chủ* (mua thêm ô rẻ)
**[TĂNG LỰC]** Synergy Thổ ×6 (**Địa Chấn**: Kết Tinh 40 vàng) · Di Vật *Địa Chất Sư*
**Mạnh:** kiếm vàng khủng → mua được mọi thứ về sau; vết nứt làm chậm địch vĩnh viễn trên đường.
**Yếu:** sát thương trực tiếp thấp nhất; thua nếu bị dồn ép sớm.
**Online:** wave 2 (kinh tế), sức mạnh thật đến wave 8+ nhờ tiền.

---

### NHÓM B — HAI NGUYÊN TỐ (chuyên một phản ứng)

#### 4.7 🔥💧 NỒI HƠI — sát thương đơn mục tiêu cao nhất game
**Bàn cờ:** 3 ô Hoả + 3 ô Thuỷ, **xen kẽ Song Cực** để tự kích Bốc Hơi. Ballista/Longbowman đòn nặng đứng ô Hoả.
**[BẮT BUỘC]** *Nhẫn Cộng Hưởng* trên tháp đòn nặng (Bốc Hơi 250% → 375%)
**[TĂNG LỰC]** Di Vật *Sách Giả Kim* · *Chuỳ Kết Liễu* · Perk chỉ số đơn thuần
**Mạnh:** **giết boss** — đây là build diệt boss số một.
**Yếu:** wave đông (mỗi phát chỉ 1 mục tiêu).
**Online:** wave 6.

#### 4.8 🔥❄️ NHIỆT SỐC — phá giáp
**Bàn cờ:** 3 Hoả + 3 Băng đặt kề nhau. Bất kỳ tháp bắn nhanh nào.
**[BẮT BUỘC]** Hai loại ô kề nhau (Song Cực) — nếu xa nhau Dấu tan trước khi ghép
**[TĂNG LỰC]** *Rìu Chém Giáp* + Tan Chảy = giáp về 0 · Perk *Hoả Sư*
**Mạnh:** Golem, Dark Knight, boss Băng Giá (giáp 10).
**Yếu:** thừa thãi khi wave toàn địch giáp thấp.
**Online:** wave 5.

#### 4.9 ⚡💧 BÃO BIỂN — xoá sổ wave đông
**Bàn cờ:** 4 Lôi + 2 Thuỷ, đặt **quanh khúc cua** nơi địch dồn cục.
**[BẮT BUỘC]** Perk *Lôi Đình* hoặc Synergy Lôi ×4
**[TĂNG LỰC]** Thuốc *Bình Nước Bẩn* · *Mắt Bão* · Di Vật *Lò Phản Ứng* (Dấu không bị tiêu thụ → dây chuyền vô tận)
**Mạnh:** wave Bat/Goblin 20+ con, wave "Bầy Đàn" (Điềm Báo).
**Yếu:** boss đơn.
**Online:** wave 4 — **build nở sớm nhất**.

#### 4.10 ☠️💧 Ô UẾ — lây lan toàn bản đồ
**Bàn cờ:** 3 Độc + 3 Thuỷ. Tháp bắn nhanh chồng tầng lên **một** con, rồi Lan Truyền phát tán.
**[BẮT BUỘC]** Perk *Độc Sư* · Thuỷ phải đủ để kích thường xuyên
**[TĂNG LỰC]** Di Vật *Vòng Cổ Thợ Săn* · Synergy Độc ×4
**Mạnh:** vừa dọn bầy vừa gặm boss — cân bằng nhất nhóm B.
**Yếu:** cần thời gian; thua trước wave nhanh-gọn.
**Online:** wave 6.

#### 4.11 🪨⚡ ĐỊA CHẤN — biến đường thành bãi lầy
**Bàn cờ:** 3 Thổ + 3 Lôi dọc **đoạn đường dài nhất**. Mục tiêu tạo vết nứt liên tục.
**[BẮT BUỘC]** Đường đủ dài (build này phụ thuộc bản đồ — mở rộng nhiều hướng để có đường dài)
**[TĂNG LỰC]** Di Vật *Long Mạch Sống* · Perk *Địa Chủ*
**Mạnh:** kéo dài thời gian địch ở trong tầm bắn → mọi tháp khác được lợi.
**Yếu:** không tự giết được ai, cần dmg đi kèm.
**Online:** wave 7.

---

### NHÓM C — KHÔNG THEO NGUYÊN TỐ (phải vẫn mạnh)

#### 4.12 ⚔️ THÉP NGUYÊN BẢN — vật lý thuần, không một ô nguyên tố
**Bàn cờ:** 0 ô nguyên tố. Toàn bộ vàng đổ vào **quân + trang bị + merge ★**.
**[BẮT BUỘC]** Perk *Thuần Vật Lý* (+35% cho tháp không đứng ô nguyên tố) — **không có perk này build vô nghĩa**
**[TĂNG LỰC]** *Rễ Cây Cổ* · *Chuỳ Kết Liễu* · Di Vật *Đe Của Thần* (3 ô trang bị) · merge lên ★3 sớm
**Mạnh:** ổn định, không phụ thuộc may mắn ô/phản ứng; tiền dồn hết vào sức mạnh thô.
**Yếu:** trần sức mạnh thấp hơn build phản ứng ở late game; bất lực trước giáp cao nếu thiếu *Rìu Chém Giáp*.
**Online:** wave 2 — **build vào form sớm nhất, an toàn nhất cho người mới**.

#### 4.13 🌈 BÁT QUÁI — đủ 6 nguyên tố
**Bàn cờ:** đúng 1 ô mỗi loại (6 ô), bố trí sao cho các cặp có phản ứng nằm kề nhau.
**[BẮT BUỘC]** Di Vật *Trái Tim Nguyên Sơ* (đủ 6 → +30% mọi tháp) · Synergy hỗn hợp
**[TĂNG LỰC]** *Nước Ép Đa Sắc* · *Bánh Xe Nguyên Tố* (3 Dấu) · phản ứng **Nguyên Sơ** (400%)
**Mạnh:** linh hoạt, đối phó được mọi loại địch, không sợ bị khắc chế.
**Yếu:** không phản ứng nào đạt đỉnh; **rất tốn vàng** (6 loại ô); mất một mảnh là gãy combo.
**Online:** wave 8 — build khó nhất, thưởng cao nhất.

#### 4.14 💰 THƯƠNG NHÂN — cuộn cầu tuyết kinh tế
**Bàn cờ:** 2–3 ô Thổ sớm (Kết Tinh ra vàng), phần còn lại để trống, tiêu tiền vào lãi.
**[BẮT BUỘC]** Perk *Ngân Khố* + *Hầm Vàng* (trần lãi & lãi suất — đã có trong game)
**[TĂNG LỰC]** Synergy Thổ ×4 · Di Vật *Địa Chất Sư* · *Túi Vàng Rách*
**Mạnh:** wave 9–12 mua được **mọi thứ**, chuyển hoá thành bất kỳ build nào.
**Yếu:** wave 1–6 mong manh, một lần rò rỉ là mất hết lãi.
**Online:** wave 9 — rủi ro cao, phần thưởng cao.

#### 4.15 🏰 PHÁO ĐÀI — dồn cục
**Bàn cờ:** mọi tháp chen trong **một cụm 3×3** quanh ô Lv3, thường ở khúc cua cuối gần King.
**[BẮT BUỘC]** Ô Lv3 (Long Mạch) · Di Vật *Long Mạch Sống* (lan Dấu sang 4 ô kề) hoặc *Ống Dẫn Mạch*
**[TĂNG LỰC]** Commander aura (đã có) · *Mắt Bão* · thuốc vùng (mọi tháp trong 1 vòng → 1 bình buff tất cả)
**Mạnh:** hiệu quả thuốc/aura tối đa; dễ bảo vệ; ít tốn ô nguyên tố.
**Yếu:** địch đi hết nửa bản đồ mới bị bắn; sợ Điềm Báo "Đất Nứt".
**Online:** wave 6.

#### 4.16 🕸️ THIÊN LA — trải mỏng toàn tuyến
**Bàn cờ:** rải tháp đều dọc **toàn bộ** đường, mỗi tháp một ô nguyên tố khác nhau.
**[BẮT BUỘC]** *Chân Đế Xoay*/Nước Mắt Đại Bàng (tầm bắn) · nhiều ô rẻ Lv1 hơn là ít ô Lv3
**[TĂNG LỰC]** Perk *Địa Chủ* · địch đi qua nhiều Dấu liên tiếp → phản ứng nổ liên hoàn dọc đường
**Mạnh:** không có điểm mù, chống rò rỉ tốt nhất; hưởng lợi khi bản đồ mở rộng.
**Yếu:** thuốc vùng gần như vô dụng (tháp cách xa nhau); aura Commander lãng phí.
**Online:** wave 5.

---

## 5. BẢNG ĐỐI CHIẾU NHANH

| Lối chơi | Diệt boss | Dọn bầy | Phá giáp | Kinh tế | Nở lúc | Độ khó |
|---|---|---|---|---|---|---|
| Hoả Ngục | ▲ | ●●● | ▲ | ▲ | W5 | Dễ |
| Vĩnh Đông | ●●● | ●● | ▲ | ▲ | W6 | Vừa |
| Lôi Đình | ●● | ●●● | ●●● | ▲ | W5 | Vừa |
| Đại Dịch | ●●● | ●● | ▲ | ▲ | W7 | Khó |
| Thuỷ Triều | — | ●● | — | ▲ | W3 | Cần bạn đời |
| Thạch Vương | ▲ | ● | ▲ | ●●● | W2/W8 | Vừa |
| Nồi Hơi | ●●●● | ▲ | ▲ | ▲ | W6 | Vừa |
| Nhiệt Sốc | ●●● | ●● | ●●●● | ▲ | W5 | Dễ |
| Bão Biển | ▲ | ●●●● | ●● | ▲ | W4 | Dễ |
| Ô Uế | ●●● | ●●● | ▲ | ▲ | W6 | Vừa |
| Địa Chấn | ●● | ●● | ▲ | ●● | W7 | Khó |
| Thép Nguyên Bản | ●● | ●● | ● | ●● | W2 | Rất dễ |
| Bát Quái | ●●● | ●●● | ●●● | ▲ | W8 | Rất khó |
| Thương Nhân | ●●● | ●●● | ●● | ●●●● | W9 | Khó |
| Pháo Đài | ●●● | ●●● | ●● | ▲ | W6 | Dễ |
| Thiên La | ●● | ●●● | ●● | ▲ | W5 | Vừa |

**Đọc bảng thế nào:** không có cột nào toàn ●●●● — mọi build đều có ít nhất một ô ▲.
Người chơi phải **bù chỗ yếu** bằng thuốc/trang bị, hoặc chấp nhận wave nào đó sẽ khó thở.

---

## 6. LÀM SAO ĐẢM BẢO "KHÔNG LỐI NÀO SAI"

1. **Mỗi lối chơi khắc chế ít nhất 2 loại địch** trong 10 loại hiện có.
   Golem giáp 6 → Lôi/Nhiệt Sốc. Troll hồi máu → Độc. Bat bầy → Bão Biển. Boss → Nồi Hơi/Vĩnh Đông.
2. **Shop phải đảm bảo tối thiểu**: từ wave 3, shop **luôn có ≥1 món khớp** với nguyên tố người chơi
   đang sở hữu nhiều nhất (pity system). Không để ai chết vì shop không ra đồ.
3. **Perk draft có định hướng**: 1 trong 3 lá luôn thuộc nhóm khớp build hiện tại (đọc `cell_biome` +
   ô nguyên tố đang có để suy ra build).
4. **Boss cho chọn 1 trong 3** — luôn có 1 lựa chọn khớp build, 1 lựa chọn đổi hướng, 1 lựa chọn vàng.
5. **Không có "vật phẩm bắt buộc toàn cục"**: mọi món [BẮT BUỘC] ở trên chỉ bắt buộc *cho lối chơi đó*.
6. **Chuyển build phải khả thi**: bán ô nguyên tố hoàn 60% · bán trang bị hoàn 50% ·
   Lá *Cải Đạo* đổi loại quân. Lỡ đi sai hướng ở wave 5 vẫn xoay sở được.

---

## 7. THI CÔNG

| Việc | File | Nối vào |
|---|---|---|
| Dấu trên địch | `scripts/enemy/element_marks.gd` | `enemy.take_damage()`, `_process()` |
| Bảng phản ứng | `scripts/elements/reaction_table.gd` (static) | gọi khi Dấu thứ 2 bám |
| **Ô nguyên tố** | mở rộng `territory_manager.gd` + `BIOME_STATS` | thêm `element`, `level`, hình thế |
| Tháp lấy nguyên tố từ ô | `tower.gd` đọc `grid_controller.get_element_at(cell)` | `_fire_projectile()` gắn Dấu vào đạn |
| Ghép ô Lv2/Lv3 | `territory_manager` | mượn nguyên mẫu merge ★ của `tower_placer` |
| Hình thế | `scripts/elements/formation_detector.gd` | quét sau mỗi lần đặt ô |
| Thuốc | `scripts/items/potion_system.gd` + `data/potions/*.json` | HUD túi + `GridUtil.mouse_to_ground()` |
| Trang bị | `scripts/items/equipment.gd` + `BuffLayer.EQUIP` | mẫu `apply_synergy_buff` |
| Di Vật | `scripts/items/relic_system.gd` + `data/relics/*.json` | mẫu `perk_system` (đã chạy tốt) |
| Synergy nguyên tố | `SynergyManager` bộ đếm thứ 2 | không đụng bộ đếm loại quân |
| Pity shop / draft định hướng | `shop_manager`, `perk_system` | đọc trạng thái ô nguyên tố |

**Bất biến không được phá** *(xem `CLAUDE.md`)*: mặt tile y=0 · rebase toạ độ khi mở rộng ·
★ là phép nhân tách khỏi BuffLayer · `MAX_DFS_STEPS` · `Engine.time_scale` ≠ 0 · `grid_data` chỉ clear+nạp.

**Lộ trình + tình trạng** *(cập nhật 2026-07-26)*:
1. ✅ Dấu + ô nguyên tố Lv1-3 — `scripts/elements/element_types.gd`, `element_marks.gd`,
   ô nguyên tố nằm trong `territory_manager.gd` (BIOME_STATS ánh xạ sang `element`)
2. ✅ **10/10 phản ứng** — `reaction_table.gd`. Bốc Hơi · Tan Chảy · Đóng Băng · Dẫn Điện ·
   Siêu Dẫn · Quá Tải · Cháy Độc · Lan Truyền · Kết Tinh · Chấn Địa (vết nứt trên ô)
3. ✅ Thuốc theo vùng — `potion_system.gd` + `data/potions/core.json`, túi 3 ô, phím **Z/X/C**
4. ✅ Ghép ô Lv2/Lv3 + 4 hình thế — `formation_detector.gd`; thưởng cấp ô/hình thế đi vào tháp
   qua `tower.refresh_tile_element_bonus()` (`BuffLayer.TILE_ELEMENT` + `mark_duration_bonus`)
5. ✅ Trang bị 2 ô (20 món) — `equipment_system.gd`; Di Vật 5 ô (12 món) — `relic_system.gd`;
   cả hai bán trong shop (`ShopItemData.ItemType.EQUIPMENT` / `RELIC`)
6. ✅ 10 perk lối chơi — `data/perks/element_perks.json` + kênh `element` trong `perk_system.gd`
7. ✅ Synergy nguyên tố — `scripts/elements/element_synergy.gd`, trục đếm THỨ HAI (tách khỏi
   `SynergyManager` vì nguyên tố đổi mà không có tháp nào được đặt/gỡ). Ngưỡng 2/4/6; mốc ×6
   đổi LUẬT: Biển Lửa · Băng Vĩnh Cửu · Bão Sét · Đại Dịch · Thuỷ Triều · Địa Chấn
8. ✅ Bát Quái (đủ 6 nguyên tố trên bàn) → mở **Nguyên Sơ**: 20% mỗi phản ứng thăng cấp thành
   vụ nổ 400% trong 3m. KHÔNG phải cặp Dấu mới — 6 nguyên tố thì mọi cặp đã có chủ
9. ✅ Hình thế đủ 4: Hàng Long (+1 tầm) · Tứ Trụ (+40% phản ứng) · Song Cực (tháp tự kích phản
   ứng mỗi 4s) · Trận Vòng (tháp ô giữa mượn nguyên tố vòng vây)
10. ✅ Lưới an toàn §6: pity shop (từ wave 3 luôn có ô khớp build) · draft perk định hướng
   (1/3 lá khớp) · boss chọn 1-trong-3 (khớp build / đổi hướng / vàng) · bán ô hoàn 60% ·
   ô miễn phí khi mở vùng biome mới
11. ✅ Bốn nguồn ô nguyên tố đủ (§2.4): shop · khí hậu vùng (miễn phí khi mở vùng mới) ·
   encounter ("Long Mạch Lộ Thiên", "Thợ Khắc Đá Câm" — `EncounterChoice.element_tiles`) ·
   boss (chọn 1-trong-3) · Kết Tinh rơi mảnh 5%
12. ✅ **Sách Nguyên Tố** (phím F1) — codex tra cứu 6 nguyên tố / 10 phản ứng / 4 hình thế +
   Bát Quái / 3 cấp ô. Nội dung đọc THẲNG từ `ElementTypes`, `ReactionTable.TABLE`,
   `FormationDetector`, `TerritoryManager.LEVEL_BONUS` → thêm nội dung là codex tự cập nhật.
13. ✅ **Khắc/kháng nguyên tố** (§6.1) — `EnemyStats.DEFAULT_AFFINITY`, khắc ×1.5 / kháng ×0.6,
   cân để mọi hệ khắc chế ≥2 loài. Hiện ở popup trinh sát + codex.
14. ✅ **Hình ảnh**: overlay hình thế trên bàn (`formation_overlay.gd`) + vòng nguyên tố dưới
   chân tháp (`tower._refresh_element_ring`) → bố cục ô và nguyên tố của từng tháp đọc được
   bằng mắt, không phải click từng ô.
15. ⬜ **Còn lại**: cân bằng số liệu 16 lối chơi qua playtest (không tự động hoá được)

---

## 8. NGUYÊN TẮC CÂN BẰNG

1. **Tối đa 2 Dấu.** 3 Dấu chỉ mở bằng Di Vật hiếm.
2. **Phản ứng tiêu thụ Dấu** — nếu không, 1 ô Lôi + 1 ô Thuỷ xoá sổ mọi wave.
3. **Đóng Băng có cooldown ẩn 6s/con.** Không có nó, Vĩnh Đông khoá cứng bản đồ và game hết vui.
4. **Trần sát thương phản ứng 400%** kể cả chồng đủ Di Vật.
5. **Tháp trên ô thường không được yếu hơn** — perk *Thuần Vật Lý* + trang bị thô phải bù đủ.
6. **Thuốc dùng được giữa trận.** Đó là lý do chúng vui.
7. **Mọi con số phải hiện ra**: Dấu còn mấy giây, phản ứng gây bao nhiêu, ô cấp mấy.
8. **Định nghĩa bằng JSON** (`data/potions/`, `data/relics/`, `data/equipment/`, `data/tiles/`) như `data/perks/` đang làm — cân bằng không cần build lại.

---

## 9. RỦI RO

| Rủi ro | Xử lý |
|---|---|
| 50 địch nổ phản ứng cùng lúc gây lag | Hàng đợi tối đa 8 phản ứng/frame, FX gộp theo ô |
| Người chơi không hiểu vì sao nổ | Nhật ký phản ứng góc màn hình + damage number ghi tên phản ứng |
| Bão Biển quá mạnh, build khác vô dụng | Dẫn Điện cơ bản giới hạn 4 mục tiêu; muốn 8 phải đầu tư Synergy Lôi ×6 |
| Shop không ra đồ khớp → build chết | Pity system §6.2 |
| 60+ vật phẩm khó cân bằng | JSON + log đóng góp sát thương theo nguồn (đã có `record_tower_damage`) |
| UI quá tải | Ngoài màn chỉ hiện túi thuốc 3 ô + Dấu trên địch; còn lại vào bảng Kho Đồ (phím I) |
| Ô nguyên tố xung đột ô Phước/Nguyền | Một ô chỉ mang **một** thuộc tính; ô Phước/Nguyền không đặt ô nguyên tố lên được |
| Xung đột với biome vùng | Biome ảnh hưởng **chỉ số**, ô nguyên tố ảnh hưởng **Dấu** — hai hệ độc lập |

---

## 10. VIỆC LÀM NGAY

1. `territory_manager`: thêm field `element` cho 6 loại ô, đổi tên hiển thị sang Mạch Hoả/Băng/Lôi/Thuỷ/Độc/Thổ.
2. `grid_controller.get_element_at(cell) -> String` — tháp tra khi bắn.
3. `element_marks.gd` — component trên `enemy.tscn`, tối đa 2 Dấu, đếm giờ, biểu tượng Label3D.
4. `reaction_table.gd` — 6 phản ứng đầu (Bốc Hơi, Tan Chảy, Đóng Băng, Dẫn Điện, Quá Tải, Lan Truyền).
5. `tower._fire_projectile()` đọc element của ô → gắn vào đạn → `projectile.hit_target()` gọi `marks.apply()`.
6. Túi thuốc 3 ô + vòng ngắm vùng; làm 3 bình trước: Rượu Cường Lực · Tinh Chất Cộng Hưởng · Bình Nước Bẩn.
7. Perk *Thuần Vật Lý* + *Hoả Sư* + *Lôi Đình* — để 3 lối chơi đầu tiên chơi được ngay.
8. Regression 12 wave, đếm phản ứng/wave và sát thương theo nguồn để cân bằng.
