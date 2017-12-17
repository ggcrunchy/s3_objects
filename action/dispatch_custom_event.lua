--- Dispatch a custom runtime event.

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

-- Standard library imports --
local pairs = pairs
local remove = table.remove
local type = type

-- Modules --
local bind = require("tektite_core.bind")

-- Corona globals --
local Runtime = Runtime

--
--
--

local function EditorEvent (what, arg1, arg2, arg3)
	-- preserve name
	-- verify: check within type for dups, otherwise ok
end

local Event, Stash = {}, {}

local function AddSubtable (key)
	local t = remove(Stash) or {}

	for k in pairs(t) do
		t[k] = nil
	end

	Event[key] = t
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local name = "custom:" .. info.name

		local function dispatch (comp, arg)
			Event.name = name -- sanity check, since event is user code

			-- Populate!

			Runtime:dispatchEvent(Event)

			for k, t in pairs(Event) do
				if type(t) == "table" then -- another sanity check
					Stash[#Stash + 1] = t
				end

				Event[k] = nil
			end
		end

		return dispatch
	end
end