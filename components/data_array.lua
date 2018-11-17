--- Component that confers some array storage on its owner.

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
local assert = assert
local pairs = pairs
local rawequal = rawequal
local remove = table.remove

-- Modules --
local component = require("tektite_core.component")

-- Unique member keys --
local _dynamic_list = {}
local _item_size = {}
local _list = {}

--
--
--

local Component = {}

--
local function AuxAddToList (list, top, item, func, arg1, arg2)
	list[top + 1], list[top + 2], list[top + 3], list[top + 4] = item, func, arg1 or false, arg2 or false

	return top + 4
end

--- Adds an item to the block's list.
-- @param item Item to add.
-- @callable func Commands to use on _item_, according to the type of event block.
-- @param[opt] arg1 Argument #1 to _func_ (default **false**)...
-- @param[opt] arg2 ...and #2 (ditto).
function Component:DataArray_AddToList (item, func, arg1, arg2)
	local list = self[_list] or { top = 0 }

	list.top = AuxAddToList(list, list.top, item, func, arg1, arg2)

	self[_list] = list
end

-- --
local Dynamic

--- Adds an item to the block's list.
-- @param item Item to add.
-- @callable func Commands to use on _item_, according to the type of event block.
-- @treturn function X
function Component:DataArray_AddToList_Dynamic (item, func, arg1, arg2)
	local list = self[_dynamic_list] or {}

	Dynamic = Dynamic or {}

	local dfunc = remove(Dynamic)

	if dfunc then
		dfunc(Dynamic, item, func, arg1, arg2) -- arbitrary nonce
	else
		function dfunc (what, a, b, c, d)
			if rawequal(what, Dynamic) then -- see note above
				item, func, arg1, arg2 = a, b, c, d
			else
				assert(list[dfunc], "Invalid dynamic function")

				if what == "get" then
					return item, func, arg1, arg2
				elseif what == "update_args" then
					arg1, arg2 = a, b
				elseif what == "remove" then
					Dynamic[#Dynamic + 1], list[dfunc], item, func, arg1, arg2 = dfunc
				end
			end
		end
	end

	self[_dynamic_list], list[dfunc] = list, true

	return dfunc
end




--- DOCME
function Component:DataArray_GetItemSize ()
	return self[_item_size] or 1
end

--- Getters.
-- @treturn boolean List has items?
function Component:DataArray_HasItems ()
	return self[_list] ~= nil
end











-- Helper to iterate list
local function AuxIterList (list, index)
	index = index + 4

	local item = list and list[index]

	if item and index <= list.n then
		return index, item, list[index + 1], list[index + 2], list[index + 3]
	end
end

--
local function AddDynamicItems (block, dlist, list)
	local n = list and list.top or 0 -- N.B. dynamic items added after top

	for dfunc in pairs(dlist) do
		list = list or { top = 0 }
		n = AuxAddToList(list, n, dfunc("get"))
	end

	if list then
		block[_list], list.n = list, n
	end

	return list
end

--- Performs some operation on each item in the list.
-- @treturn iterator Supplies tile index, item, commands function, argument #1, argument #2.
function Component:DataArray_IterList ()
	local list, dlist = self[_list], self[_dynamic_list]

	if dlist then
		list = AddDynamicItems(self, dlist, list)
	elseif list then
		list.n = list.top
	end

	return AuxIterList, list, -3
end

--- DOCME
function Component:DataArray_RemoveList ()
	local list = self[_list]

	self[_list] = nil

	return list
end

--- DOCME
function Component:DataArray_SetItemSize (size)
	assert(size > 0, "Non-positive size")
	assert(not self[_item_size], "Already set")

	-- choose stuff...

	self[_item_size] = size
end


-- Sprint:
--[[
function Spring:Reset ()
	self.m_cargo = {}
	self.m_items = nil
end

--- Dot method: update spring state.
function Spring:Update ()
	local cargo = self.m_cargo

	for i = #cargo, 1, -1 do
		if cargo[i]() then
			array_funcs.Backfill(cargo, i)
		end
	end
end
]]


-- Warp:
--[[
		local items = warp.m_items

		if items then
			warp.m_items = nil
]]

-- AddItem: (spring, warp)
--[[
	local items = self.m_items or {}

	items[#items + 1] = item

	self.m_items = items
]]

-- Reset:
-- self.m_items = nil

-- TODO: various move_done_* etc. events

local Actions = { allow_add = "is_table" }

function Actions:add ()
	for k, v in pairs(Component) do
		self[k] = v
	end
end

function Actions:remove ()
	self[_dynamic_list], self[_list], self[_item_size] = nil

	for k, v in pairs(Component) do
		self[k] = v
	end
end

return component.RegisterType{ name = "data_array", actions = Actions }