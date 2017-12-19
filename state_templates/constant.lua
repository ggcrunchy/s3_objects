--- Common logic used to fetch a constant.

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

-- Exports --
local M = {}

--
--
--

function M.Make (vtype, def, add_constant, fix_constant, resolve_text)
	local function EditorEvent (what, arg1, arg2, arg3)
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Item to build
		if what == "build" then
			if resolve_text then
				arg3.constant_value = resolve_text(arg2.constant_value)
			end

			arg3.defer_evaluation = nil

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.constant_value = def

			if fix_constant then
				arg1.defer_evaluation = true
			end

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			add_constant(arg1)

			if fix_constant then
				arg1:AddCheckbox{ value_name = "defer_evaluation", text = "Defer evaluation?" }
			end

		-- Get Tag --
		elseif what == "get_tag" then
			return vtype .. "_constant"

		-- New Tag --
		elseif what == "new_tag" then
			return "extend", "no_before"

		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			if arg2.defer_evaluation and not resolve_text(arg2.constant_value) then
				arg1[#arg1 + 1] = "Invalid constant"
			end
		end
	end

	return function(info, _)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return vtype
		else
			local k = info.constant_value

			if fix_constant then
				k = fix_constant(k)
			end

			return function()
				return k
			end
		end
	end
end

-- Export the module.
return M