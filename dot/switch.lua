--- Switch-type dot.

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

-- Modules --
local args = require("iterator_ops.args")
local audio = require("corona_utils.audio")
local bind = require("corona_utils.bind")
local collision = require("corona_utils.collision")
local file = require("corona_utils.file")
local meta = require("tektite_core.table.meta")

-- Plugins --
local bit = require("plugin.bit")

-- Corona globals --
local display = display
local Runtime = Runtime

-- Imports --
local band = bit.band

-- Dot methods --
local Switch = {}

-- Switch <-> events binding --
local Events = bind.BroadcastBuilder_Helper()

-- Sounds played by switch --
local Sounds = audio.NewSoundGroup{ _here = ..., _prefix = "sfx", "Switch1.wav", "Switch2.mp3" }

--
local Targets = {}

--
local function TargetsLoop (...)
	local n = 0

	for _, targets in args.Args(...) do
		if targets then
			Targets[n + 1], n = targets, n + 1
		end
	end

	for i = #Targets, n + 1, -1 do
		Targets[i] = nil
	end

	return ipairs(Targets)
end

--- Dot method: switch acted on as dot of interest.
function Switch:ActOn ()
	local forward, any_successes, no_failures = self.m_forward, false, true

	-- Fire the event and stop showing its hint, and wait for it to finish.
	local n = 0

	for _, targets in TargetsLoop(self, self[forward]) do
		local flag, waiting = 1, targets.m_waiting

		for _, event in Events.Iter(targets) do
			local commands = bind.GetActionCommands(event)

			if band(waiting, flag) == 0 then
				if commands then
					commands("set_direction", forward)
				end

				if event() ~= "failed" then
					any_successes, waiting = true, waiting + flag
				else
					no_failures = false
				end

				n = n + 1

				if commands then
					commands("show", false)
				end
			end

			flag = 2 * flag
		end

		targets.m_waiting = waiting
	end

	bind.AddCalls(n)

	-- If there is state around to restore the initial "forward" state of the switch,
	-- we do what it anticipated: reverse the switch's forward-ness.
	if self.m_forward_saved ~= nil and any_successes then
		self.m_forward = not forward
	end

	--
	if no_failures or any_successes then
		Sounds:RandomSound()

		-- Change the switch image.
		self[1].isVisible = not self[1].isVisible
		self[2].isVisible = not self[2].isVisible

	--
	else
		-- Fail sound
	end
end

-- Physics body --
local Body = { radius = 25 }

-- Touch image --
local TouchImage = file.Prefix_FromModuleAndPath(..., "hud") .. "SwitchTouch.png"

--- Dot method: get property.
-- @string name Property name.
-- @return Property value, or **nil** if absent.
function Switch:GetProperty (name)
	if name == "body" then
		return Body
	elseif name == "touch_image" then
		return TouchImage
	end
end

--- Dot method: reset switch state.
function Switch:Reset ()
	self[1].isVisible = true
	self[2].isVisible = false

	self.m_touched = false

	for _, targets in args.Args(self, self[true], self[false]) do
		if targets then
			targets.m_waiting = 0
		end
	end

	if self.m_forward_saved ~= nil then
		self.m_forward = self.m_forward_saved
	end
end

--- Dot method: update switch state.
function Switch:Update ()
	local forward, touched = self.m_forward, self.m_touched

	for _, targets in TargetsLoop(self, self[true], self[false]) do
		local flag, waiting = 1, targets.m_waiting

		for _, event in Events.Iter(targets) do
			local commands = bind.GetActionCommands(event)

			if band(waiting, flag) ~= 0 and (not commands or commands("is_done")) then
				waiting = waiting - flag

				if touched and commands then
					commands("set_direction", forward)
					commands("show", true)
				end
			end

			flag = 2 * flag
		end

		targets.m_waiting = waiting
	end
end

-- Switch-being-touched event --
local TouchEvent = { name = "touching_dot" }

