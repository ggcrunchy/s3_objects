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
local expression = require("s3_utils.state.expression")
local state_vars = require("config.StateVariables")

-- Exports --
local M = {}

--
--
--

local LinkSuper

local function LinkValue (bvalue, other, sub, other_sub, links)
	if sub == "value" then
		bvalue.value = other.uid
	else
		LinkSuper(bvalue, other, sub, other_sub, links)
	end
end

local Args = { x = false }

--- DOCME
function M.Make (vtype, gdef, suffix, choice_pairs, def_choice, rtype)
	rtype = rtype or vtype

	local list_opts, ops = { value_name = "choice" }, {}

	for i = 1, #choice_pairs, 2 do
		local name = choice_pairs[i]

		list_opts[#list_opts + 1] = name
		ops[name] = choice_pairs[i + 1]
	end

	local function EditorEvent (what, arg1, arg2, arg3)
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Item to build
		if what == "build" then
			if arg2.use_expression then
				arg3.arg, arg3.choice = nil
			else
				arg3.expression = nil
			end

			arg3.use_expression = nil

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.choice = def_choice
			arg1.expression = ""
			arg1.use_expression = false

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()

			arg1:AddCheckbox{ text = "Use expression?", value_name = "use_expression" }

			local expression_section = arg1:BeginSection()

				arg1:AddString{ before = "Expression:", value_name = "expression" }

			arg1:EndSection()

			local ops_section = arg1:BeginSection()

				arg1:AddString{ text = "Choices", is_static = true }
				arg1:AddListbox(list_opts)
				-- TODO: on-demand way to extend with arg

			arg1:EndSection()

			--
			arg1:SetStateFromValue_Watch(expression_section, "use_expression")
			arg1:SetStateFromValue_Watch(ops_section, "use_expression", "use_false")

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = { friendly_name = state_vars.abbreviations[rtype] .. ": result", is_source = true }
			arg1.value = state_vars.abbreviations[vtype] .. ": source value"

		-- Get Tag --
		elseif what == "get_tag" then
			return "unary_" .. suffix

		-- New Tag --
		elseif what == "new_tag" then
			return "extend_properties", nil, { [vtype] = "value" }

		-- Prep Value Link --
		-- arg1: Parent handler
		elseif what == "prep_link:value" then
			LinkSuper = LinkSuper or arg1

			return LinkValue
		
		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			if not arg1.links:HasLinks(arg3, "value") then
				arg1[#arg1 + 1] = "`" .. arg1.links:GetTag(arg3) .. "` action has no `value` link"
			end

			if arg2.use_expression then
				local expr_object, err = expression.Process(gdef, arg2.expression)

				if not expr_object then
					arg1[#arg1 + 1] = err
				elseif expr_object(Args, "check_no_unbound_vars") then
					arg1[#arg1 + 1] = "Expression contains unbound variables; only `x` allowed"
				end
			end
		end
	end

	return function(info, wname)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return rtype
		else
			local wlist, getter, value = wname or "loading_level"

			if info.expression then
				local expr_object = expression.Process(gdef, info.expression)

				function getter (comp)
					if value then
						Args.x = value

						return expr_object(Args)
					else
						value = comp
					end
				end
			else
				local op, arg = ops[info.choice], info.arg

				function getter (comp)
					if value then
						return op(value(), arg)
					else
						value = comp
					end
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