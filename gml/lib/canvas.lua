--[[

canvas library

creates canvas objects, which can be used interchangably with the gpu for drawing.
Store both the totall buffer and the set of differences since last presented to their
parents, and do sorting and grouping to optimally draw those buffers up to their parents.

--]]
local component=require("component")
local colorutils=require("colorutils")

--copy these to file local, they're called a lot in performance-intensive loops
local convColor_hto8=colorutils.convColor_hto8
local convColor_hto4=colorutils.convColor_hto4
local convColor_hto1=colorutils.convColor_hto1
local convColor_8toh=colorutils.convColor_8toh
local convColor_4toh=colorutils.convColor_4toh
local convColor_1toh=colorutils.convColor_1toh

local canvas={VERSION="1.0"}
local canvasMeta={}

local function round(x)
  return math.floor(x+.5)
end



local function canvas_initBuffer(canvas)
  local color="2 "
  if canvas.depth==8 then
    color="FF00 "
  elseif canvas.depth==4 then
    color="F0 "
  end

  canvas.buffer=color:rep(canvas.width*canvas.height)
end

local function canvas_posToIndex8(canvas,x,y)
  return (x-1+(y-1)*canvas.width)*5+1
end

local function canvas_posToIndex4(canvas,x,y)
  return (x-1+(y-1)*canvas.width)*3+1
end

local function canvas_posToIndex1(canvas,x,y)
  return (x-1+(y-1)*canvas.width)*2+1
end

local function colorToStr8(fg,bg)
  return string.format("%02x%02x",convColor_hto8(fg),convColor_hto8(bg))
end

local function colorToStr4(fg,bg)
  return string.format("%x%x",convColor_hto8(fg),convColor_hto8(bg))
end

local function colorToStr1(fg,bg)
  return convColor_hto8(fg)..convColor_hto8(bg)
end

function canvasMeta.strToSpan(canvas,string)
  local color=canvas.colorStr
  local outStr=""
  for ch in string:gmatch(".") do
    outStr=outStr..color..ch
  end
  return outStr
end

function canvasMeta.getResolution(canvas)
  return canvas.width, canvas.height
end

function canvasMeta.setResolution(canvas,width,height)
  assert(width==canvas.width and height==canvas.height,
      "unsupported resolution - canvases are not resizable")

  return false
end

function canvasMeta.maxResolution(canvas)
  return canvas.width,canvas.height
end

function canvasMeta.getDepth(canvas)
  return canvas.depth
end

function canvasMeta.setDepth(canvas)
  assert(depth==canvas.depth,
      "unsupported depth - canvas depth cannot be changed")

  return false
end

function canvasMeta.maxDepth(canvas)
  return canvas.depth
end

function canvasMeta.getSize(canvas)
  return 1,1
end

function canvasMeta.getBackground(canvas)
  return canvas.colorBackground
end

function canvasMeta.setBackground(canvas,color)
  local p=canvas.colorBackground
  canvas.colorBackground=color
  canvas.colorStr=canvas.colorToStr(canvas.colorForeground,canvas.colorBackground)
  return p
end

function canvasMeta.getForeground(canvas)
  return canvas.colorForeground
end

function canvasMeta.setForeground(canvas,color)
  local p=canvas.colorForeground
  canvas.colorForeground=color
  canvas.colorStr=canvas.colorToStr(canvas.colorForeground,canvas.colorBackground)
  return p
end

