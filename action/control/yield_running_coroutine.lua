--- Yield the running coroutine, if any.

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
local running = coroutine.running
local yield = coroutine.yield

-- Modules --
local bind = require("corona_utils.bind")

--
--
--

local Events = {}

for _, name in ipairs{ "on_not_in_coroutine", "on_yielding" } do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local function LinkYield (coro_yield, other, cysub, osub)
	local helper = bind.PrepLink(coro_yield, other, cysub, osub)

	helper("try_events", Events)

	return helper("commit")
end

local function EditorEvent (what, arg1, _, arg3)
	-- Get Link Grouping --
	if what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next", "on_yielding", "on_not_in_coroutine"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Yield"
		arg1.on_not_in_coroutine = "On(not in coroutine)"
		arg1.on_yielding = "On(about to yield)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "yield_running_coroutine"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", Events

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkYield
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local function yield_coro ()
			if running() then
				Events.on_yielding(yield_coro)

				yield() -- TODO: okay to tail-call?
			else
				return Events.on_not_in_coroutine(yield_coro)
			end
		end

		for k, v in pairs(Events) do
			v.Subscribe(wlist, info[k], yield_coro)
		end

		return yield_coro
	end
end