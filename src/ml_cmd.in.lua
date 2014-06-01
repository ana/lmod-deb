#!@path_to_lua@/lua
-- -*- lua -*-
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
package.path = LuaCommandName_dir .. "../tools/?.lua;" ..
               LuaCommandName_dir .. "?.lua;"       .. package.path

require("strict")
require("string_utils")
local concatTbl = table.concat
local function quoteWrap(a)
   return "'" .. tostring(a) .. "'"
end

function usage()
   io.stderr:write("\n",
                   "ml: A handy front end for the module command:\n\n",
                   "Simple usage:\n",
                   " -------------\n",
                   "  $ ml\n",
                   "                           means: module list\n",
                   "  $ ml foo bar\n",
                   "                           means: module load foo bar\n",
                   "  $ ml -foo -bar baz goo\n",
                   "                           means: module unload foo bar;\n",
                   "                                  module load baz goo;\n\n",
                   "Command usage:\n",
                   "--------------\n\n",
                   "Any module command can be given after ml:\n\n",
                   "if name is avail, save, restore, show, swap,...\n",
                   "    $ ml name  arg1 arg2 ...\n\n",
                   "Then this is the same :\n",
                   "    $ module name arg1 arg2 ...\n\n",
                   "In other words you can not load a module named: show swap etc\n")
   io.stderr:write("\n\n-----------------------------------------------\n",
                   "  Robert McLay, TACC\n",
                   "     mclay@tacc.utexas.edu\n")
end



function main()

   local argA     = {}
   local optA     = {}
   local cmdA     = {}

   ------------------------------------------------------------
   -- lmodOptT: Hash table of command line arguments.  The key
   --           is the name of the argument and the value is the
   --           number of arguments the option requires

   local lmodOptT = {
      ["-?"] = 0, ["-h"] = 0, ["--help"] = 0, ["-d"]=0, ["--version"]=0,
      ["--old_style"] = 0, ["--expert"]=0, ["--novice"]=0, ["-D"]=0,
      ["--localvar"]=1, ["--terse"] = 0, ["-t"] = 0, ["--latest"] = 0,
      ["--versoin"]=0, ["--ver"]=0, ["--v"]=0, ["-v"]=0,['--config'] = 0,
      ["--mt"] = 0, ["--ignore_cache"] = 0, ["--dumpversion"] = 0,
      ["--force"] = 0,['-w'] = 1, ['--width'] = 1, ['-r'] = 0,
      ['--regexp'] = 0, ['--raw'] = 0,["-q"] = 0, ["-quiet"] = 0,
   }

   local translateT = {
      ["--versoin"]="--version",
      ["--ver"]="--version",
      ["--v"]="--version",
      ["-v"]="--version",
   }

   ------------------------------------------------------------
   -- lmodCmdT: Hash table of module commands.  The value just
   --           has to be non-nil

   local lmodCmdT = {
      avail="avail",  av="avail",
      getdefault="getdefault", gd="getdefault",
      help="help",
      key="keyword", keyword="keyword",
      list="list",
      listdefault="listdefault", ld="listdefault",
      load="load", add="load",
      purge="purge",
      r="restore", restore="restore",
      refresh="refresh",
      reset="reset",
      s="save",
      save="save",
      savelist="savelist", sl="savelist",
      setdefault="save", sd="save",
      search="search",
      show="show",
      spider="spider",
      swap="swap", sw="swap", switch="swap",
      tablelist="tablelist",
      ['try-load'] = "try-load",
      unload="unload", rm = "unload", del = "unload", delete="unload",
      unuse="unuse",
      update="update",
      use="use",
      whatis="whatis",
   }

   local grab     = 0
   local verbose  = false
   local oldStyle = false
   local show     = false
   local cmdFound = false

   for _,v in ipairs(arg) do
      local done = false
      if (grab > 0) then
         optA[#optA+1] = v
         grab          = grab - 1
         done          = true
      end

      if (not done and v == "--Verbose") then
         done    = true
         verbose = true
      end

      if (not done and v == "--old_style") then
         done     = true
         oldStyle = true
      end

      if (not done and v == "--show") then
         done   = true
         show   = true
      end

      if (not done and v == "--help" or v == "-?" or v== "-h") then
         done = true
         usage()
         return
      end


      local num = lmodOptT[v]
      if (not done and num) then
         grab          = num
         optA[#optA+1] = translateT[v] or v
         done          = true
      end

      local cmd = lmodCmdT[v]
      if (not done and cmd and not cmdFound) then
         cmdA[#cmdA + 1] = cmd
         done            = true
         cmdFound        = true
      end

      if (not done) then
         argA[#argA+1] = v
      end
   end

   if (#cmdA > 1) then
      io.stderr:write("ml error: too many commands\n")
      os.exit(1)
   end

   local opts = concatTbl(optA," ")

   local a = {}

   local kind = nil

   a[#a + 1] = "module"
   a[#a + 1] = opts

   if (#cmdA == 1) then
      a[#a + 1] = cmdA[1]
   elseif (#argA < 1) then
      a[#a + 1] = "list"
   else
      if (oldStyle) then
         kind      = "load"
      else
         a[#a + 1] = "load"
      end
   end

   if (kind == 'load') then
      local b = {}
      local u = {}
      for i = 1,#argA do
         if (argA[i]:sub(1,1) == "-") then
            u[#u+1] = quoteWrap(argA[i]:sub(2,-1))
         else
            b[#b+1] = quoteWrap(argA[i])
         end
      end
      if (#u > 0) then
         a[#a+1] = "unload"
         a[#a+1] = concatTbl(u," ")
         if (#b > 0) then
            a[#a+1] = "; module"
            a[#a+1] = opts
         end
      end

      if (#b > 0) then
         a[#a+1] = "load "
         a[#a+1] = concatTbl(b," ")
      end
   else
      for i = 1,#argA do
         a[#a+1] = quoteWrap(argA[i])
      end
   end

   local s = concatTbl(a," ")

   if (verbose or show) then
      io.stderr:write(s, "\n")
   end

   if (not show) then
      io.stdout:write(s, "\n")
   end
end

main()
