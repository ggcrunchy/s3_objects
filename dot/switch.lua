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

-- Modules --
local audio = require("corona_utils.audio")
local bind = require("corona_utils.bind")
local call = require("corona_utils.call")
local collision = require("corona_utils.collision")
local entity = require("corona_utils.entity")
local file = require("corona_utils.file")

-- Plugins --
local bit = require("plugin.bit")

-- Corona globals --
local display = display
local Runtime = Runtime

-- Imports --
local band = bit.band

-- Exports --
local M = {}

--
--
--

-- Dot methods --
local Switch = entity.NewMethods()

-- Switch <-> events binding --
local Events = call.NewDispatcher()

-- Sounds played by switch --
local Sounds = audio.NewSoundGroup{ _here = ..., _prefix = "sfx", "Switch1.wav", "Switch2.mp3" }

--- Dot method: switch acted on as dot of interest.
function Switch:ActOn ()
	local any_successes, no_failures = false, true

	-- Fire the event and stop showing its hint, and wait for it to finish.
	local n, flag, waiting = 0, 1, self.m_waiting

	for _, event in Events:IterateFunctionsForObject(self) do
		local commands = bind.GetActionCommands(event)

		if band(waiting, flag) == 0 then
			if event() ~= "failed" then
				any_successes, waiting = true, waiting + flag
			else
				no_failures = false
			end

			n = n + 1

			if commands then
				commands("show", false)
				-- TODO: entity.SendMessageTo(...)
			end
		end

		flag = 2 * flag
	end

	self.m_waiting = waiting

	--bind.AddCalls(n)
	call.AddCalls(n)

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

local function Getter (_, what)
	return what == "body_P" and Body or TouchImage
end

Switch.__rprops = { body_P = Getter, touch_image_P = Getter }

--- Dot method: reset switch state.
function Switch:Reset ()
	self[1].isVisible = true
	self[2].isVisible = false

	self.m_touched, self.m_waiting = false, 0
end

--- Dot method: update switch state.
function Switch:Update ()
	local touched, flag, waiting = self.m_touched, 1, self.m_waiting

	for _, event in Events:IterateFunctionsForObject(self) do
		local commands = bind.GetActionCommands(event)

		if band(waiting, flag) ~= 0 and (not commands or commands("is_done")) then
			waiting = waiting - flag

			if touched and commands then
				commands("show", true)
				-- ^^ TODO: entity.SendMessageTo(...)
				-- actually, leaning more and more to just eliminating this approach
				-- few enough use cases to just handle there
					-- Direction node, OnDone, ShowHint, HideHint, etc.
			end
		end

		flag = 2 * flag
	end

	self.m_waiting = waiting
end

-- Switch-being-touched event --
local TouchEvent = { name = "touching_dot" }

-- Add switch-OBJECT collision handler.
collision.AddHandler("switch", function(phase, switch, other, other_type)
	-- Player touched switch: signal it as the dot of interest.
	if other_type == "player" then
		local is_touched = phase == "began"

		TouchEvent.dot, TouchEvent.is_touching, switch.m_touched = switch, is_touched, is_touched

		Runtime:dispatchEvent(TouchEvent)

		TouchEvent.dot = nil

		--
		local flag, waiting = 1, switch.m_waiting

		for _, event in Events:IterateFunctionsForObject(switch) do
			local commands = bind.GetActionCommands(event)

			if commands and band(waiting, flag) == 0 then
				commands("show", is_touched)
				-- TODO: entity.SendMessageTo(...)
			end

			flag = 2 * flag
		end

	-- Switch-flipper touched switch: try to flip it.
	elseif phase == "began" and collision.Implements_PredOrDefPass(other, "flips_switch") == "passed" then
		switch:ActOn()
	end
end)

--
local function LinkSwitch (switch, other, sub, other_sub)
	if sub == "trip" then
		bind.AddId(switch, "target", other.uid, other_sub)
	end
end

-- Handler for switch-specific editor events, cf. s3_utils.dots.EditorEvent
function M.editor (what, arg1, arg2, arg3)
	--[[
		TODO: should become something like:
			return a table that gets stitched into a list...
		return {
			_init = function(name) -- or something that does GetState() for us, e.g. init_nodes()
				local np = function_set.GetState(name)

				np:AddExportNode("trip", "func")
			end,
			get_node_info = function(info)
				info:SetExportHeading("EVENTS")
					:SetFont("bold")
					:SetColor("actions")
				info:AddExportNode("trip", "Fire target actions")

					or

				info:SetHeading("EVENTS")
					:SetFont("bold")
					:SetColor("actions")
				info:AddNode("trip", "Fire target actions")

					or

				{ name = "EVENTS", font = "bold", color = "actions" },
					"trip", "Fire target actions"

					or

				info:AddString("EVENTS")
					:SetFont("bold")
					:SetColor("actions"),
				info:AddNode("trip", "func", "Fire target actions"),
				blocks = {
					{
						-- as above...
					}, {
						-- ...ditto
					}
				}
				-- ^^^ This seems to be the winner (annoying implementation but useful properties)
			end,
			-- thumb filename?
			verify = function(vblock, switch, id)
				if not vblock.links:HasLinks(id, "trip") then
					vblock[#vblock + 1] = "Switch ``" .. switch.name .. "`` has no event targets"
				end
			end
		}
	]]
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		-- STUFF

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		-- STUFF

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		-- STUFF

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "EVENTS", font = "bold", color = "actions", is_source = true }, "trip"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.trip = "Fire target action"

	-- Get Tag --
	elseif what == "get_tag" then
		return "switch"

	-- Get Thumb Filename --
	elseif what == "get_thumb_filename" then
		return "s3_objects/dot/thumb/switch.png"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", "trip", nil

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkSwitch

	-- Verify --
	-- arg1: Verify block
	-- arg2: Switch values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "trip") then
			arg1[#arg1 + 1] = "Switch `" .. arg2.name .. "` has no event targets"
		end
	end
end

-- GFX path --
local GFX = file.Prefix_FromModuleAndPath(..., "gfx")

function M.make (group, info, params)
	local switch = display.newGroup()

	group:insert(switch)

	local _ = display.newImage(switch, GFX .. "Switch-1.png")
	local image2 = display.newImage(switch, GFX .. "Switch-2.png")

	image2.isVisible = false

	switch:scale(.5, .5)

	entity.Make(switch, Switch)

	Sounds:Load()

	local psl = params:GetPubSubList()

	psl:Subscribe(info.target, Events:GetAdder(), switch)

	switch.m_waiting = 0

	return switch
end

return M