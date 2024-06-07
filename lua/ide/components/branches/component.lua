local base = require("ide.panels.component")
local tree = require("ide.trees.tree")
local git = require("ide.lib.git.client").new()
local libbuf = require("ide.lib.buf")
local libwin = require("ide.lib.win")
local libws = require("ide.lib.workspace")
local gitutil = require("ide.lib.git.client")
local branchnode = require("ide.components.branches.branchnode")
local commands = require("ide.components.branches.commands")
local logger = require("ide.logger.logger")
local icons = require("ide.icons")

local BranchesComponent = {}

local config_prototype = {
	default_height = nil,
	disabled_keymaps = false,
	hidden = false,
	keymaps = {
		expand = "zo",
		collapse = "zc",
		collapse_all = "zM",
		jump = "<CR>",
		create_branch = "c",
		refresh = "r",
		hide = "H",
		close = "X",
		details = "d",
		pull = "p",
		push = "P",
		set_upstream = "s",
		help = "?",
	},
}

-- BranchesComponent is a derived @Component implementing a tree of incoming
-- or outgoing calls.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
BranchesComponent.new = function(name, config)
	-- extends 'ide.panels.Component' fields.
	local self = base.new(name)

	-- a @Tree containing the current buffer's document symbols.
	self.tree = tree.new("branches")

	-- a logger that will be used across this class and its base class methods.
	self.logger = logger.new("branches")

	-- seup config, use default and merge in user config if not nil
	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	self.hidden = self.config.hidden

	self.refresh_aucmd = nil

	-- we register fs events for .git/HEAD and .git/refs/heads to identify when
	-- branches are modified or checked out.
	self.fsevents = {
		vim.loop.new_fs_event(),
		vim.loop.new_fs_event(),
	}

	-- the HEAD file is re-created each time a branch change occurs, which breaks
	-- the watch on the inode, must be recreated each time.
	local function register_head_fs_event()
		self.fsevents[1]:stop()
		self.fsevents[1] = vim.loop.new_fs_event()
		self.fsevents[1]:start(
			vim.fn.fnamemodify(".git/HEAD", ":p"),
			{},
			vim.schedule_wrap(function()
				if not libws.is_current_ws(self.workspace) then
					return
				end
				if libbuf.is_regular_buffer(0) then
					self.get_branches()
				end
				register_head_fs_event()
			end)
		)
	end

	register_head_fs_event()

	-- watching on the heads/ directory, so no special case like above.
	self.fsevents[2]:start(
		vim.fn.fnamemodify(".git/refs/heads", ":p"),
		{},
		vim.schedule_wrap(function()
			if not libws.is_current_ws(self.workspace) then
				return
			end
			if libbuf.is_regular_buffer(0) then
				self.get_branches()
			end
		end)
	)

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
				self.config.keymaps.jump,
				function()
					self.jump_branchnode({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.create_branch,
				function()
					self.create_branch()
				end,
			},
			{
				self.config.keymaps.refresh,
				function()
					self.get_branches()
				end,
			},
			{
				self.config.keymaps.hide,
				function()
					self.hide()
				end,
			},
			{
				self.config.keymaps.details,
				function()
					self.details()
				end,
			},
			{
				self.config.keymaps.pull,
				function()
					self.pull_branch()
				end,
			},
			{
				self.config.keymaps.push,
				function()
					self.push_branch()
				end,
			},
			{
				self.config.keymaps.set_upstream,
				function()
					self.set_upstream()
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
		if self.tree.root == nil then
			self.get_branches()
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
		log = self.logger.logger_from(nil, "Component.get_commands")
		return commands.new(self).get()
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
		local log = self.logger.logger_from("Branches", "Component.collapse")
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
		local log = self.logger.logger_from("Branches", "Component.collapse_all")
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

	function self.details(args)
		local log = self.logger.logger_from("Branches", "Component.details")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		if node.depth == 0 then
			return
		end

		node.details()
	end

	function self.get_branches()
		git.if_in_git_repo(function()
			local cur_tab = vim.api.nvim_get_current_tabpage()
			local repo = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
			if self.workspace.tab ~= cur_tab then
				return
			end
			git.branch(function(branches)
				if branches == nil or #branches == 0 then
					return
				end
				local children = {}
				for _, branch in ipairs(branches) do
					local node = branchnode.new(branch.sha, branch.branch, branch.is_head)
					node.remote = branch.remote
					node.remote_branch = branch.remote_branch
					node.remote_ref = branch.remote_ref
					node.tracking = branch.tracking
					if node.is_head then
						table.insert(children, 1, node)
					else
						table.insert(children, node)
					end
				end
				local root = branchnode.new("", repo, false, 0)
				self.tree.add_node(root, children)
				self.tree.marshal({ no_guides_leafs = true, virt_text_pos = "eol" })
			end)
		end)
	end

	function self.jump_branchnode(args)
		log = self.logger.logger_from(nil, "Component.jump_branchnode")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		git.checkout(node.branch, function()
			self.get_branches()
			local commits = self.workspace.search_component("Commits")
			if commits ~= nil then
				commits.component.get_commits()
			end
		end)
	end

	function self.create_branch(args)
		if not gitutil.in_git_repo() then
			vim.notify("Must be in a git repo to create a branch", vim.log.levels.ERROR, {
				title = "Branches",
			})
			return
		end

		vim.ui.input({
			prompt = "Enter a branch name: ",
		}, function(branch)
			if branch == nil or branch == "" then
				return
			end
			git.checkout_branch(branch, function(ok)
				self.get_branches()
			end)
		end)
	end

	function self.pull_branch(args)
		if not gitutil.in_git_repo() then
			vim.notify("Must be in a git repo to create a branch", vim.log.levels.ERROR, {
				title = "Branches",
			})
			return
		end

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		if node.remote == "" or node.remote == nil then
			vim.notify(
				"Local branch is not tracking remote branch.\nPlease push the local branch to a remote",
				vim.log.levels.INFO,
				{
					title = "Branches",
				}
			)
			return
		end

		git.pull(node.remote, node.remote_branch, function(success)
			if success == nil then
				return
			end
			self.get_branches()
			vim.notify(
				string.format("Pulled latest branch: %s from remote: %s", node.branch, node.remote),
				vim.log.levels.INFO,
				{
					title = "Branches",
				}
			)
		end)
	end

	function self.push_branch(args)
		if not gitutil.in_git_repo() then
			vim.notify("Must be in a git repo to create a branch", vim.log.levels.ERROR, {
				title = "Branches",
			})
			return
		end

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		local function push(remote, remote_branch, cb)
			git.push(remote, remote_branch, function(success)
				if success == nil then
					return
				end
				vim.notify(
					string.format("Pushed branch: %s to remote: %s", remote_branch, remote),
					vim.log.levels.INFO,
					{
						title = "Branches",
					}
				)
				self.get_branches()
				if cb ~= nil then
					cb()
				end
			end)
		end

		if node.remote == "" or node.remote == nil then
			vim.notify("Local branch does not belong to any remote", vim.log.levels.INFO, {
				title = "Branches",
			})
			git.remotes(function(remotes)
				vim.ui.select(remotes, { prompt = "Select a remote to push to" }, function(remote)
					push(remote, node.branch, function()
						git.set_upstream(node.branch, string.format("%s/%s", remote, node.branch), function()
							vim.notify(
								string.format(
									"Local branch %s set to track upstream %s/%s",
									node.branch,
									remote,
									node.branch
								),
								vim.log.levels.INFO,
								{
									title = "Branches",
								}
							)
						end)
					end)
				end)
			end)
			return
		end
		push(node.remote, node.remote_branch)
	end

	function self.set_upstream(args, node)
		if not gitutil.in_git_repo() then
			vim.notify("Must be in a git repo to create a branch", vim.log.levels.ERROR, {
				title = "Branches",
			})
			return
		end

		if not node then
			node = self.tree.unmarshal(self.state["cursor"].cursor[1])
			if node == nil then
				return
			end
		end

		vim.ui.input({
			prompt = "Set upstream to (remote/branch): ",
			default = "origin/" .. node.branch,
		}, function(input)
			if input == nil or input == "" then
				return
			end
			git.set_upstream(node.branch, input, function(resp)
				if resp ~= nil then
					self.get_branches()
				end
			end)
		end)
	end

	self.refresh_aucmd = vim.api.nvim_create_autocmd({ "BufEnter" }, {
		callback = function()
			if not libws.is_current_ws(self.workspace) then
				return
			end
			if libbuf.is_regular_buffer(0) then
				self.get_branches()
			end
		end,
	})

	return self
end

return BranchesComponent
