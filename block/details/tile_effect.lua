--- Implementation behind effects that interact with the tileset.

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

-- Exports --
local M = {}

--
--
--

-- Standard library imports --
local pairs = pairs
local setmetatable = setmetatable

-- Modules --
local args = require("iterator_ops.args")
local tilesets = require("s3_utils.tilesets")

-- Solar2D globals --
local graphics = graphics

--
--
--

local function NewEffect (name, tile_shader)
	local category, group, sname = name:match("(%a+)%.([_%a][_%w]*)%.([_%a][_%w]*)")
	local mp_name = ("%s_%s"):format(sname, tile_shader:gsub("%.", "__"))
	local mp_effect = { category = category, group = group, name = mp_name }

	mp_effect.graph = {
		nodes = {
			tile = { effect = tile_shader, input1 = "paint1" },
			[sname] =  { effect = name, input1 = "tile" },
		},
		output = sname
	}

	graphics.defineEffect(mp_effect)

	return category .. "." .. group .. "." .. mp_name
end

--- DOCME
-- N.B. takes ownership of names
function M.NewMapping (names)
	local mapping = {
		__index = function(t, shader)
			local mnames = { m_multipass = true, m_vertex_data_cache = {} }

			for k, v in pairs(names) do
				mnames[k] = NewEffect(v, shader)
			end

			t[shader] = mnames

			return mnames
		end
	}

	return setmetatable(mapping, mapping)
end

--- DOCME
function M.GetNames (names, mapping, shader)
	local mnames = mapping[shader]

	if mnames then
		local vertex_data_cache = mnames.m_vertex_data_cache

		for i, name in args.Args(tilesets.GetVertexDataNames()) do
			if name and i <= 4 then
				vertex_data_cache[name] = 0
			end
		end

		return mnames
	else
		return names
	end
end

local function CacheTileVertexData (tile, vertex_data_cache)
	if vertex_data_cache then
		local basic, fill = not tile.m_augmented, tile.fill
		local effect = basic and fill.effect or fill.effect.tile

		for k in pairs(vertex_data_cache) do
			vertex_data_cache[k] = effect[k]
		end

		tile.m_augmented = true
	end
end

--- DOCME
function M.AttachEffect (names, tile, what)
	local fill = tile.fill

	CacheTileVertexData(tile, names.vertex_data_cache)

	fill.effect = names[what]

	if names.m_multipass then
		local tile = fill.effect.tile

		for k, v in pairs(names.m_vertex_data_cache) do
			tile[k] = v
		end

		return fill.effect[what]
	else
		return fill.effect
	end
end

return M