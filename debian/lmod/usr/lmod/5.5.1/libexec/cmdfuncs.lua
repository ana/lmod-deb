--------------------------------------------------------------------------
-- Lmod License
--------------------------------------------------------------------------
--
--  Lmod is licensed under the terms of the MIT license reproduced below.
--  This means that Lmod is free software and can be used for both academic
--  and commercial purposes at absolutely no cost.
--
--  ----------------------------------------------------------------------
--
--  Copyright (C) 2008-2014 Robert McLay
--
--  Permission is hereby granted, free of charge, to any person obtaining
--  a copy of this software and associated documentation files (the
--  "Software"), to deal in the Software without restriction, including
--  without limitation the rights to use, copy, modify, merge, publish,
--  distribute, sublicense, and/or sell copies of the Software, and to
--  permit persons to whom the Software is furnished to do so, subject
--  to the following conditions:
--
--  The above copyright notice and this permission notice shall be
--  included in all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
--  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--  NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
--  THE SOFTWARE.
--
--------------------------------------------------------------------------

-------------------------------------------------------------------------
-- The command functions: The all the user commands are implemented here.
-------------------------------------------------------------------------

require("strict")
require("myGlobals")
require("string_utils")
require("escape")
require("TermWidth")
require("fileOps")
require("utils")
local BeautifulTbl = require('BeautifulTbl')
local ColumnTable  = require('ColumnTable')
local MName        = require("MName")
local Spider       = require("Spider")
local concatTbl    = table.concat
local dbg          = require("Dbg"):dbg()
local getenv       = os.getenv
local hook         = require("Hook")
local lfs          = require("lfs")
local posix        = require("posix")
local pack         = (_VERSION == "Lua 5.1") and argsPack or table.pack
local unpack       = unpack or table.unpack

--------------------------------------------------------------------------
-- Access(): Both Help and Whatis functions funnel their actions through
-- the Access function. MC_Access defines real functions for both M.help
-- and M.access.  The mcp.accessMode function activates one or the other
-- depending on what mode Access is called with.

local function Access(mode, ...)
   local master    = Master:master()
   local masterTbl = masterTbl()
   dbg.start{"Access(", concatTbl({...},", "),")"}
   mcp = MasterControl.build("access", mode)
   mcp.accessMode(mode,true)

   local n = select('#',...)
   if (n < 1) then
      pcall(pager, io.stderr, masterTbl.cmdHelpMsg, "\n", Usage(), "\n",
            version())
      dbg.fini("Access")
      return
   end

   master:access(...)
   mcp.accessMode(mode,false)
   dbg.fini("Access")
end

--------------------------------------------------------------------------
-- findNamedCollections:  This helper function walks the ~/.lmod.d
-- directory and reports back the list of named collections.
-- Note that names that start with "." or end with "~" or start with
-- "__" are ignored.

