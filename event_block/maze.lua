--- Maze-type event block.
--
-- A maze is a strictly toggle-type event, i.e. it goes on &rarr; off or vice versa, and may
-- begin in either state. After toggling, the **"tiles_changed"** event is dispatched with
-- **"maze"** under key **how**.
--
-- @todo Maze format.

-- FIXLISTENER! (Explain event!)

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
local pairs = pairs
local random = math.random
local remove = table.remove

-- Modules --
local effect_props = require("corona_shader.effect_props")
local match_slot_id = require("tektite_core.array.match_slot_id")
local movement = require("s3_utils.movement")
local tile_flags = require("s3_utils.tile_flags")
local tile_maps = require("s3_utils.tile_maps")
local timers = require("corona_utils.timers")

-- Kernels --
local kernel_stipple = require("s3_objects.event_block.kernel.stipple")
local kernel_unfurl = require("s3_objects.event_block.kernel.unfurl")

graphics.defineEffect(kernel_stipple)
graphics.defineEffect(kernel_unfurl)

-- Corona globals --
local display = display
local Runtime = Runtime
local timer = timer
local transition = transition

-- Layer used to draw hints --
local MarkersLayer

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		MarkersLayer = level.markers_layer
	end,

	-- Leave Level --
	leave_level = function()
		MarkersLayer = nil
	end
} do
	Runtime:addEventListener(k, v)
end

-- Ping-pong buffers for unfurling the maze --
local List1, List2 = {}, {}

-- Unfurl timing values --
local UnfurlDelay, UnfurlTime = 150, 850

-- Unfurl transition --
local UnfurlParams = { time = UnfurlTime, transition = easing.outQuint }

-- Unfurl parameter destinations --
local To = { top = 1, left = 0, bottom = 0, right = 1 }

-- Unfurl parameter initial values, plus which parameter (if any) is already in place --
local ParamsSetup = {
	-- Up --
	up = { from = { bottom = 0, left = .6, top = 0, right = .4 }, except = "bottom" },

	-- Left --
	left = { from = { bottom = .6, left = 1, top = .4, right = 1 }, except = "right" },

	-- Down --
	down = { from = { bottom = 1, left = .6, top = 1, right = .4 }, except = "top" },

	-- Right --
	right = { from = { bottom = .6, left = 0, top = .4, right = 0 }, except = "left" },

	-- Start --
	start = { from = { bottom = .6, left = .6, top = .4, right = .4 } }
}

-- Adds a tile to the unfurling maze
local function Unfurl (x, y, occupancy, which, delay)
	local index = tile_maps.GetTileIndex(x, y)
	local image, setup = tile_maps.GetImage(index), ParamsSetup[which]

	if occupancy("mark", index) and image then
		effect_props.AssignEffect(image, "filter.event_block_maze.unfurl")

		local effect, except = effect_props.Wrap(image), setup.except

		for k, v in pairs(setup.from) do
			effect[k], UnfurlParams[k] = v, To[k ~= except and k]
		end

		effect.x, effect.y, UnfurlParams.delay, image.isVisible = image.x, image.y, delay, true

		transition.to(effect, UnfurlParams)

		return true
	end
end

-- Kicks off a fade-in
local function FadeIn (block, occupancy)
	occupancy("begin_generation")

	-- Start all the maze off hidden.
	for index in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			image.isVisible = false
		end
	end

	-- Unfurl the tiles from some random starting point.
	local col1, row1, col2, row2 = block:GetInitialRect()
	local from, to, count, delay = List1, List2, 2, UnfurlDelay

	from[1], from[2] = random(col1, col2), random(row1, row2)

	Unfurl(from[1], from[2], occupancy, "start")

	repeat
		local nadded = 0

		for i = 1, count, 2 do
			local x, y = from[i], from[i + 1]

			for dir in movement.Ways(tile_maps.GetTileIndex(x, y)) do
				local tx, ty, bounded = x, y, true

				if dir == "left" or dir == "right" then
					tx = tx + (dir == "left" and -1 or 1)
					bounded = tx >= col1 and tx <= col2
				else
					ty = ty + (dir == "up" and -1 or 1)
					bounded = ty >= row1 and ty <= row2
				end

				if bounded and Unfurl(tx, ty, occupancy, dir, delay) then
					to[nadded + 1], to[nadded + 2], nadded = tx, ty, nadded + 2
				end
			end
		end

		from, to, count, delay = to, from, nadded, delay + UnfurlDelay
	until count == 0
end

