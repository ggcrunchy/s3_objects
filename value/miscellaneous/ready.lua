--- A condition that is either ready or somehow waiting.

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

-- Modules --
local bind = require("corona_utils.bind")
local object_vars = require("config.ObjectVariables")

-- Corona globals --
local system = system

--
--
--

local InProperties = {
	boolean = { should_disable = true, start_ready = true },
	uint = "get_amount"
}

local function LinkReady (ready, other, rsub, other_sub)
	local helper = bind.PrepLink(ready, other, rsub, other_sub)

	helper("try_in_properties", InProperties)

	return helper("commit")
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		arg3.as_count = arg2.as_count or nil
		arg3.persist_across_reset = arg2.persist_across_reset or nil

		if arg2.get_amount then
			arg3.amount = nil
		end

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.amount = 500
		arg1.as_count = false
		arg1.persist_across_reset = false

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddStepperWithEditable{ before = "Amount:", value_name = "amount", min = 1 }
		arg1:AddCheckbox{ value_name = "as_count", text = "Interpret amount as times fetched?" }
		arg1:AddCheckbox{ value_name = "persist_across_reset", text = "Persist across reset?" }

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_amount", "should_disable", "start_ready",
			{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get = "BOOL: Is ready?"
		arg1.get_amount = "NUM: Count or delay until ready again"
		arg1.should_disable = "BOOL: Disable after reporting ready?"
		arg1.start_ready = "BOOL: Start in ready state?"

	-- Get Tag --
	elseif what == "get_tag" then
		return "ready"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", nil, InProperties

	-- Prep Value Link --
	elseif what == "prep_link:value" then
		return LinkReady
	end
end

local function AddGetter (list, what, getter)
	list = list or {}

	list[what] = getter

	return list
end

local function Update (is_stale, amount, threshold, getters)
	if is_stale() then
		threshold = nil
	end

	local starts_ready = getters and getters.starts_ready

	if threshold == nil and starts_ready and starts_ready() then
		threshold = 0 -- next steps skipped, dovetails with normal check for 0
	end

	local is_new

	if threshold == "disabled" then
		return false, "disabled"
	elseif threshold == nil then
		threshold, is_new = amount or getters.get_amount(), true
	end

	if threshold == 0 then
		local should_disable = getters and getters.should_disable

		return true, (should_disable and should_disable()) and "disabled" or nil
	else
		return false, threshold, is_new
	end
end

local function NewReady (info, params)
	local is_stale = object_vars.MakeStaleSessionPredicate(info.persist_across_reset)
	local amount, getters, ready, threshold = info.amount

	if info.as_count then
		function ready (what, getter)
			if what then
				getters = AddGetter(what, getter)
			else
				local is_ready, result = Update(is_stale, amount, threshold, getters)

				if is_ready or result == "disabled" then
					threshold = result
				else
					threshold = threshold - 1
				end

				return is_ready
			end
		end
	else
		local up_to

		function ready (what, getter)
			if what then
				getters = AddGetter(what, getter)
			else
				if up_to then
					threshold = max(0, up_to - system.getTimer())
				end

				local is_ready, result, is_new = Update(is_stale, amount, threshold, getters)

				if is_ready or result == "disabled" then
					threshold, up_to = result
				elseif is_new then
					up_to = system.getTimer() + result
				end

				return is_ready
			end
		end
	end

	local pubsub = params.pubsub

	bind.Subscribe(pubsub, info.get_amount, ready, "get_amount")
	bind.Subscribe(pubsub, info.should_disable, ready, "should_disable")
	bind.Subscribe(pubsub, info.starts_ready, ready, "starts_ready")

	return ready
end

return { make = NewReady, editor = EditorEvent, value_type = "boolean" }