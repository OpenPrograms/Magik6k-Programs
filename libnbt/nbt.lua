local math = math
local bit32 = bit32
local computer = require "computer"

data = {}
data.raw = {'\1','\0', '\1' ,'A','\162'}
data.pointer = 1
data.size = #data.raw

data.move = function(data,size)
  size = size or 1
  data.pointer = data.pointer + size
end

data.read = function(data,size)
  size = size or 1
  local result = 0
  for i=1, size do
    result = result * 2^8 + data.raw[data.pointer]:byte()
    data:move()
  end
  return result
end
data.get = function(data,n)
  n = n or 1
  return data.raw[data.pointer+n-1]:byte()
end


data.readByte = function(data)
  local result = data:read()
  return result
end

data.readShort = function(data)
  local result = data:read() * 2^8    -- FF 00
  result = result + data:read() -- FF FF
  if bit32.btest(result, 2^15) then
    return (bit32.extract(bit32.bnot(result),0,16))-1
  end
  return result
  
end

data.readInt = function(data)
  local result = data:read(4) 
  if bit32.btest(result, 2^31) then
    return -bit32.bnot(result) - 1
  end
  return result
  
end

data.readLong = function(data)
  local high = data:readInt()
  local low = data:read(4)
  
  local neg = high < 0
  if neg then
    high = -(high + 1)
    low = bit32.bnot(low)
    return -(high * 2^32 + low) - 1
  end
  return high * 2^32 + low
end

data.readFloat = function(data)
  local sign = 1
  local mantissa = data:get(2) % 128
  for i = 3, 4 do
    mantissa = mantissa * 256 + data:get(i)
  end
  if data:get(1) > 127 then sign = -1 end
  local exponent = (data:get(1) % 128) * 2 + math.floor(data:get(2) / 128)
  data:move(4)
  if exponent == 0 then
    return 0
  end
  mantissa = (math.ldexp(mantissa, -23) + 1) * sign
  return math.ldexp(mantissa, exponent - 127)
end

data.readDouble = function(data)
  local sign = 1
  local mantissa = data:get(2) % 2^4
  for i = 3, 8 do
    mantissa = mantissa * 256 + data:get(i)
  end
  if data:get(1) > 127 then sign = -1 end
  local exponent = (data:get(1) % 128) * 2^4 + math.floor(data:get(2) / 2^4)
  data:move(8)
  if exponent == 0 then
    return 0
  end
  mantissa = (math.ldexp(mantissa, -52) + 1) * sign
  return math.ldexp(mantissa, exponent - 1023)
end

data.readString = function(data)
  local lenght = data:readShort()
  local result = ""
  for i = 1, lenght do
    result = result .. string.char(data:readByte())
  end
  return result
end

data.readByteArray = function(data)
  local result = {}
  for i = 1, data:readInt() do
    result[i] = data:readByte()
  end
  return result
end

data.readList = function(data)
  local result = {}
  local fun = data.readFun[data:readByte()]
  for i = 1, data:readInt() do
    result[i] = fun(data)
  end
  return result
end

data.readIntArray = function(data)
  local result = {}
  for i = 1, data:readInt() do
    result[i] = data:readInt()
  end
  return result
end

data.readCompound = function(data)
  local result = {}
  while data.pointer <= data.size do
    local id = data:readByte()
    if id == 0 then return result end
    result[data:readString()] = data.readFun[id](data)
  end
  return result
end


data.readFun = {
    [1] = data.readByte,
    [2] = data.readShort,
    [3] = data.readInt,
    [4] = data.readLong,
    [5] = data.readFloat,
    [6] = data.readDouble,
    [7] = data.readByteArray, -- read byte array
    [8] = data.readString,
    [9] = data.readList, -- List
    [10] = data.readCompound,
    [11] = data.readIntArray -- Int List
  }

return {
    readFromNBT = function(rawdata)
        data.raw = rawdata
        data.pointer = 1
        data.size = #data.raw
        return data:readCompound()[""]
    end
}

