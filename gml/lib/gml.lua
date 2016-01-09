--[[*********************************************

gui library

by GopherAtl

do whatever you want, just don't be a dick. Give
me credit whenever you redistribute, modified or
otherwise.

For the latest updates and documentations, check
out the github repo and it's wiki at
https://github.com/OpenPrograms/Gopher-Programs

*************************************************
Edited by Krutoy242
Added unicode, color fixes and syntax improvments
--***********************************************]]

local event=require("event")
local component=require("component")
local term=require("term")
local computer=require("computer")
local shell=require("shell")
local filesystem=require("filesystem")
local keyboard=require("keyboard")
local unicode=require("unicode")
local gfxbuffer=require("gfxbuffer")
local process = require("process")

local len = unicode.len

local doubleClickThreshold=.25

local gml={VERSION="1.0"}

local defaultStyle=nil

--clipboard is global between guis and gui sessions, as long as you don't reboot.
local clipboard=nil

local validElements = {
  ["*"]=true,
  gui=true,       --top gui container
  label=true,     --text labels, non-focusable (naturally), non-readable
  button=true,    --buttons, text label, clickable
  textfield=true, --single-line text input, can scroll left-right, never has scrollbar, just scrolls with cursor
  scrollbar=true, --scroll bar, scrolls. Can be horizontal or vertical.
  textbox=true,   --multi-line text input, line wraps, scrolls up-down, has scroll bar if needed
  listbox=true,   --list, vertical stack of labels with a scrollbar
}

local validStates = {
  ["*"]=true,
  enabled=true,
  disabled=true,
  checked=true,
  focus=true,
  empty=true,
  selected=true,
}

local validDepths = {
  ["*"]=true,
  [1]=true,
  [4]=true,
  [8]=true,
}

local screen = {
      posX=1, posY=1,
      bodyX=1,bodyY=1,
      hidden=false,
      isHidden=function() return false end,
      renderTarget=component.gpu
    }

screen.width,screen.height=component.gpu.getResolution()
screen.bodyW,screen.bodyH=screen.width,screen.height

--**********************
--utility functions

function round(v)
  return math.floor(v+.5)
end


--**********************
--api functions

