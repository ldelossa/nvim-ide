local component_factory = require("ide.panels.component_factory")
local component = require("ide.components.branches.component")

local Init = {}

Init.Name = "Branches"

local function register_component()
	component_factory.register(Init.Name, component.new)
end

-- call yourself, this will be triggered when another module wants to reference
-- ide.components.explorer.Name
register_component()

return Init