-- Add switch-OBJECT collision handler.
collision.AddHandler("switch", function(phase, switch, other, other_type)
	-- Player touched switch: signal it as the dot of interest.
	if other_type == "player" then
		local forward, is_touched = switch.m_forward, phase == "began"

		TouchEvent.dot, TouchEvent.is_touching, switch.m_touched = switch, is_touched, is_touched

		Runtime:dispatchEvent(TouchEvent)

		TouchEvent.dot = nil

		--
		for _, targets in TargetsLoop(switch, switch[true], switch[false]) do
			local flag, waiting = 1, targets.m_waiting

			for _, event in Events.Iter(targets) do
				local commands = bind.GetActionCommands(event)

				if commands and band(waiting, flag) == 0 then
					commands("set_direction", forward)
					commands("show", is_touched)
				end

				flag = 2 * flag
			end
		end

	-- Switch-flipper touched switch: try to flip it.
	elseif phase == "began" and collision.Implements_PredOrDefPass(other, "flips_switch") == "passed" then
		switch:ActOn()
	end
end)

--
local function LinkSwitch (switch, other, sub, other_sub)
	local tkey

	if sub == "trip" then
		tkey = "target"
	elseif sub == "ftrip" or sub == "rtrip" then
		tkey = sub == "ftrip" and "ftarget" or "rtarget"
	end

	if tkey then
		bind.AddId(switch, tkey, other.uid, other_sub)
	end
end

-- Handler for switch-specific editor events, cf. s3_utils.dots.EditorEvent
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
		arg1.forward = false
		arg1.reverses = false

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddCheckbox{ text = "Starts forward?", value_name = "forward" }
		arg1:AddCheckbox{ text = "Reverse on trip?", value_name = "reverses" }

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "EVENTS", font = "bold", color = "actions", is_source = true }, "trip", "ftrip", "rtrip"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.trip = "Fire target action"
		arg1.ftrip = "Fire forward-only action"
		arg1.rtrip = "Fire reverse-only action"

	-- Get Tag --
	elseif what == "get_tag" then
		return "switch"

	-- Get Thumb Filename --
	elseif what == "get_thumb_filename" then
		return "s3_objects/dot/thumb/switch.png"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", { trip = true, ftrip = true, rtrip = true }, nil

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkSwitch

	-- Verify --
	-- arg1: Verify block
	-- arg2: Switch values
	-- arg3: Representative object
	elseif what == "verify" then
		local has_any

		for _, tkey in args.Args("trip", "ftrip", "rtrip") do
			if arg1.links:HasLinks(arg3, tkey) then
				has_any = true
			end
		end

		if not has_any then
			arg1[#arg1 + 1] = "Switch `" .. arg2.name .. "` has no event targets"
		end
	end
end

-- GFX path --
local GFX = file.Prefix_FromModuleAndPath(..., "gfx")

--
local function ExclusiveTarget (id, pubsub)
	if id then
		local into = { m_waiting = 0 }

		Events.Subscribe(into, id, pubsub)

		return into
	end
end

-- Export the switch factory.
return function (group, info, params)
	if group == "editor_event" then
		return OnEditorEvent
	end

	local switch = display.newGroup()

	group:insert(switch)

	local image1 = display.newImage(switch, GFX .. "Switch-1.png")
	local image2 = display.newImage(switch, GFX .. "Switch-2.png")

	image2.isVisible = false

	switch:scale(.5, .5)

	meta.Augment(switch, Switch)

	Sounds:Load()

	local pubsub = params.pubsub

	Events.Subscribe(switch, info.target, pubsub)

	switch[true] = ExclusiveTarget(info.ftarget, pubsub)
	switch[false] = ExclusiveTarget(info.rtarget, pubsub)

	switch.m_forward = not not info.forward
	switch.m_waiting = 0

	if info.reverses then
		switch.m_forward_saved = switch.m_forward
	end

	return switch
end