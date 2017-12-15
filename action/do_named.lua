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

-- Exports --
local M = {}

--
--
--

local LinkSuper

local function LinkDoNamed (named, other, nsub, other_sub, links)
	local helper = bind.PrepLink(named, other, nsub, other_sub)

	helper("try_in_instances", "named_labels", "choices")

	if not helper("commit") then
		LinkSuper(named, other, nsub, other_sub, links)
	end
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Entry
	-- arg3: Built
	if what == "build" then
		arg3.named_labels = arg3.labeled_instances

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "can_fire",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next", "instead", "choices*"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Launch choice"
		arg1["choices*"] = { friendly_name = "Map of choices", is_set = true }

	-- Get Tag --
	elseif what == "get_tag" then
		return "do_named"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", "choices*", nil

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
					arg1[#arg1] = "Name `" .. label .. "`has shown up more than once"
				else
					names[label] = true
				end
			end
		end

		-- Has indexing link...
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local builder, object_to_broadcaster = bind.BroadcastBuilder()

		if info.choices then
			for name, id in pairs(info.choices) do
				-- TODO: Include a no-op under some nonce, just to know it's one of our keys?

				bind.Subscribe(wlist, id, builder, name)
			end
		end

		return function()
			--[[
				get name
	
				local func = object_to_broadcaster[name]

				if func then
					func("fire", false)
				end

				-- any way to detect "bad" name?
					-- possible as above about no-op
			end
			]]
		end
	end
end