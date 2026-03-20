-- HUD Stat Frame - 160x36 - small panel for health/gold/phase labels
local OUT = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/hud_stat_frame.aseprite"
local PNG = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/hud_stat_frame.png"
local W, H = 160, 36

local spr = Sprite(W, H)
local img = spr.cels[1].image

local function px(x,y,r,g,b,a)
  a=a or 255
  if x>=0 and x<W and y>=0 and y<H then img:putPixel(x,y,Color(r,g,b,a)) end
end
local function hline(x0,x1,y,r,g,b) for x=x0,x1 do px(x,y,r,g,b) end end
local function vline(x,y0,y1,r,g,b) for y=y0,y1 do px(x,y,r,g,b) end end
local function fill(x0,y0,x1,y1,r,g,b)
  for y=y0,y1 do for x=x0,x1 do px(x,y,r,g,b) end end
end

-- Background: dark semi-transparent lacquer
fill(0,0,W-1,H-1, 0x10,0x08,0x04)

-- Outer border: gold
hline(0,W-1,0, 0xC8,0x96,0x0C)
hline(0,W-1,H-1, 0xC8,0x96,0x0C)
vline(0,0,H-1, 0xC8,0x96,0x0C)
vline(W-1,0,H-1, 0xC8,0x96,0x0C)

-- Second border: dark gold
hline(1,W-2,1, 0x7A,0x5A,0x0A)
hline(1,W-2,H-2, 0x7A,0x5A,0x0A)
vline(1,1,H-2, 0x7A,0x5A,0x0A)
vline(W-2,1,H-2, 0x7A,0x5A,0x0A)

-- Corner ornaments (small L-shapes)
px(2,2, 0xFF,0xD7,0x00); px(3,2, 0xFF,0xD7,0x00)
px(2,3, 0xFF,0xD7,0x00)
px(W-3,2, 0xFF,0xD7,0x00); px(W-4,2, 0xFF,0xD7,0x00)
px(W-3,3, 0xFF,0xD7,0x00)
px(2,H-3, 0xFF,0xD7,0x00); px(3,H-3, 0xFF,0xD7,0x00)
px(2,H-4, 0xFF,0xD7,0x00)
px(W-3,H-3, 0xFF,0xD7,0x00); px(W-4,H-3, 0xFF,0xD7,0x00)
px(W-3,H-4, 0xFF,0xD7,0x00)

-- Top highlight
hline(3,W-4,2, 0x30,0x20,0x08)

-- Left icon separator (vertical line at x=28 for icon area)
vline(28,2,H-3, 0x7A,0x5A,0x0A)
vline(29,2,H-3, 0x3A,0x28,0x06)

-- Small diamond on left separator
px(28, H//2-1, 0xFF,0xD7,0x00)
px(27, H//2,   0xC8,0x96,0x0C)
px(28, H//2,   0xFF,0xFF,0x80)
px(29, H//2,   0xC8,0x96,0x0C)
px(28, H//2+1, 0xFF,0xD7,0x00)

spr:saveAs(OUT)
spr:saveCopyAs(PNG)
