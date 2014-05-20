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

require("strict")

require("capture")
require("fileOps")
require("pairsByKeys")
require("serializeTbl")
require("utils")
require("string_utils")
local BeautifulTbl = require('BeautifulTbl')
local Version      = require("Version")
local concatTbl    = table.concat
local dbg          = require('Dbg'):dbg()
local getenv       = os.getenv
local rep          = string.rep
local M            = {}

s_configuration   = false

local function locatePkg(pkg)
   local result = nil
   for path in package.path:split(";") do
      local s = path:gsub("?",pkg)
      local f = io.open(s,"r")
      if (f) then
         f:close()
         result = s
         break;
      end
   end
   return result
end


local function new(self)
   local o = {}
   setmetatable(o,self)
   self.__index = self

   local locSitePkg = locatePkg("SitePackage") or "unknown"

   if (locSitePkg ~= "unknown") then

      local std_sha1 = "15fea255d00cc957ce2431cfe3a888349a8bb4ef"

      local HashSum = "/usr/bin/sha1sum"
      if (HashSum:sub(1,1) == "@") then
         HashSum = findInPath("sha1sum")
      end

      local result = capture(HashSum .. " " .. locSitePkg)
      result       = result:gsub(" .*","")
      if (result == std_sha1) then
         locSitePkg = "standard"
      end
   end

   local lmod_version = Version.git()
   if (lmod_version == "") then
      lmod_version = Version.tag()
   else
      lmod_version = lmod_version:gsub("[)(]","")
   end
   local settarg_support = "no"
   local pkgName         = Pkg.name() or "unknown"
   local lmod_colorize   = getenv("LMOD_COLORIZE") or "yes"
   local scDescriptT     = getSCDescriptT()
   local numSC           = #scDescriptT
   local uname           = capture("uname -a")
   local adminFn, readable = findAdminFn()

   local tbl = {}
   tbl.prefix     = { doc = "Lmod prefix"                     , value = "/usr",                    }
   tbl.dupPaths   = { doc = "Allow duplicate paths"           , value = LMOD_DUPLICATE_PATHS,          }
   tbl.path_lua   = { doc = "Path to Lua"                     , value = "/usr/bin",               }
   tbl.path_pager = { doc = "Path to Pager"                   , value = "/bin/more",             }
   tbl.path_hash  = { doc = "Path to HashSum"                 , value = "/usr/bin/sha1sum",           }
   tbl.settarg    = { doc = "Supporting Full Settarg Use"     , value = settarg_support,               }
   tbl.dot_files  = { doc = "Using dotfiles"                  , value = "yes",             }
   tbl.numSC      = { doc = "number of cache dirs"            , value = numSC,                         }
   tbl.lmodV      = { doc = "Lmod version"                    , value = lmod_version,                  }
   tbl.ancient    = { doc = "User cache valid time(sec)"      , value = "86400",                   }
   tbl.short_tm   = { doc = "Write cache after (sec)"         , value = "2",                }
   tbl.prpnd_blk  = { doc = "Prepend order"                   , value = "normal",             }
   tbl.colorize   = { doc = "Colorize Lmod"                   , value = lmod_colorize,                 }
   tbl.allowTCL   = { doc = "Allow TCL modulefiles"           , value = LMOD_ALLOW_TCL_MFILES,         }
   tbl.mpath_av   = { doc = "Include modulepath dir in avail" , value = LMOD_MPATH_AVAIL,              }
   tbl.mpath_root = { doc = "MODULEPATH_ROOT"                 , value = "/usr/modulefiles",           }
   tbl.pkg        = { doc = "Pkg Class name"                  , value = pkgName,                       }
   tbl.sitePkg    = { doc = "Site Pkg location"               , value = locSitePkg,                    }
   tbl.lua_term   = { doc = "System lua-term"                 , value = "yes",             }
   tbl.lua_json   = { doc = "System lua_json"                 , value = "",             }
   tbl.uname      = { doc = "uname -a"                        , value = uname,                         }
   tbl.z01_admin  = { doc = "Admin file"                      , value = adminFn,                       }
   tbl.z02_admin  = { doc = "Does Admin file exist"           , value = tostring(readable),            }
   tbl.luaV       = { doc = "Lua Version"                     , value = _VERSION,                      }       
   tbl.case       = { doc = "Case Independent Sorting"        , value = LMOD_CASE_INDEPENDENT_SORTING, }

   o.tbl = tbl
   return o
end

function M.configuration(self)
   if (not s_configuration) then
      s_configuration = new(self)
   end
   return s_configuration
end

function M.report(self)
   local a   = {}
   local tbl = self.tbl
   a[#a+1]   = {"Description", "Value", }
   a[#a+1]   = {"-----------", "-----", }

   for k, v in pairsByKeys(tbl) do
      a[#a+1] = {v.doc, v.value }
   end

   local b = {}
   local bt = BeautifulTbl:new{tbl=a}
   b[#b+1]  = bt:build_tbl()
   b[#b+1]  = "\n"

   local rcFileA = getRCFileA()
   if (#rcFileA) then
      b[#b+1] = "Active RC file(s):"
      b[#b+1] = "------------------"
      for i = 1, #rcFileA do
         b[#b+1] = rcFileA[i]
      end
      b[#b+1]  = "\n"
   end


   local scDescriptT = getSCDescriptT()
   if (#scDescriptT > 0) then
      a = {}
      a[#a+1]   = {"Cache Directory",  "Time Stamp File",}
      a[#a+1]   = {"---------------",  "---------------",}
      for i = 1, #scDescriptT do
         a[#a+1] = { scDescriptT[i].dir, scDescriptT[i].timestamp}
      end
      bt = BeautifulTbl:new{tbl=a}
      b[#b+1]  = bt:build_tbl()
      b[#b+1]  = "\n"
   end

   local border = banner:border(2)
   local str    = " Lmod Property Table:"
   b[#b+1]  = border
   b[#b+1]  = str
   b[#b+1]  = border
   b[#b+1]  = "\n"
   b[#b+1]  = serializeTbl{ indent = true, name="propT", value = getPropT() }
   b[#b+1]  = "\n"

   return concatTbl(b,"\n")
end
return M
