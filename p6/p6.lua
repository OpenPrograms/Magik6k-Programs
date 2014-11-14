local prepare
local posix = {}
local rom = {}
local computer = computer
local component = component
local unicode = unicode
local status, dofile, loadfile
local acG = nil

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

do
  _G._OSVERSION = "p6 core/1.0"

  

  -- Low level dofile implementation to read filesystem libraries.
  --local rom = {}
  function rom.invoke(method, ...)
    return component.invoke(computer.getBootAddress(), method, ...)
  end
  function rom.open(file) return rom.invoke("open", file) end
  function rom.read(handle) return rom.invoke("read", handle, math.huge) end
  function rom.close(handle) return rom.invoke("close", handle) end
  function rom.inits() return ipairs(rom.invoke("list", "boot")) end
  function rom.isDirectory(path) return rom.invoke("isDirectory", path) end

  local screen = component.list('screen')()
  for address in component.list('screen') do
    if #component.invoke(address, 'getKeyboards') > 0 then
      screen = address
    end
  end

  -- Report boot progress if possible.
  local gpu = component.list("gpu")()
  local w, h
  if gpu and screen then
    component.invoke(gpu, "bind", screen)
    w, h = component.invoke(gpu, "getResolution")
    component.invoke(gpu, "setResolution", w, h)
    component.invoke(gpu, "setBackground", 0x000000)
    component.invoke(gpu, "setForeground", 0xFFFFFF)
    component.invoke(gpu, "fill", 1, 1, w, h, " ")
  end
  local y = 1
  status = function(...)
    local msg = ""
    for _,s in ipairs({...})do msg = msg.." "..tostring(s) end
    for line in msg:gmatch("[^\n]+") do
      if gpu and screen then
        component.invoke(gpu, "set", 1, y, line)
        if y == h then
          component.invoke(gpu, "copy", 1, 2, w, h - 1, 0, -1)
          component.invoke(gpu, "fill", 1, h, w, 1, " ")
        else
          y = y + 1
        end
      end
    end
  end

  status("Booting " .. _OSVERSION .. "...")

  -- Custom low-level loadfile/dofile implementation reading from our ROM.
  loadfile = function(file)
    status("> " .. file.. (acG and(" -E "..tostring(acG))or("")))
    local handle, reason = rom.open(file)
    if not handle then
      error(reason)
    end
    local buffer = ""
    repeat
      local data, reason = rom.read(handle)
      if not data and reason then
        error(reason)
      end
      buffer = buffer .. (data or "")
    until not data
    rom.close(handle)
    return load(buffer, "=" .. file,nil,acG)
  end

  dofile = function(file)
    local program, reason = loadfile(file)
    if program then
      local result = table.pack(pcall(program))
      if result[1] then
        return table.unpack(result, 2, result.n)
      else
        error(result[2])
      end
    else
      error(reason)
    end
  end

end


