--- Grammar for boolean operations.

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
local expression = require("s3_utils.expression")

--
--
--

local Grammar = {
	default = false,

	constants = { ["false"] = false, ["true"] = true },
	binary_ops = {
		["and"] = { op = function(oper1, oper2, params) return oper1(params) and oper2(params) end, prec = 2 },
		converse_implies = { op = function(oper1, oper2, params) return oper1(params) or not oper2(params) end, prec = 2 },
		iff = { op = function(oper1, oper2, params) return oper1(params) == oper1(params) end, prec = 2 },
		implies = { op = function(oper1, oper2, params) return not oper1(params) or oper2(params) end, prec = 2 },
		nand = { op = function(oper1, oper2, params) return not oper1(params) or not oper2(params) end, prec = 2 },
		nconverse_implies = { op = function(oper1, oper2, params) return not oper1(params) and oper2(params) end, prec = 2 },
		nimplies = { op = function(oper1, oper2, params) return oper1(params) and not oper2(params) end, prec = 2 },
		nor = { op = function(oper1, oper2, params) return not oper1(params) and not oper2(params) end, prec = 2 },
		["or"] = { op = function(oper1, oper2, params) return oper1(params) or oper2(params) end, prec = 2 },
		xor =  { op = function(oper1, oper2, params) return oper1(params) ~= oper2(params) end, prec = 2 }
	}, unary_ops = {
		["not"] = { op = function(oper, params) return not oper(params) end, prec = 1 }
	}
}

return { grammar = Grammar, gdef = expression.DefineGrammar(Grammar) }