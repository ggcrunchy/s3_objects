--- Common logic used to transform a single value.

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
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

--
--
--

local function LinkValue (bvalue, other, sub)
	if sub == "value" then
		bvalue.value = other.uid
	end
end

--- DOCME
function M.Make (vtype, abbreviation, suffix, choice_pairs, def_choice)
	local list_opts, ops = { var_name = "choice", default = def_choice }, {}

	for i = 1, #choice_pairs, 2 do
		local name = choice_pairs[i]

		list_opts[#list_opts + 1] = name
		ops[name] = choice_pairs[i + 1]
	end

	local function EditorEvent (what, arg1, arg2, arg3)
		-- Enumerate Properties --
		-- arg1: Dialog
		if what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()
			arg1:AddString{ text = "Choices", is_static = true }
			arg1:AddListbox(list_opts)

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = "Query final value"
			arg1.value = "Source value"

		-- Get Tag --
		elseif what == "get_tag" then
			return "unary_" .. suffix

		-- New Tag --
		elseif what == "new_tag" then
			return "properties", {
				[vtype] = "get"
			}, {
				[vtype] = "value"
			}

		-- Prep Link --
		elseif what == "prep_link" then
			return LinkValue
		
		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Key
		elseif what == "verify" then
			-- arg1.links:HasLinks(arg2[arg3], "value")
		end
	end

	return function(info, wname)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return vtype
		else
			local wlist, op, arg, value = wname or "loading_level", ops[info.choice], info.arg

			local function getter (comp)
				if value then
					return op(value(), arg)
				else
					value = comp
				end
			end

			--
			bind.Subscribe(wlist, info.value, getter)

			return getter
		end
	end
end

-- Export the module.
return M