--[[local component=require("component")

local robot=require("robot")

robot.down()
robot.up()
--]]
local serialization=require("serialization")

local function getValueField(node,field)
  --[[for i=1,#node.children do
    if node.children[i].tag==field then
      if #node.children[i].children~=1 then
        error("expected exactly one value for field '"..field.."' in node '"..node.name.."'!")
      end

      return node.children[i].children[1]
    end
  end--]]
  if not node[field] then
    return nil
  elseif type(node[field])=="table" then
    error("expected exactly one value for field '"..field.."' in node '"..node.name.."'!")
  end
  return node[field]
end

local validXPosStrings={center=true,left=true,right=true,}
local validYPosStrings={top=true,bottom=true,center=true}
local function parsePosXField(node,field)
  local str=getValueField(node,field)
  local n=tonumber(str)
  if n then
    return n
  elseif validXPosStrings[str] then
    return str
  else
    error("Invalid position value '"..(str or "nil").."' for field "..field.." of element "..getValueField(node,"name"))
  end
end
local function parsePosYField(node,field)
  local str=getValueField(node,field)
  local n=tonumber(str)
  if n then
    return n
  elseif validYPosStrings[str] then
    return str
  else
    error("Invalid position value '"..(str or "nil").."' for field "..field.." of element "..getValueField(node,"name"))
  end
end


local function parseNumberField(node,field)
  local str=getValueField(node,field)
  local n=tonumber(str)
  if n then
    return n
  else
    error("expected number, got '"..(str or "nil").." for field "..field.." of element "..getValueField(node,"name"))
  end
end

local function parseListField(node,field)
  local str=getValueField(node,field)
  --print("list = "..str)
  local l=serialization.unserialize(str)
  if l and type(l)=="table" then
    return l
  else
    error("expected list for field "..field.." of element "..getValueField(node,"name"))
  end
end


local fieldTypes={
  xpos=parsePosXField,
  ypos=parsePosYField,
  num=parseNumberField,
  str=getValueField,
  list=parseListField,

}

local function parseElementFields(node,...)
  local element={}
  local args={...}
  --print("parseElementFields for "..name)
  for i=1,#args do
    local f,t,req,def=table.unpack(args[i])
    --print("f="..f..", t="..t)
    element[f]=fieldTypes[t](node,f)
    if not element[f] then
      if req then
        error("missing required field '"..f.."' on element type '"..node.tag.."'!")
      else
        element[f]=def
      end
    end
  end
  return element,element.name
end

local FS_name={"name","str",true}
local FS_xpos={"x","xpos",true}
local FS_ypos={"y","ypos",true}
local FS_width={"w","num",true}
local FS_height={"h","num",true}
local FS_maxscroll={"maxScroll","num",false,100}

local function parseLabel(node)
  local e,name=parseElementFields(node,FS_name,FS_xpos,FS_ypos,FS_width,{"text","str",false,name})
  e.type="label"
  return e,name
end

local function parseTextField(node)
  local e,name=parseElementFields(node,FS_name,FS_xpos,FS_ypos,FS_width,{"text","str",false,""})
  e.type="textField"
  return e,name
end

local function parseButton(node)
  local e,name=parseElementFields(node,FS_name,FS_xpos,FS_ypos,FS_width,FS_height,{"text","str",false,name},{"onClick","str",false})
  e.type="button"
  return e,name
end

local function parseScrollBarH(node)
  local e,name=parseElementFields(node,FS_name,FS_xpos,FS_ypos,FS_width,FS_maxscroll,{"onScroll","str",false})
  e.type="scrollBarH"
  return e,name
end

local function parseScrollBarV(node)
  local e,name=parseElementFields(node,FS_name,FS_xpos,FS_ypos,FS_height,FS_maxscroll,{"onScroll","str",false})
  e.type="scrollBarV"
  return e,name
end

local function parseListBox(node)
  local e,name=parseElementFields(node,FS_name,FS_xpos,FS_ypos,FS_width,FS_height,{"list","list",false,{}})
  e.type="listBox"
  return e,name
end

