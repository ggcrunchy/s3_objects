--- A shader used to preview a maze.

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

local kernel = { category = "filter", group = "event_block_maze", name = "preview" }

kernel.vertexData = {
	{
		name = "t",
		default = 0, min = 0,
		index = 0
	},
	{
		name = "rise",
		index = 1
	},
	{
		name = "hold",
		index = 2
	},
	{
		name = "total",
		index = 3
	}
}

kernel.fragment = [[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		#define PREVIEW_TIME CoronaVertexUserData.x

		P_COLOR vec2 time_opacity = texture2D(CoronaSampler0, uv).rg; // What "time" and opacity does this part of the maze have?
		P_UV float rise_and_hold = dot(CoronaVertexUserData.yz, vec2(1.)); // Duration over which we rise and hold
		P_UV float has_risen = step(CoronaVertexUserData.y, PREVIEW_TIME); // Have we already risen?
		P_UV float t_rise = PREVIEW_TIME / CoronaVertexUserData.y; // If not, when are we along the way?
		P_UV float is_falling = step(rise_and_hold, PREVIEW_TIME); // Are we now falling?
		P_UV float t_fall = (PREVIEW_TIME - rise_and_hold) / (CoronaVertexUserData.w - rise_and_hold); // If so, when?

		// Figure out the "time" (0 = bottom, 1 = top) according to what interval the preview time is in. 
		P_UV float when = mix(mix(t_rise, 1., has_risen), 1. - t_fall, is_falling);

		// Choose a color based on how well the preview and maze times agree.
		P_COLOR float gray = 1. - smoothstep(0., max(when * CoronaVertexUserData.y, 1e-4), time_opacity.x) * .35;
		P_COLOR vec4 color = CoronaColorScale(vec4(vec3(gray), 1.));

		// Mask out off-maze parts.
		color *= step(.5, time_opacity.y);

		// Dither the remaining bits somewhat and supply the color.
		P_COLOR float h1 = fract(32. * (uv.x + uv.y)), h2 = fract(32. * (uv.x - uv.y));

		color *= (1. - step(.5, h1) * step(.5, h2));

		return color;
	}
]]

graphics.defineEffect(kernel)

return "filter.event_block_maze.preview"