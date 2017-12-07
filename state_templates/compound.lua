--- Common logic used to reduce arbitrarily many named values of a given type to a result.

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
local expression = require("s3_utils.state.expression")
local state_vars = require("config.StateVariables")

-- Exports --
local M = {}

--
--
--

local LinkSuper

local function LinkCompound (cvalue, other, sub, other_sub)
	local instance_to_label = cvalue.named_labels
	local label = instance_to_label and instance_to_label[sub]

	if label then
		local list = cvalue.values or {}

		bind.AddId(list, label, other.uid, other_sub)

		cvalue.values = list
	else
		LinkSuper(cvalue, other, sub, other_sub)
	end
end

local BindingPolicy = { value_name = "binding_policy", "none", "check_match", "check_no_extra_args", "check_no_unbound_vars" }

--- DOCME
function M.Make (vtype, gdef, suffix, rtype)
	rtype = rtype or vtype

	local function EditorEvent (what, arg1, arg2, arg3)
		-- Build --
		-- arg1: Level
		-- arg2: Entry
		-- arg3: Built
		if what == "build" then
			arg3.named_labels, arg3.binding_policy = arg3.labeled_instances

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.binding_policy = "none"
			arg1.expression = ""

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddString{ before = "Expression:", value_name = "expression" }
			arg1:AddString{ text = "Binding policy", is_static = true }
			arg1:AddListbox(BindingPolicy)

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = { friendly_name = state_vars.abbreviations[rtype] .. " Result", is_source = true }
			arg1["values*"] = { friendly_name = state_vars.abbreviations[vtype] .. "S: Source values", is_set = true }

		-- Get Tag --
		elseif what == "get_tag" then
			return "compound_" .. suffix 

		-- New Tag --
		elseif what == "new_tag" then
			return "extend_properties", nil, { [vtype] = "values*" }
			-- TODO: allow booleans and indices down the road?
			-- ^^^ If either is already the vtype, simplify

		-- Prep Value Link --
		-- arg1: Parent handler
		elseif what == "prep_link:value" then
			LinkSuper = LinkSuper or arg1

			return LinkCompound

		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			local tag_db, names = arg1.links:GetTagDatabase()

			for instance in tag_db:Sublinks(arg1.links:GetTag(arg3), "values*") do
				names = names or {}

				local label = arg1.get_label(instance)

				if names[label] then
					arg1[#arg1] = "Name `" .. label .. "`has shown up more than once"
				else
					names[label] = true
				end
			end

			local expr_object, err = expression.Process(gdef, arg2.expression)

			if not expr_object then
				arg1[#arg1 + 1] = err
			elseif arg2.binding_policy ~= "none" then
				local names = nil

				if not expr_object(names, arg2.binding_policy) then
					arg1[#arg1 + 1] = "Variable / key mismatch following: `" .. arg2.error_policy .. "` policy"
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
			local wlist = wname or "loading_level"
			local expr_object, args = expression.Process(gdef, info.expression)

			local function getter (comp, name)
				if comp then
					args[name] = comp
				else
					return expr_object(args)
				end
			end

			--
			if info.values then
				args = {}

				for label, target in pairs(info.values) do
					bind.Subscribe(wlist, target, getter, label)
				end
			end

			return getter
		end
	end
end

-- Export the module.
return M