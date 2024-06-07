local base = require("ide.panels.component")
local commands = require("ide.components.bookmarks.commands")
local logger = require("ide.logger.logger")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local icons = require("ide.icons")
local notebook = require("ide.components.bookmarks.notebook")
local base64 = require("ide.lib.encoding.base64")

local BookmarksComponent = {}

BookmarksComponent.NotebooksPath = vim.fn.stdpath("config") .. "/bookmarks"

local config_prototype = {
	default_height = nil,
	disabled_keymaps = false,
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
		remove_bookmark = "D",
	},
}

-- BookmarksComponent is a derived @Component implementing a file explorer.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
BookmarksComponent.new = function(name, config)
	-- extends 'ide.panels.Component' fields.
	local self = base.new(name)

	-- a logger that will be used across this class and its base class methods.
	self.logger = logger.new("bookmarks")

	-- seup config, use default and merge in user config if not nil
	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	self.hidden = true

	-- the currently opened notebook containing bookmarks
	self.notebook = nil

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
					self.jump_bookmarknode({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.jump_tab,
				function()
					self.jump_bookmarknode({ fargs = { "tab" } })
				end,
			},
			{
				self.config.keymaps.jump_split,
				function()
					self.jump_bookmarknode({ fargs = { "split" } })
				end,
			},
			{
				self.config.keymaps.jump_vsplit,
				function()
					self.jump_bookmarknode({ fargs = { "vsplit" } })
				end,
			},
			{
				self.config.keymaps.remove_bookmark,
				function()
					self.remove_bookmark()
				end,
			},
			{
				self.config.keymaps.details,
				function()
					self.details()
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

	-- implements @Component.open()
	function self.open()
		return self.buf
	end

	-- implements @Component interface
	function self.post_win_create()
		local log = self.logger.logger_from(nil, "Component.post_win_create")
		icons.global_icon_set.set_win_highlights()
	end

	function self.expand(args)
		local log = self.logger.logger_from(nil, "Component.expand")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.notebook.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.notebook.tree.expand_node(node)
		self.notebook.tree.marshal({ no_guides_leaf = true })
		self.state["cursor"].restore()
	end

	function self.collapse(args)
		local log = self.logger.logger_from(nil, "Component.collapse")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.notebook.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.notebook.tree.collapse_node(node)
		self.notebook.tree.marshal({ no_guides_leaf = true })
		self.state["cursor"].restore()
	end

	function self.collapse_all(args)
		local log = self.logger.logger_from(nil, "Component.collapse_all")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.notebook.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.notebook.tree.collapse_subtree(self.notebook.tree.root)
		self.notebook.tree.marshal({ no_guides_leaf = true })
		self.state["cursor"].restore()
	end

	function self.jump_bookmarknode(args)
		log = self.logger.logger_from(nil, "Component.jump_bookmarknode")

		local node = self.notebook.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		local split = false
		local vsplit = false
		local tab = false
		for _, arg in ipairs(args.fargs) do
			if arg == "split" then
				split = true
			end
			if arg == "vsplit" then
				vsplit = true
			end
			if arg == "tab" then
				tab = true
			end
		end

		local win = self.workspace.get_win()
		vim.api.nvim_set_current_win(win)
		if split then
			vim.cmd("split")
			win = 0
		elseif vsplit then
			vim.cmd("vsplit")
			win = 0
		elseif tab then
			vim.cmd("tabnew")
			win = 0
		end

		vim.api.nvim_set_current_win(win)
		vim.cmd("edit " .. node.file)
		libwin.safe_cursor_restore(0, { node.start_line, 1 })
	end

	function self.get_commands()
		local log = self.logger.logger_from(nil, "Component.get_commands")
		return commands.new(self).get()
	end

	-- notebook functions --

	local function _get_notebooks_dir()
		local project_dir = vim.fn.getcwd()
		local project_sha = base64.encode(project_dir)
		local notebook_dir = vim.fn.fnamemodify(BookmarksComponent.NotebooksPath, ":p") .. "/" .. project_sha
		local exists = false
		if vim.fn.isdirectory(notebook_dir) ~= 0 then
			exists = true
		end
		return notebook_dir, exists
	end

	local function _ls_notebooks()
		local notebooks_dir, exists = _get_notebooks_dir()
		if not exists then
			return {}
		end
		local notebooks = vim.fn.readdir(notebooks_dir)
		return notebooks
	end

	function self.open_notebook(args, name)
		local notebooks = _ls_notebooks()
		local on_choice = function(item)
			local notebooks_dir = _get_notebooks_dir()
			local notebook_file = notebooks_dir .. "/" .. item
			local name = vim.fn.fnamemodify(item, ":t")
			if self.notebook ~= nil then
				self.notebook.close()
			end
			self.notebook = notebook.new(self.buf, name, notebook_file, self)
			self.focus()
		end

		if name ~= nil then
			for _, notebook in ipairs(notebooks) do
				if name == notebook then
					on_choice(name)
					return
				end
			end
			return
		end

		vim.ui.select(notebooks, {
			prompt = "Select a notebook to open: ",
			format_item = function(item)
				return vim.fn.fnamemodify(item, ":r")
			end,
		}, on_choice)
	end

	function self.remove_notebook(args, name)
		local notebooks = _ls_notebooks()
		local on_choice = function(item)
			local notebooks_dir = _get_notebooks_dir()
			local notebook_file = notebooks_dir .. "/" .. item
			local name = vim.fn.fnamemodify(item, ":t")
			if self.notebook ~= nil then
				self.notebook.close()
			end
			vim.fn.delete(notebook_file, "rf")
		end

		if name ~= nil then
			for _, notebook in ipairs(notebooks) do
				if name == notebook then
					on_choice(name)
					return
				end
			end
			return
		end

		vim.ui.select(notebooks, {
			prompt = "Select a notebook to open: ",
			format_item = function(item)
				return vim.fn.fnamemodify(item, ":r")
			end,
		}, on_choice)
	end

	function self.create_notebook(args)
		local on_confirm = function(name)
			if name == nil or name == "" then
				return
			end
			-- get notebook directory for current project, create if not exists.
			local notebook_dir, exists = _get_notebooks_dir()
			if not exists then
				vim.fn.mkdir(notebook_dir)
			end
			-- create notebook file
			local notebook_file = notebook_dir .. "/" .. name
			vim.fn.mkdir(notebook_file)
			-- open it
			self.open_notebook(nil, name)
		end
		vim.ui.input({
			prompt = "Name this notebook: ",
		}, on_confirm)
	end

	-- bookmark functions --

	function self.create_bookmark(args)
		if self.notebook == nil then
			vim.notify("A notebook must be opened first.", vim.log.levels.Error, {
				title = "Bookmarks",
			})
			return
		end
		self.notebook.create_bookmark(args)
	end

	function self.remove_bookmark(args)
		if self.notebook == nil then
			vim.notify("A notebook must be opened first.", vim.log.levels.Error, {
				title = "Bookmarks",
			})
			return
		end
		local node = self.notebook.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.notebook.remove_bookmark(node.key)
	end

	function self.details(args)
		local node = self.notebook.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		node.details()
	end

	return self
end

return BookmarksComponent
