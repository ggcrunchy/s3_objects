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

local kernel = { category = "filter", group = "event_block_maze", name = "unfurl" }

kernel.vertexData = {
	{
		name = "left",
		default = -.25, min = -1, max = 1,
		index = 0
	},
	{
		name = "top",
		default = -.25, min = -1, max = 1,
		index = 1
	},
	{
		name = "right",
		default = .25, min = -1, max = 1,
		index = 2
	},
	{
		name = "bottom",
		default = .25, min = -1, max = 1,
		index = 3
	}
}

kernel.isTimeDependent = true

kernel.fragment = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		// Build up some wave sums to displace the edges a bit.
		P_UV vec4 s1 = sin(vec4(7.9, 3.2, 1.6, 1.7) * uv.yxyx + vec4(2.7, 3.9, 4.1, -3.7) * 3.7 * CoronaTotalTime);
		P_UV vec4 s2 = sin(vec4(3.6, 6.1, 5.7, 8.1) * uv.yxyx + vec4(-3.9, 2.1, 8.2, 1.1) * 2.1 * CoronaTotalTime);
		P_UV vec4 s3 = sin(vec4(1.7, 1.3, 3.1, 3.9) * uv.yxyx + vec4(2.3, -2.8, 1.1, 3.3) * 0.3 * CoronaTotalTime);
		P_UV vec4 sum = CoronaVertexUserData + s1 * .043 + s2 * .033 + s3 * .013;

		// Draw the pixel if it lies within all four (displaced) edges.
		P_UV vec2 pos = uv - .5;

		if (any(lessThan(pos, sum.xy)) || any(greaterThan(pos, sum.zw))) return vec4(0.);

		return CoronaColorScale(texture2D(CoronaSampler0, uv));
	}
]]

return kernel