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
local sin = math.sin

-- Modules --
local audio = require("solar2d_utils.audio")
local bind = require("solar2d_utils.bind")
local call = require("solar2d_utils.call")
local collision = require("solar2d_utils.collision")
local component = require("tektite_core.component")
local data_store = require("s3_objects.mixin.data_store")
local distort = require("s3_utils.snippets.operations.distort")
local dots = require("s3_utils.dots")
local file = require("solar2d_utils.file")
local frames = require("solar2d_utils.frames")
local length = require("tektite_core.number.length")
local markers = require("s3_utils.object.markers")
local meta = require("tektite_core.table.meta")

-- Effects --
local warp_effect = require("s3_objects.dot.effect.warp")

-- Corona globals --
local display = display
local easing = easing
local graphics = graphics
local Runtime = Runtime
local transition = transition

-- Exports --
local M = {}

--
--
--

local Warp = {}

local WarpEvent = {}

--- Dot method: warp acted on as dot of interest.
--
-- If the warp has a valid target, dispatches various events (cf. _func_ in @{Warp:Use})
-- to the actor with this warp and said target as arguments.
function Warp:ActOn (actor)
	if not self:Use(actor) then
		-- Sound effect?
	end
end

local Body = { radius = 25 }

local TouchImage = file.Prefix_FromModuleAndPath(..., "hud") .. "WarpTouch.png"

local function Rotate (warp, angle)
	-- TODO: polarity, etc.
end

local function Getter (_, what)
	if what == "body_P" then
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
	self:DataStore_RemoveParts()
end

local function Scale (warp, scale)
	warp.xScale = .5 * scale
	warp.yScale = .5 * scale
end

--- Dot method: update warp state.
function Warp:Update ()
	self.rotation = self.rotation - 150 * frames.DiffTime()

	Scale(self, 1 - sin(self.rotation / 30) * .05)
end

local function DispatchWarpEvent (user, name, from, to)
	WarpEvent.name, WarpEvent.from, WarpEvent.to = name, from, to

	call.DispatchOrHandleEvent(user, WarpEvent)

	WarpEvent.from, WarpEvent.to = nil
end

local function ClearMask (object)
	object:setMask(nil)
end

local function ScaleMask (body, object)
	object = object or body

	object.maskScaleX = body.width / 4
	object.maskScaleY = body.height / 2
end

local Tag = "Warp:TransitionTag"

local MaskIn = { time = 900, tag = Tag, transition = easing.inQuad }

local function DoTransitionThenComplete (object, params, on_complete)
	params.onComplete = on_complete

	transition.to(object, params)

	params.onComplete = nil
end

local function WarpIn (object, on_complete)
	ScaleMask(object, MaskIn)
	DoTransitionThenComplete(object, MaskIn, on_complete or ClearMask)
end

local HereGFX = file.Prefix_FromModuleAndPath(..., "gfx")

local Mask = graphics.newMask(HereGFX .. "WarpMask.png")

local MaskOut = { maskScaleX = 0, maskScaleY = 0, tag = Tag, time = 900, transition = easing.outQuad }

local function WarpOut (object, on_complete)
	object:setMask(Mask)

	ScaleMask(object)
	DoTransitionThenComplete(object, MaskOut, on_complete)
end

local function DoAll (items, func, on_first)
	func(items[1], on_first) -- transitions more or less simultaneous, so only one needs to do the on-complete logic

	for i = 2, #items do
		func(items[i])
	end
end

local MoveParams = { tag = Tag, transition = easing.inOutQuad }

local Sounds = audio.NewSoundGroup{ _here = ..., _prefix = "sfx", warp = "Warp.mp3", whiz = "WarpWhiz.mp3" }

