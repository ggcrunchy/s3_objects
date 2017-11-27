--- Given a pair of numbers, reduce them to one.

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
local number = require("s3_objects.grammars.number")

-- Plugins --
local bit = require("plugin.bit")

--
--
--

return require("s3_objects.state_templates.binary").Make("number", number.gdef, "number_op", {
	"+", function(a, b) return a + b end,
	"-", function(a, b) return a - b end,
	"*", function(a, b) return a * b end,
	"/", function(a, b) return a / b end,
	"%", function(a, b) return a % b end,
	"^", function(a, b) return a ^ b end,
	"arshift", bit.arshift,
	"atan2", math.atan2,
	"band", bit.band,
	"bor", bit.bor,
	"bxor", bit.bxor,
	"fmod", math.fmod,
	"lshift", bit.lshift,
	"max", math.max,
	"min", math.min,
	"rol", bit.rol,
	"ror", bit.ror,
	"rshift", bit.rshift
}, "+")