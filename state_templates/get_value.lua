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
local frames = require("corona_utils.frames")
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

local function GetValue (vtype, name, def, getter)
	local value = store.GetVariable(Families[getter], vtype, name)

	if value == nil then
		return def
	else
		return value
	end
end

local LinkSuper

local function LinkGetter (getter, other, gsub, other_sub, links)
	if gsub == "get_family" then
		bind.AddId(getter, "get_family", other.uid, other_sub)
	else
		LinkSuper(getter, other, gsub, other_sub, links)
	end
end

local UpdatePolicy = { value_name = "update_policy", "cached", "uncached", "bake" }

local function WillBake (policy)
	return policy == "bake"
end

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
			arg1.family = state_vars.families[#state_vars.families]
			arg1.update_policy = "cached"
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
				arg1:AddString{ text = "Update policy", is_static = true }
				arg1:AddListbox(UpdatePolicy)

				local fresh_section = arg1:BeginSection()

					arg1:AddCheckbox{ text = "Can baked value be reset?", value_name = "can_go_stale" }

				arg1:EndSection()
			arg1:EndSection()

			--
			arg1:SetStateFromValue_Watch(constant_section, "variable", "use_false")
			arg1:SetStateFromValue_Watch(variable_section, "variable")
			arg1:SetStateFromValue_Watch(fresh_section, "update_policy", WillBake)

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = { friendly_name = state_vars.abbreviations[vtype] .. ": Get value", is_source = true }
			arg1.get_family = "FAM: Variable family"

		-- Get Tag --
		elseif what == "get_tag" then
			return "get_" .. vtype

		-- New Tag --
		elseif what == "new_tag" then
			return "extend_properties", nil, { family = "get_family" }

		-- Prep Value Link --
		-- arg1: Parent handler
		elseif what == "prep_link:value" then
			LinkSuper = LinkSuper or arg1

			return LinkGetter
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
				if fix_constant then
					k = fix_constant(k)
				end

				return function()
					return k
				end
			else
				local name, getter = info.var_name

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
					local can_go_stale, session_id, value = info.stale_on_reset

					function getter ()
						if can_go_stale then
							local id = state_vars.GetSessionID()

							if id ~= session_id then
								session_id, value = id
							end
						end

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