function gml.loadStyle(name)
  --search for file
  local fullname=name
  if name:match(".gss$") then
    name=name:match("^(.*)%.gss$")
  else
    fullname=name..".gss"
  end

  local filepath

  --search for styles in working directory, running program directory, /lib /usr/lib. Just because.
  local dirs={shell.getWorkingDirectory(),process.running():match("^(.*/).+$"), "/lib/", "/usr/lib/"}
  if dirs[1]~="/" then
    dirs[1]=dirs[1].."/"
  end
  for i=1,#dirs do
    if filesystem.exists(dirs[i]..fullname) and not filesystem.isDirectory(dirs[i]..fullname) then
      filepath=dirs[i]..fullname
      break
    end
  end

  if not filepath then
    error("Could not find gui stylesheet \""..name.."\"",2)
  end

  --found it, open and parse
  local file=assert(io.open(filepath,"r"))

  local text=file:read("*all")
  file:close()
  text=text:gsub("/%*.-%*/",""):gsub("\r\n","\n")

  local styleTree={}

  --util method used in loop later when building styleTree
  local function descend(node,to)
    if node[to]==nil then
      node[to]={}
    end
    return node[to]
  end


  for selectorStr, body in text:gmatch("%s*([^{]*)%s*{([^}]*)}") do
    --parse the selectors!
    local selectors={}
    for element in selectorStr:gmatch("([^,^%s]+)") do
      --could have a !depth modifier
      local depth,state,class, temp
      temp,depth=element:match("(%S+)!(%S+)")
      element=temp or element
      temp,state=element:match("(%S+):(%S+)")
      element=temp or element
      temp,class=element:match("(%S+)%.(%S+)")
      element=temp or element
      if element and validElements[element]==nil then
        error("Encountered invalid element "..element.." loading style "..name)
      end
      if state and validStates[state]==nil then
        error("Encountered invalid state "..state.." loading style "..name)
      end
      if depth and validDepths[tonumber(depth)]==nil then
        error("Encountered invalid depth "..depth.." loading style "..name)
      end

      selectors[#selectors+1]={element=element or "*",depth=tonumber(depth) or "*",state=state or "*",class=class or "*"}
    end

    local props={}
    for prop,val in body:gmatch("(%S*)%s*:%s*(.-);") do
      if tonumber(val) then
        val=tonumber(val)
      elseif val:match("U%+%x+") then
        val=unicode.char(tonumber("0x"..val:match("U%+(.*)")))
      elseif val:match("^%s*[tT][rR][uU][eE]%s*$") then
        val=true
      elseif val:match("^%s*[fF][aA][lL][sS][eE]%s*$") then
        val=false
      elseif val:match("%s*(['\"]).*(%1)%s*") then
        _,val=val:match("%s*(['\"])(.*)%1%s*")
      else
        error("invalid property value '"..val.."'!")
      end

      props[prop]=val
    end

    for i=1,#selectors do
      local sel=selectors[i]
      local node=styleTree


      node=descend(node,sel.depth)
      node=descend(node,sel.state)
      node=descend(node,sel.class)
      node=descend(node,sel.element)
      --much as I'd like to save mem, dupe selectors cause merges, which, if
      --instances are duplicated in the final style tree, could result in spraying
      --props in inappropriate places
      for k,v in pairs(props) do
        node[k]=v
      end
    end

  end

  return styleTree
end


--**********************
--internal style-related utility functions

local function tableCopy(t1)
  local copy={}
  for k,v in pairs(t1) do
    if type(v)=="table" then
      copy[k]=tableCopy(v)
    else
      copy[j]=v
    end
  end
end

local function mergeStyles(t1, t2)
  for k,v in pairs(t2) do
    if t1[k]==nil then
      t1[k]=tableCopy(v)
    elseif type(t1[k])=="table" then
      if type(v)=="table" then
        tableMerge(t1[k],v)
      else
        error("inexplicable error in mergeStyles - malformed style table, attempt to merge "..type(v).." with "..type(t1[k]))
      end
    elseif type(v)=="table" then
      error("inexplicable error in mergeStyles - malformed style table, attempt to merge "..type(v).." with "..type(t1[k]))
    else
      t1[k]=v
    end
  end
end


function getAppliedStyles(element)
  local styleRoot=element.style
  assert(styleRoot)

  --descend, unless empty, then back up... so... wtf
  local depth,state,class,elementType=element.renderTarget.getDepth(),element.state or "*",element.class or "*", element.type

  local nodes={styleRoot}
  local function filterDown(nodes,key)
    local newNodes={}
    for i=1,#nodes do
      if key~="*" and nodes[i][key] then
        newNodes[#newNodes+1]=nodes[i][key]
      end
      if nodes[i]["*"] then
        newNodes[#newNodes+1]=nodes[i]["*"]
      end
    end
    return newNodes
  end
  nodes=filterDown(nodes,depth)
  nodes=filterDown(nodes,state)
  nodes=filterDown(nodes,class)
  nodes=filterDown(nodes,elementType)
  return nodes
end


function extractProperty(element,styles,property)
  if element[property] then
    return element[property]
  end
  for j=1,#styles do
    local v=styles[j][property]
    if v~=nil then
      return v
    end
  end
end

local function extractProperties(element,styles,...)
  local props={...}

  --nodes is now a list of all terminal branches that could possibly apply to me
  local vals={}
  for i=1,#props do
    vals[#vals+1]=extractProperty(element,styles,props[i])
    if #vals~=i then
      for k,v in pairs(styles[1]) do print('"'..k..'"',v,k==props[i] and "<-----!!!" or "") end
      error("Could not locate value for style property "..props[i].."!")
    end
  end
  return table.unpack(vals)
end

local function findStyleProperties(element,...)
  local props={...}
  local nodes=getAppliedStyles(element)
  return extractProperties(element,nodes,...)
end


--**********************
--drawing and related functions


local function parsePosition(x,y,width,height,maxWidth, maxHeight)

  width=math.min(width,maxWidth)
  height=math.min(height,maxHeight)

  if x=="left" then
    x=1
  elseif x=="right" then
    x=maxWidth-width+1
  elseif x=="center" then
    x=math.max(1,math.floor((maxWidth-width)/2))
  elseif x<0 then
    x=maxWidth-width+2+x
  elseif x<1 then
    x=1
  elseif x+width-1>maxWidth then
    x=maxWidth-width+1
  end

  if y=="top" then
    y=1
  elseif y=="bottom" then
    y=maxHeight-height+1
  elseif y=="center" then
    y=math.max(1,math.floor((maxHeight-height)/2))
  elseif y<0 then
    y=maxHeight-height+2+y
  elseif y<1 then
    y=1
  elseif y+height-1>maxHeight then
    y=maxHeight-height+1
  end

  return x,y,width,height
end

--draws a frame, based on the relevant style properties, and
--returns the effective client area inside the frame
local function drawBorder(element,styles)
  local screenX,screenY=element:getScreenPosition()

  local borderFG, borderBG,
        border,borderLeft,borderRight,borderTop,borderBottom,
        borderChL,borderChR,borderChT,borderChB,
        borderChTL,borderChTR,borderChBL,borderChBR =
      extractProperties(element,styles,
        "border-color-fg","border-color-bg",
        "border","border-left","border-right","border-top","border-bottom",
        "border-ch-left","border-ch-right","border-ch-top","border-ch-bottom",
        "border-ch-topleft","border-ch-topright","border-ch-bottomleft","border-ch-bottomright")

  local width,height=element.width,element.height

  local bodyX,bodyY=screenX,screenY
  local bodyW,bodyH=width,height

  local gpu=element.renderTarget

  if border then
    gpu.setBackground(borderBG)
    gpu.setForeground(borderFG)

    --as needed, leave off top and bottom borders if height doesn't permit them
    if borderTop and bodyW>1 then
      bodyY=bodyY+1
      bodyH=bodyH-1
      --do the top bits
      local str=(borderLeft and borderChTL or borderChT)..borderChT:rep(bodyW-2)..(borderRight and borderChTR or borderChB)
      gpu.set(screenX,screenY,str)
    end
    if borderBottom and bodyW>1 then
      bodyH=bodyH-1
      --do the top bits
      local str=(borderLeft and borderChBL or borderChB)..borderChB:rep(bodyW-2)..(borderRight and borderChBR or borderChB)
      gpu.set(screenX,screenY+height-1,str)
    end
    if borderLeft then
      bodyX=bodyX+1
      bodyW=bodyW-1
      for y=bodyY,bodyY+bodyH-1 do
        gpu.set(screenX,y,borderChL)
      end
    end
    if borderRight then
      bodyW=bodyW-1
      for y=bodyY,bodyY+bodyH-1 do
        gpu.set(screenX+width-1,y,borderChR)
      end
    end
  end

  return bodyX,bodyY,bodyW,bodyH
end

--calculates the body coords of an element based on it's true coords
--and border style properties
local function calcBody(element)
  local x,y,w,h=element.posX,element.posY,element.width,element.height
  local border,borderTop,borderBottom,borderLeft,borderRight =
     findStyleProperties(element,"border","border-top","border-bottom","border-left","border-right")

  if border then
    if borderTop then
      y=y+1
      h=h-1
    end
    if borderBottom then
      h=h-1
    end
    if borderLeft then
      x=x+1
      w=w-1
    end
    if borderRight then
      w=w-1
    end
  end
  return x,y,w,h
end

local function correctForBorder(element,px,py)
  px=px-(element.bodyX and element.bodyX-element.posX or 0)
  py=py-(element.bodyY and element.bodyY-element.posY or 0)
  return px,py
end

local function frameAndSave(element)
  local t={}
  local x,y,width,height=element.posX,element.posY,element.width,element.height

  local pcb=term.getCursorBlink()
  local curx,cury=term.getCursor()
  local pfg,pbg=element.renderTarget.getForeground(),element.renderTarget.getBackground()
  local rtg=element.renderTarget.get
  --preserve background
  for ly=1,height do
    t[ly]={}
    local str, cfg, cbg=rtg(x,y+ly-1)
    for lx=2,width do
      local ch, fg, bg=rtg(x+lx-1,y+ly-1)
      if fg==cfg and bg==cbg then
        str=str..ch
      else
        t[ly][#t[ly]+1]={str,cfg,cbg}
        str,cfg,cbg=ch,fg,bg
      end
    end
    t[ly][#t[ly]+1]={str,cfg,cbg}
  end
  local styles=getAppliedStyles(element)

  local bodyX,bodyY,bodyW,bodyH=drawBorder(element,styles)

  local fillCh,fillFG,fillBG=extractProperties(element,styles,"fill-ch","fill-color-fg","fill-color-bg")

  local blankRow=fillCh:rep(bodyW)

  element.renderTarget.setForeground(fillFG)
  element.renderTarget.setBackground(fillBG)
  term.setCursorBlink(false)

  element.renderTarget.fill(bodyX,bodyY,bodyW,bodyH,fillCh)

  return {curx,cury,pcb,pfg,pbg, t}

end

local function restoreFrame(renderTarget,x,y,prevState)

  local curx,cury,pcb,pfg,pbg, behind=table.unpack(prevState)

  for ly=1,#behind do
    local lx=x
    for i=1,#behind[ly] do
      local str,fg,bg=table.unpack(behind[ly][i])
      renderTarget.setForeground(fg)
      renderTarget.setBackground(bg)
      renderTarget.set(lx,ly+y-1,str)
      lx=lx+len(str)
    end
  end


  term.setCursor(curx,cury)
  renderTarget.setForeground(pfg)
  renderTarget.setBackground(pbg)
  renderTarget.flush()

  term.setCursorBlink(pcb)

end

local function elementHide(element)
  if element.visible then
    element.visible=false
    element.gui:redrawRect(element.posX,element.posY,element.width,1)
  end
  element.hidden=true
end

local function elementShow(element)
  element.hidden=false
  if not element.visible then
    element:draw()
  end
end


local function drawLabel(label)
  if not label:isHidden() then
    local screenX,screenY=label:getScreenPosition()
    local fg, bg=findStyleProperties(label,"text-color","text-background")
    label.renderTarget.setForeground(fg)
    label.renderTarget.setBackground(bg)
    label.renderTarget.set(screenX,screenY, unicode.sub(label.text, 1,label.width) .. (" "):rep(label.width-len(label.text)))
    label.visible=true
  end
end



local function drawButton(button)
  if not button:isHidden() then
    local styles=getAppliedStyles(button)
    local gpu=button.renderTarget

    local fg,bg,
          fillFG,fillBG,fillCh=
      findStyleProperties(button,
        "text-color","text-background",
        "fill-color-fg","fill-color-bg","fill-ch")

    local bodyX,bodyY,bodyW,bodyH=drawBorder(button,styles)

    gpu.setBackground(fillBG)
    gpu.setForeground(fillFG)
    local bodyRow=fillCh:rep(bodyW)
    for i=1,bodyH do
      gpu.set(bodyX,bodyY+i-1,bodyRow)
    end

    --now center the label
    gpu.setBackground(bg)
    gpu.setForeground(fg)
    --calc position
    local text=button.text
    local textX=bodyX
    local textY=bodyY+math.floor((bodyH-1)/2)
    if len(text)>bodyW then
      text=unicode.sub(text, 1,bodyW)
    else
      textX=bodyX+math.floor((bodyW-len(text))/2)
    end
    gpu.set(textX,textY,text)
  end
end


local function drawTextField(tf)
  if not tf:isHidden() then
    local textFG,textBG,selectedFG,selectedBG=
        findStyleProperties(tf,"text-color","text-background","selected-color","selected-background")
    local screenX,screenY=tf:getScreenPosition()
    local gpu=tf.renderTarget

    --grab the subset of text visible
    local text=tf.text

    local visibleText=unicode.sub(text, tf.scrollIndex,tf.scrollIndex+tf.width-1)
    visibleText=visibleText..(" "):rep(tf.width-len(visibleText))
    --this may be split into as many as 3 parts - pre-selection, selection, and post-selection
    --if there is any selection at all...
    if tf.state=="focus" and not tf.dragging then
      term.setCursorBlink(false)
    end
    if tf.selectEnd~=0 then
      local visSelStart, visSelEnd, preSelText,selText,postSelText
      visSelStart=math.max(1,tf.selectStart-tf.scrollIndex+1)
      visSelEnd=math.min(tf.width,tf.selectEnd-tf.scrollIndex+1)

      selText=unicode.sub(visibleText, visSelStart,visSelEnd)

      if visSelStart>1 then
        preSelText=unicode.sub(visibleText, 1,visSelStart-1)
      end

      if visSelEnd<tf.width then
        postSelText=unicode.sub(visibleText, visSelEnd+1,tf.width)
      end

      gpu.setForeground(selectedFG)
      gpu.setBackground(selectedBG)
      gpu.set(screenX+visSelStart-1,screenY,selText)

      if preSelText or postSelText then
        gpu.setForeground(textFG)
        gpu.setBackground(textBG)
        if preSelText then
          gpu.set(screenX,screenY,preSelText)
        end
        if postSelText then
          gpu.set(screenX+visSelEnd,screenY,postSelText)
        end
      end
    else
      --no selection, just draw
      gpu.setForeground(textFG)
      gpu.setBackground(textBG)
      gpu.set(screenX,screenY,visibleText)
    end
    if tf.state=="focus" and not tf.dragging then
      term.setCursor(screenX+tf.cursorIndex-tf.scrollIndex,screenY)
      term.setCursorBlink(true)
    end
  end
end


local function drawScrollBarH(bar)
  if not bar:isHidden() then
    local leftCh,rightCh,btnFG,btnBG,
          barCh, barFG, barBG,
          gripCh, gripFG, gripBG =
      findStyleProperties(bar,
          "button-ch-left","button-ch-right","button-color-fg","button-color-bg",
          "bar-ch","bar-color-fg","bar-color-bg",
          "grip-ch-h","grip-color-fg","grip-color-bg")

    local gpu=bar.renderTarget
    local screenX,screenY=bar:getScreenPosition()

    local w,gs,ge=bar.width,bar.gripStart+screenX,bar.gripEnd+screenX
    --buttons
    gpu.setBackground(btnBG)
    gpu.setForeground(btnFG)
    gpu.set(screenX,screenY,leftCh)
    gpu.set(screenX+w-1,screenY,rightCh)

    --scroll area
    gpu.setBackground(barBG)
    gpu.setForeground(barFG)

    gpu.set(screenX+1,screenY,barCh:rep(w-2))

    --grip
    gpu.setBackground(gripBG)
    gpu.setForeground(gripFG)
    gpu.set(gs,screenY,gripCh:rep(ge-gs+1))
  end
end

local function drawScrollBarV(bar)
  if not bar:isHidden() then
    local upCh,dnCh,btnFG,btnBG,
          barCh, barFG, barBG,
          gripCh, gripFG, gripBG =
      findStyleProperties(bar,
          "button-ch-up","button-ch-down","button-color-fg","button-color-bg",
          "bar-ch","bar-color-fg","bar-color-bg",
          "grip-ch-v","grip-color-fg","grip-color-bg")

    local gpu=bar.renderTarget
    local screenX,screenY=bar:getScreenPosition()
    local h,gs,ge=bar.height,bar.gripStart+screenY,bar.gripEnd+screenY
    --buttons
    gpu.setBackground(btnBG)
    gpu.setForeground(btnFG)
    gpu.set(screenX,screenY,upCh)
    gpu.set(screenX,screenY+h-1,dnCh)

    --scroll area
    gpu.setBackground(barBG)
    gpu.setForeground(barFG)

    for screenY=screenY+1,gs-1 do
      gpu.set(screenX,screenY,barCh)
    end
    for screenY=ge+1,screenY+h-2 do
      gpu.set(screenX,screenY,barCh)
    end

    --grip
    gpu.setBackground(gripBG)
    gpu.setForeground(gripFG)
    for screenY=gs,ge do
      gpu.set(screenX,screenY,gripCh)
    end
  end
end


--**********************
--object creation functions and their utility functions

local function loadHandlers(gui)
  local handlers=gui.handlers
  for i=1,#handlers do
    event.listen(handlers[i][1],handlers[i][2])
  end
end

local function unloadHandlers(gui)
  local handlers=gui.handlers
  for i=1,#handlers do
    event.ignore(handlers[i][1],handlers[i][2])
  end
end

local function guiAddHandler(gui,eventType,func)
  checkArg(1,gui,"table")
  checkArg(2,eventType,"string")
  checkArg(3,func,"function")

  gui.handlers[#gui.handlers+1]={eventType,func}
  if gui.running then
    event.listen(eventType,func)
  end
end


local function cleanup(gui)
  --remove handlers
  unloadHandlers(gui)

  --hide gui, redraw beneath?
  if gui.prevTermState then
    restoreFrame(gui.renderTarget,gui.posX,gui.posY,gui.prevTermState)
    gui.prevTermState=nil
  end
end

local function contains(element,x,y)
  local ex,ey,ew,eh=element.posX,element.posY,element.width,element.height

  return x>=ex and x<=ex+ew-1 and y>=ey and y<=ey+eh-1
end

local function runGui(gui)
  gui.running=true
  --draw gui background, preserving underlying screen
  gui.prevTermState=frameAndSave(gui)
  gui.hidden=false

  --drawing components
  local firstFocusable, prevFocusable
  for i=1,#gui.components do
    if not gui.components[i].hidden then
      if gui.components[i].focusable and not gui.components[i].hidden then
        if firstFocusable==nil then
          firstFocusable=gui.components[i]
        else
          gui.components[i].tabPrev=prevFocusable
          prevFocusable.tabNext=gui.components[i]
        end
        prevFocusable=gui.components[i]
      end
      gui.components[i]:draw()
    end
  end
  if firstFocusable then
    firstFocusable.tabPrev=prevFocusable
    prevFocusable.tabNext=firstFocusable
    if not gui.focusElement and not gui.components[i].hidden then
      gui.focusElement=gui.components[i]
      gui.focusElement.state="focus"
    end
  end
  if gui.focusElement and gui.focusElement.gotFocus then
    gui.focusElement.gotFocus()
  end

  loadHandlers(gui)

  --run the gui's onRun, if any
  if gui.onRun then
    gui.onRun()
  end

  local function getComponentAt(tx,ty)
    for i=1,#gui.components do
      local c=gui.components[i]
      if not c:isHidden() and c:contains(tx,ty) then
        return c
      end
    end
  end

  local lastClickTime, lastClickPos, lastClickButton, dragButton, dragging=0,{0,0},nil,nil,false
  local draggingObj=nil

  while true do
    gui.renderTarget:flush()
    local e={event.pull()}
    if e[1]=="gui_close" then
      break
    elseif e[1]=="touch" then
      --figure out what was touched!
      local tx, ty, button=e[3],e[4],e[5]
      if gui:contains(tx,ty) then
        tx=tx-gui.bodyX+1
        ty=ty-gui.bodyY+1
        lastClickPos={tx,ty}
        local tickTime=computer.uptime()
        dragButton=button
        local target=getComponentAt(tx,ty)
        clickedOn=target
        if target then
          if target.focusable and target~=gui.focusElement then
            gui:changeFocusTo(clickedOn)
          end
          if lastClickPos[1]==tx and lastClickPos[2]==ty and lastClickButton==button and
              tickTime - lastClickTime<doubleClickThreshold then
            if target.onDoubleClick then
              target:onDoubleClick(tx-target.posX+1,ty-target.posY+1,button)
            end
          elseif target.onClick then
            target:onClick(tx-target.posX+1,ty-target.posY+1,button)
          end
        end
        lastClickTime=tickTime
        lastClickButton=button
      end
    elseif e[1]=="drag" then
      --if we didn't click /on/ something to start this drag, we do nada
      if clickedOn then
        local tx,ty=e[3],e[4]
        tx=tx-gui.bodyX+1
        ty=ty-gui.bodyY+1
        --is this is the beginning of a drag?
        if not dragging then
          if clickedOn.onBeginDrag then
            draggingObj=clickedOn:onBeginDrag(lastClickPos[1]-clickedOn.posX+1,lastClickPos[2]-clickedOn.posY+1,dragButton)
            dragging=true
          end
        end
        --now do the actual drag bit
        --draggingObj is for drag proxies, which are for drag and drop operations like moving files
        if draggingObj and draggingObj.onDrag then
          draggingObj:onDrag(tx,ty)
        end
        --
        if clickedOn and clickedOn.onDrag then
          tx,ty=tx-clickedOn.posX+1,ty-clickedOn.posY+1
          clickedOn:onDrag(tx,ty)
        end
      end
    elseif e[1]=="drop" then
      local tx,ty=e[3],e[4]
      tx=tx-gui.bodyX+1
      ty=ty-gui.bodyY+1
      if draggingObj and draggingObj.onDrop then
        local dropOver=getComponentAt(tx,ty)
        draggingObj:onDrop(tx,ty,dropOver)
      end
      if clickedOn and clickedOn.onDrop then
        tx,ty=tx-clickedOn.posX+1,ty-clickedOn.posY+1
        clickedOn:onDrop(tx,ty,dropOver)
      end
      draggingObj=nil
      dragging=false

    elseif e[1]=="key_down" then
      local char,code=e[3],e[4]
      --tab
      if code==15 and gui.focusElement then
        local newFocus=gui.focusElement
        if keyboard.isShiftDown() then
          repeat
            newFocus=newFocus.tabPrev
          until newFocus.hidden==false
        else
          repeat
            newFocus=newFocus.tabNext
          until newFocus.hidden==false
        end
        if newFocus~=gui.focusElement then
          gui:changeFocusTo(newFocus)
        end
      elseif char==3 then
        --copy!
        if gui.focusElement and gui.focusElement.doCopy then
          clipboard=gui.focusElement:doCopy() or clipboard
        end
      elseif char==22 then
        --paste!
        if gui.focusElement.doPaste and type(clipboard)=="string" then
          gui.focusElement:doPaste(clipboard)
        end
      elseif char==24 then
        --cut!
        if gui.focusElement.doCut then
          clipboard=gui.focusElement:doCut() or clipboard
        end
      elseif gui.focusElement and gui.focusElement.keyHandler then
        gui.focusElement:keyHandler(char,code)
      end

      if gui.focusElement and gui.focusElement.onKey then
        gui.focusElement.onKey(char,code)
      end
    end
  end

  running=false

  cleanup(gui)

  if gui.onExit then
    gui.onExit()
  end
end

local function baseComponent(gui,x,y,width,height,type,focusable)
  local c={
      visible=false,
      hidden=false,
      gui=gui,
      style=gui.style,
      focusable=focusable,
      type=type,
      renderTarget=gui.renderTarget,
    }

  c.isHidden=function(c)
     return c.hidden or c.gui:isHidden()
    end

  c.posX, c.posY, c.width, c.height =
    parsePosition(x, y, width, height, gui.bodyW, gui.bodyH)

  c.getScreenPosition=function(element)
      local e=element
      local x,y=e.posX,e.posY
      while e.gui and e.gui~=screen do
        e=e.gui
        x=x+e.bodyX-1
        y=y+e.bodyY-1
      end
      return x,y
    end

  c.hide=elementHide
  c.show=elementShow
  c.contains=contains

  return c
end


local function addLabel(gui,x,y,width,labelText)
  local label=baseComponent(gui,x,y,width,1,"label",false)

  label.text=labelText

  label.draw=drawLabel

  gui:addComponent(label)
  return label
end

local function addButton(gui,x,y,width,height,buttonText,onClick)
  local button=baseComponent(gui,x,y,width,height,"button",true)

  button.text=buttonText
  button.onClick=onClick

  button.draw=drawButton
  button.keyHandler=function(button,char,code)
      if code==28 then
         button:onClick(0,0,-1)
      end
    end
  gui:addComponent(button)
  return button
end

local function updateSelect(tf, prevCI )
  if tf.selectEnd==0 then
    --begin selecting
    tf.selectOrigin=prevCI
  end
  if tf.cursorIndex==tf.selectOrigin then
    tf.selectEnd=0
  elseif tf.cursorIndex>tf.selectOrigin then
    tf.selectStart=tf.selectOrigin
    tf.selectEnd=tf.cursorIndex-1
  else
    tf.selectStart=tf.cursorIndex
    tf.selectEnd=tf.selectOrigin-1
  end
end

local function removeSelectedTF(tf)
  tf.text=unicode.sub(tf.text, 1,tf.selectStart-1) .. unicode.sub(tf.text, tf.selectEnd+1)
  tf.cursorIndex=tf.selectStart
  tf.selectEnd=0
end

local function insertTextTF(tf,text)
  if tf.selectEnd~=0 then
    tf:removeSelected()
  end
  tf.text=unicode.sub(tf.text, 1,tf.cursorIndex-1)..text..unicode.sub(tf.text, tf.cursorIndex)
  tf.cursorIndex=tf.cursorIndex+len(text)
  if tf.cursorIndex-tf.scrollIndex+1>tf.width then
    local ts=tf.scrollIndex+math.floor(tf.width/3)
    if tf.cursorIndex-ts+1>tf.width then
      ts=tf.cursorIndex-tf.width+math.floor(tf.width/3)
    end
    tf.scrollIndex=ts
  end
end

local function addTextField(gui,x,y,width,text)
  local tf=baseComponent(gui,x,y,width,1,"textfield",true)

  tf.text=text or ""
  tf.cursorIndex=1
  tf.scrollIndex=1
  tf.selectStart=1
  tf.selectEnd=0
  tf.draw=drawTextField
  tf.insertText=insertTextTF
  tf.removeSelected=removeSelectedTF

  tf.doPaste=function(tf,text)
      tf:insertText(text)
      tf:draw()
    end
  tf.doCopy=function(tf)
      if tf.selectEnd~=0 then
        return unicode.sub(tf.text, tf.selectStart,tf.selectEnd)
      end
      return nil
    end
  tf.doCut=function(tf)
      local text=tf:doCopy()
      tf:removeSelected()
      tf:draw()
      return text
    end

  tf.onClick=function(tf,tx,ty,button)
      tf.selectEnd=0
      tf.cursorIndex=math.min(tx+tf.scrollIndex-1,len(tf.text)+1)
      tf:draw()
    end

  tf.onBeginDrag=function(tf,tx,ty,button)
      --drag events are in gui coords, not component, so correct
      if button==0 then
        tf.selectOrigin=math.min(tx+tf.scrollIndex,len(tf.text)+1)
        tf.dragging=tf.selectOrigin
        term.setCursorBlink(false)

      end
    end

  tf.onDrag=function(tf,tx,ty)
      if tf.dragging then
        local dragX=tx
        local prevCI=tf.cursorIndex
        tf.cursorIndex=math.max(math.min(dragX+tf.scrollIndex-1,len(tf.text)+1),1)
        if prevCI~=cursorIndex then
          updateSelect(tf,tf.selectOrigin)
          tf:draw()
        end
        if dragX<1 or dragX>tf.width then
          --it's dragging outside.
          local dragMagnitude=dragX-1
          if dragMagnitude>=0 then
            dragMagnitude=dragX-tf.width
          end
          local dragDir=dragMagnitude<0 and -1 or 1
          dragMagnitude=math.abs(dragMagnitude)
          local dragStep, dragRate
          if dragMagnitude>5 then
            dragRate=.1
            dragStep=dragMagnitude/5*dragDir
          else
            dragRate=(6-dragMagnitude)/10
            dragStep=dragDir
          end
          if tf.dragTimer then
            event.cancel(tf.dragTimer)
          end
          tf.dragTimer=event.timer(dragRate,function()
              assert(tf.gui.running)
                tf.cursorIndex=math.max(math.min(tf.cursorIndex+dragStep,len(tf.text)+1),1)
              if tf.cursorIndex<tf.scrollIndex then
                tf.scrollIndex=tf.cursorIndex
              elseif tf.cursorIndex>tf.scrollIndex+tf.width-2 then
                tf.scrollIndex=tf.cursorIndex-tf.width+1
              end
              updateSelect(tf,tf.selectOrigin)
              tf:draw()
            end, math.huge)
        else
          if tf.dragTimer then
            event.cancel(tf.dragTimer)
          end
        end

      end
    end

  tf.onDrop=function(tf)
    if tf.dragging then
      tf.dragging=nil
      if tf.dragTimer then
        event.cancel(tf.dragTimer)
      end
      local screenX,screenY=tf:getScreenPosition()
      term.setCursor(screenX+tf.cursorIndex-tf.scrollIndex,screenY)
      term.setCursorBlink(true)
    end
  end

  tf.keyHandler=function(tfclear,char,code)
      local screenX,screenY=tf:getScreenPosition()
      local dirty=false
      if not keyboard.isControl(char) then
        tf:insertText(unicode.char(char))
        dirty=true
      elseif code==28 and tf.tabNext then
        gui:changeFocusTo(tf.tabNext)
      elseif code==keyboard.keys.left then
        local prevCI=tf.cursorIndex
        if tf.cursorIndex>1 then
          tf.cursorIndex=tf.cursorIndex-1
          if tf.cursorIndex<tf.scrollIndex then
            tf.scrollIndex=math.max(1,tf.scrollIndex-math.floor(tf.width/3))
            dirty=true
          else
            term.setCursor(screenX+tf.cursorIndex-tf.scrollIndex,screenY)
          end
          term.setCursor(screenX+tf.cursorIndex-tf.scrollIndex,screenY)
        end
        if keyboard.isShiftDown() then
          updateSelect(tf,prevCI)
          dirty=true
        elseif tf.selectEnd~=0 then
          tf.selectEnd=0
          dirty=true
        end
      elseif code==keyboard.keys.right then
        local prevCI=tf.cursorIndex
        if tf.cursorIndex<len(tf.text)+1 then
          tf.cursorIndex=tf.cursorIndex+1

          if tf.cursorIndex>=tf.scrollIndex+tf.width then
            tf.scrollIndex=tf.scrollIndex+math.floor(tf.width/3)
            dirty=true
          else
            term.setCursor(screenX+tf.cursorIndex-tf.scrollIndex,screenY)
          end
        end
        if keyboard.isShiftDown() then
          updateSelect(tf,prevCI)
          dirty=true
        elseif tf.selectEnd~=0 then
          tf.selectEnd=0
          dirty=true
        end
      elseif code==keyboard.keys.home then
        local prevCI=tf.cursorIndex
        if tf.cursorIndex~=1 then
          tf.cursorIndex=1
          if tf.scrollIndex~=1 then
            tf.scrollIndex=1
            dirty=true
          else
            term.setCursor(screenX+tf.cursorIndex-tf.scrollIndex,screenY)
          end
        end
        if keyboard.isShiftDown() then
          updateSelect(tf,prevCI)
          dirty=true
        elseif tf.selectEnd~=0 then
          tf.selectEnd=0
          dirty=true
        end
      elseif code==keyboard.keys["end"] then
        local prevCI=tf.cursorIndex
        if tf.cursorIndex~=len(tf.text)+1 then
          tf.cursorIndex=len(tf.text)+1
          if tf.scrollIndex+tf.width-1<=tf.cursorIndex then
            tf.scrollIndex=tf.cursorIndex-tf.width+1
            dirty=true
          else
            term.setCursor(screenX+tf.cursorIndex-tf.scrollIndex,screenY)
          end
        end
        if keyboard.isShiftDown() then
          updateSelect(tf,prevCI)
          dirty=true
        elseif tf.selectEnd~=0 then
          tf.selectEnd=0
          dirty=true
        end
      elseif code==keyboard.keys.back then
        if tf.selectEnd~=0 then
          tf:removeSelected()
          dirty=true
        elseif tf.cursorIndex>1 then
          tf.text=unicode.sub(tf.text,1,tf.cursorIndex-2)..unicode.sub(tf.text,tf.cursorIndex)
          tf.cursorIndex=tf.cursorIndex-1
          if tf.cursorIndex<tf.scrollIndex then
            tf.scrollIndex=math.max(1,tf.scrollIndex-math.floor(tf.width/3))
          end
          dirty=true
        end
      elseif code==keyboard.keys.delete then
        if tf.selectEnd~=0 then
          tf:removeSelected()
          dirty=true
        elseif tf.cursorIndex<=len(tf.text) then
          tf.text=unicode.sub(tf.text,1,tf.cursorIndex-1)..unicode.sub(tf.text,tf.cursorIndex+1)
          dirty=true
        end
      end
      if dirty then
        tf:draw()
      end
    end


  tf.gotFocus=function()
    --we may want to scroll here, cursor to end of text on gaining focus
    local effText=tf.text

    if len(effText)>tf.width then
      tf.scrollIndex=len(effText)-tf.width+3
    else
      tf.scrollIndex=1
    end
    tf.cursorIndex=len(effText)+1
    tf:draw()
  end

  tf.lostFocus=function()
    tf.scrollIndex=1
    tf.selectEnd=0
    term.setCursorBlink(false)
    tf:draw()
  end

  gui:addComponent(tf)
  return tf
end

local function updateScrollBarGrip(sb)
  local gripStart,gripEnd
  local pos,max,length=sb.scrollPos,sb.scrollMax,sb.length

  --grip size
  -- gripSize / height-2 == height / scrollMax
  local gripSize=math.max(1,math.min(math.floor(math.min(1,length / (max+length-2)) * (length-2)),length-2))
  if gripSize==length-2 then
    --grip fills everything
    sb.gripStart=1
    sb.gripEnd=length-2
  else
    --grip position
    pos=round((pos-1)/(max-1)*(length-2-gripSize))+1

    --from pos and size, figure gripStart and gripEnd
    sb.gripStart=pos
    sb.gripEnd=pos+gripSize-1
  end

end


local function scrollBarBase(gui,x,y,width,height,scrollMax,onScroll)
  local sb=baseComponent(gui,x,y,width,height,"scrollbar",false)
  sb.scrollMax=scrollMax or 1
  sb.scrollPos=1
  sb.length=math.max(sb.width,sb.height)
  assert(sb.length>2,"Scroll bars must be at least 3 long.")

  sb.onScroll=onScroll


  updateScrollBarGrip(sb)

  sb._onClick=function(sb,tpos,button)
      local newPos=sb.scrollPos
      if tpos==1 then
        --up button
        newPos=math.max(1,sb.scrollPos-1)
      elseif tpos==sb.length then
        newPos=math.min(sb.scrollMax,sb.scrollPos+1)
      elseif tpos<sb.gripStart then
        --before grip, scroll up a page
        newPos=math.max(1,sb.scrollPos-sb.length+1)
      elseif tpos>sb.gripEnd then
        --before grip, scroll up a page
        newPos=math.min(sb.scrollMax,sb.scrollPos+sb.length-1)
      end
      if newPos~=sb.scrollPos then
        sb.scrollPos=newPos
        updateScrollBarGrip(sb)
        sb:draw()
        if sb.onScroll then
          sb:onScroll(sb.scrollPos)
        end
      end
    end

  sb._onBeginDrag=function(sb,tpos,button)
      if button==0 and sb.length>3 and (sb.length/sb.scrollMax<1) then
        sb.dragging=true
        sb.lastDragPos=tpos
      end
    end

  sb._onDrag=function(sb,tpos)
      if sb.dragging then
        local py=sb.lastDragPos
        local dif=tpos-py
        if dif~=0 then
          --calc the grip position for this y position
          --first clamp to range of scroll area
          local scroll=math.min(math.max(tpos,2),sb.length-1)-2
          --scale to 0-1
          scroll=scroll/(sb.length-3)
          --scale to maxScroll
          scroll=round(scroll*(sb.scrollMax-1)+1)
          --see if this is different from our current scroll position
          if scroll~=sb.scrollPos then
            --it is. We actually scrolled, then.
            sb.scrollPos=scroll
            updateScrollBarGrip(sb)
            sb:draw()
            if onScroll then
              sb:onScroll()
            end
          end
        end
      end
    end

  sb.onDrop=function(sb)
      sb.dragging=false
    end

  return sb
end

local function addScrollBarV(gui,x,y,height,scrollMax, onScroll)
  local sb=scrollBarBase(gui,x,y,1,height,scrollMax,onScroll)

  sb.draw=drawScrollBarV

  sb.onClick=function(sb,tx,ty,button) sb:_onClick(ty,button) end
  sb.onBeginDrag=function(sb,tx,ty,button) sb:_onBeginDrag(ty,button) end
  sb.onDrag=function(sb,tx,ty,button) sb:_onDrag(ty,button) end

  gui:addComponent(sb)
  return sb
end

local function addScrollBarH(gui,x,y,width,scrollMax,onScroll)

  local sb=scrollBarBase(gui,x,y,width,1,scrollMax,onScroll)

  sb.draw=drawScrollBarH

  sb.onClick=function(sb,tx,ty,button) sb:_onClick(tx,button) end
  sb.onBeginDrag=function(sb,tx,ty,button) sb:_onBeginDrag(tx,button) end
  sb.onDrag=function(sb,tx,ty,button) sb:_onDrag(tx,button) end

  gui:addComponent(sb)
  return sb
end


local function compositeBase(gui,x,y,width,height,objType,focusable)
  local comp=baseComponent(gui,x,y,width,height,objType,focusable)
  comp.bodyX,comp.bodyY,comp.bodyW,comp.bodyH=calcBody(comp)

  comp.components={}

  function comp.addComponent(obj,component)
    obj.components[#obj.components+1]=component
  end

  return comp
end

local function scrollListBox(sb)
  local lb=sb.listBox

  for i=1,#lb.labels do
    local listI=sb.scrollPos+i-1
    local l=lb.labels[i]
    if listI<=#lb.list then
      l.state=lb.selectedLabel==listI and "selected" or nil
      l.text=lb.list[listI]
    else
      l.state=nil
      l.text=""
    end
    l:draw()
  end
end


local function clickListBox(lb,tx,ty,button)
  if tx==lb.width then
    lb.scrollBar:_onClick(ty,button)
  else
    tx,ty=correctForBorder(lb,tx,ty)
    if ty>=1 and ty<=lb.bodyH then
      --ty is now index of the label clicked on
      --but is it valid?
      if ty<=#lb.list then
        lb:select(ty+lb.scrollBar.scrollPos-1)
      end
    end
  end

end

local function listBoxSelect(lb,index)
  if index<1 or index>#lb.list then
    error("index out of range to listBoxSelect",2)
  end
  local prevSelected=lb.selectedLabel
  if index==prevSelected then
    return
  end

  lb.selectedLabel=index
  --do I need to scroll?
  local scrolled=false
  local scrollIndex=lb.scrollBar.scrollPos
  if index<scrollIndex then
    scrollIndex=index
    scrolled=true
  elseif index>scrollIndex+lb.bodyH-1 then
    scrollIndex=index-lb.bodyH+1
    scrolled=true
  end
  if scrolled then
    --update scroll position
    lb.scrollBar.scrollPos=scrollIndex
    scrollListBox(lb.scrollBar)
  else
    if prevSelected>=scrollIndex and prevSelected<=scrollIndex+lb.bodyH-1 then
      local pl=lb.labels[prevSelected-scrollIndex+1]
      pl.state=nil
      pl:draw()
    end
    local l=lb.labels[index-scrollIndex+1]
    l.state="selected"
    l:draw()
  end

  if lb.onChange then
    lb:onChange(prevSelected,index)
  end
end


local function getListBoxSelected(lb)
  return lb.list[lb.selectedLabel]
end

local function updateListBoxList(lb,newList)
  lb.list=newList
  lb.scrollBar.scrollPos=1
  lb.scrollBar.scrollMax=math.max(1,#newList-lb.bodyH+1)
  updateScrollBarGrip(lb.scrollBar)
  lb.selectedLabel=1
  scrollListBox(lb.scrollBar)
  lb:draw()
end

local function addListBox(gui,x,y,width,height,list)
  local lb=compositeBase(gui,x,y,width,height,"listbox",true)
  lb.list=list

  lb.scrollBar=addScrollBarV(lb,lb.bodyW,lb.bodyY,lb.bodyH,math.max(1,#list-lb.bodyH+1),scrollListBox)
  lb.scrollBar.class="listbox"
  lb.scrollBar.listBox=lb

  lb.scrollBar.posY=1
  lb.scrollBar.height=lb.height
  lb.scrollBar.length=lb.height

  lb.selectedLabel=1
  updateScrollBarGrip(lb.scrollBar)

  lb.labels={}
  lb.list=list
  lb.onBeginDrag=function(lb,tx,ty,button) if tx==lb.width then lb.scrollBar:_onBeginDrag(ty,button) end end
  lb.onDrag=function(lb,...) lb.scrollBar:onDrag(...) end
  lb.onDrop=function(lb,...) lb.scrollBar:onDrop(...) end

  for i=1,lb.bodyH do
    lb.labels[i]=addLabel(lb,1,i,lb.bodyW-1,list[i] or "")
    lb.labels[i].class="listbox"
  end
  lb.labels[1].state="selected"

  lb.select=listBoxSelect
  lb.getSelected=getListBoxSelected

  lb.keyHandler=function(lb,char,code)
    if code==keyboard.keys.up then
      if lb.selectedLabel>1 then
        lb:select(lb.selectedLabel-1)
      end
    elseif code==keyboard.keys.down then
      if lb.selectedLabel<#lb.list then
        lb:select(lb.selectedLabel+1)
      end
    elseif code==keyboard.keys.enter and lb.onEnter then
      lb:onEnter()
    end
  end

  lb.updateList=updateListBoxList

  lb.onClick=clickListBox
  lb.draw=function(lb)
    if not lb:isHidden() then
      local styles=getAppliedStyles(lb)
      drawBorder(lb,styles)
      lb.scrollBar:draw()
      for i=1,#lb.labels do
        lb.labels[i]:draw()
      end
    end
  end

  gui:addComponent(lb)
  return lb
end



function gml.create(x,y,width,height,renderTarget)

  local newGui=compositeBase(screen,x,y,width,height,"gui",false)
  newGui.handlers={}
  newGui.hidden=true
  newGui.renderTarget=gfxbuffer.create(renderTarget)

  local running=false
  function newGui.close()
    computer.pushSignal("gui_close")
  end

  function newGui.addComponent(obj,component)
    newGui.components[#obj.components+1]=component
    if obj.focusElement==nil and component.focusable then
      component.state="focus"
      obj.focusElement=component
    end
  end


  newGui.addHandler=guiAddHandler

  function newGui.redrawRect(gui,x,y,w,h)
    local fillCh,fillFG,fillBG=findStyleProperties(newGui,"fill-ch","fill-color-fg","fill-color-bg")
    local blank=(fillCh):rep(w)
    gui.renderTarget.setForeground(fillFG)
    gui.renderTarget.setBackground(fillBG)

    x=x+newGui.bodyX-1
    for y=y+newGui.bodyY-1,y+h+newGui.bodyY-2 do
      gui.renderTarget.set(x,y,blank)
    end
  end

  function newGui.changeFocusTo(gui,target)
    if gui.focusElement then
      gui.focusElement.state=nil
      if gui.focusElement.lostFocus then
        gui.focusElement.lostFocus()
      elseif not gui.hidden then
        gui.focusElement:draw()
      end
    end
    gui.focusElement=target
    target.state="focus"
    if target.gotFocus then
      target.gotFocus()
    elseif not gui.hidden then
      target:draw()
    end
  end

  newGui.run=runGui
  newGui.contains=contains
  newGui.addLabel=addLabel
  newGui.addButton=addButton
  newGui.addTextField=addTextField
  newGui.addScrollBarV=addScrollBarV
  newGui.addScrollBarH=addScrollBarH
  newGui.addListBox=addListBox
  newGui.draw=function(gui)
      local styles=getAppliedStyles(gui)
      local bodyX,bodyY,bodyW,bodyH=drawBorder(gui,styles)
      local fillCh,fillFG,fillBG=extractProperties(gui,styles,"fill-ch","fill-color-fg","fill-color-bg")

      gui.renderTarget.setForeground(fillFG)
      gui.renderTarget.setBackground(fillBG)
      term.setCursorBlink(false)

      gui.renderTarget.fill(bodyX,bodyY,bodyW,bodyH,fillCh)

      for i=1,#gui.components do
        gui.components[i]:draw()
        gui.renderTarget:flush()
      end

      if gui.onDraw then
        gui.onDraw()
      end
    end

  return newGui
end




--**********************

defaultStyle=gml.loadStyle("default")
screen.style=defaultStyle

return gml
