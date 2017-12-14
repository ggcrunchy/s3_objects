--- Common logic used to reduce a pair of values of a given type to a result.

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
	if sub == "pick_first" or sub == "value1" or sub == "value2" then
		bind.AddId(bvalue, sub, other.uid, other_sub)
	else
		LinkSuper(bvalue, other, sub, other_sub, links)
	end
end

local Args = { x = false, y = false }

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
				arg3.pick_first = nil
			else
				arg3.expression = nil
			end

			if arg2.pick_first or arg2.use_expression then
				arg3.choice, arg3.arg = nil
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

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "value1", "value2", "pick_first",
				{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = state_vars.abbreviations[rtype] .. ": Result"
			arg1.pick_first = "BOOL: Pick the first value?"
			arg1.value1 = state_vars.abbreviations[vtype] .. ": Source value #1"
			arg1.value2 = state_vars.abbreviations[vtype] .. ": Source value #2"

		-- Get Tag --
		elseif what == "get_tag" then
			return "binary_" .. suffix

		-- New Tag --
		elseif what == "new_tag" then
			local targets = {
				[vtype] = { value1 = true, value2 = true }
			}

			targets.boolean = targets.boolean or {}
			targets.boolean.pick_first = true

			return "extend_properties", nil, targets

		-- Prep Value Link --
		-- arg1: Parent handler
		elseif what == "prep_link:value" then
			LinkSuper = LinkSuper or arg1

			return LinkValue
		
		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Key
		elseif what == "verify" then
			if not (arg1.links:HasLinks(arg3, "value1") and arg1.links:HasLinks(arg3, "value2")) then
				arg1[#arg1 + 1] = "Binary value `" .. arg2.name .. "` must link to two values"
			end

			if arg2.use_expression then
				local expr_object, err = expression.Process(gdef, arg2.expression)

				if not expr_object then
					arg1[#arg1 + 1] = err
				elseif expr_object(Args, "check_no_unbound_vars") then
					arg1[#arg1 + 1] = "Expression contains unbound variables; only `x` and `y` allowed"
				end
			end
		end
	end

	return function(info, wname)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return vtype
		else
			local wlist, getter, value1, value2 = wname or "loading_level"

			if info.expression then
				local expr_object = expression.Process(gdef, info.expression)

				function getter (comp)
					if value2 then
						Args.x, Args.y = value1, value2

						return expr_object(Args)
					elseif value1 then
						value2 = comp
					else
						value1 = comp
					end
				end
			elseif info.pick_first then
				local pick_first

				function getter (comp)
					if pick_first then
						if pick_first() then
							return value1()
						else
							return value2()
						end
					elseif value1 then
						value2 = comp
					elseif pick_first then
						value1 = comp
					else
						pick_first = comp
					end
				end

				bind.Subscribe(wlist, info.pick_first, getter)
			else
				local op, arg = ops[info.choice], info.arg

				function getter (comp)
					if value2 then
						return op(value1(), value2(), arg)
					elseif value1 then -- TODO: check order guarantees
						value2 = comp
					else
						value1 = comp
					end
				end
			end

			--
			bind.Subscribe(wlist, info.value1, getter)
			bind.Subscribe(wlist, info.value2, getter)

			return getter
		end
	end
end

-- Export the module.
return M