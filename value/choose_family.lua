--- Supply one of the available families.

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
local object_vars = require("config.ObjectVariables")

--
--
--

local FamilyFuncs = {}

for _, name in ipairs(object_vars.families) do
	FamilyFuncs[name] = function()
		return name
	end
end

local function EditorEvent (what, arg1)
	-- Enumerate Defaults --
	-- arg1: Defaults
	if what == "enum_defs" then
		arg1.family = object_vars.families[#object_vars.families]
		
	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddFamilyList{ value_name = "family" }

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get = { friendly_name = "FAM: Choice", is_source = true }

	-- Get Tag --
	elseif what == "get_tag" then
		return "choose_family"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", "no_before"
	end
end

return function(info)
	if info == "editor_event" then
		return EditorEvent
	elseif info == "value_type" then
		return "family"
	else
		return FamilyFuncs[info.family]
	end
end