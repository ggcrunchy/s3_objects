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

-- Modules --
local includer = require("solar2d_utils.includer")
local orange_duck = require("s3_utils.snippets.operations.orange_duck")

--
--
--

local effect = { category = "filter", group = "block_maze", name = "stipple" }

effect.vertexData = {
	{
		name = "u",
		default = 0, min = 0, max = 1,
		index = 0
	},
	{
		name = "v",
		default = 0, min = 0, max = 1,
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

includer.AugmentKernels({
	requires = { orange_duck.RELATIONAL },

	vertex = [[

	P_POSITION vec2 VertexKernel (P_POSITION vec2 pos)
	{
		uv_rel = WHEN_LT(CoronaTexCoord.xy, CoronaVertexUserData.xy);

		return pos;
	}
]],

	fragment = [[

	P_POSITION vec2 GetPosition (P_UV float epoch)
	{
		// Grab a value in [0, 1024), with a basic linear congruential generator.
		P_POSITION float hash = mod(epoch * 3.77 + 7.23, 10.24);

		// Resolve that to x- and y-coordinates, each in [0, 32).
		P_POSITION vec2 pos;

		pos.x = floor(hash * (100. / 32.));
		pos.y = (hash * (100. / 32.) - pos.x) * 32.;

		return pos / 32.;
	}

	P_UV float UpTo (P_UV float epoch)
	{
		return length(uv_rel - GetPosition(epoch));
	}

	void UpdateRange (P_UV float epoch, inout P_UV float up_to)
	{
		up_to = min(up_to, UpTo(epoch));
	}

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV float epoch = CoronaVertexUserData.w, up_to = UpTo(epoch);

     	UpdateRange(epoch + 1., up_to);
     	UpdateRange(epoch + 2., up_to);
    	UpdateRange(epoch + 3., up_to);
    	UpdateRange(epoch + 4., up_to);
     	UpdateRange(epoch + 5., up_to);
    	UpdateRange(epoch + 6., up_to);
    	UpdateRange(epoch + 7., up_to);

		P_COLOR float scale = smoothstep(CoronaVertexUserData.z * 1.75 + 1e-3, CoronaVertexUserData.z, up_to);

		return CoronaColorScale(texture2D(CoronaSampler0, uv)) * scale;
	}
]],

	varyings = { uv_rel = "vec2" }
}, effect)

graphics.defineEffect(effect)

return "filter.block_maze.stipple"