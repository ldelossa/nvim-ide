local options = require("ide.lib.options")
local libbuf = require("ide.lib.buf")

local Buffer = {}

-- Buffer is a base buffer class which can be used to derive more complex buffer
-- types.
--
-- It provides the basic functionality for a vim buffer, including, reading,
-- writing, ext marks, highlighting, and virtual text.
Buffer.new = function(buf, listed, scratch)
	local self = {
		buf = nil,
		first_write = true,
	}
	if listed == nil then
		listed = true
	end
	if scratch == nil then
		scratch = false
	end
	if buf == nil then
		self.buf = vim.api.nvim_create_buf(listed, scratch)
	else
		self.buf = buf
	end

	local function _modifiable_with_restore()
		local restore = function() end
		if not self.is_modifiable() then
			self.set_modifiable(true)
			restore = function()
				self.set_modifiable(false)
			end
		end
		return restore
	end

	function self.set_modifiable(bool)
		if not libbuf.buf_is_valid(self.buf) then
			error("attempted to set invalid buffer as modifiable")
		end
		vim.api.nvim_buf_set_option(self.buf, "modifiable", bool)
	end

	function self.is_modifiable()
		if not libbuf.buf_is_valid(self.buf) then
			return
		end
		return vim.api.nvim_buf_get_option(self.buf, "modifiable")
	end

	function self.truncate()
		local restore = _modifiable_with_restore()
		libbuf.truncate_buffer(self.buf)
		restore()
	end

	-- write lines to the buffer.
	--
	-- if the buffer is not modifiable it will be set so, and then set back to
	-- non-modifiable after the write.
	--
	-- if no opts field is provided, this will append lines to the buffer.
	--
	-- @lines - @table, an array of @string(s), each of which is a line to write
	--          into the buffer.
	-- @opts  - @table, a table of options to provide to nvim_buf_get_lines
	--          Fields:
	--              @start - @int, the start line (zero indexed) to begin writing/replacing lines.
	--              @end - @int, where to end the write.
	--              @strict - @bool, whether to produce an error if start,end are out
	--              of the buffer's bound.
	--
	-- return: void
	function self.write_lines(lines, opts)
		if not libbuf.buf_is_valid(self.buf) then
			return
		end
		local restore = _modifiable_with_restore()
		local buf_end = vim.api.nvim_buf_line_count(self.buf)
		local o = { start = buf_end, ["end"] = buf_end + #lines - 1, strict = false }
		if self.first_write then
			o.start = 0
		end
		o = options.merge(o, opts)
		vim.api.nvim_buf_set_lines(self.buf, o.start, o["end"], o.strict, lines)
		if self.first_write then
			self.first_write = false
		end
		restore()
	end

	-- read lines from the buffer.
	--
	-- @opts - @table, a table of options to provide to nvim_buf_get_lines
	--         Fields:
	--          @start - @int, the start line (zero indexed) to begin reading from
	--          @end - @int, where to end the read.
	--          @strict - @bool, whether to produce an error if start,end are out
	--          of the buffer's bound.
	--
	-- return: @table, an array of @string, each one being a line from the buffer.
	function self.read_lines(opts)
		if not libbuf.buf_is_valid(self.buf) then
			return
		end
		local buf_end = vim.api.nvim_buf_line_count(self.buf)
		local o = { start = 0, ["end"] = buf_end, strict = false }
		o = options.merge(o, opts)
		local lines = vim.api.nvim_buf_get_lines(self.buf, o.start, o["end"], o.strict)
		return lines
	end

	function self.set_name(name)
		vim.api.nvim_buf_set_name(self.buf, name)
	end

	return self
end

return Buffer
