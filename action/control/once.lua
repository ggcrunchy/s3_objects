--- Do some action at most once.

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

-- Modules --
local bind = require("corona_utils.bind")
local object_vars = require("config.ObjectVariables")

--
--
--

local Next = bind.BroadcastBuilder_Helper(nil)

local function LinkOnce (once, other, osub, other_sub)
	if osub == "next" then
		bind.AddId(once, osub, other.uid, other_sub)
	end
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		arg3.persist_across_reset = arg2.persist_across_reset or nil

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.persist_across_reset = true

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ value_name = "persist_across_reset", text = "Persist across reset?" }

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Attempt event (one time only)"
		arg1.next = { friendly_name = "Event", is_source = true }

	-- Get Tag --
	elseif what == "get_tag" then
		return "once"

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkOnce

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "next") then
			arg1[#arg1 + 1] = "Once requires event"
		end
	end
end

local function NewOnce (info, params)
	local is_stale = object_vars.MakeStaleSessionPredicate(info.persist_across_reset)
	local done

	local function once ()
		if is_stale() then
			done = nil
		end

		if not done then
			done = not bind.AtLimit() -- will the next call fail?

			Next(once)
		end
	end

	local pubsub = params.pubsub

	Next.Subscribe(once, info.next, pubsub)

	return once, "no_next" -- using own next, so suppress stock version
end

return { game = NewOnce, editor = EditorEvent }