local function sandbox()
    local sb = 
    {
        assert = assert,
        --error = function(...)status("E:",...)status(debug.traceback())error(...)end,
        error = error,
        _G = nil,
        getmetatable = getmetatable,
        ipairs = ipairs,
        load = load,
        loadfile = loadfile,
        next = next,
        pairs = pairs,
        pcall = pcall,
        print = print,
        rawequal = rawequal,
        rawget = rawget,
        rawlen = rawlen,
        rawset = rawset,
        select = select,
        setmetatable = setmetatable,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        _VERSION = "Lua 5.2",
        xpcall = xpcall,
        coroutine = {
            create = coroutine.create,
            resume = nil,
            running = coroutine.running,
            status = coroutine.status,
            wrap = nil,--todo
            yield = nil
        },
        string = {
            byte = string.byte,
            char = string.char,
            dump = string.dump,
            find = string.find,
            format = string.format,
            gmatch = string.gmatch,
            gsub = string.gsub,
            len = string.len,
            lower = string.lower,
            match = string.match,
            rep = string.rep,
            reverse = string.reverse,
            sub = string.sub,
            upper = string.upper
        },
        table = {
            concat = table.concat,
            insert = table.insert,
            pack = table.pack,
            remove = table.remove,
            sort = table.sort,
            unpack = table.unpack
        },
        math = {
            abs = math.abs,
            acos = math.acos,
            asin = math.asin,
            atan = math.atan,
            atan2 = math.atan2,
            ceil = math.ceil,
            cos = math.cos,
            cosh = math.cosh,
            deg = math.deg,
            exp = math.exp,
            floor = math.floor,
            fmod = math.fmod,
            frexp = math.frexp,
            huge = math.huge,
            ldexp = math.ldexp,
            log = math.log,
            max = math.max,
            min = math.min,
            modf = math.modf,
            pi = math.pi,
            pow = math.pow,
            rad = math.rad,
            random = math.random,
            randomseed = math.randomseed,
            sin = math.sin,
            sinh = math.sinh,
            sqrt = math.sqrt,
            tan = math.tan,
            tanh = math.tanh
        },
        bit32 = {
            arshift = bit32.arshift,
            band = bit32.band,
            bnot = bit32.bnot,
            bor = bit32.bor,
            btest = bit32.btest,
            bxor = bit32.bxor,
            extract = bit32.extract,
            replace = bit32.replace,
            lrotate = bit32.lrotate,
            lshift = bit32.lshift,
            rrotate = bit32.rrotate,
            rshift = bit32.rshift
        },
        io = nil,
        os = {
            clock = os.clock,
            date = os.date,
            difftime = os.difftime,
            execute = os.execute,
            exit = os.exit,
            remove = os.remove,
            rename = os.rename,
            time = os.time,
            tmpname = os.tmpname
        },
        rom = {
            open = rom.open,
            read = rom.read,
            close = rom.close,
            inits = rom.inits,
            isDirectory = rom.isDirectory
        },
        debug = {
            traceback = debug.traceback
        },
        status = status,
        require = require,
        dofile = dofile,
        loadfile = loadfile,
        
        --custom functions
        _p6 = {
            version = 0,
            mt = true
        },
        posix = {
            spawn = posix.spawn,
            spawnInit = posix.spawnInit,
            read = posix.read,
            write = posix.write,
            close = posix.close,
            pipe = posix.pipe,
            signal = posix.signal,
            ps = posix.ps,
            setIPC = posix.setIPC,
            getIPC = posix.getIPC,
            callIPC = posix.callIPC
        },
        computer = deepcopy(computer),
        component = deepcopy(component),
        unicode = deepcopy(unicode),
        checkArg = checkArg
    }
    
    sb.coroutine.resume = function(c,...)
        local r
        local par = {...}
        repeat
            r = {coroutine.resume(c,table.unpack(par))}
            if r[1] and r[2] then
                par = {coroutine.yield(true, table.unpack(r,3))}
            else
                return r[1], r[1] and table.unpack(r,3) or r[2]
            end
        until not r[1] or not r[2]
        return r[1], r[1] and table.unpack(r,3) or r[2] 
    end
    sb.coroutine.yield = function(...)return coroutine.yield(false, ...) end
    sb.computer.pullSignal = function(...)return coroutine.yield(true ,...)end
    
    sb._G = sb
    return sb
end

local _K = sandbox()

function _K.panic()
    status("KERNEL PANIC")
    while true do computer.pullSignal() end
end

---------KERNEL MEMORY

local kmem = {}

kmem.fd = {}

kmem.ipcCall = {}

kmem.proc = {}
kmem.processSignals = {}

---------USER IPC(non standard!)

function posix.setIPC(name, func)
    kmem.ipcCall[name] = func
end

function posix.getIPC(name)
    return kmem.ipcCall[name]
end

function posix.callIPC(name, ...)
    return kmem.ipcCall[name](...)
end

---------FILE CORE

function posix.read(fd, count)
    checkArg(1, fd, "number")
    local count = (type(count) == "number") and count or -1 -- -1 means read as much as possible
    
    if kmem.fd[fd] and kmem.fd[fd].flags.r then
        return kmem.fd[fd].proxy.read(fd,count)
    else
        error("File is closed or not readable")
    end
end

function posix.write(fd, data)
    checkArg(1, fd, "number")
    checkArg(1, data, "string")
    
    if kmem.fd[fd]  and kmem.fd[fd].flags.w then
        return kmem.fd[fd].proxy.write(fd,data)
    else
        error("File is closed or not writable")
    end
    
end

function posix.close(fd)
    checkArg(1, fd, "number")
    local res = false
    
    if kmem.fd[fd] then
        res = kmem.fd[fd].proxy.close(fd)
        kmem.fd[fd] = nil
    end
    return res
end

---------FILE CORE END
---------FILE UTILS

