local Win = {}

-- Reports true if the window is both non-nil and valid.
function Win.win_is_valid(win)
	if win ~= nil and vim.api.nvim_win_is_valid(win) then
		return true
	end
	return false
end

function Win.safe_cursor_restore(win, cursor)
	if not Win.win_is_valid(win) then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local lc = vim.api.nvim_buf_line_count(buf)
	if cursor[1] > lc then
		cursor[1] = lc
	end
	vim.api.nvim_win_set_cursor(win, cursor)
end

function Win.get_cursor(win)
	if not Win.win_is_valid(win) then
		return
	end
	return vim.api.nvim_win_get_cursor(win)
end

-- Returns the current cursor for `win` and also a function which can be called
-- to restore the cursor to this position.
function Win.get_cursor_with_restore(win)
	if not Win.win_is_valid(win) then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(win)
	return cursor, function()
		if Win.win_is_valid(win) then
			Win.safe_cursor_restore(win, cursor)
		end
	end
end

function Win.restore_cur_win()
	local cur_win = vim.api.nvim_get_current_win()
	return function()
		if Win.win_is_valid(cur_win) then
			vim.api.nvim_set_current_win(cur_win)
		end
	end
end

function Win.is_component_win(win)
	local buf = vim.api.nvim_win_get_buf(win)
	local name = vim.api.nvim_buf_get_name(buf)
	if vim.fn.match(name, "component://") >= 0 then
		return true
	end
	return false
end

function Win.get_buf(win)
	return vim.api.nvim_win_get_buf(win)
end

function Win.set_winbar_title(win, str)
	if Win.win_is_valid(win) then
		vim.api.nvim_win_set_option(win, "winbar", vim.fn.toupper(str))
	end
end

function Win.open_buffer(win, path)
	if not Win.win_is_valid(win) then
		return
	end
	vim.api.nvim_set_current_win(win)
	vim.cmd("edit " .. path)
end

function Win.set_option_with_restore(win, option, value)
	local cur = vim.api.nvim_win_get_option(win, option)
	vim.api.nvim_win_set_option(win, option, value)
	return function()
		if Win.win_is_valid(win) then
			vim.api.nvim_win_set_option(win, option, cur)
		end
	end
end

return Win
