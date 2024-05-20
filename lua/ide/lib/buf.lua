local Buf = {}

function Buf.is_in_workspace(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	-- make it absolute
	name = vim.fn.fnamemodify(name, ":p")
	local cwd = vim.fn.getcwd()
	cwd = vim.fn.fnamemodify(cwd, ":p")
	if vim.fn.match(name, cwd) == -1 then
		return false
	end
	return true
end

function Buf.buf_is_valid(buf)
	if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
		return true
	end
	return false
end

function Buf.is_component_buf(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if vim.fn.match(name, "component://") >= 0 then
		return true
	end
	return false
end

function Buf.is_regular_buffer(buf)
	if not Buf.buf_is_valid(buf) then
		return false
	end

	-- only consider normal buffers with files loaded into them.
	if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
		return false
	end

	local buf_name = vim.api.nvim_buf_get_name(buf)

	-- component buffers are not regular buffers
	if string.sub(buf_name, 1, 12) == "component://" then
		return false
	end

	-- diff buffers are not regular buffers
	if string.sub(buf_name, 1, 7) == "diff://" then
		return false
	end

	return true
end

function Buf.next_regular_buffer()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if (Buf.is_regular_buffer(buf)) then
			return buf
		end
	end
	return nil
end

function Buf.truncate_buffer(buf)
	if Buf.buf_is_valid(buf) then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
	end
end

function Buf.toggle_modifiable(buf)
	if Buf.buf_is_valid(buf) then
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		return function()
			vim.api.nvim_buf_set_option(buf, "modifiable", false)
		end
	end
	return function() end
end

function Buf.has_lsp_clients(buf)
	if #vim.lsp.get_clients({ bufnr = buf }) > 0 then
		return true
	end
	return false
end

function Buf.set_option_with_restore(buf, option, value)
	local cur = vim.api.nvim_buf_get_option(buf, option)
	vim.api.nvim_win_set_option(buf, value)
	return function()
		vim.api.nvim_win_set_option(buf, cur)
	end
end

function Buf.buf_exists_by_name(name)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
		if buf_name == name then
			return true, buf
		end
	end
	return false
end

function Buf.delete_buffer_by_name(name)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
		if buf_name == name then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end

function Buf.is_listed_buf(bufnr)
	return vim.bo[bufnr].buflisted and vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

function Buf.get_listed_bufs()
	return vim.tbl_filter(function(bufnr)
		return Buf.is_listed_buf(bufnr)
	end, vim.api.nvim_list_bufs())
end

function Buf.get_current_filenames()
	return vim.tbl_map(vim.api.nvim_buf_get_name, Buf.get_listed_bufs())
end

function Buf.get_unique_filename(filename)
	local filenames = vim.tbl_filter(function(filename_other)
		return filename_other ~= filename
	end, Buf.get_current_filenames())

	-- Reverse filenames in order to compare their names
	filename = string.reverse(filename)
	filenames = vim.tbl_map(string.reverse, filenames)

	local index

	-- For every other filename, compare it with the name of the current file char-by-char to
	-- find the minimum index `i` where the i-th character is different for the two filenames
	-- After doing it for every filename, get the maximum value of `i`
	if next(filenames) then
		index = math.max(unpack(vim.tbl_map(function(filename_other)
			for i = 1, #filename do
				-- Compare i-th character of both names until they aren't equal
				if filename:sub(i, i) ~= filename_other:sub(i, i) then
					return i
				end
			end
			return 1
		end, filenames)))
	else
		index = 1
	end

	-- Iterate backwards (since filename is reversed) until a "/" is found
	-- in order to show a valid file path
	while index <= #filename do
		if filename:sub(index, index) == "/" then
			index = index - 1
			break
		end

		index = index + 1
	end

	return string.reverse(string.sub(filename, 1, index))
end

-- Opinionated way of setting per-buffer keymaps, this is the typical
-- usage for nvim-ide components.
function Buf.set_keymap_normal(buf, keymap, cb)
	vim.api.nvim_buf_set_keymap(buf, "n", keymap, "", { silent = true, callback = cb })
end

return Buf
