--- Common logic used to maintain a name-value map.

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
local abs = math.abs
local min = math.min
local pairs = pairs

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local args = require("iterator_ops.args")
local bind = require("corona_utils.bind")
local object_vars = require("config.ObjectVariables")
local table_funcs = require("tektite_core.table.funcs")

-- Exports --
local M = {}

--
--
--

local Events = {}

for _, name in args.Args(
	"on_insert", "on_remove", "on_insert_when_full", "on_remove_when_empty", "on_became_empty", "on_became_full", "on_bad_get_key", "on_bad_remove_key", "on_already_has_key", "on_replace", "on_not_found"
) do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local Actions = {
	-- Insert --
	do_insert = function(map)
		return function()
			local limit, t, n = map("limit"), map("table"), map("n")
			local key, can_replace = map("insert_key")

			if t[key] ~= nil then
				if can_replace then
					t[key] = map("value")

					Events.on_replace(map)
				else
					Events.on_already_has_key(map)
				end
			elseif n < limit then
				t[key] = map("value")

				map("n", n + 1)

				Events.on_insert(map)

				if n + 1 == limit then
					Events.on_became_full(map)
				end
			else
				Events.on_insert_when_full(map)
			end
		end
	end,

	-- Remove --
	do_remove = function(map)
		return function()
			local t, n = map("table"), map("n")

			if n > 0 then
				local key = map("remove_key")

				if t[key] ~= nil then
					t[key] = nil

					map("n", n - 1)

					Events.on_remove(map)

					if n == 1 then
						Events.on_became_empty(map)
					end
				else
					Events.on_bad_remove_key(map)
				end
			else
				Events.on_remove_when_empty(map)
			end
		end
	end
}

local InPropertiesBase = {
	uint = "get_limit", string = { get_key = true, get_insert_key = true, get_remove_key = true }
}

local OutProperties = {
	boolean = {
		-- Contains --
		contains = function(map)
			return function()
				local value, t, comp, tolerance = map("value"), map("table")

				for _, v in pairs(t) do
					if comp(v, value, tolerance) then
						return true
					end
				end

				return false
			end
		end,

		-- Empty --
		empty = function(map)
			return function()
				return map("n") == 0
			end
		end
	},

	uint = {
		-- Count --
		count = function(map)
			return map("n")
		end,

		-- Find --
		find = function(map)
			return function()
				local n = map("n")

				if n > 0 then
					local value, t, comp, tolerance = map("value"), map("table")

					for k, v in pairs(t) do
						if comp(v, value, tolerance) then
							return k
						end
					end
				end

				Events.on_not_found(map)

				return ""
			end
		end
	}
}

local function Equal (a, b)
	return a == b
end

local function Approx (a, b, tolerance)
	return abs(a - b) < tolerance
end

local MaxLimit = 100

