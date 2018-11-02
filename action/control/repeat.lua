--- Do some action some number of times.

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
local bind = require("corona_utils.bind")

--
--
--

local Events = { cancelled = bind.BroadcastBuilder_Helper(nil), next = bind.BroadcastBuilder_Helper(nil) }

local InProperties = { uint = "get_count" }

local function LinkRepeat (rep, other, rsub, other_sub)
	local helper = bind.PrepLink(rep, other, rsub, other_sub)

	helper("try_events", Events)
	helper("try_in_properties", InProperties)

	return helper("commit")
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		if arg2.get_count then
			arg3.count = nil
		end

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.count = 1

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddStepperWithEditable{ before = "Count:", value_name = "count", min = 1 }

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_count",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next", "cancelled"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.cancelled = "Loop cancelled"
		arg1.fire = "Repeat event"
		arg1.get_count = "UINT: # of times"
		arg1.next = "Event"

	-- Get Tag --
	elseif what == "get_tag" then
		return "repeat"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", "cancelled", nil, nil, InProperties

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkRepeat

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "next") then
			arg1[#arg1 + 1] = "Repeat requires event"
			-- TODO: require count > 0 (if not get_count)?
		end
	end
end

return function(info, params)
	if info == "editor_event" then
		return EditorEvent
	else
		local count, get_count = info.count

		local function rep (comp)
			if comp then
				get_count = comp
			else
				for _ = 1, count or get_count() do
					local at_limit = bind.AtLimit() -- will the next call fail?

					Events.next(rep)

					if at_limit then
						return Events.cancelled(rep)					
					end
				end
			end
		end

		local pubsub = params.pubsub

		bind.Subscribe(pubsub, info.get_count, rep)

		for k, v in pairs(Events) do
			v.Subscribe(rep, info[k], pubsub)
		end

		return rep, "no_next" -- using own next, so suppress stock version
	end
end