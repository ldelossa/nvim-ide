local node = require("ide.trees.node")
local icons = require("ide.icons")
local gitutil = require("ide.lib.git.client")
local git = require("ide.lib.git.client").new()
local libpopup = require("ide.lib.popup")

local BranchNode = {}

BranchNode.new = function(sha, branch, is_head, depth)
	-- extends 'ide.trees.Node' fields.

	local key = string.format("%s:%s", sha, branch)
	local self = node.new("git_branch", branch, key, depth)

	self.sha = sha
	self.branch = branch
	self.is_head = is_head

	if self.depth == 0 then
		self.expanded = true
	end

	-- Marshal a branchnode into a buffer line.
	--
	-- @return: @icon - @string, icon used for call hierarchy item
	--          @name - @string, the name of the call hierarchy item
	--          @details - @string, the details of the call hierarchy item
	function self.marshal()
		local icon = icons.global_icon_set.get_icon("GitBranch")
		local name = string.format("%s", self.branch)
		local detail = ""

		-- root is the file we are displaying the timeline for.
		if self.depth == 0 then
			icon = icons.global_icon_set.get_icon("GitRepo")
			return icon, name, detail
		end

		if self.is_head then
			name = "* " .. name
		end

		if self.remote_ref ~= nil and self.remote_ref ~= "" then
			detail = self.remote_ref
		else
			detail = "~untracked"
		end

		if self.tracking ~= "" then
			if self.tracking == "ahead" then
				detail = detail .. " ↑"
			end
			if self.tracking == "behind" then
				detail = detail .. " ↓"
			end
			if self.tracking == "diverged" then
				detail = detail .. " ↑" .. "↓"
			end
		end

		return icon, name, detail, ""
	end

	function self.details()
		git.log(self.sha, 1, function(commits)
			local commit = commits[1]
			local lines = {}
			local head = " "
			if self.is_head then
				head = "(HEAD)"
			end
			local remote_ref = self.remote_ref
			if self.remote_ref == nil and self.remote_ref == "" then
				remote_ref = "~untracked"
			end
			table.insert(
				lines,
				string.format("%s %s %7s [%s] %s", head, self.branch, gitutil.short_sha(self.sha), remote_ref, commit.subject)
			)
			libpopup.until_cursor_move(lines)
		end)
	end

	return self
end

return BranchNode
