--- Fire a series of events in sequence.

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
local ipairs = ipairs
local max = math.max
local pairs = pairs
local tonumber = tonumber

-- Modules --
local bind = require("corona_utils.bind")

--
--
--

local function LinkSequence (sequence, other, ssub, other_sub)
	local helper = bind.PrepLink(sequence, other, ssub, other_sub)

	helper("try_in_instances", "named_labels", "stages")

	return helper("commit")
end

local function CleanupSequence (sequence)
	sequence.named_labels = nil
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build Instances --
	-- arg1: Built
	-- arg2: Info
	if what == "build_instances" then
		arg1.named_labels = {}

		for _, instance in ipairs(arg2.instances) do
			arg1.named_labels[instance] = arg2.labels[instance]
		end

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Launch"
		arg1["stages*"] = { friendly_name = "Stages, in order", is_source = true }

	-- Get Tag --
	elseif what == "get_tag" then
		return "sequence" 

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", { ["stages*"] = true, no_next = true }, nil -- next is superfluous, so suppress it

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkSequence, CleanupSequence
	end
end

local function NewSequence (info, params)
	local pubsub = params.pubsub
	local n, builder, object_to_broadcaster = 0, bind.BroadcastBuilder()

	if info.stages then
		for index, id in pairs(info.stages) do
			index = tonumber(index)
			n = max(index, n)

			bind.Subscribe(pubsub, id, builder, index)
		end
	end

	return function()
		for i = 1, n do
			local func = object_to_broadcaster[i]

			if func then
				func()
			end
		end
	end
end

return { game = NewSequence, editor = EditorEvent }