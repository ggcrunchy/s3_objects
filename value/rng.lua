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
local mwc_rng = require("number_sequence.mwc_rng")
local state_vars = require("config.StateVariables")

--
--
--

local function LinkRNG (rng, other, sub, other_sub)
	if sub == "int_bound1" or "int_bound2" then
		rng.is_integer = true
	end

	bind.AddId(rng, sub, other.uid, other_sub)
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Enumerate Properties --
	-- arg1: Dialog
	if what == "enum_props" then
		-- persist across reset?

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.int_bound1 = "Integer bound #1"
		arg1.int_bound2 = "Integer bound #2"
		arg1.num_bound1 = "Number bound #1"
		arg1.num_bound2 = "Number bound #2"
		arg1.seed1 = "Custom seed #1"
		arg1.seed2 = "Custom seed #2"

	-- Get Tag --
	elseif what == "get_tag" then
		return "rng"

	-- New Tag --
	elseif what == "new_tag" then
	--	return "sources_and_targets", nil, { seed1 = true, seed2 = true, num_bound1 = true, num_bound2 = true, int_bound1 = true, int_bound2 = true }

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkRNG

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		local has_ints = arg1.links:HasLinks(arg3, "int_bound1") or arg1.links:HasLinks(arg3, "int_bound2")

		if has_ints and (arg1.links:HasLinks(arg3, "num_bound1") or arg1.links:HasLinks(arg3, "num_bound2") then
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
		-- TODO

		return function()
			return -- TODO
		end
	end
end