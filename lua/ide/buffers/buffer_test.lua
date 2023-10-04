local buffer = require("ide.buffers.buffer")
local M = {}

function M.test_functionality()
	local buf = buffer.new(false, false)
	buf.write_lines({ "first" })
	buf.write_lines({ "second" })
	buf.write_lines({ "third" })

	local lines = buf.read_lines()
	assert(lines[1] == "first")
	assert(lines[2] == "second")
	assert(lines[3] == "third")
end

return M
