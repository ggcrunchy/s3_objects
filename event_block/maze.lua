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
local tilesets = require("s3_utils.tilesets")
local timers = require("corona_utils.timers")

-- Plugins --
local memoryBitmap = require("plugin.memoryBitmap")

-- Kernels --
require("s3_objects.event_block.kernel.preview")
require("s3_objects.event_block.kernel.stipple")
require("s3_objects.event_block.kernel.unfurl")

-- Corona globals --
local display = display
local easing = easing
local graphics = graphics
local Runtime = Runtime
local timer = timer
local transition = transition

-- Layer used to draw hints --
local MarkersLayer

-- --
local Effects = {}

-- --
local Names = {}

-- --
local IsMultiPass

--
local function NewKernel (name, tile_shader)
	local kname = ("%s_%s"):format(name, tile_shader:gsub("%.", "__"))
	local kernel = { category = "filter", group = "event_block_maze", name = kname }

	kernel.graph = {
		nodes = {
			tile = { effect = tile_shader, input1 = "paint1" },
			[name] =  { effect = "filter.event_block_maze." .. name, input1 = "tile" },
		},
		output = name
	}

	graphics.defineEffect(kernel)
	effect_props.AddMultiPassEffect(kernel)

	return "filter.event_block_maze." .. kname
end

-- --
local Time

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		MarkersLayer = level.markers_layer
	end,

	-- Leave Level --
	leave_level = function()
		if Time then
			for _, tt in pairs(Time) do
				tt.tex:releaseSelf()
			end
		end

		MarkersLayer, Time = nil
	end,

	-- Things Loaded --
	things_loaded = function()
		--
		local tile_shader = tilesets.GetShader()

		IsMultiPass = tile_shader ~= nil

		if IsMultiPass then
			local effect = Effects[tile_shader]

			if not effect then
				effect = {
					stipple = NewKernel("stipple", tile_shader),
					unfurl = NewKernel("unfurl", tile_shader)
				}

				Effects[tile_shader] = effect
			end

			Names.stipple, Names.unfurl = effect.stipple, effect.unfurl

		else
			Names.stipple, Names.unfurl = "filter.event_block_maze.stipple", "filter.event_block_maze.unfurl"
		end
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

-- --
local Identity = { __index = function(_, k) return k end }

setmetatable(Identity, Identity)

-- --
local Reroute = { u = "unfurl.u", v = "unfurl.v" }

for k in pairs(ParamsSetup.up.from) do
	Reroute[k] = "unfurl." .. k
end

--
local function AttachEffect (tile, what, proxy)
	local fill = tile.fill

	if proxy then
		effect_props.AssignEffect(tile, Names[what])
	else
		fill.effect = Names[what]
	end

	if IsMultiPass then
		return fill.effect[what]
	else
		return fill.effect
	end
end

-- Adds a tile to the unfurling maze
local function Unfurl (x, y, occupancy, which, delay)
	local index = tile_maps.GetTileIndex(x, y)
	local image, setup = tile_maps.GetImage(index), ParamsSetup[which]

	if occupancy("mark", index) and image then
		AttachEffect(image, "unfurl", true)

		local effect, except, lut = effect_props.Wrap(image), setup.except, IsMultiPass and Reroute or Identity

		for k, v in pairs(setup.from) do
			local uk = lut[k]

			effect[uk], UnfurlParams[uk] = v, To[k ~= except and k]
		end

		local name = tile_flags.GetNameByFlags(tile_flags.GetResolvedFlags(index))
		local u, v = tilesets.GetFrameCenter(name)

		effect[lut.u], effect[lut.v], UnfurlParams.delay, image.isVisible = u, v, delay, true

		transition.to(effect, UnfurlParams)

		return true
	end
end

--
local function UnfurlDirs (x, y)
	return movement.Ways(tile_maps.GetTileIndex(x, y))
end

--
local function ArgId (arg) return arg end

--
local function Visit (block, occupancy, func, dirs, arg, xform)
	occupancy("begin_generation")

	-- Unfurl the tiles from some random starting point.
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

--
local function IncDelay (delay)
	return delay + UnfurlDelay
end

-- Kicks off a fade-in
local function FadeIn (block, occupancy)
	-- Start all the maze off hidden.
	for index in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			image.isVisible = false
		end
	end

	-- Unfurl the tiles from some random starting point.
	Visit(block, occupancy, Unfurl, UnfurlDirs, UnfurlDelay, IncDelay)
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
			local effect = AttachEffect(image, "stipple")
			local name = tile_flags.GetNameByFlags(tile_flags.GetResolvedFlags(index))

			effect.u, effect.v = tilesets.GetFrameCenter(name)
			effect.seed = index + random(3)

			transition.to(image, FadeOutParams)
			transition.to(effect, StippleParams) -- TODO: Verify on reset_level with "already showing" maze
		end
	end
end

-- Tile deltas (indices into Deltas) available on current iteration, during maze building --
local Choices = {}

--
local function FindChoice (_, what)
	for i = 1, #Choices do
		if Choices[i] == what then
			return Choices[i + 1]
		end
	end
end

-- --
local IndexToDir = { "up", "left", "down", "right" }

-- Tile deltas in each cardinal direction --
local Deltas = { false, -1, false, 1 }

-- List of flood-filled tiles that might still have exits available --
local Maze = {}

-- Populates the maze state used to build tile flags
local function MakeMaze (open, occupancy)
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
			i = (i + 1) % 4 + 1 -- n.b. follows the order used by Deltas and open

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

