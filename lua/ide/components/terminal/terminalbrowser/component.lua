local base = require("ide.panels.component")
local tree = require("ide.trees.tree")
local icons = require("ide.icons")
local libbuf = require("ide.lib.buf")
local termnode = require("ide.components.terminal.terminalbrowser.terminalnode")
local logger = require("ide.logger.logger")
local commands = require("ide.components.terminal.terminalbrowser.commands")

local TerminalBrowserComponent = {}

local config_prototype = {
	default_height = nil,
	disabled_keymaps = false,
	hidden = false,
	keymaps = {
		new = "n",
		jump = "<CR>",
		hide = "H",
		delete = "D",
		rename = "r",
	},
}

TerminalBrowserComponent.new = function(name, config)
	local self = base.new(name)
	self.tree = tree.new("terminals")
	-- a logger that will be used across this class and its base class methods.
	self.logger = logger.new("terminalbrowser")


	-- seup config, use default and merge in user config if not nil
	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	self.hidden = self.config.hidden

	local function setup_buffer()
		local buf = vim.api.nvim_create_buf(false, true)

		vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(buf, "filetype", "filetree")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_option(buf, "textwidth", 0)
		vim.api.nvim_buf_set_option(buf, "wrapmargin", 0)

		if not self.config.disable_keymaps then
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.new, "", {
				silent = true,
				callback = function()
					self.new_term()
				end,
			})
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.rename, "", {
				silent = true,
				callback = function()
					self.rename_term()
				end,
			})
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.jump, "", {
				silent = true,
				callback = function()
					self.jump()
				end,
			})
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.hide, "", {
				silent = true,
				callback = function()
					self.hide()
				end,
			})
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.delete, "", {
				silent = true,
				callback = function()
					self.delete_term()
				end,
			})
		end

		return buf
	end

	self.buf = setup_buffer()
	self.tree.set_buffer(self.buf)

	function self.refresh()
		local tc = self.workspace.search_component("Terminal")
		if tc == nil then
			return
		end
		local terms = tc.component.get_terms()
		local children = {}
		for _, term in ipairs(terms) do
			table.insert(children, termnode.new(term.id, term.name))
		end
		local root = termnode.new(0, "terminals", 0)
		self.tree.add_node(root, children)
		self.tree.marshal({ no_guides = true })
		if self.state["cursor"] ~= nil then
			self.state["cursor"].restore()
		end
	end

	function self.open()
		self.refresh()
		return self.buf
	end

	function self.post_win_create()
		local log = self.logger.logger_from(nil, "Component.post_win_create")
		icons.global_icon_set.set_win_highlights()
	end

	function self.new_term(args, name, command)
		local tc = self.workspace.search_component("Terminal")
		if tc == nil then
			return
		end
		local term = tc.component.new_term(name, command)
		self.refresh()
		local aucmd = nil
		aucmd = vim.api.nvim_create_autocmd({ "TermClose" }, {
			callback = function(e)
				if e.buf == term.buf and libbuf.buf_is_valid(e.buf) then
					tc.component.delete_term(term.id)
					self.refresh()
					vim.api.nvim_del_autocmd(aucmd)
				end
			end,
		})
	end

	function self.rename_term(args)
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		local tc = self.workspace.search_component("Terminal")
		if tc == nil then
			return
		end
		vim.ui.input({
			prompt = "Rename terminal to: ",
			default = node.name,
		}, function(name)
			if name == nil then
				return
			end
			local term = tc.component.get_term(node.id)
			term.name = name
			self.refresh()
			tc.component.set_term(term.id)
		end)
	end

	function self.delete_term(args)
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		local tc = self.workspace.search_component("Terminal")
		if tc == nil then
			return
		end
		tc.component.delete_term(node.id)
		self.refresh()
	end

	function self.jump(args)
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		local tc = self.workspace.search_component("Terminal")
		if tc == nil then
			return
		end
		tc.component.set_term(node.id)
	end

	function self.get_commands()
		log = self.logger.logger_from(nil, "Component.get_commands")
		return commands.new(self).get()
	end

	return self
end

return TerminalBrowserComponent