local function parseFrame(node)
  local base=parseElementFields(node,FS_name,FS_xpos,FS_ypos,FS_width,FS_height)
  --children
  local children
  base.children={}
  for i=1,#node.children do
    if node.children[i].tag=="children" then
      children=node.children[i]
      break
    end
  end
  if children then
    for k,v in pairs(children) do
      if type(k)~="number" and k~="children" and k~="tag" then
        base.children[k]=v
      end
    end
  end
  return base,"gui"
end

local function parseMeta(node)
  local base=parseElementFields(node,{"title","str",false,"untitled"},{"author","str",false,"anonymous"},{"desc","str",false})
  return base,"meta"
end

local function parseFunction(node)
  local func=parseElementFields(node,FS_name,{"body","str",true})

  return func,"functions"
end

local function parseHandler(node)
  local func=parseElementFields(node,{"event","str",true},{"body","str",true})

  return func,"handlers"
end

local function parseCode(node)
  local code={}
  if node.functions==nil then
    code.functions={}
  elseif #node.functions==0 then
    code.functions={node.functions}
  else
    code.functions=node.functions
  end
  if node.handlers==nil then
    code.handlers={}
  elseif #node.handlers==0 then
    code.handlers={node.handlers}
  else
    code.handlers=node.handlers
  end
  if node.requires==nil then
    code.requires={}
  elseif #node.handlers==0 then
    code.requires={node.requires}
  else
    code.requires=node.requires
  end
  code.body=node.children[1]
  return code,"code"
end

local function parseGml(node)
  local gml={}
  gml.meta=node.meta
  gml.code=node.code
  gml.gui=node.gui
  return gml,"gml"
end

local typeParsers = {
  label = parseLabel,
  field = parseTextField,
  button= parseButton,
  scrollBarH=parseScrollBarH,
  scrollBarV=parseScrollBarV,
  listbox=parseListBox,
  frame=parseFrame,
  meta=parseMeta,
  ["function"]=parseFunction,
  handler=parseHandler,
  code=parseCode,
}

local gml
local parsedgml={}

