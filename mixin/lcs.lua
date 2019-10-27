--- Component that confers a local coordinate system on its owner.

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










--- DOCME
function M.GlobalToLocal (x, y, lcs)
	if lcs then
		local cx, cy, lx, ly, fx, fy, ux, uy = lcs()
		local dx, dy, flen2, ulen2 = x - lx, y - ly, fx^2 + fy^2, ux^2 + uy^2

		return cx + (dx * fx + dy * fy) / flen2, cy + (dx * ux + dy * uy) / ulen2
	else
		return x, y
	end
end

--- DOCME
function M.LocalToGlobal (x, y, lcs)
	if lcs then
		local cx, cy, lx, ly, fx, fy, ux, uy = lcs()
		local dx, dy = x - lx, y - ly

		return cx + dx * fx + dy * ux, cy + dx * fy + dy * uy
	else
		return x, y
	end
end