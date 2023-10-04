local logger = require("ide.logger.logger")

local M = {}

function M.test_functionality()
	local log = logger.new("test", "test_functionality")
	log.error("test error log %s %s", "test-value", "test-value2")
	log.info("test info log %s %s", "test-value", "test-value2")
	log.warning("test warning log %s %s", "test-value", "test-value2")
	log.debug("test debug log %s %s", "test-value", "test-value2")
	logger.open_log()
end

return M
