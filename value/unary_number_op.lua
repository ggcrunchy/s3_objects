--- Transform one number into another.

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

-- Plugins --
local bit = require("plugin.bit")

--
--
--

return require("s3_objects.state_templates.unary").Make("number", "NUM", "number_op", {
	"bnot", bit.bnot,
	"abs", math.abs,
	"acos", math.acos,
	"asin", math.asin,
	"atan", math.atan,
	"ceil", math.ceil,
	"cos", math.cos,
	"cosh", math.cosh,
	"deg", math.deg,
	"exp", math.exp,
	"floor", math.floor,
	"log", math.log,
	"log10", math.log10,
	"modf", math.modf,
	"rad", math.rad,

	"sign", function(a)
		if a < 0 then
			return -1
		elseif a > 0 then
			return 1
		else
			return 0
		end
	end,

	"sin", math.sin,
	"sinh", math.sinh,
	"sqrt", math.sqrt,
	"tan", math.tan,
	"tanh", math.tanh
}, "bnot")