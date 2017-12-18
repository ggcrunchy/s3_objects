--- Do one action or another according to some condition.

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

local Events = {}

for _, name in ipairs{ "instead", "next" } do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local InProperties = { boolean = "should_do_next" }

local function LinkBranch (branch, other, bsub, other_sub)
	local helper = bind.PrepLink(branch, other, bsub, other_sub)

	helper("try_events", Events)
	helper("try_in_properties", InProperties)

	return helper("commit")
end

local function EditorEvent (what, arg1, _, arg3)
	-- Get Link Grouping --
	if what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "should_do_next",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next", "instead"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Do choice"
		arg1.instead = "Instead"
		arg1.next = "Next"
		arg1.should_do_next = "BOOL: Do 'Next'?"

	-- Get Tag --
	elseif what == "get_tag" then
		return "branch"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", "instead", nil, nil, InProperties

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkBranch

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "should_do_next") then
			arg1[#arg1 + 1] = "Branch requires decision predicate"
		end
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local should_do_next

		local function branch (comp)
			if comp then
				should_do_next = comp
			else
				Events[should_do_next() and "next" or "instead"](branch)
			end
		end

		bind.Subscribe(wlist, info.should_go_next, branch)

		for k, event in pairs(Events) do
			event.Subscribe(branch, info[k], wlist)
		end

		return branch, "no_next" -- using own next, so suppress stock version
	end
end