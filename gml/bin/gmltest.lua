--just hrere to force reloading the api so I don't have to reboot
package.loaded.gml=nil
package.loaded.gfxbuffer=nil

local gml=require("gml")
local component=require("component")

local gui=gml.create("center","center",32,19)

local label=gui:addLabel("center",2,13,"Hello, World!")
label:hide()

local function toggleLabel()
  if label.visible then
    label:hide()
  else
    label:show()
  end
end

local textField=gui:addTextField("center",4,18)

local button1=gui:addButton(4,6,10,1,"Toggle",toggleLabel)
local button2=gui:addButton(-4,6,10,1,"Close",gui.close)

gui:addHandler("key_down",
  function(event,addy,char,key)
    --ctrl-r
    if char==18 then
      local fg,bg=component.gpu.getForeground(), component.gpu.getBackground()
      label["text-color"]=math.random(0,0xffffff)
      label:draw()
      component.gpu.setForeground(fg)
      component.gpu.setBackground(bg)
    end
  end)

local scrollBarV,scrollBarH
local label2=gui:addLabel(-2,-2,7,"  0,  0")

local function setLabelToScroll()
  label2.text=string.format("%3s,%3s",scrollBarH.scrollPos,scrollBarV.scrollPos)
  label2:draw()
end

scrollBarV=gui:addScrollBarV(-1,1,16,100,setLabelToScroll)
scrollBarH=gui:addScrollBarH(1,-1,29,100,setLabelToScroll)


local listBox=gui:addListBox("center",8,16,8,{"one","two","three","four","five","six","seven","eight","nine","ten","eleven","twelve","thirteen","fourteen","fifteen","sixteen","seventeen","eighteen","nineteen","twenty","twenty-one","twenty-two","twenty-three","twenty-four","twenty-five"})

gui:run()

