--- Warp-type dot.

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
local sin = math.sin
local type = type

-- Modules --
local audio = require("corona_utils.audio")
local bind = require("corona_utils.bind")
local collision = require("corona_utils.collision")
local component = require("tektite_core.component")
local data_array = require("s3_objects.mixin.data_array")
local distort = require("s3_utils.snippets.operations.distort")
local file = require("corona_utils.file")
local frames = require("corona_utils.frames")
local fx = require("s3_utils.fx")
local length = require("tektite_core.number.length")
local markers = require("s3_utils.effect.markers")
local meta = require("tektite_core.table.meta")
local positions = require("s3_utils.positions")
local pubsub = require("corona_utils.pubsub")
local tile_maps = require("s3_utils.tile_maps")

-- Kernels --
local warp_kernel = require("s3_objects.dot.kernel.warp")

-- Corona globals --
local display = display
local easing = easing
local Runtime = Runtime
local transition = transition

--
--
--

local Warp = {}

-- Layer used to draw hints --
local MarkersLayer

-- Move-between-warps transition --
local MoveParams = { transition = easing.inOutQuad }

-- Sounds played during warping --
local Sounds = audio.NewSoundGroup{ _here = ..., _prefix = "sfx", warp = "Warp.mp3", whiz = "WarpWhiz.mp3" }

-- Network of warps --
local WarpList

-- Default warp logic: no-op
local function DefWarp () end

-- Groups of warp transition handles, to allow cancelling --
local HandleGroups

-- Helper to resolve a warp's target
local function GetTarget (warp)
	local to = warp.m_to

	if type(to) == "number" then
		return WarpList[to], "warp"
	else
		return to, "position"
	end
end

-- Warp logic
local function DoWarp (warp, func)
	local target, ttype = GetTarget(warp)

	if target then
		func = func or DefWarp

		func("move_prepare", warp, target, ttype)

		local items = warp:DataArray_RemoveList()

		if items then
			-- Make a list for tracking transition handles and add it to a free slot.
			local hindex, handles = 1, {}

			while HandleGroups[hindex] do
				hindex = hindex + 1
			end

			HandleGroups[hindex] = handles

			-- Warp-in onComplete handler, which concludes the warp and does cleanup
			local function WarpIn_OC (object)
				if display.isValid(object) then
					func("move_done", warp, target, ttype)

					object:setMask(nil)

					-- Remove all trace of transitions.
					for i = 1, #handles do
						handles[i] = false
					end

					HandleGroups[hindex] = false
				end
			end

			-- Move onComplete handler, which segues into the warp-in stage of warping
			local function MoveParams_OC (object)
				if display.isValid(object) then
					for i, item in ipairs(items) do
						handles[i] = fx.WarpIn(item, i == 1 and WarpIn_OC)
					end

					func("move_done_moving", warp, target, ttype)

					Sounds:PlaySound("warp")
				end
			end

			-- Warp-out onComplete handler, which segues into the move stage of warping
			-- TODO: What if the warp is moving?
			local tx, ty = target.x, target.y

			local function WarpOut_OC (object)
				if display.isValid(object) then
					local dx, dy = object.x - tx, object.y - ty

					MoveParams.x = tx
					MoveParams.y = ty
					MoveParams.time = length.ToBin(dx, dy, 200, 5) * 100
					MoveParams.onComplete = MoveParams_OC

					func("move_began_moving", warp, target, ttype)

					Sounds:PlaySound("whiz")

					-- We now want to track the single move transition. If we do need to
					-- cancel the warp, the logic only looks up to the first missing handle,
					-- so we can safely clear the list by setting the second entry false;
					-- the full array will be overwritten by warp-in transition handles in
					-- the next stage.
					handles[1], handles[2] = transition.to(object, MoveParams), false
				end
			end

			-- Kick off the warp-out transitions of each item. Since the transitions all
			-- finish at the same time, only the first needs an onComplete callback.
			for i, item in ipairs(items) do
				handles[i] = fx.WarpOut(item, i == 1 and WarpOut_OC)
			end

			Sounds:PlaySound("warp")

			return true
		end
	end
end

-- Warp event state --
local WarpEvent = {}

-- DoWarp-compatible event dispatch
local function DispatchWarpEvent (name, from, to, is_warp)
	WarpEvent.name, WarpEvent.from, WarpEvent.to, WarpEvent.is_warp = name, from, to, is_warp

	Runtime:dispatchEvent(WarpEvent)

	WarpEvent.from, WarpEvent.to = nil
