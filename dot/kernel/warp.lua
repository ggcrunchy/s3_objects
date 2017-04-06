--- A shader used to render a warp.

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
local screen_fx = require("corona_shader.screen_fx")

-- Kernel --
local kernel = { language = "glsl", category = "composite", group = "dot", name = "warp" }

kernel.vertexData = {
	{ index = 0, name = "xdiv" },
	{ index = 1, name = "ydiv" },
	{ index = 2, name = "alpha", default = 1, min = 0, max = 1 }
}

kernel.vertex = screen_fx.GetPassThroughVertexKernelSource()

kernel.fragment = loader.FragmentShader[[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV vec2 uvn = 2. * uv - 1.;
		P_UV float influence = (1. - smoothstep(.75, 1., dot(uvn, uvn))) * 15.;
		P_UV float o1 = IQ(uv * 12.3) * .5;
		P_UV float o2 = IQ(uv * 14.1) * .25;
		P_COLOR vec4 foreground = texture2D(CoronaSampler0, (uvn * .95) * .5 + .5);
		P_COLOR vec3 background = GetDistortedRGB(CoronaSampler1, vec2(o1, o2) * influence, CoronaVertexUserData);

		return CoronaColorScale(mix(vec4(background, 1.), foreground, .375));
	}
]]
print("!!!!")
print(kernel.fragment)
print("!!!!")
graphics.defineEffect(kernel)