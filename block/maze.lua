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
local blocks = require("s3_utils.blocks")
local embedded_predicate = require("tektite_core.array.embedded_predicate")
local maze_ops = require("s3_objects.block.details.maze_ops")
local tile_effect = require("s3_objects.block.details.tile_effect")
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
local graphics = graphics
local Runtime = Runtime
local timer = timer
local transition = transition

--
--
--

local RawNames = { stipple = stipple_effect, unfurl = unfurl_effect.EFFECT_NAME }

local NameMapping = tile_effect.NewMapping(RawNames)

local Names

local Time

local function GetPreviewForBlock (block, with_indices)
	Time = Time or {}

	local col1, row1, col2, row2 = block:GetInitialRect()

	if not Time[block] then
		local w, h = col2 - col1 + 1, row2 - row1 + 1
		local tex = bitmap.newTexture{ width = w * 2 - 1, height = h * 2 - 1 }

		Time[block] = {
			fill = {
				type = "image", format = "rgb",
				filename = tex.filename, baseDir = tex.baseDir
			}, tex = tex
		}
	end

	if with_indices then
		local i1 = tile_layout.GetIndex(col1, row1)
		local i2 = tile_layout.GetIndex(col2, row2)

		return Time[block], col1, row1, i1, i2
	else
		return Time[block]
	end
end

for k, v in pairs{
	leave_level = function()
		if Time then
			for _, tt in pairs(Time) do
				tt.tex:releaseSelf()
			end
		end

		Names, Time = nil
	end,

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

local Rotation = { right = 0, down = 90, left = 180, up = 270 }

local To = { top = 1, left = 0, bottom = 0, right = 1 }

local UnfurlDelay, UnfurlTime = 700--[[150]], 850

local UnfurlParams = { time = UnfurlTime, transition = easing.outQuint }

graphics.defineEffect{
	category = "generator", name = "fuzz",

	vertexData = {
		{ index = 0, name = "param" },
		{ index = 1, name = "falloff" },
	},

	fragment = [[
		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			return vec4(smoothstep(CoronaVertexUserData.x + CoronaVertexUserData.y, CoronaVertexUserData.x, uv.x));
		}
	]]
}

local function UnfurlTile (which, delay, index)
	local image = tile_maps.GetImage(index)

	if image then
local movement = require("s3_utils.movement")
local g = image.parent
local gx, gy = g.m_cx, g.m_cy
if not gx then
	local bounds = g.contentBounds
	gx, gy = (bounds.xMin + bounds.xMax) / 2, (bounds.yMin + bounds.yMax) / 2
	g.m_cx, g.m_cy = gx, gy

	g:setMask(g.m_m)
	g.maskX,g.maskY=gx,gy
	timer.performWithDelay(30, function()
		g.m_mt:invalidate("cache")
	end, 0)
end
		local x, y, dx, dy = image.x - gx, image.y - gy, movement.UnitDeltas(which)
		local w, h = tile_layout.GetSizes()
		local x0, y0, t0 = x - w * dx, y - h * dy, delay - UnfurlDelay
local NSteps = 3
		local dt = UnfurlDelay / NSteps
		local px, py = -dy * w, dx * h
local N = 3
		local r = display.newRect(0, y0, w, h)

		r.fill.effect = "generator.custom.fuzz"

		r.fill.effect.param = -.25
		r.fill.effect.falloff = .25
local r2=display.newRect(x0 + gx,y0+gy,w-7,h-7)
local r3=display.newRect(0,y0+gy,w,h)
r3.anchorX,r3.x=0,x0+gx
r3.rotation=Rotation[which]
r2:setFillColor(0,0)
r3:setFillColor(0,0)
r2:setStrokeColor(1,0,0)
r3:setStrokeColor(0,0,1)
r2.strokeWidth=3
r3.strokeWidth=3
		r.anchorX, r.x = 0, x0
		r.rotation = Rotation[which]
