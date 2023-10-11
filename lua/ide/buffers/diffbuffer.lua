local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local buffer = require("ide.buffers.buffer")
local workspace_registry = require("ide.workspaces.workspace_registry")

local DiffBuffer = {}

-- DiffBuffer is actually an abstraction over two buffers and associated windows.
--
-- A DiffBuffer will reliably create two vsplit windows, provide an API for placing
-- content into both, and perform a `vimdiff` over the contents.
DiffBuffer.new = function(path_a, path_b)
	self = {
		path_a = path_a,
		path_b = path_b,
		buffer_a = nil,
		buffer_b = nil,
		win_a = nil,
		win_b = nil,
	}

	-- Setup a new DiffBuffer view.
	--
	-- After this function is ran both win_a and win_b will have been created,
	-- displaying their associated buffer_a and buff_b, respectively.
	--
	-- All other windows other then component windows will have been closed.
	--
	-- The caller can decide to perform this action in a new tab if they would
	-- rather not disrupt the current one.
	--
	-- No vimdiff commands are issued as part of this function, the caller should
	-- continue to load the contents of buffer_a and buffer_b and then use the
	-- `diff` function to configure these buffers as a vimdiff.
	function self.setup()
		-- find any non-component windows in the current tab.
		local wins = {}
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if not libwin.is_component_win(w) then
				table.insert(wins, w)
			end
		end

		-- if no wins, create one
		if #wins == 0 then
			vim.cmd("vsplit")
			-- may inherit the SB win highlight, reset it.
			vim.api.nvim_win_set_option(cur_win, "winhighlight", "Normal:Normal")
		else
			vim.api.nvim_set_current_win(wins[1])
		end

		-- close all other wins
		for _, w in ipairs(wins) do
			if w ~= wins[1] and libwin.win_is_valid(w) then
				vim.api.nvim_win_close(w, true)
			end
		end

		self.win_a = vim.api.nvim_get_current_win()
		-- vertical split to get win_b
		vim.cmd("vsplit")

		self.win_b = vim.api.nvim_get_current_win()
	end

	-- Write a series of lines into either buffer_a or buffer_b.
	--
	-- The chosen buffer will be truncated first and the lines are not appended
	-- to the buffer.
	--
	-- Thus, the intended use of this method is to write all lines to be diff'd
	-- at once into the buffer_a or buffer_b.
	--
	-- @lines - @table, an array of strings to write to the buffer.
	-- @which - @string, a string of either "a" or "b" indicating which diff
	--          buffer to write the lines to.
	function self.write_lines(lines, which, opts)
		local o = {
			listed = true,
			scratch = false,
			modifiable = true,
		}
		o = vim.tbl_extend("force", o, opts)

		local buf = nil
		if which == "a" then
			if self.buffer_a == nil then
				self.buffer_a = buffer.new(nil, o.listed, o.scratch)
				vim.api.nvim_win_set_buf(self.win_a, self.buffer_a.buf)
			end
			buf = self.buffer_a
		elseif which == "b" then
			if self.buffer_b == nil then
				self.buffer_b = buffer.new(nil, o.listed, o.scratch)
				vim.api.nvim_win_set_buf(self.win_b, self.buffer_b.buf)
			end
			buf = self.buffer_b
		end
		-- set buftype to nofile since we have no file backing it
		vim.api.nvim_buf_set_option(buf.buf, "buftype", "nofile")

		buf.set_modifiable(o.modifiable)

		buf.truncate()
		buf.write_lines(lines)
	end

	-- Open a particular file system path in either diff window a or b.
	--
	-- The buffer_a or buffer_b fields of @DiffBuffer will be updated with the
	-- new buffer that was opened.
	function self.open_buffer(path, which, opts)
		local win = nil
		if which == "a" then
			win = self.win_a
			libwin.open_buffer(win, path)
			self.buffer_a = buffer.new(vim.api.nvim_win_get_buf(0))
			self.path_a = path
		elseif which == "b" then
			win = self.win_b
			libwin.open_buffer(win, path)
			self.buffer_b = buffer.new(vim.api.nvim_win_get_buf(0))
			self.path_b = path
		end
	end

	-- Perform a vimdiff over win_a and win_b in their current configuration.
	--
	-- The caller should have either written content to buffer_a and buffer_b, or
	-- opened a file in win_a or win_b, or some combination of both, before
	-- calling this.
	function self.diff()
		if not libwin.win_is_valid(self.win_a) or not libwin.win_is_valid(self.win_b) then
			return
		end
		vim.api.nvim_set_current_win(self.win_a)
		vim.cmd("filetype detect")
		vim.cmd("diffthis")
		vim.api.nvim_set_current_win(self.win_b)
		vim.cmd("filetype detect")
		vim.cmd("diffthis")

		-- setup autcommands which rip the entire diff buffer down on :q of either
		-- a or b
		local aucmd_a = nil
		local aucmd_b = nil

		aucmd_a = vim.api.nvim_create_autocmd("QuitPre", {
			callback = function(args)
				local win = vim.api.nvim_get_current_win()
				if libwin.win_is_valid(win) and win == self.win_a then
					-- win_a is going to close so lets recover from diff in win_a
					local buf_to_use = libbuf.next_regular_buffer()
					if buf_to_use == nil then
						buf_to_use = vim.api.nvim_create_buf(false, false)
					end
					if libwin.win_is_valid(self.win_b) then
						vim.api.nvim_win_set_buf(self.win_b, buf_to_use)
						-- weird but sometimes we loose the filetype when switching back
						vim.cmd("filetype detect")
					end
					if libbuf.buf_is_valid(self.buffer_a.buf) then
						vim.api.nvim_buf_delete(self.buffer_a.buf, { force = true })
					end
					if libbuf.buf_is_valid(self.buffer_b.buf) then
						vim.api.nvim_buf_delete(self.buffer_b.buf, { force = true })
					end
					vim.api.nvim_del_autocmd(aucmd_a)
					vim.api.nvim_del_autocmd(aucmd_b)
				end
			end,
		})

		aucmd_b = vim.api.nvim_create_autocmd("QuitPre", {
			callback = function(args)
				local win = vim.api.nvim_get_current_win()
				if libwin.win_is_valid(win) and win == self.win_b then
					-- win_b is going to close so lets recover from diff in win_a
					local buf_to_use = libbuf.next_regular_buffer()
					if buf_to_use == nil then
						buf_to_use = vim.api.nvim_create_buf(false, false)
					end
					if libwin.win_is_valid(self.win_a) then
						vim.api.nvim_win_set_buf(self.win_a, buf_to_use)
						-- weird but sometimes we loose the filetype when switching back
						vim.cmd("filetype detect")
					end
					if libbuf.buf_is_valid(self.buffer_a.buf) then
						vim.api.nvim_buf_delete(self.buffer_a.buf, { force = true })
					end
					if libbuf.buf_is_valid(self.buffer_b.buf) then
						vim.api.nvim_buf_delete(self.buffer_b.buf, { force = true })
					end
					vim.api.nvim_del_autocmd(aucmd_a)
					vim.api.nvim_del_autocmd(aucmd_b)
				end
			end,
		})
	end

	return self
end

return DiffBuffer
