--- Common logic used to maintain an array of values.

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
local insert = table.insert
local min = math.min
local pairs = pairs
local remove = table.remove
local sort = table.sort

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
	"on_add", "on_remove", "on_add_when_full", "on_remove_when_empty", "on_became_empty", "on_became_full", "on_bad_get_pos", "on_bad_insert_pos", "on_bad_remove_pos", "on_not_found"
) do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local Actions = {
	-- Add --
	do_add = function(array)
		return function()
			local limit, arr, op = array("limit"), array("array")
			local n = #arr

			if n < limit then
				op(arr, "add", n + 1, array("value"))

				Events.on_add(array)

				if n + 1 == limit then
					Events.on_became_full(array)
				end
			else
				Events.on_add_when_full(array)
			end
		end
	end,

	-- Insert --
	do_insert = function(array)
		return function()
			local limit, arr, op = array("limit"), array("array")
			local n = #arr

			if n < limit then
				local index = array("insert_pos")

				if index >= 1 and index <= n + 1 then
					op(arr, "add", index, array("value"))

					Events.on_add(array)

					if n + 1 == limit then
						Events.on_became_full(array)
					end
				else
					Events.on_bad_insert_pos(array)
				end
			else
				Events.on_add_when_full(array)
			end
		end
	end,

	-- Remove --
	do_remove = function(array)
		return function()
			local arr, op = array("array")
			local n = #arr

			if n > 0 then
				local index = array("remove_pos")

				if index >= 1 and index <= n then
					op(arr, "remove", index)

					Events.on_remove(array)

					if n == 1 then
						Events.on_became_empty(array)
					end
				else
					Events.on_bad_remove_pos(array)
				end
			else
				Events.on_remove_when_empty(array)
			end
		end
	end,

	-- Remove Last --
	do_remove_last = function(array)
		return function()
			local arr, op = array("array")
			local n = #arr

			if n > 0 then
				op(arr, "remove", n)

				Events.on_remove(array)

				if n == 1 then
					Events.on_became_empty(array)
				end
			else
				Events.on_remove_when_empty(array)
			end
		end
	end
}

local InPropertiesBase = {
	uint = { get_pos = true, get_insert_pos = true, get_limit = true, get_remove_pos = true }
}

local function First (array) -- stitched into proper type on startup
	return function()
		return array("get", 1)
	end
end

