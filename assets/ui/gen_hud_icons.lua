-- HUD Icons: heart (HP), coin (gold), crown (phase/king), shield (territory)
-- Each 24x24 pixels

local BASE = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/"
local W, H = 24, 24

local function make_icon(name, draw_fn)
  local spr = Sprite(W, H)
  local img = spr.cels[1].image

  local function px(x,y,r,g,b,a)
    a=a or 255
    if x>=0 and x<W and y>=0 and y<H then img:putPixel(x,y,Color(r,g,b,a)) end
  end
  local function fill(x0,y0,x1,y1,r,g,b)
    for y=y0,y1 do for x=x0,x1 do px(x,y,r,g,b) end end
  end
  local function circle_fill(cx,cy,r,ro,go,bo)
    for y=-r,r do for x=-r,r do
      if x*x+y*y<=r*r then px(cx+x,cy+y,ro,go,bo) end
    end end
  end

  draw_fn(px, fill, circle_fill)

  spr:saveAs(BASE..name..".aseprite")
  spr:saveCopyAs(BASE..name..".png")
end

-- === HEART icon (HP) ===
make_icon("icon_heart", function(px,fill,cf)
  -- Two circles merged with triangle
  cf(8,9,5,  0xC0,0x20,0x20)
  cf(15,9,5, 0xC0,0x20,0x20)
  -- Triangle point bottom
  for i=0,7 do
    local w = 8-i
    for x=12-w,12+w do
      px(x, 14+i, 0xC0,0x20,0x20)
    end
  end
  -- Highlight
  px(7,7, 0xFF,0x80,0x80); px(8,6, 0xFF,0x80,0x80)
  px(14,7,0xFF,0x80,0x80); px(15,6,0xFF,0x80,0x80)
  -- Dark outline dots
  px(3,9, 0x60,0x08,0x08); px(20,9, 0x60,0x08,0x08); px(12,20, 0x60,0x08,0x08)
end)

-- === COIN icon (Gold) ===
make_icon("icon_coin", function(px,fill,cf)
  cf(12,12,9, 0xC8,0x96,0x0C)
  cf(12,12,7, 0xFF,0xD7,0x00)
  cf(12,12,5, 0xC8,0x96,0x0C)
  cf(12,12,3, 0xFF,0xFF,0x80)
  -- "金" mark simplified: cross
  for i=9,15 do px(12,i, 0x80,0x60,0x00) end
  for i=9,15 do px(i,12, 0x80,0x60,0x00) end
  -- Shine
  px(9,9, 0xFF,0xFF,0xC0)
end)

-- === CROWN icon (King Favor / Phase) ===
make_icon("icon_crown", function(px,fill,cf)
  -- Base band
  fill(3,16,20,19, 0xC8,0x96,0x0C)
  fill(4,17,19,18, 0xFF,0xD7,0x00)
  -- Three points
  -- Left point
  for i=0,6 do px(5+i, 15-i, 0xC8,0x96,0x0C) end
  for i=0,5 do px(5+i, 14-i, 0xFF,0xD7,0x00) end
  -- Center point (tallest)
  for i=0,8 do px(12, 14-i, 0xC8,0x96,0x0C) end
  for i=0,7 do px(11, 14-i, 0xFF,0xD7,0x00); px(13,14-i, 0xFF,0xD7,0x00) end
  -- Right point
  for i=0,6 do px(18-i, 15-i, 0xC8,0x96,0x0C) end
  for i=0,5 do px(18-i, 14-i, 0xFF,0xD7,0x00) end
  -- Gems on crown
  px(5,16, 0xFF,0x30,0x30); px(12,15, 0xFF,0xFF,0x40); px(18,16, 0xFF,0x30,0x30)
  -- Shine
  px(10,8, 0xFF,0xFF,0xC0)
end)

-- === SHIELD icon (Territories) ===
make_icon("icon_shield", function(px,fill,cf)
  -- Shield outline
  local pts = {
    {4,5},{5,4},{18,4},{19,5},
    {19,15},{12,20},{11,20},{4,15}
  }
  -- Fill shield
  for y=4,20 do
    local x0 = 4; local x1 = 19
    if y <= 15 then x0=4; x1=19
    elseif y<=17 then x0=5; x1=18
    elseif y<=18 then x0=7; x1=16
    elseif y<=19 then x0=9; x1=14
    else x0=11; x1=12 end
    for x=x0,x1 do px(x,y, 0x1A,0x40,0x1A) end
  end
  -- Border
  for y=4,15 do px(4,y, 0xC8,0x96,0x0C); px(19,y, 0xC8,0x96,0x0C) end
  for x=4,19 do px(x,4, 0xC8,0x96,0x0C) end
  for i=0,5 do
    px(4+i,16+i, 0xC8,0x96,0x0C)
    px(19-i,16+i, 0xC8,0x96,0x0C)
  end
  -- Cross on shield
  for i=7,16 do px(12,i, 0xFF,0xD7,0x00) end
  for i=8,16 do px(i,11, 0xFF,0xD7,0x00) end
  -- Shine
  px(7,7, 0x80,0xFF,0x80)
end)

print("All HUD icons created!")
