-- Panel Frame - Ancient Chinese (古風) dialog box / 320x200
-- Uses 9-slice-friendly design: thick ornate borders, plain center
local OUT = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/panel_frame.aseprite"
local PNG = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/panel_frame.png"
local W, H = 320, 200

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

-- === BACKGROUND: dark lacquer with subtle pattern ===
fill(0,0,W-1,H-1, 0x0D,0x08,0x04)

-- Subtle dot pattern inside
for y=8,H-9,8 do
  for x=8,W-9,8 do
    px(x,y, 0x18,0x10,0x06)
  end
end

-- === OUTER SHADOW (semi-transparent would need alpha, simulate with dark) ===
-- Edge darkening
for i=0,2 do
  local a = 0x0A + i*4
  hline(i,W-1-i,i, a,a,a)
  hline(i,W-1-i,H-1-i, a,a,a)
  vline(i,i,H-1-i, a,a,a)
  vline(W-1-i,i,H-1-i, a,a,a)
end

-- === OUTER FRAME: 4px thick gold ===
for i=0,3 do
  local r = 0x60 + i*0x20
  local g = 0x45 + i*0x18
  local b = 0x05
  if i==0 then r,g,b = 0xFF,0xD7,0x00 end  -- outermost = brightest
  if i==1 then r,g,b = 0xC8,0x96,0x0C end
  if i==2 then r,g,b = 0x7A,0x5A,0x0A end
  if i==3 then r,g,b = 0x3A,0x28,0x06 end
  hline(i,W-1-i,i,r,g,b); hline(i,W-1-i,H-1-i,r,g,b)
  vline(i,i,H-1-i,r,g,b); vline(W-1-i,i,H-1-i,r,g,b)
end

-- === INNER FRAME: double line (inset 8px from outer) ===
local INN = 8
hline(INN,W-1-INN,INN, 0xC8,0x96,0x0C)
hline(INN,W-1-INN,INN+1, 0x7A,0x5A,0x0A)
hline(INN,W-1-INN,H-1-INN, 0xC8,0x96,0x0C)
hline(INN,W-1-INN,H-2-INN, 0x7A,0x5A,0x0A)
vline(INN,INN,H-1-INN, 0xC8,0x96,0x0C)
vline(INN+1,INN,H-1-INN, 0x7A,0x5A,0x0A)
vline(W-1-INN,INN,H-1-INN, 0xC8,0x96,0x0C)
vline(W-2-INN,INN,H-1-INN, 0x7A,0x5A,0x0A)

-- === CORNER ORNAMENTS (8x8 flower pattern) ===
-- Each corner: square diamond with cross

local function corner_ornament(ox, oy, flip_x, flip_y)
  local dx = flip_x and -1 or 1
  local dy = flip_y and -1 or 1
  -- Outer square bracket
  for i=0,5 do px(ox+dx*i, oy, 0xFF,0xD7,0x00) end
  for i=0,5 do px(ox, oy+dy*i, 0xFF,0xD7,0x00) end
  -- Inner cross/diamond
  px(ox+dx*2, oy+dy*2, 0xFF,0xFF,0x80)
  px(ox+dx*3, oy+dy*2, 0xFF,0xD7,0x00)
  px(ox+dx*2, oy+dy*3, 0xFF,0xD7,0x00)
  px(ox+dx*4, oy+dy*2, 0xC8,0x96,0x0C)
  px(ox+dx*2, oy+dy*4, 0xC8,0x96,0x0C)
  -- Step marks
  px(ox+dx*6, oy+dy*1, 0xC8,0x96,0x0C)
  px(ox+dx*7, oy+dy*2, 0x7A,0x5A,0x0A)
  px(ox+dx*1, oy+dy*6, 0xC8,0x96,0x0C)
  px(ox+dx*2, oy+dy*7, 0x7A,0x5A,0x0A)
end

corner_ornament(5, 5, false, false)       -- top-left
corner_ornament(W-6, 5, true, false)     -- top-right
corner_ornament(5, H-6, false, true)     -- bottom-left
corner_ornament(W-6, H-6, true, true)   -- bottom-right

-- === EDGE DECORATIONS: small dividers at midpoints ===
-- Top mid
local MX = W//2
px(MX-2,1,0xFF,0xD7,0x00); px(MX-1,1,0xFF,0xFF,0x80); px(MX,1,0xFF,0xFF,0x80); px(MX+1,1,0xFF,0xD7,0x00)
px(MX-1,2,0xFF,0xD7,0x00); px(MX,2,0xFF,0xD7,0x00)
px(MX,3,0xC8,0x96,0x0C)
-- Bottom mid
px(MX-2,H-2,0xFF,0xD7,0x00); px(MX-1,H-2,0xFF,0xFF,0x80); px(MX,H-2,0xFF,0xFF,0x80); px(MX+1,H-2,0xFF,0xD7,0x00)
px(MX-1,H-3,0xFF,0xD7,0x00); px(MX,H-3,0xFF,0xD7,0x00)

-- === TITLE AREA: top section divider line (for title text) ===
local TY = 28
hline(INN+4,W-INN-5,TY, 0xC8,0x96,0x0C)
hline(INN+4,W-INN-5,TY+1, 0x3A,0x28,0x06)
-- Small diamond at mid of title divider
px(MX-1,TY, 0xFF,0xFF,0x80); px(MX,TY, 0xFF,0xFF,0x80)
px(MX,TY-1, 0xFF,0xD7,0x00); px(MX,TY+1, 0xFF,0xD7,0x00)

-- === SAVE ===
spr:saveAs(OUT)
spr:saveCopyAs(PNG)
