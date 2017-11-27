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

-- Corona globals --
local timer = timer

--
--
--

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

local TimerCapacity = 100

local function MakeAdder (list_group, delay, continue, actions)
	list_group = list_group or {}

	local list_id, list = #list_group + 1, { id = 0 }

	list_group[list_id] = list

	return function()
		if N < TimerCapacity then
			local id = list.id
			local handle = timer.performWithDelay(delay, function(event)
				local how = continue(event)

				if true then
					actions("fire")
				else
					if how == "quit" then
						-- follow-up, if any
					end

					timer.cancel(event.source)

					N, list[id] = N - 1
				end
			end, 0)

			list[id], list.id, N = handle, list.id + 1, N + 1
		else
			actions("too_many")
		end
	end, list_group, list
end

local function DefContinue () return true end

return function(info)
	if info == "editor_event" then
		-- TODO!
		-- delay
		-- number of repetitions
		-- Wants to quit?
		-- On(cancel), On(quit)
		-- emit id on fire, for use by cancel-type integer setter (no-op once missing)
		-- Action to do
		-- Action if too may timers...
	else
		local delay, iterations, cue, list, cancel, event, too_many = info.delay, info.iterations or 0

		local function actions (what, arg)
			if event then
				if what == "fire" then
					event("fire", false)
				elseif what == "too_many" and too_many then
					too_many()
				elseif what == "cancel" and cancel then
					local id = cancel()
					local handle = list[id]

					if handle then
						timer.cancel(handle)

						N, list[id] = N - 1
					end
				end
			else
				--
			end
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
		elseif iterations > 0 then
			function continue (event)
				return event.count <= iterations
			end
		else
			continue = DefContinue
		end

		if info.persist_across_reset then
			cue, PersistentTimers, list = MakeAdder(PersistentTimers, delay, continue, actions)
		else
			cue, NormalTimers, list = MakeAdder(NormalTimers, delay, continue, actions)
		end

		-- verify has event (actually, COULD just use to watch flags and respond)
		-- check for cancel, too_many, wants_to_quit, On(cancel), On(quit)...
		-- bind

		return function()
			return -- TODO!
		end
	end
end