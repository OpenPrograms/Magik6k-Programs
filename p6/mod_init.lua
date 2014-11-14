do
  status("MT Mode begin")
  _G._OSVERSION = "OpenOS 1.4(p6 kernel/MT)"
  
  local component = component
  local computer = computer
  local unicode = unicode
  
  -- Runlevel information.
  local runlevel, shutdown = "S", computer.shutdown
  computer.runlevel = function() return runlevel end
  computer.shutdown = function(reboot)
    runlevel = reboot and 6 or 0
    if os.sleep then
      computer.pushSignal("shutdown")
      os.sleep(0.1) -- Allow shutdown processing.
    end
    shutdown(reboot)
  end
  
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
  
  local primaries = {}
  for c, t in component.list() do
    local s = component.slot(c)
    if not primaries[t] or (s >= 0 and s < primaries[t].slot) then
      primaries[t] = {address=c, slot=s}
    end
    computer.pushSignal("component_added", c, t)
  end
  for t, c in pairs(primaries) do
    component.setPrimary(t, c.address)
  end
  os.sleep(0.5) -- Allow signal processing by libraries.
  computer.pushSignal("init") -- so libs know components are initialized.

  status("Initializing system...")
  require("term").clear()
  os.sleep(0.1) -- Allow init processing.
  --status("Starting shell")
  --computer.pushSiganl("start")
  runlevel = 1
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
  motd()
  local result, reason = os.execute(os.getenv("SHELL"))
  if not result then
    io.stderr:write((tostring(reason) or "unknown error") .. "\n")
    print("Press any key to continue.")
    os.sleep(0.5)
    require("event").pull("key")
  end
  require("term").clear()
end