--- DOCME
function M.Make (vtype, def, has_tolerance)
	local InProperties = table_funcs.Copy(InPropertiesBase)
	local vin = InProperties[vtype]

	vin = vin and table_funcs.Copy(vin) or {}
	InProperties[vtype], vin.get_value = vin, true

	local function LinkMap (map, other, msub, other_sub)
		local helper = bind.PrepLink(map, other, msub, other_sub)

		helper("try_events", Events)
		helper("try_actions", Actions)
		helper("try_in_properties", InProperties)
		helper("try_out_properties", OutProperties)

		return helper("commit")
	end

	local function EditorEvent (what, arg1, arg2, arg3)
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Item to build
		if what == "build" then
			if not (arg2.contains or arg2.find) then
				arg3.tolerance = nil
			end

			if not arg2.do_insert then
				arg3.do_insert, arg3.get_insert_key = nil
			end

			if not arg2.do_remove then
				arg3.get_remove_key = nil
			end

			if not arg2.get then
				arg3.get_key = nil
			end

			if arg2.get_limit then
				arg2.limit = nil
			end

			arg3.allow_replacement = arg2.allow_replacement or nil
			arg3.persist_across_reset = arg2.persist_across_reset or nil

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			if has_tolerance then
				arg1.tolerance = 1e-6
			end

			arg1.allow_replacement = true
			arg1.persist_across_reset = false
			arg1.limit = 1
			
		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddStepperWithEditable{ before = "Limit:", value_name = "limit", min = 1, max = MaxLimit }

			if has_tolerance then
				arg1:AddStepperWithEditable{ before = "Tolerance:", value_name = "tolerance", min = 1, scale = 1e-6 }
			end

			arg1:AddCheckbox{ value_name = "allow_replacement", text = "Can overwrite values?" }
			arg1:AddCheckbox{ value_name = "persist_across_reset", text = "Persist across reset?" }

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "INSERT " .. vtype:upper(), font = "bold", color = "unary_action" }, "get_insert_key", "get_value", "do_insert",
				{ text = "REMOVE " .. vtype:upper(), font = "bold", color = "unary_action" }, "get_remove_key", "do_remove",
				{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_key", "get_limit",
				{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get", "count", "empty", "contains", "find",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before", "on_insert", "on_remove", "on_became_full", "on_became_empty", "on_insert_when_full", "on_remove_when_empty", "on_bad_get_key", "on_bad_remove_key", "on_already_has_key", "on_replace", "on_not_found"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.contains = "BOOL: Value is in map?"
			arg1.count = "UINT: # of values in map"
			arg1.do_insert = "Insert it"
			arg1.do_remove = "Remove it"
			arg1.empty = "BOOL: Is map empty?"
			arg1.find = "UINT: Index of value (if absent, 0)"
			arg1.get = object_vars.abbreviations[vtype] .. ": Get value at key"
			arg1.get_insert_key = "STR: Key in which to place value"
			arg1.get_limit = object_vars.abbreviations[vtype] .. ": Pending value"
			arg1.get_key = "STR: Key of value to get"
			arg1.get_remove_key = "STR: Key of value to remove"
			arg1.get_value = object_vars.abbreviations[vtype] .. ": Value to insert / compare"
			arg1.on_insert = "On(insert)"
			arg1.on_insert_when_full = "On(tried inserting when full)"
			arg1.on_already_has_key = "On(already has key)"
			arg1.on_bad_get_key = "On(bad get key)"
			arg1.on_bad_remove_key = "On(bad remove key)"
			arg1.on_became_empty = "On(became empty)"
			arg1.on_became_full = "On(became full)"
			arg1.on_get_when_empty = "On(tried to get when empty)"
			arg1.on_not_found = "On(not found)"
			arg1.on_remove = "On(remove)"
			arg1.on_remove_when_empty = "On(tried removing when empty)"
			arg1.on_replace = "On(replace key)"

		-- Get Tag --
		elseif what == "get_tag" then
			return vtype .. "_map"

		-- New Tag --
		elseif what == "new_tag" then
			return "extend", Events, Actions, object_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties), InProperties

		-- Prep Value Link --
		elseif what == "prep_link:value" then
			return LinkMap

		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			local has_value = arg1.links:HasLinks(arg3, "get_value")

			if not has_value then
				for _, what in args.Args("do_add", "do_insert", "contains", "find") do
					if arg1.links:HasLinks(arg3, what) then
						arg1[#arg1 + 1] = "`" .. arg1.links:GetTag(arg3) .. "` has no `get_value` link for `" .. what .. "`"
					end
				end
			end

			for _, aname, pname in args.ArgsByN(2, "get", "get_key", "do_insert", "get_insert_key", "do_remove", "get_remove_key") do
				if arg1.links:HasLinks(arg3, aname) and not arg1.links:HasLinks(arg3, pname) then
					arg1[#arg1 + 1] = "`" .. arg1.links:GetTag(arg3) .. "` has no `" .. pname .. "` link for `" .. aname .. "`"
				end
			end
		end
	end

	return function(info, wlist)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return vtype
		else
			local is_stale = object_vars.MakeStaleSessionPredicate(info.persist_across_reset)
			local can_replace, limit, tolerance, n, t = info.allow_replacement, info.limit, info.tolerance, 0
			local get_limit, get_value, get_key, get_insert_key, get_remove_key

			local function map (what, arg)
				if is_stale() then
					n, t = 0

					if get_limit then
						limit = nil
					end
				end

				t = t or {}

				if what then
					if what == "n" then
						if arg then
							n = arg
						else
							return n
						end
					elseif what == "table" then
						return t, has_tolerance and Approx or Equal, tolerance
					elseif what == "value" then -- does double duty in bind and later calls
						get_value = get_value or arg

						return get_value()
					elseif what == "limit" then -- ditto
						if not limit then -- absence implies get_limit is available
							get_limit = get_limit or arg
							limit = min(get_limit(), MaxLimit)
						end

						return limit
					elseif what == "insert_key" then -- ditto
						get_insert_key = get_insert_key or arg

						return get_insert_key(), can_replace
					elseif what == "remove_key" then -- ditto
						get_remove_key = get_remove_key or arg

						return get_remove_key
					elseif what == "key" then
						get_key = arg
					end
				else
					local value = t[get_key()] -- verified to exist

					if value ~= nil then
						return value
					else
						Events.on_bad_get_key(map)

						return def
					end
				end
			end

			for _, name in args.Args("insert_key", "limit", "key", "remove_key", "value") do 
				bind.Subscribe(wlist, info["get_" .. name], map, name)
			end

			for k, event in pairs(Events) do
				event.Subscribe(map, info[k], wlist)
			end

			for k in adaptive.IterSet(info.actions) do
				bind.Publish(wlist, Actions[k](map), info.uid, k)
			end

			object_vars.PublishProperties(info.props, OutProperties, info.uid, map)

			return map
		end
	end
end

-- Export the module.
return M