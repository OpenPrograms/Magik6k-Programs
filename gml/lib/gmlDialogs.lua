--[[
Basic & Common Forms and Dialogs

a collection of common dialogs and forms for use in programs.
These dialogs can be used even whether or not your program otherwise
uses the gml library.

--]]
local gml=require("gml")
local shell=require("shell")
local filesystem=require("filesystem")

local gmlDialogs={VERSION="1.0"}


function gmlDialogs.filePicker(mode,curDir,name,extension)
  checkArg(1,mode,"string")
  checkArg(2,path,"nil","string")
  checkArg(3,name,"nil","string")
  checkArg(4,extensions,"nil","string")

  curDir=curDir or "/"
  if not filesystem.exists(curDir) or not filesystem.isDirectory(curDir) then
    error("invalid path arg to filePicker",2)
  end

  name=name or ""

  if mode=="load" then
    mode=false
  elseif mode~="save" then
    error("Invalid mode arg to gml.filePicker, must be \"save\" or \"load\"",2)
  end

  local result=nil

  local gui=gml.create("center","center",50,16)

  gui:addLabel(1,1,14,"Common Folders")
  local commonDirList=gui:addListBox(1,2,16,11,{"/","/usr/","/tmp/","/lib/","/bin/"})

  local contentsLabel=gui:addLabel(18,1,31,"contents of /")
  local directoryList=gui:addListBox(17,2,32,11,{})

  local messageLabel=gui:addLabel(1,-1,30,"")
  messageLabel.class="error"

  local filename=gui:addTextField(22,-2,26,name)
  local fileLabel=gui:addLabel(17,-2,5,"File:")
  gui:addButton(-2,-1,8,1,mode and "Save" or "Open",function()
      --require an actual filename
      local ext=filename.text
      local t=curDir..filename.text
      ext=ext:match("%.([^/]*)$")
      local failed
      local function fail(msg)
        messageLabel.text=msg
        messageLabel:draw()
        failed=true
      end

      if mode then
        --saving
        if filesystem.get(curDir).isReadOnly() then
          fail("Directory is read-only")
        elseif extension then
          if ext then
            --has an extension, is it the right one?
            if ext~=extension then
              fail("Invalid extension, use "..extension)
            end
          else
            t=t.."."..extension
          end
        end
      else
        --loading
        if not filesystem.exists(t) then
          fail("That file doesn't exist")
        elseif extension then
          if ext and ext~=extension then
            fail("Invalid extension, use ."..extension)
          end
        end
      end

      if not failed then
        result=t
        gui.close()
      end
    end)

  gui:addButton(-11,-1,8,1,"Cancel",gui.close)

  local function updateDirectoryList(dir)
    local list={}
    curDir=dir
    if dir~="/" then
      list[1]=".."
    end
    local nextDir=#list+1
    for file in filesystem.list(dir) do
      if filesystem.isDirectory(file) then
        if file:sub(-1)~="/" then
          file=file.."/"
        end
        table.insert(list,nextDir,file)
        nextDir=nextDir+1
      else
        table.insert(list,file)
      end
    end
    curDir=dir
    directoryList:updateList(list)
    contentsLabel.text="contents of "..curDir
    contentsLabel:draw()
  end

  local function onDirSelect(lb,prevIndex,selIndex)
    updateDirectoryList(commonDirList:getSelected())
  end

  commonDirList.onChange=onDirSelect
  local function onActivateItem()
    local selected=directoryList:getSelected()
    if selected==".." then
      selected=curDir:match("^(.*/)[^/]*/")
    else
      selected=curDir..selected
    end
    if filesystem.isDirectory(selected) then
      updateDirectoryList(selected)
    else
      filename.text=selected:match("([^/]*)$")
      gui:changeFocusTo(filename)
    end
  end

  directoryList.onDoubleClick=onActivateItem
  directoryList.onEnter=onActivateItem

  updateDirectoryList(curDir)

  gui:run()

  return result
