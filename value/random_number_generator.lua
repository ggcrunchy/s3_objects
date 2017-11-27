--- Fetch a random number.

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
local mwc_rng = require("number_sequences.mwc_rng")
local state_vars = require("config.StateVariables")

--
--
--

local LinkSuper

local function LinkRNG (rng, other, sub, other_sub)
	if sub == "ibound1" or sub == "ibound2" or sub == "nbound1" or sub == "nbound2" or sub == "seed1" or sub == "seed2" then
		bind.AddId(rng, sub, other.uid, other_sub)
	else
		LinkSuper(rng, other, sub, other_sub)
	end
end

local function IntBound ()
	return 1
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Enumerate Defaults --
	-- arg1: Defaults
	if what == "enum_defs" then
		arg1.persist_across_reset = false

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ value_name = "persist_across_reset", text = "Persist across reset?" }

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.ibound1 = "INT: Bound #1"
		arg1.ibound2 = "INT: Bound #2"
		arg1.nbound1 = "NUM: Bound #1"
		arg1.nbound2 = "NUM: Bound #2"
		arg1.seed1 = "INT: Custom seed #1"
		arg1.seed2 = "INT: Custom seed #2"

	-- Get Tag --
	elseif what == "get_tag" then
		return "rng"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", nil, {
			integer = { ibound1 = true, ibound2 = true, seed1 = true, seed2 = true },
			number = { nbound1 = true, nbound2 = true }
		}

	-- Prep Value Link --
	-- arg1: Parent handler
	elseif what == "prep_link:value" then
		LinkSuper = LinkSuper or arg1

		return LinkRNG

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		local has_ints = arg1.links:HasLinks(arg3, "ibound1") or arg1.links:HasLinks(arg3, "ibound2")

		if has_ints and (arg1.links:HasLinks(arg3, "nbound1") or arg1.links:HasLinks(arg3, "nbound2")) then
			arg1[#arg1 + 1] = "RNG `" .. arg2.name .. "` links to both integer and number bounds"
		end
	end
end

return function(info)
	if info == "editor_event" then
		return EditorEvent
	elseif info == "value_type" then
		return "number"
	else
		local rng, session_id

		if info.ibound1 or info.ibound2 then
			--
		else
			--
		end

		if info.persist_across_reset then
			--
		else
			--
		end

		return function()
			return -- TODO
		end
	end
end