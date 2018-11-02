--- Wait for a while in a coroutine.

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
local max = math.max
local running = coroutine.running

-- Modules --
local bind = require("corona_utils.bind")
local flow = require("coroutine_ops.flow")

--
--
--

local NotInCoroutine = bind.BroadcastBuilder_Helper(nil)

local function LinkWait (wait, other, wsub, osub)
	if wsub == "get_ms" or wsub == "on_not_in_coroutine" then
		bind.AddId(wait, wsub, other.uid, osub)

		return true
	end
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		if arg2.get_ms then
			arg3.ms = nil
		end

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.ms = 500

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddStepperWithEditable{ before = "Wait, in milliseconds:", value_name = "ms", min = 1 }

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_ms",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next", "on_not_in_coroutine"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Wait"
		arg1.get_ms = "UINT: Milliseconds to wait"
		arg1.on_not_in_coroutine = "On(not in coroutine)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "wait_in_coroutine"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", "on_not_in_coroutine", nil, nil, { uint = "get_ms" }

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkWait
	end
end

return function(info, params)
	if info == "editor_event" then
		return EditorEvent
	else
		local ms, get_ms = info.ms

		local function wait (comp)
			if comp then
				get_ms = comp
			elseif running() then
				flow.Wait(ms or max(1, get_ms()))
			else
				NotInCoroutine(wait)
			end
		end

		local pubsub = params.pubsub

		NotInCoroutine.Subscribe(info.not_in_coroutine, wait, pubsub)

		bind.Subscribe(pubsub, info.get_ms, wait)

		return wait
	end
end