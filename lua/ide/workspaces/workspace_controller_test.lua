local workspace_ctlr = require("ide.workspaces.workspace_controller")
local component_factory = require("ide.panels.component_factory")
local test_component = require("ide.panels.test_component")

local M = {}

function M.test_functionality()
	-- register a component with the component factory
	component_factory.register("test-component", test_component.new)

	local wsc = workspace_ctlr.new()
	wsc.init()
end

return M
