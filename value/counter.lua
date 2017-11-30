--- Maintain a counter.

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

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("tektite_core.bind")
local state_vars = require("config.StateVariables")

-- Corona globals --
local timer = timer

--
--
--

local Events = {}

for _, v in ipairs{ "on_hit_limit", "on_one_to_zero", "on_try_to_decrement_zero", "on_try_to_exceed_limit", "on_zero_to_one" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

local Actions = {
	decrement = function()
		--
	end,

	increment = function()
		--
	end,

	reset = function()
		--
	end,

	set = function()
		--
	end
}

local LinkSuper

local function LinkCounter (counter, other, sub, other_sub, links)
	if Events[sub] then
		bind.AddId(counter, sub, other, other_sub)
	else
		LinkSuper(counter, other, sub, other_sub, links)
	end
end

--[[
local function MakeCue (delay, continue)
	local list_id, list, get_cancel_id = #Timers + 1, { id = 0 }

	Timers[list_id] = list

	local function cue (what)
		if what then -- special commands
			if what == "get_id_and_list" then
				return get_cancel_id, list
			else
				get_cancel_id = what
			end
		elseif Timers.n < TimerCapacity then
			local id = list.id + 1 -- 0 = null, thus we may fetch it safely
			local handle = timer.performWithDelay(delay, function(event)
				local how = continue(event)

				if how == true then
					Events.on_fire(cue, "fire", false)
				else
					if how == "quit" then
						Events.on_quit(cue, "fire", false)
					end

					timer.cancel(event.source)

					Timers.n, list[id] = Timers.n - 1
				end
			end, 0)

			list[id], list.id, Timers.n = handle, id, Timers.n + 1
		else
			Events.on_too_many(cue, "fire", false)
		end
	end

	return cue, list
end
]]

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		if not (arg2.increment or arg2.set) then
			arg3.limit, arg3.limit = nil
		end

		if not arg2.decrement then
			--
		end

		if not (arg2.decrement or arg3.reset or arg3.set) then
			--
		end

		if arg3.limit or arg3.get_limit then
			if arg2.get_limit then
				arg3.limit = nil
			end
		else
			arg3.on_hit_limit, arg3.on_try_to_exceed_limit = nil
		end

		

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.persist_across_reset = false
		arg1.limit = 1

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		-- spinner for iterations?

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get = { "UINT: Counter value", is_source = true }
		arg1.get_limit = "UINT: Upper limit"
		arg1.on_hit_limit = "On(hit limit)"
		arg1.on_one_to_zero = "On(1 -> 0)"
		arg1.on_try_to_decrement_zero = "On(try to decrement 0)"
		arg1.on_try_to_exceed_limit = "On(try to exceed limit)"
		arg1.on_zero_to_one "On(0 -> 1)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "counter"

	-- New Tag --
	elseif what == "new_tag" then
	--[[
		return "extend", Events, Actions, state_vars.UnfoldPropertyFunctionsAsTagReadyList(Properties), {
			uint = "get_limit"
		}]]

	-- Prep Action Link --
	-- arg1: Parent handler
	elseif what == "prep_link:action" then
		LinkSuper = LinkSuper or arg1

		return LinkCounter

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
	--[[
		if arg1.links:HasLinks(arg3, "do_cancel") and not arg1.links:HasLinks(arg3, "get_cancel_id") then
			arg1[#arg1 + 1] = "Cancel event must be paired with a cancel ID getter"
		end]]
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		if info.limit or info.get_limit then
			--
			-- bind hit_limit, try_to_exceed_limit
		else
			--
		end

	--	bind.Subscribe(wlist, info.get_cancel_id, cue) -- see "special commands" in MakeCue()

		for k, event in pairs(Events) do
--			event.Subscribe(cue, info[k])
		end

		--
		for k in adaptive.IterSet(info.actions) do
	--		bind.Publish("loading_level", Actions[k](cue), info.uid, k)
		end

	--	state_vars.PublishProperties(info.props, Properties, info.uid, cue)

		return cue
	end
end