g.m_mt:draw(r)
		transition.to(r.fill.effect, { param = 1, delay = t0, time = UnfurlDelay })

		local dw, dh = w / NSteps, h / NSteps

		for _ = 1, NSteps do
			local xx, yy = x0 - px / 2, y0 - py / 2
			for j = 1, N do
				local xt = (j + math.random() * .25 - .5) / N
				local yt = .85 + math.random() * .3
				local rr = display.newCircle(xx + xt * px, yy + xt * py, math.random(4, 6))

rr.isVisible = false
			transition.to(rr, { x = rr.x + yt * dx * dw, y = rr.y + yt * dy * dh, delay = t0, time = dt, onComplete = display.remove
			, onStart = function(r) r.isVisible = true end })
g.m_mt:draw(rr)
			end
			x0, y0 = x0 + dx * dw, y0 + dy * dh
			t0 = t0 + dt
		end

		-- x, y = tile position
		-- dx, dy = movement.UnitDeltas(which)
		-- x0, y0 = x - TileW * dx, y - TileH * dy
		-- t0 = delay - UnfurlDelay
		-- rect at x0, y0 in mask canvas
		-- rect.rotation = Rotation[which]
		-- rect.fill.effect = FADE IN
		-- update param from -falloff to 1, delay = t0, time = UnfurlDelay
		-- dt = UnfurlDelay / nsteps
		-- for i = 1, nsteps do
		--   delay = t0 + (i - 1) * dt, time = dt
		--   random particles along (-dy, dx)
	
--[[
		local cprops, setup = unfurl_effect.CombinedProperties, ParamsSetup[which]
		local effect, except = tile_effect.AttachEffect(Names, image, "unfurl"), setup.except

		for k, v in pairs(setup.from) do
			cprops:SetProperty(effect, k, v)

			UnfurlParams[k] = To[k ~= except and k]
		end

		local ibounds = image.path.textureBounds

		cprops:SetProperty(effect, "u", (ibounds.uMin + ibounds.uMax) / 2)
		cprops:SetProperty(effect, "v", (ibounds.vMin + ibounds.vMax) / 2)

		UnfurlParams.delay, image.isVisible = delay, true

		transition.to(cprops:WrapForTransitions(effect), UnfurlParams)
]]
		return true
	end
end

--[[
x = param, y = falloff
P_COLOR vec4 FragmentKernel( P_UV vec2 texCoord ){
	return vec4(smoothstep(CoronaVertexUserData.x + CoronaVertexUserData.y, CoronaVertexUserData.x, texCoord.x), 0., 0., 1.);  
}
]]

--[[
local g = display.newGroup()
local r1 = display.newRect(g, display.contentCenterX, display.contentCenterY, 150, 150)
local r2 = display.newRect(g, r1.x - (r1.width + 3), r1.y, r1.width, r1.height)
local r3 = display.newRect(g, r1.x + (r1.width + 3), r1.y, r1.width, r1.height)

local bounds = g.contentBounds
local w, h = bounds.xMax - bounds.xMin, bounds.yMax - bounds.yMin

local canvas = graphics.newTexture{ type = "maskCanvas", width = w + 6, height = h + 6 }
local mask = graphics.newMask(canvas.filename, canvas.baseDir)

g:setMask(mask)

g.maskX, g.maskY = display.contentCenterX, display.contentCenterY

local rr = display.newRoundedRect(0, 0, 65, 85, 15)

canvas:draw(rr)

timer.performWithDelay(100, function(event)
    rr.x = math.sin(event.time / 750) * 150
    rr.rotation = (event.time / 25) % 360

    canvas:invalidate("cache")
end, 0)
]]

-- max(CoronaVertexUserData.x - 4. * dot(texCoord - .5, texCoord - .5), 0.)

local function IncDelay (delay)
	return delay + UnfurlDelay
end