end

--- Dot method: warp acted on as dot of interest.
--
-- If the warp has a valid target, dispatches various events (cf. _func_ in @{Warp:Use})
-- with this warp and the target as arguments.
function Warp:ActOn ()
	if not DoWarp(self, DispatchWarpEvent) then
		-- Sound effect?
	end
end

-- Physics body --
local Body = { radius = 25 }

-- Touch image --
local TouchImage = file.Prefix_FromModuleAndPath(..., "hud") .. "WarpTouch.png"

local function Rotate (warp, angle)
	-- TODO: polarity, etc.
end

local function IgnoreSetAngle (what)
	return what == "set_angle" and "ignore"
end

local function Getter (_, what)
	if what == "block_func_prep_P" then
		return IgnoreSetAngle
	elseif what == "body_P" then
		return Body
	elseif what == "on_rotate_block_P" then
		return Rotate
	else
		return TouchImage
	end
end

Warp.__rprops = { block_func_prep_P = Getter, body_P = Getter, on_rotate_block_P = Getter, touch_image_P = Getter }

--- Dot method: reset warp state.
function Warp:Reset ()
	self:DataArray_RemoveList()
end

-- Scale helper
local function Scale (warp, scale)
	warp.xScale = .5 * scale
	warp.yScale = .5 * scale
end

--- Dot method: update warp state.
function Warp:Update ()
	self.rotation = self.rotation - 150 * frames.DiffTime()

	Scale(self, 1 - sin(self.rotation / 30) * .05)
end

--- Manually triggers a warp, sending anything loaded by @{DataArrayMixin:DataArray_AddToList} through.
--
-- The cargo is emptied after use.
--
-- This is a no-op if the warp is missing a target.
-- @callable func As the warp progresses, this is called as
--   func(what, warp, target, target_type)
-- for the following values of _what_: **"move_prepare"** (if the cargo is empty, only this
-- is performed), **"move\_began\_moving"**, **"move\_done\_moving"**, **"move_done"**.
--
-- The target's type will be either **"position"** or **"warp"**. At a minimum, any _target_
-- will have local **x** and **y** coordinates.
--
-- If absent, this is a no-op.
-- @treturn boolean The warp had cargo and a target?
function Warp:Use (func)
	return DoWarp(self, func) ~= nil
end

-- Warp-being-touched event --
local TouchEvent = { name = "touching_dot" }

local TouchedWarpEvent = { name = "touched_warp" }

-- Arrow fade transition --
local ArrowFadeParams = { alpha = 0, transition = easing.outCirc, onComplete = display.remove }

-- Add warp-OBJECT collision handler.
collision.AddHandler("warp", function(phase, warp, other, other_type)
	-- Player touched warp: signal it as the dot of interest.
	if other_type == "player" then
		TouchEvent.dot, TouchEvent.is_touching = warp, phase == "began"

		Runtime:dispatchEvent(TouchEvent)

		TouchEvent.dot = nil

		-- Show or hide a hint between this warp and its target.
		local target = GetTarget(warp)

		if target then
			if phase == "began" then
				warp.m_line = markers.PointFromTo(MarkersLayer, warp, target, 5, .5)
			else
				transition.to(warp.m_line, ArrowFadeParams)

				warp.m_line = nil
			end
		end

	-- Enemy touched warp: react.
	elseif other_type == "enemy" then
		TouchedWarpEvent.warp, TouchedWarpEvent.is_touching = warp, phase == "began"

		other:dispatchEvent(TouchedWarpEvent)

		TouchedWarpEvent.warp = nil
	end
end)

-- Warp graphics and effect --
local WarpFill = {
	type = "composite",
	paint1 = { type = "image" },
	paint2 = { type = "image" }
}

-- Radius of warp object --
local WarpRadius

for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		MarkersLayer = level.markers_layer
		HandleGroups = {}
		WarpList = {}

		local w, h = tile_maps.GetSizes()

		WarpRadius = 1.15 * (w + h) / 2
	end,

	-- Leave Level --
	leave_level = function()
		HandleGroups, MarkersLayer, WarpList = nil
		WarpFill.paint2.filename, WarpFill.paint2.baseDir = nil
	end,

	-- Pre-Reset --
	pre_reset = function()
		for i, hgroup in ipairs(HandleGroups) do
			if hgroup then
				for _, t in ipairs(hgroup) do
					if t then
						transition.cancel(t)
					else
						break
					end
				end

				HandleGroups[i] = false
			end
		end
	end,

	-- Set Canvas --
	set_canvas = distort.CanvasToPaintAttacher(WarpFill.paint2),

	-- Set Canvas Alpha --
	set_canvas_alpha = function(event)
		local alpha = event.alpha

		for _, warp in pairs(WarpList) do
			warp.fill.effect.alpha = alpha
		end
	end
} do
	Runtime:addEventListener(k, v)
