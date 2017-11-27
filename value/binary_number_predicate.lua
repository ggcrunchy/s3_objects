--- Given a pair of numbers, reduce them to a boolean result.

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
local abs = math.abs

--
--
--

local maker = require("s3_objects.state_templates.binary").Make("number", nil, "number_predicate", {
	"<", function(a, b) return a < b end,
	">", function(a, b) return a > b end,
	"==", function(a, b) return a == b end,
	"~=", function(a, b) return a ~= b end,
	"<=", function(a, b) return a <= b end,
	">=", function(a, b) return a >= b end,

	"approximately", function(a, b, tolerance)
		return abs(a - b) <= tolerance
	end
}, "+", "boolean")

local editor_event = maker("editor_event")

return function()
	local function EditorEvent (what, arg1, arg2, arg3)
		-- Enumerate Properties --
		-- arg1: Dialog
		if what == "enum_props" then
			editor_event("enum_props", what, arg1)

			-- arg = tolerance
		-- Stock --
		else
			return editor_event(what, arg1, arg2, arg3)
		end
	end

	return function(info)
		if info == "editor_event" then
			return EditorEvent
		else
			return maker(info)
		end
	end
end