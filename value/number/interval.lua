--- Intervals and some operations on them.

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
local abs = math.abs
local frexp = math.frexp
local ldexp = math.ldexp
local max = math.max
local min = math.min
local pairs = pairs

-- Modules --
local bind = require("corona_utils.bind")
local object_vars = require("config.ObjectVariables")

--
--
--

local Events = {}

for _, name in ipairs{ "on_clamp", "on_extrapolate", "on_interpolate" } do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local InProperties = {
	number = { get_bound1 = true, get_bound2 = true, get_t = true, get_value = true }
}

local NextBefore, NextAfter

function NextAfter (x)
	local m, e = frexp(x)

	m = m + 2^-53

	if m == 1 then
		m, e = .5, e + 1
	end

	return ldexp(m, e)
end

function NextBefore  (x)
	local m, e = frexp(x)

	if m == .5 then
		m, e = 1, e - 1
	end

	return ldexp(m - 2^-53, e)
end

local function GetBounds (interval, should_sort, should_sort_open)
	local bound1, bound2, open1, open2 = interval("bounds")

	if should_sort and bound2 < bound1 then
		bound1, bound2 = bound2, bound1

		if should_sort_open then
			open1, open2 = open2, open1
		end
	end

	if open1 then
		bound1 = NextAfter(bound1)
	end

	if open2 then
		bound2 = NextBefore(bound2)
	end

	return bound1, bound2
end

local OutProperties = {
	boolean = {
		-- Within --
		within = function(interval)
			return function()
				local value, _, should_sort_open = interval("value")
				local bound1, bound2 = GetBounds(interval, true, should_sort_open)

				return value >= bound1 and value <= bound2
			end
		end
	},

	number = {
		-- Parameter --
		parameter = function(interval)
			return function()
				local value, should_sort, should_sort_open = interval("value")
				local bound1, bound2 = GetBounds(interval, true, should_sort, should_sort_open)

				return (value - bound1) / (bound2 - bound1)
			end
		end
	}
}

local function LinkInterval (interval, other, isub, other_sub)
	local helper = bind.PrepLink(interval, other, isub, other_sub)

	helper("try_events", Events)
	helper("try_in_properties", InProperties)
	helper("try_out_properties", OutProperties)

	return helper("commit")
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		if arg2.get_bound1 then
			arg3.bound1 = nil
		end

		if arg2.get_bound2 then
			arg3.bound2 = nil
		end

		if not arg2.get_t then
			arg3.t = arg2.can_extrapolate and arg2.extrapolate_t or arg2.interpolate_t
		end

		if arg2.get_value then
			arg3.value = nil
		end

		arg3.can_extrapolate, arg3.extrapolate_t, arg3.interpolate_t = nil
		arg3.should_sort = arg2.should_sort or nil
		arg3.should_sort_open = arg3.should_sort_open or nil

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.bound1 = 0
		arg1.bound2 = 1
		arg1.can_extrapolate = false
		arg1.extrapolate_t = 0
		arg1.interpolate_t = 0
		arg1.should_sort = false
		arg1.should_sort_open = false
		arg1.t = 0
		arg1.value = 0
		
	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddStepperWithEditable{ before = "Bound #1:", value_name = "bound1", min = -1 / 0, scale = .025 }
		arg1:AddStepperWithEditable{ before = "Bound #2:", value_name = "bound2", min = -1 / 0, scale = .025 }
		arg1:AddStepperWithEditable{ before = "Value:", value_name = "value", min = -1 / 0, scale = .025 }

		local interpolate_section = arg1:BeginSection()

			arg1:AddString{ text = "Interpolation:", is_static = true }
			arg1:AddHorizontalSlider{ value_name = "interpolate_t" }

		arg1:EndSection()

		arg1:AddCheckbox{ text = "Can extrapolate", value_name = "can_extrapolate" }

		local extrapolate_section = arg1:BeginSection()

			arg1:AddStepperWithEditable{ before = "Parameter:", value_name = "extrapolate_t", min = -1 / 0, scale = .025 }

		arg1:EndSection()

		arg1:AddCheckbox{ text = "Should sort bounds?", value_name = "should_sort" }
		arg1:AddCheckbox{ text = "Should sort open-ness?", value_name = "should_sort_open" }

		arg1:SetStateFromValue_Watch({ extrapolate_section, interpolate_section }, "can_extrapolate", "on_and_off")

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, "get_bound1", "get_bound2", "get_t",
			{ text = "OUT-PROPERTIES", font = "bold", color = "props" }, "get", "parameter", "within",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }
			-- ^^ Filled in automatically
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.get = "Parameter -> value"
		arg1.get_bound1 = "NUM: Bound #1"
		arg1.get_bound2 = "NUM: Bound #2"
		arg1.get_t = "NUM: Parameter"
		arg1.get_value = "NUM: Value"
		arg1.on_clamp = "On(clamp parameter)"
		arg1.on_extrapolate = "On(extrapolate)"
		arg1.on_interpolate = "On(interpolate)"
		arg1.parameter = "NUM: Value -> parameter"
		arg1.within = "BOOL: Value within bounds?"

	-- Get Tag --
	elseif what == "get_tag" then
		return "interval"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", Events, nil, object_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties), InProperties
	end
end

local function NewInterval (info, params)
	local can_extrapolate, t, get_t, value, get_value = info.can_extrapolate, info.t, info.value
	local bound1, bound2, get_bound1, get_bound2 = info.bound1, info.bound2
	local should_sort, should_sort_open = info.should_sort, info.should_sort_open

	local function interval (comp, arg)
		if comp ~= "t" then
			if arg then
				if arg == "get_bound1" then
					get_bound1 = comp
				elseif arg == "get_bound2" then
					get_bound2 = comp
				elseif arg == "get_t" then
					get_t = comp
				elseif arg == "get_value" then
					get_value = comp
				end
			elseif comp == "bounds" then
				bound1 = (get_bound1 and get_bound1()) or bound1
				bound2 = (get_bound2 and get_bound2()) or bound2

				return bound1, bound2
			elseif comp == "value" then
				value = (get_value and get_value()) or value

				return value, should_sort, should_sort_open
			end
		else
			if get_t then
				t = get_t()

				if not can_extrapolate then
					if t < 0 or t > 1 then
						t = t < 0 and 0 or 1

						Events.on_clamp(interval)
					end
				end
			end

			if comp == "t" then
				return t
			end

			local bound1, bound2 = GetBounds(interval, should_sort, should_sort_open)

			Events[(t >= 0 and t <= 1) and "on_interpolate" or "on_extrapolate"](interval)

			return (1 - t) * bound1 + t * bound2
		end
	end

	local pubsub = params.pubsub

	for name, event in pairs(Events) do
		event.Subscribe(interval, info[name], pubsub)
	end

	for name in pairs(InProperties.number) do
		bind.Subscribe(pubsub, info[name], interval, name)
	end

	object_vars.PublishProperties(pubsub, info.props, OutProperties, info.uid, interval)

	return interval
end

return { make = NewInterval, editor = EditorEvent, value_type = "number" }