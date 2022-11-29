local base = require("ide.panels.component")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local logger = require("ide.logger.logger")
local icon_set = require("ide.icons").global_icon_set
local commands = require("ide.components.bufferlist.commands")

local BufferListComponent = {}

local config_prototype = {
	disabled_keymaps = false,
	keymaps = {
		edit = "<CR>",
		edit_split = "s",
		edit_vsplit = "v",
		close = "d",
	},
}

BufferListComponent.new = function(name, config)
	local self = base.new(name)
	self.buffers = {}
	self.logger = logger.new("bufferlist")
	self.config = vim.deepcopy(config_prototype)
	self.buf = nil
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	local function setup_buffer()
		local log = self.logger.logger_from(nil, "Component._setup_buffer")

		local buf = vim.api.nvim_create_buf(false, true)
		local cur_tab = vim.api.nvim_get_current_tabpage()
		vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(buf, "filetype", "bufferlist")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_option(buf, "textwidth", 0)
		vim.api.nvim_buf_set_option(buf, "wrapmargin", 0)

		if not self.config.disable_keymaps then
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.edit, "", {
				silent = true,
				callback = function()
					self.open_buf({ fargs = {} })
				end,
			})
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.edit_split, "", {
				silent = true,
				callback = function()
					self.open_buf({ fargs = { "split" } })
				end,
			})
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.edit_vsplit, "", {
				silent = true,
				callback = function()
					self.open_buf({ fargs = { "vsplit" } })
				end,
			})
			vim.api.nvim_buf_set_keymap(buf, "n", self.config.keymaps.close, "", {
				silent = true,
				callback = function()
					self.close_buf()
				end,
			})
		end

		-- setup autocmds to refresh
		vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufWipeout" }, {
			callback = function()
				vim.schedule(self.refresh)
			end,
			group = vim.api.nvim_create_augroup("NvimIdeBufferlist", { clear = true }),
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
		icon_set.set_win_highlights()
		libwin.set_winbar_title(0, "BUFFERS")
	end

	function self.get_commands()
		return commands.new(self).get()
	end

	function self.refresh()
		local bufs = vim.tbl_map(function(buf)
			local icon
			-- use webdev icons if possible
			if pcall(require, "nvim-web-devicons") then
				local name = vim.api.nvim_buf_get_name(buf)
				local ext = vim.fn.fnamemodify(name, ":e:e")
				icon = require("nvim-web-devicons").get_icon(name, ext, { default = true })
				if self.kind == "dir" then
					icon = require("nvim-web-devicons").get_icon("dir")
				end
			else
				if self.kind ~= "dir" then
					icon = icon_set.get_icon("File")
				else
					icon = icon_set.get_icon("Folder")
				end
			end
			return {
				name = libbuf.get_unique_filename(vim.api.nvim_buf_get_name(buf)),
				icon = icon,
				id = buf,
			}
		end, libbuf.get_listed_bufs())
		self.bufs = bufs
		self.render()
	end

	function self.buf_under_cursor()
		return self.bufs[self.state["cursor"].cursor[1]]
	end

	function self.render()
		local lines = vim.tbl_map(function(buf)
			return string.format(" %s %s ", buf.icon, buf.name)
		end, self.bufs or {})

		vim.api.nvim_buf_set_option(self.buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(self.buf, "modifiable", true)
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
