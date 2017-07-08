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
local fx = require("s3_utils.fx")
local loader = require("corona_shader.loader")
local screen_fx = require("corona_shader.screen_fx")

-- Kernel --
local kernel = { language = "glsl", category = "composite", group = "dot", name = "warp" }

kernel.vertexData = fx.DistortionKernelParams()

kernel.vertex = screen_fx.GetPassThroughVertexKernelSource()

kernel.fragment = loader.FragmentShader[[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_UV vec2 offset = IQ_Octaves(uv * 12.3, uv * 14.1) * GetDistortInfluence(2. * uv - 1., .75, 15.);
		P_COLOR vec4 foreground = texture2D(CoronaSampler0, uv);
		P_COLOR vec3 background = GetDistortedRGB(CoronaSampler1, offset, CoronaVertexUserData);

		return CoronaColorScale(mix(vec4(background, 1.), foreground, .675)) * foreground.a;
	}
]]

graphics.defineEffect(kernel)