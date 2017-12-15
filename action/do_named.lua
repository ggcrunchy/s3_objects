--- Given a hashmap of actions, do the ones referred to by a name.

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

--
--
--

local Events = { on_bad_name = bind.BroadcastBuilder_Helper(nil) }
local InProperties = { uint = "get_name" }

local LinkSuper

local function LinkDoNamed (named, other, nsub, other_sub, links)
	local helper = bind.PrepLink(named, other, nsub, other_sub)

	helper("try_events", Events)
	helper("try_in_properties", InProperties)
	helper("try_in_instances", "named_labels", "choices")

	if not helper("commit") then
		LinkSuper(named, other, nsub, other_sub, links)
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
			{ text = "LAUNCH", font = "bold", color = "unary_action" }, "get_name", "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "can_fire",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "choices*", "on_bad_name", "next", "instead"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1["choices*"] = { friendly_name = "Map of choices", is_set = true }
		arg1.fire = "Launch it"
		arg1.get_name = "Choose action"
		arg1.on_bad_name = "On(bad name)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "do_named"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", { ["choices*"] = true, on_bad_name = true }, nil, nil, InProperties

	-- Prep Action Link --
	-- arg1: Parent handler
	elseif what == "prep_link:action" then
		LinkSuper = LinkSuper or arg1

		return LinkDoNamed
	
	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		local tag_db, instances, names = arg1.links:GetTagDatabase(), arg1.get_instances(arg3)

		for i = 1, #(instances or "") do
			if tag_db:GetTemplate("do_named", instances[i]) == "choices*" then
				names = names or {}

				local label = arg1.get_label(instances[i])

				if names[label] then
					arg1[#arg1 + 1] = "Name `" .. label .. "`has shown up more than once"
				else
					names[label] = true
				end
			end
		end

		if not arg1.links:HasLinks(arg3, "get_name") then
			arg1[#arg1 + 1] = "do_named actions require `get_name` link"
		end
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local builder, object_to_broadcaster = bind.BroadcastBuilder()

		if info.choices then
			for name, id in pairs(info.choices) do
				bind.Subscribe(wlist, id, builder, name)
			end
		end

		local missing = info.named_labels and {} -- if this is still present, these labels were unassigned

		if missing then
			for _, label in pairs(info.named_labels) do
				missing[label] = true
			end
		end

		local get_name

		local function do_named (comp)
			if comp then
				get_name = comp
			else
				local name = get_name()
				local func = object_to_broadcaster[name]

				if func then
					func("fire", false)
				elseif missing and missing[name] then
					Events.on_bad_name(do_named, "fire", false)
				end
			end
		end

		Events.on_bad_name.Subscribe(do_named, info.on_bad_name, wlist)

		bind.Publish(wlist, info.get_name, do_named)

		return do_named
	end
end