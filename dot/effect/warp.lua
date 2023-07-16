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
local pi = require("s3_utils.snippets.constants.pi")
local includer = require("solar2d_utils.includer")

--
--
--

local Range = 3

--
--
--

local effect = {
  language = "glsl", category = "filter", group = "dot", name = "warp",
  isTimeDependent = true, timeTransform = { func = "modulo", range = Range },
}

includer.AugmentKernels({
	requires = { pi.PI },

	fragment = [[

  // Adapted from "Untweetable Cosmic" (CC0): https://www.shadertoy.com/view/mtlGzr

  // We like the rings to interact with each other so create 4 "frisbees"
  // and add their colors together
  const P_POSITION float ringDistance = 0.0925;
  const P_POSITION float noOfRings   = 10.0;
  const P_POSITION float glowFactor  = 0.025;

  // License: MIT, author: Pascal Gilcher, found: https://www.shadertoy.com/view/flSXRV
  P_POSITION float atan_approx (P_POSITION float y, P_POSITION float x)
  {
    P_POSITION float cosatan2 = x / (abs(x) + abs(y));
    P_POSITION float t = PI_OVER_TWO - cosatan2 * PI_OVER_TWO;

    return y < 0.0 ? -t : t;
  }

  // License: CC0, author: Mårten Rånge, found: https://github.com/mrange/glsl-snippets
  P_UV vec2 toPolar (P_UV vec2 p)
  {
    return vec2(length(p), atan_approx(p.y, p.x));
  }

  // License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
  P_POSITION float mod1 (inout P_POSITION float p, P_POSITION float size)
  {
    P_POSITION float halfsize = size * 0.5;
    P_POSITION float c = floor((p + halfsize) / size);

    p = mod(p + halfsize, size) - halfsize;
      
    return c;
  }

  // License: Unknown, author: Unknown, found: don't remember
  P_POSITION float hash (P_POSITION float co)
  {
    return fract(sin(co * 12.9898) * 13758.5453);
  }

  P_POSITION vec3 glow (P_UV vec2 pp, P_COLOR float h)
  {
    P_COLOR float hh = fract(h * 8677.0);
    P_COLOR float b = TWO_PI * (h + CoronaTotalTime / ]] .. ("%f"):format(Range) .. [[) * (hh > 0.5 ? 1.0 : -1.0);
    P_COLOR float a = pp.y + b;
    P_COLOR float d = abs(pp.x) + 0.001;

    return 
      (   smoothstep(0.667 * ringDistance, 0.2 * ringDistance, d)
        * smoothstep(0.1, 1.0, cos(a))
        * glowFactor
        * ringDistance
        / d
      ) * (cos(a + b) + vec3(1.0));
  }

  P_COLOR vec3 contribution (P_UV vec2 ipp, P_COLOR float i)
  {
      ipp.x -= ringDistance * .25 * i;
        
      P_COLOR float rn = mod1(ipp.x, ringDistance); 
      P_COLOR float h = hash(rn + 123.0 * i);

      return glow(ipp, h) * step(rn, noOfRings); 
  }

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
    P_UV vec2 pp = toPolar(2. * uv - 1.);
    P_COLOR vec3 col = contribution(pp, 0.) + contribution(pp, 1.) + contribution(pp, 2.) + contribution(pp, 3.);

    col += (0.01 * vec3(0.25, 0.25, 0.25)) / length(pp);

    P_COLOR vec3 foreground = sqrt(col);
    P_COLOR float a = smoothstep(.8, .2, dot(foreground, vec3(.299, .587, .114)));

    foreground = pow(foreground * a, vec3(.37));

		return CoronaColorScale(vec4(clamp(foreground, 0., 1.), smoothstep(.7, .925, a)));
	}
]]

}, effect)

graphics.defineEffect(effect)

--
--
--

return "filter.dot.warp"