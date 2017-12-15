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
local pairs = pairs

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("tektite_core.bind")
local state_vars = require("config.StateVariables")

-- Exports --
local M = {}

--
--
--

-- stack, queue, ring buffer, singleton (add merely a replace, either empty or full)
-- actions: add; remove
-- out props: "get" = peek; extract, i.e. peek + remove; count; empty
-- misc: max count / hard max, persist across reset

local Events = {}

for _, name in ipairs{
	"on_add", "on_remove", "on_became_empty", "on_became_full", "on_add_when_full", "on_remove_when_empty", "on_get_when_empty"
} do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local Actions = {
	-- Add --
	do_add = function(container)
		return function(what)
			if what == "fire" then
				container("add")
			elseif what == "is_done" then
				return true
			end
		end
	end,

	-- Remove --
	do_remove = function(container)
		return function(what)
			if what == "fire" then
				container("remove")
			elseif what == "is_done" then
				return true
			end
		end
	end
}

local function Peek (container) -- stitched into proper type on startup
	return function()
		return container("peek")
	end
end

local OutProperties = {
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

local LinkSuper

--- DOCME
function M.Make (vtype, def)
	local InProperties = { [vtype] = "value" }

	local function LinkContainer (container, other, csub, other_sub, links)
		local helper = bind.PrepLink(container, other, csub, other_sub)

		helper("try_events", Events)
		helper("try_actions", Actions)
		helper("try_in_properties", InProperties)
		helper("try_out_properties", OutProperties)

		if not helper("commit") then
			LinkSuper(container, other, csub, other_sub, links)
		end
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

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.kind = "queue"
			arg1.limit = 10
	
		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:AddString{ text = "Kind of container:", is_static = true }
			arg1:AddListbox{ value_name = "kind", "queue", "stack", "ring", "singleton" }
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
			OutProperties[vtype] = OutProperties[vtype] or {}
			OutProperties[vtype].peek = Peek

			return "extend", Events, Actions, state_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties), InProperties

		-- Prep Value Link --
		-- arg1: Parent handler
		elseif what == "prep_link:value" then
			LinkSuper = LinkSuper or arg1

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
			local kind, n, container = info.kind, 0

			if kind == "queue" then
				--
			elseif kind == "ring" then
				--
			elseif kind == "singleton" then
				--
			elseif kind == "stack" then
				--
			end

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