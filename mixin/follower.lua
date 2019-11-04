--- Mixin for one object that follows another.

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
local assert = assert
local rawequal = rawequal
local pairs = pairs
local remove = table.remove

-- Extension imports --
local indexOf = table.indexOf

-- Modules --
local component = require("tektite_core.component")

-- Corona modules --
local display = display

-- Unique member keys --
local _followers = {}
local _leader = {}

--
--
--

local LeaderMixin = {}

--- DOCME
function LeaderMixin:Leader_GetFollowers (out)
    out = out or {}

    local list = self[_followers] or {}
    local n = #list

    for i = 1, n do
        out[i] = list[i]
    end

    return list, n
end

local Followers

local function RemoveFromLeader (follower)
    local leader, index = follower[_leader]

    if display.isValid(leader) then
        local list = leader[_followers]

        index = list and indexOf(list, follower)

        if index then
            local n = #list

            list[index] = list[n]
            list[n] = nil

            if n == 1 then -- now empty?
                Followers = Followers or {}
                Followers[#Followers + 1], leader[_followers] = list

                leader.Leader_GetFollowers = nil
            end
        end
    end

    follower[_leader] = nil

    return index ~= nil -- anything to remove?
end

local function OnFinalize (event)
    RemoveFromLeader(event.target)
end

local FollowerMixin = {}

--- DOCME
function FollowerMixin:Follower_GetLeader ()
    local leader = self[_leader]

    return display.isValid(leader) and leader or nil
end

--- DOCME
function FollowerMixin:Follower_StartFollowing (leader)
    assert(not rawequal(self, leader), "May not follow self")

    if display.isValid(leader) and not rawequal(self[_leader], leader) then
        local had_leader = RemoveFromLeader(self)
        local list = leader[_followers]

        if not list then
            list = Followers and remove(Followers) or {} -- fallthrough if empty
            leader[_followers] = list

            leader.Leader_GetFollowers = LeaderMixin.Leader_GetFollowers
        end

        list[#list + 1], self[_leader] = self, leader

        if not had_leader then
            self:addEventListener("onFinalize", OnFinalize)
        end
    end
end

--- DOCME
function FollowerMixin:Follower_StopFollowing ()
    if RemoveFromLeader(self) then
        self:removeEventListener("OnFinalize", OnFinalize)
    end
end

local Actions = { allow_add = "is_table" }

function Actions:add ()
	for k, v in pairs(FollowerMixin) do
		self[k] = v
	end
end

function Actions:remove ()
    self:Follower_StopFollowing()

	for k, v in pairs(FollowerMixin) do
		self[k] = v
	end
end

return component.RegisterType{ name = "follower", actions = Actions }