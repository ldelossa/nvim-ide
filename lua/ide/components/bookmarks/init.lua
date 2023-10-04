local component_factory = require("ide.panels.component_factory")
local component = require("ide.components.bookmarks.component")

local Init = {}

Init.Name = "Bookmarks"

local function register_component()
	component_factory.register(Init.Name, component.new)

	if vim.fn.isdirectory(vim.fn.fnamemodify(component.NotebooksPath, ":p")) == 0 then
		vim.fn.mkdir(vim.fn.fnamemodify(component.NotebooksPath, ":p"))
	end
end

-- call yourself, this will be triggered when another module wants to reference
-- ide.components.explorer.Name
register_component()

return Init