--
local FadeParams = { onComplete = display.remove }

--
local PreviewParams = { time = 2500, iterations = 0, transition = easing.inOutCubic }

-- Wipes the maze state (and optionally its flags), marking borders
local function Wipe (block, open, wipe_flags)
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
		if #open == 0 then -- ??? (more?) might be synonym for `not forming` or perhaps tighter test... review!
							-- _forward_ is also probably meaningless / failure
			return "failed"
		end
			
		-- If the previous operation was adding the maze, then wipe it.
		if added then
			FadeOut(block)
			Wipe(block, open, true)

		-- Otherwise, make a new one and add it.
		else
			MakeMaze(open, occupancy)

			-- Convert maze state into flags. Border flags are left in place, allowing the
			-- maze to coalesce with the rest of the level.
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

		-- Alert listeners about tile changes and fade tiles in or out. When fading in,
		-- we must first update the tiles to reflect the new flags; on fadeout, we need
		-- to keep the images around until the fade is done, and at that point we can
		-- just leave them as is since they're ipso facto invisible. (The fadeout is
		-- now done further up, as the flags are used to gather some of the texture
		-- information for stippling.)
		added = not added

		Runtime:dispatchEvent(TilesChangedEvent)

		if added then
			UpdateTiles(block)
			FadeIn(block, occupancy)
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
	-- TODO: What's a good way to show this? (maybe just reuse generator with line segments, perhaps
	-- with a little graphics fluff like in the Hilbert sample... seems like we could ALSO use this
	-- to sequence the unfurl)
	local mgroup, i1, i2, maxt

	local function Show (_, show)
		-- Show...
		if show then
			--
			Time = Time or {}

			if not maxt then
				local col1, row1, col2, row2 = block:GetInitialRect()
				local w, h, times = col2 - col1 + 1, row2 - row1 + 1, {}
				local tex = memoryBitmap.newTexture{ width = w * 2 - 1, height = h * 2 - 1 }

				--
				i1 = tile_maps.GetTileIndex(col1, row1)
				i2 = tile_maps.GetTileIndex(col2, row2)
				maxt = 0

				-- Make a random maze in the block and make a low-res texture to represent it.
				MakeMaze(open, occupancy)
				Visit(block, occupancy, function(x, y, _, dir)
					local index = tile_maps.GetTileIndex(x, y)

					if occupancy("mark", index) then
						local ix, iy = (x - col1) * 2 + 1, (y - row1) * 2 + 1

						if dir == "start" then
							times[index] = 0

							tex:setPixel(ix, iy, 0, 1, 0)
						else
							local dx, dy = 0, 0

							if dir == "up" or dir == "down" then
								dy = dir == "up" and -1 or 1
							else
								dx = dir == "left" and -1 or 1
							end

							local from = tile_maps.GetTileIndex(x - dx, y - dy)
							local t = times[from] + 1 / 32

							tex:setPixel(ix - dx, iy - dy, t - 1 / 64, 1, 0)
							tex:setPixel(ix, iy, t, 1, 0)

							times[index] = t

							if t > maxt then
								maxt = t
							end

							return true
						end
					end
				end, function(x, y)
					local index = tile_maps.GetTileIndex(x, y)
					local oi, n = (index - 1) * 4, 1

					Choices[1] = false

					for i, delta in ipairs(Deltas) do
						if not (open[oi + i] or occupancy("check", index + delta)) then
							Choices[n + 1], n = IndexToDir[i], n + 1
						end
					end

					for _ = 1, n - 2 do
						local j = random(2, n)

						Choices[j], Choices[n] = Choices[n], Choices[j]
					end

					for i = #Choices, n + 1, -1 do
						Choices[i] = nil
					end

					return FindChoice, nil, false
				end)

				tex:invalidate()

				--
				Time[block] = {
					fill = { type = "image", filename = tex.filename, baseDir = tex.baseDir, format = "rgb" },
					tex = tex
				}
			end

			--
			mgroup = display.newGroup()

			MarkersLayer:insert(mgroup)

			--
			local x1, y1 = tile_maps.GetTilePos(i1)
			local x2, y2 = tile_maps.GetTilePos(i2)
			local tilew, tileh = tile_maps.GetSizes()
			local cx, cy, mw, mh = (x1 + x2) / 2, (y1 + y2) / 2, x2 - x1 + tilew, y2 - y1 + tileh
			local mhint, hold = display.newRect(mgroup, cx, cy, mw, mh), .05
			local border = display.newRect(mgroup, cx, cy, mw, mh)
			local total = 2 * maxt + hold -- rise, hold, fall

			mhint.fill = Time[block].fill
			mhint.fill.effect = "filter.event_block_maze.preview"
			mhint.fill.effect.rise = maxt
			mhint.fill.effect.hold = hold
			mhint.fill.effect.total = total

			border:setFillColor(0, 0)
			border:setStrokeColor(0, 0, 1)
			mhint:setFillColor(0, 1, 0, .35)

			border.strokeWidth = 2

			--
			PreviewParams.t = total

			transition.to(mhint.fill.effect, PreviewParams)

		-- ...or hide.
		else
			if display.isValid(mgroup) then
				FadeParams.alpha = .2

				transition.to(mgroup, FadeParams)
			end

			mgroup = nil
		end
	end

	-- Put the maze into an initial state and supply its event.
	block:Reset()

	return function(what, arg1, arg2)
		-- Fire --
		-- arg1: forward boolean
		if what == "fire" then
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