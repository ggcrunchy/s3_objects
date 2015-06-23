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

local kernel = { category = "filter", group = "event_block_maze", name = "pock" }

kernel.vertexData = {
	{
		name = "scale",
		default = 1, min = 0, max = 1,
		index = 0
	}
}

kernel.isTimeDependent = true

kernel.fragment = [[
	P_POSITION vec2 GetPosition (P_UV float epoch)
	{
		// Grab a value in [0, 1024), with a basic linear congruential generator
		P_DEFAULT float hash = mod(epoch * 377. + 723., 1024.);
		P_DEFAULT vec2 pos;

		// Resolve that to x- and y-coordinates, each in [0, 32)
		pos.x = floor(hash / 32.);
		pos.y = hash - pos.x * 32.;
		
		return (pos / 32.);
	}

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_POSITION bool bNear = false;
		P_UV float up_to = CoronaVertexUserData.w, near_dist = 2.;

		for (P_POSITION int i = 0; i < 3; ++i)
		{
			P_POSITION vec2 pos = GetPosition(float(i));
			P_UV float dist = length(uv - pos);

			if (dist <= up_to)
			{
				up_to = dist;
				bNear = true;
			}
		}

		if (!bNear) return vec4(0.);

		return CoronaColorScale(texture2D(CoronaSampler0, uv));
	}
]]

return kernel