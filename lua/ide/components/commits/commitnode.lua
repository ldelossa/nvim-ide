local node = require("ide.trees.node")
local icons = require("ide.icons")
local logger = require("ide.logger.logger")
local git = require("ide.lib.git.client").new()
local libpopup = require("ide.lib.popup")

local CommitNode = {}

CommitNode.new = function(sha, file, subject, author, date, tags, depth)
	-- extends 'ide.trees.Node' fields.

	local key = string.format("%s:%s:%s:%s:%s", sha, file, subject, author, date)
	local self = node.new("git_commit", sha, sha, depth)

	-- CommitNodes make a list, not a tree, so just always expand and we'll set
	-- the tree to marshal with no leave guides.
	self.expanded = true
	self.sha = sha
	self.file = file
	self.subject = subject
	self.author = author
	self.date = date
	self.tags = tags
	self.is_file = false
	self.is_head = false

	-- all nodes start as collapsed.
	self.expanded = false
	if self.depth == 0 then
		self.expanded = true
	end

	-- Marshal a commitnode into a buffer line.
	--
	-- @return: @icon - @string, icon used for call hierarchy item
	--          @name - @string, the name of the call hierarchy item
	--          @details - @string, the details of the call hierarchy item
	function self.marshal()
		local icon = icons.global_icon_set.get_icon("GitCommit")
		if self.author == "" then
			icon = icons.global_icon_set.get_icon("File")
		end
		if self.depth == 0 then
			icon = icons.global_icon_set.get_icon("GitRepo")
		end

		local name = string.format("%s", self.subject)
		if self.is_head and self.depth ~= 0 and not self.is_file then
			name = "* " .. name
		end
		local detail = string.format("%s %s", self.author, self.date)
		if self.tags then
			detail = string.format("%s %s %s", self.tags, self.author, self.date)
		end
		if self.is_file then
			return icon, name, detail, ""
		end

		return icon, name, detail
	end

	function self.details(tab)
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
			if (self.tags) then
				table.insert(lines, string.format("%s%s", icons.global_icon_set.get_icon("GitCommit"), self.tags))
			end
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

			if tab then
				vim.cmd("tabnew")
				local buf = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
				vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)
				vim.api.nvim_buf_set_option(buf, "modifiable", false)
				vim.api.nvim_buf_set_name(buf, commit.sha .. " details")
				return
			end

			libpopup.until_cursor_move(lines)
		end)
	end

	function self.expand(cb)
		if self.is_file then
			return
		end
		git.show_rev_paths(self.sha, function(paths)
			if self.depth == 0 then
				self.expanded = true
				return
			end
			local children = {}
			for _, path in ipairs(paths) do
				local file = CommitNode.new(path.rev, path.path, path.path, "", "")
				file.is_file = true
				table.insert(children, file)
			end
			self.tree.add_node(self, children)
			self.expanded = true
			if cb ~= nil then
				cb()
			end
		end)
	end

	return self
end

return CommitNode
