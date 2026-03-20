-- Encounter Icons - 80x80 each - 4 types: battle, treasure, curse, event
-- Creates 4 separate PNG files

local ASEPRITE_PATH = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/"
local W, H = 80, 80

local function make_icon(filename, draw_fn)
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
      if x*x+y*y <= r*r then px(cx+x,cy+y,ro,go,bo) end
    end end
  end

  -- Draw background + frame (common)
  fill(0,0,W-1,H-1, 0x0D,0x08,0x04)
  hline(0,W-1,0, 0xC8,0x96,0x0C); hline(0,W-1,H-1, 0xC8,0x96,0x0C)
  vline(0,0,H-1, 0xC8,0x96,0x0C); vline(W-1,0,H-1, 0xC8,0x96,0x0C)
  hline(2,W-3,2, 0x7A,0x5A,0x0A); hline(2,W-3,H-3, 0x7A,0x5A,0x0A)
  vline(2,2,H-3, 0x7A,0x5A,0x0A); vline(W-3,2,H-3, 0x7A,0x5A,0x0A)
  -- Corner dots
  px(1,1,0xFF,0xD7,0x00); px(W-2,1,0xFF,0xD7,0x00)
  px(1,H-2,0xFF,0xD7,0x00); px(W-2,H-2,0xFF,0xD7,0x00)

  draw_fn(px, hline, vline, fill, circle_fill)

  local afile = ASEPRITE_PATH..filename..".aseprite"
  local pfile = ASEPRITE_PATH..filename..".png"
  spr:saveAs(afile)
  spr:saveCopyAs(pfile)
end

-- === BATTLE ICON: crossed swords ===
make_icon("encounter_battle", function(px,hline,vline,fill,circle_fill)
  -- Sword 1 (top-left to bottom-right diagonal)
  for i=-20,20 do
    local x = 40+i; local y = 40+i
    if i >= -18 and i <= 18 then
      px(x,y, 0xC8,0xC8,0xC8)
      px(x+1,y, 0xA0,0xA0,0xA0)
    end
  end
  -- Sword blade (thicker tip)
  for i=8,18 do
    px(40+i,40+i, 0xE8,0xE8,0xE8)
    px(40+i-1,40+i, 0xC0,0xC0,0xC0)
  end
  -- Sword 2 (top-right to bottom-left)
  for i=-18,18 do
    local x = 40+i; local y = 40-i
    px(x,y, 0xC8,0xC8,0xC8)
    px(x+1,y, 0xA0,0xA0,0xA0)
  end
  -- Cross guard sword 1
  for i=-6,6 do
    px(36+i, 40+i, 0xC8,0x96,0x0C)
    px(36+i, 41+i, 0x7A,0x5A,0x0A)
  end
  -- Cross guard sword 2
  for i=-6,6 do
    px(44+i, 40-i, 0xC8,0x96,0x0C)
    px(44+i, 41-i, 0x7A,0x5A,0x0A)
  end
  -- Handles
  for i=0,8 do
    px(22+i,22+i, 0x8B,0x4A,0x15); px(23+i,22+i, 0x6B,0x38,0x0F)
    px(56+i,56-i, 0x8B,0x4A,0x15); px(57+i,56-i, 0x6B,0x38,0x0F)
  end
  -- Red glow at cross center
  px(39,40, 0xFF,0x20,0x20); px(40,39, 0xFF,0x20,0x20)
  px(40,40, 0xFF,0x40,0x40); px(41,40, 0xFF,0x20,0x20)
  px(40,41, 0xFF,0x20,0x20)
end)

-- === TREASURE ICON: chest/coin pile ===
make_icon("encounter_treasure", function(px,hline,vline,fill,circle_fill)
  -- Chest body
  fill(16,42, 63,64, 0x6B,0x38,0x0F)
  fill(17,43, 62,63, 0x8B,0x4A,0x15)
  -- Chest lid
  fill(16,30, 63,41, 0x4A,0x28,0x08)
  fill(17,31, 62,40, 0x6B,0x38,0x0F)
  -- Chest border
  hline(16,63,30, 0xC8,0x96,0x0C); hline(16,63,42, 0xC8,0x96,0x0C); hline(16,63,64, 0xC8,0x96,0x0C)
  vline(16,30,64, 0xC8,0x96,0x0C); vline(63,30,64, 0xC8,0x96,0x0C)
  -- Lock
  fill(36,37, 43,46, 0xC8,0x96,0x0C)
  fill(37,38, 42,45, 0x7A,0x5A,0x0A)
  px(39,35,0xC8,0x96,0x0C); px(40,35,0xC8,0x96,0x0C)
  px(38,36,0xC8,0x96,0x0C); px(41,36,0xC8,0x96,0x0C)
  -- Gold coins spilling out top
  circle_fill(30,28,5, 0xFF,0xD7,0x00)
  circle_fill(40,25,4, 0xFF,0xD7,0x00)
  circle_fill(50,28,5, 0xFF,0xD7,0x00)
  circle_fill(30,28,3, 0xC8,0x96,0x0C)
  circle_fill(40,25,2, 0xC8,0x96,0x0C)
  circle_fill(50,28,3, 0xC8,0x96,0x0C)
  -- Coin shine dots
  px(28,26, 0xFF,0xFF,0xA0); px(38,24, 0xFF,0xFF,0xA0); px(48,26, 0xFF,0xFF,0xA0)
end)

