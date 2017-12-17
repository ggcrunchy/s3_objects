--- Tether one event to a named source.

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
local require_ex = require("tektite_core.require_ex")
local actions = require_ex.Lazy("s3_utils.state.actions")
local bind = require("tektite_core.bind")

--
--
--

local InProperties = { string = "get_name" }

local function LinkTetherTo (tether, other, tsub, other_sub)
	local helper = bind.PrepLink(tether, other, tsub, other_sub)

	helper("try_in_properties", InProperties)

	return helper("commit")
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		if arg2.get_name then
			arg3.source_name = nil
		end

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.source_name = ""

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddString{ value_name = "source_name", before = "Name of source:" }

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_name",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "From"
		arg1.get_name = "STR: Name of source"

	-- Get Tag --
	elseif what == "get_tag" then
		return "tether_to_named_source"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", nil, InProperties

	-- Prep Action Link --
	elseif what == "prep_link:action" then
		return LinkTetherTo
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local name, get_name = info.source_name

		local function tether_to (comp)
			if comp then
				get_name = comp
			else
				if get_name then
					name = get_name()
				end

				return actions.CallNamedSource(name)
			end
		end

		bind.Subscribe(wlist, info.get_name, tether_to)

		return tether_to
	end
end