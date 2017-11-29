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
local bind = require("tektite_core.bind")
local table_funcs = require("tektite_core.table.funcs")

-- Corona globals --
local timer = timer

--
--
--

local Events = {}

for _, v in ipairs{ "on_cancel", "on_perform", "on_too_many" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

local N, NormalTimers, PersistentTimers = 0

local function CancelList (list_group)
	for i = 1, #(list_group or "") do
		for _, handle in pairs(list_group[i]) do
			timer.cancel(handle)

			N = N - 1
		end
	end
end

for k, v in pairs{
	-- Leave Level --
	leave_level = function()
		CancelList(NormalTimers)
		CancelList(PersistentTimers)

		NormalTimers, PersistentTimers = nil
	end,

	-- Reset Level --
	reset_level = function()
		CancelList(NormalTimers)

		NormalTimers = nil
	end
} do
	Runtime:addEventListener(k, v)
end

local IDs = table_funcs.Weak("k")
local TimerCapacity = 100

local function MakeAdder (list_group, delay, continue)
	list_group = list_group or {}

	local list_id, list = #list_group + 1, {}

	list_group[list_id] = list

	local function cue (what)
		if what == "fire" then
			if N < TimerCapacity then
				local id = (IDs[cue] or 0) + 1 -- 0 = null, thus we may fetch it safely
				local handle = timer.performWithDelay(delay, function(event)
					local how = continue(event)

					if how == true then
						Events.on_fire(cue, "fire", false)
					else
						if how == "quit" then
							Events.on_quit(cue, "fire", false)
						end

						timer.cancel(event.source)

						N, list[id] = N - 1
					end
				end, 0)

				list[id], IDs[cue], N = handle, id, N + 1
			else
				Events.on_too_many(cue, "fire", false)
			end
		elseif what == "is_done" then
			return true
		end
	end

	return cue, list_group, list
end

local function DefContinue () return true end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		-- elide cancel_id if no cancel...
		-- iterations if <= 0

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.delay = 500
		arg1.iterations = 1

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		-- spinner for iterations?

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		--
	-- Get Tag --
	elseif what == "get_tag" then
		return "cue_timer"

	-- New Tag --
	elseif what == "new_tag" then
--		return "extend", { on_cancel, on_perform, on_quit, on_too_many }, { cancel }, {
--			uint: most_recent_id
--		}, {
--			uint: cancel_id, uint: wants_to_quit
--		}

	-- Prep Action Link --
	-- arg1: Parent handler
	elseif what == "prep_link:action" then
		-- URGH...

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		-- cancel and cancel_id go together
	end
end

return function(info)
	if info == "editor_event" then
		return EditorEvent
		-- TODO!
		-- number of repetitions
		-- Wants to quit?
		-- On(cancel), On(quit)
		-- emit id on fire, for use by cancel-type integer setter (no-op once missing)
		-- Action to do
		-- Action if too may timers...
	else
		local delay, iterations, cue, list = info.delay, info.iterations or 0

		if info.cancel then
			local cancel_id --

			local function cancel (what)
				if what == "fire" then
					local id = cancel_id() --
					local handle = list[id] -- not right (could be in either list), just need both indices into list groups?

					if handle then
						timer.cancel(handle)

						N, list[id] = N - 1

						Events.on_cancel(cue, "fire", false)
					end
				elseif what == "is_done" then
					return true
				end
			end

			-- publish cancel
			-- subscribe cancel_id
		end

		local continue

		if info.wants_to_quit then
			local wants_to_quit -- TODO!

			if iterations > 0 then
				function continue (event)
					if wants_to_quit() then
						return "quit"
					else
						return event.count <= iterations
					end
				end
			else
				function continue ()
					return wants_to_quit() and "quit"
				end
			end

			-- subscribe wants_to_quit
		elseif iterations > 0 then
			function continue (event)
				return event.count <= iterations
			end
		else
			continue = DefContinue
		end

		if info.persist_across_reset then
			cue, PersistentTimers, list = MakeAdder(PersistentTimers, delay, continue)
		else
			cue, NormalTimers, list = MakeAdder(NormalTimers, delay, continue)
		end

		-- subscribe to events
		-- publish most recent id

		return cue
	end
end