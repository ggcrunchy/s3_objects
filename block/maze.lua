--- Maze-type block.
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
local pairs = pairs
local random = math.random

-- Modules --
local bitmap = require("s3_utils.bitmap")
local embedded_predicate = require("tektite_core.array.embedded_predicate")
local maze_maker = require("s3_objects.block.details.maze_maker")
local movement = require("s3_utils.movement")
local tile_effect = require("s3_objects.block.details.tile_effect")
local tile_maps = require("s3_utils.tile_maps")
local tilesets = require("s3_utils.tilesets")

-- Effects --
local preview_effect = require("s3_objects.block.effect.preview")
local stipple_effect = require("s3_objects.block.effect.stipple")
local unfurl_effect = require("s3_objects.block.effect.unfurl")

-- Corona globals --
local display = display
local easing = easing
local Runtime = Runtime
local timer = timer
local transition = transition

--
--
--

local RawNames = { stipple = stipple_effect, unfurl = unfurl_effect.EFFECT_NAME }

local NameMapping = tile_effect.NewMapping(RawNames)

local Names

local MarkersLayer

local Time

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

		MarkersLayer, Names, Time = nil
	end,

	-- Things Loaded --
	things_loaded = function()
		Names = tile_effect.GetNames(RawNames, NameMapping, tilesets.GetShader())
	end
} do
	Runtime:addEventListener(k, v)
end

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

local To = { top = 1, left = 0, bottom = 0, right = 1 }

local UnfurlDelay, UnfurlTime = 150, 850

local UnfurlParams = { time = UnfurlTime, transition = easing.outQuint }

-- Adds a tile to the unfurling maze
local function Unfurl (x, y, occupancy, which, delay)
	local index = tile_maps.GetTileIndex(x, y)
	local image, setup = tile_maps.GetImage(index), ParamsSetup[which]

	if occupancy("mark", index) and image then
		local effect, except = tile_effect.AttachEffect(Names, image, "unfurl"), setup.except
		local cprops = unfurl_effect.CombinedProperties

		for k, v in pairs(setup.from) do
			cprops:SetProperty(effect, k, v)

			UnfurlParams[k] = To[k ~= except and k]
		end

		local ibounds = image.path.textureBounds

		cprops:SetProperty(effect, "u", (ibounds.uMin + ibounds.uMax) / 2)
		cprops:SetProperty(effect, "v", (ibounds.vMin + ibounds.vMax) / 2)

		UnfurlParams.delay, image.isVisible = delay, true

		transition.to(cprops:WrapForTransitions(effect), UnfurlParams)

		return true
	end
end

local function UnfurlDirs (x, y)
	return movement.Ways(tile_maps.GetTileIndex(x, y))
end

local function IncDelay (delay)
	return delay + UnfurlDelay
end

local function FadeIn (block, occupancy)
	for index in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			image.isVisible = false
		end
	end

	maze_maker.Visit(block, occupancy, Unfurl, UnfurlDirs, UnfurlDelay, IncDelay)
end

local FadeOutParams = {
	alpha = .2, time = 1250,

	onComplete = function(object)
		object.isVisible = false
	end
}

local StippleParams = { scale = 0, time = 850, transition = easing.outBounce }

local function FadeOut (block)
	for index in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			local effect, ibounds = tile_effect.AttachEffect(Names, image, "stipple"), image.path.textureBounds

			effect.u, effect.v = (ibounds.uMin + ibounds.uMax) / 2, (ibounds.vMin + ibounds.vMax) / 2
			effect.seed = index + random(3)

			transition.to(image, FadeOutParams)
			transition.to(effect, StippleParams) -- TODO: Verify on reset_level with "already showing" maze
		end
	end
end

-- Handler for maze-specific editor events, cf. s3_utils.blocks.EditorEvent
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

	-- Get Thumb Filename --
	elseif what == "get_thumb_filename" then
		return "s3_objects/block/thumb/maze.png"

	-- Verify --
	-- arg1: Verify block
	-- arg2: Maze values
	-- arg3: Representative object
	elseif what == "verify" then
		-- STUFF
	end
end

local function ShakeBy ()
	local amount = random(3, 16)

	return amount <= 8 and amount or (amount - 11)
end

local function UpdateTiles (block)
	tile_maps.SetTilesFromFlags(block:GetImageGroup(), block:GetInitialRect())
end

local FadeParams = { onComplete = display.remove }

local PreviewParams = { time = 2500, iterations = 0, transition = easing.inOutCubic }

local TilesChangedEvent = { name = "tiles_changed", how = "maze" }

local function NewMaze (info, block)
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

			shaking = timer.performWithDelay(50, function()
				group.x = gx + ShakeBy()
				group.y = gy + ShakeBy()
			end, 0)

			-- Shake for a little bit. If this is before the form itself, kick that off.
			-- Otherwise, cancel the dummy transition to conclude the form event.
			local sparams = {}

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
		maze_maker.Wipe(self, open, added)

		if added then
			UpdateTiles(self)

			added = false
		end
	end

	maze_maker.SetupFromBlock(block)

	-- Fires off the maze event
	local occupancy = embedded_predicate.Wrap(open)

	local function Fire ()
		if #open == 0 then -- ??? (more?) might be synonym for `not forming` or perhaps tighter test... review!
							-- _forward_ is also probably meaningless / failure
			return "failed"
		end
			
		-- If the previous operation was adding the maze, then wipe it.
		if added then
			FadeOut(block)
			maze_maker.Wipe(block, open, true)

		-- Otherwise, make a new one and add it.
		else
			maze_maker.Build(open, occupancy)
			maze_maker.SetFlags(block, open)
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

	local function Show (show)
		-- Show...
		if show then
			Time = Time or {}

			if not maxt then
				local col1, row1, col2, row2 = block:GetInitialRect()
				local w, h, times = col2 - col1 + 1, row2 - row1 + 1, {}
				local tex = bitmap.newTexture{ width = w * 2 - 1, height = h * 2 - 1 }

				i1 = tile_maps.GetTileIndex(col1, row1)
				i2 = tile_maps.GetTileIndex(col2, row2)
				maxt = 0

				-- Make a random maze in the block with a low-res texture to represent it.
				maze_maker.Build(open, occupancy)
				maze_maker.Visit(block, occupancy, function(x, y, _, dir)
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
					return maze_maker.IterChoices(tile_maps.GetTileIndex(x, y), open, occupancy)
				end)

				tex:invalidate()

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
			mhint.fill.effect = preview_effect
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

	block:addEventListener("is_done", function(event)
		event.result = not forming
	end)

	block:addEventListener("show", function(event)
		Show(event.should_show)
	end)

	-- Put the maze into an initial state and supply its event.
	block:Reset()

	return Fire
end

return { make = NewMaze, editor = OnEditorEvent }