function canvasMeta.set(canvas,x,y,string)
  local index=canvas.posToIndex(x,y)
  local span=canvas.strToSpan(string)
  canvas.buffer=canvas.buffer:sub(1,index-1)..span..canvas.buffer:sub(index+#span)
end

local function canvas_get8(canvas,x,y)
  local index=canvas_posToIndex8(canvas,x,y)
  local pixel=canvas.buffer:sub(index,index+4)
  local fg,bg,ch=pixel:match("(%x%x)(%x%x)(.)")
  if not fg or not bg or not ch then
    error("err in canvas_get8, x="..x..", y="..y..", pixel=\""..pixel..'"')
  end
  return ch,convColor_8toh(tonumber(fg,16)),convColor_8toh(tonumber(bg,16))
end

local function canvas_get4(canvas,x,y)
  local index=canvas_posToIndex4(canvas,x,y)
  local pixel=canvas.buffer:sub(index,index+2)
  local fg,bg,ch=pixel:match("(%x)(%x)(.)")
  return ch,convColor_4toh(tonumber(fg,16)),convColor_4toh(tonumber(bg,16))
end

local function canvas_get1(canvas,x,y)
  local index=canvas_posToIndex1(canvas,x,y)
  local pixel=canvas.buffer:sub(index,index+2)
  local color,ch=pixel:match("(%x)(.)")
  return ch,color>1 and 0xffffff or 0, color%1==1 and 0xffffff or 0
end

function canvasMeta.copy(canvas,x,y,w,h,dx,dy)
  local sx,ex,xstep=x,x+w-1,1
  local sy,ey,ystep=y,y+h-1,1
  local pixelw=canvas.depth==8 and 5 or canvas.depth==4 and 3 or 2
  local function constrain(i,l,m,d)
    if i+l-1>m then
      l=m-l+1
    end
    if i+d+l-1>m then
      l=m-d-l+1
    end
    if i+d<1 then
      local t=1-d-i
      i=i+t
      l=l-t
    end
    return x,l
  end
  x,w=constrain(x,w,canvas.width,dx)
  y,h=constrain(y,h,canvas.height,dy)

  if dy>0 then
    sy,ey=ey,sy
    ystep=-1
  end

  print("sy="..sy..", ey="..ey..", sx="..sx..", ex="..ex)
  for y=sy,ey,ystep do
    --pull the whole substring for this row
    local si, ei=canvas.posToIndex(sx,y), canvas.posToIndex(ex,y)+pixelw-1
    local str=canvas.buffer:sub(si,ei)
    print("row "..y.." segment len : "..#str)
    si,ei=canvas.posToIndex(sx+dx,y+dy),canvas.posToIndex(ex+dx,y+dy)+pixelw-1
    canvas.buffer=canvas.buffer:sub(1,si-1)..str..canvas.buffer:sub(ei+1)
  end


end

function canvasMeta.fill(canvas,x,y,w,h,char)
  local line=(canvas.colorStr..char):rep(w)
  local lineLen=#line
  local xoff=(x-1)*(#canvas.colorStr+1)+1
  local yoffstep=canvas.width*(#canvas.colorStr+1)
  local yoff=(y-1)*yoffstep
  for y=y, y+h-1 do
    canvas.buffer=canvas.buffer:sub(1,xoff+yoff-1)..line..canvas.buffer:sub(xoff+yoff+lineLen)
    yoff=yoff+yoffstep
  end
end

function canvasMeta.draw(canvas,targX,targY)
  --TODO: make better. This is a quick'n'dirty to test the rest.
  local parent=canvas.parent
  local pfg,pbg=parent.getForeground(), parent.getBackground()
  for y=1,canvas.height do
    local str,cfg,cbg=canvas.get(1,y)
    local sx=1

    for x=2,canvas.width do
      local ch,fg,bg=canvas.get(x,y)
      if fg==cfg and bg==cbg then
        str=str..ch
      else
        parent.setForeground(cfg)
        parent.setBackground(cbg)
        parent.set(sx+targX-1,y+targY-1,str)
        str,cfg,cbg,sx=ch,fg,bg,x
      end
    end
    parent.setForeground(cfg)
    parent.setBackground(cbg)
    parent.set(sx+targX-1,y+targY-1,str)
  end

  parent.setForeground(pfg)
  parent.setBackground(pbg)

end


function canvas.create(width,height,depth,parent)
  parent=parent or component.gpu
  if width==nil then
    width,height=parent.getResolution()
  elseif height==nil then
    _,height=parent.getResolution()
  end

  depth=depth or parent.getDepth()

  local posToIndex=depth==8 and canvas_posToIndex8 or (depth==4 and canvas_posToIndex4 or canvas_posToIndex1)
  local get=depth==8 and canvas_get8 or (depth==4 and canvas_get4 or canvas_get1)

  local newCanvas={
      colorForeground=0xffffff,
      colorBackground=0x000000,
      depth=depth,
      width=width,
      height=height,
      parent=parent,
    }


  --wrap suitable bit version
  newCanvas.posToIndex=function(...)  return posToIndex(newCanvas,...) end
  newCanvas.get=function(...) return get(newCanvas,...) end
  --no canvas arg required, just pick the suitable one
  newCanvas.colorToStr=depth==8 and colorToStr8 or (depth==4 and colorToStr4 or colorToStr1)

  canvas_initBuffer(newCanvas)

  setmetatable(newCanvas,{__index=function(tbl,key) local v=canvasMeta[key] if type(v)=="function" then return function(...) return v(tbl,...) end end return v end})

  newCanvas.colorStr=newCanvas.colorToStr(0xffffff,0x000000)

  return newCanvas
end

return canvas