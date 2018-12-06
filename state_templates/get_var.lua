--- Common logic used to fetch a variable.

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
local frames = require("corona_utils.frames")
local object_vars = require("config.ObjectVariables")
local store = require("s3_utils.state.store")

-- Exports --
local M = {}

--
--
--

local function GetValue (family, vtype, name, def)
	local value = store.GetVariable(family, vtype, name)

	if value == nil then
		return def
	else
		return value
	end
end

local function LinkGetter (getter, other, gsub, other_sub)
	if gsub == "get_family" then
		bind.AddId(getter, "get_family", other.uid, other_sub)

		return true
	end
end

local UpdatePolicy = { value_name = "update_policy", column = { "cached", "uncached", "bake" }, before = "Update policy:" }

local function WillBake (policy)
	return policy == "bake"
end

function M.Make (vtype, def)
	local function EditorEvent (what, arg1, arg2, arg3)
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Item to build
		if what == "build" then
			if arg2.get_family then
				arg3.family = nil
			end

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.family = object_vars.families[#object_vars.families]
			arg1.update_policy = "cached"
			arg1.var_name = ""
	
		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddFamilyList{ value_name = "family", before = "Family:" }
			arg1:AddString{ before = "Variable name:", value_name = "var_name" }
			arg1:AddDropdown(UpdatePolicy)

			local fresh_section = arg1:BeginSection()

				arg1:AddCheckbox{ text = "Can baked value be reset?", value_name = "can_go_stale" }

			arg1:EndSection()
			arg1:SetStateFromValue_Watch(fresh_section, "update_policy", WillBake)

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_family",
				{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = object_vars.abbreviations[vtype] .. ": Get value"
			arg1.get_family = "FAM: Variable family"

		-- Get Tag --
		elseif what == "get_tag" then
			return "get_" .. vtype .. "_var"

		-- New Tag --
		elseif what == "new_tag" then
			return "extend_properties", nil, { family = "get_family" }

		-- Prep Value Link --
		elseif what == "prep_link:value" then
			return LinkGetter
		end
	end

	local function NewGetVar (info, params)
		local name, family, getter = info.var_name

		if info.update_policy == "cached" then
			local id, value

			function getter (comp)
				if comp then
					family = comp
				else
					local fid = frames.GetFrameID()

					if fid ~= id then
						id, value = fid, GetValue(family, vtype, name, def)
					end

					return value
				end
			end
		elseif info.update_policy == "bake" then
			local can_go_stale, session_id, value = info.stale_on_reset

			function getter (comp)
				if comp then
					family = comp
				else
					if can_go_stale then
						local id = object_vars.GetSessionID()

						if id ~= session_id then
							session_id, value = id
						end
					end

					if value == nil then
						value = GetValue(family, vtype, name, def)
					end

					return value
				end
			end
		else
			function getter (comp)
				if comp then
					family = comp
				else
					return GetValue(family, vtype, name, def)
				end
			end
		end

		local pubsub = params.pubsub

		if info.get_family then
			bind.Subscribe(pubsub, info.get_family, getter)
		else
			family = info.family
		end

		return getter
	end

	return { game = NewGetVar, editor = EditorEvent, value_type = vtype }
end

-- Export the module.
return M