local M = {}

-- The default config which will be merged with the `config` provided to setup()
--
-- Modules can read from this field to get config values. For example
-- require('ide').config.
M.config = {
    -- the global icon set to use.
    -- values: "nerd", "codicon", "default"
    icon_set = "default",
}

function M.setup(config)
    -- merge the incoming config with our global, forcing the right table's keys
    -- to overwrite the left's.
    M.config = vim.tbl_deep_extend("force", M.config, config)

    -- configure the global icon set.
    if M.config["icon_set"] == "nerd" then
        require('ide.icons').global_icon_set = require('ide.icons.nerd_icon_set').new()
    end
    if M.config["icon_set"] == "codicon" then
        require('ide.icons').global_icon_set = require('ide.icons.codicon_icon_set').new()
    end

    -- create and launch a workspace controller.
    local wsctrl = require('ide.workspaces.workspace_controller').new()
    wsctrl.init()
end

return M
