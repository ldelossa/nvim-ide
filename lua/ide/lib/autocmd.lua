local AutoCMD = {}

-- Creates a pair of autocommands.
-- The `on_enter` callback is called when `buf` is entered.
-- Likewise the `on_leave` callback is issued the buffer is unfocused.
--
-- This is useful when you want to use a noisy autocmd event such as "CursorMoved"
-- but only when inside a specific buffer.
--
-- Both autocmds will be deleted once `buf` is deleted.
function AutoCMD.buf_enter_and_leave(buf, on_enter, on_leave)
	local buf_enter = vim.api.nvim_create_autocmd({ "BufEnter" }, {
		buffer = buf,
		callback = function(args)
			on_enter(args)
		end,
	})

	local buf_leave = vim.api.nvim_create_autocmd({ "BufLeave" }, {
		buffer = buf,
		callback = function(args)
			on_leave(args)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufDelete" }, {
		buffer = buf,
		callback = function()
			vim.api.nvim_del_autocmd(buf_enter)
			vim.api.nvim_del_autocmd(buf_leave)
		end,
	})
end

return AutoCMD
