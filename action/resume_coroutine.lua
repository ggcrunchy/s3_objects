--- Start or resume a coroutine.

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
local create = coroutine.create
local pairs = pairs
local resume = coroutine.resume
local running = coroutine.running
local status = coroutine.status
local type = type

-- Modules --
local bind = require("corona_utils.bind")
local object_vars = require("config.ObjectVariables")
local store = require("s3_utils.state.store")

--
--
--

local Events = {}

for _, name in ipairs{ "on_start", "on_resuming", "on_restarting", "on_suspend", "on_done", "on_already_running", "on_resume_when_dead", "on_error" } do
	Events[name] = bind.BroadcastBuilder_Helper(nil)
end

local OutProperties = {
	boolean = {
		-- Dead --
		dead = function(resume_coro)
			return function()
				return resume_coro("coro") == "dead"
			end
		end,

		-- Normal --
		normal = function(resume_coro)
			return function()
				local coro = resume_coro("coro")

				return type(coro) == "thread" and status(coro) == "normal"
			end
		end,

		-- Running --
		running = function(resume_coro)
			return function()
				local coro = resume_coro("coro")

				return coro ~= nil and coro == running()
			end
		end,

		-- Suspended --
		suspended = function(resume_coro)
			return function()
				local coro = resume_coro("coro")

				return coro == nil or (coro ~= "dead" and status(coro) == "suspended")
			end
		end
	},

	family = {
		-- Local Vars --
		local_vars = function(resume_coro)
			return function()
				local coro = resume_coro("coro")

				return coro ~= "dead" and coro or nil
			end
		end
	},

	string = {
		-- Last Error --
		last_error = function(resume_coro)
			return function()
				local _, last_err = resume_coro("coro")

				return last_err or ""
			end
		end,

		-- Status --
		status = function(resume_coro)
			return function()
				local coro = resume_coro("coro")

				if coro == nil then
					return "suspended"
				elseif coro == "dead" then
					return "dead"
				else
					return status(coro)
				end
			end
		end
	}
}

local function LinkResume (resume_coro, other, rcsub, osub)
	local helper = bind.PrepLink(resume_coro, other, rcsub, osub)

	helper("try_events", Events)
	helper("try_out_properties", OutProperties)

	return helper("commit")
end

local function EditorEvent (what, arg1, _, arg3)
	-- Get Link Grouping --
	if what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "fire",
			{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "status", "last_error", "local_vars", "dead", "suspended", "normal", "running",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "on_start", "next", "on_resuming", "on_suspend", "on_done", "on_error", "on_restarting", "on_already_running", "on_resume_when_dead"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.dead = "BOOL: Is dead?"
		arg1.fire = "Resume or (re)start"
		arg1.last_error = "STR: Last error"
		arg1.local_vars = "FAM: Coroutine vars"
		arg1.normal = "BOOL: In progress?"
		arg1.on_already_running = "On(already running)"
		arg1.on_done = "On(done)"
		arg1.on_error = "On(errored out)"
		arg1.on_restarting = "On(about to restart)"
		arg1.on_resume_when_dead = "On(tried resuming when dead)"
		arg1.on_resuming = "On(about to resume)"
		arg1.on_start = "Coroutine body"
		arg1.on_suspend = "On(suspend)"
		arg1.running = "BOOL: Running now?"
		arg1.status = "STR: Coroutine status"
		arg1.suspended = "BOOL: Is suspended?"

	-- Get Tag --
	elseif what == "get_tag" then
		return "resume_coroutine"

	-- New Tag --
	elseif what == "new_tag" then
		return "extend", Events, nil, object_vars.UnfoldPropertyFunctionsAsTagReadyList(OutProperties)
		
	-- Prep Value Link --
	elseif what == "prep_link:action" then
		return LinkResume

	-- Verify --
	-- arg1: Verify block
	-- arg2: Values
	-- arg3: Representative object
	elseif what == "verify" then
		if not arg1.links:HasLinks(arg3, "on_start") then
			arg1[#arg1 + 1] = "Coroutine must have starting point(s)"
		end
	end
end

return function(info, wlist)
	if info == "editor_event" then
		return EditorEvent
	else
		local is_stale = object_vars.MakeStaleSessionPredicate(info.persist_across_reset)
		local can_restart, coro, last_err = info.can_restart

		local function resume_coro (what)
			if what == "coro" then
				return coro, last_err
			else
				local went_stale = is_stale()

				if went_stale or (coro == "dead" and can_restart) then
					coro, last_err = nil

					if not went_stale then
						Events.on_restarting(resume_coro)
					end
				end

				coro = coro or create(function()
					return Events.on_start(resume_coro)
				end)

				local cstatus = status(coro)

				if cstatus == "suspended" then
					Events.on_resuming(resume_coro)

					local ok, res = resume(coro)

					if status(coro) == "suspended" then
						return Events.on_suspend(resume_coro)
					elseif not ok then
						last_err = res
					end

					store.RemoveFamily(coro)

					coro = "dead"

					return Events[ok and "on_done" or "on_error"](resume_coro)
				else
					return Events[cstatus == "normal" and "on_already_running" or "on_resume_when_dead"](resume_coro)
				end
			end
		end

		for k, v in pairs(Events) do
			v.Subscribe(resume_coro, info[k], wlist)
		end

		object_vars.PublishProperties(info.props, OutProperties, info.uid, container)

		return resume_coro
	end
end