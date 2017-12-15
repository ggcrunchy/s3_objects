--- Given an array of actions, do the ones referred to by an index.

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
local pairs = pairs
local tonumber = tonumber

-- Modules --
local bind = require("tektite_core.bind")

--
--
--

local Events = { on_bad_index = bind.BroadcastBuilder_Helper(nil) }
local InProperties = { uint = "get_index" }

local LinkSuper

local function LinkDoIndexed (indexed, other, isub, other_sub, links)
	local helper = bind.PrepLink(indexed, other, isub, other_sub)

	helper("try_events", Events)
	helper("try_in_properties", InProperties)
	helper("try_in_instances", "named_labels", "choices")

	if not helper("commit") then
		LinkSuper(indexed, other, isub, other_sub, links)
	end
end

local function EditorEvent (what, arg1, _, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Entry
	-- arg3: Built
	if what == "build" then
		arg3.named_labels = arg3.labeled_instances

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "LAUNCH", font = "bold", color = "unary_action" }, "get_index", "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "can_fire",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "choices*", "on_bad_index", "next", "instead"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1["choices*"] = "Array of choices"
		arg1.fire = "Launch it"
		arg1.get_index = "Choose action"
		arg1.on_bad_index = "On(bad index)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "do_indexed"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", { ["choices*"] = true, on_bad_index = true }, nil, nil, InProperties

	-- Prep Action Link --
	-- arg1: Parent handler
	elseif what == "prep_link:action" then
		LinkSuper = LinkSuper or arg1

		return LinkDoIndexed

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "get_indexed") then
			arg1[#arg1 + 1] = "do_indexed actions require `get_index` link"
		end
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local n, builder, object_to_broadcaster = 0, bind.BroadcastBuilder()

		if info.stages then
			for index, id in pairs(info.choices) do
				index = tonumber(index)
				n = max(index, n)

				bind.Subscribe(wlist, id, builder, index)
			end
		end

		local get_index

		local function do_indexed (comp)
			if comp then
				get_index = comp
			else
				local index = get_index()

				if index >= 1 and index <= n then
					local func = object_to_broadcaster[index]

					if func then
						func("fire", false)
					end
				else
					Events.on_bad_index(do_indexed, "fire", false)
				end
			end
		end

		Events.on_bad_index.Subscribe(do_indexed, info.on_bad_index, wlist)

		bind.Publish(wlist, info.get_index, do_indexed)

		return do_indexed
	end
end