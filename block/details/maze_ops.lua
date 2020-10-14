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
local random = math.random
local remove = table.remove

-- Modules --
local enums = require("s3_utils.enums")
local tile_layout = require("s3_utils.tile_layout")
local tile_flags = require("s3_utils.tile_flags")

-- Solar2D globals --
local display = display
local graphics = graphics
local timer = timer

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.ActivateMask (bgroup, name, clear_after)
	local cx, cy = bgroup.m_cx, bgroup.m_cy

	if not bgroup[name] then
		bgroup.m_out:translate(-cx, -cy)
		bgroup.m_mask_tex:draw(bgroup.m_out)

		bgroup[name], bgroup.m_out = bgroup.m_out
	end

	bgroup:setMask(bgroup.m_mask)

	bgroup.maskX, bgroup.maskY = cx, cy

	timer.resume(bgroup.m_mask_update)

	bgroup.m_clear_after = clear_after
end

local Choices = {}

local Deltas = { false, -1, false, 1 }

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
		local oi, n = (index - 1) * 4, 0

		for i, delta in ipairs(Deltas) do
			if not (open[oi + i] or occupancy("check", index + delta)) then
				n = n + 1

				Choices[n] = i
			end
		end

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

--- DOCME
function M.DeactivateMask (bgroup)
	timer.pause(bgroup.m_mask_update)

	if bgroup.m_clear_after then
		bgroup:setMask(nil)
	end
end

--- DOCME
function M.GetOutGroup (bgroup)
	return bgroup.m_out
end

local function HideOutGroups (bgroup)
	local cache = bgroup.m_mask_tex.cache

	for i = 1, cache.numChildren do
		cache[i].isVisible = false
	end
end

--- DOCME
function M.PrepareMask (bgroup, name)
	HideOutGroups(bgroup)

	local out = bgroup[name]

	if out then
		out.isVisible = true
	else
		out = display.newGroup()
	end

	bgroup.m_out = out
end

--- Convert maze state into flags.
--
-- Border flags are left in place, allowing the maze to coalesce with the rest of the level.
function M.SetFlags (block, open)
	local i, ncols, nrows = 0, tile_layout.GetCounts()

	for index, col, row in block:IterSelf() do
		local flags = 0

		-- Is this cell open, going up? On the interior, just accept it; along the
		-- fringe of the level, reject it. Otherwise, when on the fringe of the maze
		-- alone, accept it if the next cell up has a "down" flag.
		local uedge = open[i + 1]

		if uedge and row > 1 and (uedge ~= "edge" or tile_flags.IsWorkingFlagSet(index - ncols, "down")) then
			flags = flags + enums.GetFlagByName("up")
		end

		-- Likewise, going left...
		local ledge = open[i + 2]

		if ledge and col > 1 and (ledge ~= "edge" or tile_flags.IsWorkingFlagSet(index - 1, "right")) then
			flags = flags + enums.GetFlagByName("left")
		end

		-- ...going down...
		local dedge = open[i + 3]

		if dedge and row < nrows and (dedge ~= "edge" or tile_flags.IsWorkingFlagSet(index + ncols, "up")) then
			flags = flags + enums.GetFlagByName("down")
		end

		-- ...and going right.
		local redge = open[i + 4]

		if redge and col < ncols and (redge ~= "edge" or tile_flags.IsWorkingFlagSet(index + 1, "left")) then
			flags = flags + enums.GetFlagByName("right")
		end

		-- Register the final flags.
		tile_flags.SetFlags(index, flags)

		i = i + 4
	end
end

local function Finalize (event)
	local bgroup = event.target
	local preview_tex = bgroup.m_preview_tex

	if preview_tex then
		preview_tex:releaseSelf()
	end

	bgroup.m_mask_tex:releaseSelf()

	timer.cancel(bgroup.m_mask_update)
end

--- DOCME
function M.SetupFromBlock (block)
	local col1, col2 = block:GetColumns()
	local ncols = col2 - col1 + 1

	Deltas[1], Deltas[3] = -ncols, ncols

	local row1, row2 = block:GetRows()
	local tw, th = tile_layout.GetSizes() -- n.b. assuming these are multiples of 4...
	local gw, gh = ncols * tw, (row2 - row1 + 1) * th -- ...these will be too...
	local tex, group = graphics.newTexture{
		type = "maskCanvas", width = gw, height = gh,
		pixelWidth = gw + 8, pixelHeight = gh + 8 -- ...so we can trivially add the black border and round up
	}, block:GetGroup()

	group:addEventListener("finalize", Finalize)

	group.m_mask_tex, group.m_mask = tex, graphics.newMask(tex.filename, tex.baseDir)
	group.m_cx, group.m_cy = tw * (col1 + col2 - 1) / 2, th * (row1 + row2 - 1) / 2 -- subtract .5 from each component to center the cells

	group.m_mask_update = timer.performWithDelay(30, function()
		group.m_mask_tex:invalidate("cache")
	end, 0)

	timer.pause(group.m_mask_update)
end

local List1, List2 = {}, {}

--- DOCME
function M.Visit (block, occupancy, func, dt, arg, how)
	occupancy("begin_generation")

	local col0, row0, col1, row1, col2, row2 = 0, 0, block:GetInitialRect()
	local from, to, count, t = List1, List2, 2, 0

	if how == "offset" then
		col0, row0 = col1, row1
	end

	from[1], from[2] = random(col1, col2), random(row1, row2)

	func("start", 0, nil, from[1], from[2], arg)

	repeat
		t = t + dt

		local nadded = 0

		for i = 1, count, 2 do
			local x, y = from[i], from[i + 1]
			local tile = tile_layout.GetIndex(x, y)

			for dir in tile_flags.GetDirections(tile) do
				local tx, ty, bounded = x, y

				if dir == "left" or dir == "right" then
					tx = tx + (dir == "left" and -1 or 1)
					bounded = tx >= col1 and tx <= col2
				else
					ty = ty + (dir == "up" and -1 or 1)
					bounded = ty >= row1 and ty <= row2
				end

				if bounded then
					local tindex = tile_layout.GetIndex(tx, ty)

					if occupancy("mark", tindex) and func(dir, t, tindex, tx - col0, ty - row0, arg) then
						to[nadded + 1], to[nadded + 2], nadded = tx, ty, nadded + 2
					end
				end
			end
		end

		from, to, count = to, from, nadded
	until count == 0

	return t - dt
end

--- Wipe the maze state (and optionally its flags), marking borders.
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
		tile_flags.Wipe(col1, row1, col2, row2)
	end
end

return M