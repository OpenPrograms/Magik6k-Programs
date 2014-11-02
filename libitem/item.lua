local deflate = require "deflate"
local nbt = require "nbt"
local item = {}

function item.hasTag(itemstack)
    return itemstack.hasTag
end

function item.readTagRaw(itemstack)
    if not item.hasTag(itemstack) then
        error("Item has no NBT tag")
    end
    local out = {}
    deflate.gunzip({input = itemstack.tag,
        output = function(byte)out[#out+1]=string.char(byte)end})
    
    return out
end

function item.readTag(itemstack)
    return nbt.readFromNBT(item.readTagRaw(itemstack))
end

return item

