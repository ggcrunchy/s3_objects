--- A shader used to unfurl a maze.

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
local includer = require("solar2d_utils.includer")
local orange_duck = require("s3_utils.snippets.operations.orange_duck")
local unit_exclusive = require("s3_utils.snippets.operations.unit_inclusive")

-- Exports --
local M = {}

--
--
--

local effect = { category = "filter", group = "block_maze", name = "unfurl" }

effect.vertexData = {
	{ name = "u", index = 0, default = 0, min = 0, max = 1 },
	{ name = "v", index = 1, default = 0, min = 0, max = 1 },
	unit_exclusive.VertexDatum("left_bottom", 2, 0, 0),
	unit_exclusive.VertexDatum("right_top", 3, 1, 1)
}

local cprops = unit_exclusive.NewCombinedProperties()

cprops:AddPair("left_bottom", "left", "bottom")
cprops:AddPair("right_top", "right", "top")

--- DOCME
M.CombinedProperties = cprops

effect.isTimeDependent = true

includer.AugmentKernels({
	requires = { orange_duck.RELATIONAL, unit_exclusive.UNIT_PAIR },

	vertex = [[

	P_POSITION vec2 VertexKernel (P_POSITION vec2 pos)
	{
		left_bottom = UnitPair(CoronaVertexUserData.z);
		right_top = UnitPair(CoronaVertexUserData.w);
		uv_rel = WHEN_LT(CoronaTexCoord.xy, CoronaVertexUserData.xy);

		return pos;
	}
]],

	fragment = [[

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV float t = CoronaTotalTime;

		// Build up some wave sums to displace the edges a bit.
		P_UV vec4 s1 = sin(vec4(7.9, 3.2, 3.1, 1.7) * uv_rel.yxyx + vec4(3.707, 1.864, 2.604, 5.160) * t);
		P_UV vec4 s2 = sin(vec4(3.6, 6.1, 5.7, 8.1) * uv_rel.yxyx + vec4(4.376, 4.410, 4.654, 2.310) * t);
		P_UV vec4 s3 = sin(vec4(1.7, 1.3, 1.6, 3.9) * uv_rel.yxyx + vec4(2.990, 2.643, 1.430, 4.290) * t);
		P_UV vec4 sum = s1 * .043 + s2 * .035 + s3 * .022;

		// Draw the pixel if it lies within all four (displaced) edges.
		P_UV vec2 pos = .775 * uv + .125; // lower-left = (.125, .125), upper-right = (.875, .875)
		P_UV float in_all = WHEN_EQ(2., dot(WHEN_LE(left_bottom + sum.xy, pos), WHEN_LE(pos, right_top + sum.zw)));

		return CoronaColorScale(texture2D(CoronaSampler0, uv)) * in_all;
	}
]],

	varyings = { uv_rel = "vec2", left_bottom = "vec2", right_top = "vec2" }
}, effect)

graphics.defineEffect(effect)

--- DOCME
M.EFFECT_NAME = "filter.block_maze.unfurl"

return M