-- === CURSE/MAGIC ICON: ominous eye ===
make_icon("encounter_curse", function(px,hline,vline,fill,circle_fill)
  -- Outer glow (dark purple)
  circle_fill(40,40,22, 0x20,0x08,0x28)
  circle_fill(40,40,20, 0x30,0x0C,0x38)
  -- Eye white/iris
  circle_fill(40,40,14, 0x60,0x20,0x80)
  circle_fill(40,40,10, 0x90,0x30,0xA0)
  circle_fill(40,40,7,  0x50,0x10,0x60)
  -- Pupil
  circle_fill(40,40,4, 0x10,0x00,0x18)
  -- Inner glow
  circle_fill(40,40,2, 0xC0,0x40,0xFF)
  -- Highlight dot
  px(38,38, 0xFF,0xC0,0xFF)
  -- Eye slits (horizontal)
  hline(22,57,40, 0x80,0x20,0xA0)
  hline(23,56,39, 0x60,0x10,0x80)
  hline(23,56,41, 0x60,0x10,0x80)
  -- Lash marks
  for i=0,4 do
    local a = i*3
    px(22+a, 40-a, 0xA0,0x40,0xC0)
    px(57-a, 40-a, 0xA0,0x40,0xC0)
    px(22+a, 40+a, 0xA0,0x40,0xC0)
    px(57-a, 40+a, 0xA0,0x40,0xC0)
  end
  -- Gold border glow
  circle_fill(40,40,22, 0x20,0x08,0x28)
  for i=0,359,5 do
    local rad = math.rad(i)
    local x = math.floor(40 + 21*math.cos(rad))
    local y = math.floor(40 + 21*math.sin(rad))
    px(x,y, 0x80,0x20,0xC0)
  end
end)

-- === EVENT ICON: ancient scroll ===
make_icon("encounter_event", function(px,hline,vline,fill,circle_fill)
  -- Scroll body
  fill(20,20, 59,59, 0xD4,0xB8,0x80)
  fill(21,21, 58,58, 0xE8,0xD0,0xA0)
  -- Scroll top rod
  fill(18,16, 61,22, 0x8B,0x4A,0x15)
  fill(19,17, 60,21, 0xA0,0x60,0x20)
  -- Scroll bottom rod
  fill(18,57, 61,63, 0x8B,0x4A,0x15)
  fill(19,58, 60,62, 0xA0,0x60,0x20)
  -- Scroll end caps (circles)
  circle_fill(18,19,5, 0x6B,0x38,0x0F)
  circle_fill(61,19,5, 0x6B,0x38,0x0F)
  circle_fill(18,60,5, 0x6B,0x38,0x0F)
  circle_fill(61,60,5, 0x6B,0x38,0x0F)
  -- Text lines on scroll
  for i=0,3 do
    hline(26,53, 28+i*8, 0x8B,0x6A,0x40)
  end
  -- Red seal mark
  fill(33,36, 46,48, 0x8B,0x10,0x10)
  fill(35,38, 44,46, 0xB0,0x18,0x18)
  -- Character on seal
  px(39,40, 0xFF,0xC0,0xC0); px(40,40, 0xFF,0xC0,0xC0)
  hline(37,42,41, 0xFF,0xA0,0xA0)
  px(39,42, 0xFF,0xC0,0xC0); px(40,42, 0xFF,0xC0,0xC0)
  px(39,43, 0xFF,0xA0,0xA0); px(40,43, 0xFF,0xA0,0xA0)
  -- Gold border
  hline(18,61,15, 0xC8,0x96,0x0C); hline(18,61,64, 0xC8,0x96,0x0C)
end)

print("All encounter icons created!")
