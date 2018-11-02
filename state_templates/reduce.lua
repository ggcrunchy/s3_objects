--- Common logic used to reduce multiple values to a result.

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
local adaptive = require("tektite_core.table.adaptive")
local bind = require("corona_utils.bind")
local object_vars = require("config.ObjectVariables")

-- Exports --
local M = {}

--
--
--

local function LinkReduce (reduce, other, rsub, other_sub)
	if rsub == "values" then
		bind.AddId(reduce, rsub, other.uid, other_sub)

		return true
	end
end

--- DOCME
function M.Make (vtype, suffix, choice_pairs, def_choice, defs, rtype)
	rtype = rtype or vtype

	local list_opts, ops = { value_name = "choice" }, {}

	for i = 1, #choice_pairs, 2 do
		local name = choice_pairs[i]

		list_opts[#list_opts + 1] = name
		ops[name] = choice_pairs[i + 1]
	end

	local function EditorEvent (what, arg1, _, arg3)
		-- Enumerate Defaults --
		-- arg1: Defaults
		if what == "enum_defs" then
			arg1.choice = def_choice

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddString{ text = "Choices", is_static = true }
			arg1:AddListbox(list_opts)

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "values",
				{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = object_vars.abbreviations[rtype] .. ": Result"
			arg1.values = object_vars.abbreviations[vtype] .. "S: Source values"

		-- Get Tag --
		elseif what == "get_tag" then
			return "reduce_" .. suffix

		-- New Tag --
		elseif what == "new_tag" then
			return "extend_properties", nil, { [vtype] = "values+" }

		-- Prep Value Link --
		elseif what == "prep_link:value" then
			return LinkReduce
		
		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			arg1[#arg1 + 1] = "`" .. arg1.links:GetTag(arg3) .. "` has no `values` links"
		end
	end

	return function(info, params)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return rtype
		else
			local def, op, getter, values = defs[info.choice], ops[info.choice]

			if def == nil then
				def = defs.default
			end

			function getter (comp)
				if comp then
					values = adaptive.Append(values, comp)
				else
					local result = def

					for _, value in adaptive.IterArray(values) do
						result = op(result, value())
					end

					return result
				end
			end

			local pubsub = params.pubsub

			bind.Subscribe(pubsub, info.value, getter)

			return getter
		end
	end
end

-- Export the module.
return M