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
local state_vars = require("config.StateVariables")

--
--
--

local FamilyFuncs = {}

for _, name in ipairs(state_vars.families) do
	FamilyFuncs[name] = function()
		return name
	end
end

local function EditorEvent (what, arg1)
	-- Enumerate Properties --
	-- arg1: Dialog
	if what == "enum_props" then
		arg1:AddFamilyList{ value_name = "family", default = state_vars.families[#state_vars.families] }
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