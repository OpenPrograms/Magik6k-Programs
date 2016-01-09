local component=require("component")
local unicode=require("unicode")
local len = unicode.len

local buffer={VERSION="1.0"}
local bufferMeta={}

local debugPrint=function() end


local function convColor_8toh(hex)
  local r,g,b=bit32.rshift(hex,16),bit32.rshift(hex,8)%256,hex%256
  r=round(r*7/255)
  g=round(g*7/255)
  b=round(b*3/255)
  return r*32+g*4+b
end

local function encodeColor(fg,bg)
  return bg*0x1000000+fg
end

local function decodeColor(c)
  return math.floor(c/0x1000000),c%0x1000000
end



function bufferMeta.getBackground(buffer)
  return convColor_8toh(buffer.colorBackground)
end

function bufferMeta.setBackground(buffer,color)
  local p=buffer.colorBackground
  buffer.colorBackground=color
  buffer.color=encodeColor(buffer.colorForeground,color)
  return p
end

function bufferMeta.getForeground(buffer)
  return buffer.colorForeground
end

function bufferMeta.setForeground(buffer,color)
  local p=buffer.colorForeground
  buffer.colorForeground=color
  buffer.color=encodeColor(color,buffer.colorBackground)
  return p
end


function bufferMeta.copy(buffer,x,y,w,h,dx,dy)
  buffer.flush()
  return buffer.parent.copy(x,y,w,h,dx,dy)
end

function bufferMeta.fill(buffer,x,y,w,h,char)
  buffer.flush()
  buffer.parent.setForeground(buffer.colorForeground)
  buffer.parent.setBackground(buffer.colorBackground)
  return buffer.parent.fill(x,y,w,h,char)
end

function bufferMeta.get(buffer,x,y)
  buffer.flush()
  return buffer.parent.get(x,y)
end

function bufferMeta.set(buffer,x,y,str)
  local spans=buffer.spans

  local spanI=1
  local color=buffer.color
  local e=x+len(str)-1

  while spans[spanI] and (spans[spanI].y<y or spans[spanI].y==y and spans[spanI].e<x) do
    spanI=spanI+1
  end
  --ok, now spanI is either intersecting me or the first after me
  --if intersect, crop

  if not spans[spanI] then
    debugPrint("just inserting at "..spanI)
    local span={str=str,e=e,x=x,y=y,color=color}
    spans[spanI]=span
  else
    local span=spans[spanI]
    debugPrint("scanned to span "..spanI)
    if span.y==y and span.x<e then
      debugPrint("it starts before I end.")
      --it starts before me. Can I merge with it?
      if span.color==color then
        --we can merge. Yay.
        --splice myself in
        debugPrint("splicing at "..math.max(0,(x-span.x)))
        local a,c=unicode.sub(span.str,1,math.max(0,x-span.x)), unicode.sub(span.str,e-span.x+2)
        debugPrint("before=\""..a.."\", after=\""..c..'"')
        span.str=a..str..c
        --correct x and e(nd)
        if x<span.x then
          span.x=x
        end
        if e > span.e then
          span.e=e
        end
      else
        --can't, gonna have to make a new span
        --but first, split this guy as needed
        debugPrint("can't merge. Splitting")
        local a,b=unicode.sub(span.str,1,math.max(0,x-span.x)),unicode.sub(span.str,e-span.x+2)
        if len(a)>0 then
          span.str=a
          span.e=span.x+len(a)
          --span is a new span
          span={str=true,e=true,x=true,y=y,color=span.color}
          --insert after this span
          spanI=spanI+1
          table.insert(spans,spanI,span)
        end
        if len(b)>0 then
          span.str=b
          span.x=e+1
          span.e=span.x+len(b)

          --and another new span
          span={str=true,e=true,x=true,y=y,color=color}
          --insert /before/ this one
          table.insert(spans,spanI,span)
        end
        --now make whatever span we're left with me.
        span.color=color
        span.x, span.e = x, e
        span.str=str
        span.y=y
      end
    else
      --starts after me. just insert.
      local span={x=x,e=e,y=y,color=color,str=str}
      table.insert(spans,spanI,span)
    end
    --ok. We are span. We are at spanI. We've inserted ourselves. Now just check if we've obliterated anyone.
    --while the next span starts before I end...
    spanI=spanI+1
    while spans[spanI] and spans[spanI].y==y and spans[spanI].x<=e do
      local span=spans[spanI]
      if span.e>e then
        --it goes past me, we just circumcise it
        span.str=unicode.sub(span.str,e-span.x+2)
        span.x=e+1
        break--and there can't be more
      end
      --doesn't end after us, means we obliterated it
      table.remove(spans,spanI)
      --spanI will now point to the next, if any
    end
  end

  --[[this..won't work. Was forgetting I have a table per row, this would count rows.
  if #spans>=buffer.autoFlushCount then
    buffer.flush()
  end
  --]]
end


function bufferMeta.flush(buffer)
  debugPrint("flush?")
  if #buffer.spans==0 then
    return
  end

  --sort by colors. bg is added as high value, so this will group all with common bg together,
  --and all with common fg together within same bg.
  table.sort(buffer.spans,
      function(spanA,spanB)
        if spanA.color==spanB.color then
          if spanA.y==spanB.y then
            return spanA.x<spanB.x
          end
          return spanA.y<spanB.y
        end
        return spanA.color<spanB.color
      end )

  --now draw the spans!
  local parent=buffer.parent
  local cfg,cbg=pfg,pbg
  local spans=buffer.spans

  for i=1,#spans do
    local span=spans[i]
    local bg,fg=decodeColor(span.color)
    if fg~=cfg then
      parent.setForeground(fg)
      cfg=fg
    end
    if bg~=cbg then
      parent.setBackground(bg)
      cbg=bg
    end
    parent.set(span.x,span.y,span.str)
  end
  if cfg~=buffer.colorForeground then
    parent.setForeground(buffer.colorForeground)
  end
  if cbg~=buffer.colorBackground then
    parent.setBackground(buffer.colorBackground)
  end
  --...and that's that. Throw away our spans.
  buffer.spans={}
  --might have to experiment later, see if the cost of rebuilding (and re-growing) the table is offset
  --by the savings of not having the underlying spans object grow based on peak buffer usage,
  --but if I'm optimizing for memory (and I am, in this case), then this seems a safe call for now.
  --If it ends up an issue, might be able to offset the computational cost by initing to an array of some average size, then
  --niling the elements in a loop.

end

function buffer.create(parent)
  parent=parent or component.gpu
  local width,height=parent.getResolution()

  local newBuffer={
      colorForeground=0xffffff,
      colorBackground=0x000000,
      color=0x00ff,
      width=width,
      height=height,
      parent=parent,
      spans={},
      autoFlushCount=32,
      getResolution=parent.getResolution,
      setResolution=parent.setResolution,
      maxResolution=parent.maxResolution,
      getDepth=parent.getDepth,
      setDepth=parent.setDepth,
      maxDepth=parent.maxDepth,
      getSize=parent.getSize,
    }

  setmetatable(newBuffer,{__index=function(tbl,key) local v=bufferMeta[key] if type(v)=="function" then return function(...) return v(tbl,...) end end return v end})

  return newBuffer
end


return buffer