local function FadeIn (block, occupancy)
	for index in block:IterSelf() do
		local image = tile_maps.GetImage(index)

		if image then
	--		image.isVisible = false
		end
	end

	maze_ops.Visit(block, occupancy, UnfurlTile, 0--[[UnfurlDelay]], IncDelay)
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
	tile_maps.SetTilesFromFlags(block:GetGroup(), tilesets.NewTile, block:GetInitialRect())
end

local FadeParams = { onComplete = display.remove }

local PreviewParams = { time = 2500, iterations = 0, transition = easing.inOutCubic }

local TilesChangedEvent = { name = "tiles_changed", how = "maze" }

local function IncPreviewTime (t)
	return t + 1 / 32
end

local function CleanUpHint (block, mgroup)
	if display.isValid(mgroup) then
		FadeParams.alpha = .2

		transition.to(mgroup, FadeParams)
	end

	local tex = GetPreviewForBlock(block).tex

	for row = 1, tex.height do
		for col = 1, tex.width do
			tex:setPixel(col, row, 0, 0, 0)
		end
	end
end

local function MakeHint (block, open, occupancy, layer)
	-- Make a random maze in the block with a low-res texture to represent it.
	maze_ops.Wipe(block, open)
	maze_ops.Build(open, occupancy)

	local prev = tile_flags.UseGroup(open) -- arbitrary nonce

	maze_ops.SetFlags(block, open)
	tile_flags.Resolve()

	local preview, col1, row1, i1, i2 = GetPreviewForBlock(block, true)
	local maxt, tex = 0, preview.tex

	maze_ops.Visit(block, occupancy, function(dir, t, _, x, y)
		local ix, iy = (x - col1) * 2 + 1, (y - row1) * 2 + 1

		if dir == "start" then
			tex:setPixel(ix, iy, 0, 1, 0)
		else
			local dx, dy = 0, 0

			if dir == "up" or dir == "down" then
				dy = dir == "up" and -1 or 1
			else
				dx = dir == "left" and -1 or 1
			end

			tex:setPixel(ix - dx, iy - dy, t - 1 / 64, 1, 0)
			tex:setPixel(ix, iy, t, 1, 0)

			if t > maxt then
				maxt = t
			end

			return true
		end
	end, 0, IncPreviewTime)
	tile_flags.UseGroup(prev)

	tex:invalidate()

	--
	local mgroup = display.newGroup()

	layer:insert(mgroup)

	--
	local x1, y1 = tile_layout.GetPosition(i1)
	local x2, y2 = tile_layout.GetPosition(i2)
	local tilew, tileh = tile_layout.GetSizes()
	local cx, cy, mw, mh = (x1 + x2) / 2, (y1 + y2) / 2, x2 - x1 + tilew, y2 - y1 + tileh
	local mhint, hold = display.newRect(mgroup, cx, cy, mw, mh), .05
	local border = display.newRect(mgroup, cx, cy, mw, mh)
	local total = 2 * maxt + hold -- rise, hold, fall

	mhint.fill = preview.fill
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

	return mgroup
end

local function NewMaze (info, params)
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
			FadeOut(block)
			maze_ops.Wipe(block, open, true)
		end

		-- Alert listeners about our changes and fade tiles in or out. When fading in,
		-- we must first update the tiles to reflect the new flags; on fadeout, we need
		-- to keep the images around until the fade is done, but since this leaves them
		-- invisible we can do nothing.
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
	local mgroup

	local function Show (show)
		-- Show...
		if show then
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
	end

	block:addEventListener("is_done", function(event)
		event.result = not forming
	end)

	block:addEventListener("is_ready", function(event)
		event.result = not forming
--[[
		if #open == 0 then -- ??? (more?) might be synonym for `not forming` or perhaps tighter test... review!
							-- _forward_ is also probably meaningless / failure
			return "failed"
		end
]]
	end)

	block:addEventListener("show", function(event)
		Show(event.should_show)
	end)

	block:Reset()
	block:AttachEvent(Fire, info, params)
end

return { make = NewMaze, editor = OnEditorEvent }