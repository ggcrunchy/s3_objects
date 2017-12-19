--- Grammar for number operations.

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
local tonumber = tonumber

-- Modules --
local expression = require("s3_utils.state.expression")

-- Plugins --
local bit = require("plugin.bit")

--
--
--

local Grammar = {
	default = 0, numbers = "number",

	constants = { e = math.exp(1), inf = 1 / 0, nan = 0 / 0, pi = math.pi },
	binary_ops = {
		["^"] = { op = function(oper1, oper2, params) return oper1(params) ^ oper2(params) end, prec = 2 },
		["*"] = { op = function(oper1, oper2, params) return oper1(params) * oper2(params) end, prec = 3 },
		["/"] = { op = function(oper1, oper2, params) return oper1(params) / oper2(params) end, prec = 3 },
		["%"] = { op = function(oper1, oper2, params) return oper1(params) % oper2(params) end, prec = 3 },
		["+"] = { op = function(oper1, oper2, params) return oper1(params) + oper2(params) end, prec = 4 },
		["-"] = { op = function(oper1, oper2, params) return oper1(params) - oper2(params) end, prec = 4 },
		["&"] = { op = function(oper1, oper2, params) return bit.band(oper1(params), oper2(params)) end, prec = 5 },
		["|"] = { op = function(oper1, oper2, params) return bit.bor(oper1(params), oper2(params)) end, prec = 5 },
		["~"] = { op = function(oper1, oper2, params) return bit.bxor(oper1(params), oper2(params)) end, prec = 5 },
		["<<"] = { op = function(oper1, oper2, params) return bit.lshift(oper1(params), oper2(params)) end, prec = 6 },
		[">>"] = { op = function(oper1, oper2, params) return bit.rshift(oper1(params), oper2(params)) end, prec = 6 }
	}, unary_ops = {
		["-"] = { op = function(oper, params) return -oper(params) end, prec = 1 },
		["+"] = { op = function(oper, params) return oper(params) end, prec = 1 }
	}, funcs = {
		abs = { func = math.abs, arity = 1 },
		acos = { func = math.acos, arity = 1 },
		arshift = { func = bit.arshift, arity = 2 },
		asin = { func = math.asin, arity = 1 },
		atan = { func = math.atan, arity = 1 },
		atan2 = { func = math.atan2, arity = 2 },
		band = { func = bit.band, identity = bit.bnot(0) },
		bnot = { func = bit.bnot, arity = 1 },
		bor = { func = bit.bor, identity = 0 },
		bswap = { func = bit.bswap, arity = 1 },
		bxor = { func = bit.bxor, identity = 0 },
		ceil = { func = math.ceil, arity = 1 },
		cos = { func = math.cos, arity = 1 },
		cosh = { func = math.cosh, arity = 1 },
		deg = { func = math.deg, arity = 1 },
		exp = { func = math.exp, arity = 1 },
		floor = { func = math.floor, arity = 1 },
		fmod = { func = math.fmod, arity = 2 },
		log = { func = math.log, arity = 1 },
		log10 = { func = math.log10, arity = 1 },
		lshift = { func = bit.lshift, arity = 2 },
		max = { func = math.max, identity = -1 / 0 },
		min = { func = math.min, identity = 1 / 0 },
		modf = { func = math.modf, arity = 1 },
		rad = { func = math.rad, arity = 1 },
		random = { func = math.random, arity = 0 },
		rol = { func = bit.rol, arity = 2 },
		ror = { func = bit.ror, arity = 2 },
		round = { func = math.round, arity = 1 },
		rshift = { func = bit.rshift, arity = 2 },
		sin = { func = math.sin, arity = 1 },
		sinh = { func = math.sinh, arity = 1 },
		sqrt = { func = math.sqrt, arity = 1 },
		tan = { func = math.tan, arity = 1 },
		tanh = { func = math.tanh, arity = 1 }
	}
}

local GrammarDef = expression.DefineGrammar(Grammar)

local function ResolveText (text)
	if tonumber(text) then
		return text
	else
		local expr_obj = expression.Process(GrammarDef, text)
		local res = expr_obj and expr_obj()

		if res ~= res then
			return "nan"
		elseif res and 1 / res == 0 then
			return res < 0 and "-inf" or "+inf"
		elseif res then
			return res
		end
	end
end

return {
	grammar = Grammar, gdef = GrammarDef,

	fix_constant = function(what)
		if what == "-inf" then
			return -1 / 0
		elseif what == "+inf" then
			return 1 / 0
		elseif what == "nan" then
			return 0 / 0
		else
			return tonumber(what)
		end
	end,

	resolve_text = ResolveText,

	set_editable_text = function(editable, text)
		text = ResolveText(text)

		if text then
			editable:SetStringText(text)
		end
	end
}