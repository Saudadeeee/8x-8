-- Ve 100 icon di vat 32x32 cho 8x-8.
-- QUY TRINH (art PHAI di qua gamedev toolkit MCP, khong tu sinh bang script):
--   1. python tools/relic_icon_spec.py          -> sinh tools/relic_icon_spec.lua
--   2. Aseprite MCP run_lua_script:
--        dofile("D:/Code/SourceCode/GameDev/8x-8/tools/relic_icons.lua")
--   3. godot --headless --import                <- BAT BUOC, xem ghi chu duoi
--
-- Nhom hinh nen noi ngay co che, doc duoc TRUOC khi doc chu:
--   KHIEN      dieu kien   ("khi ... thi ...")
--   CHONG DIA  bo dem      ("moi ... thi ...")
--   CAN CONG   danh doi    (dia trai cao / dia phai thap = co mat trai)
--   DA QUY     lai         (dieu kien + bo dem)
--   CHIA KHOA  doi luat    (khong dung engine, sua CACH choi)
-- Mau loi theo chu de, vien theo bac hiem.
-- Nguon sang co dinh TREN-TRAI, outline #14100c tinh theo VIEN mat na.
-- CHU Y 1: file nay phai thuan ASCII -- server MCP tu choi ky tu ngoai ASCII.
-- CHU Y 2: PNG sinh NGOAI editor thi Godot CHUA import. Phai chay
--          `godot --headless --import`, neu khong HUD im lang roi ve nhan chu
--          viet tat va nhin y het "icon bi hong". Da dinh dung loi nay.

local S = 32
local OUT = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/relics/"
-- SPEC nap SAU khi dinh nghia hinh (dofile chay ngay, ten ham chua ton tai).

local function C(t) return app.pixelColor.rgba(t[1], t[2], t[3], 255) end
local OL = app.pixelColor.rgba(0x14, 0x10, 0x0c, 255)

local function newbuf()
  local b = {}
  for y = 0, S - 1 do b[y] = {} end
  return b
end
local function put(b, x, y, c)
  if x >= 0 and x < S and y >= 0 and y < S then b[y][x] = c end
end
local function rect(b, x0, y0, x1, y1, c)
  for y = y0, y1 do for x = x0, x1 do put(b, x, y, c) end end
end
local function disc(b, cx, cy, r, c)
  for y = cy - r, cy + r do for x = cx - r, cx + r do
    if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r then put(b, x, y, c) end
  end end
end
-- Dia NONG: be ngang gap doi chieu cao. Dung disc thi no thanh cuc tron.
local function bowl(b, cx, cy, rw, rh, cmain, ctop)
  for y = cy, cy + rh do for x = cx - rw, cx + rw do
    local nx = (x - cx) / rw
    local ny = (y - cy) / rh
    if nx * nx + ny * ny <= 1.0 then put(b, x, y, cmain) end
  end end
  for x = cx - rw, cx + rw do put(b, x, cy, ctop) end
end
-- Ellipse: dong xu nhin nghieng doc hon disc tron.
local function ell(b, cx, cy, rw, rh, c)
  for y = cy - rh, cy + rh do for x = cx - rw, cx + rw do
    local nx, ny = (x - cx) / rw, (y - cy) / rh
    if nx * nx + ny * ny <= 1.0 then put(b, x, y, c) end
  end end
end
-- Dia can: hinh thang HEP DAN XUONG DUOI. Ve bang cung tron nua duoi thi no
-- loe ra hai ben va ca hinh doc thanh "thanh gia co canh".
local function pan(b, cx, ytop, wtop, h, cmain, ctop, cbot)
  for i = 0, h do
    local w = wtop - math.floor(i * (wtop - 2) / h)
    for x = cx - w, cx + w do
      local c = cmain
      if i == 0 then c = ctop elseif i == h then c = cbot end
      put(b, x, ytop + i, c)
    end
  end