--- Trigger a warp, sending through anything loaded by @{DataArrayMixin:DataStore_Append}.
--
-- The cargo is emptied after use.
--
-- This is a no-op if the warp is missing a target.
-- @callable func As the warp progresses, this is called as
--   func(what, warp, target)
-- for the following values of _what_: **"move_prepare"** (if the cargo is empty, only this
-- is performed), **"move\_began\_moving"**, **"move\_done\_moving"**, **"move_done"**.
--
-- The target's type will be either **"position"** or **"warp"**. At a minimum, any _target_
-- will have local **x** and **y** coordinates.
--
-- If absent, this is a no-op.
-- @treturn boolean The warp had cargo and a target?
function Warp:Use (user)
	local target = self.m_to

	if target then
		DispatchWarpEvent(user, "move_prepare", self, target)

		local items = self:DataStore_RemoveParts()

		if items then
			-- Warp-in onComplete handler, which concludes the warp and does cleanup
			local function WarpIn_OC (object)
				if display.isValid(object) then
					DispatchWarpEvent(user, "move_done", self, target)

					object:setMask(nil)
				end
			end

			-- Move onComplete handler, which segues into the warp-in stage of warping
			local function MoveParams_OC (object)
				if display.isValid(object) then
					DoAll(items, WarpIn, WarpIn_OC)
					DispatchWarpEvent(user, "move_done_moving", self, target)

					Sounds:PlaySound("warp")
				end
			end

			-- Warp-out onComplete handler, which segues into the move stage of warping
			-- TODO: What if the warp is moving?
			local tx, ty = target.x, target.y

			local function WarpOut_OC (object)
				if display.isValid(object) then
					DispatchWarpEvent(user, "move_began_moving", self, target)

					Sounds:PlaySound("whiz")

					local dx, dy = object.x - tx, object.y - ty

					MoveParams.x = tx
					MoveParams.y = ty
					MoveParams.time = length.ToBin(dx, dy, 200, 5) * 100
					MoveParams.onComplete = MoveParams_OC

					transition.to(object, MoveParams)
				end
			end

			DoAll(items, WarpOut, WarpOut_OC)

			Sounds:PlaySound("warp")

			return true
		end
	end
end

local MarkersLayer

local TouchEvent = { name = "touching_dot" }

local TouchedWarpEvent = { name = "touched_warp" }

local ArrowFadeParams = { alpha = 0, transition = easing.outCirc, onComplete = display.remove }

-- Add warp-OBJECT collision handler.
collision.AddHandler("warp", function(phase, warp, other)
	local other_type = collision.GetType(other)

	-- Player touched warp: signal it as the dot of interest.
	if other_type == "player" then
		TouchEvent.dot, TouchEvent.is_touching = warp, phase == "began"

		Runtime:dispatchEvent(TouchEvent)

		TouchEvent.dot = nil

		-- Show or hide a hint between this warp and its target.
		local target = warp.m_to

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
function M.editor (what, arg1, arg2, arg3)
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

component.AddToObject(Warp, data_store)

local function PreReset()
	transition.cancel(Tag)
end

local WarpList

local function SetCanvasAlpha (event)
	local alpha = event.alpha

	for _, warp in ipairs(WarpList) do
		warp.fill.effect.alpha = alpha
	end
end

local WarpFill = {
	type = "composite",
	paint1 = { type = "image" },
	paint2 = { type = "image" }
}

local function LeaveLevel ()
	MarkersLayer, WarpList = nil
	WarpFill.paint2.filename, WarpFill.paint2.baseDir = nil

	Runtime:removeEventListener("leave_level", LeaveLevel)
	Runtime:removeEventListener("pre_reset", PreReset)
	Runtime:removeEventListener("set_canvas_alpha", SetCanvasAlpha)

	transition.cancel(Tag)
end

WarpFill.paint1.filename = HereGFX .. "Warp.png"

local function AddTarget (target, warp)
	warp.m_to = target
end

local WarpRadius

local function FirstTimeInit (params)
	MarkersLayer = params.markers_layer
	WarpList, WarpRadius = {}, 1.15 * (params.w + params.h) / 2

	distort.AttachCanvasToPaint(WarpFill.paint2, params.canvas)

	Runtime:addEventListener("leave_level", LeaveLevel)
	Runtime:addEventListener("pre_reset", PreReset)
	Runtime:addEventListener("set_canvas_alpha", SetCanvasAlpha)
end

--- DOCME
function M.make (info, params)
	if not WarpList then
		FirstTimeInit(params)
	end
	
	local warp = display.newCircle(params.things_layer, 0, 0, WarpRadius)

	distort.BindCanvasEffect(warp, WarpFill, warp_effect)

	Scale(warp, 1)

	meta.Augment(warp, Warp)

	Sounds:Load()

	local psl = params:GetPubSubList()

	psl:Subscribe(info.to, AddTarget, warp)
	psl:Publish(warp, info.uid, "pos")

	WarpList[#WarpList + 1] = warp

	dots.New(info, warp)
end

return M