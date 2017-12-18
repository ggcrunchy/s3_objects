--- Converts a number to an integer.

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

--
--
--

local function LinkToInteger (to_int, other, sub, other_sub)
	if sub == "value" then
		bind.AddId(to_int, sub, other.uid, other_sub)

		return true
	end
end

local Methods = { ceiling = math.ceil, floor = math.floor, round = math.round }

function Methods.truncate (n)
	if n < 0 then
		local rem = n % 1

		if n + rem^2 == n then
			return n
		else
			return n - rem + 1
		end
	else
		return n - n % 1
	end
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Enumerate Defaults --
	-- arg1: Defaults
	if what == "enum_defs" then
		arg1.method = "round"

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddListbox{ value_name = "method", "ceiling", "floor", "round", "truncate" }

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "value",
			{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get = "INT: Result"
		arg1.value = "NUM: Value to convert"

	-- Get Tag --
	elseif what == "get_tag" then
		return "to_integer"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", nil, { number = "value" }

	-- Prep Value Link --
	elseif what == "prep_link:value" then
		return LinkToInteger

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "value") then
			arg1[#arg1 + 1] = "to_integer has no `value` link"
		end
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	elseif info == "value_type" then
		return "integer"
	else
		local method, value = Methods[info.method]

		local function to_integer (comp)
			if value then
				return method(value())
			else
				value = comp
			end
		end

		bind.Subscribe(wlist, info.value, to_integer)

		return to_integer
	end
end