end
-- Outline tinh theo VIEN mat na, KHONG halo tung pixel: halo 3x3 lap khe ho
-- ben trong hinh (da dinh loi do o bo icon truoc).
local function outline(b)
  local add = {}
  for y = 0, S - 1 do for x = 0, S - 1 do
    if b[y][x] == nil then
      local touch = false
      for dy = -1, 1 do for dx = -1, 1 do
        local nx, ny = x + dx, y + dy
        if nx >= 0 and nx < S and ny >= 0 and ny < S and b[ny][nx] ~= nil then
          touch = true
        end
      end end
      if touch then add[#add + 1] = { x, y } end
    end
  end end
  for i = 1, #add do b[add[i][2]][add[i][1]] = OL end
end

-- -- Nam hinh nhom ----------------------------------------------------------

function shield(b, base, lite, dark)
  for y = 5, 27 do
    local w
    if y <= 20 then w = 10 else w = 10 - math.floor((y - 20) * (10 / 7)) end
    if w < 0 then w = 0 end
    for x = 16 - w, 16 + w do
      local c = base
      if x <= 16 - w + 2 then c = lite elseif x >= 16 + w - 2 then c = dark end
      put(b, x, y, c)
    end
  end
  for x = 7, 25 do put(b, x, 5, lite) end
end

function coins(b, base, lite, dark)
  -- Moi dong xu co VIEN TOI o day va cach nhau mot hang: khong the thi ca
  -- chong dinh lien va doc thanh mot o banh mi.
  local ys = { 25, 19, 13, 7 }
  for i = 1, 4 do
    local cy = ys[i]
    ell(b, 16, cy, 10, 4, base)
    ell(b, 16, cy - 1, 10, 4, base)
    for x = 6, 26 do
      local nx = (x - 16) / 10
      if nx * nx <= 1.0 then put(b, x, cy + 3, dark) end
    end
    ell(b, 12, cy - 2, 4, 2, lite)
  end
end

function scales(b, base, lite, dark)
  rect(b, 15, 7, 17, 25, base); rect(b, 15, 7, 15, 25, lite)
  rect(b, 4, 9, 28, 10, base)
  for x = 4, 28 do put(b, x, 9, lite) end
  rect(b, 4, 11, 4, 13, dark); rect(b, 28, 11, 28, 16, dark)
  pan(b, 4, 14, 6, 4, base, lite, dark)   -- dia trai CAO  = nhe
  pan(b, 28, 17, 6, 4, dark, base, dark)  -- dia phai THAP = nang
  rect(b, 10, 26, 22, 28, dark)
  for x = 10, 22 do put(b, x, 26, base) end
end

function gem(b, base, lite, dark)
  for y = 4, 28 do
    local t = math.abs(y - 14) / 12.0
    local w = math.floor(11 * (1.0 - t * 0.82))
    for x = 16 - w, 16 + w do
      local c = base
      if x < 14 then c = lite elseif x > 19 then c = dark end
      put(b, x, y, c)
    end
  end
  rect(b, 12, 10, 15, 20, lite)
end

function key(b, base, lite, dark)
  disc(b, 11, 10, 7, dark)
  disc(b, 11, 9, 7, base)
  disc(b, 8, 7, 3, lite)
  for y = 6, 12 do for x = 8, 14 do
    if (x - 11) * (x - 11) + (y - 9) * (y - 9) <= 9 then b[y][x] = nil end
  end end
  rect(b, 14, 13, 18, 16, base)
  rect(b, 16, 15, 19, 27, base)
  rect(b, 16, 15, 16, 27, lite)
  rect(b, 19, 20, 23, 22, base)
  rect(b, 19, 24, 22, 26, base)
end

-- Bang tra hinh + SPEC nap O DAY, sau khi cac ham da ton tai. dofile chay NGAY
-- luc goi, nen nap spec o dau file thi moi `fn` deu la nil.
local SHAPES = { shield = shield, coins = coins, scales = scales, gem = gem, key = key }
local SPEC = dofile("D:/Code/SourceCode/GameDev/8x-8/tools/relic_icon_spec.lua")

-- -- Ve hang loat -----------------------------------------------------------

local made = 0
for i = 1, #SPEC do
  local e = SPEC[i]
  local b = newbuf()
  local fn = SHAPES[e.fn]
  if fn == nil then error("khong co hinh " .. tostring(e.fn) .. " cho " .. e.id) end
  fn(b, C(e.b), C(e.l), C(e.d))
  outline(b)

  local spr = Sprite(S, S, ColorMode.RGB)
  local img = spr.cels[1].image
  for y = 0, S - 1 do for x = 0, S - 1 do
    if b[y][x] ~= nil then img:putPixel(x, y, b[y][x]) end
  end end
  -- Vien BAC ve SAU outline nen no nam ngoai cung, doc duoc ngay tu xa.
  local rb, rl = C(e.rb), C(e.rl)
  for x = 0, S - 1 do
    img:putPixel(x, 0, rb); img:putPixel(x, S - 1, rb)
  end
  for y = 0, S - 1 do
    img:putPixel(0, y, rb); img:putPixel(S - 1, y, rb)
  end
  for x = 1, S - 2 do img:putPixel(x, 1, rl) end

  spr:saveAs(OUT .. e.id .. ".png")
  spr:close()
  made = made + 1
end
print("da ve " .. made .. " icon vao " .. OUT)
