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
local random = math.random

-- Modules --
local bitmap = require("s3_utils.bitmap")
local blocks = require("s3_utils.blocks")
local embedded_predicate = require("tektite_core.array.embedded_predicate")
local maze_ops = require("s3_objects.block.details.maze_ops")
local movement = require("s3_utils.movement")
local tile_flags = require("s3_utils.tile_flags")
local tile_layout = require("s3_utils.tile_layout")
local tile_maps = require("s3_utils.tile_maps")
local tilesets = require("s3_utils.tilesets")

-- Effects --
local preview_effect = require("s3_objects.block.effect.preview")
local stipple_effect = require("s3_objects.block.effect.stipple")
local unfurl_effect = require("s3_objects.block.effect.unfurl")

-- Solar2D globals --
local display = display
local easing = easing
local Runtime = Runtime
local transition = transition

--
--
--

local Rotation = { right = 0, down = 90, left = 180, up = 270 }

local FalloffDistance = .25

local function GetOrientedRect (out, image, index, w, h, dir)
	local rect = out[index]

	if not rect then
		rect = display.newRect(out, 0, 0, w, h)
		rect.anchorX, rect.fill.effect = 0, unfurl_effect
		rect.fill.effect.falloff = FalloffDistance
	end

	local effect, dx, dy = rect.fill.effect, movement.UnitDeltas(dir)
	
	rect.x, rect.y = image.x - w * dx, image.y - h * dy
	rect.rotation = Rotation[dir]
	effect.param = -FalloffDistance -- start with range = [-distance, 0)

	return rect, effect
end

local UnfurlDelay = 120

local UnfurlEffectParams = { param = 1, time = UnfurlDelay }

local function GetPatch (out, image, index)
	local patch = out[index]

	if patch then
		patch.width, patch.height = 1, 1
	else
		patch = display.newRect(out, 0, 0, 1, 1)
	end

	patch.x, patch.y, patch.isVisible = image.x, image.y, false

	return patch
end

local PatchParams = {
	time = 2 * UnfurlDelay,

	onStart = function(object)
		object.isVisible = true
	end
}

local IndexInGroup

local function UnfurlTile (dir, t, index)
	local image = tile_maps.GetImage(index)

	if image then
		local out = maze_ops.GetOutGroup(image.parent)

		-- Unfurl a rect from the previous tile toward this one.
		local _, effect = GetOrientedRect(out, image, IndexInGroup + 1, PatchParams.width, PatchParams.height, dir) -- tile sizes, cf. FadeIn

		UnfurlEffectParams.delay = t - UnfurlDelay

		transition.to(effect, UnfurlEffectParams)

		-- Our rects are smaller than the tile, so will miss some corners. We disguise this
		-- by kicking off a gradual saturation once the unfurl is halfway along.
		local patch = GetPatch(out, image, IndexInGroup + 2)

		PatchParams.delay = t - .5 * UnfurlDelay

		transition.to(patch, PatchParams)

		IndexInGroup = IndexInGroup + 2

		return true
	end
end

local function FadeIn (block, occupancy)
	local group = block:GetGroup()

	maze_ops.PrepareMask(group, "m_unfurl_group")

	IndexInGroup, PatchParams.width, PatchParams.height = 0, tile_layout.GetSizes()

	local duration = maze_ops.Visit(block, occupancy, UnfurlTile, UnfurlDelay)

	maze_ops.ActivateMask(group, "m_unfurl_group", true)

	return duration + 1.25 * UnfurlDelay -- add a buffer for patches and slight timing issues
end

local function GetDot (out, image, index)
	local dot = out[index]

	if not dot then
		dot = display.newCircle(out, 0, 0, 25)
		dot.fill.effect = stipple_effect
	end

	dot.x, dot.y = image.x, image.y

	local effect = dot.fill.effect
	
	effect.radius_squared = 0

	return dot, effect
end

local DotParams = {}

local StippleParams = { radius_squared = 1, transition = easing.continuousLoop }

local StippleDensity = 5

local function FadeOut (block)
	local group = block:GetGroup()

	maze_ops.PrepareMask(group, "m_stipple_group")

	local out, duration, offset = maze_ops.GetOutGroup(group), 0, 0

	for index in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
			local x, y = image.x, image.y

			for i = 1, StippleDensity do
				local dot, effect = GetDot(out, image, offset + i)
				local delay, time = random(0, 150), random(650, 850)

				DotParams.x, DotParams.y = x + random(-48, 48), y + random(-48, 48)
				DotParams.delay, DotParams.time = delay, time

				transition.to(dot, DotParams)

				StippleParams.delay, StippleParams.time = delay, time

				transition.to(effect, StippleParams)

				local sum = delay + time

				if sum > duration then
					duration = sum
				end
			end

			offset = offset + StippleDensity
		end
	end

	maze_ops.ActivateMask(group, "m_stipple_group")

	return duration + 100 -- cf. FadeIn
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

local FadeParams = { onComplete = display.remove }

local function CleanUpHint (block, mgroup)
	if display.isValid(mgroup) then
		FadeParams.alpha = .2

		transition.to(mgroup, FadeParams)
	end

	local tex = block:GetGroup().m_preview_tex

	for row = 1, tex.height do
		for col = 1, tex.width do
			tex:setPixel(col, row, 0, 0, 0)
		end
	end
end

local HalfPreviewDelta = 1 / 64

