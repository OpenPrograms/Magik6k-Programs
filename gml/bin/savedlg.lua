--[[
save/load dialog gui

**NOTE** This is the actual source of the filePicker function in the gmlDialogs library.
There is no reason to reproduce this in your code, it is simple included as example code
for using the gml library to create guis.
If you want to use this file picker, just require gmlDialogs and call
gmlDialogs.filePicker()

See the wiki for documentation of the methods
TODO: link here when doc exists...

--]]
package.loaded.gml=nil
package.loaded.gfxbuffer=nil

local gml=require("gml")
local shell=require("shell")
local filesystem=require("filesystem")

function filePicker(mode,curDir,name,extension)
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

print(filePicker("save","/usr/","derp.lua","lua"))

--[[
ultimaely will integrate this into gml.lua and boil down to:

filename = gml.filePicker(<"save" or "load"> [, startPath [, extensions ] ])

startPath will determine waht folder the file list view starts on
if startPath is a file, rather than a folder, will start in the containing folder
and select that file, populating the textfield with it.

extensions, if specified, can be a string or list of strings, and the file list
will show only files matching that extension. For save, the extension will also be
automatically applied to the name, if it does not end with it already.




--]]