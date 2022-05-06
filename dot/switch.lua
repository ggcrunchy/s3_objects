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
local collision = require("solar2d_utils.collision")
local component = require("tektite_core.component")
local directories = require("s3_utils.directories")
local dots = require("s3_utils.dots")
local events = require("solar2d_utils.events")
local meta = require("tektite_core.table.meta")
local multicall = require("solar2d_utils.multicall")

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

--- DOCME
function M.editor ()
	return {
		actions = { trip = true } -- TODO: resolve trip / target difference
	}
end

--
--
--

local Body = { radius = 25 }

--
--
--

local Switch = {}

local function Getter (_, what)
	return what == "body_P" and Body or "Flip Switch"
end

Switch.__rprops = { body_P = Getter, touch_text_P = Getter }

--
--
--

-- Switch <-> events binding --
local Events = multicall.NewDispatcher()

local Sounds = audio.NewSoundGroup{ module = ..., path = "sfx", "Switch1.wav", "Switch2.mp3" }

--- Dot method: switch acted on as dot of interest.
function Switch:ActOn ()
	local any_successes, no_failures = false, true

	-- Fire the event and stop showing its hint, and wait for it to finish.
	local n, flag, waiting = 0, 1, self.m_waiting

	events.BindNamedArgument("origin", self)
	events.BindNamedArgument("should_show", false)

	for _, event in Events:IterateFunctionsForObject(self) do
		if band(waiting, flag) == 0 then		
			local is_ready = events.DispatchOrHandle_Named("is_ready", event, true)

			if is_ready then
				event()

				any_successes, waiting = true, waiting + flag
			else
				no_failures = false
			end

			n = n + 1

			events.DispatchOrHandle_Named("show", event)
		end

		flag = 2 * flag
	end

	events.UnbindArguments()

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

--
--
--

--- Dot method: reset switch state.
function Switch:Reset ()
	self[1].isVisible = true
	self[2].isVisible = false

	self.m_touched, self.m_waiting = false, 0
end

--
--
--

--- Dot method: update switch state.
function Switch:Update ()
	local flag, touched, waiting = 1, self.m_touched, self.m_waiting

	events.BindNamedArgument("origin", self)
	events.BindNamedArgument("should_show", true)

	for _, event in Events:IterateFunctionsForObject(self) do
		if band(waiting, flag) ~= 0 and events.DispatchOrHandle_Named("is_done", event, true) then
			waiting = waiting - flag

			if touched then
				events.DispatchOrHandle_Named("show", event)
			end
		end

		flag = 2 * flag
	end

	events.UnbindArguments()

	self.m_waiting = waiting
end

--
--
--

local GFX = directories.FromModule(..., "gfx")

function M.make (info, params)
	local switch = display.newGroup()

	params:GetLayer("things1"):insert(switch)

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

--
--
--

collision.AddHandler("switch", function(phase, switch, other)
	if collision.GetType(other) == "player" then
		switch.m_touched = dots.Touch(switch, phase)

		--
		events.BindNamedArgument("origin", switch)
		events.BindNamedArgument("should_show", switch.m_touched)

		local flag, waiting = 1, switch.m_waiting

		for _, event in Events:IterateFunctionsForObject(switch) do
			if band(waiting, flag) == 0 then
				events.DispatchOrHandle_Named("show", event)
			end

			flag = 2 * flag
		end

		events.UnbindArguments()

	elseif phase == "began" and component.ImplementedByObject(other, "flips_switch") then
		switch:ActOn()
	end
end)

--
--
--

return M