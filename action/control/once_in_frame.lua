--- Do some action at most once in a given frame.

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

-- Corona globals --
local Runtime = Runtime

--
--
--

local Next = bind.BroadcastBuilder_Helper(nil)

local function LinkOnceInFrame (oif, other, osub, other_sub)
	if osub == "next" then
		bind.AddId(oif, osub, other.uid, other_sub)
	end
end

local function EditorEvent (what, arg1, _, arg3)
	-- Get Link Info --
	-- arg1: Info to populate
	if what == "get_link_info" then
		arg1.fire = "Attempt event (once only per frame)"
		arg1.next = { friendly_name = "Event", is_source = true }

	-- Get Tag --
	elseif what == "get_tag" then
		return "once_in_frame"

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkOnceInFrame

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "next") then
			arg1[#arg1 + 1] = "Once-in-frame requires event"
		end
	end
end

local function NewOnceInFrame (info, params)
	local id

	local function once_in_frame ()
		local fid = Runtime.getFrameID()

		if fid ~= id then
			local at_limit = bind.AtLimit() -- will the next call fail?

			Next(once_in_frame)

			if not at_limit then
				id = fid
			end
		end
	end

	local pubsub = params.pubsub

	Next.Subscribe(once_in_frame, info.next, pubsub)

	return once_in_frame, "no_next" -- using own next, so suppress stock version
end

return { make = NewOnceInFrame, editor = EditorEvent }