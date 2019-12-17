--- Mixin that confers some data storage on its owner.

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

-- Modules --
local component = require("tektite_core.component")
local embedded_free_list = require("tektite_core.array.embedded_free_list")

-- Unique member keys --
local _array = {}
local _dynamic = {}
local _free = {}

--
--
--

local DataStoreMixin = {}

--- Add an item to the array.
-- @param ...
function DataStoreMixin:DataStore_Append (v)
	if v ~= nil then
		local arr = self[_array] or {}

		self[_array], arr[#arr + 1] = arr, v
	end
end

local function AuxFind (dynamic, pred, v)
	for i = 1, #(dynamic or "") do
		if embedded_free_list.InUse(dynamic, i) and pred(dynamic[i], v) then
			return i
		end
	end
end

local function IsNaN (v)
	return v ~= v
end

--- DOCME
function DataStoreMixin:DataStore_Find (v)
	return (AuxFind(self[_dynamic], IsNaN(v) and IsNaN or rawequal, v))
end

--- DOCME
function DataStoreMixin:DataStore_FindAndRemove (v)
	local index = self:DataStore_Find(v)

	if index then
		self:DataStore_Remove(index)
	end
end

--- Add an item to the array.
-- @param ...
-- @treturn function X
function DataStoreMixin:DataStore_Insert (v)
	local index

	if v ~= nil then
		local dynamic = self[_dynamic] or {}

		index, self[_free] = embedded_free_list.GetInsertIndex(dynamic, self[_free])
		self[_dynamic], dynamic[index] = dynamic, v
	end

	return index
end

---
-- @treturn boolean List has items?
function DataStoreMixin:DataStore_IsEmpty ()
	local dynamic = self[_dynamic]

	for i = 1, #(dynamic or "") do
		if embedded_free_list.InUse(dynamic, i) then
			return false
		end
	end

	return not self[_array] -- array only exists after an append
end

local function AuxIterate (ds, index)
	index = index + 1

	local arr = ds[_array]
	local n = #(arr or "")

	if index <= n then
		return index, arr[index]
	else
		local dynamic, an = ds[_dynamic], n

		index, n = index - n, #(dynamic or "")

		while index <= n do
			if embedded_free_list.InUse(dynamic, index) then
				return index + an, dynamic[index]
			end

			index = index + 1
		end
	end
end

--- Iterate over each item in the array.
-- @treturn iterator Supplies the _n_ parts of each item, cf. @{DataArrayMixin:DataArray_SetItemSize}.
function DataStoreMixin:DataStore_Iterate ()
	return AuxIterate, self, 0
end

--- DOCME
function DataStoreMixin:DataStore_Remove (index)
	local dynamic = self[_dynamic]

	if dynamic and embedded_free_list.InUse(dynamic, index) then
		self[_free] = embedded_free_list.RemoveAt(dynamic, index, self[_free])
	end
end

local Remove = { array_only = true, both = true, dynamic_only = true, dynamic_only_raw = true, merge = true }

--- DOCME
function DataStoreMixin:DataStore_RemoveParts (how)
	assert(how == nil or Remove[how], "Invalid remove option")

	local arr, result = self[_array]

	self[_array] = nil

	local dynamic_only = how == "dynamic_only" or how == "dynamic_only_raw"

	if not dynamic_only then
		result = arr
	end

	if how ~= "array_only" then
		local dynamic = self[_dynamic]

		if how == "dynamic_only_raw" then
			result = dynamic
		elseif how == "dynamic_only" or how == "merge" then
			result = result or {} -- `result` always empty for dynamic_only

			for _, v in self:DataStore_Iterate() do -- array absent, so only iterates dynamic part
				result[#result + 1] = v
			end
		else -- both, in raw form
			self[_dynamic], self[_free] = nil

			return arr, dynamic
		end

		if dynamic_only then
			self[_array] = arr -- restore the array, now that iteration is over
		end

		self[_dynamic], self[_free] = nil
	end

	return result
end

local Actions = { allow_add = "is_table" }

function Actions:add ()
	for k, v in pairs(DataStoreMixin) do
		self[k] = v
	end
end

function Actions:remove ()
	self[_array], self[_dynamic], self[_free] = nil

	for k in pairs(DataStoreMixin) do
		self[k] = nil
	end
end

return component.RegisterType{ name = "data_store", actions = Actions }