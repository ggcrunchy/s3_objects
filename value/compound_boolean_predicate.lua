--- Given multiple booleans, reduce them to one.

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

return function(info)
	if info == "editor_event" then
		-- TODO!
	elseif info == "value_type" then
		return "boolean"
	else
		-- TODO: generic link
		-- any, all, none

		return function()
			return -- TODO!
		end
	end
end

--[=[
	Binary

-- Modules --
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

--- DOCME
function M.MakeAdder (combiners, ckey)
	return function(info, wname)
		local wlist, getter = wname or "loading_level"
		local combine, value1, value2 = combiners[info[ckey]]

		function getter (comp)
			if value2 then
				return combine(value1(), value2())
			elseif value1 then -- TODO: check order guarantees
				value2 = comp
			else
				value1 = comp
			end
		end

		--
		bind.Subscribe(wlist, info.value1, getter)
		bind.Subscribe(wlist, info.value2, getter)

		--
		bind.Publish(wlist, getter, info.uid, "get")

		return getter
	end
end

--- DOCME
function M.MakeEditorEvent (type, event, tag)
	return function(what, arg1, arg2, arg3)
		-- Enumerate Properties --
		-- arg1: Dialog
		if what == "enum_props" then
			arg1:StockElements()
			arg1:AddSeparator()
			-- TODO: some way to look up connective (radio? picker wheel?)

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.get = "Query final value"
			arg1.value1 = "First source value"
			arg1.value2 = "Second source value"

		-- Get Tag --
		elseif what == "get_tag" then
			return tag

		-- New Tag --
		elseif what == "new_tag" then
			return "properties", {
				[type] = "get"
			}, {
				[type] = { value1 = true, value2 = true }
			}

		-- Prep Link --
		elseif what == "prep_link" then
			return function(bvalue, other, sub)
				if sub == "value1" or sub == "value2" then
					bvalue[sub] = other.uid
				end
			end
		
		-- Verify --
		elseif what == "verify" then
			-- Has both set?
		end

		event(what, arg1, arg2, arg3)
	end
end
]=]

--[=[
	Compound

-- Modules --
local compound = require("s3_utils.state.compound")

-- Exports --
local M = {}

-- --
local Grammar -- TODO! (stuff in expression.lua)

--- DOCME
M.AddValue = compound.MakeAdder("bools", Grammar)

--- DOCME
M.EditorEvent = compound.MakeEditorEvent("boolean", "bools", function(what, arg1, arg2, arg3)
	if what == "enum_defs" then
		--
	end
end, Grammar, "compound_boolean")
]=]