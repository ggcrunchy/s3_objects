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
local loader = require("corona_shader.loader")
local unit_pair = require("corona_shader.encode.vars.unit_pair")

--
--
--

local kernel = { category = "filter", group = "event_block_maze", name = "unfurl" }

kernel.vertexData = {
	{
		name = "u",
		default = 0, min = 0, max = 1,
		index = 0
	},
	{
		name = "v",
		default = 0, min = 0, max = 1,
		index = 1
	}

	-- left_bottom (2), set below: [0, 1; def = 0] (both)
	-- right_top (3), set below: [0, 1; def = 1] (both)
}

unit_pair.AddVertexProperty(kernel, 2, "left", "bottom", "left_bottom", 0, 0)
unit_pair.AddVertexProperty(kernel, 3, "right", "top", "right_top", 1, 1)

kernel.isTimeDependent = true

kernel.vertex = loader.VertexShader[[
	varying P_UV vec2 uv_rel;
	varying P_UV vec2 left_bottom;
	varying P_UV vec2 right_top;

	P_POSITION vec2 VertexKernel (P_POSITION vec2 pos)
	{
		left_bottom = UnitPair(CoronaVertexUserData.z);
		right_top = UnitPair(CoronaVertexUserData.w);
		uv_rel = step(CoronaTexCoord.xy, CoronaVertexUserData.xy);

		return pos;
	}
]]

kernel.fragment = loader.FragmentShader[[
	varying P_UV vec2 uv_rel;
	varying P_UV vec2 left_bottom;
	varying P_UV vec2 right_top;

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV float t = CoronaTotalTime;

		// Build up some wave sums to displace the edges a bit.
		P_UV vec4 s1 = sin(vec4(7.9, 3.2, 3.1, 1.7) * uv_rel.yxyx + mod(vec4(2.7, 3.9, 4.1, -3.7) * 3.7, TWO_PI) * t);
		P_UV vec4 s2 = sin(vec4(3.6, 6.1, 5.7, 8.1) * uv_rel.yxyx + mod(vec4(-3.9, 2.1, 8.2, 1.1) * 2.1, TWO_PI) * t);
		P_UV vec4 s3 = sin(vec4(1.7, 1.3, 1.6, 3.9) * uv_rel.yxyx + mod(vec4(2.3, -2.8, 1.1, 3.3) * 1.3, TWO_PI) * t);
		P_UV vec4 sum = s1 * .043 + s2 * .035 + s3 * .022;

		// Draw the pixel if it lies within all four (displaced) edges.
		P_UV vec2 pos = .775 * uv + .125;
		P_UV float in_all = step(2., dot(step(left_bottom + sum.xy, pos), step(pos, right_top + sum.zw)));

		return CoronaColorScale(texture2D(CoronaSampler0, uv)) * in_all;
	}
]]

graphics.defineEffect(kernel)

return "filter.event_block_maze.unfurl"