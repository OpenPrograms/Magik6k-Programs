
--MPT - Minecraft packaging tool
--Made By magik6k
--do whatever you want, there is only one rule(stolen from zlib license):
--
--1. The origin of this software must not be misrepresented; you must not
--claim that you wrote the original software. If you use this software
--in a product, an acknowledgment in the product documentation would be
--appreciated but is not required.
------
--Of course you can modify the program, then, if you want, you can add your
--name to Credits section below
------
--Credits:
--


--[[
function split(text,splitter)
	local rt = {}
	local act = ""
	local x = 1
	while x  <= #text do
		if text:sub(x,x+#splitter-1) == splitter then
			rt[#rt+1]=act
			x = x + #splitter
			act=""
		else
			act = act .. text:sub(x,x)
			x = x + 1
		end
	end
	if act ~= "" then
		rt[#rt+1] = act
	end
	return rt;
end
]]--

function split(text,splitter)
	local rt = {}
	local act = ""
	local x = 1
	while x  <= #text do
		if text:sub(x,x+#splitter-1) == splitter then
			if act ~= "" then
        		rt[#rt+1] = act
        	end
			x = x + #splitter
			act=""
		else
			act = act .. text:sub(x,x)
			x = x + 1
		end
	end
	if act ~= "" then
		rt[#rt+1] = act
	end
	return rt;
end

local opencomputers = os.getenv

local internet = {}
local fs = fs
local term = term or require("term")
local write = term and term.write

local httpHeaders = {
    ["User-Agent"] = "MPT/1.0"
}
local http = http
local shell = shell
local root = "/"
local verbose = false

if opencomputers then
    verbose = true
    root = os.getenv("APTROOT") or "/"
    if not root then
        print("NO APTROOT SET!")
        return
    end

    internet = require("internet")
    shell = require("shell")
    local lfs = require("filesystem")
    fs = {}
    
    for k,v in pairs(lfs) do fs[k]=v end
    
    fs.delete = lfs.remove
    
    fs.open = function(...)
        --print("fopen:",...)
        
        local data = ""
        local dp = 1
        
        local args = {...}
        if args[2] == "r" then
            local th = lfs.open(args[1],"r")
            if th then
                local left = lfs.size(args[1])
                while left > 0 do
                    data = data .. th:read(left)
                    left = left - (left > 2048 and 2048 or left)
                end
                th:close()
            end
        end

        local h = lfs.open(...)
        if not h then return nil end
        local hnd = setmetatable({},{
                __index = function(t,k)
                    return function(...)return h[k](h,...)end
                end
            })
        hnd.writeLine = function(s)
            h:write(s.."\n")
        end
        hnd.readLine = function()
            local sbuf= ""
            while true do
                local c = data:sub(dp,dp)
                dp = dp + 1
                if #c == 0 then c = nil end
                if c == nil then
                    if #sbuf < 1 then
                        return nil
                    end
                    return sbuf
                end
                if c == "\n" then
                    return sbuf
                end
                sbuf = sbuf .. c
            end
        end
        
        return hnd
    end
    
    term = require("term")
    term.setCursorPos = term.setCursor
    term.getCursorPos = term.getCursor
    
    fs.makeDir = function(f)
        local tree = split(f,"/")
        local check = "/"
        for k,val in pairs(tree) do
            check = check .. val
            if not fs.exists(check) then
                fs.makeDirectory(check)
            end
            check = check .. "/"
        end
    end
    fs.isDir = fs.isDirectory
    
    http = {}
    http.get = function(url)
       
        local res = {}
        res.data = ""
        if url ~= "" then
            for line in internet.request(url)do if #res.data < 1 then res.data = line else res.data = res.data .. "\n" .. line end end
            --print("Got " .. tostring(#res.data) .. "B of data")
        else
            res.data = nil
        end
        res.readAll = function()
            return res.data
        end
        res.close = function()end
        return res
    end
end

local dir = root .. "etc/ccpt/"

if not http then
    if not internet then
        error("HTTP API MUST be enabled or internet modem attached to use this program")
    end
end

local argv = {...}

--Pseudo enums

local validator = {ok = 0, installed = 1, file_conflict = 2}

---Pre-definitions

local install = nil
local remove = nil
local ppa_host = "http://cc.nativehttp.org/ppa/vlist/"

---UTILITIES

local downloaded = 0
local proc = ""
local cp = 0

local function dstart()
    if not opencomputers then
        term.clearLine()
        print("\n")
        term.clearLine()
        print("\n")
        term.clearLine()
        local x,y = term.getCursorPos()
        cp = y - 2
    end
end

local function dend()
    if not opencomputers then term.setCursorPos(1,cp+3)end
end

local function stateP(s)--print(s)
    if not opencomputers then
        if not verbose then
            term.setCursorPos(1,cp)
            term.clearLine()
            term.write(s)
        else    
            print(s)
        end
    end
end

local function det1P(s)--print(s)
    if not (verbose or opencomputers) then
        term.setCursorPos(1,cp + 1)
        term.clearLine()
        term.write(s)
    else    
        print(s)
    end
   
end

local function det2P(s)
    if not verbose then
        term.setCursorPos(1,cp + 2)
        term.clearLine()
        term.write(s)
    else    
        print(s)
    end
    
end

local function rState()
    if not opencomputers then
        stateP("DL:"..tostring(downloaded)..", PR:"..proc)
    end
end

local List = {}
function List.new ()
	return {first = 0, last = -1}
end

function List.pushleft (list, value)
	local first = list.first - 1
	list.first = first
	list[first] = value
end

function List.pushright (list, value)
	local last = list.last + 1
	list.last = last
	list[last] = value
end

function List.popleft (list)
	local first = list.first
	if first > list.last then return nil end
	local value = list[first]
	list[first] = nil
	list.first = first + 1
	return value
end

function List.popright (list)
	local last = list.last
	if list.first > last then return nil end
	local value = list[last]
	list[last] = nil 
	list.last = last - 1
	return value
end

local function CGetS(file,name)
	local _cfg = fs.open(file,"r")
	
	if not _cfg then
		error("Could not open configuration file: "..file)
	end
	
	local x = true;
	 
	while x do
		local line = _cfg.readLine()
		if line == nil then
			x = false;
		else
		 
			local side = false
			local prop = ""
			local val = ""
			for a=1,#line do
				if line:sub(a,a) == '=' then
					side = true
				elseif side then
					val =  val .. line:sub(a,a)
				else
					prop = prop .. line:sub(a,a)
				end
			end
			
			if prop == name then
				_cfg.close()
				return val
			end			
		end	 
	end
	_cfg.close()	
end
 
local function CGetN(file,name)
	return tonumber(CGetS(file,name))
end

local function download(file, url)
    if file then det2P("get:"..file) else det2P("get:"..url) end
	local res = http.get(url,httpHeaders)
	if res then
		if file ~= nil then
			fs.delete(file)
			fs.makeDir(file)
			fs.delete(file)
			local fhnd = fs.open(file, "w");
			if fhnd then
				fhnd.write(res.readAll())
				fhnd.close()
				downloaded = downloaded + 1
				rState()
				return res.readAll()
			else
				res.close()
				error("Could not open "..file.." for writing")
			end
	    else
	        rState()
	        downloaded = downloaded + 1
			return res.readAll()
		end
		res.close()
	else
		local rr = 7
	    if r then if rr == 1 then return nil end rr = r end
		det1P("WARNING:Download failed,  Retry in 5sec")
		print("\n",url)
		os.sleep(5)
		
		return download(file,url,rr-1)
	end
end

local function downloadfile(file, url)
    if file then det2P("ocget:"..file) else det2P("ocget:"..url) end
    if not opencomputers then
    	local res = http.get(url,httpHeaders)
    	if res then
    		if file ~= nil then
    			fs.delete(file)
    			fs.makeDir(file)
    			fs.delete(file)
    			local fhnd = fs.open(file, "w");
    			if fhnd then
    				fhnd.write(res.readAll())
    				fhnd.close()
    				downloaded = downloaded + 1
    				rState()
    				return res.readAll()
    			else
    				res.close()
    				error("Could not open "..file.." for writing")
    			end
    	    else
    	        rState()
    	        downloaded = downloaded + 1
    			return res.readAll()
    		end
    		res.close()
    	else
    		local rr = 7
    	    if r then if rr == 1 then return nil end rr = r end
    		det1P("WARNING:Download failed,  Retry in 5sec")
    		print("\n",url)
    		os.sleep(5)
    		
    		return download(file,url,rr-1)
    	end
    else
        if file ~= nil then
			fs.delete(file)
			fs.makeDir(file)
			fs.delete(file)
        end
        --print("sh: ".."wget -q -f "..url.." "..file)
        shell.execute("wget -q -f "..url.." "..file)--fuck it
    end

end

local function downloadln(file, url, r)
    if file then det2P("get:"..file) else det2P("get:"..url) end
	local res = http.get(url,httpHeaders)
	if res then
		if file ~= nil then
			fs.delete(file)
			fs.makeDir(file)
			fs.delete(file)
			local fhnd = fs.open(file, "w");
			if fhnd then
				if opencomputers then fhnd.write(res.readAll())else  end
				fhnd.close()
				return res.readAll()
			else
				res.close()
				error("Could not open "..file.." for writing")
			end
		else
			return res.readAll()
		end
		res.close()
	else
	    local rr = 7
	    if r then if rr == 1 then return nil end rr = r end
		det1P("WARNING:Download failed,  Retry in 5sec")
		print("\n",url)
		os.sleep(5)
		
		return downloadln(file,url,rr-1)
	end
end

-----------------------------------------------------------------
-----------------------------------------------------------------
-----------------------------------------------------------------
---Intarnal functions

local function update_list()
	--local sync = CGetS("/etc/ccpt/config","master")
	--if sync then 
		--download("/etc/ccpt/list",sync)
	proc = "Update"
	rState()
	
	local run = true
	local exec = List.new()
	local num = 0
	
	if fs.exists(dir.."ppa") then
		local sources = fs.open(dir.."ppa","r")	
		if not sources then
			error("Could not open base file: "..dir.."ppa")
		end	
		local x = true
		while x do 
			local line = sources.readLine()
			if line == nil then
				x = false
			else
				det1P("PPA:"..line)
				List.pushright(exec,{prot = "ccpt", data = download(nil,ppa_host..line)})
			end
		end
		sources.close()
	end	
	
	if fs.exists(dir.."ac") then
        local sources = fs.open(dir.."ac","r")	
        if not sources then
			error("Could not open base file: "..dir.."ac")
		end	
        local x = true
        while x do
            local line = sources.readLine()
			if line == nil then
				x = false
			else
				det1P("AC:"..line)
				List.pushright(exec,{prot = "ac", data = download(nil,line .. "/packages.list"), repo = line})
			end
        end
        
        sources.close()
	end
	
	local sources = fs.open(dir.."sources","r")	
	if not sources then
		error("Could not open base file: "..dir.."sources")
	end	
	local x = true
	while x do 
		local line = sources.readLine()
		if line == nil or line == "" then
			x = false
		else
			print("List:"..line)
			List.pushleft(exec,{prot = "ccpt", data = download(nil,line)})
		end
	end
	sources.close()
	
	fs.delete(dir.."list")
	local fhnd = fs.open(dir.."list", "w");
	if fhnd then
		while run do
			local proc = List.popright(exec)
			
			if proc then
			    if proc.prot == "ccpt" then
    				local tline = split(proc.data,"\n")
    				for k,val in pairs(tline) do
    					local row = split(val,";")
    					if row[1] == "p" then
    						fhnd.writeLine(val)
    						num = num + 1
    					elseif row[1] == "s" then
    						det1P("List:"..row[2])
    						local dl = download(nil,row[2])
    						if dl then
    						List.pushright(exec,{prot = "ccpt", data = dl})
    						end
    					end
                    end
			    elseif proc.prot == "ac" then
			        local tline = split(proc.data,"\n")
			        for k,val in pairs(tline) do
                        local row = split(val,"::")
                        fhnd.writeLine("a;" .. row[1] .. ";" .. row[2] .. ";" .. proc.repo .. "/" .. row[1])
    					num = num + 1
		            end
			    end
			else
				run = false
			end
		end
		fhnd.close()
	else
		error("Could not open "..file.." for writing")
	end		
	det2P("Packages defined: "..tostring(num))
end

local function register(name,version,header)
	
	local reg = nil
	
	if fs.exists(dir.."installed") then
		reg = fs.open(dir.."installed","a")
	else
		reg = fs.open(dir.."installed","w")
	end
	
	if reg then
		reg.writeLine(name..";"..tostring(version))
		reg.close()
	else
		error("Critical:Could not register installation")
	end
	
	local freg = nil
	
	if fs.exists(dir.."files") then
		freg = fs.open(dir.."files","a")
	else
		freg = fs.open(dir.."files","w")
	end
	
	if freg then
		local lhead = split(header,"\n")
		local x = 1
		for x = 1, #lhead do
			if split(lhead[x],";")[1] == "f" then
				freg.writeLine(name..";"..split(lhead[x],";")[2])
			elseif split(lhead[x],";")[1] == "u" then
				freg.writeLine(name..";"..split(lhead[x],";")[2])
			end
		end
		freg.close()		
	else
		error("Error:Could not register files")
	end
	
end

local database = nil

local function load_database()
    if not database then
        database = {}
        local base = fs.open(dir.."list","r")
    	
    	if not base then
    		error("Could not open base file: "..dir.."list")
    	end
        
    	local x = true;
    	while x do 
            local line = base.readLine()
    		if line == nil then
    			x = false;
    		else
		        database[#database+1] = line
		    end
        end
        base.close()
    end
end

local function base_find(name)
    load_database()

	for k,line in ipairs(database) do
		local entry = split(line,";")
		if entry[1] == "p" then
			if entry[2] == name then
				local ret = {type="ccpt",name=entry[2],url=entry[4],version=tonumber(entry[3])}
				return ret
			end
        elseif entry[1] == "a" then
            if entry[2] == name then
                local ret = {type="ac",name=entry[2],url=entry[4],version=tonumber(entry[3])}
				return ret
            end
	    end
	end

end

local function validate(pname,header)
	local instbase = fs.open(dir.."installed","r")
	if instbase then
		local x = true
		while x do
			local tline = instbase.readLine()
			if tline == nil then
				x = false
			else
				if pname == split(tline,";")[1] then
					instbase.close()
					return validator.installed
				end
			end
		end
		instbase.close()
	end
	--local filebase = fs.open("/etc/ccpt/files","r")
	if header then
		lhead = split(header,"\n")
		local x = 1
		for x = 1, #lhead do
			if split(lhead[x],";")[1] == "f" then
				if fs.exists(root .. split(lhead[x],";")[2]) then
					det1P("[info]Conflict: "..split(lhead[x],";")[2])
                    if not opencomuters then
                        return validator.file_conflict
					end
				end
			end
		end
	end
	
	return validator.ok
end

local function download_files(url,header)
	local lhead = split(header,"\n")
	local x = 1
	for x = 1, #lhead do
		if split(lhead[x],";")[1] == "f" then
		    if opencomputers then
                downloadfile(root:sub(1,#root-1)..split(lhead[x],";")[2],url..split(lhead[x],";")[2])
            else
			    download(split(lhead[x],";")[2],url..split(lhead[x],";")[2])
			end
		end
		if split(lhead[x],";")[1] == "u" then
		    if opencomputers then
                downloadfile(root:sub(1,#root-1)..split(lhead[x],";")[2],split(lhead[x],";")[3])
            else
			    download(split(lhead[x],";")[2],split(lhead[x],";")[3])
		    end
		end
	end
end

local function run_scripts(url,header)
	local lhead = split(header,"\n")
	local x = 1
	for x = 1, #lhead do
		if split(lhead[x],";")[1] == "s" then
			download("/tmp/ccptpirs",url..split(lhead[x],";")[2])
			if shell.run then shell.run("/tmp/ccptpirs") else shell.execute("/tmp/ccptpirs")end
			fs.delete("/tmp/ccptpirs")
		end
	end
end

local function dep_register(what,onwhat)
	local reg = nil
	
	if fs.exists(dir.."dtree") then
		reg = fs.open(dir.."dtree","a")
	else
		reg = fs.open(dir.."dtree","w")
	end
	
	if reg then
		reg.writeLine(what..";"..onwhat)
		reg.close()
	else
		error("Critical:Could not register dependencies")
	end
end

local function dependencies(header,package)
	local lhead = split(header,"\n")
	local x = 1
	for x = 1, #lhead do
		if split(lhead[x],";")[1] == "d" then
			install(split(lhead[x],";")[2])
			dep_register(package,split(lhead[x],";")[2])
		end
	end
end

local function filelist(package)
	local freg = fs.open(dir.."files","r")
	if freg then
		local ret = {}
		local x = true
		while x do
			local tline = freg.readLine()
			if tline == nil then
				x = false
			else
				row = split(tline,";")
				if row[1] == package then
					ret[#ret+1] = row[2]
				end
			end
		end
		freg.close()
		return ret
	end
end

local function get_deps(package)
	local reg = fs.open(dir.."dtree","r")
	if reg then
		local ret = {}
		local x = true
		while x do
			local tline = reg.readLine()
			if tline == nil then
				x = false
			else
				local row = split(tline,";")
				if row[1] == package then
					ret[#ret+1] = row[2]
				end
			end
		end
		reg.close()
		return ret
	end
end

local function get_refcount(package)
	local reg = fs.open(dir.."dtree","r")
	local ret = 0
	if reg then
		local x = true
		while x do
			local tline = reg.readLine()
			if tline == nil then
				x = false
			else
				local row = split(tline,";")
				if row[2] == package then
					ret = ret + 1
				end
			end
		end
		reg.close()
	end
	return ret
end

local function get_unused(list)
	local x = 1
	local ret = {}
	if list then
		for x = 1, #list do
			if get_refcount(list[x]) == 0 then
				ret[#ret + 1] = list[x]
			end
		end
	end
	return ret
end

local function unregister(package)
	local reg = fs.open(dir.."installed","r")
	local newbase = {}
	if reg then
		local x = true
		while x do
			local tline = reg.readLine()
			if tline == nil then
				x = false
			else
				local row = split(tline,";")
				if row[1] ~= package then
					newbase[#newbase+1] = tline
				end
			end
		end
		reg.close()
	end
	if fs.exists(dir.."installed") then fs.delete(dir.."installed")end
	reg = fs.open(dir.."installed","w")
	if reg then
		local x = 1
		for x = 1, #newbase do
			reg.writeLine(newbase[x])
		end
		reg.close()
	else
		error("CRITICAL: Could not open database for writing")
	end
	reg = fs.open(dir.."files","r")
	newbase = {}
	if reg then
		local x = true
		while x do
			local tline = reg.readLine()
			if tline == nil then
				x = false
			else
				local row = split(tline,";")
				if row[1] ~= package then
					newbase[#newbase+1] = tline
				end
			end
		end
		reg.close()
	end
	fs.delete(dir.."files")
	reg = fs.open(dir.."files","w")
	if reg then
		local x = 1
		for x = 1, #newbase do
			reg.writeLine(newbase[x])
		end
		reg.close()
	else
		error("CRITICAL: Could not open file base for writing")
	end
end

local function deptree_unregister(package)
	local reg = fs.open(dir.."dtree","r")
	local newbase = {}
	if reg then
		local x = true
		while x do
			local tline = reg.readLine()
			if tline == nil then
				x = false
			else
				local row = split(tline,";")
				if row[1] ~= package then
					newbase[#newbase+1] = tline
				end
			end
		end
		reg.close()
	end
	fs.delete(dir.."dtree")
	reg = fs.open(dir.."dtree","w")
	if reg then
		local x = 1
		for x = 1, #newbase do
			reg.writeLine(newbase[x])
		end
		reg.close()
	else
		error("CRITICAL: Could not open dtree database for writing")
	end
end

local function get_installed()
	local reg = fs.open(dir.."installed","r")
	local ret = {}
	if reg then
		local x = true
		while x do
			local tline = reg.readLine()
			if tline == nil then
				x = false
			else
				local row = split(tline,";")
				ret[#ret + 1] = {name = row[1], version = tonumber(row[2])}
			end
		end
		reg.close()
	end
	return ret
end

local function list_upgardable()
	local installed = get_installed()
	local ret = {}
	for k,val in pairs(installed) do
	    --det1P("Searching package "..val.name)
		local bpk = base_find(val.name)
		if bpk then
			if val.version ~= bpk.version then
				ret[#ret + 1] = val.name
			end
		else
			det1P("[Warning]Package "..val.name.." not found in database")
			os.sleep(0.5)
		end
	end
	return ret
end

local function ac_conv_header(head,url)
    local ret = ""
    local tline = split(head,"\n")
    for k,val in pairs(tline) do
        local pt = val:find(":")
        if pt ~= nil then
            local t = val:sub(1,pt-1)
            if t == "Executable" then
                local r = val:sub(pt+2,#val)
                local fr = val:find(" => ")
                if fr ~= nil then
                    local rfn = val:sub(pt+2,fr-1)
                    local lfn = val:sub(fr + 4, #val)
                    if lfn:sub(#lfn,#lfn) ~= "/" then
                        ret = ret .. "\nu;/bin/"..lfn..";"..url.."/bin/"..rfn..".lua"
                    end
                else
                    local fn = r
                    if fn:sub(#fn,#fn) ~= "/" then
                        ret = ret .. "\nu;/bin/" .. fn .. ";" .. url .. "/bin/" .. fn .. ".lua"
                    end
                end
            elseif t == "Library" then
                local r = val:sub(pt+2,#val)
                local fr = val:find(" => ")
                if fr ~= nil then
                    local rfn = val:sub(pt+2,fr-1)
                    local lfn = val:sub(fr + 4, #val)
                    if lfn:sub(#lfn,#lfn) ~= "/" then
                        ret = ret .. "\nu;/lib/"..lfn..";"..url.."/lib/"..rfn..".lua"
                    end
                else
                    local fn = r
                    if fn:sub(#fn,#fn) ~= "/" then
                        ret = ret .. "\nu;/lib/" .. fn .. ";" .. url .. "/lib/" .. fn .. ".lua"
                    end
                end
            elseif t == "Startup" then
                local r = val:sub(pt+2,#val)
                local fr = val:find(" => ")
                if fr ~= nil then
                    local rfn = val:sub(pt+2,fr-1)
                    local lfn = val:sub(fr + 4, #val)
                    if lfn:sub(#lfn,#lfn) ~= "/" then
                        ret = ret .. "\nu;/etc/ac.boot/"..lfn..";"..url.."/startup/"..rfn..".lua"
                    end
                else
                    local fn = r
                    if fn:sub(#fn,#fn) ~= "/" then
                        ret = ret .. "\nu;/etc/ac.boot/" .. fn .. ";" .. url .. "/startup/" .. fn .. ".lua"
                    end
                end
            elseif t == "Dependency" then
                local r = val:sub(pt+2,#val)
                ret = ret .. "\nd;" .. r
            end
            
        end
    end
    return ret
end


local function ppaadd(name)
    proc = "ppa "..name
    rState()
	local list = {}
	local fh={}
	if fs.exists(dir.."ppa") then
		local reg = fs.open(dir.."ppa","r")
		if reg then
			local x = true
			while x do
    			local ln = reg.readLine()
    			if ln == nil then
    				x = false
    			else
    				if ln == name then
    					print("PPA added")
    					reg.close()
    					return
    				end
    				list[#list + 1] = ln
    			end
			end
			reg.close()
		end
	end
	list[#list + 1] = name
	local reg = fs.open(dir.."ppa","w")
	if reg then
		for k,v in pairs(list) do
			reg.writeLine(v)
		end
    reg.close()
    end
	update_list()
	det1P("PPA added!")
end

local function pparm(name)
    proc = "rm ppa "..name
    rState()
    local list = {}
    if fs.exists(dir.."ppa") then
        local reg = fs.open(dir.."ppa","r")
		if reg then
            local x = true
			while x do
                local ln = reg.readLine()
                if ln == nil then
                    x = false
                else
                    if ln ~= name then
                        list[#list + 1] = ln
                    end
                end
			end
            reg.close()
	    end
    end
    local reg = fs.open(dir.."ppa","w")
	if reg then
		for k,v in pairs(list) do
			reg.writeLine(v)
		end
    reg.close()
    end
    update_list()
	det1P("PPA removed")
end

local function acadd(url)
    proc = "ac "..url
    rState()
	local list = {}
	local fh={}
	if fs.exists(dir.."ac") then
		local reg = fs.open(dir.."ac","r")
		if reg then
			local x = true
			while x do
			local ln = reg.readLine()
			if ln == nil then
				x = false
			else
				if ln == url then
					print("ac-get repo added")
					reg.close()
					return
				end
				list[#list + 1] = ln
			end
			end
			reg.close()
		end
	end
	list[#list + 1] = url
	local reg = fs.open(dir.."ac","w")
	if reg then
		for k,v in pairs(list) do
			reg.writeLine(v)
		end
	end
	reg.close()
	update_list()
	det1P("ac-get repo added")
end

local function acrm(name)
    proc = "rm ac "..name
    rState()
    local list = {}
    if fs.exists(dir.."ac") then
        local reg = fs.open(dir.."ac","r")
		if reg then
            local x = true
			while x do
                local ln = reg.readLine()
                if ln == nil then
                    x = false
                else
                    if ln ~= name then
                        list[#list + 1] = ln
                    end
                end
			end
            reg.close()
	    end
    end
    local reg = fs.open(dir.."ac","w")
	if reg then
		for k,v in pairs(list) do
			reg.writeLine(v)
		end
    reg.close()
    end
    update_list()
	det1P("ac-get repo removed")
end

install = function (package)
    proc = "ins "..package
    rState()
	--det1P("Reading Database")
	local entry = base_find(package)
	if entry then
	    if entry.type == "ccpt" then
    		--det1P("Downloading package header")
    		local header = download(nil, entry.url..entry.name.."/index")
    		--det1P("Processing")
    		local vres = validate(entry.name,header)
    		if vres == validator.ok then
    			--det1P("Checking dependencies")
    			dependencies(header,package)
    			det1P("Downloading files")
    			download_files(entry.url..entry.name,header)
    			det1P("Setting up")
    			register(package,entry.version,header)
    			run_scripts(entry.url..entry.name,header)
    		elseif vres == validator.installed then
    			det1P("Package already installed")
    		else
    			det1P("File conflict detected!")
    		end
        elseif entry.type == "ac" then
            --det1P("Downloading package header")
            local header = download(nil, entry.url.."/details.pkg")
            --det1P("Processing")
            local chead = ac_conv_header(header,entry.url)
            
            local vres = validate(entry.name,chead)
    		if vres == validator.ok then
    			--det1P("Checking dependencies")
    			dependencies(chead,package)
    			det1P("Downloading files")
    			download_files(entry.url,chead)
    			det1P("Setting up")
    			register(package,entry.version,chead)
    			--run_scripts(entry.url,chead)
    		elseif vres == validator.installed then
    			det1P("Package already installed")
    		else
    			det1P("File conflict detected!")
    		end
    		
		end
	else
		det1P("Package not found!")
	end
end

remove = function (package,nrdeps)
    proc = "rm "..package
    rState()
	--det1P("Reading database")
	if validate(package,nil) == validator.installed then
		det1P("Removing files")
		local list = filelist(package)
		local removed = 0
		if list then
			local x = 1
			for x = 1, #list do
				fs.delete(root..list[x])
				det2P("Remove "..list[x])
				removed = removed + 1
			end
		end
		det1P(tostring(removed).." files removed")
		--det1P("Removing from database")
		unregister(package)
		--det1P("Removing unused dependencies")
		if not nrdeps then
    		local deps = get_deps(package)
    		deptree_unregister(package)
    		local remlist = get_unused(deps)
    		for k,val in pairs(remlist) do
    			remove(val)
    		end
		end
	else
		det1P("Package not installed")
	end
end

local function upgrade()
    dstart()rState()
    
    proc = "Upgrade"
    rState()
	det1P("Updating package list")
	update_list()
	det1P("Upgrading packages")
	local todo = list_upgardable()
	det1P("Upgrading "..tostring(#todo).." packages")
	for k,val in pairs(todo) do
		remove(val,true)
		install(val)
	end
	det1P(tostring(#todo).." Packages upgraded")
	dend()
	print("Upgraded: ")
	for k,v in pairs(todo) do
        write(v.." ")
    end
    --print("\n")
    --term.clearLine()
    --local uu,cy=term.getCursorPos()
    --term.setCursorPos(1,cy)
end

local function ppa()
	if argv[3] == nil  then
		print("Usage:")
		print("mpt ppa add [name]")
		print("mpt ppa remove [name]")
	else
		if argv[2] == "add" then
			ppaadd(argv[3])
        elseif argv[2] == "remove" then
            pparm(argv[3])
		else
		    print("Usage:")
    		print("mpt ppa add [name]")
    		print("mpt ppa remove [name]")
		end
	end
end

local function ac()
    if argv[3] == nil  then
		print("Usage:")
		print("mpt ac add [name]")
		print("mpt ac remove [name]")
	else
		if argv[2] == "add" then
			acadd(argv[3])
		elseif argv[2] == "remove" then
            acrm(argv[3])
		else
		    print("Usage:")
    		print("mpt ac add [name]")
    		print("mpt ac remove [name]")
		end
	end
end

local function upck()
    if goroutine then
        rStat = function()end
        stateP = function()end
        det1P = function()end
        det2P = function()end
        
        goroutine.spawnBackground("ccptUck",function()
                update_list()
                os.queueEvent("cptupg")
            end)
        local t1 = os.startTimer(1)
        local t2 = os.startTimer(4)
        while true do
            e = {os.pullEvent()}
            if e[1] == "cptupg" then
                local x,y = term.getCursorPos()
                term.clearLine()
                term.setCursorPos(1,y)
                print("[*]MPT: "..tostring(#list_upgardable()).." Upgradable packages")
                return
            elseif e[1] == "timer" then
                if e[2] == t1 then
                    write("[*]MPT: Checking for upgrades")
                elseif e[2] == t2 then
                    local x,y = term.getCursorPos()
                    term.clearLine()
                    term.setCursorPos(1,y)
                    print("[*]MPT: Timed out")
                    --goroutine.kill("ccptUck")
                    print("[*]Coder is too lazy to kill foreground process")
                    return
                end
            end
        end
    end
end

---MAIN CODE


function main()

    if     argv[1] == "init"   then
    	if fs.exists(dir) then
    		print("MPT already initated")
    	else
    		print("Installing directories")
    		fs.makeDir("/etc/")
    		fs.makeDir(dir)
    
    		print("Downloading default configuration")
    		downloadln(dir.."sources","http://cc.nativehttp.org/fresh/sources")
    		downloadln(dir.."installed","http://cc.nativehttp.org/fresh/installed")
    		downloadln(dir.."files","http://cc.nativehttp.org/fresh/files")
    		print("Checking for upgrades")
    		ppaadd("mpt")
    		upgrade()
    	end
    elseif argv[1] == "update" then
        dstart()rState()
    	print("Updating package list")
    	update_list()
    	dend()
    	print("\n")
    elseif argv[1] == "install" then
        dstart()rState()
    	if argv[2] == nil then
    		print("Usage: mpt install [name] ...")
    		dend()
    		print("\n")
    	else
    		for i = 2, #argv do
                install(argv[i])
            end
            dend()
            print("\n")
    	end
    elseif argv[1] == "remove" then
        dstart()rState()
    	if argv[2] == nil then
    		print("Usage: mpt remove [name] ...")
    		dend()
    		print("\n")
    	else
    	    for i = 2, #argv do
    		    remove(argv[i])
    		end
    		dend()
    		print("\n")
    	end
    elseif argv[1] == "upgrade" then
    	upgrade()
    	print("\n")
    elseif argv[1] == "ppa" then
        dstart()rState()
    	ppa()
    	dend()
    	print("\n")
    elseif argv[1] == "ac" then
        dstart()rState()
    	ac()
    	dend()
    	print("\n")
    elseif argv[1] == "upck" then --update check on startup
        upck()
        print("\n")
    elseif argv[1] == "api" then
        
    elseif argv[1]:sub(1,1) == "-" then --pcman mode
    	
        local doSync = nil
        local doUpdate = false
        local doUpgrade = false
        local doRemove = nil
        
        local list = {}
        
        for i = 1, #argv do
            if argv[i]:sub(1,1) == "-" then
                for c = 2, #argv[i] do
                    if argv[i]:sub(c,c) == "S" then
                        if doSync or doRemove then
                            error("Wrong use of -S")
                        end
                        doSync = true
                    elseif argv[i]:sub(c,c) == "R" then
                        if doSync or doRemove then
                            error("Wrong use of -R")
                        end
                        doRemove = true
                        
                    elseif argv[i]:sub(c,c) == "y" then
                        doUpdate = true
                    elseif argv[i]:sub(c,c) == "u" then
                        doUpgrade = true
                    end
                end
            else
                list[#list + 1] = argv[i]
            end
        end
        
        if doUpdate then 
            dstart()rState()
            print("Updating package list")
            update_list()
            dend()
            print("\n")
        end
        if doUpgrade then
            upgrade()
            print("\n")
        end
        if doSync then
            for k,v in ipairs(list) do
                install(v)
            end
        end
        if doRemove then
            for k,v in ipairs(list) do
                remove(v)
            end
        end
    	
    else
    	print("Usage:")
    	print("mpt init")
    	print("mpt install [name]")
    	print("mpt remove [name]")
    	print("mpt update")
    	print("mpt upgrade")
    	print("mpt ppa")
    	print("mpt ac")
    	print("")
    	print("Basic pacman syntax is supported:")
    	print("-S, -R, -Sy, -Su")
    end

end

if opencomputers then
    xpcall(main, function(err) print (debug.traceback(err)) end)
else
    main()
end

--API

if not opencomputers then

    if _G.ccpt then
    	_G.ccpt = nil
    end
    _G.ccpt = {}
    
    _G.ccpt.update = update_list
    _G.ccpt.upgrade = upgrade
    _G.ccpt.install = install
    _G.ccpt.remove = remove
    
    _G.ccpt.ppa = {}
    _G.ccpt.ppa.add = ppaadd
    _G.ccpt.ppa.remove = pparm
    
    _G.ccpt.ac = {}
    _G.ccpt.ac.add = acadd
    _G.ccpt.ac.remove = acrm
    
    
    _G.mpt = _G.ccpt

end





