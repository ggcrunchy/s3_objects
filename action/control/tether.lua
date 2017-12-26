--- Tether one event to another.

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

--
--
--

local function EditorEvent (what, arg1, _, arg3)
	-- Get Link Grouping --
	if what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" },
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }
			-- ^^ Filled in automatically
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "From"
		arg1.next = "Tether to"

	-- Get Tag --
	elseif what == "get_tag" then
		return "tether"

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "next") then
			arg1[#arg1 + 1] = "Tether must have target"
		end
	end
end

return function(info, _)
	if info == "editor_event" then
		return EditorEvent
	else
		return nil -- No body
	end
end