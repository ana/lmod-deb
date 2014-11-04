#!@path_to_lua@/lua
-- -*- lua -*-

--------------------------------------------------------------------------
-- Fixme
-- @script computeHashSum 

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

------------------------------------------------------------------------
-- Use command name to add the command directory to the package.path
------------------------------------------------------------------------
local LuaCommandName = arg[0]
local i,j = LuaCommandName:find(".*/")
local LuaCommandName_dir = "./"
if (i) then
   LuaCommandName_dir = LuaCommandName:sub(1,j)
end
package.path = LuaCommandName_dir .. "../tools/?.lua;"   ..
               LuaCommandName_dir .. "../shells/?.lua;"  ..
               LuaCommandName_dir .. "?.lua;"            ..
               package.path

function cmdDir()
   return LuaCommandName_dir
end

Version = "1.0"
HashSum = "@path_to_hashsum@"

require("strict")
require("myGlobals")
require("utils")

require("fileOps")
require("capture")
MasterControl = require("MasterControl")
MCP           = {}
mcp           = {}
require("modfuncs")
require("cmdfuncs")

BaseShell         = require("BaseShell")
Master            = require("Master")
local dbg         = require("Dbg"):dbg()

local ModuleStack = require("ModuleStack")
local MT          = require("MT")
local Optiks      = require("Optiks")
local s_masterTbl = {}

local fh          = nil
local getenv      = os.getenv
local concatTbl   = table.concat

function masterTbl()
   return s_masterTbl
end


function main()
   local master    = Master:master(false)
   local mStack    = ModuleStack:moduleStack()
   local shellN    = "bash"
   master.shell    = BaseShell.build(shellN)
   local fn        = os.tmpname()
   fh              = io.open(fn,"w")
   local i         = 1
   local masterTbl = masterTbl()
   options()

   if (masterTbl.debug) then
      dbg:activateDebug(1, tonumber(masterTbl.indentLevel))
   end
   dbg.start{"computeHashSum()"}

   setenv_lmod_version()    -- push Lmod version info into env for modulefiles.
   build_epoch()            -- build the epoch function
   build_accept_functions() -- Accept or ignore TCL modulefiles.

   require("StandardPackage")
   local lmodPath = os.getenv("LMOD_PACKAGE_PATH") or ""
   for path in lmodPath:split(":") do
      path = path .. "/"
      path = path:gsub("//+","/")
      package.path  = path .. "?.lua;"      ..
         path .. "?/init.lua;" ..
         package.path

      package.cpath = path .. "../lib/?.so;"..
         package.cpath
   end

   dbg.print{"lmodPath: \"", lmodPath,"\"\n"}
   require("SitePackage")

   MCP           = MasterControl.build("computeHash","load")
   mcp           = MasterControl.build("computeHash","load")

   local f = masterTbl.pargs[1]
   mStack:push(masterTbl.fullName, masterTbl.usrName, masterTbl.sn, f)
   loadModuleFile{file=f, shell=shellN, reportErr=true}
   mStack:pop()
   local s = concatTbl(ShowResultsA,"")
   dbg.textA{name="Text to Hash",a=ShowResultsA}

   if (masterTbl.verbose) then
      io.stderr:write(s)
   end
   fh:write(s)
   if (HashSum:sub(1,1) == "@" ) then
      HashSum = findInPath("sha1sum")
   end
   fh:close()

   local result = capture(HashSum .. " " .. fn)
   os.remove(fn)
   local i,j = result:find(" ")
   dbg.print{"hash value: ",result:sub(1,i-1),"\n"}
   print (result:sub(1,i-1))
   dbg.fini("computeHashSum")
end

function options()
   local masterTbl = masterTbl()
   local usage         = "Usage: computeHashSum [options] file"
   local cmdlineParser = Optiks:new{usage=usage, version=Version}

   cmdlineParser:add_option{
      name   = {'-v','--verbose'},
      dest   = 'verbosityLevel',
      action = 'count',
   }
   cmdlineParser:add_option{
      name   = {'--fullName'},
      dest   = 'fullName',
      action = 'store',
      help   = "Full name of the module file"
   }

   cmdlineParser:add_option{
      name   = {'--usrName'},
      dest   = 'usrName',
      action = 'store',
      help   = "User name of the module file"
   }

   cmdlineParser:add_option{
      name   = {'--sn'},
      dest   = 'sn',
      action = 'store',
      help   = "Full name of the module file"
   }

   cmdlineParser:add_option{
      name   = {'-D','-d','--debug'},
      dest   = 'debug',
      action = 'store_true',
      default = false,
      help    = "debug flag"
   }
   cmdlineParser:add_option{
      name   = {'--indentLevel'},
      dest   = 'indentLevel',
      action = 'store',
      default = "0",
      help    = "indent level for Dbg"
   }



   local optionTbl, pargs = cmdlineParser:parse(arg)

   for v in pairs(optionTbl) do
      masterTbl[v] = optionTbl[v]
   end
   masterTbl.pargs = pargs

end

main()
