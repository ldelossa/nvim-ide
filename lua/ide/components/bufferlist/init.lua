local component_factory = require("ide.panels.component_factory")
local component = require("ide.components.bufferlist.component")

local Init = {}

Init.Name = "BufferList"

local function register_component()
	component_factory.register(Init.Name, component.new)
end

-- call yourself, this will be triggered when another module wants to reference
-- ide.components.bufferlist.Name
register_component()

return Init
