-- Victory and Defeat banners - 320x64 each

local BASE = "D:/Code/SourceCode/GameDev/8x-8/assets/ui/"

local function make_banner(name, label_top, label_bot, bg_r,bg_g,bg_b, accent_r,accent_g,accent_b)
  local W, H = 320, 64
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

  -- Background
  fill(0,0,W-1,H-1, bg_r,bg_g,bg_b)

  -- Diagonal stripe pattern (subtle)
  for i=0,W+H do
    if i%8 < 2 then
      for j=0,H-1 do
        local x=i-j
        if x>=0 and x<W then
          local r2=math.min(bg_r+8,255); local g2=math.min(bg_g+5,255); local b2=math.min(bg_b+3,255)
          px(x,j,r2,g2,b2)
        end
      end
    end
  end

  -- Outer border: gold 2px
  hline(0,W-1,0, 0xC8,0x96,0x0C); hline(0,W-1,1, 0xFF,0xD7,0x00)
  hline(0,W-1,H-1, 0xC8,0x96,0x0C); hline(0,W-1,H-2, 0xFF,0xD7,0x00)
  vline(0,0,H-1, 0xC8,0x96,0x0C); vline(1,0,H-1, 0xFF,0xD7,0x00)
  vline(W-1,0,H-1, 0xC8,0x96,0x0C); vline(W-2,0,H-1, 0xFF,0xD7,0x00)

  -- Corner ornaments
  local function corner(ox,oy,dx,dy)
    for i=0,6 do px(ox+dx*i,oy, 0xFF,0xD7,0x00) end
    for i=0,6 do px(ox,oy+dy*i, 0xFF,0xD7,0x00) end
    px(ox+dx*2,oy+dy*2, 0xFF,0xFF,0x80)
    px(ox+dx*3,oy+dy*3, accent_r,accent_g,accent_b)
  end
  corner(3,3,1,1); corner(W-4,3,-1,1); corner(3,H-4,1,-1); corner(W-4,H-4,-1,-1)

  -- Accent color mid-line
  hline(8,W-9,H//2, accent_r,accent_g,accent_b)
  -- Bright highlight on mid line
  for x=8,W-9 do
    if x%(W//8)==0 then px(x,H//2, 0xFF,0xFF,0x80) end
  end

  -- Pixel text using block letters (simplified 5x7 font, scaled 3x)
  -- Draw label using dot-matrix style
  local function draw_char(cx, cy, pattern, r,g,b)
    for row,line in ipairs(pattern) do
      for col=1,#line do
        if line:sub(col,col)=="1" then
          for dy=0,2 do for dx=0,2 do
            px(cx+(col-1)*4+dx, cy+(row-1)*4+dy, r,g,b)
          end end
          px(cx+(col-1)*4, cy+(row-1)*4, 0xFF,0xFF,0x80)  -- highlight corner
        end
      end
    end
  end

  -- label_top: e.g. "VICTORY" or "DEFEAT" - just draw accent bar
  -- (Full font rendering is complex, use decorative approach)
  -- Top text area: decorative crosshatch suggesting writing
  local tx = 40
  for ci=0,#label_top-1 do
    local cx = tx + ci*28
    -- Draw a vertical stroke (simple character-like mark)
    vline(cx+5,8,30, accent_r,accent_g,accent_b)
    vline(cx+6,8,30, math.min(accent_r+40,255),math.min(accent_g+20,255),accent_b)
    hline(cx+2,cx+9,8, accent_r,accent_g,accent_b)
    hline(cx+3,cx+8,9, math.min(accent_r+40,255),math.min(accent_g+20,255),accent_b)
    if ci%2==0 then
      hline(cx+2,cx+9,19, accent_r,accent_g,accent_b)
    end
    hline(cx+2,cx+9,29, accent_r,accent_g,accent_b)
    hline(cx+3,cx+8,30, math.min(accent_r+40,255),math.min(accent_g+20,255),accent_b)
  end

  -- Bottom decorative bar with dots
  local by = H-10
  for i=0,12 do
    local bx = 20+i*24
    px(bx,by, 0xFF,0xD7,0x00); px(bx+1,by, 0xC8,0x96,0x0C)
    if i%3==0 then
      px(bx,by-2, 0xFF,0xD7,0x00); px(bx,by+1, 0xC8,0x96,0x0C)
    end
  end

  -- Mid ornament
  local MX = W//2
  px(MX-1,H//2-3,0xFF,0xFF,0x80); px(MX,H//2-3,0xFF,0xFF,0x80)
  px(MX,H//2-2,0xFF,0xD7,0x00)
  px(MX-1,H//2,accent_r,accent_g,accent_b); px(MX,H//2,accent_r,accent_g,accent_b)
  px(MX,H//2+2,0xFF,0xD7,0x00)
  px(MX-1,H//2+3,0xFF,0xFF,0x80); px(MX,H//2+3,0xFF,0xFF,0x80)

  spr:saveAs(BASE..name..".aseprite")
  spr:saveCopyAs(BASE..name..".png")
end

-- Victory: gold/green tones
make_banner("victory_banner", "VICTORY", "TRIUMPH", 0x08,0x18,0x08, 0xFF,0xD7,0x00)

-- Defeat: red/dark tones
make_banner("defeat_banner", "DEFEAT", "FALLEN", 0x18,0x04,0x04, 0xFF,0x40,0x40)

print("Banners created!")
