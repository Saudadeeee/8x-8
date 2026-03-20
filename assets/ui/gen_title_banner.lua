-- Main Menu Title Banner "8x8" in ancient pixel art style
-- 320x80 pixels

local OUT = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/title_banner.aseprite"
local PNG = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/title_banner.png"
local W, H = 320, 80

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
local function circle_fill(cx,cy,r,ro,go,bo)
  for y=-r,r do for x=-r,r do
    if x*x+y*y<=r*r then px(cx+x,cy+y,ro,go,bo) end
  end end
end

-- Background: deep ink black
fill(0,0,W-1,H-1, 0x08,0x04,0x02)

-- Decorative horizontal lines (top/bottom frame)
hline(0,W-1,0, 0xC8,0x96,0x0C)
hline(0,W-1,1, 0x7A,0x5A,0x0A)
hline(0,W-1,2, 0x3A,0x28,0x06)
hline(0,W-1,H-1, 0xC8,0x96,0x0C)
hline(0,W-1,H-2, 0x7A,0x5A,0x0A)
hline(0,W-1,H-3, 0x3A,0x28,0x06)

-- Side borders
for i=0,2 do
  local c = (i==0) and 0xC8 or (i==1 and 0x7A or 0x3A)
  local g = (i==0) and 0x96 or (i==1 and 0x5A or 0x28)
  local b = (i==0) and 0x0C or (i==1 and 0x0A or 0x06)
  vline(i,0,H-1,c,g,b); vline(W-1-i,0,H-1,c,g,b)
end

-- Dragon/phoenix motif: left and right sides (simplified)
-- Left side ornament (simplified cloud/dragon curl)
for i=0,7 do
  local a = i*3
  px(6+a, 10+i, 0xC8,0x96,0x0C)
  px(6+a, H-11-i, 0xC8,0x96,0x0C)
end
for i=0,5 do
  px(5, 14+i*8, 0xFF,0xD7,0x00)
end

-- Right side ornament (mirror)
for i=0,7 do
  local a = i*3
  px(W-7-a, 10+i, 0xC8,0x96,0x0C)
  px(W-7-a, H-11-i, 0xC8,0x96,0x0C)
end
for i=0,5 do
  px(W-6, 14+i*8, 0xFF,0xD7,0x00)
end

-- ======= PIXEL ART TEXT: "8x8" =======
-- Each character is ~30px wide, 40px tall, drawn with pixel strokes
-- Starting x: center around W/2 = 160, total ~110px
-- "8" at x=65, "x" at x=125, "8" at x=180

local function draw_thick_pixel(x,y,sz,r,g,b)
  for dy=0,sz-1 do for dx=0,sz-1 do px(x+dx,y+dy,r,g,b) end end
end

local SZ = 4  -- pixel size for each "big pixel"
local TY = 18 -- top y of text

-- === "8" digit left ===
local function draw_8(sx, sy)
  -- Top half circle
  hline(sx+1,sx+5,sy, 0xC8,0x96,0x0C)
  hline(sx+1,sx+5,sy, 0xFF,0xD7,0x00)
  vline(sx,sy+1,sy+4, 0xFF,0xD7,0x00)
  vline(sx+6,sy+1,sy+4, 0xFF,0xD7,0x00)
  hline(sx+1,sx+5,sy+4, 0xFF,0xD7,0x00)
  -- Bottom half circle
  vline(sx,sy+5,sy+8, 0xFF,0xD7,0x00)
  vline(sx+6,sy+5,sy+8, 0xFF,0xD7,0x00)
  hline(sx+1,sx+5,sy+8, 0xFF,0xD7,0x00)
  -- Mid line
  hline(sx+1,sx+5,sy+4, 0xFF,0xD7,0x00)
  -- Fill with gold
  fill(sx+1,sy+1,sx+5,sy+3, 0xC8,0x96,0x0C)
  fill(sx+1,sy+5,sx+5,sy+7, 0xC8,0x96,0x0C)
  -- Highlight
  px(sx+1,sy+1, 0xFF,0xFF,0x80); px(sx+1,sy+5, 0xFF,0xFF,0x80)
  -- Shadow
  vline(sx+5,sy+1,sy+3, 0x7A,0x5A,0x0A)
  vline(sx+5,sy+5,sy+7, 0x7A,0x5A,0x0A)
end

local function draw_8_big(sx, sy)
  local SC = 5  -- scale factor
  -- Draw at 7x9 then scale: just draw big pixels
  local pattern = {
    "0111110",
    "1000001",
    "1000001",
    "0111110",
    "1000001",
    "1000001",
    "1000001",
    "0111110",
  }
  for row,line in ipairs(pattern) do
    for col=1,#line do
      local c = line:sub(col,col)
      local bright = (row==1 or row==4 or row==8)
      local r = bright and 0xFF or 0xC8
      local g = bright and 0xD7 or 0x96
      local b = bright and 0x00 or 0x0C
      if c == "1" then
        fill(sx+(col-1)*SC, sy+(row-1)*SC, sx+col*SC-1, sy+row*SC-1, r,g,b)
        -- Highlight top-left of each cell
        if bright then
          px(sx+(col-1)*SC, sy+(row-1)*SC, 0xFF,0xFF,0x80)
        end
      end
    end
  end
end

local function draw_x_big(sx, sy)
  local SC = 5
  local pattern = {
    "1000001",
    "0100010",
    "0010100",
    "0001000",
    "0010100",
    "0100010",
    "1000001",
  }
  for row,line in ipairs(pattern) do
    for col=1,#line do
      if line:sub(col,col)=="1" then
        fill(sx+(col-1)*SC, sy+(row-1)*SC, sx+col*SC-1, sy+row*SC-1, 0xC8,0x96,0x0C)
        px(sx+(col-1)*SC, sy+(row-1)*SC, 0xFF,0xD7,0x00)
      end
    end
  end
  -- Center pixel highlight
  fill(sx+3*SC, sy+3*SC, sx+4*SC-1, sy+4*SC-1, 0xFF,0xFF,0x80)
end

-- Draw "8 x 8"
draw_8_big(54, TY)   -- left "8"
draw_x_big(124, TY+5)  -- "x" (smaller, centered vertically)
draw_8_big(194, TY)  -- right "8"

-- Subtitle decorative lines
local SY = TY + 45
hline(40,W-41,SY, 0x7A,0x5A,0x0A)
hline(44,W-45,SY+1, 0xC8,0x96,0x0C)
hline(48,W-49,SY+2, 0x7A,0x5A,0x0A)

-- Center diamond on subtitle line
px(W//2-1,SY+1, 0xFF,0xFF,0x80); px(W//2,SY+1, 0xFF,0xFF,0x80)
px(W//2,SY, 0xFF,0xD7,0x00); px(W//2,SY+2, 0xFF,0xD7,0x00)

-- Left/right end ornaments on subtitle line
circle_fill(42,SY+1,3, 0xC8,0x96,0x0C)
circle_fill(W-43,SY+1,3, 0xC8,0x96,0x0C)
px(42,SY+1, 0xFF,0xD7,0x00); px(W-43,SY+1, 0xFF,0xD7,0x00)

-- Small decorative dots scattered
for i=0,5 do
  px(20+i*50, H//2-15, 0x7A,0x5A,0x0A)
  px(20+i*50, H//2+15, 0x7A,0x5A,0x0A)
end

spr:saveAs(OUT)
spr:saveCopyAs(PNG)
