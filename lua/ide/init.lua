-- default components
local explorer        = require('ide.components.explorer')
local bufferlist      = require('ide.components.bufferlist')
local outline         = require('ide.components.outline')
local callhierarchy   = require('ide.components.callhierarchy')
local timeline        = require('ide.components.timeline')
local terminal        = require('ide.components.terminal')
local terminalbrowser = require('ide.components.terminal.terminalbrowser')
local changes         = require('ide.components.changes')
local commits         = require('ide.components.commits')
local branches        = require('ide.components.branches')
local bookmarks       = require('ide.components.bookmarks')

local M = {}

-- The default config which will be merged with the `config` provided to setup()
--
-- The user provided config may just provide the values they'd like to override
-- and can omit any defaults.
--
-- Modules can read from this field to get config values. For example
-- require('ide').config.
M.config = {
    -- The global icon set to use.
    -- values: "nerd", "codicon", "default"
    icon_set = "default",
    -- Place Component config overrides here. 
    -- The keys are the Component's unique name and the values are the
    -- config values to override.
    -- See the Component's documentation for available config values.
    components = {
        -- example...
        -- Explorer = {
        --     keymaps = {
        --         expand = "x",
        --     }
        -- }
    },
    -- default panel groups to display on left and right.
    panels = {
        left = "explorer",
        right = "git"
    },
    -- panels defined by groups of components, user is free to redefine the defaults
    -- and/or add additional.
    panel_groups = {
        explorer = { outline.Name, bufferlist.Name, explorer.Name, bookmarks.Name, callhierarchy.Name, terminalbrowser.Name },
        terminal = { terminal.Name },
        git = { changes.Name, commits.Name, timeline.Name, branches.Name }
    },

    -- workspaces config
    workspaces = {
        -- automatically close vim if only remaining windows are components
        auto_close = true
    }
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
    local wsctrl = require('ide.workspaces.workspace_controller').new(M.config.workspaces)
    wsctrl.init()
end

return M
