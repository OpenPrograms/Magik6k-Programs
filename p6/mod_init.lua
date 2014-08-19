do
  status("MT Mode begin")
  _G._OSVERSION = "OpenOS 1.2(p6 kernel/MT)"
  
  
  local loadfile = function(file)
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
    return load(buffer, "=" .. file,nil,_G)
  end

  local dofile = function(file)
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


  
  
  status("Initializing package management...")

  -- Load file system related libraries we need to load other stuff moree
  -- comfortably. This is basically wrapper stuff for the file streams
  -- provided by the filesystem components.
  local package = dofile("/lib/package.lua")

  do
    -- Unclutter global namespace now that we have the package module.
    
    local computer = computer
    local component = component
    local unicode = unicode
    
    _G.component = nil
    _G.computer = nil
    _G.process = nil
    _G.unicode = nil

    -- Initialize the package module with some of our own APIs.
    package.preload["buffer"] = loadfile("/lib/buffer.lua")
    package.preload["component"] = function() return component end
    package.preload["computer"] = function() return computer end
    package.preload["filesystem"] = loadfile("/lib/filesystem.lua")
    package.preload["io"] = loadfile("/lib/io.lua")
    package.preload["unicode"] = function() return unicode end
    
    package.preload["posix"] = function() return posix end

    -- Inject the package and io modules into the global namespace, as in Lua.
    _G.package = package
    _G.io = require("io")
  end
  
  
  status("Initializing file system...")

  -- Mount the ROM and temporary file systems to allow working on the file
  -- system module from this point on.
  local filesystem = require("filesystem")
  local computer = require("computer")
  local component = require("component")
  _G.io = require("io")
  
  filesystem.mount(computer.getBootAddress(), "/")

  status("Running boot scripts...")

  -- Run library startup scripts. These mostly initialize event handlers.
  local scripts = {}
  for _, file in rom.inits() do
    local path = "boot/" .. file
    if not rom.isDirectory(path) then
      table.insert(scripts, path)
    end
  end
  table.sort(scripts)
  for i = 1, #scripts do
    dofile(scripts[i])
  end

  -- Initialize process module.
  require("process").install("/init.lua", "init")

  status("Initializing components...")

  for c, t in component.list() do
    computer.pushSignal("component_added", c, t)
  end
  os.sleep(0.5) -- Allow signal processing by libraries.
  computer.pushSignal("init") -- so libs know components are initialized.

  status("Starting shell...")
end


local function motd()
    local f = io.open("/etc/motd")
    if not f then
        return
    end
    if f:read(2) == "#!" then
        f:close()
        os.execute("/etc/motd")
    else
        f:seek("set", 0)
        print(f:read("*a"))
        f:close()
    end
end

while true do
    require("term").clear()
    motd()
    local result, reason = os.execute(os.getenv("SHELL"))
    if not result then
        io.stderr:write((tostring(reason) or "unknown error") .. "\n")
        print("Press any key to continue.")
        os.sleep(0.5)
        require("event").pull("key")
    end
end


