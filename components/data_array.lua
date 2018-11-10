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
function EventBlock:AddToList (item, func, arg1, arg2)
	local list = self.m_list or { top = 0 }

	list.top = AuxAddToList(list, list.top, item, func, arg1, arg2)

	self.m_list, self.m_new = list
end

-- --
local Dynamic

--- Adds an item to the block's list.
-- @param item Item to add.
-- @callable func Commands to use on _item_, according to the type of event block.
-- @treturn function X
function EventBlock:AddToList_Dynamic (item, func, arg1, arg2)
	local list = self.m_dynamic_list or {}

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

	self.m_dynamic_list, list[dfunc] = list, true

	return dfunc
end









--- Getters.
-- @treturn boolean List has items?
function EventBlock:HasItems ()
	return self.m_list ~= nil
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
		block.m_list, list.n = list, n
	end

	return list
end

--- Performs some operation on each item in the list.
-- @callable visit Visitor function, called as `visit(item, func, arg1, arg2)`, with inputs
-- as assigned by @{EventBlock:AddToList}.
-- @treturn iterator Supplies tile index, item, commands function, argument #1, argument #2.
function EventBlock:IterList (visit)
	local list, dlist = self.m_list, self.m_dynamic_list

	if dlist then
		list = AddDynamicItems(self, dlist, list)
	elseif list then
		list.n = list.top
	end

	return AuxIterList, list, -3
end