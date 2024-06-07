local base = require("ide.panels.component")
local sort = require("ide.lib.sort")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local libws = require("ide.lib.workspace")
local logger = require("ide.logger.logger")
local icons = require("ide.icons")
local commands = require("ide.components.bufferlist.commands")

local BufferListComponent = {}

local config_prototype = {
	default_height = nil,
	-- float the current buffer to the top of list
	current_buffer_top = false,
	-- disable all keymaps
	disabled_keymaps = false,
	hidden = false,
	keymaps = {
		edit = "<CR>",
		edit_split = "s",
		edit_vsplit = "v",
		delete = "d",
		hide = "H",
		close = "X",
		details = "d",
		help = "?"
	},
}

BufferListComponent.new = function(name, config)
	local self = base.new(name)
	self.bufs = {}
	self.logger = logger.new("bufferlist")
	self.buf = nil
	self.augroup = vim.api.nvim_create_augroup("NvimIdeBufferlist", { clear = true })

	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	self.hidden = self.config.hidden

	local function setup_buffer()
		local log = self.logger.logger_from(nil, "Component._setup_buffer")

		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(buf, "filetype", "bufferlist")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_option(buf, "textwidth", 0)
		vim.api.nvim_buf_set_option(buf, "wrapmargin", 0)

		local keymaps = {
			{
				key = self.config.keymaps.edit,
				cb = function()
					self.open_buf({ fargs = {} })
				end,
			},
			{
				key = self.config.keymaps.edit_split,
				cb = function()
					self.open_buf({ fargs = { "split" } })
				end,
			},
			{
				key = self.config.keymaps.edit_vsplit,
				cb = function()
					self.open_buf({ fargs = { "vsplit" } })
				end,
			},
			{
				key = self.config.keymaps.delete,
				cb = function()
					self.close_buf()
				end,
			},
			{
				key = self.config.keymaps.hide,
				cb = function()
					self.hide()
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
				print(vim.inspect(keymap))
				libbuf.set_keymap_normal(buf, keymap.key, keymap.cb)
			end
		end

		-- setup autocmds to refresh
		vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufWipeout" }, {
			callback = function()
				vim.schedule(self.refresh)
			end,
			group = self.augroup,
		})
		vim.api.nvim_create_autocmd({ "CursorHold" }, {
			callback = function(args)
				if not libws.is_current_ws(self.workspace) then
					return
				end
				if libbuf.is_listed_buf(args.buf) then
					vim.schedule(self.refresh)
				end
			end,
			group = self.augroup,
		})

		return buf
	end

	function self.open()
		local log = self.logger.logger_from(nil, "Component.open")
		log.debug("BufferList component opening, workspace %s", vim.api.nvim_get_current_tabpage())

		-- init buf if not already
		if self.buf == nil then
			log.debug("buffer does not exist, creating.", vim.api.nvim_get_current_tabpage())
			self.buf = setup_buffer()
		end

		log.debug("using buffer %d", self.buf)

		-- initial render
		self.refresh()
		return self.buf
	end

	function self.post_win_create()
		local log = self.logger.logger_from(nil, "Component.post_win_create")
		-- setup web-dev-icons highlights if available
		if pcall(require, "nvim-web-devicons") then
			for _, icon_data in pairs(require("nvim-web-devicons").get_icons()) do
				local hl = "DevIcon" .. icon_data.name
				vim.cmd(string.format("syn match %s /%s/", hl, icon_data.icon))
			end
		end
		-- set highlights for global icon theme
		icons.global_icon_set.set_win_highlights()
		libwin.set_winbar_title(0, "BUFFERS")
	end

	function self.get_commands()
		return commands.new(self).get()
	end

	function self.refresh()
		local cur_buf = vim.api.nvim_get_current_buf()
		local listed_bufs = libbuf.get_listed_bufs()
		if #listed_bufs == 0 then
			return
		end

		local bufs = vim.tbl_map(function(buf)
			local icon
			-- use webdev icons if possible
			if pcall(require, "nvim-web-devicons") then
				local filename = vim.api.nvim_buf_get_name(buf)
				local ext = vim.fn.fnamemodify(filename, ":e:e")
				icon = require("nvim-web-devicons").get_icon(filename, ext, { default = true })
				if self.kind == "dir" then
					icon = require("nvim-web-devicons").get_icon("dir")
				end
			else
				if self.kind ~= "dir" then
					icon = icons.global_icon_set.get_icon("File")
				else
					icon = icons.global_icon_set.get_icon("Folder")
				end
			end
			return {
				name = libbuf.get_unique_filename(vim.api.nvim_buf_get_name(buf)),
				icon = icon,
				id = buf,
				is_current = (cur_buf == buf),
			}
		end, libbuf.get_listed_bufs())
		self.bufs = bufs
		if self.config.current_buffer_top then
			sort(self.bufs, function(a, _)
				if a.is_current then
					return true
				end
				return false
			end)
		end
		self.render()
	end

	function self.buf_under_cursor()
		return self.bufs[self.state["cursor"].cursor[1]]
	end

	function self.render()
		local lines = {}
		for i, buf in ipairs(self.bufs) do
			local line = string.format(" %s %s ", buf.icon, buf.name)
			if buf.is_current then
				line = string.format(" %s * %s ", buf.icon, buf.name)
				-- track the currently opened buffer if we are displayed.
				if self.is_displayed() then
					libwin.safe_cursor_restore(self.win, { i, 1 })
				end
			end
			if vim.api.nvim_buf_get_option(buf.id, "modified") then
				line = line .. " [+]"
			end
			table.insert(lines, line)
		end

		vim.api.nvim_buf_set_option(self.buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(self.buf, "modifiable", false)
	end

	function self.open_buf(args)
		local log = self.logger.logger_from(nil, "Component.open_buf")

		local split_type = vim.tbl_get(args or {}, "fargs", 1)
		local bufnode = self.buf_under_cursor()
		if not bufnode then
			log.error("component failed to unmarshal buffer from list")
			return
		end

		if self.workspace == nil then
			log.error("component has a nil workspace, can't open filenode %s", fnode.path)
		end

		local win = self.workspace.get_win()
		vim.api.nvim_set_current_win(win)

		if split_type == "split" then
			vim.cmd("split")
		elseif split_type == "vsplit" then
			vim.cmd("vsplit")
		end

		vim.api.nvim_win_set_buf(win, bufnode.id)
	end

	function self.close_buf()
		local log = self.logger.logger_from(nil, "Component.open_buf")

		local bufnode = self.buf_under_cursor()
		if not bufnode then
			log.error("component failed to unmarshal buffer from list")
			return
		end

		vim.api.nvim_buf_delete(bufnode.id, {})
		self.refresh()
	end

	return self
end

return BufferListComponent
