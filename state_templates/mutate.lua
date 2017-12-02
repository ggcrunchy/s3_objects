--- Common logic used to mutate a variable in the store.

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
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

--
--
--

local LinkSuper

local function LinkValue (bvalue, other, sub)
	--
end

--- DOCME
function M.Make (vtype)

	local function EditorEvent (what, arg1, arg2, arg3)
		-- Enumerate Properties --
		-- arg1: Dialog
		if what == "enum_props" then
			--

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			--

		-- Get Tag --
		elseif what == "get_tag" then
			--

		-- New Tag --
		elseif what == "new_tag" then
			--

		-- Prep Value Link --
		-- arg1: Parent handler
		elseif what == "prep_link:value" then
			LinkSuper = LinkSuper or arg1

			return LinkValue
		
		-- Verify --
		-- arg1: Verify block
		-- arg2: Values
		-- arg3: Key
		elseif what == "verify" then
			-- 
		end
	end

	return function(info, wname)
		if info == "editor_event" then
			return EditorEvent
		elseif info == "value_type" then
			return vtype
		else
			--
		end
	end
end

-- Export the module.
return M