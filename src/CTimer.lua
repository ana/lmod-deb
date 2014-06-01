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
require("utils")
local M       = {}
local dbg     = require("Dbg"):dbg()

s_cTimer = false

local function new(self, msg, threshold, active)
   local o = {}
   setmetatable(o,self)
   self.__index = self

   o.state     = active and "init" or "dead"
   o.start     = epoch()
   o.msg       = msg
   o.threshold = threshold

   return o
end

function M.cTimer(self, msg, threshold, active)
   if (not s_cTimer) then
      s_cTimer = new(self, msg, threshold, active)
   end
   return s_cTimer
end

function M.test(self)
   if (self.state == "init") then
      dbg.start{"CTimer:test()", level=2}
      local delta = epoch() - self.start
      dbg.print{"delta: ",delta,"\n"}
      if (delta > self.threshold) then
         io.stderr:write(self.msg)
         self.state = "activeMsg"
      end
      dbg.fini("CTimer:test")
   end
end

function M.done(self,endMsg)
   if (self.state == "activeMsg") then
      io.stderr:write(endMsg,"\n")
      self.state = "done"
   end
end

return M