-- Fade-out transition --
local FadeOutParams = {
	alpha = .2, time = 1250,

	onComplete = function(object)
		object.isVisible = false
	end
}

-- Stipple effect transition --
local StippleParams = { scale = 0, time = 850, transition = easing.outBounce }

-- Kicks off a fade-out
local function FadeOut (block)
	for index in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			image.fill.effect = "filter.event_block_maze.stipple"

			image.fill.effect.x = image.x
			image.fill.effect.y = image.y
			image.fill.effect.epoch = index + random(3);

			transition.to(image, FadeOutParams)
			transition.to(image.fill.effect, StippleParams) -- TODO: Verify on reset_level with "already showing" maze
		end
	end
end

-- Tile deltas (indices into Deltas) available on current iteration, during maze building --
local Choices = {}

-- Tile deltas in each cardinal direction --
local Deltas = { false, -1, false, 1 }

-- List of flood-filled tiles that might still have exits available --
local Maze = {}

-- Populates the maze state used to build tile flags
local function MakeMaze (block, open, occupancy)
	occupancy("begin_generation")

	-- Choose a random maze tile and do a random flood-fill of the block.
	Maze[#Maze + 1] = random(#open / 4)

	repeat
		local index = Maze[#Maze]

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

		-- If there are no choices left, remove the tile from the list. Otherwise, choose
		-- one of the available directions and mark it, plus the reverse direction in the
		-- relevant neighbor, and try to resume the flood-fill from that neighbor.
		if n > 0 then
			local i = Choices[random(n)]
			local delta = Deltas[i]

			open[oi + i] = true

			oi = oi + delta * 4
			i = (i + 1) % 4 + 1

			open[oi + i] = true

			Maze[#Maze + 1] = index + delta
		else
			remove(Maze)
		end
	until #Maze == 0
end

-- Handler for maze-specific editor events, cf. s3_utils.event_blocks.EditorEvent
local function OnEditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		-- STUFF

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.starts_on = false
			-- Seeds?

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ text = "Starts on?", value_name = "starts_on" }

	-- Verify --
	-- arg1: Verify block
	-- arg2: Maze values
	-- arg3: Representative object
	elseif what == "verify" then
		-- STUFF
	end
end

-- A random shake displacement
local function ShakeBy ()
	local amount = random(3, 16)

	return amount <= 8 and amount or (amount - 11)
end

-- Updates tiles from maze block flags
local function UpdateTiles (block)
	tile_maps.SetTilesFromFlags(block:GetImageGroup(), block:GetInitialRect())
end

-- Wipes the maze state (and optionally its flags), marking borders
local function Wipe (block, open, wipe_flags)
	local i, col1, row1, col2, row2 = 0, block:GetInitialRect()

	for index, col, row in block:IterSelf() do
		open[i + 1] = row == row1 and index + Deltas[1]
		open[i + 2] = col == col1 and index + Deltas[2]
		open[i + 3] = row == row2 and index + Deltas[3]
		open[i + 4] = col == col2 and index + Deltas[4]

		i = i + 4
	end

	if wipe_flags then
		tile_flags.WipeFlags(col1, row1, col2, row2)
	end
end

-- Event dispatched on change --
local TilesChangedEvent = { name = "tiles_changed", how = "maze" }

-- Export the maze factory.
return function(info, block)
	if info == "editor_event" then
		return OnEditorEvent
	end

	-- Shaking block transition and state --
	local shaking, gx, gy

	-- A safe way to stop an in-progress shake
	local function StopShaking (group)
		if shaking then
			group.x, group.y = gx, gy

			timer.cancel(shaking)

			shaking = nil
		end
	end

	-- Forming maze transition (or related step) --
	local forming

	-- A safe way to stop an in-progress form, at any step (will stop shakes, too)
	local function StopForming (group)
		StopShaking(group)

		if forming then
			transition.cancel(forming)

			forming = nil
		end
	end

	-- If allowed, add some logic to shake the group before and after formation.
	local Shake

	if not info.no_shake then
		function Shake (group, params)
			-- Randomly shake the group around from a home position every so often.
			gx, gy = group.x, group.y

			shaking = timers.Repeat(function()
				group.x = gx + ShakeBy()
				group.y = gy + ShakeBy()
			end, 50)

			-- Shake until the dust clears. If this is before the form itself, kick that
			-- off. Otherwise, cancel the dummy transition to conclude the form event.
			local sparams = { time = block:Dust(3, 7) }

			function sparams.onComplete (group)
				StopShaking(group)

				forming = params and display.isValid(group) and transition.to(group, params)
			end

			return sparams
		end
	end

	-- Instantiate the maze state and some logic to reset / initialize it. The core state
	-- is a flat list of the open directions of each of the block's tiles, stored as {
	-- up1, left1, down1, right1, up2, left2, down2, right2, ... }, where upX et al. are
	-- booleans (true if open) indicating the state of tile X's directions. The list of
	-- already explored tiles is maintained under the negative integer keys.
	local open, added = {}

	function block:Reset ()
		Wipe(self, open, added)

		if added then
			UpdateTiles(self)

			added = false
		end
	end

	-- Compute the deltas between rows of the maze event block (using its width).
	local col1, col2 = block:GetColumns()

	Deltas[1] = col1 - col2 - 1
	Deltas[3] = col2 - col1 + 1

	-- Fires off the maze event
	local occupancy = match_slot_id.Wrap(open)

	local function Fire (forward)
		-- If the previous operation was adding the maze, then wipe it.
		if added then
			Wipe(block, open, true)

		-- Otherwise, make a new one and add it.
		else
			MakeMaze(block, open, occupancy)

			-- Convert maze state into flags. Border flags are left in place, allowing the
			-- maze to coalesce with the rest of the level.
			-- TODO: Are the edge checks even necessary?
			local i, ncols, nrows = 0, tile_maps.GetCounts()

			for index, col, row in block:IterSelf() do
				local flags = 0

				if open[i + 1] and row > 1 then
				--	if open[i + 1] == true or tile_flags.IsFlagSet(open[i + 1], "down") then
					flags = flags + tile_flags.GetFlagsByName("up")
				--	end
				end

				if open[i + 2] and col > 1 then
				--	if open[i + 2] == true or tile_flags.IsFlagSet(open[i + 2], "right") then
					flags = flags + tile_flags.GetFlagsByName("left")
				--	end
				end

				if open[i + 3] and row < nrows then
				--	if open[i + 3] == true or tile_flags.IsFlagSet(open[i + 3], "up") then
					flags = flags + tile_flags.GetFlagsByName("down")
				--	end
				end

				if open[i + 4] and col < ncols then
				--	if open[i + 4] == true or tile_flags.IsFlagSet(open[i + 4], "left") then
					flags = flags + tile_flags.GetFlagsByName("right")
				--	end
				end

				tile_flags.SetFlags(index, flags)

				i = i + 4
			end
		end

		-- Alert listeners about tile changes and fade tiles in or out. When fading in,
		-- we must first update the tiles to reflect the new flags; on fadeout, we need
		-- to keep the images around until the fade is done, and at that point we can
		-- just leave them as is since they're ipso facto invisible.
		added = not added

		Runtime:dispatchEvent(TilesChangedEvent)

		if added then
			UpdateTiles(block)
			FadeIn(block, occupancy)
		else
			FadeOut(block)
		end

		-- Once the actual form part of the transition is done, send out an alert, e.g. to
		-- rebake shapes, then do any shaking.
		local params = {}

		function params.onComplete (group)
			StopForming(group)

			if Shake then
				forming = transition.to(group, Shake(group))
			end
		end

		-- Kick off the form transition. If shaking, the form is actually a sequence of
		-- three transitions: before, form, after. The before and after are no-ops but
		-- consolidate much of the bookkeeping that needs to be done.
		if Shake then
			params = Shake(block:GetGroup(), params)
		end

		forming = transition.to(block:GetGroup(), params)
	end

	-- Shows or hides hints about the maze event
	-- TODO: What's a good way to show this?
	local mgroup

	local function Show (_, show)
		-- Show...
		if show then
			--
			mgroup = display.newGroup()

			MarkersLayer:insert(mgroup)

		-- ...or hide.
		else
			if display.isValid(mgroup) then -- TODO: Try to use display.remove()...
				mgroup:removeSelf()
			end

			mgroup = nil
		end
	end

	-- Put the maze into an initial state and supply its event.
	block:Reset()

	return function(what, arg1, arg2)
		-- Can Fire? --
		-- arg1: forward boolean
		if what == "can_fire" then
			return #open > 0 -- ??? (more?)

		-- Fire --
		-- arg1: forward boolean
		elseif what == "fire" then
			Fire(arg1)

		-- Is Done? --
		elseif what == "is_done" then
			return not forming

		-- Show --
		-- arg1: Object that wants to show something, e.g. a switch
		-- arg2: If true, begin showing; otherwise, stop
		elseif what == "show" then
			Show(arg1, arg2)
		end
	end
end