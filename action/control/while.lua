--- Do some condition while some condition persists.

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

local InProperties = { boolean = "continue" }

local function LinkWhile (wloop, other, wsub, other_sub)
	local helper = bind.PrepLink(wloop, other, wsub, other_sub)

	helper("try_events", Events)
	helper("try_in_properties", InProperties)

	return helper("commit")
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Get Link Grouping --
	if what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "continue",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next", "cancelled"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.cancelled = "Loop cancelled"
		arg1.continue = "BOOL: Continue?"
		arg1.fire = "Iterate event"
		arg1.next = "Event"

	-- Get Tag --
	elseif what == "get_tag" then
		return "while"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", "cancelled", nil, nil, InProperties

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkWhile

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "next") then
			arg1[#arg1 + 1] = "While requires event"
		end
	end
end

local function NewWhile (info, params)
	local continue

	local function wloop (comp)
		if comp then
			continue = comp
		else
			while continue() do
				local at_limit = bind.AtLimit() -- will the next call fail?

				Events.next(wloop)

				if at_limit then
					return Events.cancelled(wloop)					
				end
			end
		end
	end

	local pubsub = params.pubsub

	bind.Subscribe(pubsub, info.continue, wloop)

	for k, v in pairs(Events) do
		v.Subscribe(wloop, info[k], pubsub)
	end

	return wloop, "no_next" -- using own next, so suppress stock version
end

return { game = NewWhile, editor = EditorEvent }