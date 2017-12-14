--- Cue a Corona timer.

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
local native = native
local timer = timer

--
--
--

local Events = {}

for _, v in ipairs{ "on_cancel", "on_perform", "on_quit", "on_too_many" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

local Timers

local Actions = {
	-- Do Cancel --
	do_cancel = function(cue)
		return function(what)
			if what == "fire" then
				local get_cancel_id, list = cue("get_cancel_id_and_list")
				local id = get_cancel_id()
				local handle = list[id]

				if handle then
					timer.cancel(handle)

					Timers.n, list[id] = Timers.n - 1

					Events.on_cancel(cue, "fire", false)
				end
			elseif what == "is_done" then
				return true
			end
		end
	end
}

local InProperties = { boolean = "wants_to_quit", uint = "get_cancel_id" }

local OutProperties = {
	uint = {
		-- Most Recent ID --
		most_recent_id = function(cue)
			return function()
				local _, list = cue("get_cancel_id_and_list")

				return list.id
			end
		end
	}
}

local LinkSuper

local function LinkTimer (setter, other, tsub, other_sub, links)
	local helper = bind.PrepLink(setter, other, tsub, other_sub)

	helper("try_actions", Actions)
	helper("try_events", Events)
	helper("try_in_properties", InProperties)
	helper("try_out_properties", OutProperties)

	if not helper("commit") then
		LinkSuper(setter, other, tsub, other_sub, links)
	end
end

for k, v in pairs{
	-- Leave Level --
	leave_level = function()
		for i = 1, #(Timers or ""), 2 do
			for _, handle in pairs(Timers[i]) do
				timer.cancel(handle)
			end
		end

		Timers = nil
	end,

	-- Reset Level --
	reset_level = function()
		for i = 1, #(Timers or ""), 2 do
			if Timers[i + 1] == "normal" then
				local list, n = Timers[i], Timers.n

				for id, handle in pairs(list) do
					timer.cancel(handle)

					n, list[id] = n - 1
				end

				Timers.n = n
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

local TimerCapacity = 100

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
			local id = list.id + 1 -- 0 = null, thus we can fetch it safely
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

local function DefContinue () return true end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		if not arg2.do_cancel then
			arg3.get_cancel_id = nil
		end

		if arg2.iterations == 0 then
			arg3.iterations = nil
		end

		if not arg2.wants_to_quit then
			arg3.on_quit = nil
		end

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.delay = 500
		arg1.iterations = 1

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		-- numeric textfield?
		-- spinner for iterations?

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "EVENTS", font = "bold", r = 1, g = 0, b = 0 }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", r = 0, g = 1, b = 0 }, "can_fire", "wants_to_quit",
			{ text = "CANCELLATION", font = "bold", r = 0, g = 0, b = 1 }, "get_cancel_id", "do_cancel",
			{ text = "STOCK ACTIONS", font = "bold", r = .5, g = 0, b = .5, is_source = true }, "next", "instead",
			{ text = "CUSTOM ACTIONS", font = "bold", r = 0, g = .5, b = .5, is_source = true }, "on_cancel", "on_perform", "on_quit", "on_too_many",
			{ text = "OUT-PROPERTIES", font = "bold", r = .5, g = .5, b = 0, is_source = true }, "most_recent_id"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.do_cancel = "Cancel it"
		arg1.fire = "Cue a timer"
		arg1.get_cancel_id = "UINT: Timer to cancel"
		arg1.most_recent_id = "UINT: Most recent timer"
		arg1.on_cancel = "On(cancel)"
		arg1.on_perform = "On(perform)"
		arg1.on_quit = "On(quit)"
		arg1.on_too_many = "On(too many)"
		arg1.wants_to_quit = "BOOL: Should timer quit?"

	-- Get Tag --
	elseif what == "get_tag" then
		return "cue_timer"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", Events, Actions, state_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties), InProperties

	-- Prep Action Link --
	-- arg1: Parent handler
	elseif what == "prep_link:action" then
		LinkSuper = LinkSuper or arg1

		return LinkTimer

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if arg1.links:HasLinks(arg3, "do_cancel") and not arg1.links:HasLinks(arg3, "get_cancel_id") then
			arg1[#arg1 + 1] = "Cancel action must be paired with a cancel ID getter"
		end
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local iterations, continue = info.iterations

		if info.wants_to_quit then
			local wants_to_quit

			if iterations then
				function continue (event, arg)
					if arg == "add" then -- bind
						wants_to_quit = event
					elseif wants_to_quit() then
						return "quit"
					else
						return event.count <= iterations
					end
				end
			else
				function continue (what, arg)
					if arg == "add" then -- bind
						wants_to_quit = what
					else
						return wants_to_quit() and "quit"
					end
				end
			end

			bind.Subscribe(wlist, info.wants_to_quit, continue, "add")
		elseif iterations then
			function continue (event)
				return event.count <= iterations
			end
		else
			continue = DefContinue
		end

		Timers = Timers or { n = 0 }

		local cue, list = MakeCue(info.delay, continue)

		Timers[#Timers + 1] = list
		Timers[#Timers + 1] = info.persist_across_reset and "persist" or "normal"

		bind.Subscribe(wlist, info.get_cancel_id, cue) -- see "special commands" in MakeCue()

		for k, event in pairs(Events) do
			event.Subscribe(cue, info[k])
		end

		for k in adaptive.IterSet(info.actions) do
			bind.Publish("loading_level", Actions[k](cue), info.uid, k)
		end

		state_vars.PublishProperties(info.props, OutProperties, info.uid, cue)

		return cue
	end
end