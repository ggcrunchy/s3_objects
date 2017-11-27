--- Given a number, find a boolean result.

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

--
--
--

-- TODO: allow expressions with x bound

return require("s3_objects.state_templates.unary").Make("boolean", nil, "number_predicate", {
	"is_nan", function(a) return a ~= a end,
	"is_negative", function(a) return a < 0 end,
	"is_non_negative", function(a) return a >= 0 end,
	"is_non_positive", function(a) return a <= 0 end,
	"is_number", function(a) return a == a end,
	"is_positive", function(a) return a > 0 end,
	"is_finite", function(a) return a / 0 ~= 0 end, -- TODO: wild guess!
	"is_infinite", function(a) return a / 0 == 0 end,
	"is_integer", function(a) return a % 1 == 0 end,
	"is_non_integer", function(a) return a % 1 ~= 0 end,
	"is_zero", function(a) return a == 0 end,
	"is_non_zero", function(a) return a ~= 0 end,
--	"approximately_zero", function(a, b) return a or not b
--	are bits set / clear
}, "is_positive")