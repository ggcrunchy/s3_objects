--- Common logic used to fetch a value, typically from the store.

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
local core = require("s3_utils.state.core")
local frames = require("corona_utils.frames")
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

local function GetValue (vtype, name, def, getter)
	local value = core.GetVariable(Families[getter], vtype, name)

	if value == nil then
		return def
	else
		return value
	end
end

local function LinkFamily (getter, other, sub, other_sub)
	if sub == "family" then
		bind.AddId(getter, "get_family", other.uid, other_sub)
	end
end

local UpdatePolicy = { var_name = "update_policy", "cached", "uncached", "bake", default = "cached" }

function M.Make (vtype, abbreviation, def)
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

			arg1:AddString{ before = "Constant value", value_name = "constant_value" } -- TODO: stringify def...
			arg1:EndSection()

			local variable_section = arg1:BeginSection()

			arg1:AddString{ text = "Family", is_static = true }
			arg1:AddFamilyList{ value_name = "family" }
			arg1:AddString{ before = "Variable name", value_name = "var_name" }
			arg1:AddString{ text = "Update policy", is_static = true }
			arg1:AddListbox(UpdatePolicy)

			-- TODO: is call?

			arg1:EndSection()

			--
			arg1:SetStateFromValue_Watch(constant_section, "variable", true)
			arg1:SetStateFromValue_Watch(variable_section, "variable")

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.family = "Variable family"
			arg1.get = { friendly_name = abbreviation .. ": get value", is_source = true }

		-- Get Tag --
		elseif what == "get_tag" then
			return "get_" .. vtype

		-- New Tag --
		elseif what == "new_tag" then
			return "extend", nil, nil, nil, { family = "family" }

		-- Prep Link --
		elseif what == "prep_link" then
			return LinkFamily
		end
	end

	return function(info, wlist)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return vtype
		else
			local k = info.constant_value

			if k then
				return function()
					return k
				end
			else
				local getter, name = info.var_name

				if info.update_policy == "cached" then
					local id, value

					function getter ()
						local fid = frames.GetFrameID()

						if fid ~= id then
							id, value = fid, GetValue(vtype, name, def, getter)
						end

						return value
					end
				elseif info.update_policy == "bake" then
					local value

					function getter ()
						if value == nil then
							value = GetValue(vtype, name, def, getter)
						end

						return value
					end
				else
					function getter ()
						return GetValue(vtype, name, def, getter)
					end
				end

				if info.get_family then
					bind.Subscribe(wlist, info.get_family, BindFamily, getter)
				else
					Families[getter] = info.family
				end

				return getter
			end
		end
	end
end

-- Export the module.
return M