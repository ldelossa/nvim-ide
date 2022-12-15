local config = require('ide.config')
local logger = require('ide.logger.logger')

local M = {}

function M.setup(user_config)
    -- merge the incoming config with our global, forcing the right table's keys
    -- to overwrite the left's.
    config.config = vim.tbl_deep_extend("force", config.config, (user_config or {}))

    -- configure the global icon set.
    if config.config["icon_set"] == "nerd" then
        require('ide.icons').global_icon_set = require('ide.icons.nerd_icon_set').new()
    end
    if config.config["icon_set"] == "codicon" then
        require('ide.icons').global_icon_set = require('ide.icons.codicon_icon_set').new()
    end

    -- set the global log level of the any logger.
    logger.set_log_level(config.config.log_level)

    -- create and launch a workspace controller.
    local wsctrl = require('ide.workspaces.workspace_controller').new(config.config.workspaces)
    wsctrl.init()
end

return M
