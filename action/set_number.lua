--- Assign to a number in the store.

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

local function EditorEvent (what, arg1)
	-- Enumerate Properties --
	-- arg1: Dialog
	if what == "enum_props" then
		-- Family, name

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.set = { friendly_name = "NUM: set value" }
		arg1["mirble*"] = { friendly_name = "BLRGH"--[[, is_set = true]], is_source = true }

	-- Get Tag --
	elseif what == "get_tag" then
		return "set_number" -- TODO: derives from action?

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", nil, nil, { number = { ["mirble*"] = true } }, { number = "set" }
	end
end

return function(info)
	if info == "editor_event" then
		return EditorEvent
		-- unary transform?
	else
		local family, name -- TODO (or constant?)

		return function()
			return -- TODO!
		end
	end
end