-- Button Normal - Ancient Chinese (古風) style
-- 192x48 pixels

local OUT = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/button_normal.aseprite"
local PNG = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/button_normal.png"
local W, H = 192, 48

local spr = Sprite(W, H)
local img = spr.cels[1].image

local function px(x, y, r, g, b, a)
  a = a or 255
  if x >= 0 and x < W and y >= 0 and y < H then
    img:putPixel(x, y, Color(r, g, b, a))
  end
end

local function hline(x0, x1, y, r, g, b)
  for x = x0, x1 do px(x, y, r, g, b) end
end

local function vline(x, y0, y1, r, g, b)
  for y = y0, y1 do px(x, y, r, g, b) end
end

local function rect(x, y, w, h, r, g, b)
  hline(x, x+w-1, y, r, g, b)
  hline(x, x+w-1, y+h-1, r, g, b)
  vline(x, y, y+h-1, r, g, b)
  vline(x+w-1, y, y+h-1, r, g, b)
end

local function fill(x0, y0, x1, y1, r, g, b)
  for y = y0, y1 do
    for x = x0, x1 do px(x, y, r, g, b) end
  end
end

-- === BACKGROUND: dark lacquer ===
fill(0, 0, W-1, H-1, 0x10, 0x08, 0x04)

-- Subtle wood-grain lines (horizontal, slightly lighter)
for y = 6, H-7, 6 do
  for x = 4, W-5 do
    if (x + y) % 3 == 0 then
      px(x, y, 0x18, 0x0C, 0x05)
    end
  end
end

-- === OUTER BORDER: bright gold (1px) ===
rect(0, 0, W, H, 0xC8, 0x96, 0x0C)

-- === OUTER BORDER highlight dots at corners ===
-- top-left corner ornament
px(1,1, 0xFF,0xD7,0x00); px(2,1, 0xFF,0xD7,0x00); px(3,1, 0xFF,0xD7,0x00)
px(1,2, 0xFF,0xD7,0x00)
px(1,3, 0xFF,0xD7,0x00)
-- top-right
px(W-2,1, 0xFF,0xD7,0x00); px(W-3,1, 0xFF,0xD7,0x00); px(W-4,1, 0xFF,0xD7,0x00)
px(W-2,2, 0xFF,0xD7,0x00)
px(W-2,3, 0xFF,0xD7,0x00)
-- bottom-left
px(1,H-2, 0xFF,0xD7,0x00); px(2,H-2, 0xFF,0xD7,0x00); px(3,H-2, 0xFF,0xD7,0x00)
px(1,H-3, 0xFF,0xD7,0x00)
px(1,H-4, 0xFF,0xD7,0x00)
-- bottom-right
px(W-2,H-2, 0xFF,0xD7,0x00); px(W-3,H-2, 0xFF,0xD7,0x00); px(W-4,H-2, 0xFF,0xD7,0x00)
px(W-2,H-3, 0xFF,0xD7,0x00)
px(W-2,H-4, 0xFF,0xD7,0x00)

-- === INNER BORDER: dark gold (inset 3px) ===
rect(3, 3, W-6, H-6, 0x7A, 0x5A, 0x0A)

-- === DIAMOND ornament at left/right center edges ===
local MX, MY = W//2, H//2
-- Left mid diamond
px(4,  MY,   0xFF,0xD7,0x00)
px(5,  MY-1, 0xC8,0x96,0x0C); px(5, MY+1, 0xC8,0x96,0x0C)
px(6,  MY,   0xC8,0x96,0x0C)
-- Right mid diamond
px(W-5, MY,   0xFF,0xD7,0x00)
px(W-6, MY-1, 0xC8,0x96,0x0C); px(W-6, MY+1, 0xC8,0x96,0x0C)
px(W-7, MY,   0xC8,0x96,0x0C)

-- === TOP HIGHLIGHT: subtle bright line inside top border ===
hline(4, W-5, 4, 0x50, 0x38, 0x10)

-- === BOTTOM SHADOW: darker line inside bottom border ===
hline(4, W-5, H-4, 0x08, 0x05, 0x02)

-- === Save ===
spr:saveAs(OUT)
spr:saveCopyAs(PNG)
