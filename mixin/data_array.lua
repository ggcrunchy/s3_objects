--- Mixin that confers some array storage on its owner.

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
local unpack = unpack

-- Modules --
local args = require("iterator_ops.args")
local collect = require("tektite_core.array.collect")
local component = require("tektite_core.component")

-- Unique member keys --
local _dynamic_list = {}
local _item_size = {}
local _list = {}

--
--
--

local DataArrayMixin = {}

local Adders = {
	function(list, top, arg)
		list[top + 1] = arg or false

		return top + 1
	end,

	function(list, top, arg1, arg2)
		list[top + 1], list[top + 2] = arg1 or false, arg2 or false

		return top + 2
	end,

	function(list, top, arg1, arg2, arg3)
		list[top + 1], list[top + 2], list[top + 3] = arg1 or false, arg2 or false, arg3 or false

		return top + 3
	end,

	function(list, top, arg1, arg2, arg3, arg4)
		list[top + 1], list[top + 2], list[top + 3], list[top + 4] = arg1 or false, arg2 or false, arg3 or false, arg4 or false

		return top + 4
	end
}

local function DefAdder (list, top, ...)
	local did, size = 0, list.size

	for i, arg in args.Args(...) do
		if i <= size then
			list[top + i], did = arg or false, i
		end
	end

	for i = did + 1, size do
		list[top + i] = false
	end

	return top + size
end

local function GetList (da, list)
	return list or { size = da:DataArray_GetItemSize(), top = 0 }
end

--- Adds an item to the array.
-- @param ...
function DataArrayMixin:DataArray_AddToList (...)
	local list = GetList(self, self[_list])
	local adder = Adders[list.size] or DefAdder

	list.top = adder(list, list.top, ...)
-- TODO: must handle dynamic entries, e.g. by append and swap
	self[_list] = list
end

local DynamicLists = {}

local AssignmentNonce = DynamicLists -- use arbitrary internal object as nonce

