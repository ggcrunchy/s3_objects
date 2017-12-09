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
local max = math.max
local next = next
local pairs = pairs
local tonumber = tonumber

-- Modules --
local bind = require("tektite_core.bind")

--
--
--

local LinkSuper

local function LinkSequence (sequence, other, ssub, other_sub, links)
	local instance_to_index = sequence.named_labels
	local index = instance_to_index and instance_to_index[ssub]

	if index then
		local list = sequence.stages or {}

		bind.AddId(list, index, other.uid, other_sub)

		sequence.stages = list

		-- Cull the labels. In most circumstances IDs could be bound directly into the table,
		-- but this accounts for the case of labels also being instance names. (This is rather
		-- paranoid since these should be indices.)
		instance_to_index[ssub] = nil

		if next(instance_to_index, nil) == nil then
			sequence.named_labels = nil
		end
	else
		LinkSuper(sequence, other, ssub, other_sub, links)
	end
end

local function EditorEvent (what, arg1, _, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Entry
	-- arg3: Built
	if what == "build" then
		arg3.named_labels = arg3.labeled_instances

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1["stages*"] = "Stages, in order"

	-- Get Tag --
	elseif what == "get_tag" then
		return "sequence" 

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", nil, "stages*"

	-- Prep Action Link --
	-- arg1: Parent handler
	elseif what == "prep_link:action" then
		LinkSuper = LinkSuper or arg1

		return LinkSequence
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local n, builder, object_to_broadcaster = 0, bind.BroadcastBuilder()

		if info.stages then
			for index, id in pairs(info.stages) do
				index = tonumber(index)
				n = max(index, n)

				bind.Subscribe(wlist, id, builder, index)
			end
		end

		return function()
			for i = 1, n do
				local func = object_to_broadcaster[i]

				if func then
					func("fire", false)
				end
			end
		end
	end
end