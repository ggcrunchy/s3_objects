--- A condition that is either ready or somehow waiting.

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
local state_vars = require("config.StateVariables")

-- Corona globals --
local system = system

--
--
--

local LinkSuper

local function LinkReady (ready, other, sub, other_sub, links)
	if sub == "get_amount" or sub == "should_disable" or sub == "starts_ready" then
		bind.AddId(ready, sub, other.uid, other_sub)
	else
		LinkSuper(ready, other, sub, other_sub, links)
	end
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		--

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.amount = 500
		arg1.as_count = false
		arg1.persist_across_reset = false

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ value_name = "as_count", text = "Interpret amount as times fetched?" }
		arg1:AddCheckbox{ value_name = "persist_across_reset", text = "Persist across reset?" }

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get = { friendly_name = "BOOL: Is ready?", is_source = true }
		arg1.get_amount = "NUM: Count or delay until ready again"
		arg1.should_disable = "BOOL: Disable after reporting ready?"
		arg1.start_ready = "BOOL: Start in ready state?"

	-- Get Tag --
	elseif what == "get_tag" then
		return "ready"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", nil, { boolean = { should_disable = true, start_ready = true }, uint = "get_amount" }

	-- Prep Value Link --
	-- arg1: Parent handler
	elseif what == "prep_link:value" then
		LinkSuper = LinkSuper or arg1

		return LinkReady

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
	--[[
		if not arg1.links:HasLinks(arg3, "value") then
			arg1[#arg1 + 1] = "to_integer has no `value` link"
		end
		]]
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent

		-- delay or times to poll
		-- starts ready?
		-- stays ready?
		-- can be off?
		-- set state

		-- is session stale?
	elseif info == "value_type" then
		return "boolean"
	else
		local is_enabled, amount, get_amount, ready, threshold = true, info.amount

		if info.as_count then
			local pos

			function ready (comp)
				if comp then
					get_amount = comp
				elseif is_enabled then
					if pos ~= threshold then
						pos = pos + 1
					else
						-- if active, etc.
						threshold = amount or get_amount()
					end
				end
			end
		else
			threshold = -1

			function ready (comp)
				if comp then
					get_amount = comp
				elseif is_enabled then
					local now = system.getTimer()

					if now >= threshold then
						-- if active, etc.
						threshold = now + (amount or get_amount())
					end
				end
			end
		end

		if info.should_disable then
			--
		end

		if info.starts_ready then
			--
		end
		-- ^^^ Timing?

		bind.Subscribe(wlist, info.get_amount, ready)

		return ready
	end
end