-- Button Pressed - darker/pushed in
local OUT = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/button_pressed.aseprite"
local PNG = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/button_pressed.png"
local W, H = 192, 48

local spr = Sprite(W, H)
local img = spr.cels[1].image

local function px(x,y,r,g,b,a)
  a=a or 255
  if x>=0 and x<W and y>=0 and y<H then img:putPixel(x,y,Color(r,g,b,a)) end
end
local function hline(x0,x1,y,r,g,b) for x=x0,x1 do px(x,y,r,g,b) end end
local function vline(x,y0,y1,r,g,b) for y=y0,y1 do px(x,y,r,g,b) end end
local function rect(x,y,w,h,r,g,b)
  hline(x,x+w-1,y,r,g,b); hline(x,x+w-1,y+h-1,r,g,b)
  vline(x,y,y+h-1,r,g,b); vline(x+w-1,y,y+h-1,r,g,b)
end
local function fill(x0,y0,x1,y1,r,g,b)
  for y=y0,y1 do for x=x0,x1 do px(x,y,r,g,b) end end
end

-- Dark pressed background
fill(0,0,W-1,H-1, 0x08,0x05,0x02)

-- Outer border: dim gold
rect(0,0,W,H, 0x7A,0x5A,0x0A)
-- Inner pressed shadow at top
hline(1,W-2,1, 0x04,0x03,0x01)
hline(1,W-2,2, 0x06,0x04,0x01)
-- Bottom highlight (opposite of normal)
hline(4,W-5,H-4, 0x3A,0x28,0x08)

-- Corner marks (dimmed)
px(2,2,0xC8,0x96,0x0C); px(3,2,0x7A,0x5A,0x0A)
px(W-3,2,0xC8,0x96,0x0C); px(W-4,2,0x7A,0x5A,0x0A)
px(2,H-3,0xC8,0x96,0x0C); px(3,H-3,0x7A,0x5A,0x0A)
px(W-3,H-3,0xC8,0x96,0x0C); px(W-4,H-3,0x7A,0x5A,0x0A)

-- Inner border: very dim
rect(3,3,W-6,H-6, 0x4A,0x38,0x08)

spr:saveAs(OUT)
spr:saveCopyAs(PNG)
