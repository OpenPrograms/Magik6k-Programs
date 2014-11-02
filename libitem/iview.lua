local item = require "item"
local term = require "term"
local component = require "component"
local serialization = require "serialization"

local args = {...}

print("getting controller")
local cont = component.inventory_controller

print("getting stack")
local stack = cont.getStackInSlot(tonumber(args[1]),tonumber(args[2]))

if args[3] == "p" then
    print("Reding raw:")
    local ln = ""
    for k,v in ipairs(item.readTagRaw(stack))do
        
        ln = ln .. (tostring(v:byte()))
        for i=1,3 - tostring(v:byte()):len()do ln = ln ..(" ") end
        if v:match("[a-z-A-Z0-9]") then
            ln = ln .. ("["..v.."],")
        else
            ln = ln .. ("   ,")
        end
        if k%16==0 then
            print (ln)
            ln = ""
        end
    end
    print(ln)
end
if args[3] == "r" then
    local s = ""
    for k,v in ipairs(item.readTagRaw(stack))do
        s = s .. "\\" .. tostring(v:byte())
    end
    
    for i = 1, #s, 80 do
        print(s:sub(i,i+79))
    end
end

print("Decode NBT")
local tag = item.readTag(stack)

print("Serialize NBT")
local d = serialization.serialize(tag)
print("TAG("..tostring(#d).."):")

for i = 1, #d, 80 do
    print(d:sub(i,i+79))
end