local function UpdatePreview (dir, t, _, x, y, tex)
	local ix, iy = x * 2 + 1, y * 2 + 1

	if dir == "start" then
		tex:setPixel(ix, iy, 0, 1, 0)
	else
		local dx, dy = 0, 0

		if dir == "up" or dir == "down" then
			dy = dir == "up" and -1 or 1
		else
			dx = dir == "left" and -1 or 1
		end

		tex:setPixel(ix - dx, iy - dy, t - HalfPreviewDelta, 1, 0)
		tex:setPixel(ix, iy, t, 1, 0)

		return true
	end
end

local HoldTime, PreviewDelta = .05, 2 * HalfPreviewDelta

local PreviewParams = { time = 2500, iterations = 0, transition = easing.inOutCubic }

local function AddPreviewTexture (bgroup, col1, row1, col2, row2)
	local tex = bitmap.newTexture{ width = (col2 - col1) * 2 + 1, height = (row2 - row1) * 2 + 1 }

	bgroup.m_preview_fill, bgroup.m_preview_tex = {
		type = "image", format = "rgb",
		filename = tex.filename, baseDir = tex.baseDir
	}, tex

	return tex
end

local function MakeHint (block, open, occupancy, layer)
	-- Prepare a new maze.
	maze_ops.Wipe(block, open)
	maze_ops.Build(open, occupancy)

	local prev = tile_flags.UseGroup(open) -- arbitrary nonce

	maze_ops.SetFlags(block, open)
	tile_flags.Resolve()

	-- Make a low-res texture to represent it.
	local bgroup = block:GetGroup()
	local preview_tex = bgroup.m_preview_tex or AddPreviewTexture(bgroup, block:GetInitialRect())
	local duration = maze_ops.Visit(block, occupancy, UpdatePreview, PreviewDelta, preview_tex, "offset")

	tile_flags.UseGroup(prev)

	preview_tex:invalidate()

	--
	local mgroup = display.newGroup()

	layer:insert(mgroup)

	--
	local mask_tex = bgroup.m_mask_tex
	local mhint = display.newRect(mgroup, bgroup.m_cx, bgroup.m_cy, mask_tex.width, mask_tex.height)
	local border = display.newRect(mgroup, mhint.x, mhint.y, mhint.width, mhint.height)
	local total = 2 * duration + HoldTime -- rise, hold, fall

	mhint.fill = bgroup.m_preview_fill
	mhint.fill.effect = preview_effect
	mhint.fill.effect.rise = duration
	mhint.fill.effect.hold = HoldTime
	mhint.fill.effect.total = total

	border:setFillColor(0, 0)
	border:setStrokeColor(0, 0, 1)
	mhint:setFillColor(0, 1, 0, .35)

	border.strokeWidth = 2

	--
	PreviewParams.t = total

	transition.to(mhint.fill.effect, PreviewParams)

	return mgroup
end

local function UpdateTiles (block)
	tile_maps.SetTilesFromFlags(block:GetGroup(), tilesets.NewTile, block:GetInitialRect())
end

local TilesChangedEvent = { name = "tiles_changed", how = "maze" }

local function IsDone (event)
	event.result = not event.target:GetGroup().m_forming
end

local function IsReady (event)
	event.result = not event.target:GetGroup().m_forming
--[[
	if #open == 0 then -- ??? (more?) might be synonym for `not forming` or perhaps tighter test... review!
						-- _forward_ is also probably meaningless / failure
		return "failed"
	end
]]
end

local function StopForming (bgroup)
	if bgroup.m_forming then
		maze_ops.DeactivateMask(bgroup)
		transition.cancel(bgroup.m_forming)

		bgroup.m_forming = nil
	end
end

local FormingParams = { onComplete = StopForming }

local function NewMaze (info, params)
	-- Instantiate the maze state and some logic to reset / initialize it. The core state
	-- is a flat list of the open directions of each of the block's tiles, stored as {
	-- up1, left1, down1, right1, up2, left2, down2, right2, ... }, where upX et al. are
	-- booleans (true if open) indicating the state of tile X's directions. The list of
	-- already explored tiles is maintained under the negative integer keys.
	local open, block, added = {}, blocks.New(info, params)

	function block:Reset ()
		maze_ops.Wipe(self, open, added)

		if added then
			UpdateTiles(self)

			added = false
		end
	end

	maze_ops.SetupFromBlock(block)

	local occupancy = embedded_predicate.Wrap(open)

	local function Fire ()
		added = not added

		if added then
			maze_ops.SetFlags(block, open)
		else
			FormingParams.time = FadeOut(block)

			maze_ops.Wipe(block, open, true)
		end

		Runtime:dispatchEvent(TilesChangedEvent)

		if added then
			UpdateTiles(block)

			FormingParams.time = FadeIn(block, occupancy)
		end

		local bgroup = block:GetGroup()

		bgroup.m_forming = transition.to(bgroup, FormingParams)
	end

	local mgroup

	block:addEventListener("show", function(event)
		-- Show...
		if event.should_show then
			if added then
				return -- or show some "close" hint?
			elseif mgroup then
				mgroup.isVisible = true
			else
				mgroup = MakeHint(block, open, occupancy, params.markers_layer)
			end

		-- ...or hide.
		elseif mgroup then
			if added then
				CleanUpHint(block, mgroup)

				mgroup = nil
			else
				mgroup.isVisible = false
			end
		end
	end)

	block:addEventListener("is_done", IsDone)
	block:addEventListener("is_ready", IsReady)

	block:Reset()
	block:AttachEvent(Fire, info, params)
end

return { make = NewMaze, editor = OnEditorEvent }