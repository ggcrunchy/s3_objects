--- Common logic used to assign a variable.

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
local bind = require("solar2d_utils.bind")
local object_vars = require("config.ObjectVariables")
local store = require("s3_utils.state.store")

-- Exports --
local M = {}

--
--
--

local function LinkSetter (setter, other, ssub, other_sub)
	if ssub == "get_family" or ssub == "value" then
		bind.AddId(setter, ssub, other.uid, other_sub)

		return true
	end
end

--- DOCME
function M.Make (vtype)
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
			arg1.var_name = ""
			
		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddFamilyList{ value_name = "family", before = "Family:" }
			arg1:AddString{ before = "Variable name:", value_name = "var_name" }

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "SET " .. vtype:upper(), font = "bold", color = "unary_action" }, "value", "fire",
				{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_family",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.fire = "Set it"
			arg1.get_family = "FAM: Variable family"
			arg1.value = object_vars.abbreviations[vtype] .. ": Value to set"

		-- Get Tag --
		elseif what == "get_tag" then
			return "set_" .. vtype

		-- New Tag --
		elseif what == "new_tag" then
			return "extend_properties", nil, { family = "get_family", [vtype] = "value" }

		-- Prep Action Link --
		elseif what == "prep_link:action" then
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

	local function NewSetVar (info, params)
		local name, family, value = info.var_name

		local function setter (comp, get_family)
			if comp then
				if get_family then
					family = comp()
				else
					value = comp
				end
			else
				store.SetVariable(family, vtype, name, value())
			end
		end

		local pubsub = params.pubsub

		bind.Subscribe(pubsub, info.value, setter)

		if info.get_family then
			bind.Subscribe(pubsub, info.get_family, setter, true)
		else
			family = info.family
		end

		return setter
	end

	return { make = NewSetVar, editor = EditorEvent }
end

return M