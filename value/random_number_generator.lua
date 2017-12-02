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

-- Standard library imports --
local pairs = pairs

-- Modules --
local bind = require("tektite_core.bind")
local mwc_rng = require("number_sequences.mwc_rng")
local state_vars = require("config.StateVariables")

--
--
--

local InProperties = {
	integer = { get_ibound1 = "ibound1", get_ibound2 = "ibound2", get_seed1 = "seed1", get_seed2 = "seed2" },
	number = { get_nbound1 = "nbound1", get_nbound2 = "nbound2" }
}

local LinkSuper

local function LinkRNG (rng, other, sub, other_sub)
	local helper = bind.PrepLink(rng, other, sub, other_sub)

	helper("try_in_properties", InProperties)

	if not helper("commit") then
		LinkSuper(rng, other, sub, other_sub)
	end
end

local Seed1, Seed2

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		if arg2.use_integers then
			arg3.nbound1, arg3.nbound2 = nil
		else
			arg3.ibound1, arg3.ibound2 = nil
		end

		arg3.use_integers = nil

		for _, props in pairs(InProperties) do
			for gkey, key in pairs(props) do
				if arg2[gkey] then
					arg3[key] = nil
				end
			end
		end

		if arg2.seed1 == Seed1 then
			arg3.seed1 = nil
		end

		if arg2.seed2 == Seed2 then
			arg3.seed2 = nil
		end

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.persist_across_reset = false
		arg1.ibound1, arg1.ibound2 = 1, 1
		arg1.nbound1, arg1.nbound2 = 0, 1
		-- arg1.seed1, arg1.seed2 = Seed1, Seed2

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ value_name = "persist_across_reset", text = "Persist across reset?" }
		-- use integers
		-- various bounds...
		-- seeds

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get_ibound1 = "INT: Bound #1"
		arg1.get_ibound2 = "INT: Bound #2"
		arg1.get_nbound1 = "NUM: Bound #1"
		arg1.get_nbound2 = "NUM: Bound #2"
		arg1.get_seed1 = "INT: Custom seed #1"
		arg1.get_seed2 = "INT: Custom seed #2"

	-- Get Tag --
	elseif what == "get_tag" then
		return "rng"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", nil, InProperties

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
		local has_ints = arg1.links:HasLinks(arg3, "get_ibound1") or arg1.links:HasLinks(arg3, "get_ibound2")

		if has_ints and (arg1.links:HasLinks(arg3, "get_nbound1") or arg1.links:HasLinks(arg3, "get_nbound2")) then
			arg1[#arg1 + 1] = "RNG `" .. arg2.name .. "` links to both integer and number bounds getters"
		end
	end
end

local function AddGetter (list, what, getter)
	list = list or {}

	list[what] = getter

	return list
end

local function Update (is_stale, gen, getters, bound1, bound2, seed1, seed2)
	if is_stale() then
		gen = nil
	end

	if gen == nil then
		if getters then
			local get_seed1, get_seed2 = getters.get_seed1, getters.get_seed2

			seed1 = seed1 or (get_seed1 and get_seed1())
			seed2 = seed2 or (get_seed2 and get_seed2())
		end

		gen = mwc_rng.MakeGenerator_Lib(seed1, seed2)
	end

	return gen, bound1 or getters.get_bound1(), bound2 or getters.get_bound2()
end

return function(info, wlist)
	if not Seed1 then
		local _, get_zw = mwc_rng.MakeGenerator()

		Seed1, Seed2 = get_zw{ get_zw = true }
	end
	
	if info == "editor_event" then
		return EditorEvent
	elseif info == "value_type" then
		return "number"
	else
		local is_stale, gen, getters, rng = state_vars.MakeStaleSessionPredicate(info.persist_across_reset)
		local bound1, seed1 = info.ibound1 or info.nbound1, info.seed1
		local bound2, seed2 = info.ibound2 or info.nbound2, info.seed2

		if info.ibound1 or info.ibound2 or info.get_ibound1 or info.get_ibound2 then
			function rng (comp, arg)
				if comp then
					getters = AddGetter(getters, arg, comp)
				else
					local i1, i2

					gen, i1, i2 = Update(is_stale, gen, getters, bound1, bound2, seed1, seed2)

					if i2 <= i1 then
						if i1 == i2 then
							return i1
						end

						i1, i2 = i2, i1
					end

					return gen(i1, i2)
				end
			end
		else
			function rng (comp, arg)
				if is_stale() then
					gen = nil
				end

				if comp then
					getters = AddGetter(getters, arg, comp)
				else
					local n1, n2

					gen, n1, n2 = Update(is_stale, gen, getters, bound1, bound2, seed1, seed2)

					return n1 + gen() * (n2 - n1)
				end
			end
		end

		bind.Subscribe(wlist, info.get_ibound1 or info.get_nbound1, rng, "bound1")
		bind.Subscribe(wlist, info.get_ibound2 or info.get_nbound2, rng, "bound2")
		bind.Subscribe(wlist, info.get_seed1, rng, "seed1")
		bind.Subscribe(wlist, info.get_seed2, rng, "seed2")

		return rng
	end
end