kmem.fds = 0
local function fdAlloc()
    kmem.fds = kmem.fds + 1
    return kmem.fds
end

local function mkfd(r,w)
    local fd = {}
    fd.flags = {r=r,w=w}
    return fd
end

kmem.fileProxy = {}


---------FILE UTILS END
---------PIPE

kmem.fileProxy.pipe = {}

function kmem.fileProxy.pipe.read(fd,count)
    if kmem.fd[fd].data.endpoints ~= 2 then error("Broken pipe") end
    local res = kmem.fd[fd].data.buf:sub(1,count)
    kmem.fd[fd].data.buf = (count >= 0) and kmem.fd[fd].data.buf:sub(count+1) or ""
    return res
end

function kmem.fileProxy.pipe.write(fd,data)
    if kmem.fd[fd].data.endpoints ~= 2 then error("Broken pipe") end
    kmem.fd[fd].data.buf = kmem.fd[fd].data.buf .. data
    return #data
end

function kmem.fileProxy.pipe.close(fd)
    kmem.fd[fd].data.endpoints = kmem.fd[fd].data.endpoints - 1
    kmem.fd[fd].data.buf = nil
    return true
end

function posix.pipe()
    local fdOut, fdIn = fdAlloc(),fdAlloc()
    
    local data = {buf = "", endpoints = 2}
    
    kmem.fd[fdOut] = mkfd(true,false)
    kmem.fd[fdIn] = mkfd(false,true)
    
    kmem.fd[fdOut].data = data
    kmem.fd[fdIn].data = data
    
    kmem.fd[fdIn].proxy = kmem.fileProxy.pipe
    kmem.fd[fdOut].proxy = kmem.fileProxy.pipe
    
    return fdOut, fdIn
end

---------PIPE END
---------THREADING

function posix.spawnInit(tfn)
    
    local process = {}
    process._ENV = sandbox()
    process.rt = coroutine.create(load(tfn,"=init",nil,process._ENV))
    process.name = "[init]"
    process.globalSignals = true
    local pid = #kmem.proc+1
    kmem.proc[pid] = process
    
    return pid
    
end

function posix.spawn(tfn, name, noglobal)
    
    local process = {}
    local parrentEnv = (acG or sandbox())
    process._ENV = setmetatable({}, {__index = function(_,i)return parrentEnv[i]end})
    process.rt = coroutine.create(load(tfn,"="..name or "process",nil,process._ENV))
    process.name = name or "!noname"
    process.globalSignals = not noglobal
    local pid = #kmem.proc+1
    kmem.proc[pid] = process
    
    return pid
    
end
---------THREADING UTILS

function posix.ps()
    
    local res = {}
    
    for pid, p in pairs(kmem.proc) do
        res[#res + 1] = {
            pid = pid,
            name = p.name
        }
    end
    
    return res
end

function posix.signal(pid, ...)
    if not kmem.processSignals[pid] then kmem.processSignals[pid] = {} end
    kmem.processSignals[pid][#kmem.processSignals[pid]+1] = {...}
end

---------PREINIT

local function bootInit()
    local handle, reason = rom.open("/lib/modules/init.lua")
    if not handle then
      error(reason)
    end
    local buffer = ""
    repeat
      local data, reason = rom.read(handle)
      if not data and reason then
        error(reason)
      end
      buffer = buffer .. (data or "")
    until not data
    rom.close(handle)
    posix.spawnInit(buffer)
end

bootInit()

---------TASKER

local deadln = math.huge

do
    status("Begin MT mode")
    computer.pushSignal("boot")
    while true do
        local dl = deadln - computer.uptime()
        if dl > 10 then dl=10 end
        local sig = {computer.pullSignal(dl)}
        deadln = math.huge
        
        for k,process in pairs(kmem.proc) do --process global signals
            if process.globalSignals then
                --status("                         S:",table.unpack(sig))
                acG = process._ENV
                local res 
                repeat
                    res = {coroutine.resume(process.rt, table.unpack(sig))}
                    --status("[Kdbg]ThRESM:",table.unpack(res))
                until not res[1] or res[2] --res 2 means user yield
                acG = nil
                --status("[Kdbg]ThPT:"..tostring(res[3]))
                if res[1] and type(res[3]) == "number" then
                    deadln = math.min(deadln, res[3] + computer.uptime())
                end
                
                --status(table.unpack(res))
            end
        end
    end
    
end

_K.panic()
