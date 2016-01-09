--[[
colorutils

a simple library with some useful functions for dealing with colors.
Shared by gfxbuffer and canvas, and possibly gml later?

--]]
local colorutils = {VERSION="1.0"}

function colorutils.convColor_hto8(hex)
  local r,g,b=bit32.rshift(hex,16),bit32.rshift(hex,8)%256,hex%256
  r=round(r*7/255)
  g=round(g*7/255)
  b=round(b*3/255)
  return r*32+g*4+b
end

function colorutils.convColor_8toh(c)
  local r,g,b=math.floor(c/32),math.floor(c/4)%8,c%4
  r=round(r*255/7)
  g=round(g*255/7)
  b=round(b*255/3)
  return r*65536+g*256+b
end

function colorutils.convColor_hto4(hex)
  local r,g,b=bit32.rshift(hex,16),bit32.rshift(hex,8)%256,hex%256
  r=round(r/255)
  g=round(g*3/255)
  b=round(b/255)
  return r*8+g*2+b
end

function colorutils.convColor_4toh(c)
  local r,g,b=math.floor(c/8),math.floor(c/2)%4,c%2
  r=r*0xff0000
  g=round(g*0xff/3)*256
  b=b*0x0000ff
  return r+g+b
end

function colorutils.convColor_hto1(hex)
  return hex<0 and 1 or 0
end

function colorutils.convColor_1toh(c)
  return c<0 and 0xffffff or 0
end

return colorutils