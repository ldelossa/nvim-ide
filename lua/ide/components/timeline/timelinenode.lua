local node = require("ide.trees.node")
local icons = require("ide.icons")
local git = require("ide.lib.git.client").new()
local libpopup = require("ide.lib.popup")

local TimelineNode = {}

TimelineNode.new = function(sha, file, subject, author, date, depth)
	-- extends 'ide.trees.Node' fields.

	local self = node.new("git_commit", sha, sha, depth)

	-- TimelineNodes make a list, not a tree, so just always expand and we'll set
	-- the tree to marshal with no leave guides.
	self.expanded = true
	self.sha = sha
	self.file = file
	self.subject = subject
	self.author = author
	self.date = date

	-- Marshal a timelinenode into a buffer line.
	--
	-- @return: @icon - @string, icon used for call hierarchy item
	--          @name - @string, the name of the call hierarchy item
	--          @details - @string, the details of the call hierarchy item
	function self.marshal()
		local icon = icons.global_icon_set.get_icon("GitCommit")
		-- root is the file we are displaying the timeline for.
		if self.depth == 0 then
			icon = icons.global_icon_set.get_icon("File")
		end
		local name = string.format("%s", self.subject)
		local detail = string.format("%s %s", self.author, self.date)
		return icon, name, detail
	end

	function self.details()
		git.log(self.sha, 1, function(data)
			if data == nil then
				return
			end

			local commit = data[1]
			if commit == nil then
				return
			end

			local lines = {}
			table.insert(lines, string.format("%s %s", icons.global_icon_set.get_icon("GitCommit"), commit.sha))
			table.insert(lines, string.format("%s %s", icons.global_icon_set.get_icon("Account"), commit.author))
			table.insert(lines, string.format("%s %s", icons.global_icon_set.get_icon("Calendar"), commit.date))
			table.insert(lines, "")

			local subject = vim.fn.split(commit.subject, "\n")
			table.insert(lines, subject[1])

			table.insert(lines, "")

			local body = vim.fn.split(commit.body, "\n")
			for _, l in ipairs(body) do
				table.insert(lines, l)
			end

			libpopup.until_cursor_move(lines)
		end)
	end

	return self
end

return TimelineNode
