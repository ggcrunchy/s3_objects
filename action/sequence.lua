--- Fire a series of events in sequence.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Modules --
local bind = require("tektite_core.bind")

--
--
--

local function EditorEvent (what, arg1, arg2, arg3)
	--
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
		-- TODO!
		-- Array-style link
		-- Care about gaps?
		-- No sorting among multiple links
		-- Any way to use the bind event helper?
			-- maybe just build raw broadcaster as upvalue and then use the indices as "object"?
	else
		local builder, object_to_broadcaster = bind.BroadcastBuilder()
		local n -- TODO!

		for i = 1, n do
--			bind.Subscribe(wlist, info.indices, builder, i)
		end

		return function()
			for i = 1, n do
				local func = object_to_broadcaster[i]

				if func then
					func("fire", false)
				end
			end
		end
	end
end