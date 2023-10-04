local buffer = require("ide.buffers.buffer")
local libwin = require("ide.lib.win")
local autocmd = require("ide.lib.autocmd")

local DoomScrollBuffer = {}

-- A DoomScrollBuffer is a buffer which calls the on_scroll callback
-- each time it detects the cursor has moved to the final line of
-- the buffer.
--
-- @on_scroll - @function(@DoomScrollBuffer), a callback functions which
--              must return an array of @string, each of which is a line to
--              append to the buffer.
--              the function is called with the @DoomScrollBuffer performing the
--              callback.
DoomScrollBuffer.new = function(on_scroll, buf, listed, scratch, opts)
	local self = buffer.new(buf, listed, scratch)
	self.on_scroll = on_scroll
	self.on_scroll_aucmd = nil
	self.debouncing = false

	function self.doomscroll_aucmd(args)
		local event_win = vim.api.nvim_get_current_win()
		if not libwin.win_is_valid(event_win) then
			return
		end
		local buf = vim.api.nvim_win_get_buf(event_win)
		if buf == self.buf then
			local cursor = libwin.get_cursor(event_win)
			if cursor == nil then
				return
			end
			if cursor[1] == vim.api.nvim_buf_line_count(self.buf) then
				local lines = on_scroll(self)
				if lines ~= nil then
					self.write_lines(lines)
				end
			end
		end
	end

	autocmd.buf_enter_and_leave(self.buf, function()
		self.on_scroll_aucmd = vim.api.nvim_create_autocmd({ "CursorHold" }, {
			callback = function()
				if not self.debouncing then
					self.doomscroll_aucmd()
					self.debouncing = true
					vim.defer_fn(function()
						self.debouncing = false
					end, 350)
				end
			end,
		})
	end, function()
		if self.on_scroll_aucmd ~= nil then
			vim.api.nvim_del_autocmd(self.on_scroll_aucmd)
			self.on_scroll_aucmd = nil
		end
	end)

	return self
end

return DoomScrollBuffer
