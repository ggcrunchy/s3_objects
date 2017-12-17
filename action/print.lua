--- Print a message.

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
local concat = table.concat
local pairs = pairs
local print = print
local tostring = tostring
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local bind = require("tektite_core.bind")

--
--
--

local Prefix = "get_"

local InProperties = {
	boolean = Prefix .. "bools",
	number = Prefix .. "nums",
	string = Prefix .. "strs"
}

local InPropertiesMulti = {}

for k, v in pairs(InProperties) do
	InPropertiesMulti[k] = v .. "+"
end

local LinkSuper

local function LinkPrint (print, other, psub, other_sub, links)
	local helper = bind.PrepLink(print, other, psub, other_sub)

	helper("try_in_properties", InProperties)

	if not helper("commit") then
		LinkSuper(print, other, psub, other_sub, links)
	end
end

local function Specifier (name, offset)
	offset = (offset or 0) + 1

	return "{" .. name:sub(offset, offset):upper() .. "}"
end

local function AddLinkInfo (info, name)
	info[Prefix .. name] = name:sub(1, -2):upper() .. ": Value(s) for " .. Specifier(name)
end

local function Find (message, name)
	local specifier = Specifier(name, #Prefix)

	return message:find(specifier, 1, true), specifier
end

local function EditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Action to build
	if what == "build" then
		for _, name in pairs(InProperties) do
			if not Find(arg2.message, name) then
				arg3[name] = nil
			end
		end

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.message = ""

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddString{ value_name = "message", before = "Message:" }

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "IN-PROPERTIES", font = "bold", color = "props" }, -- filled in automatically
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "next",
			{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "get_string"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.fire = "Print message"
		arg1.get_string = "STR: Resolved message"

		for _, name in pairs(InProperties) do
			AddLinkInfo(arg1, name:sub(#Prefix + 1))
		end

	-- Get Tag --
	elseif what == "get_tag" then
		return "print"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend_properties", { string = "get_string" }, InPropertiesMulti

	-- Prep Action Link --
	-- arg1: Parent handler
	elseif what == "prep_link:action" then
		LinkSuper = LinkSuper or arg1

		return LinkPrint

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		for vtype, name in pairs(InProperties) do
			local found, specifier = Find(arg2.message, name)

			if found and not arg1.links:HasLinks(arg3, name) then
				arg1[#arg1 + 1] = "`" .. specifier .. "` found without " .. vtype .. " value(s) to satisfy it"
			end
		end
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local message, values = info.message

		local function get_string (comp, arg)
			if comp then
				local specifier = Specifier(arg, #Prefix)

				values = values or {}
				values[specifier] = adaptive.Append(values[specifier], comp)
			else
				local resolved = message

				if values then
					for specifier, list in pairs(values) do
						local str

						for _, getter in adaptive.IterArray(list) do
							str = adaptive.Append(str, tostring(getter()))
						end

						if type(str) == "table" then
							str = "{" .. concat(str, ", ") .. "}"
						end

						resolved = resolved:gsub(specifier, str)
					end
				end

				return resolved
			end
		end

		for _, name in pairs(InProperties) do
			bind.Subscribe(wlist, info[name], get_string, name)
		end

		return function()
			print(get_string())
		end
	end
end