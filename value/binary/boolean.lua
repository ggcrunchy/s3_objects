--- Binary boolean values.

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
local binary = require("s3_utils.state.binary")

-- Exports --
local M = {}

-- --
local Connectives = {
	And = function(a, b) return a and b end,
	Or = function(a, b) return a or b end,
	NAnd = function(a, b) return not a or not b end,
	NOr = function(a, b) return not a and not b end,
	Xor = function(a, b) return not a ~= not b end,
	Iff = function(a, b) return not a == not b end,
	Implies = function(a, b) return not a or b end,
	NImplies = function(a, b) return a and not b end,
	ConverseImplies = function(a, b) return a or not b end,
	NConverseImplies = function(a, b) return not a and b end
}

--- DOCME
M.AddValue = binary.MakeAdder(Connectives, "connective")

--- DOCME
M.EditorEvent = binary.MakeEditorEvent("boolean", function(what, arg1, arg2, arg3)
	if what == "enum_defs" then
		arg1.connective = "And"
	end
end, "binary_boolean")

-- Export the module.
return M