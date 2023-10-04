local diff_buffer = require("ide.buffers.diffbuffer")

local M = {}

function M.test_write_diff()
	local diff_buf = diff_buffer.new()
	local lines_a = { "one", "two", "three" }
	local lines_b = { "one", "four", "three" }
	diff_buf.setup()
	diff_buf.write_lines(lines_a, "a")
	diff_buf.write_lines(lines_b, "b")
	diff_buf.diff()
end

function M.test_path_diff()
	vim.fn.writefile({ "one", "two", "three" }, "/tmp/a")
	vim.fn.writefile({ "one", "four", "three" }, "/tmp/b")

	local diff_buf = diff_buffer.new()
	diff_buf.setup()
	diff_buf.open_buffer("/tmp/a", "a")
	diff_buf.open_buffer("/tmp/b", "b")
	diff_buf.diff()

	vim.fn.delete("/tmp/a")
	vim.fn.delete("/tmp/b")
end

function M.test_path_mix()
	vim.fn.writefile({ "one", "two", "three" }, "/tmp/a")

	local diff_buf = diff_buffer.new()
	diff_buf.setup()
	diff_buf.open_buffer("/tmp/a", "a")

	local lines_b = { "one", "four", "three" }
	diff_buf.write_lines(lines_b, "b")
	diff_buf.diff()
end

return M