local function findNamedCollections(a,path)
   if (not isDir(path)) then return end
   for file in lfs.dir(path) do
      if (file:sub(1,1) ~= "." and file:sub(-1) ~= "~" and
          file:sub(1,2) ~= "__") then
         local f    = pathJoin(path,file)
         local attr = lfs.attributes(f)
         if (attr and attr.mode == "directory") then
            findNamedCollections(a,f)
         else
            a[#a+1] = f
         end
      end
   end
end

------------------------------------------------------------------------
-- Avail(): just convert the vararg into an actual array and call
--          master.avail to do the real work.

function Avail(...)
   local master = Master:master()
   local arg    = pack(...)
   master.avail(arg)
end

--------------------------------------------------------------------------
-- GetDefault(): get the command line argument and use MT:getMTfromFile()
--               to read the module table from the file and use that
--               collections of module to load.  This routine is deprecated
--               and will be removed.  Use restore instead.


function GetDefault(a)
   a          = a or "default"
   dbg.start{"GetDefault(",a,")"}

   local path = pathJoin(os.getenv("HOME"), ".lmod.d", a)
   local mt   = MT:mt()
   mt:getMTfromFile{fn=path, name=a}
   dbg.fini("GetDefault")
end

--------------------------------------------------------------------------
-- Help():  Define the prtHdr function and use the helper function Access()
--          to report the Help message to the user.

function Help(...)

   prtHdr = function()
      local twidth    = TermWidth()
      local middleStr = "Module Specific Help for \"" .. ModuleName .. "\""
      local title     = banner:bannerStr(middleStr)
      io.stderr:write("\n")
      io.stderr:write(title, "\n")
   end

   Access("help",...)
end

--------------------------------------------------------------------------
-- Keyword(): Use the list of user requested keywords to be searched
--            through the spider cache.


function Keyword(...)
   dbg.start{"Keyword(",concatTbl({...},","),")"}

   local master  = Master:master()
   local cache   = Cache:cache()
   local moduleT = cache:build()
   local s
   local dbT = {}
   local spider = Spider:new()
   spider:searchSpiderDB({...},{"default"},moduleT, dbT)
   local a = {}
   local ia = 0

   local border = banner:border(0)

   ia = ia+1; a[ia] = "\n"
   ia = ia+1; a[ia] = border
   ia = ia+1; a[ia] = "The following modules match your search criteria: \""
   ia = ia+1; a[ia] = concatTbl({...},"\", \"")
   ia = ia+1; a[ia] = "\"\n"
   ia = ia+1; a[ia] = border
   ia = ia+1; a[ia] = "\n"

   spider:Level0Helper(dbT,a)
   pcall(pager,io.stderr,concatTbl(a,""))

   dbg.fini("Keyword")
end

--------------------------------------------------------------------------
-- List(): List the loaded modulefile


function List(...)
   dbg.start{"List(...)"}
   local masterTbl = masterTbl()
   local mt = MT:mt()
   local totalA = mt:list("userName","any")
   if (#totalA < 1) then
      LmodWarning("No modules installed\n")
      dbg.fini("List")
      return
   end

   local wanted = pack(...)

   local msg     = "Currently Loaded Modules"
   local activeA = mt:list("short","active")
   local a       = {}
   local msg2    = ":"

   if (wanted.n == 0) then
      wanted[1] = ".*"
      wanted.n  = 1
   else
      msg2 = " Matching: " .. table.concat(wanted," or ")
      if (not masterTbl.regexp) then
         for i = 1, wanted.n do
            wanted[i] = caseIndependent(wanted[i])
         end
      end
   end

   if (masterTbl.terse) then
      for i = 1,#activeA do
         local mname = MName:new("mt",activeA[i])
         local sn    = mname:sn()
         local full  = mt:fullName(sn)
         for j = 1, wanted.n do
            local p = wanted[j]
            if (full:find(p)) then
               io.stderr:write(full,"\n")
            end
         end
      end
      dbg.fini("List")
      return
   end

   io.stderr:write("\n",msg,msg2,"\n")
   local kk = 0
   local legendT = {}
   for i = 1, #activeA do
      local mname = MName:new("mt",activeA[i])
      local sn    = mname:sn()
      local full  = mt:fullName(sn)
      for j = 1, wanted.n do
         local p = wanted[j]
         if (full:find(p)) then
            kk = kk + 1
            a[#a + 1] = mt:list_property(kk, sn, "short", legendT)
         end
      end
   end

   if (kk == 0) then
      io.stderr:write("  None found.\n")
   else
      local ct = ColumnTable:new{tbl=a, gap=0, len=length}
      io.stderr:write(ct:build_tbl(),"\n")
   end

   if (next(legendT)) then
      local term_width = TermWidth()
      io.stderr:write("\n  Where:\n")
      a = {}
      for k, v in pairsByKeys(legendT) do
         a[#a+1] = { "   " .. k ..":", v}
      end
      local bt = BeautifulTbl:new{tbl=a, column = term_width-1}
      io.stderr:write(bt:build_tbl(),"\n")
   end
   a = {}
   kk = 0

   for i = 1, #totalA do
      local v = totalA[i]
      if (not mt:have(v.sn,"active")) then
         local name = v.name
         for j = 1, wanted.n do
            local p = wanted[j]
            if (name:find(p)) then
               kk      = kk + 1
               a[#a+1] = {"  " .. tostring(kk).. ")" , name}
            end
         end
      end
   end

   if (#a > 0) then
      io.stderr:write("\nInactive Modules",msg2,"\n")
      local ct = ColumnTable:new{tbl=a,gap=0}
      io.stderr:write(ct:build_tbl(),"\n")
   end

   local aa = {}
   aa = hook.apply("msgHook","list",aa)
   if (#aa > 0) then
      io.stderr:write(concatTbl(aa,""))
   end

   dbg.fini("List")
end


------------------------------------------------------------------------
-- Load_Try():  load modules from users but do not issue warnings
--              if the module is not there.

function Load_Try(...)
   local master = Master:master()
   local mt     = MT:mt()

   dbg.start{"Load_Try(",concatTbl({...},", "),")"}
   deactivateWarning()
   Load_Usr(...)
   activateWarning()
   dbg.fini("Load_Try")
end

------------------------------------------------------------------------
-- Load_Usr():  load modules from users.  If a module name has
--              a minus sign in front of it then unload it.  Do that
--              before loading any other modules.  Also if the
--              shortName of a request module is already loaded then
--              unload it.  This way:
--                   $ module load foo/1.1; module load foo/1.3
--              the second load of "foo" will not load it twice.
--              Finally any successful loading of a module is registered
--              with "MT" so that when a user does the above commands
--              it won't get the swap message.

function Load_Usr(...)
   LMOD_IGNORE_CACHE = true
   local master = Master:master()
   local mt     = MT:mt()

   dbg.start{"Load_Usr(",concatTbl({...},", "),")"}
   local uA = {}
   local lA = {}
   local arg = pack(...)
   for i = 1, arg.n do
      local v = arg[i]
      if (v:sub(1,1) == "-") then
         uA[#uA+1] = MName:new("mt", v:sub(2))
      else
         if (v:sub(1,1) == "+") then
            v = v:sub(2)
         end
         local mname = MName:new("load",v)
         local sn    = mname:sn()
         lA[#lA+1]   = mname
      end
   end

   if (#uA > 0) then
      MCP:unload_usr(uA)
   end

   local mcp_old = mcp
   mcp           = MCP
   dbg.print{"Setting mcp to ", mcp:name(),"\n"}
   local b       = mcp:load_usr(lA)
   mcp           = mcp_old

   dbg.fini("Load_Usr")
   return b
end

--------------------------------------------------------------------------
-- Purge():  unload all loaded modules

function Purge(force)
   local master = Master:master()
   local mt     = MT:mt()
   local totalA  = mt:list("short","any")

   if (#totalA < 1) then
      return
   end

   local mA = {}
   for i = #totalA,1,-1 do
      mA[#mA+1] = MName:new("mt",totalA[i])
   end
   dbg.start{"Purge(",concatTbl(totalA,", "),")"}

   MCP:unload_usr(mA,force)

   -- Make Default Path be the new MODULEPATH
   mt:buildMpathA(mt:getBaseMPATH())

   dbg.fini("Purge")
end

--------------------------------------------------------------------------
-- RecordCmd(): Write the current state of the module table to the
--              lmod-save directory.  This command should probably go away.

function RecordCmd()
   dbg.start{"RecordCmd()"}
   local mt   = MT:mt()
   local s    = serializeTbl{indent=true, name="_ModuleTable_",
                             value=_ModuleTable_}
   local uuid = UUIDString(epoch())
   local fn   = pathJoin(usrSaveDir, uuid .. ".lua")

   local d = dirname(fn)
   local attr = lfs.attributes(d)
   if (not attr) then
      mkdir_recursive(d)
   end

   local f = io.open(fn,"w")
   if (f) then
      f:write(s)
      f:close()
   end
   dbg.fini("RecordCmd")
end

--------------------------------------------------------------------------
-- Refresh(): reload all loaded modules so that any alias or shell
--            functions are defined.  No other module commands are active.
--            This command exists so that sub-shells will have the aliases
--            defined.


function Refresh()
   dbg.start{"Refresh()"}
   local master  = Master:master()
   master:refresh()
   dbg.fini("Refresh")
end

--------------------------------------------------------------------------
-- Reset():  Reset all module commands back to the system defined default
--           value in env. var. LMOD_SYSTEM_DEFAULT_MODULES.  If that
--           variable is not defined then there are no default modules
--           and this command is the same as a purge.

function Reset(msg)
   dbg.start{"Reset()"}
   Purge()
   local default = os.getenv("LMOD_SYSTEM_DEFAULT_MODULES") or ""
   dbg.print{"default: \"",default,"\"\n"}

   default = default:trim()
   default = default:gsub(" *, *",":")
   default = default:gsub(" +",":")

   if (msg ~= false) then
      io.stderr:write("Restoring modules to system default\n")
   end

   if (default == "") then
      io.stderr:write("\nThe system default contains no modules\n")
      io.stderr:write("  (env var: LMOD_SYSTEM_DEFAULT_MODULES is empty)\n\n")
      dbg.fini("Reset")
      return
   end


   local a = {}
   for m in default:split(":") do
      dbg.print{"m: ",m,"\n"}
      a[#a + 1] = m
   end
   if (#a > 0) then
      Load_Usr(unpack(a))
   end
   dbg.fini("Reset")
end

--------------------------------------------------------------------------
-- Restore(): Restore the state of the user's loaded modules original
--            state. If a user has a "default" then use that collection.
--            Otherwise do a "Reset()"

function Restore(a)
   dbg.start{"Restore(",a,")"}

   local msg
   local path
   local sname   = LMOD_SYSTEM_NAME
   local msgTail = ""
   if (sname == nil) then
      sname   = ""
   else
      msgTail = ", for system: \"".. sname .. "\""
      sname   = "." .. sname
   end


   if (a == nil) then
      path = pathJoin(os.getenv("HOME"), ".lmod.d", "default" .. sname)
      if (not isFile(path)) then
         a = "system"
      end
   elseif (a ~= "system") then
      path = pathJoin(os.getenv("HOME"), ".lmod.d", a .. sname)
      if (not isFile(path)) then
         LmodError(" User module collection: \"",a,"\" does not exist.\n",
                   " Try \"module savelist\" for possible choices.\n")
      end
   end

   local masterTbl = masterTbl()

   if (a == "system" ) then
      msg = "system default" .. msgTail
   else
      a   = a or "default"
      msg = "user's ".. a .. msgTail
   end

   if (masterTbl.initial) then
      msg = false
   end


   if (a == "system" ) then
      Reset(msg)
   else
      local mt      = MT:mt()
      local results = mt:getMTfromFile{fn=path, name=a, msg=msg} or Reset(true)
   end

   dbg.fini("Restore")
end

--------------------------------------------------------------------------
-- Save(): Save the current list of modules to whatever name the user
--         gave on the command line or "default" if there is none.
--         Note that this function checks to see if any of the currently
--         loaded modules mix load statements with the setting of
--         environment variables.  In that case, Lmod will not save the
--         state of the modules into a collection.  The reasons are
--         complicated but a "manager" module file is "fake" loaded so
--         that any setenv or prepend_path commands will not be executed.

function Save(...)
   local masterTbl = masterTbl()
   local mt        = MT:mt()
   local a         = select(1, ...) or "default"
   local path      = pathJoin(os.getenv("HOME"), LMODdir)
   dbg.start{"Save(",concatTbl({...},", "),")"}

   local msgTail = ""
   local sname   = LMOD_SYSTEM_NAME
   if (sname == nil) then
      sname   = ""
   else
      msgTail = ", for system: \"".. sname .. "\""
      sname   = "." .. sname
   end

   if (a == "system") then
      LmodWarning("The named collection 'system' is reserved. Please choose another name.\n")
      dbg.fini("Save")
      return
   end

   local activeA = mt:list("short","active")
   local force   = masterTbl.force
   if (#activeA == 0 and not force) then
      LmodWarning("You are trying to save an empty collection of modules in \"",a,
                  "\".  If this is what you want then enter: \n",
                  "   module --force save ",a,"\n")
      dbg.fini("Save")
      return
   end

   --local aa = mt:safeToSave()
   --
   --if (#aa > 0) then
   --   LmodWarning("Unable to save module state as a \"default\"\n",
   --               "The following module(s):\n",
   --               "  ",concatTbl(aa,", "),"\n",
   --               "mix load statements with setting of environment variables.\n")
   --   dbg.fini("Save")
   --   return
   --end

   local attr = lfs.attributes(path)
   if (not attr) then
      mkdir_recursive(path)
   end
   path = pathJoin(path, a .. sname)
   if (isFile(path)) then
      os.rename(path, path .. "~")
   end
   mt:setHashSum()
   serializeTbl{name=mt:name(), value=mt, fn = path, indent = true}
   mt:hideHash()
   if (not expert()) then
      io.stderr:write("Saved current collection of modules to: ",a,
                      msgTail, "\n")
   end
   dbg.fini("Save")
end


--------------------------------------------------------------------------
-- SaveList(): report to the user all the named collections he/she has.

function SaveList(...)
   local mt        = MT:mt()
   local path      = pathJoin(os.getenv("HOME"), LMODdir)
   local masterTbl = masterTbl()
   local a         = {}
   local b         = {}

   findNamedCollections(b,path)
   if (masterTbl.terse) then
      for k = 1,#b do
         local name = b[k]
         local i,j  = name:find(path,1,true)
         if (i) then
            name = name:sub(j+2)
         end
         io.stderr:write(name,"\n")
      end
      return
   end


   for k = 1,#b do
      local name = b[k]
      local i,j  = name:find(path,1,true)
      if (i) then
         name = name:sub(j+2)
      end
      local cstr = string.format("%3d) ",k)
      a[#a+1] = cstr .. name
   end

   if (#a > 0) then
      io.stderr:write("Named collection list:\n")
      local ct = ColumnTable:new{tbl=a,gap=0}
      io.stderr:write(ct:build_tbl(),"\n")
   else
      io.stderr:write("No Named collections.\n")
   end
end

--------------------------------------------------------------------------
-- SearchCmd(): Point users to either spider or keyword

function SearchCmd(...)
   local s = concatTbl({...}, " ")
   io.stderr:write("\"module search\" does not exist. To list all possible modules do: \n",
                   "   module spider ",s,"\n\n",
                   "To search the contents of modules for matching words do:\n",
                   "   module keyword ",s,"\n")
end




--------------------------------------------------------------------------
-- Show(): use the show mode of MasterControl to list the active Lmod
--         commands in a module file.  Note that it is always in Lua
--         even if the modulefile is written in TCL.

function Show(...)
   local master = Master:master()
   dbg.start{"Show(", concatTbl({...},", "),")"}

   mcp = MasterControl.build("show")
   local borderStr = banner:border(0)

   prtHdr       = function()
                     io.stderr:write(borderStr)
                     io.stderr:write("   ",ModuleFn,":\n")
                     io.stderr:write(borderStr)
                  end
   master:access(...)
   dbg.fini("Show")
end

--------------------------------------------------------------------------
-- SpiderCmd(): Do a level 0 spider report if there are no command line
--              arguments.  Otherwise do a spider search to generate a
--              level 1 or level 2 report on particular modules.

function SpiderCmd(...)
   dbg.start{"SpiderCmd(", concatTbl({...},", "),")"}
   local cache     = Cache:cache()
   local moduleT   = cache:build()
   local masterTbl = masterTbl()
   local dbT     = {}
   local s
   local srch
   local spider    = Spider:new()
   spider:buildSpiderDB({"default"},moduleT, dbT)

   local arg = pack(...)

   if (arg.n < 1) then
      s = spider:Level0(dbT)
   else
      local a    = {}
      local help = false
      for i = 1, arg.n-1 do
         a[#a+1] = spider:spiderSearch(dbT, arg[i], help)
      end
      a[#a+1] = spider:spiderSearch(dbT, arg[arg.n], true)
      s = concatTbl(a,"\n")
   end
   local a = {}
   a[#a+1] = s
   a = hook.apply("msgHook","spider",a)

   pcall(pager,io.stderr, concatTbl(a,""), "\n")
   dbg.fini("SpiderCmd")
end

--------------------------------------------------------------------------
--  Swap(): Swap one module for another.  That is unload the first
--          and load the second.  If the second modulefile is successfully
--          loaded then it is registered with MT so that it won't be
--          reported in a swap message.


function Swap(...)
   local a = select(1, ...) or ""
   local b = select(2, ...) or ""
   local s = {}

   dbg.start{"Swap(",concatTbl({...},", "),")"}

   local n = select("#", ...)
   if (n ~= 2) then
      LmodError("Wrong number of arguments to swap.\n")
   end

   local mt    = MT:mt()
   local mname = MName:new("mt", a)
   local sn    = mname:sn()
   if (not mt:have(sn,"any")) then
      LmodError("Swap failed: \"",a,"\" is not loaded.\n")
   end

   local mA      = {}
   local mcp_old = mcp
   mcp           = MCP
   dbg.print{"Setting mcp to ", mcp:name(),"\n"}
   mA[1]         = mname
   mcp:unload(mA)
   mA[1]         = MName:new("load",b)
   local aa = mcp:load_usr(mA)
   if (not aa[1]) then
      LmodError("Swap failed.\n")
   end

   ------------------------------------------------------
   -- Register user loads so that Karl will be happy.

   local mname = mA[1]
   local sn    = mname:sn()
   local usrN  = (not masterTbl().latest) and b or mt:fullName(sn)
   mt:userLoad(sn,usrN)
   mcp = mcp_old
   dbg.print{"Setting mcp to ", mcp:name(),"\n"}
   dbg.fini("Swap")
end

--------------------------------------------------------------------------
--  TableList(): list the loaded modules in a lua table

function TableList()
   dbg.start{"TableList()"}
   local mt = MT:mt()

   local t = {}
   local activeA = mt:list("short","active")
   for i,v  in ipairs(activeA) do
      local mname   = MName:new("mt",v)
      local sn      = mname:sn()
      local version = mname:version()
      dbg.print{"sn: ",sn,", version: ",version,"\n"}
      t[sn] = version
   end
   local s = serializeTbl{name="activeList",indent=true, value=t}
   io.stderr:write(s,"\n")
   dbg.fini()
end

--------------------------------------------------------------------------
--  Update(): reload all modules.

function Update()
   local master = Master:master()
   master:reloadAll()
end

--------------------------------------------------------------------------
--  Use(): add a directory to MODULEPATH and LMOD_DEFAULT_MODULEPATH.
--         Note that this causes all the modules to be reviewed and
--         possibly reloaded if a module.

function Use(...)
   local mt  = MT:mt()
   local a = {}
   local op = MCP.prepend_path
   dbg.start{"Use(", concatTbl({...},", "),")"}

   local arg      = pack(...)
   local iarg     = 1
   local priority = 0

   while (iarg <= arg.n) do
      local v = arg[iarg]
      local w = v:lower()
      if (w == "-a" or w == "--append" ) then
         op = MCP.append_path
      elseif (w == "--priority") then
         iarg     = iarg + 1
         priority = tonumber(arg[iarg])
      else
         a[#a + 1] = v
      end
      iarg = iarg + 1
   end
   local nodups = true
   for _,v in ipairs(a) do
      v = abspath(v)
      if (v) then
         op(MCP, { ModulePath,  v, delim = ":", nodups=nodups, priority=priority })
         op(MCP, { DfltModPath, v, delim = ":", nodups=nodups, priority=priority })
      end
   end


   mt:buildBaseMpathA(varTbl[DfltModPath]:expand())
   mt:buildMpathA(varTbl[ModulePath]:expand())
   dbg.fini("Use")
end

--------------------------------------------------------------------------
--  UnUse(): remove a directory from both MODULEPATH and
--           LMOD_DEFAULT_MODULEPATH.  Note that all currently loaded
--           modules reviewed and possibly reloaded or made inactive.

function UnUse(...)
   local mt  = MT:mt()
   dbg.start{"UnUse(", concatTbl({...},", "),")"}
   local arg = pack(...)
   local nodups = true
   for i = 1, arg.n do
      local v = arg[i]
      MCP:remove_path{ ModulePath,  v, delim=":", nodups = true}
      MCP:remove_path{ DfltModPath, v, delim=":", nodups = true}
   end
   mt:buildBaseMpathA(varTbl[DfltModPath]:expand())
   mt:reloadAllModules()
   dbg.fini("UnUse")
end

--------------------------------------------------------------------------
--  UnLoad():  unload all requested modules

function UnLoad(...)
   dbg.start{"UnLoad(",concatTbl({...},", "),")"}
   MCP:unload_usr(MName:buildA("mt", ...))
   dbg.fini("UnLoad")
end

--------------------------------------------------------------------------
--  Whatis(): Run whatis on all request modules given the the command line.

function Whatis(...)
   prtHdr    = dbg.quiet
   Access("whatis",...)
end
