--- Common logic used to assign a value in the store.

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
local pairs = pairs

-- Modules --
local bind = require("tektite_core.bind")
local state_vars = require("config.StateVariables")
local store = require("s3_utils.state.store")
local table_funcs = require("tektite_core.table.funcs")

-- Exports --
local M = {}

--
--
--

local Families = table_funcs.Weak("k")

local function BindFamily (get_family, getter)
	Families[getter] = get_family()
end

local LinkSuper

local function LinkSetter (setter, other, ssub, other_sub, links)
	if ssub == "get_family" or ssub == "value" then
		bind.AddId(setter, ssub, other.uid, other_sub)
	else
		LinkSuper(setter, other, ssub, other_sub, links)
	end
end

--- DOCME
function M.Make (vtype, def, add_constant, fix_constant)
	local function EditorEvent (what, arg1, arg2, arg3)
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Item to build
		if what == "build" then
			if arg2.variable then
				arg3.constant_value, arg3.variable = nil

				if arg2.get_family then
					arg3.family = nil
				end
			else
				for k in pairs(arg2) do
					if k ~= "constant_value" and k ~= "type" then
						arg3[k] = nil
					end
				end
			end

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.constant_value = def
			arg1.variable = true
			
		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddCheckbox{ text = "Is variable?", value_name = "variable" }

			local constant_section = arg1:BeginSection()

				add_constant(arg1)

			arg1:EndSection()

			local variable_section = arg1:BeginSection()

				arg1:AddString{ text = "Family", is_static = true }
				arg1:AddFamilyList{ value_name = "family" }
				arg1:AddString{ before = "Variable name", value_name = "var_name" }

			arg1:EndSection()

			--
			arg1:SetStateFromValue_Watch(constant_section, "variable", "use_false")
			arg1:SetStateFromValue_Watch(variable_section, "variable")

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get_family = "FAM: Variable family"
			arg1.value = state_vars.abbreviations[vtype] .. ": Value to set"

		-- Get Tag --
		elseif what == "get_tag" then
			return "set_" .. vtype

		-- New Tag --
		elseif what == "new_tag" then
			return "extend_properties", nil, { family = "get_family", [vtype] = "value" }

		-- Prep Action Link --
		-- arg1: Parent handler
		elseif what == "prep_link:action" then
			LinkSuper = LinkSuper or arg1

			return LinkSetter

		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			if not arg1.links:HasLinks(arg3, "value") then
				arg1[#arg1 + 1] = "`" .. arg1.links:GetTag(arg3) .. "` action has no `value` link"
			end
		end
	end

	return function(info, wlist)
		if info == "editor_event" then
			return EditorEvent
		else
			local k = info.constant_value

			if k then
				if fix_constant then
					k = fix_constant(k)
				end

				return function()
					return k
				end
			else
				local name, value = info.var_name

				local function setter (comp)
					if value then
						store.SetVariable(Families[setter], vtype, name, value())
					else
						value = comp
					end
				end

				bind.Subscribe(wlist, info.value, setter)

				if info.get_family then
					bind.Subscribe(wlist, info.get_family, BindFamily, setter)
				else
					Families[setter] = info.family
				end

				return setter
			end
		end
	end
end

-- Export the module.
return M