local DynamicFactories = {
	function(dset, list, arg)
		local function dfunc (what, a, b)
			if rawequal(what, AssignmentNonce) then
				arg = a
			else
				assert(list[dfunc], "Invalid dynamic function")

				if what == "get" then
					return arg
				elseif what == "update_arg" then -- a: input, b: index
					if not b or b == 1 then
						arg = a
					end
				elseif what == "remove" then
					dset[#dset + 1], list[dfunc], arg = dfunc
				end
			end
		end

		return dfunc
	end,

	function(dset, list, arg1, arg2)
		local function dfunc (what, a, b)
			if rawequal(what, AssignmentNonce) then
				arg1, arg2 = a, b
			else
				assert(list[dfunc], "Invalid dynamic function")

				if what == "get" then
					return arg1, arg2
				elseif what == "update_arg" then -- a: input, b: index
					if not b or b == 1 then
						arg1 = a
					elseif b == 2 then
						arg2 = a
					end
				elseif what == "remove" then
					dset[#dset + 1], list[dfunc], arg1, arg2 = dfunc
				end
			end
		end

		return dfunc
	end,

	function(dset, list, arg1, arg2, arg3)
		local function dfunc (what, a, b, c)
			if rawequal(what, AssignmentNonce) then
				arg1, arg2, arg3 = a, b, c
			else
				assert(list[dfunc], "Invalid dynamic function")

				if what == "get" then
					return arg1, arg2, arg3
				elseif what == "update_arg" then -- a: input, b: index
					if not b or b == 1 then
						arg1 = a
					elseif b == 2 then
						arg2 = a
					elseif b == 3 then
						arg3 = a
					end
				elseif what == "remove" then
					dset[#dset + 1], list[dfunc], arg1, arg2, arg3 = dfunc
				end
			end
		end

		return dfunc
	end,

	function(dset, list, arg1, arg2, arg3, arg4)
		local function dfunc (what, a, b, c, d)
			if rawequal(what, AssignmentNonce) then
				arg1, arg2, arg3, arg4 = a, b, c, d
			else
				assert(list[dfunc], "Invalid dynamic function")

				if what == "get" then
					return arg1, arg2, arg3, arg4
				elseif what == "update_arg" then -- a: input, b: index
					if not b or b == 1 then
						arg1 = a
					elseif b == 2 then
						arg2 = a
					elseif b == 3 then
						arg3 = a
					elseif b == 4 then
						arg4 = a
					end
				elseif what == "remove" then
					dset[#dset + 1], list[dfunc], arg1, arg2, arg3, arg4 = dfunc
				end
			end
		end

		return dfunc
	end
}

local function CollectAndTrim (cur, list, ...)
	local n = collect.CollectArgsInto(cur, ...)

	for i = n, list.size + 1, -1 do
		cur[i] = nil -- trim if too long
	end

	return n
end

local function DefDynamicFactory (dset, list, ...)
	local cur = {}

	CollectAndTrim(cur, list, ...)

	local function dfunc (what, a, b, ...)
		if rawequal(what, AssignmentNonce) then
			local n = CollectAndTrim(cur, list, a, b, ...)

			for i = n + 1, list.size do
				cur[i] = nil -- if too short, remove any lingering trailing entries
			end
		else
			assert(list[dfunc], "Invalid dynamic function")

			if what == "get" then
				return unpack(cur, 1, list.size)
			elseif what == "update_arg" then -- a: input, b: index
				b = b or 1

				if b <= list.size then
					cur[b] = a
				end
			elseif what == "remove" then
				for i = 1, list.size do
					cur[i] = nil
				end

				dset[#dset + 1], list[dfunc] = dfunc
			end
		end
	end

	return dfunc
end

--- Adds an item to the array.
-- @param ...
-- @treturn function X
function DataArrayMixin:DataArray_AddToList_Dynamic (...)
	local list, size = self[_dynamic_list] or {}, self:DataArray_GetItemSize()
	local dset = DynamicLists[size] or {}
	local dfunc = remove(dset)

	if dfunc then
		dfunc(AssignmentNonce, ...)
	else
		local factory = DynamicFactories[size] or DefDynamicFactory

		dfunc = factory(dset, list, ...)
	end

	self[_dynamic_list], list[dfunc], DynamicLists[size] = list, true, dset

	return dfunc
end




--- DOCME
function DataArrayMixin:DataArray_GetItemSize ()
	return self[_item_size] or 1
end

--- Getters.
-- @treturn boolean List has items?
function DataArrayMixin:DataArray_HasItems ()
	return self[_list] ~= nil
end











local function AuxIterList (list, index)
	local size = list.size

	index = index + size

	local item = list[index]

	if item and index <= list.n then
		return index, item, unpack(list, index + 1, index + size - 1)
	end
end

local function DefIter () end

local function AddDynamicItems (da, dlist, list)
	local n = list and list.top or 0 -- N.B. dynamic items added after top

	for dfunc in pairs(dlist) do
		list = GetList(da, list)
		n = Adders[list.size or DefAdder](list, n, dfunc("get"))
	end

	if list then
		da[_list], list.n = list, n
	end

	return list
end

--- Iterate over each item in the array.
-- @treturn iterator Supplies the _n_ parts of each item, cf. @{DataArrayMixin:DataArray_SetItemSize}.
function DataArrayMixin:DataArray_IterList ()
	local list, dlist = self[_list], self[_dynamic_list]

	if dlist then
		list = AddDynamicItems(self, dlist, list)
	elseif list then
		list.n = list.top
	end

	if list then
		return AuxIterList, list, 1 - list.size
	else
		return DefIter
	end
end

--- DOCME
function DataArrayMixin:DataArray_RemoveList (dlist_too)
	local list = self[_list]

	self[_list] = nil

	if dlist_too then
		self[_dynamic_list] = nil
	end

	return list
end

--- DOCME
function DataArrayMixin:DataArray_SetItemSize (size)
	assert(size > 0, "Non-positive size")
	assert(not (self[_dynamic_list] or self[_list]), "Cannot set size while list has items")

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
	for k, v in pairs(DataArrayMixin) do
		self[k] = v
	end
end

function Actions:remove ()
	self[_dynamic_list], self[_list], self[_item_size] = nil

	for k, v in pairs(DataArrayMixin) do
		self[k] = v
	end
end

return component.RegisterType{ name = "data_array", actions = Actions }