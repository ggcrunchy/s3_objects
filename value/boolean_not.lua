--- Get the not'd result of a boolean.

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

--
--
--

local function LinkOriginal (getter, other, sub, other_sub)
	if sub == "original" then
		bind.AddId(getter, "original", other.uid, other_sub)
	end
end

local function EditorEvent (what, arg1)
	-- Get Link Info --
	-- arg1: Info to populate
	if what == "get_link_info" then
		arg1.get = { friendly_name = "BOOL: get result", is_source = true }
		arg1.original = "BOOL: original value"

	-- Get Tag --
	elseif what == "get_tag" then
		return "bnot" -- TODO: derives from value?

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", nil, nil, { boolean = "get" }, { boolean = "original" }

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkOriginal

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Key
	elseif what == "verify" then
		-- arg1.links:HasLinks(arg2[arg3], "original")?
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	elseif info == "value_type" then
		return "boolean"
	else
		local original

		local function getter (from)
			if original then
				return not original()
			else
				original = from
			end
		end

		bind.Subscribe(wlist, info.original, getter) -- TODO: verify original exists, to make bind work

		return getter
	end
end