local file=io.open("gmltest.gml","r")
assert(file)
gml=file:read("*all")
file:close()
local codeBlocks={}
gml=gml:gsub("<<(.-)>>",function(v) codeBlocks[#codeBlocks+1]=v return "%%"..#codeBlocks.."%%" end)
gml=gml:gsub("\n"," ")
local tagStack={}


for close,tag,body in gml:gmatch("<(/?)(%w+)>%s*([^<^>^]*)") do
  close=close=="/"
  body=body:match("^(.-)%s*$"):gsub("(%s+)"," "):gsub("%%%%(%d+)%%%%",function (i) return codeBlocks[tonumber(i)] end)
  --print(body)
  --io.read()
  if close then
    local topTag=tagStack[#tagStack]
    tagStack[#tagStack]=nil
    if not topTag or tag~=topTag.tag then
      error("encountered /"..tag..", expected "..(topTag and ("/"..topTag.tag) or "eof").."!")
    end
    if #tagStack>0 then
      if typeParsers[topTag.tag] then
        --must have a name
        local parsed,name=typeParsers[topTag.tag](topTag)
        tagStack[#tagStack][name]=parsed
      else
        --default parsing
        if #topTag.children==1 then
          local t=tagStack[#tagStack]
          if t[topTag.tag] then
            if type(t[topTag.tag])=="table" then
              table.insert(t[topTag.tag],topTag.children[1])
            else
              t[topTag.tag]={t[topTag.tag],topTag.children[1]}
            end
          else
            t[topTag.tag]=topTag.children[1]
          end
        else
          --print("unhandled tag "..topTag.tag.."?")
          table.insert(tagStack[#tagStack].children,topTag)
        end
      end
    else
      parsedgml=topTag
    end

    if body~="" then
      table.insert(tagStack[#tagStack].children,body)
    end
  else
    --print(string.rep(" ",#tagStack)..tag)
    local tag={tag=tag,children={}}
    tagStack[#tagStack+1]=tag
    if body~="" then
      table.insert(tagStack[#tagStack].children,body)
      --print(string.rep(" ",#tagStack)..'"'..body..'"')
    end
  end
end

if #tagStack>0 then
  error("Unexpected eof; "..#tagStack.." unclosed tags!")
end

if not parsedgml then
  error("found... nothing?")
end

parsedgml.tag=nil
parsedgml.children=nil

local file=io.open("foo","w")
local function writeIndent(str,depth)
  file:write((" "):rep(depth*2)..str)
end

local function prettyPrint(tab,depth,skipFirst)
  writeIndent("{\n",skipFirst and 0 or depth)
  for i=1,#tab do
    local v=tab[i]
    if type(v)=="table" then
      prettyPrint(v,depth+1)
      file:write(",\n")
    elseif type(v)=="string" then
      writeIndent('"'..v..'",\n',depth+1)
    else
      writeIndent(tostring(v)..",\n",depth+1)
    end
  end
  for k,v in pairs(tab) do
    if type(k)~="number" then
      writeIndent(k.." = ",depth+1)
      if type(v)=="table" then
        prettyPrint(v,depth+2,true)
      elseif type(v)=="string" then
        file:write('"'..v..'"')
      else
        file:write(tostring(v))
      end
      file:write(",\n")
    end
  end
  writeIndent("}",depth)
end

prettyPrint(parsedgml,0)
file:close()
--error("",0)

--what I want in the end

local parsedgml2 = {
  meta = {
    title="gmltest",
    author="GopherAtl",
    desc="A test program for the GML gui library",
  },
  gui = {
    name="testgui",
    x="center",
    y="center",
    w=32,
    h=19,
    children = {
      label1 = {
        type="label",
        x="center",
        y=2,
        w=13,
        text="Hello, World!",
      },
      label2 = {
        type="label",
        x=-2,
        y=-2,
        w=7,
      },
      field1 = {
        type="textField",
        x="center",
        y=4,
        w=18,
      },
      button1 = {
        type="button",
        x=4,
        y=4,
        w=10,
        h=1,
        text="Toggle",
        onClick=[[
          function()
            if label1.visible then
              label1:hide()
            else
              label1:show()
            end
          end
        ]],
      },
      button2 = {
        type="button",
        x=4,
        y=6,
        w=10,
        h=1,
        text="Close",
        onClick="testgui.close"
      },
      scrollV = {
        type="scrollBarV",
        x=-1,
        y=1,
        h=16,
        maxScroll=100,
        onScroll="setLabelToScroll",
      },
      scrollH = {
        type="scrollBarH",
        x=1,
        y=-1,
        w=29,
        maxScroll=100,
        onScroll="setLabelToScroll",
      },
      listbox1 = {
        type="listBox",
        x="center",
        y=8,
        w=16,
        h=8,
        list={
            "one", "two", "three", "four", "five", "six", "seven",
            "eight", "nine", "ten", "eleven", "twelve", "thirteen",
            "fourteen", "fifteen", "sixteen", "seventeen",
            "eighteen", "nineteen", "twenty", "twenty-one",
            "twenty-two", "twenty-three", "twenty-four", "twenty-five"
          },
      },
    },
  },
  code = {
    requires={"component",},
    functions = {
      setLabelToScroll={
        args={},
        body=[[
          label2.text=string.format("%3s,%3s",scrollH.scrollPos,scrollV.scrollPos)
          label2:draw()
        ]],
      },
    },
    handlers = {
      key_down=[[
        function(event,addy,char,key)
          --ctrl-r
          if char==18 then
            local fg,bg=component.gpu.getForeground(), component.gpu.getBackground()
            label["text-color"]=math.random(0,0xffffff)
            label1:draw()
            component.gpu.setForeground(fg)
            component.gpu.setBackground(bg)
          end
        end
      ]],

    },
    body=[[
      label:hide()

      label2.text="  0,  0"
    ]],

  },
}

local function varToStr(var)
  if type(var)=="string" then
    return '"'..var..'"'
  else
    return var
  end
end

local function indentCode(spaces,text,skipFirst)
  local lines={}
  local shortest=1000000000
  local function appendLine(s,t)
    if s and #t>0 then
      if #s<shortest then
        shortest=#s
      end
      lines[#lines+1]={#s,t}
    end
  end
  if text:match("\n") then
    text:gsub("([ \t]*)(.-)[ \t]*\n",appendLine)
    appendLine(text:match("\n([ \t]*)([^\n]-)[ \t]*$"))
  else
    print("single line")
    print('['..text..']')
    shortest,lines[1]=text:match("^([ \t]*)(.-)[ \t]*$")
    shortest=#shortest
    print("shortest="..shortest)
    print(lines[1])
    lines[1]={shortest,lines[1]}
  end

  for i=1,#lines do
    if i==1 and skipFirst then
      lines[i]=lines[i][2]
    else
      lines[i]=(" "):rep(spaces+lines[i][1]-shortest)..lines[i][2]
    end
  end
  --last line
  return table.concat(lines,"\n")
end


local function createFrame(base,name,frame)
  local str=name.." = gml.create("..
    varToStr(frame.x)..","..varToStr(frame.y)..","..
    varToStr(frame.w)..","..varToStr(frame.h)..")"
  return str
end

local s=require("serialization")
local function createLabel(base,name,label)
  local str=name.." = "..base..":addLabel("..
    varToStr(label.x)..","..varToStr(label.y)..","..
    varToStr(label.w)..","..'"'..(label.text or name)..'")'
  return str
end

local function createButton(base,name,button)
  local str=name.." = "..base..":addButton("..
    varToStr(button.x)..","..varToStr(button.y)..","..
    varToStr(button.w)..","..varToStr(button.h)..","..
    '"'..(button.text or name).."\","..indentCode(4,button.onClick,true)..')'
  return str
end

local function createField(base,name,field)
  local str=name.." = "..base..":addTextField("..
    varToStr(field.x)..","..varToStr(field.y)..","..
    varToStr(field.w)..","..
    '"'..(field.text or "")..'")'
  return str
end

local function createScrollBarH(base,name,bar)
  local str=name.." = "..base..":addScrollBarH("..
    varToStr(bar.x)..","..varToStr(bar.y)..","..
    varToStr(bar.w)..","..varToStr(bar.maxScroll)..","..
    indentCode(4,bar.onScroll,true)..")"
  return str
end

local function createScrollBarV(base,name,bar)
  local str=name.." = "..base..":addScrollBarV("..
    varToStr(bar.x)..","..varToStr(bar.y)..","..
    varToStr(bar.h)..","..varToStr(bar.maxScroll)..","..
    indentCode(4,bar.onScroll,true)..")"
  return str
end

local function createListBox(base,name,box)
  local str=name.." = "..base..":addListBox("..
    varToStr(box.x)..","..varToStr(box.y)..","..
    varToStr(box.w)..","..varToStr(box.h)..","..
    serialization.serialize(box.list)..")"
  return str
end

local createType={
  frame=createFrame,
  label=createLabel,
  button=createButton,
  textField=createField,
  scrollBarH=createScrollBarH,
  scrollBarV=createScrollBarV,
  listBox=createListBox,
}

--io.read()
local file=io.open("output.lua","w")

file:write("--"..(parsedgml.meta.title or "unnamed gml").."\n")
file:write("--gml written by "..(parsedgml.meta.author or "anonymous").."\n")
file:write("--lua auto-generated by gmlc\n")
if parsedgml.meta.desc then
  file:write("--"..parsedgml.meta.desc.."\n")
end
file:write()
local baseName=parsedgml.gui.name
file:write('local gml=require("gml")\n')

for i=1,#parsedgml.code.requires do
  local r=parsedgml.code.requires[i]
  file:write('local '..r.."=require(\""..r.."\")\n")
end

local names={baseName}
for k,v in pairs(parsedgml.gui.children) do
  names[#names+1]=k
end
for k,v in pairs(parsedgml.code.functions) do
  names[#names+1]=v.name
end

file:write("\nlocal "..table.concat(names,",").."\n\n")

file:write(createFrame(baseName,baseName,parsedgml.gui).."\n")

for k,v in pairs(parsedgml.gui.children) do
  if createType[v.type] then
    file:write(createType[v.type](baseName,k,v).."\n")
  else
    file:write(v.type.." called "..k.."\n\n")
  end
end
file:write("\n")


for k,v in pairs(parsedgml.code.functions) do
  file:write("function "..v.name.."()\n"..indentCode(2,v.body).."\nend\n\n")
end

for k,v in pairs(parsedgml.code.handlers) do
  file:write(baseName..":addHandler(\""..v.event.."\",\n"..indentCode(4,v.body).."\n)\n\n")
end

file:write(indentCode(0,parsedgml.code.body).."\n")

file:write("\n"..baseName..":run()")

file:close()