end

function splitToLines(message, lineWidth)
  --do some figuring
  local lines={}
  message:gsub("([^\n]+)",function(line) lines[#lines+1]=line end)
  local i=1
  while i<=#lines do
    if #lines[i]>lineWidth then
      local s,rs=lines[i],lines[i]:reverse()
      local pos=-lineWidth
      local prev=1
      while #s>prev+lineWidth-1 do
        local space=rs:find(" ",pos)
        if space then
          table.insert(lines,i,s:sub(prev,#s-space))
          prev=#s-space+2
          pos=-(#s-space+lineWidth+2)
        else
          table.insert(lines,i,s:sub(prev,prev+lineWidth-1))
          prev=prev+lineWidth
          pos=pos-lineWidth
        end
        i=i+1
      end
      lines[i]=s:sub(prev)
    end
    i=i+1
  end
  
  return lines
end

function gmlDialogs.messageBox(message,buttons)
  checkArg(1,message,"string")
  checkArg(2,buttons,"table","nil")

  local buttons=buttons or {"cancel","ok"}
  local choice

  local lines = splitToLines(message, 30 - 4)

  local gui=gml.create("center","center",30,6+#lines)

  local labels={}
  for i=1,#lines do
    labels[i]=gui:addLabel(2,1+i,#lines[i],lines[i])
  end

  local buttonObjs={}
  --now the buttons

  local xpos=2
  for i=1,#buttons do
    if type(buttons[i])~="string" then eror("messageBox must be passed an array of strings for buttons",2) end
    if i==#buttons then xpos=-2 end
    buttonObjs[i]=gui:addButton(xpos,-2,#buttons[i]+2,1,buttons[i],function() choice=buttons[i] gui.close() end)
    xpos=xpos+#buttons[i]+3
  end

  gui:changeFocusTo(buttonObjs[#buttonObjs])
  gui:run()

  return choice
end

---
-- A simple selection box, displays a message and listbox with selectable options.
-- Returns the label of the selected listbox option and nil if the cancel button was pressed.
function gmlDialogs.listSelection(message, listContent)
  checkArg(1,message,"string")
  checkArg(2,listContent,"nil","table")
  
  local result=nil

  local gui=gml.create("center", "center", 50, 16)

  local messageLabel = gui:addLabel("center", 1, string.len(message), message)
  
  local listContentTable = { }
  for key, var in pairs(listContent) do
    table.insert(listContentTable, var)
  end
  
  local selectionList=gui:addListBox(1, 2 + messageLabel.posY, gui.width, 10, listContentTable)
  
  gui:addButton(4, -1, 8, 1, "Cancel", gui.close)
  
  gui:addButton(-4, -1, 8, 1, "Select", function()
      local t=selectionList:getSelected()
      result=t
      gui.close()
    end)
  
  gui:run()

  return result
end

---
-- A simple text inputbox, displays a message and textfield.
-- Returns text from the textfield and nil if the cancel button was pressed.
function gmlDialogs.inputBox(message, defaultValue)
  checkArg(1, message, "string")
  checkArg(2, defaultValue, "string", "nil")
  
  local result = nil
  
  local lines = splitToLines(message, 50 - 4)

  local gui=gml.create("center", "center", 50, 8 + #lines)

  local labels={}
  for i=1,#lines do
    labels[i]=gui:addLabel(2,1+i,#lines[i],lines[i])
  end
  
  if defaultValue == nil then defaultValue = "" end
  
  local textInput = gui:addTextField(2, labels[#lines].posY + 2 , gui.width - 4, defaultValue)
  
  gui:addButton(4, textInput.posY + 2, 8, 1, "Cancel", gui.close)
  
  gui:addButton(-4, textInput.posY + 2, 8, 1, "OK", function()
      local t = textInput.text
      result = t
      gui.close()
    end)
  
  gui:run()

  return result
end

return gmlDialogs