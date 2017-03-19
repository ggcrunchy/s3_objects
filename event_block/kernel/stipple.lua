--- A shader used to reduce an image as a series of points.

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

-- Kernel --
local kernel = { category = "filter", group = "event_block_maze", name = "stipple" }

kernel.vertexData = {
	{
		name = "x",
		default = 0, min = -65535, max = 65535,
		index = 0
	},
	{
		name = "y",
		default = 0, min = -65535, max = 65535,
		index = 1
	},
	{
		name = "scale",
		default = 1, min = 0, max = 1,
		index = 2
	},
	{
		name = "seed",
		default = 0, min = 0, max = 100,
		index = 3
	}
}

kernel.vertex = [[
	varying P_UV vec2 uv_rel;

	P_POSITION vec2 VertexKernel (P_POSITION vec2 pos)
	{
		uv_rel = step(pos, CoronaVertexUserData.xy);

		return pos;
	}
]]

kernel.fragment = [[
	varying P_UV vec2 uv_rel;

	P_POSITION vec2 GetPosition (P_UV float epoch)
	{
		// Grab a value in [0, 1024), with a basic linear congruential generator.
		P_POSITION float hash = mod(epoch * 3.77 + 7.23, 10.24) * 100.;

		// Resolve that to x- and y-coordinates, each in [0, 32).
		P_POSITION vec2 pos;

		pos.x = floor(hash / 32.);
		pos.y = hash - pos.x * 32.;

		return pos / 32.;
	}

	void UpdateRange (P_UV float epoch, inout P_UV float up_to)
	{
		P_POSITION vec2 pos = GetPosition(epoch);
		P_UV float dist = length(uv_rel - pos);

		up_to = mix(up_to, max(up_to, dist), step(dist, CoronaVertexUserData.z));
	}

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV float epoch = CoronaVertexUserData.w, up_to = -1.;

    	UpdateRange(epoch, up_to);
     	UpdateRange(epoch + 1., up_to);
     	UpdateRange(epoch + 2., up_to);
    	UpdateRange(epoch + 3., up_to);
    	UpdateRange(epoch + 4., up_to);
     	UpdateRange(epoch + 5., up_to);
    	UpdateRange(epoch + 6., up_to);
    	UpdateRange(epoch + 7., up_to);

		return CoronaColorScale(texture2D(CoronaSampler0, uv) * smoothstep(-.07, .15, up_to));
	}
]]

graphics.defineEffect(kernel)