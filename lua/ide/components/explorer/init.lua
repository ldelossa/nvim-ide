local component_factory = require("ide.panels.component_factory")
local component = require("ide.components.explorer.component")

local Init = {}

Init.Name = "Explorer"

local function register_component()
	if pcall(require, "nvim-web-devicons") then
		-- setup the dir icon and file type.
		local devicons = require("nvim-web-devicons")
		require("nvim-web-devicons").set_icon({
			["dir"] = {
				icon = "",
				color = "#6d8086",
				cterm_color = "108",
				name = "Directory",
			},
		})
		devicons.set_up_highlights()
	end

	component_factory.register(Init.Name, component.new)
end

-- call yourself, this will be triggered when another module wants to reference
-- ide.components.explorer.Name
register_component()

return Init
