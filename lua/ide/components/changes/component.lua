local base = require("ide.panels.component")
local tree = require("ide.trees.tree")
local commands = require("ide.components.changes.commands")
local logger = require("ide.logger.logger")
local diff_buf = require("ide.buffers.diffbuffer")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local libws = require("ide.lib.workspace")
local statusnode = require("ide.components.changes.statusnode")
local icons = require("ide.icons")
local git = require("ide.lib.git.client").new()
local gitutil = require("ide.lib.git.client")

local ChangesComponent = {}

local config_prototype = {
	default_height = nil,
	disabled_keymaps = false,
	hidden = false,
	keymaps = {
		add = "s",
		amend = "a",
		close = "X",
		collapse = "zc",
		collapse_all = "zM",
		commit = "c",
		details = "d",
		diff = "<CR>",
		diff_tab = "t",
		edit = "e",
		expand = "zo",
		help = "?",
		hide = "H",
		restore = "r",
	},
}

-- ChangesComponent is a derived @Component implementing a file explorer.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
ChangesComponent.new = function(name, config)
	-- extends 'ide.panels.Component' fields.
	local self = base.new(name)

	-- a @Tree containing the current buffer's document status.
	self.tree = tree.new("changes")

	-- a logger that will be used across this class and its base class methods.
	self.logger = logger.new("changes")

	-- a map between node node paths to statusnodes, used to determine if an
	-- unstaged node has a cooresponding staged node
	self.staged = {}

	self.unstaged = {}

	self.untracked = {}

	-- seup config, use default and merge in user config if not nil
	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	self.hidden = self.config.hidden

	local function setup_buffer()
		local log = self.logger.logger_from(nil, "Component._setup_buffer")
		local buf = vim.api.nvim_create_buf(false, true)

		vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(buf, "filetype", "filetree")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_option(buf, "textwidth", 0)
		vim.api.nvim_buf_set_option(buf, "wrapmargin", 0)

		local keymaps = {
			{
				self.config.keymaps.expand,
				function()
					self.expand()
				end,
			},
			{
				self.config.keymaps.collapse,
				function()
					self.collapse()
				end,
			},
			{
				self.config.keymaps.collapse_all,
				function()
					self.collapse_all()
				end,
			},
			{
				self.config.keymaps.restore,
				function()
					self.restore({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.add,
				function()
					self.add({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.amend,
				function()
					self.amend({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.commit,
				function()
					self.commit({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.edit,
				function()
					self.edit()
				end,
			},
			{
				self.config.keymaps.details,
				function()
					self.details()
				end,
			},
			{
				self.config.keymaps.diff,
				function()
					self.diff({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.diff_tab,
				function()
					self.diff({ fargs = { "tab" } })
				end,
			},
			{
				self.config.keymaps.hide,
				function()
					self.hide()
				end,
			},
			{
				self.config.keymaps.help,
				function()
					self.help_keymaps()
				end,
			},
		}

		if not self.config.disable_keymaps then
			for _, keymap in ipairs(keymaps) do
				libbuf.set_keymap_normal(buf, keymap[1], keymap[2])
			end
		end

		return buf
	end

	self.buf = setup_buffer()

	self.tree.set_buffer(self.buf)

	-- implements @Component.open()
	function self.open()
		if self.tree.root ~= nil then
			self.tree.marshal({ no_guides_leaf = true, virt_text_pos = "right_align" })
		end
		return self.buf
	end

	-- implements @Component interface
	function self.post_win_create()
		local log = self.logger.logger_from(nil, "Component.post_win_create")

		-- setup web-dev-icons highlights if available
		if pcall(require, "nvim-web-devicons") then
			for _, icon_data in pairs(require("nvim-web-devicons").get_icons()) do
				local hl = "DevIcon" .. icon_data.name
				vim.cmd(string.format("syn match %s /%s/", hl, icon_data.icon))
			end
		end

		-- we can kick of an initial creation of the tree on load.
		self.event_handler(nil)

		icons.global_icon_set.set_win_highlights()
	end

	function self.expand(args)
		local log = self.logger.logger_from(nil, "Component.expand")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.tree.expand_node(node)
		self.tree.marshal({ no_guides_leaf = true, virt_text_pos = "right_align" })
		self.state["cursor"].restore()
	end

	function self.collapse(args)
		local log = self.logger.logger_from(nil, "Component.collapse")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.tree.collapse_node(node)
		self.tree.marshal({ no_guides_leaf = true, virt_text_pos = "right_align" })
		self.state["cursor"].restore()
	end

	function self.collapse_all(args)
		local log = self.logger.logger_from(nil, "Component.collapse_all")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.tree.collapse_subtree(self.tree.root)
		self.tree.marshal({ no_guides_leaf = true, virt_text_pos = "right_align" })
		self.state["cursor"].restore()
	end

	local function _build_tree(stats)
		self.staged = (function()
			return {}
		end)()
		self.unstaged = (function()
			return {}
		end)()
		self.untracked = (function()
			return {}
		end)()

		local root = statusnode.new("", vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), false, 0)
		local staged = statusnode.new("", "Staged Changes", false)
		local unstaged = statusnode.new("", "Unstaged Changes", false)
		local untracked = statusnode.new("", "Untracked Changes", false)
		local children = { staged, unstaged, untracked }
		self.tree.add_node(root, children)

		for _, stat in ipairs(stats) do
			if stat.unstaged_status == "?" or stat.staged_status == "?" then
				local node = statusnode.new(stat.unstaged_status, stat.path, false)

				self.tree.add_node(untracked, { node }, { append = true })
				self.untracked[stat.path] = node

				goto continue
			end
			if stat.staged_status ~= " " then
				local node = statusnode.new(stat.staged_status, stat.path, true)
				self.tree.add_node(staged, { node }, { append = true })
				self.staged[stat.path] = node
			end
			if stat.unstaged_status ~= " " then
				local node = statusnode.new(stat.unstaged_status, stat.path, false)

				self.tree.add_node(unstaged, { node }, { append = true })
				self.unstaged[stat.path] = node
			end
			::continue::
		end

		self.tree.marshal({ no_guides_leaf = true, virt_text_pos = "right_align" })
		if self.is_displayed() then
			self.state["cursor"].restore()
		end
	end

	function self.event_handler(args)
		git.status(function(stats)
			if stats == nil then
				return
			end
			_build_tree(stats)
		end)
	end

	function self.add(args)
		log = self.logger.logger_from(nil, "Component.add")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		git.git_add(node.path, function()
			self.event_handler()
		end)
	end

	function self.restore(args)
		log = self.logger.logger_from(nil, "Component.restore")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		git.git_restore(node.staged, node.path, function()
			self.event_handler()
		end)
	end

	function self.commit(args)
		local term = self.workspace.search_component("TerminalBrowser")
		if term == nil then
			return
		end
		term.component.new_term(nil, "git commit", "/bin/bash -c 'git commit -s'")
		local aucmd = nil
		aucmd = vim.api.nvim_create_autocmd({ "TermClose" }, {
			callback = function()
				local commits = self.workspace.search_component("Commits")
				if commits ~= nil then
					commits.component.get_commits()
				end
				vim.api.nvim_del_autocmd(aucmd)
			end,
		})
	end

	function self.amend(args)
		local term = self.workspace.search_component("TerminalBrowser")
		if term == nil then
			return
		end
		term.component.new_term(nil, "git commit", "/bin/bash -c 'git commit --amend'")
		local aucmd = nil
		aucmd = vim.api.nvim_create_autocmd({ "TermClose" }, {
			callback = function()
				local commits = self.workspace.search_component("Commits")
				if commits ~= nil then
					commits.component.get_commits()
				end
				vim.api.nvim_del_autocmd(aucmd)
			end,
		})
	end

	function self.edit(args)
		local log = self.logger.logger_from(nil, "Component.edit")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		vim.api.nvim_set_current_win(self.workspace.get_win())
		vim.cmd("edit " .. node.path)
	end

	function self.details(args)
		local log = self.logger.logger_from(nil, "Component.details")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		if node.depth == 0 then
			return
		end

		node.details()
	end

	function self.diff(args)
		local log = self.logger.logger_from(nil, "Component.jump_statusnode")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		local tab = false
		for _, arg in ipairs(args.fargs) do
			if arg == "tab" then
				tab = true
			end
		end

		if tab then
			vim.cmd("tabnew")
		end

		if node.staged then
			git.show_file("HEAD~1", node.path, function(file_a)
				local dbuff = diff_buf.new()
				dbuff.setup()
				local o = { listed = false, scratch = true, modifiable = false }

				dbuff.write_lines(file_a, "a", o)
				local buf_name = "diff:///" .. vim.fn.rand() .. "/" .. "HEAD~1" .. "/" .. node.path
				dbuff.buffer_a.set_name(buf_name)

				-- if the file is staged, and there aren't any unstaged edits
				-- we can diff on an editable file on the file system.
				if self.untracked[node.path] == nil and self.unstaged[node.path] == nil then
					dbuff.open_buffer(node.path, "b")
					dbuff.diff()
					vim.api.nvim_set_current_win(self.win)
					return
				end

				-- otherwise, diff against the staging area directly since theres
				-- unstaged changes for this file.
				git.show_file(nil, node.path, function(file_b)
					dbuff.write_lines(file_b, "b", o)
					local buf_name = "diff:///" .. vim.fn.rand() .. "/" .. "STAGING" .. "/" .. node.path
					dbuff.buffer_b.set_name(buf_name)
					dbuff.diff()
					vim.notify("This file has unstaged changes, cannot modify diff", vim.log.levels.INFO, {
						title = "Changes",
					})
					vim.api.nvim_set_current_win(self.win)
				end, true)
			end)
			return
		end

		-- if its untracked make it look like a new file diff.
		if node.status == "?" or node.status == "A" then
			local dbuff = diff_buf.new()
			dbuff.setup()
			local o = { listed = false, scratch = true, modifiable = false }

			dbuff.write_lines({}, "a", o)
			local buf_name = "diff:///" .. vim.fn.rand() .. "/" .. "NOTFOUND" .. "/" .. node.path
			dbuff.buffer_a.set_name(buf_name)

			dbuff.open_buffer(node.path, "b")
			dbuff.diff()

			vim.api.nvim_set_current_win(self.win)
			return
		end

		-- if not staged, check if we need to diff against a staged version of
		-- ourselves
		if self.staged[node.path] ~= nil then
			git.show_file(nil, node.path, function(file)
				if file == nil then
					return
				end
				local dbuff = diff_buf.new()
				dbuff.setup()
				local o = { listed = false, scratch = true, modifiable = false }

				dbuff.write_lines(file, "a", o)
				local buf_name = "diff:///" .. vim.fn.rand() .. "/" .. "STAGING" .. "/" .. node.path
				dbuff.buffer_a.set_name(buf_name)

				dbuff.open_buffer(node.path, "b")
				dbuff.diff()

				vim.api.nvim_set_current_win(self.win)
			end, true)
			return
		end

		git.show_file("HEAD", node.path, function(file)
			if file == nil then
				return
			end
			local dbuff = diff_buf.new()
			dbuff.setup()
			local o = { listed = false, scratch = true, modifiable = false }

			dbuff.write_lines(file, "a", o)
			local buf_name = "diff:///" .. vim.fn.rand() .. "/" .. "HEAD~1" .. "/" .. node.path
			dbuff.buffer_a.set_name(buf_name)

			dbuff.open_buffer(node.path, "b")
			dbuff.diff()

			vim.api.nvim_set_current_win(self.win)
		end, node.staged)
	end

	function self.get_commands()
		local log = self.logger.logger_from(nil, "Component.get_commands")
		return commands.new(self).get()
	end

	vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold" }, {
		callback = function()
			if not self.is_displayed then
				return
			end

			if not libws.is_current_ws(self.workspace) then
				return
			end
			-- this really helps us avoid running in streaming buffers such as
			-- the log buffer.
			if not libbuf.is_regular_buffer(0) then
				return
			end
			git.if_in_git_repo(self.event_handler)
		end,
	})

	return self
end

return ChangesComponent
