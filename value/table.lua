--- Maintain a table.

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

-- Modules --
local bind = require("corona_utils.bind")

--
--
--

local Before = bind.BroadcastBuilder_Helper(nil)

local OutProperties = {
	-- T --
	get_t = function(interval)
		return function()
			--
		end
	end,

	-- Within --
	within = function(interval)
		return function()
			-- get bounds
			-- check interval()
		end
	end
}

local function LinkInterval (interval, other, isub, other_sub)
	local helper = bind.PrepLink(interval, other, isub, other_sub)

	-- TODO!

	return helper("commit")
end

local function EditorEvent (what, arg1, arg2, arg3)
	--
end

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

return {
	game = function(info, params)
		-- TODO
		local function interval ()
			--
		end

		return interval, "no_before" -- using own Before
	end,

	editor = EditorEvent,

	value_type = "number"
}