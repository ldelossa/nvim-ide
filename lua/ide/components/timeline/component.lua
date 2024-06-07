local base = require("ide.panels.component")
local tree = require("ide.trees.tree")
local ds_buf = require("ide.buffers.doomscrollbuffer")
local diff_buf = require("ide.buffers.diffbuffer")
local git = require("ide.lib.git.client").new()
local gitutil = require("ide.lib.git.client")
local timelinenode = require("ide.components.timeline.timelinenode")
local commands = require("ide.components.timeline.commands")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local logger = require("ide.logger.logger")
local icons = require("ide.icons")

local TimelineComponent = {}

local config_prototype = {
	default_height = nil,
	disabled_keymaps = false,
	hidden = false,
	keymaps = {
		close = "X",
		collapse = "zc",
		collapse_all = "zM",
		details = "d",
		expand = "zo",
		help = "?",
		hide = "H",
		jump = "<CR>",
		jump_split = "s",
		jump_tab = "t",
		jump_vsplit = "v",
	},
}

-- TimelineComponent is a derived @Component implementing a tree of incoming
-- or outgoing calls.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
TimelineComponent.new = function(name, config)
	-- extends 'ide.panels.Component' fields.
	local self = base.new(name)

	-- a @Tree containing the current buffer's document symbols.
	self.tree = tree.new("timeline")

	-- a logger that will be used across this class and its base class methods.
	self.logger = logger.new("timeline")

	-- seup config, use default and merge in user config if not nil
	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	self.hidden = self.config.hidden

	-- a map of file names to the number of commits to skip to obtain the next
	-- page.
	self.paging = {}

	-- keep track of last created timeline, and don't refresh listing
	self.last_timeline = ""

	-- The callback used to load more git commits into the Timeline when the
	-- bottom of the buffer is hit.
	function self.doomscroll(Buffer)
		if self.tree.root == nil then
			return
		end
		local name = self.tree.root.subject
		if name == nil or name == "" then
			return
		end
		vim.notify("loading more commits...", vim.log.levels.INFO, {
			title = "Timeline",
		})
		git.log_file_history(name, self.paging[name], 25, function(commits)
			if commits == nil then
				return
			end
			if #commits == 0 then
				return
			end
			local children = {}
			for _, commit in ipairs(commits) do
				local node = timelinenode.new(commit.sha, name, commit.subject, commit.author, commit.date)
				table.insert(children, node)
			end
			self.tree.add_node(self.tree.root, children, { append = true })
			self.tree.marshal({ no_guides = true, virt_text_pos = "eol" })
			if #children > 0 then
				self.paging[name] = self.paging[name] + 25
			end
			self.state["cursor"].restore()
		end)
	end

	-- Use a doomscrollbuffer to load more commits when the cursor hits
	-- the bottom of the buffer.
	self.buffer = ds_buf.new(self.doomscroll, nil, false, true)

	local function setup_buffer()
		local log = self.logger.logger_from(nil, "Component._setup_buffer")
		local buf = self.buffer.buf

		vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(buf, "filetype", "filetree")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_option(buf, "textwidth", 0)
		vim.api.nvim_buf_set_option(buf, "wrapmargin", 0)

		local keymaps = {
			{
				key = self.config.keymaps.expand,
				cb = function()
					self.expand()
				end,
			},
			{
				key = self.config.keymaps.collapse,
				cb = function()
					self.collapse()
				end,
			},
			{
				key = self.config.keymaps.collapse_all,
				cb = function()
					self.collapse_all()
				end,
			},
			{
				key = self.config.keymaps.jump,
				cb = function()
					self.jump_timelinenode({ fargs = {} })
				end,
			},
			{
				key = self.config.keymaps.jump_tab,
				cb = function()
					self.jump_timelinenode({ fargs = { "tab" } })
				end,
			},
			{
				key = self.config.keymaps.hide,
				cb = function()
					self.hide()
				end,
			},
			{
				key = self.config.keymaps.details,
				cb = function()
					self.details()
				end,
			},
			{
				key = self.config.keymaps.help,
				cb = function()
					self.help_keymaps()
				end,
			},
		}

		if not self.config.disable_keymaps then
			for _, keymap in ipairs(keymaps) do
				libbuf.set_keymap_normal(buf, keymap.key, keymap.cb)
			end
		end

		return buf
	end

	self.buf = setup_buffer()

	self.tree.set_buffer(self.buf)

	-- implements @Component.open()
	function self.open()
		if self.tree.root ~= nil then
			self.tree.marshal({ no_guides = true, virt_text_pos = "eol" })
		end
		return self.buf
	end

	-- implements @Component interface
	function self.post_win_create()
		local log = self.logger.logger_from(nil, "Component.post_win_create")
		icons.global_icon_set.set_win_highlights()
	end

	-- implements @Component interface
	function self.get_commands()
		local log = self.logger.logger_from(nil, "Component.get_commands")
		return commands.new(self).get()
	end

	-- implements optional @Component interface
	-- Expand the @CallNode at the current cursor location
	--
	-- @args - @table, user command table as described in ":h nvim_create_user_command()"
	-- @timelinenode - @CallNode, an override which expands the given @CallNode, ignoring the
	--          node under the current position.
	function self.expand(args, timelinenode)
		local log = self.logger.logger_from(nil, "Component.expand")
		if not libwin.win_is_valid(self.win) then
			return
		end
		if timelinenode == nil then
			timelinenode = self.tree.unmarshal(self.state["cursor"].cursor[1])
			if timelinenode == nil then
				return
			end
		end
		timelinenode.expand()
		self.tree.marshal({ no_guides = true, virt_text_pos = "eol" })
		self.state["cursor"].restore()
	end

	-- Collapse the @CallNode at the current cursor location
	--
	-- @args - @table, user command table as described in ":h nvim_create_user_command()"
	-- @timelinenode - @CallNode, an override which collapses the given @CallNode, ignoring the
	--           node under the current position.
	function self.collapse(args, timelinenode)
		local log = self.logger.logger_from(nil, "Component.collapse")
		if not libwin.win_is_valid(self.win) then
			return
		end
		if timelinenode == nil then
			timelinenode = self.tree.unmarshal(self.state["cursor"].cursor[1])
			if timelinenode == nil then
				return
			end
		end
		self.tree.collapse_subtree(timelinenode)
		self.tree.marshal({ no_guides = true, virt_text_pos = "eol" })
		self.state["cursor"].restore()
	end

	-- Collapse the call hierarchy up to the root.
	--
	-- @args - @table, user command table as described in ":h nvim_create_user_command()"
	function self.collapse_all(args)
		local log = self.logger.logger_from(nil, "Component.collapse_all")
		if not libwin.win_is_valid(self.win) then
			return
		end
		if timelinenode == nil then
			timelinenode = self.tree.unmarshal(self.state["cursor"].cursor[1])
			if timelinenode == nil then
				return
			end
		end
		self.tree.collapse_subtree(self.tree.root)
		self.tree.marshal({ no_guides = true, virt_text_pos = "eol" })
		self.state["cursor"].restore()
	end

	function self.on_buf_enter()
		if not gitutil.repo_has_commits() then
			return
		end
		local cur_buf = vim.api.nvim_get_current_buf()
		local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(cur_buf), ":.")
		local cur_tab = vim.api.nvim_get_current_tabpage()
		if self.workspace.tab ~= cur_tab then
			return
		end
		if not libbuf.is_regular_buffer(cur_buf) then
			return
		end
		if not libbuf.is_in_workspace(cur_buf) then
			return
		end
		if libbuf.is_component_buf(cur_buf) then
			return
		end
		if name == nil or name == "" then
			return
		end
		-- don't reset the timeline if we didn't change files.
		if name == self.last_timeline then
			return
		end
		git.log_file_history(name, 0, 25, function(commits)
			if commits == nil then
				return
			end
			local children = {}
			for _, commit in ipairs(commits) do
				local node = timelinenode.new(commit.sha, name, commit.subject, commit.author, commit.date)
				table.insert(children, node)
			end
			local root = timelinenode.new("", "", name, "", "", 0)
			self.tree.add_node(root, children)
			self.tree.marshal({ no_guides = true, virt_text_pos = "eol" })
			self.paging[name] = 25
			self.last_timeline = name
		end)
	end

	function self.jump_timelinenode(args)
		local log = self.logger.logger_from(nil, "Component.jump_timelinenode")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		-- we need to find the parent node, but this is a list where all commits
		-- are at depth one,
		local _, i = self.tree.depth_table.search(1, node.key)
		if i == nil then
			error("failed to find index of node in depth table")
		end

		local pnode = self.tree.depth_table.table[1][i + 1]

		local function do_diff(file_a, file_b, sha_a, sha_b, path_a, path_b)
			local tab = false
			for _, arg in ipairs(args.fargs) do
				if arg == "tab" then
					tab = true
				end
			end

			if tab then
				vim.cmd("tabnew")
			end

			local buf_name_a = string.format("diff:///%d/%s/%s", vim.fn.rand(), sha_a, path_a)
			local buf_name_b = string.format("diff:///%d/%s/%s", vim.fn.rand(), sha_b, path_b)

			local dbuff = diff_buf.new()
			dbuff.setup()
			local o = { listed = false, scratch = true, modifiable = false }
			dbuff.write_lines(file_a, "a", o)
			dbuff.write_lines(file_b, "b", o)

			dbuff.buffer_a.set_name(buf_name_a)
			dbuff.buffer_b.set_name(buf_name_b)

			dbuff.diff()
		end

		-- we
		if pnode == nil then
			git.show_file(node.sha, node.file, function(file_b)
				if file_b == nil then
					return
				end
				do_diff({ "" }, file_b, "", node.sha, "", node.file)
				vim.api.nvim_set_current_win(self.win)
			end)
			return
		end

		git.show_file(pnode.sha, pnode.file, function(file_a)
			git.show_file(node.sha, node.file, function(file_b)
				if file_b == nil then
					return
				end
				do_diff(file_a, file_b, pnode.sha, node.sha, pnode.file, node.file)
				vim.api.nvim_set_current_win(self.win)
			end)
		end)
	end

	function self.details(args)
		log = self.logger.logger_from(nil, "Component.details")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		if node.depth == 0 then
			return
		end

		node.details()
	end

	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		callback = function()
			git.if_in_git_repo(self.on_buf_enter)
		end,
	})

	return self
end

return TimelineComponent
