--- Component that confers a coordinate system on its owner.

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

-- Standard library imports --
local pairs = pairs

-- Modules --
local component = require("tektite_core.component")

-- Unique member keys --
local _lcs = {}

--
--
--

local CoordinateMixin = {}

--
--
--

local function Component (vx, vy, wx, wy, normalized)
  local dot = vx * wx + vy * wy

  if normalized then
    return dot
  else
    return dot / (wx^2 + wy^2)
  end
end

--- DOCME
function CoordinateMixin:Coordinate_GetComponents (x, y)
	local lcs = self[_lcs]

	if lcs then
    local cx, cy = lcs("origin")
		local dx, dy = x - cx, y - cy
    local rx, ry, ux, uy, normalized = lcs("axes")
		local s = Component(dx, dy, rx, ry, normalized)
		local t = Component(dx, dy, ux, uy, normalized)

		return s, t
	else
		return x, y
	end
end

--
--
--

--- DOCME
function CoordinateMixin:Coordinate_GlobalToLocal (x, y)
	local lcs = self[_lcs]

	if lcs then
    local cx, cy = lcs("origin")
		local dx, dy = x - cx, y - cy
    local rx, ry, ux, uy, normalized = lcs("axes")
		local s = Component(dx, dy, rx, ry, normalized)
		local t = Component(dx, dy, ux, uy, normalized)

		return s * rx + t * ux, s * ry + t * uy
	else
		return x, y
	end
end

--
--
--

--- DOCME
function CoordinateMixin:Coordinate_HasLocalSystem ()
	return self[_lcs] ~= nil
end

--
--
--

--- DOCME
function CoordinateMixin:Coordinate_LocalToGlobal (x, y, how)
	local lcs = self[_lcs]

	if lcs then
    local cx, cy = lcs("origin")
    local rx, ry, ux, uy = lcs("axes") -- TODO? account for axes not normalized?

    if how == "use_ref" then
      local x0, y0 = lcs("ref")

      x, y = x - (x0 or 0), y - (y0 or 0)
    end

		x, y = cx + x * rx + y * ux, cy + x * ry + y * uy
  end

  return x, y
end

--
--
--

--- DOCME
function CoordinateMixin:Coordinate_SetLocalSystem (lcs)
	self[_lcs] = lcs
end

--
--
--

local Actions = { allow_add = "is_table" }

function Actions:add ()
	for k, v in pairs(CoordinateMixin) do
		self[k] = v
	end
end

function Actions:remove ()
	self[_lcs] = nil

	for k in pairs(CoordinateMixin) do
		self[k] = nil
	end
end

--
--
--

return component.RegisterType{ name = "coordinate", actions = Actions }