end

--
local function LinkWarp (warp, other, sub, other_sub)
	if sub == "to" or (sub == "from" and not warp.to) then
		if sub == "to" and other.type ~= "warp" then
			bind.AddId(warp, "to", other.uid, other_sub)
		else
			warp.to = other.uid
		end
	end
end

-- Handler for warp-specific editor events, cf. s3_utils.dots.EditorEvent
local function OnEditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		arg3.reciprocal_link = nil

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.reciprocal_link = true

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ text = "Two-way link, if one is blank?", value_name = "reciprocal_link" }
		-- Polarity? Can be rotated?

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.from = { friendly_name = "Link from source warp", is_source = true }
		arg1.to = "Link to target (warp or position)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "warp"

	-- Get Thumb Filename --
	elseif what == "get_thumb_filename" then
		return "s3_objects/dot/thumb/warp.png"

	-- New Tag --
	elseif what == "new_tag" then
		--
		local function Pair (links, _, other, _, osub, link_to)
			if links:GetTag(other) ~= "warp" then
				return false, "Non-warp partner", true
			elseif osub:GetName() ~= link_to then
				return false, "Expects `" .. link_to .. "` sublink", true
			end

			return true
		end

		--
		return {
			sub_links = {
				-- From --
				from = function(warp, other, wsub, osub, links)
					return Pair(links, warp, other, wsub, osub, "to")
				end,

				-- To --
				to = function(warp, other, wsub, osub, links)
					-- Is another warp being validly targeted?
					local passed, why, is_cont = Pair(links, warp, other, wsub, osub, "from")

					-- Otherwise, it may still be possible to target a position. If that is not what the
					-- target is, then retain the previous errors; otherwise, provisionally succeed.
					if not passed and links:GetTag(other) == "position" then
						passed, why, is_cont = true
					end

					-- Finally, see if the link is even able to bind a target.
					-- TODO: There are fairly obvious applications of multiple targets... however, it implies
					-- some more editor support, e.g. load-time verification (ensuring constraints, say, after
					-- manual editing) and perhaps "graying out" certain widgets (could use some of the dialog
					-- functionality?)--e.g. an "Allow Multiple Targets" one--when not valid (this would then
					-- require some detection for same).
					if passed and links:HasLinks(warp, "to") then
						passed, why, is_cont = false, "Already has a target"
					end

					return passed, why, is_cont
				end
			}
		}

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkWarp

	-- Verify --
	-- arg1: Verify block
	-- arg2: Warp values
	-- arg3: Representative object
	elseif what == "verify" then
		local links, problem = arg1.links
		local nfrom = links:CountLinks(arg3, "from")

		if links:HasLinks(arg3, "to") or (arg2.reciprocal_link and nfrom == 1) then
			return
		elseif arg2.reciprocal_link then
			if nfrom == 0 then
				problem = "Missing back-link"
			elseif nfrom > 1 then
				problem = "Ambiguous back-link"
			end
		else
			problem = "Missing target"
		end

		arg1[#arg1 + 1] = "Warp `" .. arg2.name .. "`: " .. problem
	end
end

component.AddToObject(Warp, data_array)

-- Warp image --
WarpFill.paint1.filename = file.Prefix_FromModuleAndPath(..., "gfx") .. "Warp.png"

local function NewWarp (group, info)
	local warp = display.newCircle(group, 0, 0, WarpRadius)

	distort.BindCanvasEffect(warp, WarpFill, warp_kernel)

	Scale(warp, 1)

	meta.Augment(warp, Warp)

	Sounds:Load()

	--
	local id = pubsub.IsEndpoint(info.to, true)

	if id then
		warp.m_to = positions.GetPosition(id)
	else
		warp.m_to = info.to
	end

	-- Add the warp to the list so it can be targeted.
	WarpList[info.uid] = warp

	return warp
end

return { make = NewWarp, editor = OnEditorEvent }