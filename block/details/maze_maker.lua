--- TODO

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
local ipairs = ipairs
local next = next
local random = math.random
local remove = table.remove

-- Modules --
local tile_flags = require("s3_utils.tile_flags")
local tile_maps = require("s3_utils.tile_maps")

-- Exports --
local M = {}

--
--
--

-- Tile deltas (indices into Deltas) available on current iteration, during maze building --
local Choices = {}

-- Tile deltas in each cardinal direction --
local Deltas = { false, -1, false, 1 }

local function GetChoices (index, occupancy, open)
	local oi, n = (index - 1) * 4, 0

	for i, delta in ipairs(Deltas) do
		if not (open[oi + i] or occupancy("check", index + delta)) then
			n = n + 1

			Choices[n] = i
		end
	end

	return n, oi
end

local Work = {}

--- DOCME
function M.Build (open, occupancy)
	occupancy("begin_generation")

	-- Choose a random maze tile and do a random flood-fill of the block.
	Work[#Work + 1] = random(#open / 4)

	repeat
		local index = Work[#Work]

		-- Mark this tile slot as explored.
		occupancy("mark", index)

		-- Examine each direction out of the tile. If the direction was already marked
		-- (borders are pre-marked in the relevant direction), or the relevant neighbor
		-- has already been explored, ignore it. Otherwise, add it to the choices.
		local n, oi = GetChoices(index, occupancy, open)

		-- Remove the tile from the list if no choices remain. Otherwise, choose and mark
		-- one of the available directions, plus the reverse direction for the relevant
		-- neighbor, and try to resume the flood-fill from that neighbor.
		if n > 0 then
			local i = Choices[random(n)]
			local delta = Deltas[i]

			open[oi + i] = true

			oi = oi + delta * 4
			i = (i + 1) % 4 + 1 -- n.b. follows the order used by Deltas and open

			open[oi + i] = true

			Work[#Work + 1] = index + delta
		else
			remove(Work)
		end
	until #Work == 0
end

local IndexToDir = { "up", "left", "down", "right" }

local Dirs = {}

local function AuxIterChoice (_, k)
	k = next(Dirs, k)

	if k then
		Dirs[k] = nil
	end

	return k
end

--- DOCME
function M.IterChoices (index, open, occupancy)
	for i = 1, GetChoices(index, occupancy, open) do
		local name = IndexToDir[Choices[i]]

		Dirs[name] = true
	end

	return AuxIterChoice, nil, nil
end

--- Convert maze state into flags.
--
-- Border flags are left in place, allowing the maze to coalesce with the rest of the level.
function M.SetFlags (block, open)
	local i, ncols, nrows = 0, tile_maps.GetCounts()

	for index, col, row in block:IterSelf() do
		local flags = 0

		-- Is this cell open, going up? On the interior, just accept it; along the
		-- fringe of the level, reject it. Otherwise, when on the fringe of the maze
		-- alone, accept it if the next cell up has a "down" flag.
		local uedge = open[i + 1]

		if uedge and row > 1 and (uedge ~= "edge" or tile_flags.IsFlagSet_Working(index - ncols, "down")) then
			flags = flags + tile_flags.GetFlagsByName("up")
		end

		-- Likewise, going left...
		local ledge = open[i + 2]

		if ledge and col > 1 and (ledge ~= "edge" or tile_flags.IsFlagSet_Working(index - 1, "right")) then
			flags = flags + tile_flags.GetFlagsByName("left")
		end

		-- ...going down...
		local dedge = open[i + 3]

		if dedge and row < nrows and (dedge ~= "edge" or tile_flags.IsFlagSet_Working(index + ncols, "up")) then
			flags = flags + tile_flags.GetFlagsByName("down")
		end

		-- ...and going right.
		local redge = open[i + 4]

		if redge and col < ncols and (redge ~= "edge" or tile_flags.IsFlagSet_Working(index + 1, "left")) then
			flags = flags + tile_flags.GetFlagsByName("right")
		end

		-- Register the final flags.
		tile_flags.SetFlags(index, flags)

		i = i + 4
	end
end

--- DOCME
function M.SetupFromBlock (block)
	local col1, col2 = block:GetColumns()
	local delta = col1 - col2 - 1

	Deltas[1], Deltas[3] = delta, -delta
end

local function ArgId (arg) return arg end

local List1, List2 = {}, {}

--- DOCME
function M.Visit (block, occupancy, func, dirs, arg, xform)
	occupancy("begin_generation")

	local col1, row1, col2, row2 = block:GetInitialRect()
	local from, to, count = List1, List2, 2

	from[1], from[2], xform = random(col1, col2), random(row1, row2), xform or ArgId

	func(from[1], from[2], occupancy, "start")

	repeat
		local nadded = 0

		for i = 1, count, 2 do
			local x, y = from[i], from[i + 1]

			for dir in dirs(x, y, arg) do
				local tx, ty, bounded = x, y, true

				if dir == "left" or dir == "right" then
					tx = tx + (dir == "left" and -1 or 1)
					bounded = tx >= col1 and tx <= col2
				else
					ty = ty + (dir == "up" and -1 or 1)
					bounded = ty >= row1 and ty <= row2
				end

				if bounded and func(tx, ty, occupancy, dir, arg) then
					to[nadded + 1], to[nadded + 2], nadded = tx, ty, nadded + 2
				end
			end
		end

		from, to, count, arg = to, from, nadded, xform(arg)
	until count == 0
end

--- Wipes the maze state (and optionally its flags), marking borders.
function M.Wipe (block, open, wipe_flags)
	local i, col1, row1, col2, row2 = 0, block:GetInitialRect()

	for _, col, row in block:IterSelf() do
		open[i + 1] = row == row1 and "edge"
		open[i + 2] = col == col1 and "edge"
		open[i + 3] = row == row2 and "edge"
		open[i + 4] = col == col2 and "edge"

		i = i + 4
	end

	if wipe_flags then
		tile_flags.WipeFlags(col1, row1, col2, row2)
	end
end

return M