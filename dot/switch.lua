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
local audio = require("solar2d_utils.audio")
local bind = require("solar2d_utils.bind")
local call = require("solar2d_utils.call")
local collision = require("solar2d_utils.collision")
local component = require("tektite_core.component")
local directories = require("s3_utils.directories")
local dots = require("s3_utils.dots")
local meta = require("tektite_core.table.meta")

-- Plugins --
local bit = require("plugin.bit")

-- Solar2D globals --
local display = display
local Runtime = Runtime

-- Imports --
local band = bit.band

-- Exports --
local M = {}

--
--
--

local Switch = {}

-- Switch <-> events binding --
local Events = call.NewDispatcher()

local Sounds = audio.NewSoundGroup{ module = ..., path = "sfx", "Switch1.wav", "Switch2.mp3" }

--- Dot method: switch acted on as dot of interest.
function Switch:ActOn ()
	local any_successes, no_failures = false, true

	-- Fire the event and stop showing its hint, and wait for it to finish.
	local n, flag, waiting = 0, 1, self.m_waiting

	call.BindNamedArgument("origin", self)
	call.BindNamedArgument("should_show", false)

	for _, event in Events:IterateFunctionsForObject(self) do
		if band(waiting, flag) == 0 then		
			local is_ready = call.DispatchOrHandleNamedEvent("is_ready", event, true)

			if is_ready then
				event()

				any_successes, waiting = true, waiting + flag
			else
				no_failures = false
			end

			n = n + 1

			call.DispatchOrHandleNamedEvent("show", event)
		end

		flag = 2 * flag
	end

	call.UnbindArguments()

	n = Events:AddForObject(self, n)

	self.m_waiting = waiting

	--
	if no_failures or any_successes then -- we might more robustly do this BEFORE making any actual calls / shows
										 -- some sort of named event like "will_fail" might be checked?
										 -- then we could also choose a policy too; complicating this is that
										 -- a couple of these cases do calculations, so either these would be
										 -- at best redundant or potentially affect correctness; in particular,
										 -- non-switch users will not likely do all the legwork 
		Sounds:RandomSound()

		-- Change the switch image.
		self[1].isVisible = not self[1].isVisible
		self[2].isVisible = not self[2].isVisible

	--
	else
		-- Fail sound
	end
end

local Body = { radius = 25 }

local function Getter (_, what)
	return what == "body_P" and Body or "Flip Switch"
end

Switch.__rprops = { body_P = Getter, touch_text_P = Getter }

--- Dot method: reset switch state.
function Switch:Reset ()
	self[1].isVisible = true
	self[2].isVisible = false

	self.m_touched, self.m_waiting = false, 0
end

--- Dot method: update switch state.
function Switch:Update ()
	local flag, touched, waiting = 1, self.m_touched, self.m_waiting

	call.BindNamedArgument("origin", self)
	call.BindNamedArgument("should_show", true)

	for _, event in Events:IterateFunctionsForObject(self) do
		if band(waiting, flag) ~= 0 and call.DispatchOrHandleNamedEvent("is_done", event, true) then
			waiting = waiting - flag

			if touched then
				call.DispatchOrHandleNamedEvent("show", event)
			end
		end

		flag = 2 * flag
	end

	call.UnbindArguments()

	self.m_waiting = waiting
end

local TouchEvent = { name = "touching_dot" }

collision.AddHandler("switch", function(phase, switch, other)
	if collision.GetType(other) == "player" then
		local is_touched = phase == "began"

		TouchEvent.dot, TouchEvent.is_touching, switch.m_touched = switch, is_touched, is_touched

		Runtime:dispatchEvent(TouchEvent)

		TouchEvent.dot = nil

		--
		call.BindNamedArgument("origin", switch)
		call.BindNamedArgument("should_show", is_touched)

		local flag, waiting = 1, switch.m_waiting

		for _, event in Events:IterateFunctionsForObject(switch) do
			if band(waiting, flag) == 0 then
				call.DispatchOrHandleNamedEvent("show", event)
			end

			flag = 2 * flag
		end

		call.UnbindArguments()

	elseif phase == "began" and component.ImplementedByObject(other, "flips_switch") then
		switch:ActOn()
	end
end)

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

local GFX = directories.FromModule(..., "gfx")

function M.make (info, params)
	local switch = display.newGroup()

	params.things_layer:insert(switch)

	local _ = display.newImage(switch, GFX .. "Switch-1.png")
	local image2 = display.newImage(switch, GFX .. "Switch-2.png")

	image2.isVisible = false

	switch:scale(.5, .5)

	meta.Augment(switch, Switch)

	Sounds:Load()

	local psl = params:GetPubSubList()

	psl:Subscribe(info.target, Events:GetAdder(), switch)

	switch.m_waiting = 0

	dots.New(info, switch)
end

return M