local function Last (array) -- ditto
	return function()
		local arr = array("array")

		return array("get", #arr)
	end
end

local OutPropertiesBase = {
	boolean = {
		-- Contains --
		contains = function(array)
			return function()
				local value, arr, _, comp, tolerance = array("value"), array("array")

				for i = 1, #arr do
					if comp(arr[i], value, tolerance) then
						return true
					end
				end

				return false
			end
		end,

		-- Empty --
		empty = function(array)
			return function()
				return #array("array") == 0
			end
		end
	},

	uint = {
		-- Count --
		count = function(array)
			return #array("array")
		end,

		-- Find --
		find = function(array)
			return function()
				local arr, _, comp, tolerance = array("array")
				local n = #arr

				if n > 0 then
					local value = array("value")

					if comp(array("get", 1, tolerance), value) then -- will sort array, if using deferred method
						return 1
					else
						for i = 2, n do
							if comp(arr[i], value, tolerance) then
								return i
							end
						end
					end
				end

				Events.on_not_found(array)

				return 0
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

local Ops = {
	append = function(arr, what, index, value)
		if what == "get" then
			return arr[index]
		elseif what == "insert" then
			insert(arr, index, value)
		elseif what == "remove" then
			return remove(arr, index)
		end
	end,

	deferred_sort = function(arr, what, index, value)
		local n = #arr

		if what == "insert" then
			arr[n + 1], arr.is_sorted = value, (n == 0 or arr.is_sorted) and value >= arr[n]
		else
			if not arr.is_sorted then
				sort(arr)

				arr.is_sorted = true
			end

			if what == "get" then
				return arr[index]
			else
				return remove(arr, index)
			end
		end
	end,

	insertion_sort = function(arr, what, index, value)
		if what == "get" then
			return arr[index]
		elseif what == "insert" then
			local i, n = 1, #arr

			repeat
				if value < arr[i] then
					break
				end

				i = i + 1
			until i > n

			arr[i] = value
		elseif what == "remove" then
			return remove(arr, index)
		end
	end
}

local MaxLimit = 100

--- DOCME
function M.Make (vtype, def, has_order, has_tolerance)
	local InProperties, OutProperties = table_funcs.Copy(InPropertiesBase), table_funcs.Copy(OutPropertiesBase)
	local vin, vout = InProperties[vtype], OutProperties[vtype]

	vin, vout = vin and table_funcs.Copy(vin) or {}, vout and table_funcs.Copy(vout) or {}
	InProperties[vtype], OutProperties[vtype], vin.get_value, vout.first, vout.last = vin, vout, true, First, Last

	local function LinkArray (array, other, asub, other_sub)
		local helper = bind.PrepLink(array, other, asub, other_sub)

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

			if arg2.method ~= "append" or not arg2.do_insert then
				arg3.do_insert, arg3.get_insert_pos = nil
			end

			if not arg2.do_remove then
				arg3.get_remove_pos = nil
			end

			if not arg2.get then
				arg3.get_pos = nil
			end

			if arg2.get_limit then
				arg2.limit = nil
			end

			arg3.persist_across_reset = arg2.persist_across_reset or nil

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			if has_order then
				arg1.method = "append"

				if has_tolerance then
					arg1.tolerance = 1e-6
				end
			end

			arg1.persist_across_reset = false
			arg1.limit = 1
			
		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddStepperWithEditable{ before = "Limit:", value_name = "limit", min = 1, max = MaxLimit }

			if has_order then
				arg1:AddString{ text = "Method:", is_static = true }
				arg1:AddListbox{ value_name = "method", "append", "insertion_sort", "deferred_sort" }
			end

			if has_tolerance then
				arg1:AddStepperWithEditable{ before = "Tolerance:", value_name = "tolerance", min = 1, scale = 1e-6 }
			end

			arg1:AddCheckbox{ value_name = "persist_across_reset", text = "Persist across reset?" }

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "ADD " .. vtype:upper(), font = "bold", color = "unary_action" }, "get_value", "do_add",
				{ text = "INSERT " .. vtype:upper(), font = "bold", color = "unary_action" }, "get_insert_pos", "do_insert",
				{ text = "REMOVE " .. vtype:upper(), font = "bold", color = "unary_action" }, "get_remove_pos", "do_remove",
				{ text = "ACTIONS", font = "bold", color = "unary_action" }, "do_remove_last",
				{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_pos", "get_limit",
				{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get", "first", "last", "count", "empty", "contains", "find",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before", "on_add", "on_remove", "on_became_full", "on_became_empty", "on_add_when_full", "on_remove_when_empty", "on_bad_get_pos", "on_bad_insert_pos", "on_bad_remove_pos", "on_not_found"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.contains = "BOOL: Value is in array?"
			arg1.count = "UINT: # of values in array"
			arg1.do_add = "Add it"
			arg1.do_insert = "Insert it"
			arg1.do_remove = "Remove it"
			arg1.do_remove_last = "Remove last value"
			arg1.empty = "BOOL: Is array empty?"
			arg1.find = "UINT: Index of value (if absent, 0)"
			arg1.first = object_vars.abbreviations[vtype] .. ": Get first value"
			arg1.get = object_vars.abbreviations[vtype] .. ": Get value at index"
			arg1.get_insert_pos = "UINT: Slot in which to place value"
			arg1.get_limit = object_vars.abbreviations[vtype] .. ": Pending value"
			arg1.get_pos = "UINT: Slot of value to get"
			arg1.get_remove_pos = "UINT: Slot of value to remove"
			arg1.get_value = object_vars.abbreviations[vtype] .. ": Value to add / compare"
			arg1.last = object_vars.abbreviations[vtype] .. ": Get last value"
			arg1.on_add = "On(add)"
			arg1.on_add_when_full = "On(tried adding when full)"
			arg1.on_bad_get_pos = "On(bad get position)"
			arg1.on_bad_insert_pos = "On(bad insert position)"
			arg1.on_bad_remove_pos = "On(bad remove position)"
			arg1.on_became_empty = "On(became empty)"
			arg1.on_became_full = "On(became full)"
			arg1.on_get_when_empty = "On(tried to get when empty)"
			arg1.on_not_found = "On(not found)"
			arg1.on_remove = "On(remove)"
			arg1.on_remove_when_empty = "On(tried removing when empty)"

		-- Get Tag --
		elseif what == "get_tag" then
			return vtype .. "_array"

		-- New Tag --
		elseif what == "new_tag" then
			return "extend", Events, Actions, object_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties), InProperties

		-- Prep Value Link --
		elseif what == "prep_link:value" then
			return LinkArray

		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			local has_value = arg1.links:HasLinks(arg3, "get_value")

			if not has_value then
				for _, what in args.Args("do_add", "do_insert", "contains", "find") do
					if arg1.links:HasLinks(arg3, what) --[[ TODO?: or (what == "do_insert" and arg2.method ~= "append")]] then
						arg1[#arg1 + 1] = "`" .. arg1.links:GetTag(arg3) .. "` has no `get_value` link for `" .. what .. "`"
					end
				end
			end

			for _, aname, pname in args.ArgsByN(2, "get", "get_pos", "do_insert", "get_insert_pos", "do_remove", "get_remove_pos") do
				if arg1.links:HasLinks(arg3, aname) and not arg1.links:HasLinks(arg3, pname) then
					arg1[#arg1 + 1] = "`" .. arg1.links:GetTag(arg3) .. "` has no `" .. pname .. "` link for `" .. aname .. "`"
				end
			end
		end
	end

	local function NewArray (info, params)
		local is_stale = object_vars.MakeStaleSessionPredicate(info.persist_across_reset)
		local op, limit, tolerance, arr = Ops[info.method], info.limit, info.tolerance
		local get_limit, get_value, get_pos, get_insert_pos, get_remove_pos

		local function array (what, arg)
			if is_stale() then
				arr = nil

				if get_limit then
					limit = nil
				end
			end

			if what then
				arr = arr or {}

				if what == "get" then
					local value = op(arr, "get", arg)

					if value ~= nil then
						return value
					else
						Events.on_bad_get_pos(array)

						return def
					end
				elseif what == "array" then
					return arr, op, has_tolerance and Approx or Equal, tolerance
				elseif what == "value" then -- does double duty in bind and later calls
					get_value = get_value or arg

					return get_value()
				elseif what == "limit" then -- ditto
					if not limit then -- absence implies get_limit is available
						get_limit = get_limit or arg
						limit = min(get_limit(), MaxLimit)
					end

					return limit
				elseif what == "insert_pos" then -- ditto
					get_insert_pos = get_insert_pos or arg

					return get_insert_pos()
				elseif what == "remove_pos" then -- ditto
					get_remove_pos = get_remove_pos or arg

					return get_remove_pos
				elseif what == "pos" then
					get_pos = arg
				end
			else
				return array("get", get_pos()) -- verified to exist
			end
		end

		local pubsub = params.pubsub

		for _, name in args.Args("insert_pos", "limit", "pos", "remove_pos", "value") do 
			bind.Subscribe(pubsub, info["get_" .. name], array, name)
		end

		for k, event in pairs(Events) do
			event.Subscribe(array, info[k], pubsub)
		end

		for k in adaptive.IterSet(info.actions) do
			bind.Publish(pubsub, Actions[k](array), info.uid, k)
		end

		object_vars.PublishProperties(pubsub, info.props, OutProperties, info.uid, array)

		return array
	end

	return { make = NewArray, editor = EditorEvent, value_type = vtype }
end

-- Export the module.
return M