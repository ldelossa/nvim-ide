local base = require("ide.panels.component")
local commands = require("ide.components.terminal.commands")
local logger = require("ide.logger.logger")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")

local TerminalComponent = {}

local config_prototype = {
	default_height = nil,
	shell = nil,
	disabled_keymaps = false,
	keymaps = {},
}

TerminalComponent.new = function(name, config)
	local self = base.new(name)

	self.config = vim.deepcopy(config_prototype)

	self.terminals = {}

	self.counter = 1

	self.current_term = nil

	self.hidden = true

	self.shell = self.config.shell
	if self.shell == nil then
		self.shell = vim.fn.getenv("SHELL")
		if self.shell == nil or self.shell == "" then
			error("could not determine shell to use.")
		end
	end

	function self.open()
		if #self.terminals == 0 then
			return vim.api.nvim_create_buf(false, true)
		end
		return self.terminals[1].buf
	end

	-- implements @Component interface
	function self.post_win_create()
		local buf = vim.api.nvim_win_get_buf(0)
		local term = self.get_term_by_buf(buf)
		if term == nil then
			return
		end
		libwin.set_winbar_title(0, string.format("Terminal - %s", term.name))
	end

	function self.get_commands()
		log = self.logger.logger_from(nil, "Component.get_commands")
		return commands.new(self).get()
	end

	local opts = { noremap = true, silent = true }
	local function terminal_buf_setup(buf)
		vim.api.nvim_buf_set_keymap(buf, "t", "<C-w>n", "<C-\\><C-n>", opts)
		vim.api.nvim_buf_set_keymap(buf, "t", "<C-w>h", "<C-\\><C-n><C-w>h", opts)
		vim.api.nvim_buf_set_keymap(buf, "t", "<C-w>j", "<C-\\><C-n><C-w>j", opts)
		vim.api.nvim_buf_set_keymap(buf, "t", "<C-w>k", "<C-\\><C-n><C-w>k", opts)
		vim.api.nvim_buf_set_keymap(buf, "t", "<C-w>l", "<C-\\><C-n><C-w>l", opts)
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
	end

	function self.new_term(name, command)
		local buf = vim.api.nvim_create_buf(false, true)
		terminal_buf_setup(buf)

		if name == nil then
			name = self.shell
		end
		if command == nil then
			command = self.shell
		end

		term = {
			id = self.counter,
			buf = buf,
			name = name,
		}
		table.insert(self.terminals, term)

		-- focus ourselves so we can attach the new term
		self.focus()

		vim.api.nvim_win_set_buf(0, buf)
		vim.fn.termopen(command)
		self.set_term(term.id)
		vim.cmd("wincmd =")

		self.current_term = self.counter
		self.counter = self.counter + 1
		return term
	end

	function self.delete_term(id)
		local term = self.get_term(id)
		if term == nil then
			return
		end

		-- subtlety, do this before deleting the buffer so the TermClose aucmd
		-- TerminalBrowser uses doesn't try to delete the term as well
		-- (it will be missing from the inventory already.)
		local terms = {}
		for _, t in ipairs(self.terminals) do
			if t.id ~= id then
				table.insert(terms, t)
			end
		end
		self.terminals = (function()
			return {}
		end)()
		self.terminals = terms

		vim.api.nvim_buf_set_option(term.buf, "modified", false)
		vim.api.nvim_buf_delete(term.buf, { force = true })
	end

	function self.get_terms()
		return self.terminals
	end

	function self.get_term(id)
		for _, term in ipairs(self.terminals) do
			if id == term.id then
				return term
			end
		end
	end

	function self.get_term_by_buf(buf)
		for _, term in ipairs(self.terminals) do
			if buf == term.buf then
				return term
			end
		end
	end

	function self.set_term(id)
		local term = self.get_term(id)
		if term == nil then
			return
		end

		self.focus()
		vim.api.nvim_win_set_buf(self.win, term.buf)
		libwin.set_winbar_title(0, string.format("Terminal - %s", term.name))
	end

	return self
end

return TerminalComponent
