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
local sqrt = math.sqrt

-- Modules --
local component = require("tektite_core.component")

-- Unique member keys --
local _lcs = {}

--
--
--

local CoordinateMixin = {}

--- DOCME
-- TODO: VERY unsure about this :P
function CoordinateMixin:Coordinate_GetComponents (x, y)
	local lcs = self[_lcs]

	if lcs then
		local cx, cy, lx, ly, rx, ry, ux, uy = lcs()
		local dx, dy, r2, u2 = x - cx, y - cy, rx^2 + ry^2, ux^2 + uy^2
		local s = (dx * rx + dy * ry) / r2
		local t = (dx * ux + dy * uy) / u2

		return lx + s * sqrt(r2), ly + t * sqrt(u2)
	else
		return x, y
	end
end

--- DOCME
function CoordinateMixin:Coordinate_GlobalToLocal (x, y)
	local lcs = self[_lcs]

	if lcs then
		local cx, cy, lx, ly, rx, ry, ux, uy = lcs()
		local dx, dy, rlen2, ulen2 = x - lx, y - ly, rx^2 + ry^2, ux^2 + uy^2

		return cx + (dx * rx + dy * ry) / rlen2, cy + (dx * ux + dy * uy) / ulen2
	else
		return x, y
	end
end

--- DOCME
function CoordinateMixin:Coordinate_HasLocalSystem ()
	return self[_lcs] ~= nil
end

--- DOCME
function CoordinateMixin:Coordinate_LocalToGlobal (x, y)
	local lcs = self[_lcs]

	if lcs then
		local cx, cy, lx, ly, rx, ry, ux, uy = lcs()
		local dx, dy = x - lx, y - ly

		return cx + dx * rx + dy * ux, cy + dx * ry + dy * uy
	else
		return x, y
	end
end

--- DOCME
function CoordinateMixin:Coordinate_SetLocalSystem (lcs)
	self[_lcs] = lcs
end

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

return component.RegisterType{ name = "coordinate", actions = Actions }