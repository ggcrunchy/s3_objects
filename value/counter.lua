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
local huge = math.huge
local pairs = pairs

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("tektite_core.bind")
local state_vars = require("config.StateVariables")

--
--
--

local Events = {}

for _, v in ipairs{ "on_hit_limit", "on_one_to_zero", "on_try_to_decrement_zero", "on_try_to_exceed_limit", "on_zero_to_one" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

local Actions = {
	do_decrement = function(counter)
		return function(what)
			if what == "fire" then
				local n = counter() - 1

				if n >= 0 then
					counter("set", n)
				end

				if n <= 0 then
					Events[n == 0 and "on_one_to_zero" or "on_try_to_decrement_zero"](counter, "fire", false)
				end
			elseif what == "is_done" then
				return true
			end
		end
	end,

	do_increment = function(counter)
		return function(what)
			if what == "fire" then
				local n, limit = counter() + 1, counter("get_limit")

				if n <= limit then
					counter("set", n)
				end

				if n == 1 then
					Events.on_zero_to_one(counter, "fire", false)
				end

				if n >= limit then
					Events[n == limit and "on_hit_limit" or "on_try_to_exceed_limit"](counter, "fire", false)
				end
			elseif what == "is_done" then
				return true
			end
		end
	end,

	do_reset = function(counter)
		return function(what)
			if what == "fire" then
				counter("set", 0)
			elseif what == "is_done" then
				return true
			end
		end
	end,

	do_set = function(counter)
		return function(what)
			if what == "fire" then
				local count = counter("get_count")

				if count ~= counter() then
					local limit = counter("get_limit")

					if limit and count > limit then
						Events.on_try_to_exceed_limit(counter, "fire", false)
					else
						counter("set", count)

						if count == limit then
							Events.on_hit_limit(counter, "fire", false)
						end
					end
				end
			elseif what == "is_done" then
				return true
			end
		end
	end
}

local InProperties = {
	uint = { get_count = true, get_limit = true }
}

local LinkSuper

local function LinkCounter (counter, other, csub, other_sub, links)
	local helper = bind.PrepLink(counter, other, csub, other_sub)

	helper("try_actions", Actions)
	helper("try_events", Events)
	helper("try_in_properties", InProperties)

	if not helper("commit") then
		LinkSuper(counter, other, csub, other_sub, links)
	end
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		local actions = arg2.actions

		if not (actions and (actions.do_increment or actions.do_set)) then
			arg3.limit, arg3.on_try_to_exceed_limit, arg3.get_limit = nil
		elseif arg2.get_limit or arg2.limit == 0 then
			arg3.limit = nil
		end

		if not (actions and actions.do_decrement) then
			arg3.on_one_to_zero, arg3.on_try_to_decrement_zero = nil
		end

		if not (actions and actions.do_increment) then
			arg3.on_hit_limit, arg3.on_zero_to_one = nil
		end

		if not (actions and actions.do_set) then
			arg3.count, arg3.get_count = nil
		elseif arg2.get_count then
			arg3.count = nil
		end

		arg3.persist_across_reset = arg2.persist_across_reset or nil

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.count = 0
		arg1.persist_across_reset = false
		arg1.limit = 1

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		-- spinners for count assignement, limit

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get = { "UINT: Counter value", is_source = true }
		arg1.get_count = "UINT: Count to assign"
		arg1.get_limit = "UINT: Upper limit"
		arg1.on_hit_limit = "On(hit limit)"
		arg1.on_one_to_zero = "On(decrement 1 -> 0)"
		arg1.on_try_to_decrement_zero = "On(try to decrement 0)"
		arg1.on_try_to_exceed_limit = "On(try to exceed limit)"
		arg1.on_zero_to_one = "On(increment 0 -> 1)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "counter"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", Events, Actions, nil, InProperties

	-- Prep Value Link --
	-- arg1: Parent handler
	elseif what == "prep_link:value" then
		LinkSuper = LinkSuper or arg1

		return LinkCounter
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	elseif info == "value_type" then
		return "uint"
	else
		local is_stale = state_vars.MakeStaleSessionPredicate(info.persist_across_reset)
		local count, get_count, limit

		local function counter (what, getter)
			if is_stale() then
				count, limit = nil
			end

			if what then
				if what == "get_count" then -- does double duty in bind and later calls
					get_count = get_count or getter

					return get_count and get_count() or (count or 0)
				elseif what == "get_limit" then -- ditto
					limit = limit or (getter and getter()) or huge

					return limit
				elseif what == "set" then
					count = what
				end
			else
				return count
			end
		end

		bind.Subscribe(wlist, info.get_count, counter, "get_count") -- see notes in counter()
		bind.Subscribe(wlist, info.get_limit, counter, "get_limit")

		for k, event in pairs(Events) do
			event.Subscribe(counter, info[k])
		end

		for k in adaptive.IterSet(info.actions) do
			bind.Publish(wlist, Actions[k](counter), info.uid, k)
		end

		return counter
	end
end