--- Dispatch a custom runtime event.

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
local ipairs = ipairs
local pairs = pairs
local remove = table.remove
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("corona_utils.bind")

-- Corona globals --
local Runtime = Runtime

--
--
--

local InProperties = { boolean = "get_bools*", number = "get_nums*", string = "get_strs*" }

local function LinkDispatch (dispatch, other, dsub, other_sub)
	for k, v in pairs(InProperties) do
		local helper = bind.PrepLink(dispatch, other, dsub, other_sub)

		helper("try_in_instances", v, k)

		if helper("commit") then
			return true
		end
	end
end

local function CleanupDispatch (dispatch)
	for _, v in pairs(InProperties) do
		dispatch[v] = nil
	end
end

local function GetText (what)
	for k, v in pairs(InProperties) do
		if v == what then
			return k
		end
	end
end

local Choices = {}

for _, v in pairs(InProperties) do
	Choices[#Choices + 1] = GetText(v)
end

table.sort(Choices)

local function AddChoices (choice)
	for _, v in ipairs(Choices) do
		choice:Append(InProperties[v])
	end
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		arg3.name = arg2.name -- name stripped by default

	-- Build Instances --
	-- arg1: Built
	-- arg2: Info
	elseif what == "build_instances" then
		local tag_db = arg2.links:GetTagDatabase()

		for _, instance in ipairs(arg2.instances) do
			local template = tag_db:GetTemplate("dispatch_custom_event", instance)
			local into = arg1[template] or {}

			into[instance], arg1[template] = arg2.labels[instance], into
		end

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "unary_action" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "inputs",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Dispatch"
		arg1["get_bools*"] = { friendly_name = "BOOL:", group = "inputs" }
		arg1["get_nums*"] = { friendly_name = "NUM:", group = "inputs" }
		arg1["get_strs*"] = { friendly_name = "STR:", group = "inputs" }
		arg1.inputs = {	friendly_name = "Inputs", choice_text = "Type to add:", add_choices = AddChoices, get_text = GetText }

	-- Get Tag --
	elseif what == "get_tag" then
		return "dispatch_custom_event"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", nil, InProperties

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkDispatch, CleanupDispatch

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		local tag_db, instances, names = arg1.links:GetTagDatabase(), arg1.get_instances(arg3)
		local tag = arg1.links:GetTag(arg3)

		for i = 1, #(instances or "") do
			names = names or {}

			local template, label = tag_db:GetTemplate(tag, instances[i]), arg1.get_label(instances[i])

			if adaptive.InSet(names[template], label) then
				arg1[#arg1 + 1] = "Name `" .. label .. "`has shown up more than once for template `" .. template .. "`"
			else
				names[template] = adaptive.AddToSet(names[template], label)
			end
		end
	end
end

local Event, Stash = {}, {}

local function AddSubtable (key)
	local t = remove(Stash) or {}

	for k in pairs(t) do
		t[k] = nil
	end

	Event[key] = t

	return t
end

return function(info, params)
	if info == "editor_event" then
		return EditorEvent
	else
		local name, inputs = "custom:" .. info.name

		local function dispatch (comp, arg)
			if comp then
				local vtype, label = arg()

				inputs = inputs or {}
				inputs[vtype] = inputs[vtype] or {}
				inputs[vtype][label] = comp

			else
				Event.name = name -- sanity check, since event is user code

				if inputs then
					for vtype, funcs in pairs(inputs) do
						local t = AddSubtable(vtype)

						for label, func in pairs(funcs) do
							t[label] = func()
						end
					end
				end

				Runtime:dispatchEvent(Event)

				for k, t in pairs(Event) do
					if type(t) == "table" then -- another sanity check
						Stash[#Stash + 1] = t
					end

					Event[k] = nil
				end
			end
		end

		local pubsub = params.pubsub

		for itype in pairs(InProperties) do
			local inputs = info[itype]

			if inputs then
				for label, id in pairs(inputs) do
					bind.Subscribe(pubsub, id, dispatch, function()
						return itype, label
					end)
				end
			end
		end

		return dispatch
	end
end