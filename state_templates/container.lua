--- Common logic used to add values to, and remove them from, a container.

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
local next = next
local pairs = pairs

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("corona_utils.bind")
local ring_buffer = require("tektite_core.array.ring_buffer")
local state_vars = require("config.StateVariables")
local table_funcs = require("tektite_core.table.funcs")

-- Exports --
local M = {}

--
--
--

local Events = {}

for _, name in ipairs{
	"on_add", "on_remove", "on_became_empty", "on_became_full", "on_add_when_full", "on_remove_when_empty", "on_get_when_empty"
} do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local Actions = {
	-- Add --
	do_add = function(container)
		return function()
			return container("add")
		end
	end,

	-- Remove --
	do_remove = function(container)
		return function()
			return container("remove")
		end
	end
}

local function Peek (container) -- stitched into proper type on startup
	return function()
		return container("peek")
	end
end

local OutPropertiesBase = {
	boolean = {
		-- Empty --
		empty = function(container)
			return function()
				return container("count") == 0
			end
		end
	}, uint = {
		-- Count --
		count = function(container)
			return function()
				return container("count")
			end
		end
	}
}

local Singletons = table_funcs.Weak("k")

local ADT = {
	queue = function(list, what, arg)
		if what == "peek" then
			return list[list.tail or 1]
		elseif what == "add" then
			list.head, list.tail = ring_buffer.Push(list, arg, list.head, list.tail, list.limit)
		elseif what == "remove" then
			arg, list.head, list.tail = ring_buffer.Pop(list, list.head, list.tail, list.limit) -- arg = junk
		end
	end,

	singleton = function(key, what, arg)
		if what == "peek" then
			return Singletons[key]
		elseif what == "add" then
			Singletons[key] = arg
		elseif what == "remove" then
			Singletons[key] = nil
		end
	end,

	stack = function(list, what, arg)
		if what == "peek" then
			return list[#list]
		elseif what == "add" then
			list[#list + 1] = arg
		elseif what == "remove" then
			list[#list] = nil
		end
	end
}

local function Add (adt, container, t, n, limit, value)
	if n == limit then
		Events.on_add_when_full(container)
	else
		n = n + 1

		adt(t, "add", value())

		Events.on_add(container)

		if n == limit then
			Events.on_became_full(container)
		end
	end

	return n
end

local function Remove (adt, container, t, n)
	if n > 0 then
		n = n - 1

		adt(t, "remove")

		Events.on_remove(container)

		if n == 0 then
			Events.on_became_empty(container)
		end
	else
		Events.on_remove_when_empty(container)
	end

	return n
end

--- DOCME
function M.Make (vtype, def)
	local InProperties, OutProperties = { [vtype] = "value" }, table_funcs.Copy(OutPropertiesBase)
	local vout = OutProperties[vtype]

	vout = vout and table_funcs.Copy(vout) or {}
	OutProperties[vtype], vout.peek = vout, Peek

	local function LinkContainer (container, other, csub, other_sub)
		local helper = bind.PrepLink(container, other, csub, other_sub)

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
			if arg2.kind == "singleton" then
				arg3.limit, arg3.get_limit = nil
			end

			arg3.persist_across_reset = arg2.persist_across_reset or nil

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.kind = "queue"
			arg1.limit = 10
			arg1.persist_across_reset = false
	
		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddString{ text = "Kind of container:", is_static = true }
			arg1:AddListbox{ value_name = "kind", "queue", "stack", "singleton" }
			-- limit spinner?

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "ADD", font = "bold", color = "unary_action" }, "value", "do_add",
				{ text = "ACTIONS", font = "bold", color = "actions" }, "do_remove",
				{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get", "peek", "count", "empty",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "before", "on_add", "on_remove", "on_became_empty", "on_became_full", "on_add_when_full", "on_remove_when_empty", "on_get_when_empty"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.count = "UINT: # of values in container"
			arg1.do_add = "Add it"
			arg1.do_remove = "Remove pending value"
			arg1.empty = "BOOL: Is container empty?"
			arg1.get = state_vars.abbreviations[vtype] .. ": Get pending value, removing it"
			arg1.on_add = "On(add)"
			arg1.on_add_when_full = "On(tried adding when full)"
			arg1.on_became_empty = "On(became empty)"
			arg1.on_became_full = "On(became full)"
			arg1.on_get_when_empty = "On(tried to get when empty)"
			arg1.on_remove = "On(remove)"
			arg1.on_remove_when_empty = "On(tried removing when empty)"
			arg1.peek = state_vars.abbreviations[vtype] .. ": Pending value"
			arg1.value = state_vars.abbreviations[vtype] .. ": Value to add"

		-- Get Tag --
		elseif what == "get_tag" then
			return vtype .. "_container"

		-- New Tag --
		elseif what == "new_tag" then
			return "extend", Events, Actions, state_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties), InProperties

		-- Prep Value Link --
		elseif what == "prep_link:value" then
			return LinkContainer

		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Representative object
		elseif what == "verify" then
			if not arg1.links:HasLinks(arg3, "value") then
				arg1[#arg1 + 1] = "Containers require `value` link"
			end
		end
	end

	return function(info, wlist)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return vtype
		else
			local kind, is_stale = info.kind, state_vars.MakeStaleSessionPredicate(info.persist_across_reset)
			local adt, limit, n, t, value = ADT[kind], info.limit, 0

			local function container (comp)
				if is_stale() then
					t, Singletons[container] = nil -- use container as key in weak table
				end

				if t == nil then
					if kind == "queue" then
						t = { limit = limit }
					elseif kind ~= "singleton" then
						t = {}
					else
						t = container -- see note in is_stale() block
					end
				end

				local remove

				if comp and comp ~= "remove" then
					if value then
						if comp == "count" then
							return n
						elseif comp == "add" then
							n = Add(adt, container, t, n, limit, value) -- fall through to result below
						end
					else
						value = comp
					end
				else
					remove = true -- "get" or comp == "remove"
				end

				local result

				if n > 0 then
					result = adt(t, "peek")
				else
					result = def

					Events.on_get_when_empty(container)
				end

				if remove then
					n = Remove(adt, container, t, n)
				end

				return result
			end

			bind.Subscribe(wlist, info.get_value, container)

			for k, event in pairs(Events) do
				event.Subscribe(container, info[k], wlist)
			end

			for k in adaptive.IterSet(info.actions) do
				bind.Publish(wlist, Actions[k](container), info.uid, k)
			end

			state_vars.PublishProperties(info.props, OutProperties, info.uid, container)

			return container
		end
	end
end

-- Export the module.
return M